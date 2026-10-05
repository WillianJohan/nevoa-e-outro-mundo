package nom.render;

import java.util.Arrays;

/**
 * Bancos de névoa: de onde vem a névoa que entra na grade. Um ruído no mundo (tiles), com limiar
 * calibrado pra cobrir uma fração do chão e o resto ficar em vácuo, levado pelo vento médio e mudando
 * de forma devagar. Puro, sem API do jogo (tests/java/FlowTravelTest.java).
 */
public final class FogBanks {
    static final float SOFT = 0.06f;      // largura da borda do banco, em unidades do ruído
    static final float MORPH_RATE = 1f / 50f;

    public final float scale;             // tiles por banco (grosso modo)
    private final int seed;
    private final float threshold;
    private double offX, offY;
    private float morph;

    public FogBanks(int seed, float coverage, float scale) {
        this.seed = seed;
        this.scale = scale;
        float[] s = new float[4096];
        for (int k = 0; k < s.length; k++) s[k] = fbm((k % 64) * 0.731, (k / 64) * 0.677, 0f);
        Arrays.sort(s);
        threshold = s[Math.max(0, Math.min(s.length - 1, Math.round((1f - coverage) * s.length)))];
    }

    /** O desenho anda com o vento (tiles/s) e muda de forma devagar. */
    public void advance(float windX, float windY, float dt) {
        offX += windX * dt;
        offY += windY * dt;
        morph += MORPH_RATE * dt;
    }

    /** Quanto o vento já levou o desenho (tiles); o shader anda o ruído dos rolos junto. */
    public double offsetX() { return offX; }

    public double offsetY() { return offY; }

    /** Densidade dos bancos no ponto do mundo: 0 (vácuo) a 1 (banco cheio). */
    public float sample(double x, double y) {
        float n = fbm((x - offX) / scale, (y - offY) / scale, morph);
        float t = (n - threshold + SOFT) / (2f * SOFT);
        t = t < 0f ? 0f : (t > 1f ? 1f : t);
        return t * t * (3f - 2f * t);
    }

    private float fbm(double x, double y, float z) {
        return 0.6f * noise(x, y, z) + 0.3f * noise(x * 2.03 + 17.1, y * 2.03 - 5.3, z * 1.7f)
                + 0.1f * noise(x * 4.1 - 9.7, y * 4.1 + 3.1, z * 2.3f);
    }

    private float noise(double x, double y, float z) {
        int xi = (int) Math.floor(x), yi = (int) Math.floor(y), zi = (int) Math.floor(z);
        float fx = (float) (x - xi), fy = (float) (y - yi), fz = z - zi;
        fx = fx * fx * (3 - 2 * fx);
        fy = fy * fy * (3 - 2 * fy);
        fz = fz * fz * (3 - 2 * fz);
        float a = lerp(lerp(hash(xi, yi, zi), hash(xi + 1, yi, zi), fx),
                       lerp(hash(xi, yi + 1, zi), hash(xi + 1, yi + 1, zi), fx), fy);
        float b = lerp(lerp(hash(xi, yi, zi + 1), hash(xi + 1, yi, zi + 1), fx),
                       lerp(hash(xi, yi + 1, zi + 1), hash(xi + 1, yi + 1, zi + 1), fx), fy);
        return lerp(a, b, fz);
    }

    private static float lerp(float a, float b, float t) { return a + (b - a) * t; }

    private float hash(int x, int y, int z) {
        int h = x * 374761393 + y * 668265263 + z * 1274126177 + seed * 1442695041;
        h = (h ^ (h >>> 13)) * 1274126177;
        h ^= h >>> 16;
        return (h & 0xffffff) / (float) 0xffffff;
    }
}
