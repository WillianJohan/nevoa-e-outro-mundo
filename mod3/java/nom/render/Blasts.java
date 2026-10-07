package nom.render;

/**
 * Tiro e explosão na névoa (sprint 0037c): o raio do sopro pelo alcance do som e as clareiras que o
 * shader abre por cima de tudo (véu de fundo, rolos e fluido). Java puro, sem o jogo: FlowBlastTest.
 *
 * Por que clareira além do sopro no fluido: perto do jogador o fluido já está quase vazio (o próprio
 * personagem cava o rastro) e o véu de fundo (HAZE no NOM_VolFog.frag) não depende do fluido, então só
 * o sopro não aparecia na tela. A clareira abre a névoa inteira no raio e fecha devagar.
 */
public final class Blasts {
    static final float PER_SOUND = 0.25f;               // pistola (som 40) -> 10 tiles; som 20 -> 5
    static final float MIN_RADIUS = 5f, MAX_RADIUS = 12f;
    static final float OPEN_S = 0.15f, CLOSE_S = 4f;    // abre rápido, fecha devagar (segundos de simulação)
    public static final int MAX_CLEARS = 8;             // o mesmo tamanho de uClears no NOM_RenderContext.glsl

    private final float[] clears = new float[MAX_CLEARS * 4];   // x, y, raio, início
    private int count;

    public static float radius(int soundRadius) {
        return Math.max(MIN_RADIUS, Math.min(MAX_RADIUS, soundRadius * PER_SOUND));
    }

    public void clear() { count = 0; }

    /** Força da clareira (0..1) com a idade em segundos. */
    public static float strength(float age) {
        if (age < 0f || age >= OPEN_S + CLOSE_S) return 0f;
        if (age < OPEN_S) return smooth(age / OPEN_S);
        return 1f - smooth((age - OPEN_S) / CLOSE_S);
    }

    private static float smooth(float t) { return t * t * (3f - 2f * t); }

    /**
     * Clareira nova em (x, y). Os sons do mesmo tiro (pistola: raio 40 e 20 no mesmo tile, no mesmo
     * instante) viram uma só, com o maior raio. Cheio, a mais velha sai.
     */
    public void add(float x, float y, float r, float now) {
        int slot = -1;
        for (int i = 0; i < count; i++) {
            int k = i * 4;
            if (clears[k] == x && clears[k + 1] == y && now - clears[k + 3] < OPEN_S) {
                clears[k + 2] = Math.max(clears[k + 2], r);
                return;
            }
        }
        if (count < MAX_CLEARS) slot = count++;
        else {
            slot = 0;
            for (int i = 1; i < MAX_CLEARS; i++) if (clears[i * 4 + 3] < clears[slot * 4 + 3]) slot = i;
        }
        int k = slot * 4;
        clears[k] = x;
        clears[k + 1] = y;
        clears[k + 2] = r;
        clears[k + 3] = now;
    }

    /**
     * Escreve as clareiras vivas em `out` (x, y relativos à origem, raio, força) e devolve quantas.
     * As que já fecharam saem da lista.
     */
    public int fill(float[] out, float now, float originX, float originY) {
        int n = 0;
        for (int i = 0; i < count; ) {
            int k = i * 4;
            float s = strength(now - clears[k + 3]);
            if (s <= 0f && now - clears[k + 3] >= OPEN_S) {
                count--;
                System.arraycopy(clears, count * 4, clears, k, 4);
                continue;
            }
            int o = n++ * 4;
            out[o] = clears[k] - originX;
            out[o + 1] = clears[k + 1] - originY;
            out[o + 2] = clears[k + 2];
            out[o + 3] = s;
            i++;
        }
        return n;
    }

    /** Teto de linhas de log: no máximo `perMinute` a cada 60 s. */
    public static final class Budget {
        private final int perMinute;
        private long windowStart = Long.MIN_VALUE;
        private int used;

        public Budget(int perMinute) { this.perMinute = perMinute; }

        public boolean take(long nanos) {
            if (windowStart == Long.MIN_VALUE || nanos - windowStart >= 60_000_000_000L) {
                windowStart = nanos;
                used = 0;
            }
            if (used >= perMinute) return false;
            used++;
            return true;
        }
    }
}
