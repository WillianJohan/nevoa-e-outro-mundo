package nom.render;

import static org.lwjgl.opengl.GL33C.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;

import org.joml.Vector3f;

import se.krka.kahlua.integration.annotations.LuaMethod;
import zombie.GameWindow;
import zombie.ZomboidFileSystem;
import zombie.characters.IsoGameCharacter;
import zombie.characters.IsoPlayer;
import zombie.characters.IsoZombie;
import zombie.core.Color;
import zombie.core.Core;
import zombie.core.SpriteRenderer;
import zombie.core.skinnedmodel.visual.ItemVisual;
import zombie.core.skinnedmodel.visual.ItemVisuals;
import zombie.core.textures.TextureDraw;
import zombie.core.textures.TextureFBO;
import zombie.gameStates.IngameState;
import zombie.inventory.InventoryItem;
import zombie.iso.IsoCamera;
import zombie.iso.IsoCell;
import zombie.iso.IsoDepthHelper;
import zombie.iso.IsoWorld;
import zombie.iso.Vector2;
import zombie.iso.weather.ClimateManager;
import zombie.iso.weather.fog.ImprovedFog;
import zombie.scripting.objects.VehicleScript;
import zombie.vehicles.BaseVehicle;
import zombie.vehicles.VehicleLight;
import zombie.vehicles.VehiclePart;

/**
 * "NOM render context": tudo que um pós-passe do mundo precisa, num lugar só.
 *
 * Main thread (Core.EndFrame(int), depois do IsoWorld.render): tira um retrato do
 * quadro (câmera iso, âncora de profundidade, personagens perto, névoa do clima,
 * cabeças do Sem-rosto, params do Lua) e enfileira um GenericDrawer. Render thread (o
 * FBO fora da tela do jogador ainda está preso): copia a profundidade do FBO pra uma
 * textura nossa (e a cor, só com rosto censurado na tela) e roda cada passe registrado em
 * PASSES, na ordem, por cima da cena, antes do screen.frag e da UI.
 *
 * Efeito novo = um arquivo media/shaders/NOM_X.frag (que usa o cabeçalho
 * NOM_RenderContext.glsl) + o nome em PASSES.
 */
public final class RenderContext {
    // o rosto censurado vem antes da névoa: a névoa cobre o quadrado (sprint 0044)
    static final String[] PASSES = { "NOM_Censura", "NOM_VolFog" };
    static final int MAX_CHARS = 8;
    static final float CHAR_RANGE = 20f;
    static final int MAX_TORCHES = 4;
    static final float TORCH_RANGE = 40f;
    // a origem pula a cada 256 tiles; o ruído da névoa fica no mundo (uDrift), então não salta
    static final double ORIGIN_SNAP = 256;

    // params que o Lua empurra (NOMRender_setParam); 4 x vec4
    static final float[] luaParams = new float[16];
    static final long t0 = System.nanoTime();
    static final int PARAM_LOOK = 5;            // NOMRender_setParam(5, 0) volta pro visual antigo da névoa
    static final int PARAM_QUALITY = 6;         // 0 baixa, 1 média, 2 alta (Opções > Mods, pelo Lua)
    static final int PARAM_HAZE = 7;            // escala do véu de fundo da névoa (0 = só rolos)
    static final int PARAM_VANILLA_FOG = 8;     // 1 devolve a névoa vanilla (ImprovedFog) por baixo da nossa
    static final int PARAM_FLOW_RES = 9;        // células por tile da névoa fluida, 1 a 3 (Opções > Mods, pelo Lua)
    static final int PARAM_VACUUM = 10;         // 1 vácuo atrás dos prédios (o Johan escolheu no A/B); 0 a esteira enche
    static final int PARAM_WIND_SOURCE = 11;    // 1 liga um foco de vento aleatório perto do jogador (teste, sprint 0033); padrão 0
    static final int PARAM_BLACK = 12;          // 1 na névoa preta: a luz empurra a névoa (sprint 0039, client/NOM_FogQualitySync.lua)
    static final int PARAM_CENSOR = 13;         // rosto censurado do Sem-rosto: 0 desliga, 1 tamanho normal, 1,5 maior (sprint 0044)
    static {
        luaParams[Flow.PARAM_ON] = 1f;          // névoa fluida ligada por padrão
        luaParams[PARAM_FLOW_RES] = 2f;
        luaParams[PARAM_VACUUM] = 1f;
        luaParams[PARAM_LOOK] = 1f;             // rolos com sombra própria por padrão
        luaParams[PARAM_QUALITY] = 2f;
        luaParams[PARAM_HAZE] = 1f;
        luaParams[PARAM_CENSOR] = 1f;
    }

    // ---------- Lua ----------

    public RenderContext() {}

    @LuaMethod(name = "NOMRender_setParam", global = true)
    public static void setParam(double index, double value) {
        int i = (int) index;
        if (i >= 0 && i < luaParams.length) luaParams[i] = (float) value;
    }

    @LuaMethod(name = "NOMRender_isActive", global = true)
    public static boolean isActive() { return true; }

    /**
     * Sonar do Estalador (sprint 0037, client/NOM_SonarFx.lua): anel em (x, y) no andar z que empurra
     * a névoa fluida. true: o mod3 pegou; false: o Lua desenha o anel na tela. Nunca derruba o jogo.
     */
    @LuaMethod(name = "NOMRender_sonar", global = true)
    public static boolean sonar(double x, double y, double z) {
        try {
            return Flow.addSonar((float) x, (float) y, (int) Math.floor(z));
        } catch (Throwable t) {
            log("sonar: erro, o anel vai pra tela: " + t);
            return false;
        }
    }

    /**
     * A névoa vanilla para antes da borda de baixo da tela (maxYOffset -5) e com zoom afastado vira
     * uma faixa limpa; a nossa cobre a tela toda, com véu de fundo. Se o passe morreu, a vanilla fica.
     */
    public static void afterVanillaFogUpdate() {
        if (disabled || luaParams[PARAM_VANILLA_FOG] >= 0.5f) return;
        ImprovedFog.setBaseAlpha(0f);
    }

    /** Estado da névoa fluida, no console e no console.txt. */
    @LuaMethod(name = "NOMRender_flowInfo", global = true)
    public static String flowInfo() {
        String s = Flow.info();
        log(s);
        return s;
    }

    // ---------- main thread ----------

    /** Retrato de um quadro de um jogador. Novo a cada quadro: o render thread lê depois. */
    static final class Frame extends TextureDraw.GenericDrawer {
        int depthW, depthH;
        // Tudo relativo a uma origem inteira perto da câmera (ORIGIN_SNAP): offX/offY e x+y
        // absolutos (~6e5 px, ~2e4 tiles) em float32 têm ulp de 0,06 px / 0,002 tile, e o
        // b − a da reconstrução cancela e vira ruído que muda de sinal a cada linha.
        float offX, offY, zoom, tileScale;  // offX/offY já menos a tela da origem
        float d0, s0, z0;             // âncora de profundidade no personagem da câmera (s0 relativo)
        float originX, originY;
        float time;
        float fogIntensity;
        float fogR, fogG, fogB;
        int charCount;
        final float[] chars = new float[MAX_CHARS * 4]; // x, y, z, raio
        final float[] params = new float[16];
        int torchCount;
        final float[] torchPos = new float[MAX_TORCHES * 4];   // x, y (relativos), z, alcance
        final float[] torchDir = new float[MAX_TORCHES * 4];   // dx, dy, dz (unitário, tiles), cos do cone
        final float[] torchColor = new float[MAX_TORCHES * 4]; // r, g, b, força
        int clearCount;
        final float[] clears = new float[Blasts.MAX_CLEARS * 4]; // x, y (relativos), raio, força
        int censorCount;
        final float[] censors = new float[Censor.MAX * 4];   // x, y (relativos), z da cabeça, alfa pro jogador

        @Override public void render() { RenderContext.renderFrame(this); }
    }

    // público: o advice é inlinado dentro do zombie.core.Core, e chamada a método
    // package-private de lá dá IllegalAccessError e derruba o jogo.
    public static void onWorldEnd(int playerIndex) {
        try {
            if (!(GameWindow.states.current instanceof IngameState)) return;
            IsoCamera.FrameState fs = IsoCamera.frameState;
            IsoGameCharacter cam = fs.camCharacter;
            IsoCell cell = IsoWorld.instance.currentCell;
            if (cam == null || cell == null) return;
            TextureFBO fbo = Core.getInstance().offscreenBuffer.getCurrent(playerIndex);
            if (fbo == null) return;

            // ponytail: um Frame por quadro (~300 bytes); pool se o GC reclamar
            Frame f = new Frame();
            f.depthW = fbo.getTexture().getWidthHW();
            f.depthH = fbo.getTexture().getHeightHW();
            f.zoom = fs.zoom;
            f.tileScale = Core.tileScale;
            float cx = fs.camCharacterX, cy = fs.camCharacterY, cz = fs.camCharacterZ;
            double ox = Math.floor(cx / ORIGIN_SNAP) * ORIGIN_SNAP, oy = Math.floor(cy / ORIGIN_SNAP) * ORIGIN_SNAP;
            double T = Core.tileScale;
            f.originX = (float) ox;
            f.originY = (float) oy;
            f.offX = (float) (fs.offX - 32 * T * (ox - oy));   // IsoUtils.XToScreen(ox, oy, 0)
            f.offY = (float) (fs.offY - 16 * T * (ox + oy));   // IsoUtils.YToScreen(ox, oy, 0)
            // mesma chamada do IsoSprite.renderTextureWithDepth: profundidade de um ponto do mundo
            f.d0 = IsoDepthHelper.getSquareDepthData((int) Math.floor(cx), (int) Math.floor(cy), cx, cy, cz).depthStart;
            f.s0 = (float) ((cx - ox) + (cy - oy));
            f.z0 = cz;
            f.time = ((System.nanoTime() - t0) / 1e9f) % 3600f;

            ClimateManager cm = ClimateManager.getInstance();
            f.fogIntensity = cm.getFogIntensity();
            Color c = cm.getClimateColor(1).getFinalValue().getExterior(); // COLOR_NEW_FOG
            f.fogR = c.r; f.fogG = c.g; f.fogB = c.b;

            collectChars(f, cell, cx, cy);
            collectTorches(f, cell, cx, cy);
            if (playerIndex == 0) {
                Flow.setTorches(f.torchPos, f.torchDir, f.torchCount, f.originX, f.originY);
                Flow.update(cell, fs);
            }
            f.clearCount = Flow.fillClears(f.clears, f.originX, f.originY);
            System.arraycopy(luaParams, 0, f.params, 0, 16);
            if (f.params[PARAM_CENSOR] > 0f) collectCensors(f, cell, cx, cy, playerIndex);
            SpriteRenderer.instance.drawGeneric(f);
        } catch (Throwable t) {
            fail("onWorldEnd", t);
        }
    }

    /** Jogadores locais + os zumbis mais perto, até MAX_CHARS. */
    private static void collectChars(Frame f, IsoCell cell, float cx, float cy) {
        float[] best = new float[MAX_CHARS];
        for (IsoPlayer p : IsoPlayer.players) {
            if (p != null) add(f, best, p, cx, cy);
        }
        ArrayList<IsoZombie> zs = cell.getZombieList();
        for (int i = 0; i < zs.size(); i++) add(f, best, zs.get(i), cx, cy);
    }

    private static void add(Frame f, float[] best, IsoGameCharacter ch, float cx, float cy) {
        float dx = ch.getX() - cx, dy = ch.getY() - cy, d2 = dx * dx + dy * dy;
        if (d2 > CHAR_RANGE * CHAR_RANGE) return;
        int slot;
        if (f.charCount < MAX_CHARS) slot = f.charCount++;
        else {
            slot = 0;
            for (int i = 1; i < MAX_CHARS; i++) if (best[i] > best[slot]) slot = i;
            if (best[slot] <= d2) return;
        }
        best[slot] = d2;
        f.chars[slot * 4] = ch.getX() - f.originX;
        f.chars[slot * 4 + 1] = ch.getY() - f.originY;
        f.chars[slot * 4 + 2] = ch.getZ();
        f.chars[slot * 4 + 3] = 1.2f;
    }

    private static final Censor censor = new Censor();
    private static boolean censorFailed;

    /**
     * Cabeças do Sem-rosto pro quadrado censurado: o zumbi com a peça do visual (a lista de ItemVisual que o
     * client/NOM_VariantLook.lua preenche; IsoZombie.getItemVisuals, ItemVisual.getItemType, bytecode em
     * pz-api-notes §33) e o alfa dele pra este jogador (IsoObject.getAlpha(int): 0 fora da vista).
     * Erro aqui só apaga o quadrado; a névoa segue.
     */
    private static void collectCensors(Frame f, IsoCell cell, float cx, float cy, int playerIndex) {
        try {
            censor.begin();
            ArrayList<IsoZombie> zs = cell.getZombieList();
            for (int i = 0; i < zs.size(); i++) {
                IsoZombie z = zs.get(i);
                float dx = z.getX() - cx, dy = z.getY() - cy, d2 = dx * dx + dy * dy;
                if (d2 > Censor.RANGE * Censor.RANGE) continue;
                ItemVisuals ivs = z.getItemVisuals();
                boolean semRosto = false;
                for (int k = 0; ivs != null && k < ivs.size() && !semRosto; k++) {
                    ItemVisual iv = ivs.get(k);
                    semRosto = iv != null && Censor.isSemRostoItem(iv.getItemType());
                }
                if (semRosto) censor.offer(z.getX(), z.getY(), z.getZ(), z.getAlpha(playerIndex), d2);
            }
            f.censorCount = censor.fill(f.censors, f.originX, f.originY);
        } catch (Throwable t) {
            f.censorCount = 0;
            if (!censorFailed) log("rosto censurado: erro, sem quadrado neste quadro: " + t);
            censorFailed = true;
        }
    }

    private static final ArrayList<InventoryItem> lightItems = new ArrayList<>();
    private static final Vector2 look = new Vector2();
    private static final Vector3f lightPos = new Vector3f(), forward = new Vector3f();

    /**
     * Lanternas dos jogadores locais e faróis dos carros perto, pro facho na névoa. Os mesmos dados que
     * o jogo usa na luz (IsoGameCharacter$TorchInfo.set, bytecode no plan.md da sprint 0026).
     */
    private static void collectTorches(Frame f, IsoCell cell, float cx, float cy) {
        for (IsoPlayer p : IsoPlayer.players) {
            if (p == null) continue;
            lightItems.clear();
            p.getActiveLightItems(lightItems);
            for (int i = 0; i < lightItems.size() && f.torchCount < MAX_TORCHES; i++) {
                InventoryItem it = lightItems.get(i);
                boolean cone = it.isTorchCone();
                if (cone) p.getLookVector(look);
                addTorch(f, p.getX(), p.getY(), p.getZ() + 0.4f, cone ? look.x : 1f, cone ? look.y : 0f,
                        cone ? it.getTorchDot() : -1f, it.getLightDistance(), it.getLightStrength(),
                        it.getColorRed(), it.getColorGreen(), it.getColorBlue());
            }
        }
        for (BaseVehicle v : cell.getVehicles()) {
            if (f.torchCount >= MAX_TORCHES) return;
            if (v == null || !v.getHeadlightsOn()) continue;
            float dx = v.getX() - cx, dy = v.getY() - cy;
            if (dx * dx + dy * dy > TORCH_RANGE * TORCH_RANGE) continue;
            VehicleScript sc = v.getScript();
            if (sc == null) continue;
            Vector3f ext = sc.getExtents();
            v.getForwardVector(forward);
            for (int i = 0; i < v.getLightCount() && f.torchCount < MAX_TORCHES; i++) {
                VehiclePart part = v.getLightByIndex(i);
                if (part == null || part.getId().contains("Rear")) continue;
                VehicleLight l = part.getLight();
                if (l == null) continue;
                lightPos.set(l.offset.x * ext.x / 2f, 0f, l.offset.y * ext.z / 2f);
                v.getWorldPos(lightPos, lightPos);
                addTorch(f, lightPos.x, lightPos.y, lightPos.z + 0.2f, forward.x, forward.z, l.dot,
                        part.getLightDistance(), part.getLightIntensity(), l.r, l.g, l.b);
            }
        }
    }

    private static void addTorch(Frame f, float x, float y, float z, float dx, float dy, float dot, float dist,
                                 float strength, float r, float g, float b) {
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        if (len < 1e-4f || dist <= 0f || strength <= 0f) return;
        float dz = -0.12f;                      // o facho desce um pouco rumo ao chão
        float n = (float) Math.sqrt(len * len + dz * dz);
        int k = f.torchCount++ * 4;
        f.torchPos[k] = x - f.originX;
        f.torchPos[k + 1] = y - f.originY;
        f.torchPos[k + 2] = z;
        f.torchPos[k + 3] = dist;
        f.torchDir[k] = dx / n;
        f.torchDir[k + 1] = dy / n;
        f.torchDir[k + 2] = dz / n;
        f.torchDir[k + 3] = Math.max(-1f, Math.min(0.995f, dot));
        f.torchColor[k] = r;
        f.torchColor[k + 1] = g;
        f.torchColor[k + 2] = b;
        f.torchColor[k + 3] = strength;
    }

    // ---------- render thread ----------

    private static boolean disabled;
    private static int vao, depthFbo, depthTex, depthTexW, depthTexH;
    private static int sceneFbo, sceneTex, sceneTexW, sceneTexH;
    static final int SCENE_UNIT = 5;
    private static int[] programs;

    static void renderFrame(Frame f) {
        if (disabled) return;
        int prevDraw = glGetInteger(GL_DRAW_FRAMEBUFFER_BINDING);
        if (prevDraw == 0) return; // sem FBO fora da tela: nada a fazer
        int prevRead = glGetInteger(GL_READ_FRAMEBUFFER_BINDING);
        int prevProg = glGetInteger(GL_CURRENT_PROGRAM);
        int prevActive = glGetInteger(GL_ACTIVE_TEXTURE);
        int prevVao = glGetInteger(GL_VERTEX_ARRAY_BINDING);
        boolean blend = glIsEnabled(GL_BLEND), depthTest = glIsEnabled(GL_DEPTH_TEST),
                stencil = glIsEnabled(GL_STENCIL_TEST), cull = glIsEnabled(GL_CULL_FACE);
        boolean alphaTest = org.lwjgl.opengl.GL11.glIsEnabled(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
        int bSrcRgb = glGetInteger(GL_BLEND_SRC_RGB), bDstRgb = glGetInteger(GL_BLEND_DST_RGB),
            bSrcA = glGetInteger(GL_BLEND_SRC_ALPHA), bDstA = glGetInteger(GL_BLEND_DST_ALPHA);
        boolean depthMask = glGetBoolean(GL_DEPTH_WRITEMASK);
        glActiveTexture(GL_TEXTURE0 + Flow.UNIT);
        int prevTexFlow = glGetInteger(GL_TEXTURE_BINDING_2D);
        glActiveTexture(GL_TEXTURE7);
        int prevTex7 = glGetInteger(GL_TEXTURE_BINDING_2D);
        glActiveTexture(GL_TEXTURE0 + SCENE_UNIT);
        int prevTexScene = glGetInteger(GL_TEXTURE_BINDING_2D);
        int[] vp = new int[4];
        glGetIntegerv(GL_VIEWPORT, vp);
        try {
            if (programs == null) init();
            ensureDepthTarget(f.depthW, f.depthH);

            // profundidade: o FBO do jogo guarda num renderbuffer (não amostrável); copia o retângulo do jogador
            glBindFramebuffer(GL_READ_FRAMEBUFFER, prevDraw);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, depthFbo);
            glBlitFramebuffer(vp[0], vp[1], vp[0] + vp[2], vp[1] + vp[3],
                              vp[0], vp[1], vp[0] + vp[2], vp[1] + vp[3], GL_DEPTH_BUFFER_BIT, GL_NEAREST);
            // cor da cena pro borrado do rosto censurado: só com quadrado na tela (o blit custa ~0,1 ms)
            if (f.censorCount > 0) {
                ensureSceneTarget(f.depthW, f.depthH);
                glBindFramebuffer(GL_DRAW_FRAMEBUFFER, sceneFbo);
                glBlitFramebuffer(vp[0], vp[1], vp[0] + vp[2], vp[1] + vp[3],
                                  vp[0], vp[1], vp[0] + vp[2], vp[1] + vp[3], GL_COLOR_BUFFER_BIT, GL_NEAREST);
            }
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prevDraw);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, prevRead);

            glDisable(GL_DEPTH_TEST);
            glDepthMask(false);
            glDisable(GL_STENCIL_TEST);
            glDisable(GL_CULL_FACE);
            org.lwjgl.opengl.GL11.glDisable(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
            glEnable(GL_BLEND);
            // saída pré-multiplicada; o alfa de destino fica como está
            glBlendFuncSeparate(GL_ONE, GL_ONE_MINUS_SRC_ALPHA, GL_ZERO, GL_ONE);
            Flow.prepare();
            glActiveTexture(GL_TEXTURE0 + SCENE_UNIT);
            glBindTexture(GL_TEXTURE_2D, f.censorCount > 0 ? sceneTex : 0);
            glActiveTexture(GL_TEXTURE7);
            glBindTexture(GL_TEXTURE_2D, depthTex);
            glBindVertexArray(vao);

            for (int i = 0; i < programs.length; i++) {
                int prog = programs[i];
                if (prog == 0 || (f.censorCount == 0 && "NOM_Censura".equals(PASSES[i]))) continue;
                glUseProgram(prog);
                bindContext(prog, f, vp);
                glDrawArrays(GL_TRIANGLES, 0, 3);
            }
        } catch (Throwable t) {
            fail("renderFrame", t);
        } finally {
            glBindVertexArray(prevVao);
            glActiveTexture(GL_TEXTURE0 + Flow.UNIT);
            glBindTexture(GL_TEXTURE_2D, prevTexFlow);
            glActiveTexture(GL_TEXTURE7);
            glBindTexture(GL_TEXTURE_2D, prevTex7);
            glActiveTexture(GL_TEXTURE0 + SCENE_UNIT);
            glBindTexture(GL_TEXTURE_2D, prevTexScene);
            glActiveTexture(prevActive);
            glUseProgram(prevProg);
            glBlendFuncSeparate(bSrcRgb, bDstRgb, bSrcA, bDstA);
            setCap(GL_BLEND, blend);
            setCap(GL_DEPTH_TEST, depthTest);
            setCap(GL_STENCIL_TEST, stencil);
            setCap(GL_CULL_FACE, cull);
            if (alphaTest) org.lwjgl.opengl.GL11.glEnable(org.lwjgl.opengl.GL11.GL_ALPHA_TEST);
            glDepthMask(depthMask);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prevDraw);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, prevRead);
        }
    }

    /** O contrato de uniforms: tudo que está no NOM_RenderContext.glsl. */
    private static void bindContext(int prog, Frame f, int[] vp) {
        glUniform1i(glGetUniformLocation(prog, "uDepth"), 7);
        glUniform4f(glGetUniformLocation(prog, "uViewport"), vp[0], vp[1], vp[2], vp[3]);
        glUniform2f(glGetUniformLocation(prog, "uDepthSize"), f.depthW, f.depthH);
        glUniform4f(glGetUniformLocation(prog, "uCam"), f.offX, f.offY, f.zoom, f.tileScale);
        glUniform4f(glGetUniformLocation(prog, "uDepthRef"), f.d0, f.s0, f.z0, IsoDepthHelper.SQUARE_DEPTH * 0.5f);
        glUniform1f(glGetUniformLocation(prog, "uTime"), f.time);
        glUniform2f(glGetUniformLocation(prog, "uOrigin"), f.originX, f.originY);
        glUniform4f(glGetUniformLocation(prog, "uFog"), f.fogIntensity, f.fogR, f.fogG, f.fogB);
        glUniform1i(glGetUniformLocation(prog, "uCharCount"), f.charCount);
        glUniform4fv(glGetUniformLocation(prog, "uChars"), f.chars);
        glUniform4fv(glGetUniformLocation(prog, "uParams"), f.params);
        glUniform1i(glGetUniformLocation(prog, "uTorchCount"), f.torchCount);
        glUniform4fv(glGetUniformLocation(prog, "uTorchPos"), f.torchPos);
        glUniform4fv(glGetUniformLocation(prog, "uTorchDir"), f.torchDir);
        glUniform4fv(glGetUniformLocation(prog, "uTorchColor"), f.torchColor);
        glUniform1i(glGetUniformLocation(prog, "uClearCount"), f.clearCount);
        glUniform4fv(glGetUniformLocation(prog, "uClears"), f.clears);
        glUniform1i(glGetUniformLocation(prog, "uScene"), SCENE_UNIT);
        glUniform1i(glGetUniformLocation(prog, "uCensorCount"), f.censorCount);
        glUniform4fv(glGetUniformLocation(prog, "uCensor"), f.censors);
        Flow.bindUniforms(prog, f.originX, f.originY);
    }

    private static void init() throws java.io.IOException {
        programs = new int[PASSES.length];
        vao = glGenVertexArrays();
        String header = read("media/shaders/NOM_RenderContext.glsl");
        String vert = read("media/shaders/NOM_Fullscreen.vert");
        for (int i = 0; i < PASSES.length; i++) {
            try {
                String frag = read("media/shaders/" + PASSES[i] + ".frag");
                programs[i] = link(vert, header + "\n#line 1\n" + frag);
                log("pass " + PASSES[i] + " ok");
            } catch (Throwable t) {
                log("ERRO no passe " + PASSES[i] + " (desligado, os outros seguem): " + t);
            }
        }
    }

    private static void ensureDepthTarget(int w, int h) {
        if (depthFbo != 0 && w == depthTexW && h == depthTexH) return;
        if (depthFbo != 0) { glDeleteFramebuffers(depthFbo); glDeleteTextures(depthTex); }
        depthTex = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, depthTex);
        // mesmo formato do renderbuffer do jogo (TextureFBO.initInternal: GL_DEPTH24_STENCIL8): o blit exige
        glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH24_STENCIL8, w, h, 0, GL_DEPTH_STENCIL, GL_UNSIGNED_INT_24_8, (java.nio.ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_NONE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        depthFbo = glGenFramebuffers();
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, depthFbo);
        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_TEXTURE_2D, depthTex, 0);
        glDrawBuffer(GL_NONE);
        int st = glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER);
        if (st != GL_FRAMEBUFFER_COMPLETE) throw new IllegalStateException("depth FBO incompleto: 0x" + Integer.toHexString(st));
        depthTexW = w;
        depthTexH = h;
        log("depth target " + w + "x" + h);
    }

    /** Textura RGBA8 do tamanho da de profundidade, pra cópia da cor da cena (rosto censurado). */
    private static void ensureSceneTarget(int w, int h) {
        if (sceneFbo != 0 && w == sceneTexW && h == sceneTexH) return;
        if (sceneFbo != 0) { glDeleteFramebuffers(sceneFbo); glDeleteTextures(sceneTex); }
        sceneTex = glGenTextures();
        glBindTexture(GL_TEXTURE_2D, sceneTex);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, (java.nio.ByteBuffer) null);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        sceneFbo = glGenFramebuffers();
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, sceneFbo);
        glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, sceneTex, 0);
        int st = glCheckFramebufferStatus(GL_DRAW_FRAMEBUFFER);
        if (st != GL_FRAMEBUFFER_COMPLETE) throw new IllegalStateException("scene FBO incompleto: 0x" + Integer.toHexString(st));
        sceneTexW = w;
        sceneTexH = h;
        log("scene target " + w + "x" + h);
    }

    private static int link(String vs, String fs) {
        int v = compile(GL_VERTEX_SHADER, vs), fr = compile(GL_FRAGMENT_SHADER, fs);
        int p = glCreateProgram();
        glAttachShader(p, v);
        glAttachShader(p, fr);
        glLinkProgram(p);
        glDeleteShader(v);
        glDeleteShader(fr);
        if (glGetProgrami(p, GL_LINK_STATUS) == 0) throw new IllegalStateException(glGetProgramInfoLog(p));
        return p;
    }

    private static int compile(int type, String src) {
        int s = glCreateShader(type);
        glShaderSource(s, src);
        glCompileShader(s);
        if (glGetShaderi(s, GL_COMPILE_STATUS) == 0) throw new IllegalStateException(glGetShaderInfoLog(s));
        return s;
    }

    /** Lê pelo mapa de arquivos dos mods ativos (o mesmo que o jogo usa pros shaders). */
    private static String read(String rel) throws java.io.IOException {
        return Files.readString(Path.of(ZomboidFileSystem.instance.getString(rel)));
    }

    private static void setCap(int cap, boolean on) { if (on) glEnable(cap); else glDisable(cap); }

    static void log(String s) { System.out.println("[NOM-Render] " + s); }

    static void fail(String where, Throwable t) {
        // ponytail: um erro desliga tudo até reiniciar; melhor sem névoa que travando a tela
        disabled = true;
        log("ERRO em " + where + ", contexto desligado: " + t);
        t.printStackTrace();
    }
}
