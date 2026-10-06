import java.util.Random;

import nom.render.FlowGrid;
import nom.render.WindSource;

/** Foco de vento (sprint 0033, NOMRender_setParam(11, 1)): sorteio do foco e o sopro constante na grade. Sem o jogo. */
public class FlowWindSourceTest {
    static final float DT = 0.05f;
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("pickSource: distância em [15, 30] e velocidade SOURCE_SPEED", FlowWindSourceTest::pickRange);
        run("pickSource: sorteios diferentes variam o ponto e a direção", FlowWindSourceTest::pickVaries);
        run("foco sopra constante: velocidade perto do foco na direção do sopro e maior que longe", FlowWindSourceTest::blowsNearFocus);
        System.out.println("mod3 foco de vento: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void pickRange() {
        Random r = new Random(1);
        for (int k = 0; k < 500; k++) {
            float px = 100f + k, py = -50f + 3 * k;
            WindSource w = WindSource.pick(px, py, r);
            double d = Math.hypot(w.x - px, w.y - py);
            check(d >= WindSource.MIN_DIST - 1e-3 && d <= WindSource.MAX_DIST + 1e-3, "distância fora de [15, 30]: " + d);
            double sp = Math.hypot(w.vx, w.vy);
            check(Math.abs(sp - WindSource.SPEED) < 1e-3, "velocidade diferente de SOURCE_SPEED: " + sp);
        }
        check(WindSource.MIN_DIST == 15f && WindSource.MAX_DIST == 30f && WindSource.SPEED == 2.5f && WindSource.RADIUS == 4f,
                "constantes diferentes da spec");
    }

    static void pickVaries() {
        Random r = new Random(7);
        WindSource a = WindSource.pick(0, 0, r), b = WindSource.pick(0, 0, r);
        check(a.x != b.x || a.y != b.y, "dois sorteios deram o mesmo ponto");
        check(a.vx != b.vx || a.vy != b.vy, "dois sorteios deram a mesma direção");
    }

    /** Componente de (u, v) do tile na direção (dx, dy), unitária. */
    static float along(FlowGrid g, int ti, int tj, float dx, float dy) {
        return FlowTravelTest.tileU(g, ti, tj) * dx + FlowTravelTest.tileV(g, ti, tj) * dy;
    }

    static void blowsNearFocus() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.stillDecay = 0f;
        g.edgeRefill = 0f;
        g.ambient = 1f;
        g.reset(0, 0);
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) g.setDensity(i, j, 1f);
        float fx = 20.5f, fy = 32.5f;
        float vx = WindSource.SPEED * 0.8f, vy = WindSource.SPEED * 0.6f;     // módulo SPEED
        for (int s = 0; s < 60; s++) {
            g.impulse(fx, fy, vx, vy, WindSource.RADIUS);
            g.step(DT);
        }
        float dx = 0.8f, dy = 0.6f;
        float near = 0, far = 0;
        int nNear = 0, nFar = 0;
        for (int tj = 0; tj < 64; tj++) {
            for (int ti = 0; ti < 64; ti++) {
                double d = Math.hypot(ti + 0.5 - fx, tj + 0.5 - fy);
                if (d <= 6) { near += along(g, ti, tj, dx, dy); nNear++; }
                else if (d >= 25) { far += along(g, ti, tj, dx, dy); nFar++; }
            }
        }
        near /= nNear;
        far /= nFar;
        System.out.printf("  foco: velocidade média na direção do sopro, perto %.3f, longe %.3f%n", near, far);
        check(near > 0.3f, "perto do foco o ar não anda na direção do sopro: " + near);
        check(near > far + 0.2f, "perto do foco não é maior que longe: " + near + " vs " + far);
    }
}
