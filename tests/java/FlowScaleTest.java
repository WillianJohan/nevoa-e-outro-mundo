import java.util.Random;

import nom.render.FlowGrid;
import nom.render.FogBanks;

/** Grade com mais de uma célula por tile (sprint 0030): a física em tiles tem que ser a mesma. Sem o jogo. */
public class FlowScaleTest {
    static final float DT = 0.05f;
    static int passed, failed;

    public static void main(String[] args) {
        run("escala 2: setTile marca 2x2 células e a parede fecha 2 faces", FlowScaleTest::tileApi);
        run("escala 2: rolagem em tiles leva as células junto", FlowScaleTest::scrollInTiles);
        run("escala 2: buraco viaja na velocidade do vento (tiles/s)", FlowScaleTest::holeSpeed);
        run("escala 2: vento forte não freia a névoa (subpassos)", FlowScaleTest::holeSpeedStrongWind);
        run("difusão igual nas escalas 1 e 2", FlowScaleTest::diffusionMatches);
        run("névoa entra em casa igual nas escalas 1 e 2", FlowScaleTest::seepMatches);
        run("escala 2: prédio deixa vácuo atrás", FlowScaleTest::wake);
        run("escala 2: explosão conserva massa", FlowScaleTest::blastMass);
        run("escala 2: tudo ligado não explode", FlowScaleTest::stable);
        run("escalas 1 e 3: redemoinho estável, casa parada, vácuo", FlowScaleTest::otherScales);
        run("escala 2: custo do passo em 128 tiles", FlowScaleTest::cost);
        System.out.println("mod3 escala da grade: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    /** Como o jogo liga (FlowTravelTest.travel), com escala. */
    static FlowGrid travel(int tiles, int scale, FogBanks banks) {
        FlowGrid g = new FlowGrid(tiles, scale);
        g.banks = banks;
        g.inertia = true;
        g.windRelax = 0.15f;
        g.outdoorRefill = 0f;
        g.stillDecay = 0.08f;
        g.reset(0, 0);
        return g;
    }

    /** Média da densidade no tile (ti, tj). */
    static float tile(FlowGrid g, int ti, int tj) {
        float s = 0;
        for (int b = 0; b < g.scale; b++)
            for (int a = 0; a < g.scale; a++) s += g.density(ti * g.scale + a, tj * g.scale + b);
        return s / (g.scale * g.scale);
    }

    static void tileApi() {
        FlowGrid g = new FlowGrid(16, 2);
        check(g.n == 32 && g.tiles == 16 && g.scale == 2, "tamanho errado: " + g.n);
        g.setTile(3, 4, FlowGrid.F_INDOOR);
        for (int j = 0; j < 32; j++)
            for (int i = 0; i < 32; i++) {
                boolean in = i / 2 == 3 && j / 2 == 4;
                check((g.cellFlags(i, j) == FlowGrid.F_INDOOR) == in, "flag na célula " + i + "," + j);
            }
        g.setTileOpenW(3, 4, false);
        check(!g.isOpenW(6, 8) && !g.isOpenW(6, 9), "a parede oeste não fechou as 2 faces");
        check(g.isOpenW(7, 8) && g.isOpenW(6, 10), "fechou face demais");
        g.setTileOpenN(3, 4, false);
        check(!g.isOpenN(6, 8) && !g.isOpenN(7, 8) && g.isOpenN(6, 9), "a parede norte errou as faces");
        g.setTileOpenW(16, 0, false);
        check(!g.isOpenW(32, 0) && !g.isOpenW(32, 1), "a borda leste não fechou");
    }

    static void scrollInTiles() {
        FlowGrid g = new FlowGrid(16, 2);
        g.reset(100, 200);
        for (int b = 0; b < 2; b++) for (int a = 0; a < 2; a++) g.setDensity(10 + a, 10 + b, 0.3f);
        g.scroll(101, 200);
        check(g.x0 == 101, "origem em tiles: " + g.x0);
        check(Math.abs(tile(g, 4, 5) - 0.3f) < 1e-6, "o tile não ficou no mesmo lugar do mundo: " + tile(g, 4, 5));
        check(Math.abs(tile(g, 5, 5) - 1f) < 1e-6, "sobrou névoa velha onde estava");
    }

    /** Onde está o buraco (tile com menos névoa) na linha tj, depois de soltá-lo em x = 19..21. */
    static float holeAfter(int scale, float wind, int steps) {
        FlowGrid g = travel(64, scale, null);
        g.windX = wind;
        for (int s = 0; s < 200; s++) g.step(DT);
        for (int tj = 31; tj < 34; tj++)
            for (int ti = 19; ti < 22; ti++)
                for (int b = 0; b < scale; b++)
                    for (int a = 0; a < scale; a++) g.setDensity(ti * scale + a, tj * scale + b, 0f);
        for (int s = 0; s < steps; s++) g.step(DT);
        int at = -1;
        float lo = 2f;
        for (int ti = 0; ti < 64; ti++) if (tile(g, ti, 32) < lo) { lo = tile(g, ti, 32); at = ti; }
        check(lo < 0.7f, "o buraco sumiu: " + lo);
        return at;
    }

    static void holeSpeed() {
        float a = holeAfter(1, 1.5f, 80), b = holeAfter(2, 1.5f, 80);
        check(Math.abs(b - 26) <= 3, "escala 2: buraco em x = " + b + ", queria ~26");
        check(Math.abs(a - b) <= 2, "escalas diferentes: " + a + " e " + b);
    }

    static void holeSpeedStrongWind() {
        // o ar chega a ~80% do vento (windRelax 0,15 desde o repouso): 3 s andam ~12 tiles. Sem subpasso,
        // o limite por face (0,24 célula por passo) segura a névoa em 2,4 tiles/s: ~7 tiles
        float b = holeAfter(2, 5f, 60);
        check(Math.abs(b - 32.8f) <= 2.5f, "buraco em x = " + b + ", queria ~33 (névoa freada pelo limite por face?)");
    }

    /** Caixa fechada, metade oeste cheia, sem vento: perfil em tiles depois de 10 s. */
    static float[] diffusionProfile(int scale, int flags, FlowGrid[] out) {
        FlowGrid g = new FlowGrid(32, scale);
        g.outdoorRefill = 0f;
        g.indoorDecay = 0f;
        g.edgeRefill = 0f;
        g.reset(0, 0);
        int n = g.n;
        for (int k = 0; k < n; k++) {
            g.setOpenW(0, k, false); g.setOpenW(n, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, n, false);
        }
        for (int j = 0; j < n; j++)
            for (int i = 0; i < n; i++) {
                g.setCell(i, j, flags);
                g.setDensity(i, j, i < n / 2 ? 1f : 0f);
            }
        for (int s = 0; s < 200; s++) g.step(DT);
        float[] p = new float[32];
        for (int ti = 0; ti < 32; ti++) p[ti] = tile(g, ti, 16);
        return p;
    }

    static void diffusionMatches() {
        float[] a = diffusionProfile(1, 0, null), b = diffusionProfile(2, 0, null);
        for (int ti = 12; ti < 20; ti++)
            check(Math.abs(a[ti] - b[ti]) < 0.06f, "tile " + ti + ": escala 1 = " + a[ti] + ", escala 2 = " + b[ti]);
        check(b[17] > 0.1f, "a névoa não espalhou: " + b[17]);
    }

    static void seepMatches() {
        float[] a = diffusionProfile(1, FlowGrid.F_INDOOR, null), b = diffusionProfile(2, FlowGrid.F_INDOOR, null);
        for (int ti = 10; ti < 22; ti++)
            check(Math.abs(a[ti] - b[ti]) < 0.08f, "tile " + ti + ": escala 1 = " + a[ti] + ", escala 2 = " + b[ti]);
        check(b[19] > 0.2f, "a névoa não entrou: " + b[19]);
    }

    static void wake() {
        FlowGrid g = travel(64, 2, null);
        g.windX = 1.5f;
        for (int tj = 28; tj < 36; tj++) for (int ti = 24; ti < 32; ti++) g.setTile(ti, tj, FlowGrid.F_SOLID);
        for (int s = 0; s < 800; s++) g.step(DT);
        float behind = tile(g, 34, 31), up = tile(g, 16, 31), side = tile(g, 28, 22);
        check(behind < 0.6f, "sem vácuo atrás do prédio: " + behind);
        check(up > 0.9f, "a frente do prédio esvaziou: " + up);
        check(side > 0.8f, "o lado do prédio esvaziou: " + side);
    }

    static void blastMass() {
        FlowGrid g = new FlowGrid(32, 2);
        g.reset(0, 0);
        for (int k = 0; k < 64; k++) {
            g.setOpenW(0, k, false); g.setOpenW(64, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, 64, false);
        }
        float m0 = g.totalMass();
        g.blast(16f, 16f, 4f);
        check(tile(g, 16, 16) < 0.4f, "o centro não abriu: " + tile(g, 16, 16));
        check(tile(g, 16, 21) > 1.05f || tile(g, 21, 16) > 1.05f, "a névoa não foi pro anel (raio em tiles?)");
        check(Math.abs(g.totalMass() - m0) / m0 < 0.01f, "a explosão mudou a massa");
    }

    static void stable() {
        FlowGrid g = travel(32, 2, new FogBanks(2, 0.7f, 10f));
        g.doorPuff = 0.35f;
        g.vorticity = FlowTravelTest.VORT;
        g.windX = 30f;
        Random r = new Random(4);
        for (int s = 0; s < 300; s++) {
            g.impulse(r.nextFloat() * 32, r.nextFloat() * 32, r.nextFloat() * 100 - 50, r.nextFloat() * 100 - 50, 3f);
            if (s % 20 == 0) g.blast(r.nextFloat() * 32, r.nextFloat() * 32, 1f + r.nextFloat() * 10);
            if (s % 7 == 0) g.setTileOpenW(r.nextInt(33), r.nextInt(32), r.nextBoolean());
            if (s % 11 == 0) g.setTile(r.nextInt(32), r.nextInt(32), r.nextBoolean() ? FlowGrid.F_SOLID : 0);
            if (s % 50 == 0) g.scroll(g.x0 + r.nextInt(7) - 3, g.y0 + r.nextInt(7) - 3);
            g.step(DT);
        }
        for (int j = 0; j < g.n; j++)
            for (int i = 0; i < g.n; i++) {
                float d = g.density(i, j);
                check(d >= 0f && d <= 1.5f && !Float.isNaN(d), "densidade fora de [0, 1.5]: " + d);
                check(!Float.isNaN(g.faceU(i, j)) && !Float.isNaN(g.faceV(i, j)), "velocidade NaN");
            }
    }

    /** Escalas que o jogador pode escolher além da padrão: redemoinho estável, casa parada, vácuo. */
    static void otherScales() {
        for (int scale : new int[] { 1, 3 }) {
            FlowGrid house = FlowTravelTest.windyHouse(FlowTravelTest.VORT, scale);
            FlowGrid block = FlowTravelTest.windyBlock(FlowTravelTest.VORT, scale);
            float inside = 0f, maxV = 0f;
            for (int s = 0; s < 800; s++) {
                house.step(DT);
                block.step(DT);
                if (s >= 400) inside = Math.max(inside, FlowTravelTest.indoorSpeed(house));
            }
            for (int j = 0; j < block.n; j++)
                for (int i = 0; i < block.n; i++) {
                    float x = Math.abs(block.faceU(i, j)) + Math.abs(block.faceV(i, j));
                    check(!Float.isNaN(x), "escala " + scale + ": NaN");
                    maxV = Math.max(maxV, x);
                }
            check(inside < 0.2f, "escala " + scale + ": o ar dentro da casa mexe: " + inside);
            check(maxV < 8f, "escala " + scale + ": velocidade disparou: " + maxV);
            float behind = FlowTravelTest.tileDensity(block, 34, 31);
            check(behind < 0.7f, "escala " + scale + ": sem vácuo atrás do prédio: " + behind);
        }
    }

    static void cost() {
        FlowGrid g = travel(128, 2, new FogBanks(9, 0.7f, 22f));
        g.doorPuff = 0.35f;
        g.vorticity = FlowTravelTest.VORT;
        g.windX = 1.4f; g.windY = 0.5f;
        Random r = new Random(1);
        for (int k = 0; k < 400; k++) g.setTile(r.nextInt(128), r.nextInt(128), r.nextBoolean() ? FlowGrid.F_SOLID : FlowGrid.F_INDOOR);
        for (int s = 0; s < 100; s++) g.step(DT);
        long t0 = System.nanoTime();
        int steps = 100;
        for (int s = 0; s < steps; s++) g.step(DT);
        double ms = (System.nanoTime() - t0) / 1e6 / steps;
        // roda na thread da simulação a 20 Hz: 8 ms são 16% de um núcleo
        System.out.printf("  passo escala 2 (256x256 células): %.3f ms (meta < 8 ms, fora da thread principal)%n", ms);
        check(ms < 8.0, "passo lento: " + ms + " ms");
    }
}
