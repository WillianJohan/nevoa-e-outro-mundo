package nom.render;

import java.util.Arrays;

/**
 * Névoa fluida: o núcleo da simulação, puro (sem API do jogo), testado em tests/java/FlowGridTest.java.
 *
 * Grade n x n de tiles, num andar só: a célula (i, j) é o tile do mundo (x0 + i, y0 + j). É escalonada:
 * a densidade mora no centro da célula e a velocidade nas faces, então a parede fina do jogo (borda
 * N/W de um square) é só uma face fechada. A densidade anda por fluxo nas faces (upwind conservativo):
 * face fechada não passa nada, por construção. Fora da grade é ar aberto, com a densidade ambiente e
 * pressão 0: a névoa entra e sai pelas bordas.
 */
public final class FlowGrid {
    public static final int F_SOLID = 1, F_TREE = 2, F_INDOOR = 4;
    /** Só na textura (canal a): a face oeste / norte da célula está fechada na máscara. */
    public static final int T_WALL_W = 8, T_WALL_N = 16;
    static final int F_FRESH = 32;
    /** Escala da velocidade na textura (tiles/s): o NOM_FLOW_VMAX do cabeçalho GLSL. */
    public static final float VEL_MAX = 4f;
    // por passo, cada face leva no máximo esta fração da célula: 4 faces < 1, densidade nunca negativa
    static final float MAX_FACE_FLUX = 0.24f;
    static final float MAX_DIFFUSE = 0.06f;
    static final float D_MAX = 1.5f;
    static final float V_CLAMP = 10f;
    static final float SOR = 1.8f;

    public final int n;
    public int x0, y0;
    public float ambient = 1f;
    public float windX, windY;
    public float windRelax = 0.6f;      // 1/s: a velocidade volta pro vento
    public float outdoorRefill = 0.12f; // 1/s: fora, a névoa volta pro ambiente (o rastro some em ~8 s)
    public float indoorDecay = 0.05f;   // 1/s: dentro, a névoa que entrou se desfaz
    public float edgeRefill = 2f;       // 1/s: nas bordas da grade, a névoa entra
    public float diffusion = 0.15f;     // tiles²/s
    // tiles²/s nas faces que tocam interior. Casa com uma porta só não recebe nada pelo vento (fluxo
    // incompressível: o que entra teria que sair por outra abertura), então a névoa escorre pra dentro
    // por aqui; penetra ~sqrt(indoorSeep / indoorDecay) ≈ 5 tiles.
    public float indoorSeep = 1.2f;
    public int iterations = 16;         // 128x128: ~0,9 ms por passo (Ryzen 7600X); 24 passa de 1 ms

    // Névoa viajante (sprint 0026). Tudo desligado aqui; o Flow liga.
    public FogBanks banks;              // fora da grade e célula nova vêm dos bancos (null: ambient)
    public boolean inertia;             // a velocidade é levada por ela mesma: esteira e redemoinho
    public float stillDecay;            // 1/s: fora, onde o ar para (atrás de prédio), a névoa se desfaz
    public float doorPuff;              // fração da diferença que uma porta que abre sopra pra dentro

    private final int nu, m;             // nu = n + 1 (faces u por linha); m = n + 2 (pressão com moldura de zeros)
    private final float[] d, dn, div, invSum, p;
    private final float[] cW, cE, cN, cS;  // peso de cada vizinho na pressão (face aberta / nº de faces abertas)
    private final float[] u, v;          // u: face oeste da célula (i, j) em j*nu + i; v: face norte em j*n + i
    private final byte[] openU, openV;   // máscara do jogo (parede, porta, janela)
    private final float[] wu, wv;        // 1 = face aberta de verdade (máscara e nenhum lado sólido)
    private final byte[] flags;
    private final float[] tmpF;
    private final byte[] tmpB;
    private final float[] edgeW, edgeE, edgeN, edgeS;  // densidade logo fora da grade, por linha / coluna
    private final float[] u2, v2;
    private final int[] doors = new int[64];           // faces que abriram: f = face u, ~f = face v
    private int doorCount;
    private boolean facesDirty = true;

    public FlowGrid(int n) {
        this.n = n;
        nu = n + 1;
        m = n + 2;
        d = new float[n * n];
        dn = new float[n * n];
        div = new float[n * n];
        invSum = new float[n * n];
        cW = new float[n * n];
        cE = new float[n * n];
        cN = new float[n * n];
        cS = new float[n * n];
        p = new float[m * m];
        u = new float[nu * n];
        v = new float[n * nu];
        openU = new byte[nu * n];
        openV = new byte[n * nu];
        wu = new float[nu * n];
        wv = new float[n * nu];
        flags = new byte[n * n];
        tmpF = new float[nu * n];
        tmpB = new byte[nu * n];
        edgeW = new float[n];
        edgeE = new float[n];
        edgeN = new float[n];
        edgeS = new float[n];
        u2 = new float[nu * n];
        v2 = new float[n * nu];
        reset(0, 0);
    }

    // ---------- estado ----------

    public void reset(int x0, int y0) {
        this.x0 = x0;
        this.y0 = y0;
        Arrays.fill(d, ambient);
        Arrays.fill(u, 0f);
        Arrays.fill(v, 0f);
        Arrays.fill(openU, (byte) 1);
        Arrays.fill(openV, (byte) 1);
        Arrays.fill(flags, (byte) F_FRESH);
        if (banks != null)
            for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) d[j * n + i] = freshDensity(i, j);
        doorCount = 0;
        facesDirty = true;
        refreshEdges();
    }

    private float freshDensity(int i, int j) {
        return banks == null ? ambient : ambient * banks.sample(x0 + i + 0.5, y0 + j + 0.5);
    }

    /** Flags do square (F_SOLID, F_TREE, F_INDOOR). Célula que acabou de entrar na grade e é interior começa vazia. */
    public void setCell(int i, int j, int f) {
        int c = j * n + i;
        int old = flags[c];
        if ((old & F_FRESH) != 0 && (f & F_INDOOR) != 0) d[c] = 0f;
        if (((old ^ f) & F_SOLID) != 0) facesDirty = true;
        flags[c] = (byte) (f & (F_SOLID | F_TREE | F_INDOOR));
    }

    public int cellFlags(int i, int j) { return flags[j * n + i] & (F_SOLID | F_TREE | F_INDOOR); }

    /** Face oeste da célula (i, j); i vai até n (a face leste da última coluna). */
    public void setOpenW(int i, int j, boolean open) {
        int f = j * nu + i;
        byte b = (byte) (open ? 1 : 0);
        if (openU[f] == b) return;
        if (open) queueDoor(f);
        openU[f] = b;
        facesDirty = true;
    }

    private void queueDoor(int code) {
        if (doorPuff > 0f && doorCount < doors.length) doors[doorCount++] = code;
    }

    /** Face norte da célula (i, j); j vai até n (a face sul da última linha). */
    public void setOpenN(int i, int j, boolean open) {
        int f = j * n + i;
        byte b = (byte) (open ? 1 : 0);
        if (openV[f] == b) return;
        if (open) queueDoor(~f);
        openV[f] = b;
        facesDirty = true;
    }

    public boolean isOpenW(int i, int j) { return openU[j * nu + i] != 0; }
    public boolean isOpenN(int i, int j) { return openV[j * n + i] != 0; }
    public float density(int i, int j) { return d[j * n + i]; }
    public void setDensity(int i, int j, float value) { d[j * n + i] = value; }
    public float faceU(int i, int j) { return u[j * nu + i]; }
    public float faceV(int i, int j) { return v[j * n + i]; }

    // ---------- diagnóstico ----------

    public int countCells(int flag) {
        int k = 0;
        for (byte f : flags) if ((f & flag) != 0) k++;
        return k;
    }

    public int closedFaces() {
        int k = 0;
        for (byte b : openU) if (b == 0) k++;
        for (byte b : openV) if (b == 0) k++;
        return k;
    }

    /** min, média, max da densidade. */
    public float[] densityStats() {
        float lo = Float.MAX_VALUE, hi = -Float.MAX_VALUE;
        double s = 0;
        for (float x : d) { lo = Math.min(lo, x); hi = Math.max(hi, x); s += x; }
        return new float[] { lo, (float) (s / d.length), hi };
    }

    public float totalMass() {
        double s = 0;
        for (float x : d) s += x;
        return (float) s;
    }

    // ---------- rolagem ----------

    /** Leva a grade pra nova origem; o que já estava no mundo fica onde estava. */
    public void scroll(int newX0, int newY0) {
        int dx = newX0 - x0, dy = newY0 - y0;
        if (dx == 0 && dy == 0) return;
        if (Math.abs(dx) >= n || Math.abs(dy) >= n) { reset(newX0, newY0); return; }
        shift(d, n, n, dx, dy, Float.NaN);
        shift(u, nu, n, dx, dy, 0f);
        shift(v, n, nu, dx, dy, 0f);
        shift(flags, n, n, dx, dy, (byte) F_FRESH);
        shift(openU, nu, n, dx, dy, (byte) 1);
        shift(openV, n, nu, dx, dy, (byte) 1);
        x0 = newX0;
        y0 = newY0;
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) if (Float.isNaN(d[j * n + i])) d[j * n + i] = freshDensity(i, j);
        doorCount = 0;
        facesDirty = true;
        refreshEdges();
    }

    private void shift(float[] a, int w, int h, int dx, int dy, float fill) {
        for (int j = 0; j < h; j++) {
            int oj = j + dy;
            for (int i = 0; i < w; i++) {
                int oi = i + dx;
                tmpF[j * w + i] = (oi >= 0 && oi < w && oj >= 0 && oj < h) ? a[oj * w + oi] : fill;
            }
        }
        System.arraycopy(tmpF, 0, a, 0, w * h);
    }

    private void shift(byte[] a, int w, int h, int dx, int dy, byte fill) {
        for (int j = 0; j < h; j++) {
            int oj = j + dy;
            for (int i = 0; i < w; i++) {
                int oi = i + dx;
                tmpB[j * w + i] = (oi >= 0 && oi < w && oj >= 0 && oj < h) ? a[oj * w + oi] : fill;
            }
        }
        System.arraycopy(tmpB, 0, a, 0, w * h);
    }

    // ---------- forças ----------

    /**
     * Quem anda em (wx, wy) a (vx, vy) tiles/s arrasta a névoa junto e abre um vazio onde passa:
     * o rastro. Coordenadas de mundo.
     */
    public void impulse(float wx, float wy, float vx, float vy, float radius) {
        float speed = (float) Math.sqrt(vx * vx + vy * vy);
        if (speed > 2 * VEL_MAX) { vx *= 2 * VEL_MAX / speed; vy *= 2 * VEL_MAX / speed; speed = 2 * VEL_MAX; }
        float lx = wx - x0, ly = wy - y0;
        int i0 = Math.max(0, (int) Math.floor(lx - radius)), i1 = Math.min(n, (int) Math.ceil(lx + radius));
        int j0 = Math.max(0, (int) Math.floor(ly - radius)), j1 = Math.min(n, (int) Math.ceil(ly + radius));
        float carve = Math.min(1f, speed / VEL_MAX) * 0.3f;
        for (int j = j0; j <= j1; j++) {
            for (int i = i0; i <= i1; i++) {
                if (j < n) {     // face oeste de (i, j), em (i, j + 0,5)
                    float w = falloff(i - lx, j + 0.5f - ly, radius);
                    if (w > 0) { int f = j * nu + i; u[f] += (vx - u[f]) * w * 0.8f; }
                }
                if (i < n) {     // face norte de (i, j), em (i + 0,5, j)
                    float w = falloff(i + 0.5f - lx, j - ly, radius);
                    if (w > 0) { int f = j * n + i; v[f] += (vy - v[f]) * w * 0.8f; }
                }
                if (i < n && j < n && carve > 0) {
                    float w = falloff(i + 0.5f - lx, j + 0.5f - ly, radius);
                    if (w > 0) d[j * n + i] *= 1f - carve * w;
                }
            }
        }
    }

    private static float falloff(float dx, float dy, float r) {
        float t = 1f - (float) Math.sqrt(dx * dx + dy * dy) / r;
        return t > 0 ? t * t : 0f;
    }

    // ---------- passo ----------

    /**
     * Tiro ou explosão em (wx, wy): a névoa do miolo (raio r) é empurrada pra um anel em volta, sem
     * criar nem sumir massa. Interior não recebe (a onda não atravessa parede de casa fechada).
     */
    public void blast(float wx, float wy, float radius) {
        if (radius <= 0f) return;
        float lx = wx - x0, ly = wy - y0, outer = radius * 1.6f, mid = (radius + outer) * 0.5f, half = (outer - radius) * 0.5f;
        int i0 = Math.max(0, (int) Math.floor(lx - outer)), i1 = Math.min(n - 1, (int) Math.ceil(lx + outer));
        int j0 = Math.max(0, (int) Math.floor(ly - outer)), j1 = Math.min(n - 1, (int) Math.ceil(ly + outer));
        if (i0 > i1 || j0 > j1) return;
        double taken = 0, ringW = 0;
        for (int j = j0; j <= j1; j++)
            for (int i = i0; i <= i1; i++) {
                int c = j * n + i;
                if ((flags[c] & F_SOLID) != 0) continue;
                float dist = (float) Math.hypot(i + 0.5f - lx, j + 0.5f - ly);
                if (dist < radius) {
                    float q = dist / radius, t = d[c] * 0.85f * (1f - q * q);
                    d[c] -= t;
                    dn[c] = t;
                    taken += t;
                } else if (dist < outer && (flags[c] & F_INDOOR) == 0) {
                    ringW += 1f - Math.abs(dist - mid) / half;
                }
            }
        double left = taken;
        if (ringW > 0)
            for (int j = j0; j <= j1; j++)
                for (int i = i0; i <= i1; i++) {
                    int c = j * n + i;
                    if ((flags[c] & (F_SOLID | F_INDOOR)) != 0) continue;
                    float dist = (float) Math.hypot(i + 0.5f - lx, j + 0.5f - ly);
                    if (dist < radius || dist >= outer) continue;
                    float put = (float) (taken * (1f - Math.abs(dist - mid) / half) / ringW);
                    put = Math.min(put, D_MAX - d[c]);
                    if (put <= 0f) continue;
                    d[c] += put;
                    left -= put;
                }
        if (left > 1e-6 && taken > 0) {           // o que não coube no anel volta pro miolo
            float back = (float) (left / taken);
            for (int j = j0; j <= j1; j++)
                for (int i = i0; i <= i1; i++) {
                    int c = j * n + i;
                    if ((flags[c] & F_SOLID) != 0) continue;
                    if (Math.hypot(i + 0.5f - lx, j + 0.5f - ly) < radius) d[c] += dn[c] * back;
                }
        }
    }

    public void step(float dt) {
        if (facesDirty) rebuildFaces();
        if (banks != null) banks.advance(windX, windY, dt);
        refreshEdges();
        puffDoors();
        if (inertia) advectVelocity(dt);
        float k = 1f - (float) Math.exp(-windRelax * dt);
        for (int f = 0; f < u.length; f++) u[f] = clampV(u[f] + (windX - u[f]) * k) * wu[f];
        for (int f = 0; f < v.length; f++) v[f] = clampV(v[f] + (windY - v[f]) * k) * wv[f];
        project();
        advect(dt);
        diffuse(dt);
        sources(dt);
    }

    private static float clampV(float x) { return x > V_CLAMP ? V_CLAMP : (x < -V_CLAMP ? -V_CLAMP : x); }

    private void refreshEdges() {
        if (banks == null) {
            Arrays.fill(edgeW, ambient); Arrays.fill(edgeE, ambient);
            Arrays.fill(edgeN, ambient); Arrays.fill(edgeS, ambient);
            return;
        }
        for (int k = 0; k < n; k++) {
            edgeW[k] = ambient * banks.sample(x0 - 0.5, y0 + k + 0.5);
            edgeE[k] = ambient * banks.sample(x0 + n + 0.5, y0 + k + 0.5);
            edgeN[k] = ambient * banks.sample(x0 + k + 0.5, y0 - 0.5);
            edgeS[k] = ambient * banks.sample(x0 + k + 0.5, y0 + n + 0.5);
        }
    }

    /** Porta (ou janela) que acabou de abrir: troca parte da diferença de névoa entre os dois lados. */
    private void puffDoors() {
        for (int k = 0; k < doorCount; k++) {
            int f = doors[k], a, b;
            if (f >= 0) {
                int j = f / nu, i = f % nu;
                if (i == 0 || i == n || wu[f] == 0f) continue;
                a = j * n + i - 1;
                b = a + 1;
            } else {
                f = ~f;
                int j = f / n, i = f % n;
                if (j == 0 || j == n || wv[f] == 0f) continue;
                a = (j - 1) * n + i;
                b = j * n + i;
            }
            float amt = doorPuff * (d[a] - d[b]);
            d[a] -= amt;
            d[b] += amt;
        }
        doorCount = 0;
    }

    /** Semi-lagrangiano: cada face pega a velocidade de onde o ar dela veio. */
    private void advectVelocity(float dt) {
        for (int j = 0; j < n; j++)
            for (int i = 0; i <= n; i++) {
                int f = j * nu + i;
                u2[f] = wu[f] == 0f ? 0f : sampleU(i - u[f] * dt, j + 0.5f - vAtU(i, j) * dt);
            }
        for (int j = 0; j <= n; j++)
            for (int i = 0; i < n; i++) {
                int f = j * n + i;
                v2[f] = wv[f] == 0f ? 0f : sampleV(i + 0.5f - uAtV(i, j) * dt, j - v[f] * dt);
            }
        System.arraycopy(u2, 0, u, 0, u.length);
        System.arraycopy(v2, 0, v, 0, v.length);
    }

    /** v nas quatro faces em volta da face oeste da célula (i, j). */
    private float vAtU(int i, int j) {
        int a = Math.max(0, i - 1), b = Math.min(n - 1, i);
        return 0.25f * (v[j * n + a] + v[j * n + b] + v[(j + 1) * n + a] + v[(j + 1) * n + b]);
    }

    /** u nas quatro faces em volta da face norte da célula (i, j). */
    private float uAtV(int i, int j) {
        int a = Math.max(0, j - 1), b = Math.min(n - 1, j);
        return 0.25f * (u[a * nu + i] + u[a * nu + i + 1] + u[b * nu + i] + u[b * nu + i + 1]);
    }

    /** u mora em (i, j + 0,5): i em [0, n], j em [0, n - 1]. */
    private float sampleU(float x, float y) {
        float gy = y - 0.5f;
        x = x < 0f ? 0f : (x > n ? n : x);
        gy = gy < 0f ? 0f : (gy > n - 1 ? n - 1 : gy);
        int i0 = Math.min((int) x, n - 1), j0 = Math.min((int) gy, n - 2);
        float fx = x - i0, fy = gy - j0;
        int f = j0 * nu + i0;
        return (u[f] * (1 - fx) + u[f + 1] * fx) * (1 - fy) + (u[f + nu] * (1 - fx) + u[f + nu + 1] * fx) * fy;
    }

    /** v mora em (i + 0,5, j): i em [0, n - 1], j em [0, n]. */
    private float sampleV(float x, float y) {
        float gx = x - 0.5f;
        gx = gx < 0f ? 0f : (gx > n - 1 ? n - 1 : gx);
        y = y < 0f ? 0f : (y > n ? n : y);
        int i0 = Math.min((int) gx, n - 2), j0 = Math.min((int) y, n - 1);
        float fx = gx - i0, fy = y - j0;
        int f = j0 * n + i0;
        return (v[f] * (1 - fx) + v[f + 1] * fx) * (1 - fy) + (v[f + n] * (1 - fx) + v[f + n + 1] * fx) * fy;
    }

    private boolean solid(int i, int j) {
        return i >= 0 && i < n && j >= 0 && j < n && (flags[j * n + i] & F_SOLID) != 0;
    }

    private void rebuildFaces() {
        for (int j = 0; j < n; j++)
            for (int i = 0; i <= n; i++) {
                int f = j * nu + i;
                wu[f] = (openU[f] != 0 && !solid(i - 1, j) && !solid(i, j)) ? 1f : 0f;
            }
        for (int j = 0; j <= n; j++)
            for (int i = 0; i < n; i++) {
                int f = j * n + i;
                wv[f] = (openV[f] != 0 && !solid(i, j - 1) && !solid(i, j)) ? 1f : 0f;
            }
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                int c = j * n + i, fw = j * nu + i;
                float s = wu[fw] + wu[fw + 1] + wv[c] + wv[c + n];
                float inv = ((flags[c] & F_SOLID) != 0 || s == 0) ? 0f : 1f / s;
                invSum[c] = inv;
                cW[c] = wu[fw] * inv;
                cE[c] = wu[fw + 1] * inv;
                cN[c] = wv[c] * inv;
                cS[c] = wv[c + n] * inv;
            }
        facesDirty = false;
    }

    /**
     * Tira a divergência (SOR red-black: a célula de uma cor só lê vizinhos da outra, sem cadeia de
     * dependência no laço). Começa do zero a cada passo: a velocidade que fica já é quase sem
     * divergência, e o que sobrar volta no passo seguinte.
     */
    private void project() {
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                int c = j * n + i, fw = j * nu + i;
                div[c] = (u[fw + 1] - u[fw] + v[c + n] - v[c]) * invSum[c];
            }
        Arrays.fill(p, 0f);
        for (int it = 0; it < iterations; it++) {
            for (int color = 0; color < 2; color++) {
                for (int j = 0; j < n; j++) {
                    int row = (j + 1) * m + 1;
                    for (int i = (j + color) & 1; i < n; i += 2) {
                        int c = j * n + i, q = row + i;
                        float t = cW[c] * p[q - 1] + cE[c] * p[q + 1] + cN[c] * p[q - m] + cS[c] * p[q + m] - div[c];
                        p[q] += SOR * (t - p[q]);
                    }
                }
            }
        }
        for (int j = 0; j < n; j++) {
            int row = (j + 1) * m + 1;
            for (int i = 0; i <= n; i++) {
                int f = j * nu + i;
                if (wu[f] != 0f) u[f] -= p[row + i] - p[row + i - 1];
            }
        }
        for (int j = 0; j <= n; j++) {
            int row = (j + 1) * m + 1;
            for (int i = 0; i < n; i++) {
                int f = j * n + i;
                if (wv[f] != 0f) v[f] -= p[row + i] - p[row + i - m];
            }
        }
    }

    private void advect(float dt) {
        System.arraycopy(d, 0, dn, 0, d.length);
        for (int j = 0; j < n; j++)
            for (int i = 0; i <= n; i++) {
                int f = j * nu + i;
                if (wu[f] == 0f) continue;
                float c = limit(u[f] * dt);
                float src = c > 0 ? (i > 0 ? d[j * n + i - 1] : edgeW[j]) : (i < n ? d[j * n + i] : edgeE[j]);
                move(i > 0 ? j * n + i - 1 : -1, i < n ? j * n + i : -1, c * src);
            }
        for (int j = 0; j <= n; j++)
            for (int i = 0; i < n; i++) {
                int f = j * n + i;
                if (wv[f] == 0f) continue;
                float c = limit(v[f] * dt);
                float src = c > 0 ? (j > 0 ? d[f - n] : edgeN[i]) : (j < n ? d[f] : edgeS[i]);
                move(j > 0 ? f - n : -1, j < n ? f : -1, c * src);
            }
        System.arraycopy(dn, 0, d, 0, d.length);
    }

    private static float limit(float c) {
        return c > MAX_FACE_FLUX ? MAX_FACE_FLUX : (c < -MAX_FACE_FLUX ? -MAX_FACE_FLUX : c);
    }

    /** Fluxo da célula a (oeste/norte) pra b (leste/sul); -1 = fora da grade. */
    private void move(int a, int b, float flux) {
        if (a >= 0) dn[a] -= flux;
        if (b >= 0) dn[b] += flux;
    }

    private void diffuse(float dt) {
        float aOut = Math.min(diffusion * dt, MAX_DIFFUSE), aIn = Math.min(indoorSeep * dt, MAX_DIFFUSE);
        if (aOut <= 0f && aIn <= 0f) return;
        System.arraycopy(d, 0, dn, 0, d.length);
        for (int j = 0; j < n; j++)
            for (int i = 0; i <= n; i++) {
                if (wu[j * nu + i] == 0f) continue;
                int lc = i > 0 ? j * n + i - 1 : -1, rc = i < n ? j * n + i : -1;
                float l = lc >= 0 ? d[lc] : edgeW[j], r = rc >= 0 ? d[rc] : edgeE[j];
                move(lc, rc, (indoor(lc) || indoor(rc) ? aIn : aOut) * (l - r));
            }
        for (int j = 0; j <= n; j++)
            for (int i = 0; i < n; i++) {
                int f = j * n + i;
                if (wv[f] == 0f) continue;
                int tc = j > 0 ? f - n : -1, bc = j < n ? f : -1;
                float t = tc >= 0 ? d[tc] : edgeN[i], b = bc >= 0 ? d[bc] : edgeS[i];
                move(tc, bc, (indoor(tc) || indoor(bc) ? aIn : aOut) * (t - b));
            }
        System.arraycopy(dn, 0, d, 0, d.length);
    }

    private boolean indoor(int c) { return c >= 0 && (flags[c] & F_INDOOR) != 0; }

    private void sources(float dt) {
        float kOut = 1f - (float) Math.exp(-outdoorRefill * dt);
        float kIn = (float) Math.exp(-indoorDecay * dt);
        float kEdge = 1f - (float) Math.exp(-edgeRefill * dt);
        float wind = (float) Math.hypot(windX, windY);
        boolean still = stillDecay > 0f && wind > 0.1f;
        float invHalfWind = still ? 2f / wind : 0f, kStill = stillDecay * dt;
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                int c = j * n + i;
                int f = flags[c];
                if ((f & F_SOLID) != 0) continue;
                float x = d[c];
                if ((f & F_INDOOR) != 0) x *= kIn;
                else {
                    x += (ambient - x) * kOut;
                    if (still) {    // ar parado (abaixo da metade do vento): a névoa se desfaz
                        int fw = j * nu + i;
                        float sx = (u[fw] + u[fw + 1]) * 0.5f, sy = (v[c] + v[c + n]) * 0.5f;
                        float s = 1f - (float) Math.sqrt(sx * sx + sy * sy) * invHalfWind;
                        if (s > 0f) x *= 1f - kStill * s * s;
                    }
                }
                if (i == 0 || j == 0 || i == n - 1 || j == n - 1) {
                    float edge = i == 0 ? edgeW[j] : i == n - 1 ? edgeE[j] : j == 0 ? edgeN[i] : edgeS[i];
                    x += (edge - x) * kEdge;
                }
                d[c] = x < 0f ? 0f : (x > D_MAX ? D_MAX : x);
            }
    }

    // ---------- textura ----------

    /** RGBA8, linha j a partir de out[j*n*4]: r densidade, gb velocidade (128 ± 127·v/VEL_MAX), a flags. */
    public void writeRGBA(byte[] out) {
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                int c = j * n + i, fw = j * nu + i, o = c * 4;
                int f = flags[c] & (F_SOLID | F_TREE | F_INDOOR);
                float dens = (f & F_SOLID) != 0 ? neighborDensity(i, j) : d[c];
                out[o] = (byte) Math.round(Math.max(0f, Math.min(1f, dens)) * 255f);
                out[o + 1] = encodeVel((u[fw] + u[fw + 1]) * 0.5f);
                out[o + 2] = encodeVel((v[c] + v[c + n]) * 0.5f);
                if (openU[fw] == 0) f |= T_WALL_W;
                if (openV[c] == 0) f |= T_WALL_N;
                out[o + 3] = (byte) f;
            }
    }

    /** Célula sólida não tem densidade própria: a média dos vizinhos abertos, pra o filtro linear não abrir buraco. */
    private float neighborDensity(int i, int j) {
        float s = 0;
        int k = 0;
        int[] di = { -1, 1, 0, 0 }, dj = { 0, 0, -1, 1 };
        for (int t = 0; t < 4; t++) {
            int a = i + di[t], b = j + dj[t];
            if (a < 0 || a >= n || b < 0 || b >= n || solid(a, b)) continue;
            s += d[b * n + a];
            k++;
        }
        return k == 0 ? ambient : s / k;
    }

    private static byte encodeVel(float x) {
        float t = Math.max(-1f, Math.min(1f, x / VEL_MAX));
        return (byte) Math.round(128f + t * 127f);
    }
}
