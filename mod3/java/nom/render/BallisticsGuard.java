package nom.render;

/**
 * Crash nativo ao mirar arma de fogo (hs_err 18/10, SIGSEGV em
 * {@code PZBallisticsTarget::updateSkeletonBoneTransforms}). Java puro, sem o jogo:
 * BallisticsGuardTest. O RenderContext lê os campos do BallisticsTarget por reflexão antes
 * do updateSkeleton e aplica a resposta daqui.
 *
 * Causa (playtests 18/10 13:10 e 13:18): o {@code initialize()} vanilla tira
 * {@code numberOfBones} do AnimationPlayer (ossos do modelo), mas o
 * {@code getBoneTransforms()} só escreve os {@code SkeletonBone.all()} (35) e o Bullet espera
 * isso. Zumbi normal: 35 = 35. Zumbi esqueleto ({@code setSkeleton(true)}, as almas): 45 no
 * modelo, o C++ lê 10 ossos além do fim (0x1680 = 45 × 128 nos três hs_err). Mandar só os
 * ossos escritos deixa o esqueleto igual a um zumbi normal pro Bullet.
 */
public final class BallisticsGuard {
    private BallisticsGuard() { }

    /** Floats por osso no boneTransformData (posição xyz + quaternião xyzw). */
    public static final int FLOATS_PER_BONE = 7;

    /**
     * Quantos ossos mandar pro Bullet, ou -1 pra pular o updateSkeleton (alvo sem ossos
     * prontos: o add() vanilla ignora o initialize() falho). Nunca mais que os escritos.
     */
    public static int bonesToSend(int numberOfBones, int playerBones, int dataLength, int writtenBones) {
        if (numberOfBones <= 0 || writtenBones <= 0 || playerBones <= 0) return -1;
        // a contagem do modelo, ou a que este guard já baixou num quadro anterior
        if (numberOfBones != playerBones && numberOfBones != Math.min(playerBones, writtenBones)) return -1;
        if (dataLength < writtenBones * FLOATS_PER_BONE) return -1;
        return Math.min(numberOfBones, writtenBones);
    }
}
