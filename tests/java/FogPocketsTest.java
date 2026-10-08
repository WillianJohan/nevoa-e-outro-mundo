import nom.render.FogPockets;

/** Bolsões viajantes (sprint 0047). Sem o jogo. */
public class FogPocketsTest {
    static int passed, failed;

    public static void main(String[] args) {
        run("cobertura rara ~8%", FogPocketsTest::rareCoverage);
        run("aggression 0 = sempre zero", FogPocketsTest::zeroCoverage);
        run("andam com o vento", FogPocketsTest::moveWithWind);
        run("sample em [0, 1]", FogPocketsTest::bounded);
        System.out.println("mod3 bolsões: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void rareCoverage() {
        FogPockets p = new FogPockets(11, 0.08f, 55f);
        int in = 0, total = 0;
        for (int j = 0; j < 300; j++)
            for (int i = 0; i < 300; i++) {
                if (p.sample(i * 7.3, j * 6.9 - 200) > 0.5f) in++;
                total++;
            }
        float cov = in / (float) total;
        check(cov > 0.04f && cov < 0.14f, "cobertura " + cov);
    }

    static void zeroCoverage() {
        FogPockets p = new FogPockets(3, 0f, 55f);
        for (int k = 0; k < 200; k++)
            check(p.sample(k * 3.1, k * -2.7) == 0f, "não zerou");
    }

    static void moveWithWind() {
        FogPockets p = new FogPockets(5, 0.1f, 50f);
        float[] before = new float[400];
        for (int k = 0; k < 400; k++) before[k] = p.sample((k % 20) * 5.0, (k / 20) * 5.0);
        p.advance(2f, 0f, 15f); // 30 tiles leste
        double shifted = 0, still = 0;
        for (int k = 0; k < 400; k++) {
            double x = (k % 20) * 5.0, y = (k / 20) * 5.0;
            shifted += Math.abs(p.sample(x + 30, y) - before[k]);
            still += Math.abs(p.sample(x, y) - before[k]);
        }
        check(shifted < still * 0.35, "não acompanhou o vento: shift=" + shifted + " still=" + still);
    }

    static void bounded() {
        FogPockets p = new FogPockets(9, 0.12f, 40f);
        for (int j = -50; j < 50; j++)
            for (int i = -50; i < 50; i++) {
                float v = p.sample(i * 11.1, j * 9.7);
                check(v >= 0f && v <= 1f, "fora: " + v);
            }
    }
}
