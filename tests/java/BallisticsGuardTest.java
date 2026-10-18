import nom.render.BallisticsGuard;

/** Guarda do esqueleto da balística (hotfix pós-1.0.1). Sem o jogo. */
public class BallisticsGuardTest {
    static int passed, failed;

    public static void main(String[] args) {
        run("zumbi normal (35 = 35) manda os 35", () -> eq(35, BallisticsGuard.bonesToSend(35, 35, 315, 35)));
        run("zumbi esqueleto (45 no modelo) manda só os 35 escritos (playtest 18/10)",
            () -> eq(35, BallisticsGuard.bonesToSend(45, 45, 315, 35)));
        run("esqueleto já ajustado no quadro anterior (35 contra 45) segue com 35",
            () -> eq(35, BallisticsGuard.bonesToSend(35, 45, 315, 35)));
        run("alvo novo sem initialize (-1) pula", () -> eq(-1, BallisticsGuard.bonesToSend(-1, 35, 315, 35)));
        run("zero ossos pula", () -> eq(-1, BallisticsGuard.bonesToSend(0, 0, 315, 35)));
        run("contagem velha de outro personagem pula", () -> eq(-1, BallisticsGuard.bonesToSend(40, 45, 315, 35)));
        run("array menor que os ossos escritos pula", () -> eq(-1, BallisticsGuard.bonesToSend(35, 35, 35 * 7 - 1, 35)));
        System.out.println("mod3 balística: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void eq(int want, int got) { if (want != got) throw new AssertionError("esperava " + want + ", veio " + got); }
}
