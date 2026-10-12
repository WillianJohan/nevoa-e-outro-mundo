import nom.render.FlowGrid;
import nom.render.Sonar;

/** Sonar do Estalador na névoa fluida (sprint 0037): os anéis (Sonar) e a frente na grade (FlowGrid.sonar). Sem o jogo. */
public class FlowSonarTest {
    static final float DT = 0.05f;   // Flow.STEP
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("anel: faixas contíguas de 0 a RANGE em DURATION, depois sai", FlowSonarTest::bandsContiguous);
        run("anel: no máximo MAX_RINGS; passo jogado fora também avança", FlowSonarTest::ringsCap);
        run("anel: a curva do raio é a do Lua (tests/sonar_curve.csv)", FlowSonarTest::curveMatchesLua);
        run("frente anda pra fora: monte na frente, miolo ralo, longe intocado", FlowSonarTest::frontTravels);
        run("frente conserva massa e respeita o teto", FlowSonarTest::massAndCeiling);
        run("sólido e interior não dão nem recebem", FlowSonarTest::wallsUntouched);
        run("a frente não leva névoa pra trás de parede (face fechada ou sólido)", FlowSonarTest::noneBehindWall);
        run("custo: 8 anéis num passo da grade do jogo", FlowSonarTest::cost);
        System.out.println("mod3 sonar: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void bandsContiguous() {
        Sonar s = new Sonar();
        check(s.add(10f, 20f), "não aceitou");
        float[] out = new float[4];
        float last = 0f;
        int steps = 0;
        while (s.count() > 0) {
            check(s.bands(DT, out, 0) == 1, "uma faixa por anel");
            check(out[0] == 10f && out[1] == 20f, "centro mudou");
            check(Math.abs(out[2] - last) < 1e-5f, "faixa com buraco: " + last + " → " + out[2]);
            check(out[3] > out[2], "faixa vazia");
            last = out[3];
            steps++;
        }
        check(Math.abs(last - Sonar.RANGE) < 1e-5f, "não chegou em RANGE: " + last);
        check(Math.abs(steps - Sonar.DURATION / DT) <= 1, "durou " + steps + " passos");
        check(Sonar.radius(Sonar.DURATION / 2) == Sonar.RANGE / 2, "não é linear");
    }

    static void ringsCap() {
        Sonar s = new Sonar();
        for (int k = 0; k < Sonar.MAX_RINGS; k++) check(s.add(k, 0), "recusou o " + k);
        check(!s.add(99, 0), "aceitou além de MAX_RINGS");
        // soma de float: DURATION / DT passos podem dar um fio abaixo de DURATION, então +1
        for (int k = 0; k <= Math.round(Sonar.DURATION / DT); k++) s.bands(DT, null, 0);
        check(s.count() == 0, "passo jogado fora não avançou: " + s.count());
        s.add(1, 1);
        s.clear();
        check(s.count() == 0, "clear");
    }

    /** Os mesmos pontos que o tests/test_mod3_sonar.lua confere no NOM_SonarRules.radius. */
    static void curveMatchesLua() throws Exception {
        int k = 0;
        for (String line : java.nio.file.Files.readAllLines(java.nio.file.Path.of("tests/sonar_curve.csv"))) {
            if (line.isEmpty() || line.startsWith("#")) continue;
            String[] p = line.split(",");
            float ms = Float.parseFloat(p[0]), r = Float.parseFloat(p[1]);
            check(Math.abs(Sonar.radius(ms / 1000f) - r) < 1e-4f, "raio em " + p[0] + " ms: " + Sonar.radius(ms / 1000f));
            k++;
        }
        check(k >= 4, "poucos pontos: " + k);
    }

    static FlowGrid still() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.stillDecay = 0f;
        g.edgeRefill = 0f;
        g.ambient = 1f;
        g.reset(0, 0);
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) g.setDensity(i, j, 1f);
        return g;
    }

    /** Densidade média dos tiles com centro a [r0, r1) de (cx, cy). */
    static float ring(FlowGrid g, float cx, float cy, float r0, float r1) {
        float s = 0;
        int k = 0;
        for (int tj = 0; tj < 64; tj++)
            for (int ti = 0; ti < 64; ti++) {
                double d = Math.hypot(ti + 0.5 - cx, tj + 0.5 - cy);
                if (d >= r0 && d < r1) { s += FlowTravelTest.tileDensity(g, ti, tj); k++; }
            }
        return s / k;
    }

    /** Roda o anel em (cx, cy) com a grade passo a passo, como o Flow.apply, por n passos. */
    static void play(FlowGrid g, Sonar s, int n) {
        float[] out = new float[Sonar.MAX_RINGS * 4];
        for (int k = 0; k < n; k++) {
            int b = s.bands(DT, out, 0);
            for (int q = 0; q < b; q++) g.sonar(out[q * 4], out[q * 4 + 1], out[q * 4 + 2], out[q * 4 + 3]);
            g.step(DT);
        }
    }

    static void frontTravels() {
        FlowGrid g = still();
        Sonar s = new Sonar();
        float cx = 32f, cy = 32f;
        s.add(cx, cy);
        play(g, s, Math.round(Sonar.DURATION / DT / 2));
        float r = Sonar.RANGE / 2;
        float inner = ring(g, cx, cy, 0, r - 1), front = ring(g, cx, cy, r - 0.5f, r + 1.5f), far = ring(g, cx, cy, 14, 24);
        System.out.printf("  meio do caminho (r=%.1f): miolo %.3f, frente %.3f, longe %.3f%n", r, inner, front, far);
        check(inner < 0.85f, "miolo não ficou ralo: " + inner);
        check(front > 1.08f, "não tem monte na frente: " + front);
        check(Math.abs(far - 1f) < 0.02f, "longe mexeu: " + far);
        play(g, s, Math.round(Sonar.DURATION / DT));
        float best = 0;
        int at = -1;
        for (int k = 0; k < 12; k++) {
            float m = ring(g, cx, cy, k, k + 1);
            if (m > best) { best = m; at = k; }
        }
        System.out.printf("  no fim: monte em [%d, %d) tiles, %.3f%n", at, at + 1, best);
        check(at >= Sonar.RANGE - 1 && at <= Sonar.RANGE + 1, "o monte não chegou em RANGE: " + at);
    }

    static void massAndCeiling() {
        FlowGrid g = still();
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) g.setDensity(i, j, 1.45f);
        float m0 = g.totalMass();
        Sonar s = new Sonar();
        s.add(20.3f, 41.7f);
        s.add(40f, 30f);
        float[] out = new float[Sonar.MAX_RINGS * 4];
        while (s.count() > 0) {
            int b = s.bands(DT, out, 0);
            for (int q = 0; q < b; q++) g.sonar(out[q * 4], out[q * 4 + 1], out[q * 4 + 2], out[q * 4 + 3]);
        }
        check(Math.abs(g.totalMass() - m0) / m0 < 1e-3f, "massa mudou: " + m0 + " → " + g.totalMass());
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) check(g.density(i, j) <= 1.5f + 1e-5f, "passou do teto");
        g.sonar(-500f, -500f, 0f, 4f);   // fora da grade: nada
        check(Math.abs(g.totalMass() - m0) / m0 < 1e-3f, "fora da grade mexeu");
    }

    static void wallsUntouched() {
        FlowGrid g = still();
        for (int tj = 28; tj < 36; tj++) {
            g.setTile(36, tj, FlowGrid.F_SOLID);
            g.setTile(28, tj, FlowGrid.F_INDOOR);   // interior novo começa vazio (FlowGrid.setCell)
        }
        float[] solid = new float[8], indoor = new float[8];
        for (int k = 0; k < 8; k++) {
            solid[k] = FlowTravelTest.tileDensity(g, 36, 28 + k);
            indoor[k] = FlowTravelTest.tileDensity(g, 28, 28 + k);
        }
        Sonar s = new Sonar();
        s.add(32f, 32f);
        float[] out = new float[Sonar.MAX_RINGS * 4];
        while (s.count() > 0) {
            int b = s.bands(DT, out, 0);
            for (int q = 0; q < b; q++) g.sonar(out[q * 4], out[q * 4 + 1], out[q * 4 + 2], out[q * 4 + 3]);
        }
        for (int k = 0; k < 8; k++) {
            check(FlowTravelTest.tileDensity(g, 36, 28 + k) == solid[k], "sólido mexeu em " + (28 + k));
            check(FlowTravelTest.tileDensity(g, 28, 28 + k) == indoor[k], "interior mexeu em " + (28 + k));
        }
        check(FlowTravelTest.tileDensity(g, 32, 30) != 1f, "a rua do lado nem mexeu: o teste não testa nada");
    }

    /**
     * Parede comprida a 4 tiles do anel: o lado de trás começa vazio e continua vazio (a névoa da
     * frente vai só na direção radial de cada célula e para na parede). Parede do jogo é face
     * fechada entre tiles (setTileOpenW); sólido é o tile inteiro. A massa total não muda.
     */
    static void noneBehindWall() {
        for (int kind = 0; kind < 2; kind++) {
            FlowGrid g = still();
            int wall = 36, behind = kind == 0 ? wall : wall + 1;
            for (int tj = 0; tj < 64; tj++) {
                if (kind == 0) g.setTileOpenW(wall, tj, false);
                else g.setTile(wall, tj, FlowGrid.F_SOLID);
            }
            for (int j = 0; j < g.n; j++)
                for (int i = behind * g.scale; i < g.n; i++) g.setDensity(i, j, 0f);
            float m0 = g.totalMass();
            Sonar s = new Sonar();
            s.add(32f, 32f);
            float[] out = new float[Sonar.MAX_RINGS * 4];
            while (s.count() > 0) {
                int b = s.bands(DT, out, 0);
                for (int q = 0; q < b; q++) g.sonar(out[q * 4], out[q * 4 + 1], out[q * 4 + 2], out[q * 4 + 3]);
            }
            double back = 0;
            for (int j = 0; j < g.n; j++)
                for (int i = behind * g.scale; i < g.n; i++) back += g.density(i, j);
            String name = kind == 0 ? "face fechada" : "sólido";
            check(back < 1e-6, name + ": névoa atrás da parede: " + back);
            check(Math.abs(g.totalMass() - m0) / m0 < 1e-3f, name + ": massa mudou");
            check(FlowTravelTest.tileDensity(g, wall - 1, 32) > 1.05f, name + ": não amontoou na frente da parede");
        }
    }

    /** Pior caso histórico: 8 anéis grandes num passo (o teto de ripples 0048 é maior; custo separado). */
    static void cost() {
        FlowGrid g = new FlowGrid(128, S);
        g.reset(0, 0);
        int reps = 400;
        int n = 8; // custo do anel de achado; MAX_RINGS agora é teto de ripples
        long t0 = System.nanoTime();
        for (int k = 0; k < reps; k++)
            for (int q = 0; q < n; q++) g.sonar(30f + q * 9, 64f, Sonar.RANGE - 0.3f, Sonar.RANGE);
        double ms = (System.nanoTime() - t0) / 1e6 / reps;
        System.out.printf("  custo: 8 anéis num passo (128 tiles, escala %d): %.3f ms%n", S, ms);
        check(ms < 1.0, "8 anéis custam " + ms + " ms por passo");
    }
}
