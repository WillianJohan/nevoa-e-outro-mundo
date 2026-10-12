import nom.render.Censor;

/**
 * Rosto censurado do Sem-rosto (sprint 0044 / 0060f): quem ganha o quadrado (visível,
 * no alcance), os mais perto quando passa do teto, cabeça em coords de mundo (osso ou
 * estimativa em pé/prone), e o que vai pro shader. Sem o jogo.
 */
public class CensorTest {
    static int passed, failed;

    public static void main(String[] args) {
        run("zumbi invisível pro jogador ou longe não ganha quadrado", CensorTest::filters);
        run("cheio, fica o mais perto", CensorTest::nearestWins);
        run("fill: relativo à origem, z absoluto da cabeça, alfa preso em 1", CensorTest::fillRelative);
        run("begin zera o quadro anterior", CensorTest::beginResets);
        run("estimateHead em pé = pés + HEAD_Z (sem offset XY)", CensorTest::estimateStanding);
        run("estimateHead prone = baixo + à frente no forward", CensorTest::estimateProne);
        run("offerHead não soma HEAD_Z de novo", CensorTest::offerHeadAbsolute);
        System.out.println("mod3 rosto censurado: " + passed + " ok, " + failed + " falharam");
        if (failed > 0) System.exit(1);
    }

    interface Case { void run() throws Exception; }

    static void run(String name, Case c) {
        try { c.run(); passed++; }
        catch (Throwable t) { failed++; System.out.println("FALHOU: " + name + ": " + t); }
    }

    static void check(boolean ok, String msg) { if (!ok) throw new AssertionError(msg); }

    static void filters() {
        Censor c = new Censor();
        c.begin();
        c.offerHead(10f, 10f, 0.5f, 0f, 4f);                                   // fora da vista: alfa 0
        c.offerHead(10f, 10f, 0.5f, 1f, (Censor.RANGE + 1f) * (Censor.RANGE + 1f));
        c.offerHead(10f, 10f, 0.5f, Censor.MIN_ALPHA * 0.5f, 4f);
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 0, "entrou quem não devia");
        c.offerHead(10f, 10f, 0.5f, 0.5f, 4f);
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 1, "o visível e perto não entrou");
    }

    static void nearestWins() {
        Censor c = new Censor();
        c.begin();
        for (int i = 0; i < Censor.MAX; i++) c.offerHead(100f + i, 0f, 0.5f, 1f, 50f + i);
        c.offerHead(1f, 2f, 0.5f, 1f, 1f);                                     // o mais perto expulsa o mais longe
        c.offerHead(9f, 9f, 0.5f, 1f, 999f);                                   // mais longe que todos: fica fora
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
        float hz = 1f + Censor.HEAD_Z;
        c.offerHead(10300.5f, 9700.25f, hz, 3f, 4f);
        float[] out = new float[Censor.MAX * 4];
        check(c.fill(out, 10240f, 9472f) == 1, "contagem");
        check(out[0] == 60.5f && out[1] == 228.25f, "x, y relativos: " + out[0] + ", " + out[1]);
        check(Math.abs(out[2] - hz) < 1e-6f, "z absoluto da cabeça: " + out[2]);
        check(out[3] == 1f, "alfa acima de 1 não prendeu: " + out[3]);
        check(Censor.HEAD_Z > 0.4f && Censor.HEAD_Z < 0.6f, "cabeça entre a lanterna (0,4) e o alto (0,6): " + Censor.HEAD_Z);
    }

    static void beginResets() {
        Censor c = new Censor();
        c.begin();
        c.offerHead(1f, 1f, 0.5f, 1f, 1f);
        c.begin();
        check(c.fill(new float[Censor.MAX * 4], 0f, 0f) == 0, "sobrou do quadro anterior");
    }

    static void estimateStanding() {
        float[] out = new float[3];
        Censor.estimateHead(10f, 20f, 1f, false, 0f, 1f, out);
        check(out[0] == 10f && out[1] == 20f, "XY dos pés: " + out[0] + "," + out[1]);
        check(Math.abs(out[2] - (1f + Censor.HEAD_Z)) < 1e-6f, "z em pé: " + out[2]);
    }

    static void estimateProne() {
        float[] out = new float[3];
        // forward +Y: cabeça à frente em y, z baixo (print 09: quadrado no ar com HEAD_Z fixo)
        Censor.estimateHead(10f, 20f, 0f, true, 0f, 2f, out);
        check(Math.abs(out[0] - 10f) < 1e-5f, "x sem deriva: " + out[0]);
        check(Math.abs(out[1] - (20f + Censor.HEAD_XY_PRONE)) < 1e-5f, "y à frente: " + out[1]);
        check(Math.abs(out[2] - Censor.HEAD_Z_PRONE) < 1e-6f, "z prone: " + out[2]);
        check(Censor.HEAD_Z_PRONE < 0.25f, "prone tem de ficar perto do chão: " + Censor.HEAD_Z_PRONE);
        check(Censor.HEAD_Z_PRONE < Censor.HEAD_Z, "prone mais baixo que em pé");
        // forward zero → eixo +X
        Censor.estimateHead(0f, 0f, 0f, true, 0f, 0f, out);
        check(Math.abs(out[0] - Censor.HEAD_XY_PRONE) < 1e-5f, "forward zero usa +X: " + out[0]);
    }

    static void offerHeadAbsolute() {
        Censor c = new Censor();
        c.begin();
        // se somasse HEAD_Z de novo, o quadrado subiria (print 11: blocos acima da cabeça)
        c.offerHead(5f, 6f, 0.40f, 1f, 1f);
        float[] out = new float[Censor.MAX * 4];
        check(c.fill(out, 0f, 0f) == 1, "contagem");
        check(out[0] == 5f && out[1] == 6f, "xy");
        check(Math.abs(out[2] - 0.40f) < 1e-6f, "z não pode ganhar HEAD_Z: " + out[2]);
        check(Censor.MODDATA_KEY.equals("NOM_semrosto"), "chave ModData: " + Censor.MODDATA_KEY);
    }
}
