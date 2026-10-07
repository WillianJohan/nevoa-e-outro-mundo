import nom.render.Blasts;
import nom.render.FlowGrid;

/**
 * Tiro na névoa (sprint 0037c): raio do sopro pelo som, a clareira que abre rápido e fecha em ~4 s,
 * os dois sons do mesmo tiro numa clareira só, teto de clareiras e de log, e o sopro de raio 10 na
 * grade como o jogo liga (escala 2). Sem o jogo.
 */
public class FlowBlastTest {
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("raio do sopro: som 40 -> 10 tiles, 20 -> 5, preso entre 5 e 12", FlowBlastTest::radiusFromSound);
        run("clareira abre em 0,15 s e fecha em 4 s, suave", FlowBlastTest::strengthCurve);
        run("dois sons do mesmo tiro no mesmo tile viram uma clareira só (a maior)", FlowBlastTest::mergeSameTile);
        run("cheio, a clareira mais velha sai; as fechadas somem da lista", FlowBlastTest::capAndExpire);
        run("fill devolve x, y relativos à origem, raio e força", FlowBlastTest::fillRelative);
        run("log do tiro: no máximo 10 por minuto", FlowBlastTest::logBudget);
        run("sopro de raio 10 abre o miolo, o anel recebe e a massa se conserva", FlowBlastTest::bigHole);
        System.out.println("mod3 tiro na névoa: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void radiusFromSound() {
        check(Blasts.radius(40) == 10f, "som 40: " + Blasts.radius(40));
        check(Blasts.radius(20) == 5f, "som 20: " + Blasts.radius(20));
        check(Blasts.radius(100) == 12f, "som 100 não prendeu em 12: " + Blasts.radius(100));
        check(Blasts.radius(8) == 5f, "som 8 não prendeu em 5: " + Blasts.radius(8));
        check(Blasts.radius(30) == 7.5f, "som 30: " + Blasts.radius(30));
    }

    static void strengthCurve() {
        check(Blasts.strength(-0.1f) == 0f, "antes de começar");
        check(Blasts.strength(0.15f) > 0.99f, "não abriu inteira em 0,15 s: " + Blasts.strength(0.15f));
        check(Blasts.strength(0.075f) > 0.3f && Blasts.strength(0.075f) < 0.7f, "meio da abertura: " + Blasts.strength(0.075f));
        check(Blasts.strength(1f) > 0.85f, "fechou rápido demais: " + Blasts.strength(1f));
        check(Blasts.strength(2.15f) > 0.4f && Blasts.strength(2.15f) < 0.6f, "meio do fechamento: " + Blasts.strength(2.15f));
        check(Blasts.strength(4.15f) == 0f, "não fechou em 4,15 s: " + Blasts.strength(4.15f));
        float last = 1f;
        for (float t = 0.15f; t < 4.15f; t += 0.05f) {
            float s = Blasts.strength(t);
            check(s <= last + 1e-6f, "fechamento voltou a abrir em " + t);
            last = s;
        }
    }

    static void mergeSameTile() {
        Blasts b = new Blasts();
        b.add(100.5f, 200.5f, Blasts.radius(20), 10f);
        b.add(100.5f, 200.5f, Blasts.radius(40), 10f);   // a ordem na lista do jogo varia
        float[] out = new float[Blasts.MAX_CLEARS * 4];
        int n = b.fill(out, 10.15f, 0f, 0f);
        check(n == 1, "o tiro virou " + n + " clareiras");
        check(out[2] == 10f, "não ficou o maior raio: " + out[2]);
        b.add(100.5f, 200.5f, 5f, 11f);                    // outro tiro no mesmo tile, 1 s depois
        check(b.fill(out, 11f, 0f, 0f) == 2, "o segundo tiro no mesmo tile não virou outra clareira");
    }

    static void capAndExpire() {
        Blasts b = new Blasts();
        for (int k = 0; k < Blasts.MAX_CLEARS + 3; k++) b.add(10.5f + k, 10.5f, 5f, k * 0.5f);
        float[] out = new float[Blasts.MAX_CLEARS * 4];
        int n = b.fill(out, 5.4f, 0f, 0f);
        check(n <= Blasts.MAX_CLEARS, "passou do teto: " + n);
        for (int i = 0; i < n; i++) check(out[i * 4] >= 13.5f, "a mais velha ficou: x=" + out[i * 4]);
        check(b.fill(out, 100f, 0f, 0f) == 0, "clareiras fechadas ficaram na lista");
    }

    static void fillRelative() {
        Blasts b = new Blasts();
        b.add(1000.5f, 2000.5f, 10f, 3f);
        float[] out = new float[Blasts.MAX_CLEARS * 4];
        check(b.fill(out, 3.5f, 992f, 1984f) == 1, "sumiu");
        check(out[0] == 8.5f && out[1] == 16.5f && out[2] == 10f, "posição/raio: " + out[0] + " " + out[1] + " " + out[2]);
        check(out[3] > 0.95f, "força com 0,5 s: " + out[3]);
    }

    static void logBudget() {
        Blasts.Budget l = new Blasts.Budget(10);
        long t = 5_000_000_000L;
        int ok = 0;
        for (int k = 0; k < 25; k++) if (l.take(t + k * 1_000_000_000L)) ok++;
        check(ok == 10, "em 25 s deixou " + ok + " linhas");
        check(l.take(t + 61_000_000_000L), "depois de um minuto não liberou de novo");
    }

    /** Grade 64 tiles na escala do jogo, fechada nas bordas, névoa cheia (1,0). */
    static FlowGrid full() {
        FlowGrid g = new FlowGrid(64, S);
        g.reset(0, 0);
        for (int k = 0; k < g.n; k++) {
            g.setOpenW(0, k, false); g.setOpenW(g.n, k, false);
            g.setOpenN(k, 0, false); g.setOpenN(k, g.n, false);
        }
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) g.setDensity(i, j, 1f);
        return g;
    }

    static void bigHole() {
        FlowGrid g = full();
        float r = Blasts.radius(40), cx = 32.5f, cy = 32.5f;
        float m0 = g.totalMass();
        g.blast(cx, cy, r);
        float center = FlowScaleTest.tile(g, 32, 32), half = FlowScaleTest.tile(g, 37, 32), ring = FlowScaleTest.tile(g, 45, 32);
        System.out.printf("  raio %.0f: centro %.2f, a 5 tiles %.2f, anel (13 tiles) %.2f%n", r, center, half, ring);
        check(center < 0.2f, "o centro não abriu: " + center);
        check(half < 0.5f, "a 5 tiles (meio raio) ficou cheio: " + half);
        check(ring > 1.2f, "o anel não recebeu: " + ring);
        check(Math.abs(g.totalMass() - m0) / m0 < 1e-3f, "o sopro mudou a massa: " + m0 + " -> " + g.totalMass());
    }
}
