package nom.render;

/**
 * Anéis do sonar do Estalador na névoa fluida. Puro, sem o jogo: a thread principal
 * guarda os anéis e, a cada passo da simulação que manda, anota a faixa que cada frente andou; a
 * thread da simulação aplica com FlowGrid.sonar. Os números são os do shared/NOM_SonarRules.lua
 * (contrato em tests/test_mod3_sonar.lua).
 *
 * Sprint 0037: anel de achado RANGE/DURATION (ainda usado em testes e add()).
 * Sprint 0048: ripples curtos (RIPPLE_*) no ritmo do burst; a tela/mod3 usa addRipple;
 * MAX_RINGS sobe pro teto de ripples (MAX_RIPPLES no Lua).
 */
public final class Sonar {
    public static final float RANGE = 8f;        // tiles (NOM_SonarRules.RANGE) — achado / legado
    public static final float DURATION = 1.5f;   // s reais até RANGE (NOM_SonarRules.DURATION_MS)
    public static final float RIPPLE_RANGE = 3f; // NOM_SonarRules.RIPPLE_RANGE
    public static final float RIPPLE_DURATION = 0.55f; // NOM_SonarRules.RIPPLE_DURATION_MS
    public static final int MAX_RINGS = 36;      // NOM_SonarRules.MAX_RIPPLES (ripples vivos)
    public static final float TAKE = 0.5f;       // fração da névoa da faixa varrida que a frente leva
    public static final float AHEAD = 1f;        // tiles: largura do monte logo à frente

    private final float[] x = new float[MAX_RINGS], y = new float[MAX_RINGS], age = new float[MAX_RINGS];
    private final float[] range = new float[MAX_RINGS], duration = new float[MAX_RINGS];
    private int count;

    public int count() { return count; }

    public void clear() { count = 0; }

    /** Anel grande (legado / testes). false: cheio. */
    public boolean add(float wx, float wy) {
        return add(wx, wy, RANGE, DURATION);
    }

    /** Ripple curto de presença (sprint 0048). */
    public boolean addRipple(float wx, float wy) {
        return add(wx, wy, RIPPLE_RANGE, RIPPLE_DURATION);
    }

    private boolean add(float wx, float wy, float r, float d) {
        if (count >= MAX_RINGS) return false;
        x[count] = wx;
        y[count] = wy;
        age[count] = 0f;
        range[count] = r;
        duration[count] = d;
        count++;
        return true;
    }

    public static float radius(float age) {
        return radius(age, RANGE, DURATION);
    }

    public static float radius(float age, float range, float duration) {
        if (age <= 0f) return 0f;
        return age >= duration ? range : range * age / duration;
    }

    /**
     * Avança dt segundos. Escreve (x, y, r0, r1) de cada anel em out a partir de off (out null: só
     * avança, o passo foi jogado fora) e devolve quantos. O anel que chegou no próprio range sai depois.
     */
    public int bands(float dt, float[] out, int off) {
        int k = 0, w = 0;
        for (int i = 0; i < count; i++) {
            float r0 = radius(age[i], range[i], duration[i]);
            age[i] += dt;
            if (out != null) {
                int o = off + k * 4;
                out[o] = x[i];
                out[o + 1] = y[i];
                out[o + 2] = r0;
                out[o + 3] = radius(age[i], range[i], duration[i]);
            }
            k++;
            if (age[i] < duration[i]) {
                x[w] = x[i];
                y[w] = y[i];
                age[w] = age[i];
                range[w] = range[i];
                duration[w] = duration[i];
                w++;
            }
        }
        count = w;
        return k;
    }
}
