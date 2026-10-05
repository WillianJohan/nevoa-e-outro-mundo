import java.util.Random;

import nom.render.FlowGrid;

/** Névoa que contorna (sprint 0031): esteira que enche, árvore porosa, carro baixo, pressão com chute. Sem o jogo. */
public class FlowContourTest {
    static final float DT = 0.05f;
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("sem o sorvedouro, a esteira do prédio enche", FlowContourTest::wakeFills);
        run("com o sorvedouro, o vácuo da 0026 volta", FlowContourTest::wakeSinkStillWorks);
        run("árvore é porosa: o ar passa freado e a névoa atrás fica", FlowContourTest::porousTree);
        run("carro é obstáculo baixo: passa fluxo, mais lento", FlowContourTest::lowObstacle);
        run("domínio fechado com obstáculo baixo conserva massa", FlowContourTest::lowKeepsMass);
        run("pressão com chute do passo anterior sobra menos divergência", FlowContourTest::warmPressure);
        System.out.println("mod3 névoa que contorna: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void wakeFills() {
        FlowGrid g = FlowTravelTest.windyBlock(FlowTravelTest.VORT, S);
        g.stillDecay = 0f;
        for (int s = 0; s < 2000; s++) g.step(DT);   // 100 s
        for (int back : new int[] { 2, 4, 8 }) {
            float d = FlowTravelTest.tileDensity(g, 31 + back, 31);
            check(d > 0.8f, back + " tiles atrás do prédio: " + d);
        }
    }

    static void wakeSinkStillWorks() {
        FlowGrid g = FlowTravelTest.windyBlock(FlowTravelTest.VORT, S);
        for (int s = 0; s < 2000; s++) g.step(DT);
        float d = FlowTravelTest.tileDensity(g, 34, 31);
        check(d < 0.6f, "sem vácuo com o sorvedouro: " + d);
    }

    /** Bosque 6x6 tiles no meio do vento, sem sorvedouro. */
    static FlowGrid grove() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.vorticity = FlowTravelTest.VORT;
        g.stillDecay = 0f;
        g.windX = 1.5f;
        for (int tj = 29; tj < 35; tj++) for (int ti = 24; ti < 30; ti++) g.setTile(ti, tj, FlowGrid.F_TREE);
        return g;
    }

    static void porousTree() {
        FlowGrid g = grove();
        for (int s = 0; s < 800; s++) g.step(DT);
        float u = FlowTravelTest.tileU(g, 27, 31);
        check(u > 0.1f * 1.5f && u < 0.7f * 1.5f, "velocidade dentro do bosque: " + u);
        float behind = FlowTravelTest.tileDensity(g, 33, 31);
        check(behind > 0.8f, "a névoa sumiu atrás do bosque: " + behind);
        check((g.cellFlags(48, 62) & FlowGrid.F_SOLID) == 0, "árvore virou sólido");
    }

    static void lowObstacle() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.stillDecay = 0f;
        g.windX = 1.5f;
        for (int tj = 30; tj < 33; tj++) for (int ti = 26; ti < 31; ti++) g.setTile(ti, tj, FlowGrid.F_LOW);
        for (int s = 0; s < 800; s++) g.step(DT);
        float in = FlowTravelTest.tileU(g, 28, 31), out = FlowTravelTest.tileU(g, 28, 20);
        check(in > 0.05f, "nada passa pelo carro: " + in);
        check(in < 0.8f * out, "o carro não freia: dentro " + in + ", fora " + out);
        check(FlowTravelTest.tileDensity(g, 33, 31) > 0.8f, "a névoa sumiu atrás do carro");
    }

    static void lowKeepsMass() {
        FlowGrid g = new FlowGrid(24, S);
        g.edgeRefill = 0;
        g.outdoorRefill = 0;
        g.inertia = true;
        g.reset(0, 0);
        g.windX = 1.5f; g.windY = -0.8f;
        int n = g.n;
        for (int k = 0; k < n; k++) {
            g.setOpenW(0, k, false); g.setOpenW(n, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, n, false);
        }
        Random r = new Random(3);
        for (int k = 0; k < 20; k++) g.setTile(r.nextInt(24), r.nextInt(24), r.nextBoolean() ? FlowGrid.F_LOW : FlowGrid.F_TREE);
        for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) g.setDensity(i, j, r.nextFloat());
        float m0 = g.totalMass();
        for (int s = 0; s < 300; s++) g.step(DT);
        float err = Math.abs(g.totalMass() - m0) / m0;
        check(err < 1e-3f, "massa mudou " + err);
    }

    static void warmPressure() {
        FlowGrid warm = FlowTravelTest.windyHouse(FlowTravelTest.VORT, S), cold = FlowTravelTest.windyHouse(FlowTravelTest.VORT, S);
        cold.warmPressure = false;
        double a = 0, b = 0;
        for (int s = 0; s < 600; s++) {
            warm.step(DT);
            cold.step(DT);
            if (s >= 400) { a += warm.maxDivergence(); b += cold.maxDivergence(); }
        }
        System.out.printf("  divergência máxima média: com chute %.4f, do zero %.4f%n", a / 200, b / 200);
        check(a < 0.7 * b, "o chute não ajudou: com " + a / 200 + ", do zero " + b / 200);
    }
}
