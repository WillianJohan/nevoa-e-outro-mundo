package nom.render;

import java.util.Random;

/**
 * Foco de vento de teste (sprint 0033, NOMRender_setParam(11, 1)): um ponto sorteado perto do jogador que
 * sopra de forma constante numa direção sorteada. Puro, sem API do jogo, pra testar sem o jogo
 * (tests/java/FlowWindSourceTest.java); o Flow.pickSource só chama isto.
 */
public final class WindSource {
    public static final float MIN_DIST = 15f, MAX_DIST = 30f;   // tiles do jogador
    public static final float SPEED = 2.5f;                     // tiles/s
    public static final float RADIUS = 4f;                      // tiles

    public final float x, y, vx, vy;   // posição de mundo e velocidade de sopro

    private WindSource(float x, float y, float vx, float vy) {
        this.x = x;
        this.y = y;
        this.vx = vx;
        this.vy = vy;
    }

    /** Ponto a MIN_DIST..MAX_DIST de (px, py), em ângulo aleatório, e sopro de módulo SPEED em outro ângulo. */
    public static WindSource pick(float px, float py, Random r) {
        double a = r.nextDouble() * 2 * Math.PI;
        double d = MIN_DIST + r.nextDouble() * (MAX_DIST - MIN_DIST);
        double b = r.nextDouble() * 2 * Math.PI;
        return new WindSource((float) (px + Math.cos(a) * d), (float) (py + Math.sin(a) * d),
                (float) (Math.cos(b) * SPEED), (float) (Math.sin(b) * SPEED));
    }
}
