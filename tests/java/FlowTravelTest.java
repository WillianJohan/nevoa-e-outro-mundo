import java.util.Random;

import nom.render.FlowGrid;
import nom.render.FogBanks;
import nom.render.Wind;

/** Névoa viajante (sprint 0026): bancos, inércia, vácuo, porta, explosão. Sem o jogo. */
public class FlowTravelTest {
    static final float DT = 0.05f;
    static final float VORT = 0.6f;      // o grid.vorticity do Flow
    static int passed, failed;

    public static void main(String[] args) {
        run("bancos cobrem ~70% do mundo", FlowTravelTest::banksCoverage);
        run("bancos andam com o vento", FlowTravelTest::banksMoveWithWind);
        run("banco atravessa a grade com o vento", FlowTravelTest::bankCrossesGrid);
        run("cobertura na grade fica perto de 70%", FlowTravelTest::coverageInGrid);
        run("prédio deixa vácuo atrás", FlowTravelTest::wakeBehindBuilding);
        run("buraco viaja com o vento", FlowTravelTest::holeTravels);
        run("porta que abre sopra névoa pra dentro", FlowTravelTest::doorPuff);
        run("explosão abre buraco e conserva massa", FlowTravelTest::blastOpensHole);
        run("tudo ligado não explode", FlowTravelTest::stableTravel);
        run("custo do passo viajante em 128x128", FlowTravelTest::travelCost);
        run("deslocamento dos bancos é o vento acumulado", FlowTravelTest::banksOffsetIsWindIntegral);
        run("vento é contínuo e fica na faixa", FlowTravelTest::windSmoothAndBounded);
        run("vento não se repete (sem ritmo fixo)", FlowTravelTest::windNotPeriodic);
        run("reforço de redemoinho enrola a esteira do prédio", FlowTravelTest::vorticityCurlsWake);
        run("reforço de redemoinho não explode e mantém o vácuo", FlowTravelTest::vorticityStable);
        run("reforço de redemoinho não pontilha a esteira", FlowTravelTest::vorticityNoSpeckle);
        run("dentro da casa fechada o ar fica parado", FlowTravelTest::vorticityStillIndoors);
        System.out.println("mod3 névoa viajante: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    /** Grade como o jogo liga: bancos, inércia, sem recarga, vácuo onde o ar para. */
    static FlowGrid travel(int n, FogBanks banks) {
        FlowGrid g = new FlowGrid(n);
        g.banks = banks;
        g.inertia = true;
        g.windRelax = 0.15f;
        g.outdoorRefill = 0f;
        g.stillDecay = 0.08f;
        g.reset(0, 0);
        return g;
    }

    static void banksCoverage() {
        FogBanks b = new FogBanks(7, 0.7f, 22f);
        int in = 0, total = 0;
        for (int j = 0; j < 200; j++)
            for (int i = 0; i < 200; i++) {
                float v = b.sample(i * 9.7, j * 9.3 - 500);
                check(v >= 0f && v <= 1f, "fora de [0, 1]: " + v);
                if (v > 0.5f) in++;
                total++;
            }
        float cov = in / (float) total;
        check(cov > 0.62f && cov < 0.78f, "cobertura " + cov);
    }

    static void banksMoveWithWind() {
        FogBanks b = new FogBanks(3, 0.7f, 22f);
        float[] before = new float[400];
        for (int k = 0; k < 400; k++) before[k] = b.sample((k % 20) * 4.0, (k / 20) * 4.0);
        b.advance(2f, 0f, 10f);   // 20 tiles pra leste
        double shifted = 0, still = 0;
        for (int k = 0; k < 400; k++) {
            double x = (k % 20) * 4.0, y = (k / 20) * 4.0;
            shifted += Math.abs(b.sample(x + 20, y) - before[k]);
            still += Math.abs(b.sample(x, y) - before[k]);
        }
        check(shifted / 400 < 0.08, "o desenho não foi levado junto: " + shifted / 400);
        check(still / 400 > 0.15, "o desenho ficou parado: " + still / 400);
    }

    /** Correlação entre a e b deslocado de dx em x, no miolo da grade. */
    static double corr(float[] a, float[] b, int n, int dx) {
        double sa = 0, sb = 0, saa = 0, sbb = 0, sab = 0;
        int k = 0;
        for (int j = 8; j < n - 8; j++)
            for (int i = 8; i < n - 8 - dx; i++) {
                double x = a[j * n + i], y = b[j * n + i + dx];
                sa += x; sb += y; saa += x * x; sbb += y * y; sab += x * y; k++;
            }
        double cov = sab / k - (sa / k) * (sb / k);
        double va = saa / k - (sa / k) * (sa / k), vb = sbb / k - (sb / k) * (sb / k);
        return cov / Math.sqrt(Math.max(1e-12, va * vb));
    }

    static float[] snapshot(FlowGrid g) {
        float[] s = new float[g.n * g.n];
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) s[j * g.n + i] = g.density(i, j);
        return s;
    }

    static void bankCrossesGrid() {
        FlowGrid g = travel(64, new FogBanks(11, 0.6f, 14f));
        g.windX = 2f;
        for (int s = 0; s < 300; s++) g.step(DT);
        float[] a = snapshot(g);
        for (int s = 0; s < 100; s++) g.step(DT);   // 5 s: ~10 tiles
        float[] b = snapshot(g);
        double moved = corr(a, b, 64, 10), still = corr(a, b, 64, 0);
        check(moved > 0.6, "o campo não andou junto com o vento: " + moved);
        check(moved > still + 0.2, "andou (" + moved + ") não difere de parado (" + still + ")");
    }

    static void coverageInGrid() {
        FlowGrid g = travel(64, new FogBanks(5, 0.7f, 18f));
        g.windX = 1.5f; g.windY = 0.4f;
        double cov = 0;
        int samples = 0;
        for (int s = 0; s < 1600; s++) {           // 80 s
            g.step(DT);
            if (s >= 400 && s % 100 == 0) {
                int in = 0;
                for (int j = 0; j < 64; j++) for (int i = 0; i < 64; i++) if (g.density(i, j) > 0.5f) in++;
                cov += in / 4096.0;
                samples++;
            }
        }
        cov /= samples;
        check(cov > 0.5 && cov < 0.88, "cobertura média " + cov);
    }

    static void wakeBehindBuilding() {
        FlowGrid g = travel(64, null);
        g.windX = 1.5f;
        for (int j = 28; j < 36; j++) for (int i = 24; i < 32; i++) g.setCell(i, j, FlowGrid.F_SOLID);
        for (int s = 0; s < 800; s++) g.step(DT);   // 40 s
        float behind = g.density(34, 31), up = g.density(16, 31), side = g.density(28, 22);
        check(behind < 0.6f, "sem vácuo atrás do prédio: " + behind);
        check(up > 0.9f, "a frente do prédio esvaziou: " + up);
        check(side > 0.8f, "o lado do prédio esvaziou: " + side);
    }

    static void holeTravels() {
        FlowGrid g = travel(64, null);
        g.windX = 1.5f;
        for (int s = 0; s < 200; s++) g.step(DT);
        for (int j = 31; j < 34; j++) for (int i = 19; i < 22; i++) g.setDensity(i, j, 0f);
        for (int s = 0; s < 80; s++) g.step(DT);    // 4 s: ~6 tiles
        int at = -1;
        float lo = 2f;
        for (int i = 0; i < 64; i++) if (g.density(i, 32) < lo) { lo = g.density(i, 32); at = i; }
        check(lo < 0.6f, "o buraco sumiu: " + lo);
        check(Math.abs(at - 26) <= 3, "o buraco está em x = " + at + ", queria ~26");
    }

    static FlowGrid house(float puff) {
        FlowGrid g = new FlowGrid(32);
        g.doorPuff = puff;
        g.reset(0, 0);
        for (int k = 0; k < 6; k++) {
            g.setOpenW(12, 12 + k, false); g.setOpenW(18, 12 + k, false);
            g.setOpenN(12 + k, 12, false); g.setOpenN(12 + k, 18, false);
        }
        for (int j = 12; j < 18; j++) for (int i = 12; i < 18; i++) g.setCell(i, j, FlowGrid.F_INDOOR);
        g.step(DT);
        return g;
    }

    static void doorPuff() {
        FlowGrid g = house(0.35f);
        g.setOpenW(12, 14, true);
        g.step(DT);
        float with = g.density(12, 14);
        FlowGrid h = house(0f);
        h.setOpenW(12, 14, true);
        h.step(DT);
        float without = h.density(12, 14);
        check(with > 0.2f, "a porta não soprou: " + with);
        check(without < 0.1f, "sem sopro já entrou demais: " + without);
        g.setOpenW(12, 14, false);
        g.setOpenW(12, 14, true);
        float before = g.density(13, 14);
        g.step(DT);
        check(g.density(12, 14) > 0f && g.density(13, 14) >= before, "abrir de novo não soprou");
    }

    static void blastOpensHole() {
        FlowGrid g = new FlowGrid(32);
        g.reset(0, 0);
        for (int k = 0; k < 32; k++) {
            g.setOpenW(0, k, false); g.setOpenW(32, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, 32, false);
        }
        float m0 = g.totalMass();
        g.blast(16f, 16f, 4f);
        check(g.density(16, 16) < 0.4f, "o centro não abriu: " + g.density(16, 16));
        float ring = 0;
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) ring = Math.max(ring, g.density(i, j));
        check(ring > 1.05f, "a névoa não foi empurrada pra borda: " + ring);
        check(Math.abs(g.totalMass() - m0) / m0 < 0.01f, "a explosão mudou a massa");
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) check(g.density(i, j) <= 1.5f, "passou do teto");
    }

    static void stableTravel() {
        FlowGrid g = travel(32, new FogBanks(2, 0.7f, 10f));
        g.doorPuff = 0.35f;
        g.windX = 30f;
        Random r = new Random(4);
        for (int s = 0; s < 300; s++) {
            g.impulse(r.nextFloat() * 32, r.nextFloat() * 32, r.nextFloat() * 100 - 50, r.nextFloat() * 100 - 50, 3f);
            if (s % 20 == 0) g.blast(r.nextFloat() * 32, r.nextFloat() * 32, 1f + r.nextFloat() * 10);
            if (s % 7 == 0) g.setOpenW(r.nextInt(33), r.nextInt(32), r.nextBoolean());
            if (s % 50 == 0) g.scroll(g.x0 + r.nextInt(7) - 3, g.y0 + r.nextInt(7) - 3);
            g.step(DT);
        }
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) {
            float d = g.density(i, j);
            check(d >= 0f && d <= 1.5f && !Float.isNaN(d), "densidade fora de [0, 1.5]: " + d);
            check(!Float.isNaN(g.faceU(i, j)) && !Float.isNaN(g.faceV(i, j)), "velocidade NaN");
        }
    }

    static void travelCost() {
        FlowGrid g = travel(128, new FogBanks(9, 0.7f, 22f));
        g.doorPuff = 0.35f;
        g.vorticity = VORT;
        g.windX = 1.4f; g.windY = 0.5f;
        Random r = new Random(5);
        for (int k = 0; k < 40; k++) {
            int bx = 4 + r.nextInt(112), by = 4 + r.nextInt(112), s = 4 + r.nextInt(6);
            if (bx + s >= 128 || by + s >= 128) continue;
            for (int q = 0; q < s; q++) {
                g.setOpenW(bx, by + q, false); g.setOpenW(bx + s, by + q, false);
                g.setOpenN(bx + q, by, false); g.setOpenN(bx + q, by + s, false);
            }
            g.setOpenW(bx, by + 1, true);
            for (int j = by; j < by + s; j++) for (int i = bx; i < bx + s; i++) g.setCell(i, j, FlowGrid.F_INDOOR);
        }
        for (int k = 0; k < 500; k++) g.setCell(r.nextInt(128), r.nextInt(128), FlowGrid.F_SOLID | FlowGrid.F_TREE);
        for (int s = 0; s < 150; s++) g.step(DT);
        int steps = 200;
        long t0 = System.nanoTime();
        for (int s = 0; s < steps; s++) {
            for (int c = 0; c < 8; c++) g.impulse(60 + c, 60 + (s % 10), 1.5f, 0.5f, 1.6f);
            g.step(DT);
        }
        double ms = (System.nanoTime() - t0) / 1e6 / steps;
        System.out.printf("  passo viajante 128x128: %.3f ms (meta < 1,5 ms)%n", ms);
        check(ms < 3.0, "passo caro demais: " + ms + " ms");
    }

    /** O shader anda o ruído por esse deslocamento: tem que ser o mesmo que leva os bancos. */
    static void banksOffsetIsWindIntegral() {
        FogBanks b = new FogBanks(5, 0.7f, 22f);
        for (int s = 0; s < 100; s++) b.advance(1.5f, -0.5f, DT);
        for (int s = 0; s < 100; s++) b.advance(-0.4f, 2f, DT);
        check(Math.abs(b.offsetX() - (7.5 - 2.0)) < 1e-6, "offsetX " + b.offsetX());
        check(Math.abs(b.offsetY() - (-2.5 + 10.0)) < 1e-6, "offsetY " + b.offsetY());
    }

    static void windSmoothAndBounded() {
        Wind w = new Wind(11);
        float intensity = 0.5f, base = 1f + 1.2f * intensity;
        float lo = 99f, hi = 0f, prevS = -1f, prevA = 0f, maxDs = 0f, maxDa = 0f;
        for (int s = 0; s <= 12000; s++) {
            w.at(0.3f, intensity, s * DT);
            float sp = (float) Math.hypot(w.x, w.y), ang = (float) Math.atan2(w.y, w.x);
            lo = Math.min(lo, sp);
            hi = Math.max(hi, sp);
            if (prevS >= 0f) {
                maxDs = Math.max(maxDs, Math.abs(sp - prevS));
                maxDa = Math.max(maxDa, Math.abs(ang - prevA));
            }
            prevS = sp;
            prevA = ang;
        }
        check(lo >= 0.5f * base && hi <= 1.5f * base, "fora da faixa: " + lo + ".." + hi);
        check(lo < 0.85f * base && hi > 1.15f * base, "rajada fraca demais: " + lo + ".." + hi);
        check(maxDs < 0.05f && maxDa < 0.03f, "aos trancos: dv=" + maxDs + " da=" + maxDa);
    }

    /** Seno tem ritmo: a velocidade num instante repete a de um período antes. Ruído não. */
    static void windNotPeriodic() {
        Wind w = new Wind(23);
        int n = 1600;                       // 400 s, de 0,25 em 0,25 s
        float[] sp = new float[n];
        for (int k = 0; k < n; k++) {
            w.at(0f, 0.5f, k * 0.25f);
            sp[k] = (float) Math.hypot(w.x, w.y);
        }
        double worst = -1;
        int worstLag = 0;
        for (int lag = 8; lag <= 240; lag++) {     // 2 s a 60 s
            double c = corr(sp, lag);
            if (c > worst) { worst = c; worstLag = lag; }
        }
        check(worst < 0.8, "repete com " + worstLag * 0.25f + " s (correlação " + worst + ")");
    }

    /** Escala do jogo (Flow.SCALE_DEFAULT): os testes de redemoinho rodam nela. */
    static final int GAME_SCALE = 2;

    /** Prédio no meio do vento, um pouco de lado pra esteira não ficar simétrica. */
    static FlowGrid windyBlock(float vorticity, int scale) {
        FlowGrid g = travelScaled(64, scale);
        g.vorticity = vorticity;
        g.windX = 1.5f;
        g.windY = 0.12f;
        for (int tj = 28; tj < 36; tj++) for (int ti = 24; ti < 32; ti++) g.setTile(ti, tj, FlowGrid.F_SOLID);
        return g;
    }

    /** Casa como o jogo manda: interior com parede fina em volta (face fechada), nada sólido. */
    static FlowGrid windyHouse(float vorticity, int scale) {
        FlowGrid g = travelScaled(64, scale);
        g.vorticity = vorticity;
        g.windX = 1.5f;
        g.windY = 0.12f;
        for (int tj = 28; tj < 36; tj++) {
            for (int ti = 24; ti < 32; ti++) g.setTile(ti, tj, FlowGrid.F_INDOOR);
            g.setTileOpenW(24, tj, false);
            g.setTileOpenW(32, tj, false);
        }
        for (int ti = 24; ti < 32; ti++) { g.setTileOpenN(ti, 28, false); g.setTileOpenN(ti, 36, false); }
        return g;
    }

    static FlowGrid travelScaled(int tiles, int scale) {
        FlowGrid g = new FlowGrid(tiles, scale);
        g.inertia = true;
        g.windRelax = 0.15f;
        g.outdoorRefill = 0f;
        g.stillDecay = 0.08f;
        g.reset(0, 0);
        return g;
    }

    /** Média da densidade no tile. */
    static float tileDensity(FlowGrid g, int ti, int tj) {
        float s = 0;
        for (int b = 0; b < g.scale; b++)
            for (int a = 0; a < g.scale; a++) s += g.density(ti * g.scale + a, tj * g.scale + b);
        return s / (g.scale * g.scale);
    }

    /** Velocidade média do tile (x, y), pelas faces de dentro e da borda. */
    static float tileU(FlowGrid g, int ti, int tj) {
        float s = 0;
        int k = g.scale;
        for (int b = 0; b < k; b++) for (int a = 0; a <= k; a++) s += g.faceU(ti * k + a, tj * k + b);
        return s / (k * (k + 1));
    }

    static float tileV(FlowGrid g, int ti, int tj) {
        float s = 0;
        int k = g.scale;
        for (int b = 0; b <= k; b++) for (int a = 0; a < k; a++) s += g.faceV(ti * k + a, tj * k + b);
        return s / (k * (k + 1));
    }

    /** Giro na escala de tile atrás do prédio: soma de |rotacional| da velocidade média por tile. */
    static double wakeSwirl(FlowGrid g) {
        double s = 0;
        for (int tj = 20; tj <= 44; tj++)
            for (int ti = 33; ti <= 60; ti++)
                s += Math.abs((tileV(g, ti, tj) - tileV(g, ti - 1, tj)) - (tileU(g, ti, tj) - tileU(g, ti, tj - 1)));
        return s;
    }

    /** Ruído na escala da célula: cada face menos a média das quatro vizinhas, na esteira, por tile². */
    static double gridNoise(FlowGrid g) {
        double s = 0;
        int k = g.scale;
        for (int j = 20 * k; j <= 44 * k; j++)
            for (int i = 33 * k; i <= 60 * k; i++) {
                s += Math.abs(g.faceU(i, j) - 0.25f * (g.faceU(i - 1, j) + g.faceU(i + 1, j) + g.faceU(i, j - 1) + g.faceU(i, j + 1)));
                s += Math.abs(g.faceV(i, j) - 0.25f * (g.faceV(i - 1, j) + g.faceV(i + 1, j) + g.faceV(i, j - 1) + g.faceV(i, j + 1)));
            }
        return s / (k * k);
    }

    /** Maior |velocidade| nas faces de dentro da casa de windyHouse. */
    static float indoorSpeed(FlowGrid g) {
        int k = g.scale;
        float m = 0f;
        for (int j = 28 * k; j < 36 * k; j++)
            for (int i = 24 * k + 1; i < 32 * k; i++) m = Math.max(m, Math.abs(g.faceU(i, j)));
        for (int j = 28 * k + 1; j < 36 * k; j++)
            for (int i = 24 * k; i < 32 * k; i++) m = Math.max(m, Math.abs(g.faceV(i, j)));
        return m;
    }

    static void vorticityCurlsWake() {
        FlowGrid plain = windyBlock(0f, GAME_SCALE), curled = windyBlock(VORT, GAME_SCALE);
        double a = 0, b = 0;
        for (int s = 0; s < 600; s++) {
            plain.step(DT);
            curled.step(DT);
            if (s >= 400) { a += wakeSwirl(plain); b += wakeSwirl(curled); }
        }
        check(b > 1.3 * a, "a esteira não enrolou: sem " + a + ", com " + b);
    }

    static void vorticityStable() {
        FlowGrid g = windyBlock(VORT, GAME_SCALE);
        float maxV = 0f;
        for (int s = 0; s < 2000; s++) g.step(DT);  // 100 s
        for (int j = 0; j < g.n; j++)
            for (int i = 0; i < g.n; i++) {
                float x = Math.abs(g.faceU(i, j)) + Math.abs(g.faceV(i, j));
                check(!Float.isNaN(x) && !Float.isNaN(g.density(i, j)), "NaN em " + i + "," + j);
                maxV = Math.max(maxV, x);
            }
        check(maxV < 8f, "velocidade disparou: " + maxV);
        float behind = tileDensity(g, 34, 31), up = tileDensity(g, 16, 31);
        check(behind < 0.7f, "o redemoinho apagou o vácuo atrás do prédio: " + behind);
        check(up > 0.85f, "a frente do prédio esvaziou: " + up);
    }

    /**
     * O reforço pode criar onda (giro na escala de tile), não pontilhado: o ruído de célula não cresce
     * mais que o giro. Sem a média do giro, na escala 2 o ruído subia 3,3x pra 1,5x de giro.
     */
    static void vorticityNoSpeckle() {
        FlowGrid plain = windyHouse(0f, GAME_SCALE), curled = windyHouse(VORT, GAME_SCALE);
        // régua da 0030 (aprovada no jogo): com o chute, a referência fica limpa demais e deixa de ser régua
        plain.warmPressure = false;
        double na = 0, nb = 0, wa = 0, wb = 0;
        for (int s = 0; s < 600; s++) {
            plain.step(DT);
            curled.step(DT);
            if (s >= 400) {
                na += gridNoise(plain); nb += gridNoise(curled);
                wa += wakeSwirl(plain); wb += wakeSwirl(curled);
            }
        }
        double noise = nb / na, swirl = wb / wa;
        check(noise < 1.15 * swirl, "o redemoinho pontilhou a esteira: ruído " + noise + "x, giro " + swirl + "x");
    }

    static void vorticityStillIndoors() {
        FlowGrid g = windyHouse(VORT, GAME_SCALE);
        float maxV = 0f;
        for (int s = 0; s < 600; s++) {
            g.step(DT);
            if (s >= 400) maxV = Math.max(maxV, indoorSpeed(g));
        }
        check(maxV < 0.2f, "o ar dentro da casa fechada mexe: " + maxV);
    }

    static double corr(float[] a, int lag) {
        int m = a.length - lag;
        double sa = 0, sb = 0;
        for (int k = 0; k < m; k++) { sa += a[k]; sb += a[k + lag]; }
        sa /= m;
        sb /= m;
        double ab = 0, aa = 0, bb = 0;
        for (int k = 0; k < m; k++) {
            double x = a[k] - sa, y = a[k + lag] - sb;
            ab += x * y;
            aa += x * x;
            bb += y * y;
        }
        return ab / Math.sqrt(aa * bb + 1e-12);
    }
}
