#!/usr/bin/env python3
import glob
import re
import sys

import moderngl
import numpy as np

SETTLE = float(sys.argv[1]) if len(sys.argv) > 1 else 600.
DT = 1. / 60.
BUF = "bufferConveyor.glsl"
BAKE = re.compile(r"const int CV_BAKED = \d;\nconst vec4 CV_BAKE\[\d+\] = vec4\[\]\(.*?\);\n", re.S)


def const(src, name):
    return int(re.search(rf"const int\s+{name}\s*=\s*(\d+)", src).group(1))


def lit(v):
    s = f"{v:.9g}"
    return s if any(c in s for c in ".en") else s + "."


parts = sorted(glob.glob("[0-9][0-9]_*.glsl"))
lib = "".join(open(p).read() for p in parts)
buf = open(BUF).read()
assert BAKE.search(buf), "CV_BAKE block not found"
body = BAKE.sub("const int CV_BAKED = 0;\nconst vec4 CV_BAKE[1] = vec4[](vec4(0.));\n", buf)

src = open("../../../qt_preamble.glsl").read()
for part in [lib, body]:
    src += re.sub(r"(?m)^(#version.*|precision\s.*)$", "", part)
src += """
void main() {
    vec2 fragCoord = qt_TexCoord0 * iResolution.xy;
    fragCoord.y = iResolution.y - fragCoord.y;
    mainImage(fragColor, fragCoord);
}
"""
m = re.search(r"layout\(std140, binding = 0\) uniform buf \{(.*?)\n\};", src, re.S)
decl = ["uniform " + l for l in (re.sub(r"//.*", "", l).strip() for l in m.group(1).split("\n")) if l.endswith(";")]
src = src.replace(m.group(0), "\n".join(decl))
src = src.replace("layout(location = 0) in vec2 qt_TexCoord0;", "#define qt_TexCoord0 (gl_FragCoord.xy / iResolution.xy)")
src = re.sub(r"layout\(binding = \d+\) uniform sampler2D", "uniform sampler2D", src)

n = const(lib, "CV_N")
row = const(lib, "AG_BIN0") + const(lib, "AG_GY")
W, H = const(lib, "AG_W"), row + 1
nst = max(int(v) for v in re.findall(r"CX_\w+ = (\d+)", lib)) + 5

ctx = moderngl.create_standalone_context(backend="egl", require=440)
prog = ctx.program(vertex_shader="#version 440\nin vec2 p; void main(){ gl_Position = vec4(p, 0., 1.); }", fragment_shader=src)
vao = ctx.vertex_array(prog, [(ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype="f4")), "2f", "p")])
tex = [ctx.texture((W, H), 4, dtype="f4") for _ in range(2)]
fbo = [ctx.framebuffer(color_attachments=[t]) for t in tex]
for t in tex:
    t.filter = (moderngl.NEAREST, moderngl.NEAREST)
for name, v in (("iResolution", (W, H, 1.)), ("u_aspect", 16. / 9.), ("qt_Opacity", 1.), ("iChannel9", 9)):
    if name in prog:
        prog[name].value = v

cur = 0
for f in range(int(SETTLE / DT)):
    prog["iTime"].value = 1. + f * DT
    if "iFrame" in prog:
        prog["iFrame"].value = f
    tex[cur].use(9)
    fbo[1 - cur].use()
    vao.render(moderngl.TRIANGLE_STRIP)
    cur = 1 - cur

a = np.frombuffer(tex[cur].read(), dtype="f4").reshape(H, W, 4)
texels = [a[y, x] for x in range(n) for y in (0, 1)] + [a[row, x] for x in range(nst)]
vecs = [f"vec4({', '.join(lit(float(c)) for c in v)})" for v in texels]
lines = ",\n".join("    " + ", ".join(vecs[i:i + 4]) for i in range(0, len(vecs), 4))
block = f"const int CV_BAKED = 1;\nconst vec4 CV_BAKE[{len(vecs)}] = vec4[](\n{lines}\n);\n"
open(BUF, "w").write(BAKE.sub(lambda _: block, buf))
live = int((np.rint(a[1, :n, 0]) >= 0).sum())
print(f"baked {n} items ({live} live) and {nst} station texels after {SETTLE:.0f}s")
