package nom.render;

/**
 * A luz empurra a névoa preta (sprint 0039, spec §8): o facho é um vento constante da lâmpada na
 * direção que aponta; lampião e poste empurram pra todo lado. Puro, sem API do jogo
 * (tests/java/FlowLightWindTest.java): escreve os impulsos (x, y, vx, vy, raio) que o Flow aplica na
 * grade a cada passo, como o foco de vento (FlowGrid.impulse, que também abre o vazio onde sopra).
 */
public final class LightWind {
    public static final float SPEED = 2.5f;                       // tiles/s, o do foco de vento
    public static final float BEAM_REACH = 12f;                   // tiles: o facho empurra até aqui (ou o alcance da luz)
    public static final int BEAM_POINTS = 4;
    public static final float BEAM_R0 = 1.2f, BEAM_R_MAX = 3.5f;  // raio do impulso, crescendo com o cone
    public static final int RING_POINTS = 6;
    public static final float RING_MIN = 1.5f, RING_MAX = 4f;     // raio do anel: metade do alcance, preso
    public static final float RING_R = 1.6f;
    public static final int FLOATS = 5;
    public static final int MAX_PER_LIGHT = Math.max(BEAM_POINTS, RING_POINTS);

    private LightWind() {}

    /**
     * Facho em (x, y) na direção (dx, dy), cone de cosseno dot (TorchDot) e alcance dist: impulsos em
     * out a partir de off, pontos espaçados no alcance, mais perto primeiro. Devolve quantos.
     */
    public static int beam(float x, float y, float dx, float dy, float dot, float dist, float[] out, int off) {
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        if (len < 1e-4f || dist <= 0f) return 0;
        dx /= len;
        dy /= len;
        float reach = Math.min(dist, BEAM_REACH);
        float c = Math.max(0.05f, Math.min(dot, 0.999f));
        float tan = (float) Math.sqrt(1 - c * c) / c;
        for (int k = 0; k < BEAM_POINTS; k++) {
            float t = reach * (k + 0.5f) / BEAM_POINTS;
            int o = off + k * FLOATS;
            out[o] = x + dx * t;
            out[o + 1] = y + dy * t;
            out[o + 2] = dx * SPEED;
            out[o + 3] = dy * SPEED;
            out[o + 4] = Math.max(BEAM_R0, Math.min(BEAM_R_MAX, t * tan));
        }
        return BEAM_POINTS;
    }

    /** Luz sem cone em (x, y) com alcance range: um anel de impulsos soprando pra fora. Devolve quantos. */
    public static int ring(float x, float y, float range, float[] out, int off) {
        float r = Math.max(RING_MIN, Math.min(RING_MAX, range / 2f));
        for (int k = 0; k < RING_POINTS; k++) {
            double a = 2 * Math.PI * k / RING_POINTS;
            float cx = (float) Math.cos(a), cy = (float) Math.sin(a);
            int o = off + k * FLOATS;
            out[o] = x + cx * r;
            out[o + 1] = y + cy * r;
            out[o + 2] = cx * SPEED;
            out[o + 3] = cy * SPEED;
            out[o + 4] = RING_R;
        }
        return RING_POINTS;
    }
}
