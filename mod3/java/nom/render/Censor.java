package nom.render;

/**
 * Rosto censurado do Sem-rosto (sprint 0044): quais cabeças ganham o quadrado do NOM_Censura.frag.
 * Java puro, sem o jogo: CensorTest. O RenderContext acha o Sem-rosto pela peça que o
 * client/NOM_VariantLook.lua veste (ITEMS) e passa o alfa do zumbi pro jogador local: fora da vista
 * o jogo leva o alfa a 0, e o quadrado não pode entregar quem está atrás da parede ou das costas.
 */
public final class Censor {
    public static final int MAX = 4;                // o mesmo tamanho de uCensor no NOM_RenderContext.glsl
    public static final float RANGE = 20f;          // o mesmo alcance dos personagens da névoa
    public static final float MIN_ALPHA = 0.02f;
    // meio da cabeça, em andares acima dos pés: a lanterna sai em z + 0,4 (RenderContext.collectTorches)
    // e o medidor da pesca vanilla fica em cima da cabeça, em z + 0,6 (client/Fishing/TensionUI.lua:11)
    public static final float HEAD_Z = 0.52f;
    static final String[] ITEMS = { "Base.NOM_SemRostoEstatica", "Base.NOM_SemRostoEstaticaFx" };

    private final float[] best = new float[MAX];
    private final float[] slots = new float[MAX * 4];   // x, y (absolutos), z da cabeça, alfa
    private int count;

    public static boolean isSemRostoItem(String type) {
        if (type == null) return false;
        for (String s : ITEMS) if (s.equals(type)) return true;
        return false;
    }

    public void begin() { count = 0; }

    /** Cabeça candidata em (x, y, z dos pés) com o alfa pro jogador e a distância² até a câmera. */
    public void offer(float x, float y, float z, float alpha, float d2) {
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
        slots[k] = x;
        slots[k + 1] = y;
        slots[k + 2] = z + HEAD_Z;
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
