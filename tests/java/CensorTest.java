import nom.render.Censor;

/**
 * Rosto censurado do Sem-rosto (sprint 0044): quem ganha o quadrado (só o item do Sem-rosto, visível pro
 * jogador, no alcance), os mais perto quando passa do teto, e o que vai pro shader (x, y relativos à
 * origem, z no meio da cabeça, alfa). Sem o jogo.
 */
public class CensorTest {
    static int passed, failed;

    public static void main(String[] args) {
        run("só a peça do Sem-rosto (e o gêmeo Fx) conta", CensorTest::itemTypes);
        run("zumbi invisível pro jogador ou longe não ganha quadrado", CensorTest::filters);
        run("cheio, fica o mais perto", CensorTest::nearestWins);
        run("fill: relativo à origem, z no meio da cabeça, alfa preso em 1", CensorTest::fillRelative);
        run("begin zera o quadro anterior", CensorTest::beginResets);
        System.out.println("mod3 rosto censurado: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void itemTypes() {
        check(Censor.isSemRostoItem("Base.NOM_SemRostoEstatica"), "peça");
        check(Censor.isSemRostoItem("Base.NOM_SemRostoEstaticaFx"), "gêmeo Fx");
        check(!Censor.isSemRostoItem("Base.NOM_CorredorBoca"), "outra variante");
        check(!Censor.isSemRostoItem("Base.Hat_BalaclavaFull"), "balaclava vanilla");
        check(!Censor.isSemRostoItem(null), "item sem tipo");
    }

    static void filters() {
        Censor c = new Censor();
        c.begin();
        c.offer(10f, 10f, 0f, 0f, 4f);                                   // fora da vista: alfa 0
        c.offer(10f, 10f, 0f, 1f, (Censor.RANGE + 1f) * (Censor.RANGE + 1f));
        c.offer(10f, 10f, 0f, Censor.MIN_ALPHA * 0.5f, 4f);
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 0, "entrou quem não devia");
        c.offer(10f, 10f, 0f, 0.5f, 4f);
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 1, "o visível e perto não entrou");
    }

    static void nearestWins() {
        Censor c = new Censor();
        c.begin();
        for (int i = 0; i < Censor.MAX; i++) c.offer(100f + i, 0f, 0f, 1f, 50f + i);
        c.offer(1f, 2f, 0f, 1f, 1f);                                     // o mais perto expulsa o mais longe
        c.offer(9f, 9f, 0f, 1f, 999f);                                   // mais longe que todos: fica fora
        float[] out = new float[Censor.MAX * 4];
        check(c.fill(out, 0f, 0f) == Censor.MAX, "teto");
        boolean near = false, far = false;
        for (int i = 0; i < Censor.MAX; i++) {
            if (out[i * 4] == 1f) near = true;
            if (out[i * 4] == 100f + Censor.MAX - 1 || out[i * 4] == 9f) far = true;
        }
        check(near && !far, "o mais perto não ficou ou o mais longe ficou");
    }

    static void fillRelative() {
        Censor c = new Censor();
        c.begin();
        c.offer(10300.5f, 9700.25f, 1f, 3f, 4f);
        float[] out = new float[Censor.MAX * 4];
        check(c.fill(out, 10240f, 9472f) == 1, "contagem");
        check(out[0] == 60.5f && out[1] == 228.25f, "x, y relativos: " + out[0] + ", " + out[1]);
        check(Math.abs(out[2] - (1f + Censor.HEAD_Z)) < 1e-6f, "z do meio da cabeça: " + out[2]);
        check(out[3] == 1f, "alfa acima de 1 não prendeu: " + out[3]);
        check(Censor.HEAD_Z > 0.4f && Censor.HEAD_Z < 0.6f, "cabeça entre a lanterna (0,4) e o alto (0,6): " + Censor.HEAD_Z);
    }

    static void beginResets() {
        Censor c = new Censor();
        c.begin();
        c.offer(1f, 1f, 0f, 1f, 1f);
        c.begin();
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 0, "sobrou do quadro anterior");
    }
}
