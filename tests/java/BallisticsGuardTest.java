import nom.render.BallisticsGuard;

/** Guarda do esqueleto da balística (hotfix pós-1.0.1). Sem o jogo. */
public class BallisticsGuardTest {
    static int passed, failed;

    public static void main(String[] args) {
        run("contagem válida passa", () -> check(BallisticsGuard.bonesOk(60, 60, 60 * 7, 60), "60 ossos"));
        run("alvo novo sem initialize (-1) não passa", () -> check(!BallisticsGuard.bonesOk(-1, 60, 420, 60), "-1"));
        run("zero ossos não passa", () -> check(!BallisticsGuard.bonesOk(0, 0, 420, 60), "0"));
        run("contagem velha de outro personagem não passa", () -> check(!BallisticsGuard.bonesOk(60, 72, 72 * 7, 60), "60 vs 72"));
        run("array curto não passa", () -> check(!BallisticsGuard.bonesOk(60, 60, 60 * 7 - 1, 60), "curto"));
        run("Java escreve mais ossos que cabem não passa", () -> check(!BallisticsGuard.bonesOk(60, 60, 60 * 7, 61), "61 escritos"));
        System.out.println("mod3 balística: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }
}
