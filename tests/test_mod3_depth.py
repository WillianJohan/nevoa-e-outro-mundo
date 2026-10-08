"""mod3: a reconstrução do mundo no NOM_RenderContext.glsl inverte as fórmulas do jogo.

Ida (bytecode B42.21): IsoUtils.XToScreen/YToScreen e IsoDepthHelper (profundidade
linear em x+y e z, SQUARE_DEPTH = LEVEL_DEPTH = 0.0028867084, k = metade por tile de x+y).
Volta: nomWorldPos do cabeçalho GLSL, transcrita aqui. Se alguém mexer numa, quebra.
"""
import random

T, SQ = 2, 0.0028867084
k = SQ * 0.5

def forward(x, y, z, cam):
    cx, cy, cz = cam
    d0 = 0.5  # qualquer âncora: só a diferença importa
    sx = 32 * T * (x - y)
    sy = 16 * T * (x + y) - 96 * T * z
    d = d0 - k * ((x + y) - (cx + cy)) - SQ * (z - cz)
    return sx, sy, d, d0

def inverse(sx, sy, d, d0, cam):  # = nomWorldPos
    cx, cy, cz = cam
    u = sx / (32 * T)
    a = sy / (16 * T)
    b = (cx + cy) + 2 * cz - (d - d0) / k
    z = (b - a) / 8
    s = a + 6 * z
    return (s + u) / 2, (s - u) / 2, z

random.seed(1)
for _ in range(1000):
    cam = (random.uniform(0, 15000), random.uniform(0, 15000), random.randint(0, 7))
    p = (cam[0] + random.uniform(-60, 60), cam[1] + random.uniform(-60, 60), random.uniform(-1, 8))
    q = inverse(*forward(*p, cam), cam)
    assert all(abs(a - b) < 1e-6 for a, b in zip(p, q)), (p, q)
print("mod3 depth inverse ok")

# Caso real em float32 (o 1º teste no jogo, 05/10): janela 1696x1346 dentro do FBO 2048x2048,
# zoom != 1, jogador em x=10994 y=9699. Ida em double (o jogo), volta transcrita do GLSL em
# float32. O z do chão sai 0 ± ruído (1 ulp de 2e4 em coordenada absoluta, profundidade
# quantizada); com sinal trocando de linha pra linha, o fract(z) do modo 1 dava 0 ou ~1:
# listras de 1–3 px só no chão (paredes, com z entre andares, saíram lisas no print 17).
# Correção: coordenadas relativas a uma origem perto da câmera e debug com z + 0,5 / modo 4.
import numpy as np
f32 = np.float32

def div(a, b):  # GPU: a / b = a * (1 / b), não arredondado certo (GLSL aceita 2,5 ulp)
    return f32(a) * (f32(1) / f32(b))

def glsl_world(frag, vp, cam_u, ref):  # = nomIsoScreen + nomWorldPos, tudo em float32
    offX, offY, zoom, Tt = map(f32, cam_u)
    d0, s0, z0, kk = map(f32, ref)
    px, py = f32(frag[0]) - f32(vp[0]), f32(frag[1]) - f32(vp[1])
    iso = (px * zoom + offX, (f32(vp[3]) - py) * zoom + offY)
    u = div(iso[0], f32(32) * Tt)
    a = div(iso[1], f32(16) * Tt)
    b = s0 + f32(2) * z0 - div(f32(frag[2]) - d0, kk)
    z = (b - a) / f32(8)
    s = a + f32(6) * z
    return (s + u) * f32(0.5), (s - u) * f32(0.5), z

def frame(cx, cy, cz, zoom, relative):
    # o que o Java manda (RenderContext.onWorldEnd), em double, depois cortado pra float
    ox = oy = 0.0
    if relative:
        ox, oy = (cx // 256) * 256, (cy // 256) * 256
    offX = float(int(32 * T * (cx - cy) - 848 * zoom))   # câmera centrada no jogador; PlayerCamera.getOffX faz f2i
    offY = float(int(16 * T * (cx + cy) - 96 * T * cz - 673 * zoom))
    cam_u = (offX - 32 * T * (ox - oy), offY - 16 * T * (ox + oy), zoom, T)
    ref = (0.5, (cx - ox) + (cy - oy), cz, k)
    return cam_u, ref, (offX, offY), (ox, oy)

def worst_ground_z(relative, zoom):
    cx, cy, cz = 10994.37, 9699.81, 0.0
    vp = (0, 0, 1696, 1346)                     # viewport menor que a textura 2048
    cam_u, ref, (offX, offY), (ox, oy) = frame(cx, cy, cz, zoom, relative)
    worst = 0.0
    for row in range(0, 1346, 3):
        for col in range(0, 1696, 97):
            # pixel -> ponto do chão (z = 0) em double, e a profundidade que o jogo escreveria
            fx, fy = col + 0.5, row + 0.5                 # gl_FragCoord é o centro do pixel
            isx, isy = fx * zoom + offX, fy * zoom + offY  # row 0 = topo da tela
            u, s = isx / (32 * T), isy / (16 * T)
            x, y = (s + u) / 2, (s - u) / 2
            d = 0.5 - k * ((x + y) - (cx + cy)) - SQ * (0 - cz)
            d = round(d * (2**24 - 1)) / (2**24 - 1)          # DEPTH24
            X, Y, Z = glsl_world((fx, 1346 - fy, d), vp, cam_u, ref)
            if relative:
                assert abs(float(X) + ox - x) < 0.01 and abs(float(Y) + oy - y) < 0.01, (x, y, X, Y)
            worst = max(worst, abs(float(Z)))
    return worst

for zoom in (0.5, 1.0, 1.75, 2.5):
    new = worst_ground_z(True, zoom)
    assert new < 2e-5, ("chão fora do andar 0 com origem relativa", zoom, new)
    # x, y absolutos: ulp(2e4) = 0,002 tile; relativo a origem: 1e-5
    assert np.spacing(f32(20694.18)) > 30 * np.spacing(f32(470.18))

# Debug: z do chão = 0 ± ruído. fract(z) vira 0 ou ~1 (a listra); fract(z + 0,5) e o modo 4 não.
for eps in (-1e-3, -1e-5, 0.0, 1e-5, 1e-3):
    assert abs(((eps + 0.5) % 1.0) - 0.5) < 2e-3
    assert abs(eps - round(eps)) * 10 < 0.02
assert (-1e-5) % 1.0 > 0.99  # o modo 1 antigo: fract(-0,00001) = 0,99999
print("mod3 float32 ground z ok (relativo)")

# Advice do ZombieBuddy é inlinado na classe do jogo: todo método do mod3 chamado
# de dentro de um @Patch precisa ser public, senão IllegalAccessError derruba o jogo.
import re, pathlib
src = pathlib.Path(__file__).resolve().parent.parent / "mod3/java/nom/render"
called = set(re.findall(r"RenderContext\.(\w+)\(", (src / "Patches.java").read_text()))
ctx = (src / "RenderContext.java").read_text()
for m in called:
    assert re.search(r"public static \S+ " + m + r"\(", ctx), "mod3: RenderContext." + m + " precisa ser public"
print("mod3 patch calls public ok")

# Contrato Java <-> GLSL: todo uniform que o Java procura existe no cabeçalho, e as flags e a
# escala da velocidade da textura do fluido (FlowGrid.writeRGBA) batem com as constantes NOM_FLOW_*.
header = (src.parent.parent.parent / "42/media/shaders/NOM_RenderContext.glsl").read_text()
java = "".join(p.read_text() for p in src.glob("*.java"))
declared = set(re.findall(r"^uniform \w+ (\w+)", header, re.M))
for name in set(re.findall(r'glGetUniformLocation\(\w+, "(\w+)"\)', java)):
    assert name in declared, "mod3: uniform " + name + " usado no Java e ausente do cabeçalho GLSL"
flow = (src / "FlowGrid.java").read_text()
for jname, gname in [("F_SOLID", "SOLID"), ("F_TREE", "TREE"), ("F_INDOOR", "INDOOR"),
                     ("T_WALL_W", "WALL_W"), ("T_WALL_N", "WALL_N")]:
    jv = re.search(jname + r" = (\d+)", flow)
    gv = re.search(r"const int NOM_FLOW_" + gname + r" = (\d+);", header)
    assert jv and gv and jv.group(1) == gv.group(1), ("mod3: flag do fluido diverge", jname, gname)
jv = re.search(r"VEL_MAX = ([\d.]+)f", flow)
gv = re.search(r"const float NOM_FLOW_VMAX = ([\d.]+);", header)
assert jv and gv and float(jv.group(1)) == float(gv.group(1)), "mod3: VEL_MAX diverge de NOM_FLOW_VMAX"
# Visual novo da névoa (sprint 0025): NOMRender_setParam(5, v) chega no shader como uParams[1].y.
jl = re.search(r"PARAM_LOOK = (\d+);", java)
assert jl, "mod3: PARAM_LOOK ausente no Java"
assert re.search(r"luaParams\[PARAM_LOOK\] = 1f", java), "mod3: o visual novo tem que ser o padrão"
idx = int(jl.group(1))
comp = "uParams[%d].%s" % (idx // 4, "xyzw"[idx % 4])
volfog = (src.parent.parent.parent / "42/media/shaders/NOM_VolFog.frag").read_text()
assert comp in volfog, "mod3: NOM_VolFog não lê " + comp + " (PARAM_LOOK)"
# Qualidade (sprint 0026): NOMRender_setParam(6, q), padrão alta, lida pelo shader no componente certo.
jq = re.search(r"PARAM_QUALITY = (\d+);", java)
assert jq and re.search(r"luaParams\[PARAM_QUALITY\] = 2f", java), "mod3: PARAM_QUALITY ausente ou sem padrão alto"
qi = int(jq.group(1))
assert "uParams[%d].%s" % (qi // 4, "xyzw"[qi % 4]) in volfog, "mod3: NOM_VolFog não lê a qualidade"
for name in ("uTorchCount", "uTorchPos", "uTorchDir", "uTorchColor"):
    assert name in volfog, "mod3: NOM_VolFog não usa " + name
# Sem vai e vem (sprint 0027): o ruído anda pelo vento acumulado (uDrift, o mesmo dos bancos) e
# nunca recomeça por fase do relógio, que fazia a altura dos rolos subir e descer junto na tela toda.
assert '"uDrift"' in java and "uDrift" in volfog, "mod3: o ruído da névoa tem que andar por uDrift"
assert not re.search(r"fract\(\s*uTime", volfog), "mod3: NOM_VolFog recomeça o ruído por fase do relógio (pulsa)"
assert "FLOW_PERIOD" not in volfog, "mod3: sobrou o flow map de duas fases no NOM_VolFog"
# Névoa só nossa (sprint 0028): a vanilla (ImprovedFog) para antes da borda de baixo da tela e com
# zoom afastado vira uma faixa limpa. Com o mod3 ligado ela é zerada logo depois do update dela, e o
# shader desenha o véu de fundo (NOMRender_setParam(7, v) escala; (8, 1) devolve a vanilla).
patches = (src / "Patches.java").read_text()
assert re.search(r'className = "zombie\.iso\.weather\.fog\.ImprovedFog", methodName = "update"', patches), \
    "mod3: falta o patch no ImprovedFog.update"
assert re.search(r"@Patch\.OnExit[\s\S]*RenderContext\.afterVanillaFogUpdate\(", patches), \
    "mod3: o patch do ImprovedFog tem que rodar na saída do update"
assert re.search(r"PARAM_VANILLA_FOG = 8;", java) and not re.search(r"luaParams\[PARAM_VANILLA_FOG\] = 1f", java), \
    "mod3: PARAM_VANILLA_FOG (8) ausente ou com a vanilla ligada por padrão"
jh = re.search(r"PARAM_HAZE = (\d+);", java)
# sprint 0047f: HAZE×scale ≈ 0,17 (const 0,32 × param 0,52); mar opaco sem sopa flat da 0047e
assert jh and re.search(r"luaParams\[PARAM_HAZE\] = 0\.52f", java), "mod3: PARAM_HAZE ausente ou sem padrão 0,52 (0047f)"
assert re.search(r"luaParams\[2\] = 0\.68f", java), "mod3: altura da base padrão 0,68 (0047f)"
assert '"uPocket"' in java and "uPocket" in header, "mod3: falta uniform uPocket dos bolsões"
assert '"uPocketShape"' in java and "uPocketShape" in header, "mod3: falta uniform uPocketShape"
assert "pocketSample" in volfog and "layerAt" in volfog, "mod3: NOM_VolFog sem base/bolsão (0047)"
assert re.search(r"return uParams\[0\]\.z > 0\.0 \? uParams\[0\]\.z : 0\.68;", volfog), \
    "mod3: baseLayer fallback 0,68 (0047f)"
hi = int(jh.group(1))
assert "uParams[%d].%s" % (hi // 4, "xyzw"[hi % 4]) in volfog, "mod3: NOM_VolFog não lê o véu (PARAM_HAZE)"
dens_look = volfog.split("float densityLook")[1].split("vec3 torchLight")[0]
assert "NOM_FLOW_INDOOR" in dens_look, "mod3: o véu não pode entrar dentro de casa"
assert "FLOOR_MIN" in dens_look, "mod3: falta piso mínimo independente de fd (0047f)"
assert "floorUnd" in dens_look or "floorBody" in dens_look, "mod3: falta mar de chão com ondulação (0047f)"
assert re.search(r"mix\(3\.2,\s*1\.0,\s*pk\)", dens_look), "mod3: C-lite fall fora de 3,2 (0047f gelo seco)"
# Ondas nos obstáculos (sprint 0029): o rolo sobe onde o ar freia contra a parede e o volume tem
# altura pra isso; a simulação liga o reforço de redemoinho.
roll = volfog.split("float rollTop")[1].split("float densityLook")[0]
assert "pileUp(" in roll, "mod3: o topo do rolo não sobe onde o ar freia (pileUp)"
assert re.search(r"float top = ground \+ max\(layer, pocketLayer\(\)\) \* 1\.6;", volfog) \
    or re.search(r"float top = ground \+ layer \* 1\.6;", volfog), \
    "mod3: o volume não tem altura pro empilhamento"
# 0047f: estável (eixo mundo, sem ridge) + floor orgânico + advecção suave por nomFlowVel
roll_fn = volfog.split("float rollTop")[1].split("float pocketSample")[0]
assert "ROLL_STRETCH" in volfog, "mod3: rollTop sem anisotropia"
assert "SWIRL_AMP" in volfog and "FLOW_ADV" in volfog, "mod3: falta redemoinho/curl por fluxo (0047f)"
assert "SWIRL_ADV" not in volfog, "mod3: SWIRL_ADV voltou (advecção não pode ser tempo solto × vento)"
assert not re.search(r"\bridge\b\s*=", roll_fn), "mod3: ridge de volta no rollTop (bolhas/flicker no piso)"
assert "0.857" in roll_fn, "mod3: falta eixo mundo estável no rollTop"
assert not re.search(r"uDrift\.zw\s*\*\s*inversesqrt", roll_fn), \
    "mod3: eixo do rollTop não pode seguir o vento do quadro (flicker)"
assert not re.search(r"1\.0\s*-\s*pow\s*\(\s*1\.0\s*-\s*smoothstep", roll_fn), \
    "mod3: voltou o puff redondo (algodão) no rollTop"
assert re.search(r"0\.78\s*\+\s*0\.55", roll_fn), \
    "mod3: amplitude do shape (0047f; ~0,78 + forma)"
assert re.search(r"const float PILE = 0\.85;", volfog), "mod3: PILE baixo demais pra abraçar obstáculo"
assert re.search(r"const float HAZE = 0\.32;", volfog), "mod3: HAZE shader fora do alvo 0047f"
assert re.search(r"const float FLOOR_MIN = 0\.42;", volfog), "mod3: FLOOR_MIN fora do alvo 0047f"
assert re.search(r"const float FLOW_ADV = 0\.12;", volfog), "mod3: FLOW_ADV alto demais (smear 0047e)"
# fiapos não reancoram eixo no vel do quadro (flicker)
assert "normalize(velF)" not in dens_look, "mod3: fiapos não podem normalize(vel) por quadro"

assert re.search(r"\bg\.vorticity = [\d.]+f;", java), "mod3: o Flow não liga o reforço de redemoinho"
# Alta resolução (sprint 0030): NOMRender_setParam(9, s), padrão 2 células por tile; o shader acha a
# célula pela escala da textura; a simulação roda numa thread própria e a grade é só dela.
assert re.search(r"PARAM_FLOW_RES = 9;", java) and re.search(r"luaParams\[PARAM_FLOW_RES\] = 2f", java), \
    "mod3: PARAM_FLOW_RES (9) ausente ou sem padrão 2"
ctx = (src.parent.parent.parent / "42/media/shaders/NOM_RenderContext.glsl").read_text()
flags_fn = ctx.split("int nomFlowFlags")[1].split("float nomFlowTree")[0]
assert "textureSize(uFlowTex" in flags_fn, "mod3: nomFlowFlags tem que achar a célula pela escala da textura"
flow = (src / "Flow.java").read_text()
assert 'new Thread(Flow::workLoop, "NOM-fluido")' in flow, "mod3: a simulação tem que rodar na thread própria"
main_part = flow.split("// ---------- main thread ----------")[1].split("// ---------- thread da simulação ----------")[0]
assert "grid." not in main_part, "mod3: a thread principal não pode mexer na grade (é da thread da simulação)"
# Névoa que contorna (sprint 0031): NOMRender_setParam(10, v) liga o vácuo atrás dos prédios (padrão
# 1, escolhido pelo Johan no A/B; 0 enche); a textura vai até D_MAX e o shader desfaz; árvore é porosa e carro é obstáculo baixo;
# o rolo só sobe onde há obstáculo logo à frente no vento, não na esteira.
assert re.search(r"PARAM_VACUUM = 10;", java) and re.search(r"luaParams\[PARAM_VACUUM\] = 1f", java), \
    "mod3: PARAM_VACUUM (10) ausente ou sem padrão 1"
assert "PARAM_VACUUM" in main_part and "stillDecay" in flow.split("private static void apply")[1], \
    "mod3: o vácuo tem que ir da thread principal pra simulação pelo Input"
gv = re.search(r"const float NOM_FLOW_DMAX = ([\d.]+);", header)
jv = re.search(r"D_MAX = ([\d.]+)f", (src / "FlowGrid.java").read_text())
assert gv and jv and float(gv.group(1)) == float(jv.group(1)), "mod3: D_MAX diverge de NOM_FLOW_DMAX"
assert "NOM_FLOW_DMAX" in ctx.split("float nomFlowDensity")[1].split("vec2 nomFlowVel")[0], \
    "mod3: nomFlowDensity tem que desfazer a divisão por D_MAX"
gl = re.search(r"const int NOM_FLOW_LOW = (\d+);", header)
jl = re.search(r"F_LOW = (\d+);", (src / "FlowGrid.java").read_text())
assert gl and jl and gl.group(1) == jl.group(1), "mod3: F_LOW diverge de NOM_FLOW_LOW"
cell_fn = flow.split("private static void buildCell")[1].split("private static void wind")[0]
assert re.search(r"HasTree\(\)\) f \|= FlowGrid\.F_TREE;", cell_fn), "mod3: árvore tem que ser porosa (sem F_SOLID)"
assert re.search(r"getVehicleContainer\(\) != null\) f \|= FlowGrid\.F_LOW;", cell_fn), "mod3: carro tem que ser F_LOW"
pile = volfog.split("float pileUp")[1].split("float rollTop")[0]
assert "nomFlowFlags(" in pile, "mod3: o pileUp tem que olhar se há obstáculo à frente no vento"
# Névoa com altura (sprint 0032): a cerca baixa (HoppableW/N, pz-api-notes §20) vira face aberta com
# altura; o topo do rolo sobe a altura do carro; o debug 5 mostra a cerca.
grid_src = (src / "FlowGrid.java").read_text()
for jname, gname in [("T_FENCE_W", "FENCE_W"), ("T_FENCE_N", "FENCE_N")]:
    jv = re.search(jname + r" = (\d+)", grid_src)
    gv = re.search(r"const int NOM_FLOW_" + gname + r" = (\d+);", header)
    assert jv and gv and jv.group(1) == gv.group(1), ("mod3: flag da cerca diverge", jname, gname)
jv = re.search(r"H_LOW = ([\d.]+)f", grid_src)
gv = re.search(r"const float NOM_FLOW_LOW_H = ([\d.]+);", header)
assert jv and gv and float(jv.group(1)) == float(gv.group(1)), "mod3: H_LOW diverge de NOM_FLOW_LOW_H"
assert "gLow" in roll and "NOM_FLOW_LOW_H" in roll and "gLow = nomFlowLow(" in volfog, \
    "mod3: o topo do rolo não sobe em cima do carro (nomFlowLow)"
assert "NOM_FLOW_FENCE_W" in volfog and "NOM_FLOW_FENCE_N" in volfog, "mod3: o debug 5 não mostra a cerca baixa"
assert re.search(r"has\(IsoFlagType\.HoppableW\)", cell_fn) and re.search(r"has\(IsoFlagType\.HoppableN\)", cell_fn), \
    "mod3: o Flow tem que ler a cerca baixa (HoppableW/N)"
assert "setTileFenceW" in flow and "setTileFenceN" in flow, "mod3: a cerca tem que chegar na grade"
# Foco de vento (sprint 0033): NOMRender_setParam(11, 1) sorteia um foco perto do jogador (borda lida na
# thread principal) que sopra constante; o foco chega na simulação pelo Input e é aplicado antes do passo.
# Padrão desligado; o NOM.wind do Lua escreve no mesmo índice.
assert re.search(r"PARAM_WIND_SOURCE = 11;", java), "mod3: PARAM_WIND_SOURCE (11) ausente"
assert not re.search(r"luaParams\[PARAM_WIND_SOURCE\] = [1-9]", java), "mod3: o foco de vento tem que começar desligado (0)"
assert "PARAM_WIND_SOURCE" in main_part and "pickSource(" in main_part, \
    "mod3: o sorteio do foco tem que ficar na thread principal"
apply_part = flow.split("private static void apply")[1].split("private static void publish")[0]
assert re.search(r"grid\.impulse\(in\.sourceX, in\.sourceY, in\.sourceVX, in\.sourceVY, SOURCE_RADIUS\)", apply_part), \
    "mod3: a simulação tem que aplicar o foco de vento pelo Input"
console = (src.parent.parent.parent.parent / "mod/42/media/lua/client/NOM_Console.lua").read_text()
assert "NOMRender_setParam(11," in console, "mod3: o NOM.wind do Lua não escreve no parâmetro 11"
print("mod3 contrato Java/GLSL ok")
