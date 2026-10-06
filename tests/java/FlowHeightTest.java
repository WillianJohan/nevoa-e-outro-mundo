import java.util.Random;

import nom.render.FlowGrid;
import nom.render.FogBanks;

/** Névoa com altura (sprint 0032): cerca baixa, carro, névoa rasa vs funda, espalhamento por gravidade. Sem o jogo. */
public class FlowHeightTest {
    static final float DT = 0.05f;
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("cerca baixa: a névoa e o vento passam por cima", FlowHeightTest::fencePasses);
        run("muro do mesmo tamanho deixa o vácuo", FlowHeightTest::wallKeepsVacuum);
        run("névoa mais rasa que a cerca não passa", FlowHeightTest::shallowStops);
        run("névoa rasa empilha na frente da cerca", FlowHeightTest::shallowPilesUp);
        run("névoa mais funda que a cerca passa", FlowHeightTest::deepPasses);
        run("carro: a névoa passa por cima e enche o outro lado", FlowHeightTest::carPassesOver);
        run("sem vento, a névoa funda transborda a cerca e a rasa fica", FlowHeightTest::slumpSpills);
        run("domínio fechado com cercas, carros e árvores conserva massa", FlowHeightTest::keepsMass);
        run("estável com bancos, vácuos e vento forte", FlowHeightTest::stableWithGaps);
        System.out.println("mod3 névoa com altura: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    /** Linha de 20 tiles na borda oeste da coluna 30, com o vento do jogo (o vácuo ligado, escolha do Johan). */
    static FlowGrid windyLine(boolean fence) {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.vorticity = FlowTravelTest.VORT;
        g.windX = 1.5f;
        for (int tj = 22; tj < 42; tj++) {
            if (fence) g.setTileFenceW(30, tj, true);
            else g.setTileOpenW(30, tj, false);
        }
        return g;
    }

    static void fencePasses() {
        FlowGrid g = windyLine(true);
        for (int s = 0; s < 2000; s++) g.step(DT);
        float d = FlowTravelTest.tileDensity(g, 32, 31), u = FlowTravelTest.tileU(g, 31, 31);
        System.out.printf("  cerca: névoa 2 tiles atrás %.2f, vento logo atrás %.2f%n", d, u);
        check(d > 0.7f, "a névoa não passou a cerca: " + d);
        check(u > 0.4f * 1.5f, "o vento não passou a cerca: " + u);
    }

    static void wallKeepsVacuum() {
        FlowGrid g = windyLine(false);
        for (int s = 0; s < 2000; s++) g.step(DT);
        float d = FlowTravelTest.tileDensity(g, 32, 31);
        check(d < 0.5f, "atrás do muro não ficou vácuo: " + d);
    }

    /** Névoa de densidade `amb` só antes da cerca, que corta a grade inteira; depois dela, vazio. */
    static FlowGrid fenceAcross(float amb, int steps) { return fenceAcross(amb, steps, 1.5f); }

    static FlowGrid fenceAcross(float amb, int steps, float wind) {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.stillDecay = 0f;
        g.edgeRefill = 0f;
        g.ambient = amb;
        g.reset(0, 0);
        g.windX = wind;
        for (int tj = 0; tj < 64; tj++) g.setTileFenceW(30, tj, true);
        for (int j = 0; j < g.n; j++) for (int i = 30 * S; i < g.n; i++) g.setDensity(i, j, 0f);
        for (int s = 0; s < steps; s++) g.step(DT);
        return g;
    }

    static final float SHALLOW = 0.8f * FlowGrid.H_FENCE / FlowGrid.FOG_DEPTH;   // 80% da altura da cerca

    /** Parada ao lado da cerca: logo atrás fica vazio. */
    static void shallowStops() {
        float d = FlowTravelTest.tileDensity(fenceAcross(SHALLOW, 200, 0f), 31, 31);
        check(d < 0.01f, "névoa rasa atravessou a cerca: " + d);
    }

    /** Com o vento trazendo mais, a rasa sobe contra a cerca (e um dia transborda). */
    static void shallowPilesUp() {
        float d = FlowTravelTest.tileDensity(fenceAcross(SHALLOW, 400), 29, 31);
        check(d > 1.3f * SHALLOW, "não empilhou na frente da cerca: " + d);
    }

    static void deepPasses() {
        float d = FlowTravelTest.tileDensity(fenceAcross(1f, 60), 31, 31);
        check(d > 0.2f, "névoa funda não passou a cerca: " + d);
    }

    static void carPassesOver() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.vorticity = FlowTravelTest.VORT;
        g.windX = 1.5f;
        for (int tj = 30; tj < 33; tj++) for (int ti = 26; ti < 31; ti++) g.setTile(ti, tj, FlowGrid.F_LOW);
        for (int s = 0; s < 1200; s++) g.step(DT);
        float over = FlowTravelTest.tileDensity(g, 28, 31), behind = FlowTravelTest.tileDensity(g, 33, 31);
        System.out.printf("  carro: névoa por cima %.2f, 2 tiles atrás %.2f%n", over, behind);
        check(over > 0.3f, "não passa névoa por cima do carro: " + over);
        check(behind > 0.7f, "não encheu atrás do carro: " + behind);
    }

    /** Sem vento: a névoa funda escorre por cima da cerca (gravidade e difusão só pela parte de cima). */
    static void slumpSpills() {
        FlowGrid deep = fenceAcross(1.2f, 200, 0f);
        float d = FlowTravelTest.tileDensity(deep, 31, 31);
        System.out.printf("  sem vento, 10 s: logo atrás da cerca %.3f%n", d);
        check(d > 0.05f, "a névoa funda não transbordou: " + d);
        FlowGrid dry = fenceAcross(1.2f, 0, 0f);
        float m0 = dry.totalMass();
        dry.slump = 0f;
        for (int s = 0; s < 200; s++) dry.step(DT);
        check(FlowTravelTest.tileDensity(dry, 31, 31) < d, "sem a gravidade transbordou igual");
        for (int j = 0; j < deep.n; j++) for (int i = 0; i < deep.n; i++) check(deep.density(i, j) >= 0f, "densidade negativa");
    }

    static void keepsMass() {
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
        Random r = new Random(5);
        for (int k = 0; k < 20; k++) g.setTile(r.nextInt(24), r.nextInt(24), r.nextBoolean() ? FlowGrid.F_LOW : FlowGrid.F_TREE);
        for (int k = 0; k < 30; k++) {
            if (r.nextBoolean()) g.setTileFenceW(1 + r.nextInt(23), r.nextInt(24), true);
            else g.setTileFenceN(r.nextInt(24), 1 + r.nextInt(23), true);
        }
        for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) g.setDensity(i, j, r.nextFloat() * 1.4f);
        float m0 = g.totalMass();
        for (int s = 0; s < 300; s++) g.step(DT);
        float err = Math.abs(g.totalMass() - m0) / m0;
        check(err < 1e-3f, "massa mudou " + err);
    }

    static void stableWithGaps() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.banks = new FogBanks(7, 0.7f, 22f);
        g.vorticity = FlowTravelTest.VORT;
        g.reset(0, 0);
        Random r = new Random(9);
        for (int k = 0; k < 60; k++) g.setTile(r.nextInt(64), r.nextInt(64), FlowGrid.F_LOW);
        for (int k = 0; k < 120; k++) g.setTileFenceW(1 + r.nextInt(63), r.nextInt(64), true);
        for (int s = 0; s < 600; s++) {
            g.windX = 4f * (float) Math.cos(s * 0.01);
            g.windY = 4f * (float) Math.sin(s * 0.01);
            g.step(DT);
        }
        for (int j = 0; j < g.n; j++)
            for (int i = 0; i < g.n; i++) {
                float d = g.density(i, j);
                check(!Float.isNaN(d) && d >= 0f && d <= 1.5f, "densidade fora de [0, 1.5]: " + d);
            }
    }
}
