package nom.render;

/**
 * Anéis do sonar do Estalador (sprint 0037) na névoa fluida. Puro, sem o jogo: a thread principal
 * guarda os anéis e, a cada passo da simulação que manda, anota a faixa que cada frente andou; a
 * thread da simulação aplica com FlowGrid.sonar. Os números são os do shared/NOM_SonarRules.lua
 * (contrato em tests/test_mod3_sonar.lua).
 */
public final class Sonar {
    public static final float RANGE = 8f;        // tiles (NOM_SonarRules.RANGE)
    public static final float DURATION = 1.5f;   // s reais até RANGE (NOM_SonarRules.DURATION_MS)
    public static final int MAX_RINGS = 8;       // NOM_SonarRules.MAX_RINGS
    public static final float TAKE = 0.5f;       // fração da névoa da faixa varrida que a frente leva
    public static final float AHEAD = 1f;        // tiles: largura do monte logo à frente

    private final float[] x = new float[MAX_RINGS], y = new float[MAX_RINGS], age = new float[MAX_RINGS];
    private int count;

    public int count() { return count; }

    public void clear() { count = 0; }

    /** false: cheio (a tela desenha esse). */
    public boolean add(float wx, float wy) {
        if (count >= MAX_RINGS) return false;
        x[count] = wx;
        y[count] = wy;
        age[count] = 0f;
        count++;
        return true;
    }

    public static float radius(float age) {
        if (age <= 0f) return 0f;
        return age >= DURATION ? RANGE : RANGE * age / DURATION;
    }

    /**
     * Avança dt segundos. Escreve (x, y, r0, r1) de cada anel em out a partir de off (out null: só
     * avança, o passo foi jogado fora) e devolve quantos. O anel que chegou em RANGE sai depois.
     */
    public int bands(float dt, float[] out, int off) {
        int k = 0, w = 0;
        for (int i = 0; i < count; i++) {
            float r0 = radius(age[i]);
            age[i] += dt;
            if (out != null) {
                int o = off + k * 4;
                out[o] = x[i];
                out[o + 1] = y[i];
                out[o + 2] = r0;
                out[o + 3] = radius(age[i]);
            }
            k++;
            if (age[i] < DURATION) {
                x[w] = x[i];
                y[w] = y[i];
                age[w] = age[i];
                w++;
            }
        }
        count = w;
        return k;
    }
}
