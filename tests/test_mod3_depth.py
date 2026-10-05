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
