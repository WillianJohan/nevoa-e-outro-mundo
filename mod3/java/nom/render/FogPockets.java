package nom.render;

import java.util.Arrays;

/**
 * Bolsões densos viajantes (sprint 0047): ruído de mundo com cobertura baixa, escala grande,
 * levado pelo vento como {@link FogBanks}. Puro — tests/java/FogPocketsTest.java.
 */
public final class FogPockets {
    static final float SOFT = 0.08f;
    static final float MORPH_RATE = 1f / 80f;

    public final float scale;
    private final int seed;
    private final float threshold;
    private final float coverage;
    private double offX, offY;
    private float morph;

    public FogPockets(int seed, float coverage, float scale) {
        this.seed = seed;
        this.scale = scale;
        this.coverage = Math.max(0f, Math.min(1f, coverage));
        if (this.coverage <= 0f) {
            threshold = 2f; // sample sempre 0
            return;
        }
        float[] s = new float[4096];
        for (int k = 0; k < s.length; k++) s[k] = fbm((k % 64) * 0.731, (k / 64) * 0.677, 0f);
        Arrays.sort(s);
        threshold = s[Math.max(0, Math.min(s.length - 1, Math.round((1f - this.coverage) * s.length)))];
    }

    public void advance(float windX, float windY, float dt) {
        offX += windX * dt;
        offY += windY * dt;
        morph += MORPH_RATE * dt;
    }

    public double offsetX() { return offX; }
    public double offsetY() { return offY; }
    public float morph() { return morph; }
    public float threshold() { return threshold; }
    public float soft() { return SOFT; }
    public int seed() { return seed; }
    public float coverage() { return coverage; }

    /** Força do bolsão no ponto do mundo: 0 (fora) a 1 (miolo). */
    public float sample(double x, double y) {
        if (coverage <= 0f) return 0f;
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
