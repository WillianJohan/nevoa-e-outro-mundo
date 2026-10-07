import nom.render.FlowGrid;
import nom.render.LightWind;

/** A luz empurra a névoa preta (sprint 0039): os impulsos do facho e do anel, e o efeito na grade. Sem o jogo. */
public class FlowLightWindTest {
    static final float DT = 0.05f;
    static final int S = FlowTravelTest.GAME_SCALE;
    static int passed, failed;

    public static void main(String[] args) {
        run("facho: impulsos na frente da lâmpada, soprando na direção dela", FlowLightWindTest::beamAhead);
        run("facho: nada além do alcance da luz nem de BEAM_REACH; raio cresce com a distância", FlowLightWindTest::beamReach);
        run("facho: direção zero ou sem alcance não sopra", FlowLightWindTest::beamDegenerate);
        run("anel: em volta da luz, soprando pra fora", FlowLightWindTest::ringOut);
        run("grade: a névoa sai da frente do facho e fica atrás da lâmpada", FlowLightWindTest::gridClearsAhead);
        System.out.println("mod3 luz empurra a névoa: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void beamAhead() {
        float[] out = new float[LightWind.MAX_PER_LIGHT * LightWind.FLOATS];
        int n = LightWind.beam(10f, 20f, 0f, 2f, 0.5f, 15f, out, 0);   // pra +y, direção não unitária
        check(n == LightWind.BEAM_POINTS, "pontos do facho: " + n);
        for (int k = 0; k < n; k++) {
            int o = k * LightWind.FLOATS;
            check(Math.abs(out[o] - 10f) < 1e-4, "saiu da linha do facho: x " + out[o]);
            check(out[o + 1] > 20f, "impulso atrás da lâmpada: y " + out[o + 1]);
            check(Math.abs(out[o + 2]) < 1e-4 && Math.abs(out[o + 3] - LightWind.SPEED) < 1e-4,
                    "sopro fora da direção: " + out[o + 2] + "," + out[o + 3]);
        }
    }

    static void beamReach() {
        float[] out = new float[LightWind.MAX_PER_LIGHT * LightWind.FLOATS];
        int n = LightWind.beam(0f, 0f, 1f, 0f, 0.5f, 6f, out, 0);
        float last = 0, prevR = 0;
        for (int k = 0; k < n; k++) {
            int o = k * LightWind.FLOATS;
            check(out[o] + out[o + 4] <= 6f + LightWind.BEAM_R_MAX, "passou do alcance da luz: " + out[o]);
            check(out[o] > last, "pontos fora de ordem");
            check(out[o + 4] >= prevR && out[o + 4] >= LightWind.BEAM_R0 && out[o + 4] <= LightWind.BEAM_R_MAX,
                    "raio: " + out[o + 4]);
            last = out[o];
            prevR = out[o + 4];
        }
        n = LightWind.beam(0f, 0f, 1f, 0f, 0.5f, 40f, out, 0);
        check(out[(n - 1) * LightWind.FLOATS] <= LightWind.BEAM_REACH, "passou de BEAM_REACH");
    }

    static void beamDegenerate() {
        float[] out = new float[LightWind.MAX_PER_LIGHT * LightWind.FLOATS];
        check(LightWind.beam(0f, 0f, 0f, 0f, 0.5f, 15f, out, 0) == 0, "direção zero soprou");
        check(LightWind.beam(0f, 0f, 1f, 0f, 0.5f, 0f, out, 0) == 0, "sem alcance soprou");
    }

    static void ringOut() {
        float[] out = new float[LightWind.MAX_PER_LIGHT * LightWind.FLOATS];
        int n = LightWind.ring(5f, 5f, 8f, out, 0);
        check(n == LightWind.RING_POINTS, "pontos do anel: " + n);
        float sx = 0, sy = 0;
        for (int k = 0; k < n; k++) {
            int o = k * LightWind.FLOATS;
            float dx = out[o] - 5f, dy = out[o + 1] - 5f;
            float r = (float) Math.hypot(dx, dy);
            check(r >= LightWind.RING_MIN - 1e-4 && r <= LightWind.RING_MAX + 1e-4, "raio do anel: " + r);
            check(out[o + 2] * dx + out[o + 3] * dy > 0, "sopra pra dentro");
            check(Math.abs(Math.hypot(out[o + 2], out[o + 3]) - LightWind.SPEED) < 1e-3, "velocidade do anel");
            sx += out[o + 2];
            sy += out[o + 3];
        }
        check(Math.abs(sx) < 1e-3 && Math.abs(sy) < 1e-3, "o anel empurra mais pra um lado: " + sx + "," + sy);
    }

    static float mean(FlowGrid g, int i0, int i1, int j0, int j1) {
        float s = 0;
        int n = 0;
        for (int j = j0; j <= j1; j++) for (int i = i0; i <= i1; i++) { s += FlowTravelTest.tileDensity(g, i, j); n++; }
        return s / n;
    }

    static void gridClearsAhead() {
        FlowGrid g = FlowTravelTest.travelScaled(64, S);
        g.stillDecay = 0f;
        g.edgeRefill = 0f;
        g.ambient = 1f;
        g.reset(0, 0);
        for (int j = 0; j < g.n; j++) for (int i = 0; i < g.n; i++) g.setDensity(i, j, 1f);
        float[] out = new float[LightWind.MAX_PER_LIGHT * LightWind.FLOATS];
        for (int s = 0; s < 60; s++) {
            int n = LightWind.beam(20.5f, 32.5f, 1f, 0f, 0.5f, 15f, out, 0);
            for (int k = 0; k < n; k++) {
                int o = k * LightWind.FLOATS;
                g.impulse(out[o], out[o + 1], out[o + 2], out[o + 3], out[o + 4]);
            }
            g.step(DT);
        }
        float ahead = mean(g, 22, 28, 31, 33), behind = mean(g, 13, 18, 31, 33);
        System.out.printf("  facho: névoa na frente %.3f, atrás %.3f%n", ahead, behind);
        check(ahead < behind - 0.15f, "a névoa não saiu da frente do facho: " + ahead + " vs " + behind);
    }
}
