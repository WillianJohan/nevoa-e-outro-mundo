package nom.render;

import static org.lwjgl.opengl.GL33C.*;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.IdentityHashMap;
import java.util.List;

import org.lwjgl.BufferUtils;

import zombie.GameTime;
import zombie.WorldSoundManager;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.IsoMovingObject;
import zombie.iso.SpriteDetails.IsoFlagType;
import zombie.iso.weather.ClimateManager;
import zombie.vehicles.BaseVehicle;

/**
 * Névoa fluida: liga o FlowGrid ao jogo.
 *
 * Thread principal (update, chamado do RenderContext.onWorldEnd): só lê o jogo. Rola a origem com o
 * personagem da câmera, monta a máscara de obstáculos aos poucos, lê o vento do clima, quem anda, carro e
 * os sons altos, e empilha tudo como entrada (Input) pra thread da simulação.
 * Thread da simulação (sprint 0030, "NOM-fluido"): aplica a entrada na grade, avança a 20 Hz e publica
 * a textura sob trava. A grade é só dela; a thread principal nunca toca nela.
 * Thread de render (prepare): sobe a versão nova e prende na unidade 6.
 * Erro em qualquer uma desliga só o fluido; a névoa segue com densidade 1.
 *
 * A névoa viaja (sprint 0026): entra em bancos pelo lado de onde vem o vento, atravessa e sai pelo
 * outro; a rua não é recarregada, então rastro e vácuo atrás de prédio duram e andam com ela.
 * Resolução (sprint 0030): NOMRender_setParam(9, s), s células por tile (1 a 3); trocar recria a grade.
 */
final class Flow {
    static final int TILES = 128;
    static final int SCALE_MAX = 3;
    static final float STEP = 1f / 20f;
    static final int MAX_PENDING_STEPS = 4; // a simulação atrasou mais que isso: o resto é jogado fora
    static final int ROWS_PER_FRAME = 8;   // máscara inteira a cada 16 quadros
    static final float MOVER_RANGE = 40f;
    static final int MAX_MOVERS = 48;
    static final float MOVER_RADIUS = 1.6f;
    static final float VEHICLE_RADIUS = 3f;
    static final int LOUD_RADIUS = 20;     // som com raio de pelo menos isso (tiro, explosão) empurra a névoa
    static final int MAX_BLASTS = 8;
    static final float STILL_DECAY = 0.08f;   // 1/s, com o vácuo ligado (o da 0026)
    // foco de vento (sprint 0033, PARAM_WIND_SOURCE): sorteado na borda de subida, sopra constante até desligar
    static final float SOURCE_MIN_DIST = WindSource.MIN_DIST, SOURCE_MAX_DIST = WindSource.MAX_DIST;
    static final float SOURCE_SPEED = WindSource.SPEED;       // tiles/s
    static final float SOURCE_RADIUS = WindSource.RADIUS;     // tiles
    static float sourceX, sourceY, sourceVX, sourceVY;        // só a thread principal escreve
    static boolean sourceOn;
    private static final java.util.Random sourceRandom = new java.util.Random();
    static final int PARAM_ON = 4;         // NOMRender_setParam(4, 0) desliga, (4, 1) liga
    static final int UNIT = 6;
    static final int W_OPEN = 1 << 8, N_OPEN = 1 << 9;   // na máscara empilhada, junto das flags
    static final int W_FENCE = 1 << 10, N_FENCE = 1 << 11; // cerca baixa na borda (aberta, com altura)

    private static final Wind gusts = new Wind((int) System.nanoTime() ^ 0x5bd1e995);
    static final float CALM_X = 0.35f, CALM_Y = 0.15f;   // tiles/s, com a simulação desligada
    // quanto o vento já levou a névoa, contínuo a cada quadro: espelho do deslocamento dos bancos
    // (a thread principal soma o mesmo vento·STEP de cada passo que manda) + a fração de passo que falta
    private static volatile double driftX, driftY;
    private static volatile float driftWX = CALM_X, driftWY = CALM_Y;
    private static double bankX, bankY;
    private static volatile boolean dead;
    private static boolean running;
    private static int z = Integer.MIN_VALUE, maskRow, frameStamp, scale, x0, y0;
    private static long lastNanos, stepsSent;
    private static float acc, simTime, camX, camY, windX, windY;
    private static volatile float sentX, sentY, sentOn = -1f;   // último uFlow mandado ao shader

    // quem anda (personagem ou carro): posição anterior (x, y, segundos, quadro em que foi visto)
    private static final IdentityHashMap<IsoMovingObject, float[]> prev = new IdentityHashMap<>();
    private static final float[] movers = new float[MAX_MOVERS * 5];   // x, y, vx, vy, raio
    private static int moverCount;
    // sons altos: os vistos no quadro anterior não explodem de novo
    private static HashSet<Long> soundsSeen = new HashSet<>(), soundsNow = new HashSet<>();
    private static final float[] blasts = new float[MAX_BLASTS * 3];  // x, y, raio
    private static int blastCount;
    private static final Sonar sonar = new Sonar();   // anéis do sonar do Estalador (sprint 0037)
    private static long statFrames, statMaskNanos;

    /** O que a thread principal leu do jogo desde a última vez que a simulação pegou. */
    static final class Input {
        boolean reset, scroll;
        int resetScale, rx0, ry0, sx0, sy0;
        int[] mask = new int[3 * 4096];   // x, y (tiles do mundo), flags | W_OPEN | N_OPEN
        int maskCount;
        final float[] movers = new float[MAX_MOVERS * 5];
        int moverCount;
        final float[] blasts = new float[MAX_BLASTS * 3];
        int blastCount;
        final float[] winds = new float[MAX_PENDING_STEPS * 2];
        int steps;
        // frente de cada anel do sonar em cada passo: x, y, r0, r1 (Sonar.bands)
        final float[] sonars = new float[MAX_PENDING_STEPS * Sonar.MAX_RINGS * 4];
        final int[] sonarCount = new int[MAX_PENDING_STEPS];
        float stillDecay;   // sorvedouro do ar parado: o vácuo atrás dos prédios (PARAM_VACUUM)
        boolean sourceOn;   // foco de vento ligado (PARAM_WIND_SOURCE); posição e sopro em coordenadas de mundo
        float sourceX, sourceY, sourceVX, sourceVY;

        boolean hasWork() { return reset || scroll || maskCount > 0 || steps > 0; }

        void clear() { reset = scroll = false; maskCount = moverCount = blastCount = steps = 0; }

        void addMask(int x, int y, int code) {
            if (maskCount + 3 > mask.length) mask = Arrays.copyOf(mask, mask.length * 2);
            mask[maskCount++] = x;
            mask[maskCount++] = y;
            mask[maskCount++] = code;
        }
    }

    private static final Object IN_LOCK = new Object();
    private static Input pending = new Input(), work = new Input();
    private static Thread worker;

    // thread da simulação
    private static FlowGrid grid;
    private static FogBanks banks;
    private static volatile long statSteps, statStepNanos;
    private static volatile String simInfo = "sem grade";

    // publicado: simulação -> render
    private static final Object LOCK = new Object();
    private static byte[] pub = new byte[0];
    private static int pubX0, pubY0, pubN;
    private static volatile int pubVersion;
    private static volatile boolean pubOn;

    // render thread
    private static int tex, texVersion = -1, texX0, texY0, texN;
    private static ByteBuffer upload;

    private Flow() {}

    /** Grade como o jogo liga, na escala pedida. Os bancos são os mesmos em toda grade (o shader anda junto). */
    static FlowGrid newGrid(int scale, FogBanks banks) {
        FlowGrid g = new FlowGrid(TILES, scale);
        g.banks = banks;
        g.inertia = true;
        g.windRelax = 0.15f;
        g.outdoorRefill = 0f;
        g.stillDecay = 0f;              // a thread principal manda o do PARAM_VACUUM a cada passo
        g.doorPuff = 0.35f;
        g.vorticity = 0.6f;             // por tile; o dobro fecha o vácuo atrás do prédio
        return g;
    }

    static int requestedScale() {
        int s = Math.round(RenderContext.luaParams[RenderContext.PARAM_FLOW_RES]);
        return s < 1 ? 1 : (s > SCALE_MAX ? SCALE_MAX : s);
    }

    // ---------- main thread ----------

    static void update(IsoCell cell, IsoCamera.FrameState fs) {
        if (dead) return;
        try {
            long now = System.nanoTime();
            float dt = lastNanos == 0 ? 0f : Math.min(0.25f, (now - lastNanos) / 1e9f);
            lastNanos = now;
            if (RenderContext.luaParams[PARAM_ON] < 0.5f) {
                running = false;
                pubOn = false;
                if (!GameTime.isGamePaused()) {
                    driftX += CALM_X * dt;
                    driftY += CALM_Y * dt;
                }
                driftWX = CALM_X;
                driftWY = CALM_Y;
                return;
            }
            if (worker == null) startWorker();
            frameStamp++;

            float cx = fs.camCharacterX, cy = fs.camCharacterY;
            camX = cx;
            camY = cy;
            int cz = (int) Math.floor(fs.camCharacterZ);
            int nx0 = (int) Math.floor(cx) - TILES / 2, ny0 = (int) Math.floor(cy) - TILES / 2;
            int want = requestedScale();
            long m0 = System.nanoTime();
            synchronized (IN_LOCK) {
                Input in = pending;
                if (!running || cz != z || want != scale) {
                    // começo, outro andar ou outra resolução: grade nova com a máscara inteira de uma
                    // vez (um soluço só), senão o interior dos prédios começaria cheio de névoa
                    z = cz;
                    scale = want;
                    x0 = nx0;
                    y0 = ny0;
                    // passos na fila ficam: o espelho dos bancos (bankX/Y) já contou com eles
                    in.scroll = false;
                    in.maskCount = 0;
                    in.reset = true;
                    in.resetScale = want;
                    in.rx0 = nx0;
                    in.ry0 = ny0;
                    for (int j = 0; j < TILES; j++) buildRow(cell, in, j);
                    maskRow = 0;
                    acc = 0f;
                    prev.clear();
                    sonar.clear();
                    running = true;
                } else if (nx0 != x0 || ny0 != y0) {
                    int dx = nx0 - x0, dy = ny0 - y0;
                    x0 = nx0;
                    y0 = ny0;
                    in.scroll = true;
                    in.sx0 = nx0;
                    in.sy0 = ny0;
                    if (Math.abs(dx) >= TILES || Math.abs(dy) >= TILES) {
                        for (int j = 0; j < TILES; j++) buildRow(cell, in, j);
                    } else {            // só a faixa que entrou
                        for (int k = 0; k < Math.abs(dx); k++) buildColumn(cell, in, dx > 0 ? TILES - 1 - k : k);
                        for (int k = 0; k < Math.abs(dy); k++) buildRow(cell, in, dy > 0 ? TILES - 1 - k : k);
                    }
                }
                float vac = RenderContext.luaParams[RenderContext.PARAM_VACUUM];
                in.stillDecay = STILL_DECAY * (vac < 0f ? 0f : (vac > 1f ? 1f : vac));
                // foco de vento: na borda de subida do parâmetro sorteia outro; desligado, para de soprar
                boolean srcWant = RenderContext.luaParams[RenderContext.PARAM_WIND_SOURCE] >= 0.5f;
                if (srcWant && !sourceOn) pickSource(cx, cy, sourceRandom);
                sourceOn = srcWant;
                in.sourceOn = sourceOn;
                in.sourceX = sourceX;
                in.sourceY = sourceY;
                in.sourceVX = sourceVX;
                in.sourceVY = sourceVY;
                for (int r = 0; r < ROWS_PER_FRAME; r++) {
                    buildRow(cell, in, maskRow);
                    maskRow = (maskRow + 1) % TILES;
                }
                statMaskNanos += System.nanoTime() - m0;
                statFrames++;

                if (!GameTime.isGamePaused()) {
                    acc += dt;
                    if (acc >= STEP) {
                        collectMovers(cell, cx, cy, cz, now);
                        collectSounds(cz);
                        System.arraycopy(movers, 0, in.movers, 0, moverCount * 5);
                        in.moverCount = moverCount;
                        for (int k = 0; k < blastCount * 3 && in.blastCount < MAX_BLASTS; k += 3) {
                            System.arraycopy(blasts, k, in.blasts, in.blastCount * 3, 3);
                            in.blastCount++;
                        }
                        blastCount = 0;
                    }
                    int steps = 0;
                    while (acc >= STEP && steps < 2) {
                        simTime += STEP;
                        wind();
                        if (in.steps < MAX_PENDING_STEPS) {
                            in.winds[in.steps * 2] = windX;
                            in.winds[in.steps * 2 + 1] = windY;
                            in.sonarCount[in.steps] = sonar.bands(STEP, in.sonars, in.steps * Sonar.MAX_RINGS * 4);
                            in.steps++;
                            bankX += windX * STEP;      // a mesma conta do FogBanks.advance
                            bankY += windY * STEP;
                            if (++stepsSent % 600 == 0) logStats();
                        } else {
                            sonar.bands(STEP, null, 0);   // passo jogado fora: o anel anda igual
                        }
                        acc -= STEP;
                        steps++;
                    }
                    if (acc > STEP) acc = 0f;   // quadro muito longo: não tenta alcançar
                }
                if (in.hasWork()) IN_LOCK.notifyAll();
            }
            driftX = bankX + windX * acc;
            driftY = bankY + windY * acc;
            driftWX = windX;
            driftWY = windY;
        } catch (Throwable t) {
            die("ERRO no fluido, simulação desligada (a névoa segue sem ela): ", t);
        }
    }

    /** Sorteia o foco de vento perto de (px, py) e loga. O sorteio em si é do WindSource (puro, testável). */
    public static void pickSource(float px, float py, java.util.Random r) {
        WindSource w = WindSource.pick(px, py, r);
        sourceX = w.x;
        sourceY = w.y;
        sourceVX = w.vx;
        sourceVY = w.vy;
        RenderContext.log(String.format("vento: foco em (%.1f,%.1f) soprando (%.2f,%.2f)", sourceX, sourceY, sourceVX, sourceVY));
    }

    /**
     * Anel do sonar do Estalador (NOMRender_sonar, thread principal, a mesma do update). false: a
     * tela desenha (fluido desligado ou morto, sem névoa, outro andar, perto da borda da grade, cheio).
     */
    static boolean addSonar(float wx, float wy, int wz) {
        if (dead || !running || RenderContext.luaParams[PARAM_ON] < 0.5f || wz != z) return false;
        if (ClimateManager.getInstance().getFogIntensity() < 0.05f) return false;
        float reach = TILES / 2f - Sonar.RANGE - Sonar.AHEAD;
        if (Math.abs(wx - camX) > reach || Math.abs(wy - camY) > reach) return false;
        return sonar.add(wx, wy);
    }

    private static void die(String why, Throwable t) {
        dead = true;
        running = false;
        pubOn = false;
        RenderContext.log(why + t);
        t.printStackTrace();
    }

    private static void startWorker() {
        worker = new Thread(Flow::workLoop, "NOM-fluido");
        worker.setDaemon(true);
        worker.setPriority(Thread.NORM_PRIORITY - 1);
        worker.start();
        RenderContext.log("fluido: thread da simulação iniciada");
    }

    private static void buildRow(IsoCell cell, Input in, int j) {
        for (int i = 0; i < TILES; i++) buildCell(cell, in, i, j);
    }

    private static void buildColumn(IsoCell cell, Input in, int i) {
        for (int j = 0; j < TILES; j++) buildCell(cell, in, i, j);
    }

    /**
     * Um square vira flags + as bordas oeste e norte. isBlockedTo = parede (collideN/W, sem janela),
     * janela fechada ou barricada, porta fechada ou barricada, escada (bytecode, ver o plan.md da 0024).
     * Cerca baixa (HoppableW/N, pz-api-notes §20) é a exceção: borda aberta com altura, a névoa passa
     * por cima. Square não carregado é ar aberto.
     */
    private static void buildCell(IsoCell cell, Input in, int i, int j) {
        int x = x0 + i, y = y0 + j;
        IsoGridSquare sq = cell.getGridSquare(x, y, z);
        int f = 0;
        boolean openW = true, openN = true, fenceW = false, fenceN = false;
        if (sq != null) {
            if (sq.isSolid()) f |= FlowGrid.F_SOLID;
            if (sq.HasTree()) f |= FlowGrid.F_TREE;
            if (!sq.isOutside()) f |= FlowGrid.F_INDOOR;
            if ((f & FlowGrid.F_SOLID) == 0 && sq.getVehicleContainer() != null) f |= FlowGrid.F_LOW;
            fenceW = sq.has(IsoFlagType.HoppableW);
            fenceN = sq.has(IsoFlagType.HoppableN);
            IsoGridSquare w = cell.getGridSquare(x - 1, y, z);
            if (!fenceW && w != null && sq.isBlockedTo(w)) openW = false;
            IsoGridSquare n = cell.getGridSquare(x, y - 1, z);
            if (!fenceN && n != null && sq.isBlockedTo(n)) openN = false;
        }
        in.addMask(x, y, f | (openW ? W_OPEN : 0) | (openN ? N_OPEN : 0) | (fenceW ? W_FENCE : 0) | (fenceN ? N_FENCE : 0));
    }

    /**
     * Vento do clima, com rajadas e a direção vagando (Wind): forte o bastante pra ver a névoa
     * passar (um banco atravessa a tela em 20 a 40 s). A convenção do ângulo não importa pra névoa.
     */
    private static void wind() {
        ClimateManager cm = ClimateManager.getInstance();
        gusts.at(cm.getWindAngleRadians(), cm.getWindIntensity(), simTime);
        windX = gusts.x;
        windY = gusts.y;
    }

    /** Jogadores locais, zumbis e carros no mesmo andar, a até MOVER_RANGE: velocidade pela posição anterior. */
    private static void collectMovers(IsoCell cell, float cx, float cy, int cz, long now) {
        float t = (now - RenderContext.t0) / 1e9f;
        moverCount = 0;
        for (IsoPlayer p : IsoPlayer.players) {
            if (p != null) mover(p, cx, cy, cz, t, MOVER_RADIUS, 225f);
        }
        for (BaseVehicle v : cell.getVehicles()) {
            if (v != null) mover(v, cx, cy, cz, t, VEHICLE_RADIUS, 1600f);
        }
        ArrayList<IsoZombie> zs = cell.getZombieList();
        for (int i = 0; i < zs.size() && moverCount < MAX_MOVERS; i++) mover(zs.get(i), cx, cy, cz, t, MOVER_RADIUS, 225f);
        final int stamp = frameStamp;
        prev.values().removeIf(e -> (int) e[3] != stamp);
    }

    /** maxSpeed2: acima disso (tiles²/s²) foi teleporte, não movimento. */
    private static void mover(IsoMovingObject o, float cx, float cy, int cz, float t, float radius, float maxSpeed2) {
        float x = o.getX(), y = o.getY();
        if ((int) Math.floor(o.getZ()) != cz) return;
        float dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > MOVER_RANGE * MOVER_RANGE) return;
        float[] e = prev.get(o);
        if (e == null) { prev.put(o, new float[] { x, y, t, frameStamp }); return; }
        float dt = t - e[2];
        float vx = dt > 1e-3f ? (x - e[0]) / dt : 0f, vy = dt > 1e-3f ? (y - e[1]) / dt : 0f;
        e[0] = x; e[1] = y; e[2] = t; e[3] = frameStamp;
        float sp2 = vx * vx + vy * vy;
        if (sp2 < 0.09f || sp2 > maxSpeed2 || moverCount >= MAX_MOVERS) return; // parado, ou teleportou
        int k = moverCount++ * 5;
        movers[k] = x; movers[k + 1] = y; movers[k + 2] = vx; movers[k + 3] = vy; movers[k + 4] = radius;
    }

    /**
     * Som alto novo no andar (tiro, explosão, vidro quebrando) vira explosão na névoa, com raio pelo
     * alcance do som. Zumbi, carro e som que se repete (alarme) ficam de fora.
     */
    private static void collectSounds(int cz) {
        List<WorldSoundManager.WorldSound> list = WorldSoundManager.instance.soundList;
        soundsNow.clear();
        for (int i = 0; i < list.size(); i++) {
            WorldSoundManager.WorldSound s = list.get(i);
            if (s == null || s.sourceIsZombie || s.repeating || s.sourceIsVehicle() || s.radius < LOUD_RADIUS || s.z != cz) continue;
            long key = ((long) s.x << 40) ^ ((long) s.y << 16) ^ (s.radius * 31L) ^ System.identityHashCode(s);
            soundsNow.add(key);
            if (soundsSeen.contains(key) || blastCount >= MAX_BLASTS) continue;
            int k = blastCount++ * 3;
            blasts[k] = s.x + 0.5f;
            blasts[k + 1] = s.y + 0.5f;
            blasts[k + 2] = Math.max(2.5f, Math.min(9f, s.radius / 10f));
        }
        HashSet<Long> t = soundsSeen;
        soundsSeen = soundsNow;
        soundsNow = t;
    }

    private static void logStats() {
        long n = Math.max(1, statSteps);
        RenderContext.log(String.format("fluido: passo %.3f ms (thread da simulação), máscara %.3f ms/quadro",
                statStepNanos / 1e6 / n, statMaskNanos / 1e6 / Math.max(1, statFrames)));
        RenderContext.log(info());
        statSteps = 0;
        statStepNanos = 0;
        statMaskNanos = 0;
        statFrames = 0;
    }

    /** Estado da simulação: o que a thread principal mandou, o que a simulação achou e o que o shader recebeu. */
    static String info() {
        return String.format("fluido: %s param4=%.0f escala=%d vento=(%.2f,%.2f) andar=%d origem=(%d,%d) %s"
                        + " publicada=%d enviada=%d shader uFlow=(%.0f,%.0f,%.0f) tex0=(%d,%d) tex=%d",
                dead ? "MORTO" : running ? "rodando" : "parado", RenderContext.luaParams[PARAM_ON], scale, windX, windY, z,
                x0, y0, simInfo, pubVersion, texVersion, sentX, sentY, sentOn, texX0, texY0, texN);
    }

    // ---------- thread da simulação ----------

    private static void workLoop() {
        try {
            while (!dead) {
                synchronized (IN_LOCK) {
                    while (!pending.hasWork()) IN_LOCK.wait();
                    Input t = pending;
                    pending = work;
                    work = t;
                }
                apply(work);
                work.clear();
            }
        } catch (Throwable t) {
            die("ERRO na thread do fluido, simulação desligada (a névoa segue sem ela): ", t);
        }
    }

    /** Aplica a entrada na ordem em que a thread principal leu: grade nova, rolagem, máscara, passos. */
    private static void apply(Input in) {
        if (in.reset) {
            if (banks == null) banks = new FogBanks((int) System.nanoTime(), 0.7f, 22f);
            if (grid == null || grid.scale != in.resetScale) grid = newGrid(in.resetScale, banks);
            grid.reset(in.rx0, in.ry0);
        }
        if (grid == null) return;
        if (in.scroll) grid.scroll(in.sx0, in.sy0);
        grid.stillDecay = in.stillDecay;
        for (int k = 0; k < in.maskCount; k += 3) {
            int ti = in.mask[k] - grid.x0, tj = in.mask[k + 1] - grid.y0, code = in.mask[k + 2];
            if (ti < 0 || tj < 0 || ti >= TILES || tj >= TILES) continue;
            grid.setTile(ti, tj, code & 0xff);
            grid.setTileOpenW(ti, tj, (code & W_OPEN) != 0);
            grid.setTileOpenN(ti, tj, (code & N_OPEN) != 0);
            grid.setTileFenceW(ti, tj, (code & W_FENCE) != 0);
            grid.setTileFenceN(ti, tj, (code & N_FENCE) != 0);
        }
        for (int s = 0; s < in.steps; s++) {
            long s0 = System.nanoTime();
            grid.windX = in.winds[s * 2];
            grid.windY = in.winds[s * 2 + 1];
            for (int k = 0; k < in.moverCount; k++) {
                int o = k * 5;
                grid.impulse(in.movers[o], in.movers[o + 1], in.movers[o + 2], in.movers[o + 3], in.movers[o + 4]);
            }
            if (in.sourceOn) grid.impulse(in.sourceX, in.sourceY, in.sourceVX, in.sourceVY, SOURCE_RADIUS);
            if (s == 0)
                for (int k = 0; k < in.blastCount; k++) grid.blast(in.blasts[k * 3], in.blasts[k * 3 + 1], in.blasts[k * 3 + 2]);
            for (int k = 0, o = s * Sonar.MAX_RINGS * 4; k < in.sonarCount[s]; k++, o += 4)
                grid.sonar(in.sonars[o], in.sonars[o + 1], in.sonars[o + 2], in.sonars[o + 3]);
            grid.step(STEP);
            statStepNanos += System.nanoTime() - s0;
            statSteps++;
        }
        if (in.steps > 0 || in.reset || !pubOn) publish();
    }

    private static void publish() {
        synchronized (LOCK) {
            int size = grid.n * grid.n * 4;
            if (pub.length != size) pub = new byte[size];
            grid.writeRGBA(pub);
            pubX0 = grid.x0;
            pubY0 = grid.y0;
            pubN = grid.n;
            pubVersion++;
        }
        pubOn = true;
        if (pubVersion % 20 == 1) {
            float[] s = grid.densityStats();
            int i = (int) Math.floor(camX) - grid.x0, j = (int) Math.floor(camY) - grid.y0;
            boolean in = i >= 0 && j >= 0 && i < TILES && j < TILES;
            simInfo = String.format("grade=(%d,%d) %dx%d interior=%d sólido=%d árvore=%d faces fechadas=%d"
                            + " densidade min/média/max=%.2f/%.2f/%.2f sob o jogador=%s flags=%s",
                    grid.x0, grid.y0, grid.n, grid.n, grid.countCells(FlowGrid.F_INDOOR), grid.countCells(FlowGrid.F_SOLID),
                    grid.countCells(FlowGrid.F_TREE), grid.closedFaces(), s[0], s[1], s[2],
                    in ? String.format("%.2f", grid.tileDensity(i, j)) : "fora", in ? Integer.toString(grid.tileFlags(i, j)) : "-");
        }
    }

    // ---------- render thread ----------

    /** Sobe a textura nova e prende na unidade 6. Muda a unidade ativa: quem chama restaura. */
    static void prepare() {
        if (dead) return;
        try {
            if (tex == 0) {
                tex = glGenTextures();
                glActiveTexture(GL_TEXTURE0 + UNIT);
                glBindTexture(GL_TEXTURE_2D, tex);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            }
            glActiveTexture(GL_TEXTURE0 + UNIT);
            glBindTexture(GL_TEXTURE_2D, tex);
            if (!pubOn || texVersion == pubVersion) return;
            // o jogo pode ter deixado um PBO de upload preso ou um row length próprio
            int unpackBuf = glGetInteger(GL_PIXEL_UNPACK_BUFFER_BINDING);
            int rowLength = glGetInteger(GL_UNPACK_ROW_LENGTH), align = glGetInteger(GL_UNPACK_ALIGNMENT);
            if (unpackBuf != 0) glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
            int n;
            synchronized (LOCK) {
                n = pubN;
                if (upload == null || upload.capacity() != pub.length) upload = BufferUtils.createByteBuffer(pub.length);
                upload.clear();
                upload.put(pub).flip();
                texX0 = pubX0;
                texY0 = pubY0;
                texVersion = pubVersion;
            }
            if (n != texN) {        // resolução nova: textura do tamanho da grade
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, n, n, 0, GL_RGBA, GL_UNSIGNED_BYTE, (ByteBuffer) null);
                texN = n;
                RenderContext.log("fluido: textura " + n + "x" + n);
            }
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, n, n, GL_RGBA, GL_UNSIGNED_BYTE, upload);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, rowLength);
            glPixelStorei(GL_UNPACK_ALIGNMENT, align);
            if (unpackBuf != 0) glBindBuffer(GL_PIXEL_UNPACK_BUFFER, unpackBuf);
        } catch (Throwable t) {
            die("ERRO no upload do fluido, simulação desligada (a névoa segue sem ela): ", t);
        }
    }

    /** uFlowTex e uFlow (x0, y0 relativos à origem do quadro, tiles cobertos, ligado). */
    static void bindUniforms(int prog, float originX, float originY) {
        // o parâmetro também: a simulação pode publicar uma última vez depois de desligada
        boolean on = !dead && pubOn && texVersion >= 0 && texN > 0 && RenderContext.luaParams[PARAM_ON] >= 0.5f;
        sentX = (float) (texX0 - (double) originX);
        sentY = (float) (texY0 - (double) originY);
        sentOn = on ? 1f : 0f;
        glUniform1i(glGetUniformLocation(prog, "uFlowTex"), UNIT);
        glUniform4f(glGetUniformLocation(prog, "uFlow"), sentX, sentY, TILES, sentOn);
        glUniform4f(glGetUniformLocation(prog, "uDrift"), (float) (originX - driftX), (float) (originY - driftY),
                driftWX, driftWY);
    }
}
