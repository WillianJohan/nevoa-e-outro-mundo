import java.util.Random;

import nom.render.FlowGrid;

/** Núcleo da névoa fluida (mod3/java/nom/render/FlowGrid.java), sem o jogo. */
public class FlowGridTest {
    static final float DT = 0.05f;
    static int passed, failed;

    public static void main(String[] args) {
        run("caixa fechada não deixa entrar névoa", FlowGridTest::closedBox);
        run("parede com fresta de 1 tile deixa passar", FlowGridTest::wallGap);
        run("casa com porta e janela abertas enche", FlowGridTest::houseTwoOpenings);
        run("rolagem preserva a densidade no mundo", FlowGridTest::scrollKeepsWorld);
        run("impulso desloca a densidade", FlowGridTest::impulseMovesBlob);
        run("quem anda deixa rastro", FlowGridTest::walkerLeavesTrail);
        run("domínio fechado conserva massa", FlowGridTest::closedDomainKeepsMass);
        run("velocidade absurda não explode", FlowGridTest::stableUnderAbuse);
        run("interior novo começa vazio e esvazia", FlowGridTest::freshIndoor);
        run("vento contorna obstáculo sólido", FlowGridTest::flowsAroundSolid);
        run("textura RGBA codifica densidade, velocidade e flags", FlowGridTest::textureEncoding);
        run("custo do passo em 128x128", FlowGridTest::stepCost);
        System.out.println("mod3 FlowGrid: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    /** Fecha as quatro bordas de uma caixa s x s com canto em (bx, by). */
    static void box(FlowGrid g, int bx, int by, int s) {
        for (int k = 0; k < s; k++) {
            g.setOpenW(bx, by + k, false);
            g.setOpenW(bx + s, by + k, false);
            g.setOpenN(bx + k, by, false);
            g.setOpenN(bx + k, by + s, false);
        }
    }

    static void fill(FlowGrid g, int bx, int by, int s, float v) {
        for (int j = by; j < by + s; j++) for (int i = bx; i < bx + s; i++) g.setDensity(i, j, v);
    }

    static float mean(FlowGrid g, int bx, int by, int s) {
        float sum = 0;
        for (int j = by; j < by + s; j++) for (int i = bx; i < bx + s; i++) sum += g.density(i, j);
        return sum / (s * s);
    }

    static float max(FlowGrid g, int bx, int by, int s) {
        float m = 0;
        for (int j = by; j < by + s; j++) for (int i = bx; i < bx + s; i++) m = Math.max(m, g.density(i, j));
        return m;
    }

    static FlowGrid pureFlow(int n) {
        FlowGrid g = new FlowGrid(n);
        g.reset(0, 0);
        g.outdoorRefill = 0;
        g.indoorDecay = 0;
        return g;
    }

    static void closedBox() {
        FlowGrid g = pureFlow(32);
        g.windX = 2f; g.windY = 0.7f;
        box(g, 10, 10, 6);
        fill(g, 10, 10, 6, 0f);
        for (int s = 0; s < 400; s++) {
            float t = s * DT;
            g.impulse(9.5f, 10f + (t % 6f), 0f, 3f, 1.6f);
            g.impulse(16.5f, 16f - (t % 6f), 0f, -3f, 1.6f);
            g.step(DT);
        }
        check(max(g, 10, 10, 6) < 1e-6f, "interior da caixa ganhou névoa: " + max(g, 10, 10, 6));
        for (int k = 10; k < 16; k++) {
            check(g.faceU(10, k) == 0f && g.faceU(16, k) == 0f, "face oeste/leste fechada com velocidade");
            check(g.faceV(k, 10) == 0f && g.faceV(k, 16) == 0f, "face norte/sul fechada com velocidade");
        }
    }

    static float gapCase(boolean open) {
        FlowGrid g = pureFlow(32);
        g.edgeRefill = 0;
        g.windX = 1.5f;
        for (int j = 0; j < 32; j++) {
            g.setOpenW(16, j, open && j == 16);
            for (int i = 16; i < 32; i++) g.setDensity(i, j, 0f);
        }
        for (int s = 0; s < 200; s++) g.step(DT);
        return (g.density(16, 16) + g.density(17, 16) + g.density(18, 16)) / 3f;
    }

    static void wallGap() {
        float open = gapCase(true), closed = gapCase(false);
        check(open > 0.3f, "fresta aberta deixou passar pouco: " + open);
        check(open > closed + 0.2f, "fresta aberta (" + open + ") não difere da fechada (" + closed + ")");
    }

    static void houseTwoOpenings() {
        FlowGrid g = pureFlow(32);
        g.windX = 1.5f;
        box(g, 12, 12, 6);
        g.setOpenW(12, 14, true);   // porta a oeste
        g.setOpenW(18, 15, true);   // janela a leste
        fill(g, 12, 12, 6, 0f);
        for (int s = 0; s < 300; s++) g.step(DT);
        check(mean(g, 12, 12, 6) > 0.2f, "casa com duas aberturas não encheu: " + mean(g, 12, 12, 6));
    }

    static void scrollKeepsWorld() {
        FlowGrid g = new FlowGrid(16);
        g.reset(100, 200);
        Random r = new Random(7);
        float[][] world = new float[16][16];
        for (int j = 0; j < 16; j++) for (int i = 0; i < 16; i++) {
            world[j][i] = r.nextFloat();
            g.setDensity(i, j, world[j][i]);
        }
        g.setOpenW(9, 4, false);    // parede no tile do mundo (109, 204)
        g.scroll(105, 197);
        check(g.x0 == 105 && g.y0 == 197, "origem não rolou");
        for (int j = 0; j < 16; j++) for (int i = 0; i < 16; i++) {
            int oi = i + 5, oj = j - 3;
            float want = (oi >= 0 && oi < 16 && oj >= 0 && oj < 16) ? world[oj][oi] : g.ambient;
            check(g.density(i, j) == want, "célula (" + i + "," + j + ") = " + g.density(i, j) + ", queria " + want);
        }
        check(!g.isOpenW(4, 7), "parede não rolou junto com o mundo");
        check(g.isOpenW(9, 4), "parede ficou presa na grade, não no mundo");
        g.scroll(105 + 40, 197);
        check(g.x0 == 145 && g.density(3, 3) == g.ambient, "rolagem maior que a grade não resetou");
    }

    static float[] centroid(FlowGrid g) {
        double m = 0, cx = 0, cy = 0;
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) {
            float d = g.density(i, j);
            m += d; cx += d * (i + 0.5); cy += d * (j + 0.5);
        }
        return new float[] { (float) (cx / m), (float) (cy / m) };
    }

    static void impulseMovesBlob() {
        FlowGrid g = pureFlow(32);
        g.ambient = 0; g.edgeRefill = 0; g.diffusion = 0;
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) {
            float dx = i + 0.5f - 16, dy = j + 0.5f - 16;
            g.setDensity(i, j, (float) Math.exp(-(dx * dx + dy * dy) / 9.0));
        }
        float[] a = centroid(g);
        for (int s = 0; s < 20; s++) { g.impulse(16f, 16f, 3f, 0f, 2.5f); g.step(DT); }
        float[] b = centroid(g);
        check(b[0] - a[0] > 0.3f, "centróide andou pouco em x: " + (b[0] - a[0]));
        check(Math.abs(b[1] - a[1]) < 0.1f, "centróide andou em y: " + (b[1] - a[1]));
    }

    static void walkerLeavesTrail() {
        FlowGrid g = new FlowGrid(32);
        g.reset(0, 0);
        for (int s = 0; s < 160; s++) {
            g.impulse(8f + s * DT * 2f, 16.5f, 2f, 0f, 1.6f);
            g.step(DT);
        }
        // quem anda chegou em x = 24; 4 tiles atrás passou há 2 s
        check(g.density(20, 16) < 0.85f, "sem rastro atrás de quem andou: " + g.density(20, 16));
        check(g.density(16, 4) > 0.98f, "longe de quem anda a névoa mudou: " + g.density(16, 4));
    }

    static void closedDomainKeepsMass() {
        FlowGrid g = pureFlow(24);
        g.edgeRefill = 0;
        g.windX = 1.5f; g.windY = -0.8f;
        for (int k = 0; k < 24; k++) {
            g.setOpenW(0, k, false); g.setOpenW(24, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, 24, false);
        }
        Random r = new Random(3);
        for (int j = 0; j < 24; j++) for (int i = 0; i < 24; i++) g.setDensity(i, j, r.nextFloat());
        float m0 = g.totalMass();
        // só transporte: o impulso abre vazio de propósito (o rastro), então fica de fora
        for (int s = 0; s < 300; s++) g.step(DT);
        float err = Math.abs(g.totalMass() - m0) / m0;
        check(err < 1e-3f, "massa mudou " + err);
    }

    static void stableUnderAbuse() {
        FlowGrid g = new FlowGrid(32);
        g.reset(0, 0);
        g.windX = 30f;
        Random r = new Random(11);
        for (int s = 0; s < 200; s++) {
            g.impulse(r.nextFloat() * 32, r.nextFloat() * 32, r.nextFloat() * 100 - 50, r.nextFloat() * 100 - 50, 3f);
            g.step(DT);
        }
        for (int j = 0; j < 32; j++) for (int i = 0; i < 32; i++) {
            float d = g.density(i, j);
            check(d >= 0f && d <= 1.5f && !Float.isNaN(d), "densidade fora de [0, 1.5]: " + d);
            check(!Float.isNaN(g.faceU(i, j)) && !Float.isNaN(g.faceV(i, j)), "velocidade NaN");
        }
    }

    static void freshIndoor() {
        FlowGrid g = new FlowGrid(8);
        g.reset(0, 0);
        g.setCell(3, 3, FlowGrid.F_INDOOR);
        check(g.density(3, 3) == 0f, "interior novo não começou vazio");
        g.setCell(4, 4, 0);
        check(g.density(4, 4) == g.ambient, "exterior novo não começou no ambiente");
        g.setCell(5, 5, 0);
        g.setDensity(5, 5, 0.7f);
        g.setCell(5, 5, FlowGrid.F_INDOOR);
        check(g.density(5, 5) == 0.7f, "célula já simulada zerou ao virar interior");
        box(g, 5, 5, 1);
        g.setDensity(5, 5, 1f);
        for (int s = 0; s < 200; s++) g.step(DT);
        check(g.density(5, 5) < 0.5f, "interior fechado não esvaziou: " + g.density(5, 5));
    }

    static void flowsAroundSolid() {
        FlowGrid g = pureFlow(32);
        g.windX = 1f;
        for (int j = 12; j < 20; j++) for (int i = 14; i < 18; i++) g.setCell(i, j, FlowGrid.F_SOLID);
        for (int s = 0; s < 100; s++) g.step(DT);
        check(g.faceU(14, 15) == 0f && g.faceU(18, 15) == 0f, "velocidade entrando no sólido");
        check(g.faceV(15, 12) == 0f && g.faceV(15, 20) == 0f, "velocidade entrando no sólido (y)");
        check(g.faceU(16, 11) > 1.02f, "não acelerou ao lado do bloco: " + g.faceU(16, 11));
    }

    static int at(byte[] t, int n, int i, int j, int c) { return t[(j * n + i) * 4 + c] & 0xff; }

    static void textureEncoding() {
        FlowGrid g = new FlowGrid(4);
        g.reset(0, 0);
        g.setDensity(1, 1, 0.5f);
        g.setOpenW(1, 1, false);
        g.setOpenN(1, 1, false);
        g.setCell(2, 2, FlowGrid.F_SOLID | FlowGrid.F_TREE);
        g.setDensity(1, 2, 0.2f); g.setDensity(3, 2, 0.4f); g.setDensity(2, 1, 0.6f); g.setDensity(2, 3, 0.8f);
        byte[] t = new byte[4 * 4 * 4];
        g.writeRGBA(t);
        check(at(t, 4, 1, 1, 0) == 128, "densidade 0.5 virou " + at(t, 4, 1, 1, 0));
        check(at(t, 4, 1, 1, 3) == (FlowGrid.T_WALL_W | FlowGrid.T_WALL_N), "flags de parede: " + at(t, 4, 1, 1, 3));
        check(at(t, 4, 2, 2, 3) == (FlowGrid.F_SOLID | FlowGrid.F_TREE), "flags de sólido: " + at(t, 4, 2, 2, 3));
        check(at(t, 4, 2, 2, 0) == 128, "sólido sem a média dos vizinhos: " + at(t, 4, 2, 2, 0));
        check(at(t, 4, 0, 0, 1) == 128 && at(t, 4, 0, 0, 2) == 128, "velocidade zero não é 128");

        FlowGrid w = new FlowGrid(8);
        w.reset(0, 0);
        w.windX = 2f; w.windY = -1f;
        for (int s = 0; s < 300; s++) w.step(DT);   // 15 s: o vento já convergiu (relaxa a 0,6/s)
        byte[] tw = new byte[8 * 8 * 4];
        w.writeRGBA(tw);
        int gx = at(tw, 8, 4, 4, 1), gy = at(tw, 8, 4, 4, 2);
        check(Math.abs(gx - (128 + 2f / FlowGrid.VEL_MAX * 127)) < 3, "velocidade x codificada: " + gx);
        check(Math.abs(gy - (128 - 1f / FlowGrid.VEL_MAX * 127)) < 3, "velocidade y codificada: " + gy);
    }

    static void stepCost() {
        FlowGrid g = new FlowGrid(128);
        g.reset(0, 0);
        g.windX = 0.6f; g.windY = 0.3f;
        Random r = new Random(5);
        for (int k = 0; k < 40; k++) {     // casas com porta
            int bx = 4 + r.nextInt(112), by = 4 + r.nextInt(112), s = 4 + r.nextInt(6);
            if (bx + s >= 128 || by + s >= 128) continue;
            box(g, bx, by, s);
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
        System.out.printf("  passo 128x128: %.3f ms (meta < 1 ms)%n", ms);
        check(ms < 3.0, "passo caro demais: " + ms + " ms");
    }
}
