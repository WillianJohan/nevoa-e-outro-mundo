package nom.render;

import zombie.Lua.LuaManager;

public class Main {
    /**
     * O ZombieBuddy chama este main quando carrega o jar. Se o mod foi ativado só no
     * save, o jar entra DEPOIS do LuaManager.Exposer.exposeAll e os @LuaMethod globais
     * ficam de fora até o próximo boot do Lua; então registramos na hora, no env atual.
     * Repetir o registro (mod também ativo no menu) só sobrescreve a mesma função.
     */
    public static void main(String[] args) {
        try {
            if (LuaManager.exposer == null || LuaManager.env == null) return;
            LuaManager.exposer.exposeGlobalFunctions(new RenderContext());
            RenderContext.log("Lua: NOMRender_setParam, NOMRender_isActive e NOMRender_flowInfo registrados");
        } catch (Throwable t) {
            RenderContext.log("Lua: registro falhou: " + t);
        }
    }
}
