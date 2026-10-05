package nom.render;

import me.zed_0xff.zombie_buddy.Patch;

public class Patches {
    /**
     * Core.EndFrame(int) roda logo depois do IsoWorld.render de cada jogador
     * (IngameState.renderFrameInternal 83 -> 160) e antes do RenderOffScreenBuffer:
     * o que for enfileirado aqui desenha no FBO do jogador, por cima do mundo.
     * O @Argument int casa só com EndFrame(I)V, não com EndFrame().
     */
    @Patch(className = "zombie.core.Core", methodName = "EndFrame")
    public static class EndFrame {
        @Patch.OnEnter
        public static void enter(@Patch.Argument(0) int playerIndex) {
            // o advice roda dentro do Core: nada pode escapar daqui e derrubar o jogo
            try { RenderContext.onWorldEnd(playerIndex); } catch (Throwable t) { }
        }
    }
}
