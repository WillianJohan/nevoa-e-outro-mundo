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
print("mod3 contrato Java/GLSL ok")
