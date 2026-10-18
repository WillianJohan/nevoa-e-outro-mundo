package nom.render;

/**
 * Crash nativo ao mirar arma de fogo (hs_err 18/10, SIGSEGV em
 * {@code PZBallisticsTarget::updateSkeletonBoneTransforms}). O
 * {@code BallisticsTarget.add()} vanilla ignora o retorno de {@code initialize()}: se o
 * personagem ainda não tem ossos prontos, o {@code numberOfBones} fica em -1 (alvo novo do
 * pool) ou com o valor de outro personagem, e o C++ lê fora do array. Java puro, sem o jogo:
 * BallisticsGuardTest. O RenderContext lê os campos por reflexão e pula o updateSkeleton
 * quando a regra diz não.
 *
 * Playtest 18/10 13:10: o primeiro alvo da mira foi uma alma ({@code setSkeleton(true)}) com
 * contagem coerente (45 ossos no AnimationPlayer, 35 escritos pelo Java) e mesmo assim o C++
 * crashou. Nos três hs_err o deslocamento é 0x1680 = 45 × 128 bytes: o esqueleto vanilla do
 * zumbi esqueleto não serve pro Bullet. Zumbi esqueleto fica fora do updateSkeleton.
 */
public final class BallisticsGuard {
    private BallisticsGuard() { }

    /** Floats por osso no boneTransformData (posição xyz + quaternião xyzw). */
    public static final int FLOATS_PER_BONE = 7;

    /**
     * true se dá pra mandar o esqueleto pro Bullet: não é zumbi esqueleto, contagem positiva,
     * igual à do AnimationPlayer de agora e com espaço no array pra todos os ossos que o Java
     * escreve.
     */
    public static boolean bonesOk(boolean skeleton, int numberOfBones, int playerBones, int dataLength, int writtenBones) {
        if (skeleton) return false;
        if (numberOfBones <= 0 || playerBones != numberOfBones) return false;
        int needed = Math.max(numberOfBones, writtenBones) * FLOATS_PER_BONE;
        return dataLength >= needed;
    }
}
