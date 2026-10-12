package nom.render;

/**
 * Rosto censurado do Sem-rosto (sprint 0044; 0060f: cabeça pelo osso, sem casca-ovo).
 * Java puro, sem o jogo: CensorTest. O RenderContext marca o Sem-rosto pelo ModData
 * {@code NOM_semrosto} (client/NOM_VariantLook.lua) e passa o alfa do zumbi pro jogador
 * local: fora da vista o jogo leva o alfa a 0, e o quadrado não pode entregar quem está
 * atrás da parede ou das costas.
 *
 * Causa raiz do quadrado flutuando (prints 09/11): {@code offer} usava pés + {@link #HEAD_Z}
 * fixo, ignorando animação (caído/rastejando a cabeça vai pro chão e pra frente) e o osso
 * {@code Bip01_Head}. Agora a cabeça chega já em coords de mundo ({@link #offerHead}); o
 * fallback puro é {@link #estimateHead}.
 */
public final class Censor {
    public static final int MAX = 4;                // o mesmo tamanho de uCensor no NOM_RenderContext.glsl
    public static final float RANGE = 20f;          // o mesmo alcance dos personagens da névoa
    public static final float MIN_ALPHA = 0.02f;
    // meio da cabeça em pé, em andares acima dos pés (lanterna 0,4; UI pesca 0,6)
    public static final float HEAD_Z = 0.52f;
    // cabeça baixa (prone/crawl/knocked): perto do chão
    public static final float HEAD_Z_PRONE = 0.12f;
    // avanço da cabeça no chão ao longo do forward (tiles)
    public static final float HEAD_XY_PRONE = 0.45f;
    /** ModData que o VariantLook grava enquanto o Sem-rosto está pintado (sem peça 3D). */
    public static final String MODDATA_KEY = "NOM_semrosto";

    private final float[] best = new float[MAX];
    private final float[] slots = new float[MAX * 4];   // x, y (absolutos), z da cabeça, alfa
    private int count;

    /**
     * Estimativa pura da cabeça sem o osso: em pé = pés + {@link #HEAD_Z}; baixo =
     * pés + forward·{@link #HEAD_XY_PRONE} e {@link #HEAD_Z_PRONE}.
     */
    public static void estimateHead(float x, float y, float z, boolean low,
                                    float fwdX, float fwdY, float[] out) {
        if (!low) {
            out[0] = x;
            out[1] = y;
            out[2] = z + HEAD_Z;
            return;
        }
        float len = (float) Math.sqrt(fwdX * fwdX + fwdY * fwdY);
        if (len < 1e-4f) {
            fwdX = 1f;
            fwdY = 0f;
            len = 1f;
        }
        out[0] = x + fwdX / len * HEAD_XY_PRONE;
        out[1] = y + fwdY / len * HEAD_XY_PRONE;
        out[2] = z + HEAD_Z_PRONE;
    }

    public void begin() { count = 0; }

    /** Cabeça já em coords de mundo (osso Bip01_Head ou {@link #estimateHead}). */
    public void offerHead(float hx, float hy, float hz, float alpha, float d2) {
        if (alpha < MIN_ALPHA || d2 > RANGE * RANGE) return;
        int slot;
        if (count < MAX) slot = count++;
        else {
            slot = 0;
            for (int i = 1; i < MAX; i++) if (best[i] > best[slot]) slot = i;
            if (best[slot] <= d2) return;
        }
        best[slot] = d2;
        int k = slot * 4;
        slots[k] = hx;
        slots[k + 1] = hy;
        slots[k + 2] = hz;
        slots[k + 3] = Math.min(1f, alpha);
    }

    /** Escreve x, y relativos à origem, z da cabeça e alfa; devolve quantas. */
    public int fill(float[] out, float originX, float originY) {
        for (int i = 0; i < count; i++) {
            int k = i * 4;
            out[k] = slots[k] - originX;
            out[k + 1] = slots[k + 1] - originY;
            out[k + 2] = slots[k + 2];
            out[k + 3] = slots[k + 3];
        }
        return count;
    }
}
