package nom.render;

/**
 * Crash nativo ao mirar arma de fogo (hs_err 18/10, SIGSEGV em
 * {@code PZBallisticsTarget::updateSkeletonBoneTransforms}). O
 * {@code BallisticsTarget.add()} vanilla ignora o retorno de {@code initialize()}: se o
 * personagem ainda não tem ossos prontos, o {@code numberOfBones} fica em -1 (alvo novo do
 * pool) ou com o valor de outro personagem, e o C++ lê fora do array. Java puro, sem o jogo:
 * BallisticsGuardTest. O RenderContext lê os campos por reflexão e pula o updateSkeleton
 * quando a regra diz não.
 */
public final class BallisticsGuard {
    private BallisticsGuard() { }

    /** Floats por osso no boneTransformData (posição xyz + quaternião xyzw). */
    public static final int FLOATS_PER_BONE = 7;

    /**
     * true se dá pra mandar o esqueleto pro Bullet: contagem positiva, igual à do
     * AnimationPlayer de agora e com espaço no array pra todos os ossos que o Java escreve.
     */
    public static boolean bonesOk(int numberOfBones, int playerBones, int dataLength, int writtenBones) {
        if (numberOfBones <= 0 || playerBones != numberOfBones) return false;
        int needed = Math.max(numberOfBones, writtenBones) * FLOATS_PER_BONE;
        return dataLength >= needed;
    }
}
