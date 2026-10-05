package nom.render;

import static org.lwjgl.opengl.GL33C.*;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.IdentityHashMap;

import org.lwjgl.BufferUtils;

import zombie.GameTime;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;
import zombie.iso.IsoGridSquare;
import zombie.iso.weather.ClimateManager;

/**
 * Névoa fluida: liga o FlowGrid ao jogo.
 *
 * Thread principal (update, chamado do RenderContext.onWorldEnd): rola a grade com o personagem da
 * câmera, monta a máscara de obstáculos aos poucos, injeta o vento do clima e o impulso de quem anda,
 * avança a 20 Hz e publica a textura sob trava. Thread de render (prepare): sobe a versão nova e
 * prende na unidade 6. Erro aqui desliga só o fluido; a névoa segue com densidade 1.
 */
final class Flow {
    static final int N = 128;
    static final float STEP = 1f / 20f;
    static final int ROWS_PER_FRAME = 8;   // máscara inteira a cada 16 quadros
    static final float MOVER_RANGE = 40f;
    static final int MAX_MOVERS = 48;
    static final float MOVER_RADIUS = 1.6f;
    static final int PARAM_ON = 4;         // NOMRender_setParam(4, 0) desliga, (4, 1) liga
    static final int UNIT = 6;

    private static final FlowGrid grid = new FlowGrid(N);
    private static boolean dead, running;
    private static int z = Integer.MIN_VALUE, maskRow, frameStamp;
    private static long lastNanos;
    private static float acc, simTime, camX, camY;
    private static volatile float sentX, sentY, sentOn = -1f;   // último uFlow mandado ao shader

    // quem anda: posição anterior por personagem (x, y, segundos, quadro em que foi visto)
    private static final IdentityHashMap<IsoGameCharacter, float[]> prev = new IdentityHashMap<>();
    private static final float[] movers = new float[MAX_MOVERS * 4];
    private static int moverCount;

    private static long statSteps, statStepNanos, statFrames, statMaskNanos;

    // publicado: main -> render
    private static final Object LOCK = new Object();
    private static final byte[] pub = new byte[N * N * 4];
    private static int pubX0, pubY0;
    private static volatile int pubVersion;
    private static volatile boolean pubOn;

    // render thread
    private static int tex, texVersion = -1, texX0, texY0;
    private static ByteBuffer upload;

    private Flow() {}

    // ---------- main thread ----------

    static void update(IsoCell cell, IsoCamera.FrameState fs) {
        if (dead) return;
        try {
            if (RenderContext.luaParams[PARAM_ON] < 0.5f) { running = false; pubOn = false; return; }
            long now = System.nanoTime();
            float dt = lastNanos == 0 ? 0f : Math.min(0.25f, (now - lastNanos) / 1e9f);
            lastNanos = now;
            frameStamp++;

            float cx = fs.camCharacterX, cy = fs.camCharacterY;
            camX = cx;
            camY = cy;
            int cz = (int) Math.floor(fs.camCharacterZ);
            int nx0 = (int) Math.floor(cx) - N / 2, ny0 = (int) Math.floor(cy) - N / 2;
            long m0 = System.nanoTime();
            if (!running || cz != z) {
                // começo ou outro andar: grade nova com a máscara inteira de uma vez (um soluço só),
                // senão o interior dos prédios começaria cheio de névoa
                z = cz;
                grid.reset(nx0, ny0);
                for (int j = 0; j < N; j++) buildRow(cell, j);
                maskRow = 0;
                acc = 0f;
                prev.clear();
                running = true;
            } else if (nx0 != grid.x0 || ny0 != grid.y0) {
                int dx = nx0 - grid.x0, dy = ny0 - grid.y0;
                grid.scroll(nx0, ny0);
                if (Math.abs(dx) >= N || Math.abs(dy) >= N) {
                    for (int j = 0; j < N; j++) buildRow(cell, j);
                } else {                // só a faixa que entrou
                    for (int k = 0; k < Math.abs(dx); k++) buildColumn(cell, dx > 0 ? N - 1 - k : k);
                    for (int k = 0; k < Math.abs(dy); k++) buildRow(cell, dy > 0 ? N - 1 - k : k);
                }
            }
            for (int r = 0; r < ROWS_PER_FRAME; r++) {
                buildRow(cell, maskRow);
                maskRow = (maskRow + 1) % N;
            }
            statMaskNanos += System.nanoTime() - m0;
            statFrames++;

            if (GameTime.isGamePaused()) return;
            acc += dt;
            if (acc >= STEP) collectMovers(cell, cx, cy, cz, now);
            int steps = 0;
            while (acc >= STEP && steps < 2) {
                long s0 = System.nanoTime();
                simTime += STEP;
                wind();
                for (int k = 0; k < moverCount; k++)
                    grid.impulse(movers[k * 4], movers[k * 4 + 1], movers[k * 4 + 2], movers[k * 4 + 3], MOVER_RADIUS);
                grid.step(STEP);
                acc -= STEP;
                steps++;
                statStepNanos += System.nanoTime() - s0;
                if (++statSteps % 600 == 0) logStats();
            }
            if (acc > STEP) acc = 0f;   // quadro muito longo: não tenta alcançar
            if (steps > 0 || !pubOn) publish();
        } catch (Throwable t) {
            dead = true;
            running = false;
            pubOn = false;
            RenderContext.log("ERRO no fluido, simulação desligada (a névoa segue sem ela): " + t);
            t.printStackTrace();
        }
    }

    private static void buildRow(IsoCell cell, int j) {
        for (int i = 0; i < N; i++) buildCell(cell, i, j);
    }

    private static void buildColumn(IsoCell cell, int i) {
        for (int j = 0; j < N; j++) buildCell(cell, i, j);
    }

    /**
     * Um square vira flags + as faces oeste e norte. isBlockedTo = parede (collideN/W, sem janela),
     * janela fechada ou barricada, porta fechada ou barricada, escada (bytecode, ver o plan.md).
     * Square não carregado é ar aberto.
     */
    private static void buildCell(IsoCell cell, int i, int j) {
        int x = grid.x0 + i, y = grid.y0 + j;
        IsoGridSquare sq = cell.getGridSquare(x, y, z);
        int f = 0;
        boolean openW = true, openN = true;
        if (sq != null) {
            if (sq.isSolid()) f |= FlowGrid.F_SOLID;
            if (sq.HasTree()) f |= FlowGrid.F_SOLID | FlowGrid.F_TREE;
            if (!sq.isOutside()) f |= FlowGrid.F_INDOOR;
            if ((f & FlowGrid.F_SOLID) == 0 && sq.getVehicleContainer() != null) f |= FlowGrid.F_SOLID;
            IsoGridSquare w = cell.getGridSquare(x - 1, y, z);
            if (w != null && sq.isBlockedTo(w)) openW = false;
            IsoGridSquare n = cell.getGridSquare(x, y - 1, z);
            if (n != null && sq.isBlockedTo(n)) openN = false;
        }
        grid.setCell(i, j, f);
        grid.setOpenW(i, j, openW);
        grid.setOpenN(i, j, openN);
    }

    /** Vento do clima, lento, com a direção oscilando devagar. A convenção do ângulo não importa pra névoa. */
    private static void wind() {
        ClimateManager cm = ClimateManager.getInstance();
        float ang = cm.getWindAngleRadians() + 0.6f * (float) Math.sin(simTime / 40f);
        float speed = 0.25f + cm.getWindIntensity();
        grid.windX = (float) Math.cos(ang) * speed;
        grid.windY = (float) Math.sin(ang) * speed;
    }

    /** Jogadores locais e zumbis no mesmo andar, a até MOVER_RANGE: velocidade pela posição anterior. */
    private static void collectMovers(IsoCell cell, float cx, float cy, int cz, long now) {
        float t = (now - RenderContext.t0) / 1e9f;
        moverCount = 0;
        for (IsoPlayer p : IsoPlayer.players) {
            if (p != null) mover(p, cx, cy, cz, t);
        }
        ArrayList<IsoZombie> zs = cell.getZombieList();
        for (int i = 0; i < zs.size() && moverCount < MAX_MOVERS; i++) mover(zs.get(i), cx, cy, cz, t);
        final int stamp = frameStamp;
        prev.values().removeIf(e -> (int) e[3] != stamp);
    }

    private static void mover(IsoGameCharacter ch, float cx, float cy, int cz, float t) {
        float x = ch.getX(), y = ch.getY();
        if ((int) Math.floor(ch.getZ()) != cz) return;
        float dx = x - cx, dy = y - cy;
        if (dx * dx + dy * dy > MOVER_RANGE * MOVER_RANGE) return;
        float[] e = prev.get(ch);
        if (e == null) { prev.put(ch, new float[] { x, y, t, frameStamp }); return; }
        float dt = t - e[2];
        float vx = dt > 1e-3f ? (x - e[0]) / dt : 0f, vy = dt > 1e-3f ? (y - e[1]) / dt : 0f;
        e[0] = x; e[1] = y; e[2] = t; e[3] = frameStamp;
        float sp2 = vx * vx + vy * vy;
        if (sp2 < 0.09f || sp2 > 225f || moverCount >= MAX_MOVERS) return; // parado, ou teleportou
        int k = moverCount++ * 4;
        movers[k] = x; movers[k + 1] = y; movers[k + 2] = vx; movers[k + 3] = vy;
    }

    private static void publish() {
        synchronized (LOCK) {
            grid.writeRGBA(pub);
            pubX0 = grid.x0;
            pubY0 = grid.y0;
            pubVersion++;
        }
        pubOn = true;
    }

    private static void logStats() {
        RenderContext.log(String.format("fluido: passo %.3f ms, máscara %.3f ms/quadro",
                statStepNanos / 1e6 / 600, statMaskNanos / 1e6 / Math.max(1, statFrames)));
        RenderContext.log(info());
        statStepNanos = 0;
        statMaskNanos = 0;
        statFrames = 0;
    }

    /** Estado real da simulação (thread principal): o que ela achou no mundo e o que o shader recebeu. */
    static String info() {
        int i = (int) Math.floor(camX) - grid.x0, j = (int) Math.floor(camY) - grid.y0;
        boolean in = i >= 0 && j >= 0 && i < N && j < N;
        float[] s = grid.densityStats();
        return String.format("fluido: %s param4=%.0f andar=%d grade=(%d,%d) interior=%d sólido=%d árvore=%d"
                        + " faces fechadas=%d densidade min/média/max=%.2f/%.2f/%.2f sob o jogador=%s flags=%s"
                        + " publicada=%d enviada=%d shader uFlow=(%.0f,%.0f,%.0f) tex0=(%d,%d)",
                dead ? "MORTO" : running ? "rodando" : "parado", RenderContext.luaParams[PARAM_ON], z,
                grid.x0, grid.y0, grid.countCells(FlowGrid.F_INDOOR), grid.countCells(FlowGrid.F_SOLID),
                grid.countCells(FlowGrid.F_TREE), grid.closedFaces(), s[0], s[1], s[2],
                in ? String.format("%.2f", grid.density(i, j)) : "fora", in ? Integer.toString(grid.cellFlags(i, j)) : "-",
                pubVersion, texVersion, sentX, sentY, sentOn, texX0, texY0);
    }

    // ---------- render thread ----------

    /** Sobe a textura nova e prende na unidade 6. Muda a unidade ativa: quem chama restaura. */
    static void prepare() {
        if (dead) return;
        try {
            if (tex == 0) {
                upload = BufferUtils.createByteBuffer(N * N * 4);
                tex = glGenTextures();
                glActiveTexture(GL_TEXTURE0 + UNIT);
                glBindTexture(GL_TEXTURE_2D, tex);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, N, N, 0, GL_RGBA, GL_UNSIGNED_BYTE, (ByteBuffer) null);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                RenderContext.log("fluido: textura " + N + "x" + N);
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
            synchronized (LOCK) {
                upload.clear();
                upload.put(pub).flip();
                texX0 = pubX0;
                texY0 = pubY0;
                texVersion = pubVersion;
            }
            glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, N, N, GL_RGBA, GL_UNSIGNED_BYTE, upload);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, rowLength);
            glPixelStorei(GL_UNPACK_ALIGNMENT, align);
            if (unpackBuf != 0) glBindBuffer(GL_PIXEL_UNPACK_BUFFER, unpackBuf);
        } catch (Throwable t) {
            dead = true;
            pubOn = false;
            RenderContext.log("ERRO no upload do fluido, simulação desligada (a névoa segue sem ela): " + t);
            t.printStackTrace();
        }
    }

    /** uFlowTex e uFlow (x0, y0 relativos à origem do quadro, n, ligado). */
    static void bindUniforms(int prog, float originX, float originY) {
        boolean on = !dead && pubOn && texVersion >= 0;
        sentX = (float) (texX0 - (double) originX);
        sentY = (float) (texY0 - (double) originY);
        sentOn = on ? 1f : 0f;
        glUniform1i(glGetUniformLocation(prog, "uFlowTex"), UNIT);
        glUniform4f(glGetUniformLocation(prog, "uFlow"), sentX, sentY, N, sentOn);
    }
}
