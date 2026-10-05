package nom.render;

/**
 * Vento da névoa: o do clima, com rajadas e a direção vagando por ruído suave. Sem seno, porque seno
 * tem ritmo e a névoa fica mecânica (sprint 0027). Puro, sem API do jogo (tests/java/FlowTravelTest.java).
 */
public final class Wind {
    public float x, y;   // tiles/s
    private final int seed;

    public Wind(int seed) { this.seed = seed; }

    /** Vento no instante t (s): ângulo base do clima (rad) e intensidade do clima (0..1). */
    public void at(float baseAngle, float intensity, float t) {
        float ang = baseAngle + 1.2f * (smooth(t / 30f, 1) - 0.5f) + 0.5f * (smooth(t / 9f, 2) - 0.5f);
        float gust = 1f + 0.7f * (smooth(t / 6f, 3) - 0.5f) + 0.2f * (smooth(t / 2.5f, 4) - 0.5f);
        float speed = (1f + 1.2f * intensity) * gust;
        x = (float) Math.cos(ang) * speed;
        y = (float) Math.sin(ang) * speed;
    }

    /** Ruído 1D de 0 a 1, contínuo até a segunda derivada, que não se repete. */
    float smooth(float t, int salt) {
        int i = (int) Math.floor(t);
        float f = t - i;
        f = f * f * f * (f * (f * 6f - 15f) + 10f);
        float a = hash(i, salt), b = hash(i + 1, salt);
        return a + (b - a) * f;
    }

    private float hash(int i, int salt) {
        int h = i * 374761393 + salt * 668265263 + seed * 1442695041;
        h = (h ^ (h >>> 13)) * 1274126177;
        h ^= h >>> 16;
        return (h & 0xffffff) / (float) 0xffffff;
    }
}
