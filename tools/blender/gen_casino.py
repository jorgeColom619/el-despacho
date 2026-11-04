"""Genera art/casino/casino.glb: las piezas del Gran Casino (minijuego del casino, scripts/stages3d/casino_3d.gd).

Cada pieza es un objeto suelto con su nombre y su punto de giro; el juego las copia del .glb y les pone sus
materiales (madera, oro, terciopelo, paño...) según el nombre del material, igual que a los visitantes.

  RW_Bowl, RW_Rotor, RW_Ball        la ruleta: la caja con la pista de la bola, el plato que gira (37 casillas,
                                    aro de números con UV polar para la textura que dibuja el juego) y la bola
  RT_Table, BJ_Table, PK_Table      mesas de ruleta, blackjack y póker (paño con UV plana para su estampado)
  BJ_Tray, BJ_Shoe, BJ_Discard      bandeja de fichas, sabot de cartas y descarte del blackjack
  SL_Cabinet, SL_Reel_0..2, SL_Lever  tragaperras: el mueble, los tres rodillos (UV para la tira de símbolos) y la
                                    palanca (gira sobre su eje)
  Chip, Dolly                       ficha (UV en el centro para el valor) y marcador del número ganador
  Chandelier, Column, Chair, Stool  lámpara de araña de tres pisos, columna de mármol, silla dorada y taburete
  Stanchion, Rope, Cashier          poste de latón, cordón de terciopelo y la caja del casino

Medidas en metros. Ejes de Blender (Z arriba, el frente de cada pieza mira a -Y); el .glb sale con Y arriba.
Las medidas que el juego necesita para mover la bola, los rodillos y la palanca están repetidas en
scripts/stages3d/casino_3d.gd (RW_*, SL_*): si se cambian aquí, hay que cambiarlas allí.

Uso:
  blender -b --factory-startup -P tools/blender/gen_casino.py -- [salida.glb] [vista_previa.png]
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = ARGS[0] if ARGS else os.path.join(ROOT, "art", "casino", "casino.glb")
PREVIEW = ARGS[1] if len(ARGS) > 1 else ""

TAU = 2.0 * math.pi

bpy.ops.wm.read_factory_settings(use_empty=True)
SCN = bpy.context.scene


# ------------------------------------------------------------------ utilidades

def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_linear(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


## Colores de partida (el juego pone los suyos; estos sirven para la vista previa y por si falta alguno)
MAT_COL = {
    "Wood": ("6b2f1a", 0.35, 0.0), "WoodDark": ("2a1610", 0.35, 0.0), "Gold": ("d4a656", 0.28, 0.95),
    "Chrome": ("d0d2d8", 0.12, 0.95), "Felt": ("1f5a3a", 0.95, 0.0), "Leather": ("3a1a12", 0.45, 0.0),
    "Velvet": ("7a1622", 0.85, 0.0), "Marble": ("e8e2d6", 0.15, 0.0), "Crystal": ("f4f8ff", 0.0, 0.2),
    "Bulb": ("ffe2a8", 0.4, 0.0), "Ivory": ("f3eee0", 0.25, 0.0), "Black": ("141416", 0.5, 0.0),
    "RW_Numbers": ("5a1414", 0.4, 0.0), "RW_Red": ("a3161c", 0.4, 0.0), "RW_Black": ("141416", 0.4, 0.0),
    "RW_Green": ("1d7a3c", 0.4, 0.0), "RW_Cone": ("8a5a32", 0.3, 0.0),
    "SL_Body": ("7a1220", 0.3, 0.2), "SL_Inner": ("0c0c10", 0.8, 0.0), "SL_Deck": ("15151a", 0.4, 0.0),
    "SL_Reel": ("f2ede0", 0.5, 0.0), "SL_Sign": ("ffcf5a", 0.5, 0.0), "SL_Belly": ("2a2a6a", 0.5, 0.0),
    "SL_Crest": ("e0b040", 0.5, 0.0), "SL_Lights": ("ffd27a", 0.4, 0.0), "SL_Knob": ("c41a1a", 0.2, 0.0),
    "SL_Btn": ("e04a2a", 0.3, 0.0), "SL_Payline": ("ff3030", 0.4, 0.0), "Glass": ("cfe4ff", 0.05, 0.0),
    "ChipBody": ("b81c2a", 0.5, 0.0), "ChipSpot": ("f2efe6", 0.5, 0.0), "ChipInlay": ("f2efe6", 0.5, 0.0),
    "Sign": ("1a1a22", 0.5, 0.0),
}


def get_mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    b = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if b is None:
        b = nt.nodes.new('ShaderNodeBsdfPrincipled')
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(b.outputs[0], out.inputs[0])
    col, rough, metal = MAT_COL.get(name, ("888888", 0.6, 0.0))
    lin = to_linear(hexrgb(col))
    b.inputs["Base Color"].default_value = (*lin, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*lin, 1.0)
    return m


def T(xf, p):
    if xf is None:
        return Vector(p)
    return xf @ Vector(p)


def at(x, y, z, rz=0.0):
    return Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, 'Z')


def newell(P):
    n = Vector((0.0, 0.0, 0.0))
    for i in range(len(P)):
        a, b = P[i], P[(i + 1) % len(P)]
        n.x += (a.y - b.y) * (a.z + b.z)
        n.y += (a.z - b.z) * (a.x + b.x)
        n.z += (a.x - b.x) * (a.y + b.y)
    return n


class MB:
    """Constructor de mallas: vértices, caras con material y UV por esquina."""

    def __init__(self):
        self.v = []
        self.f = []
        self.fm = []
        self.uv = []
        self.mats = []

    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def vert(self, p):
        self.v.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.v) - 1

    def face(self, idx, mat, uvs=None):
        # sin vértices repetidos seguidos (los polos de los tornos)
        out = []
        ouv = []
        uvs = uvs if uvs is not None else [(0.0, 0.0)] * len(idx)
        for i, v in enumerate(idx):
            if out and out[-1] == v:
                continue
            out.append(v)
            ouv.append(uvs[i])
        if len(out) > 1 and out[0] == out[-1]:
            out.pop()
            ouv.pop()
        if len(out) < 3:
            return
        self.f.append(out)
        self.fm.append(self.mi(mat))
        self.uv.append(ouv)

    def face_n(self, pts, mat, want, uvs=None):
        """Cara con los puntos pts orientada para que su normal vaya hacia want."""
        P = [Vector(p) for p in pts]
        ids = [self.vert(p) for p in P]
        if newell(P).dot(Vector(want)) < 0.0:
            ids.reverse()
            uvs = list(reversed(uvs)) if uvs else None
        self.face(ids, mat, uvs)

    # -------------------------------------------------------------- piezas

    def lathe(self, prof, mat, seg=48, xf=None, a0=0.0, a1=TAU, uv=None, vflip=False, seg_mat=None, swap=False):
        """Torno alrededor del eje Z. prof: [(r, z)] recorrido de forma que, girando en sentido antihorario,
        la cara quede hacia fuera (por fuera hacia arriba, por arriba hacia dentro, por dentro hacia abajo).
        mat: un material o una lista (uno por tramo del perfil). uv: 'polar' (u = ángulo / 2π, v = perfil;
        swap: al revés). seg_mat(k): material del sector k (las casillas de la ruleta)."""
        full = abs((a1 - a0) - TAU) < 1e-6
        ncol = seg if full else seg + 1
        rows = []
        for (r, z) in prof:
            if r < 1e-7:
                c = self.vert(T(xf, (0.0, 0.0, z)))
                rows.append([c] * ncol)
                continue
            row = []
            for k in range(ncol):
                a = a0 + (a1 - a0) * k / seg
                row.append(self.vert(T(xf, (r * math.cos(a), r * math.sin(a), z))))
            rows.append(row)
        L = [0.0]
        for i in range(1, len(prof)):
            L.append(L[-1] + math.hypot(prof[i][0] - prof[i - 1][0], prof[i][1] - prof[i - 1][1]))
        tot = max(L[-1], 1e-9)
        for i in range(len(prof) - 1):
            m = mat[i] if isinstance(mat, (list, tuple)) else mat
            for k in range(seg):
                k1 = (k + 1) % ncol if full else k + 1
                a, b, c, d = rows[i][k], rows[i][k1], rows[i + 1][k1], rows[i + 1][k]
                uvs = None
                if uv == 'polar':
                    u0 = k / seg
                    u1 = (k + 1) / seg
                    v0 = L[i] / tot
                    v1 = L[i + 1] / tot
                    if vflip:
                        v0, v1 = 1.0 - v0, 1.0 - v1
                    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
                    if swap:
                        uvs = [(q[1], q[0]) for q in uvs]
                self.face([a, b, c, d], seg_mat(k) if seg_mat else m, uvs)

    def box(self, c, size, mat, xf=None, uv=False):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        P = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
             (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        base = Matrix.Translation(c)
        if xf is not None:
            base = xf @ base
        ids = [self.vert(base @ Vector(p)) for p in P]
        quads = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        for q in quads:
            self.face([ids[i] for i in q], mat, [(0, 1), (1, 1), (1, 0), (0, 0)] if uv else None)

    def cyl(self, c, r, h, mat, seg=24, xf=None, r_top=None, caps=True):
        rt = r if r_top is None else r_top
        prof = []
        if caps:
            prof.append((0.0, 0.0))
        prof += [(r, 0.0), (rt, h)]
        if caps:
            prof.append((0.0, h))
        base = Matrix.Translation(c)
        if xf is not None:
            base = xf @ base
        self.lathe(prof, mat, seg, base)

    def sphere(self, c, r, mat, seg=16, rings=10, xf=None):
        prof = []
        for i in range(rings + 1):
            t = -math.pi / 2 + math.pi * i / rings
            prof.append((r * math.cos(t) if 0 < i < rings else 0.0, r * math.sin(t)))
        base = Matrix.Translation(c)
        if xf is not None:
            base = xf @ base
        self.lathe(prof, mat, seg, base)

    def tube(self, pts, r, mat, seg=8, caps=True):
        """Tubo de sección circular a lo largo de una polilínea (brazos de la lámpara, la palanca)."""
        pts = [Vector(p) for p in pts]
        rad = r if isinstance(r, (list, tuple)) else [r] * len(pts)
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = (pts[i + 1] - pts[i - 1]).normalized()
            if prev_n is None:
                up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                n = t.cross(up).normalized()
            else:
                n = (prev_n - t * prev_n.dot(t)).normalized()
            prev_n = n
            bn = t.cross(n).normalized()
            ring = []
            for k in range(seg):
                a = TAU * k / seg
                ring.append(self.vert(p + (n * math.cos(a) + bn * math.sin(a)) * rad[i]))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for k in range(seg):
                k1 = (k + 1) % seg
                self.face([rings[i][k], rings[i + 1][k], rings[i + 1][k1], rings[i][k1]], mat)
        if caps:
            c0 = self.vert(pts[0])
            c1 = self.vert(pts[-1])
            for k in range(seg):
                k1 = (k + 1) % seg
                self.face([c0, rings[0][k1], rings[0][k]], mat)
                self.face([c1, rings[-1][k], rings[-1][k1]], mat)

    def sweep(self, path, prof, mat, closed=True):
        """Perfil a lo largo de un camino en planta (en sentido antihorario). prof: [(salida hacia fuera, z)]
        recorrido igual que en lathe (por fuera hacia arriba, por arriba hacia dentro)."""
        n = len(path)
        offs = []
        for i in range(n):
            p = Vector(path[i])
            has_prev = closed or i > 0
            has_next = closed or i < n - 1
            n0 = n1 = None
            if has_prev:
                e0 = (p - Vector(path[i - 1])).normalized()
                n0 = Vector((e0.y, -e0.x))
            if has_next:
                e1 = (Vector(path[(i + 1) % n]) - p).normalized()
                n1 = Vector((e1.y, -e1.x))
            if n0 is not None and n1 is not None:
                nn = n0 + n1
                nn = nn.normalized() if nn.length > 1e-6 else n1
                offs.append(nn / max(0.35, nn.dot(n1)))
            else:
                offs.append(n0 if n0 is not None else n1)
        rows = []
        for i in range(n):
            p = Vector(path[i])
            rows.append([self.vert((p.x + offs[i].x * o, p.y + offs[i].y * o, z)) for (o, z) in prof])
        last = n if closed else n - 1
        for i in range(last):
            i1 = (i + 1) % n
            for j in range(len(prof) - 1):
                mm = mat[j] if isinstance(mat, (list, tuple)) else mat
                self.face([rows[i][j], rows[i1][j], rows[i1][j + 1], rows[i][j + 1]], mm)
        if not closed:
            mm = mat[0] if isinstance(mat, (list, tuple)) else mat
            t0 = Vector(path[1]) - Vector(path[0])
            t1 = Vector(path[-1]) - Vector(path[-2])
            for ring, want in ((rows[0], (-t0.x, -t0.y, 0.0)), (rows[-1], (t1.x, t1.y, 0.0))):
                P = [Vector(self.v[i]) for i in ring]
                ids = list(ring)
                if newell(P).dot(Vector(want)) < 0.0:
                    ids.reverse()
                self.face(ids, mm)

    def ngon(self, pts2d, z, mat, uv_rect=None, down=False):
        """Cara plana (convexa) a la altura z, mirando arriba. uv_rect = (x0, y0, x1, y1): UV plana con la
        imagen derecha vista desde -Y (arriba de la imagen hacia +Y)."""
        ids = [self.vert((p[0], p[1], z)) for p in pts2d]
        uvs = None
        if uv_rect:
            x0, y0, x1, y1 = uv_rect
            uvs = [((p[0] - x0) / (x1 - x0), (y1 - p[1]) / (y1 - y0)) for p in pts2d]
        if down:
            ids = list(reversed(ids))
            uvs = list(reversed(uvs)) if uvs else None
        self.face(ids, mat, uvs)

    def build(self, name, loc=(0, 0, 0), sharp=35.0, bevel=0.0, bevel_seg=2):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], self.f)
        for mn in self.mats:
            me.materials.append(get_mat(mn))
        for i, p in enumerate(me.polygons):
            p.material_index = self.fm[i]
        # las UV se escriben como en una imagen (v hacia abajo); Blender las cuenta desde abajo (y el .glb las
        # vuelve a dar la vuelta al exportar), así que aquí se invierte v
        uvl = me.uv_layers.new(name="UVMap")
        for i, p in enumerate(me.polygons):
            for k in range(p.loop_total):
                u, v = self.uv[i][k]
                uvl.data[p.loop_start + k].uv = (u, 1.0 - v)
        me.validate()
        me.update()
        # fusiona vértices repetidos (costuras de los tornos) sin tocar las UV
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(me)
        bm.free()
        try:
            me.shade_smooth()
            me.set_sharp_from_angle(angle=math.radians(sharp))
        except Exception:
            for p in me.polygons:
                p.use_smooth = True
        ob = bpy.data.objects.new(name, me)
        SCN.collection.objects.link(ob)
        ob.location = loc
        if bevel > 0.0:
            md = ob.modifiers.new("bevel", 'BEVEL')
            md.width = bevel
            md.segments = bevel_seg
            md.limit_method = 'ANGLE'
            md.angle_limit = math.radians(50)
            try:
                md.use_clamp_overlap = True
            except Exception:
                pass
        return ob


def rrect(w, d, r, n=8, cx=0.0, cy=0.0):
    """Rectángulo de esquinas redondeadas en sentido antihorario."""
    hw, hd = w / 2 - r, d / 2 - r
    pts = []
    for (sx, sy, a0) in ((1, -1, -math.pi / 2), (1, 1, 0.0), (-1, 1, math.pi / 2), (-1, -1, math.pi)):
        for k in range(n + 1):
            a = a0 + (math.pi / 2) * k / n
            pts.append((cx + sx * hw + r * math.cos(a), cy + sy * hd + r * math.sin(a)))
    # sin puntos repetidos (con r = la mitad del fondo, los extremos de dos esquinas coinciden)
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > 1e-6 or abs(p[1] - out[-1][1]) > 1e-6):
            out.append(p)
    if abs(out[0][0] - out[-1][0]) < 1e-6 and abs(out[0][1] - out[-1][1]) < 1e-6:
        out.pop()
    return out


def offset_path(path, d):
    """Camino desplazado d hacia fuera (negativo: hacia dentro). Mismo sentido."""
    n = len(path)
    out = []
    for i in range(n):
        p = Vector(path[i])
        e0 = (p - Vector(path[i - 1])).normalized()
        e1 = (Vector(path[(i + 1) % n]) - p).normalized()
        n0 = Vector((e0.y, -e0.x))
        n1 = Vector((e1.y, -e1.x))
        nn = (n0 + n1).normalized()
        q = p + nn * d / max(0.35, nn.dot(n1))
        out.append((q.x, q.y))
    return out


# ------------------------------------------------------------------ canto de las mesas

## Altura del tablero de las mesas
TOP = 0.80


def rail_profile(top=TOP, apron=0.17, cushion=0.13, height=0.045):
    """Faldón de madera, junquillo, cojín de cuero acolchado y el borde interior que baja al paño."""
    p = [(-0.08, top - apron), (0.0, top - apron), (0.0, top - 0.035), (-0.004, top - 0.022), (-0.012, top - 0.016)]
    mats = ["WoodDark", "Wood", "Wood", "Wood"]
    n = 9
    cx = -0.012 - cushion / 2
    for k in range(n + 1):
        a = math.pi * k / n
        p.append((cx + math.cos(a) * cushion / 2, top - 0.01 + math.sin(a) * height))
        mats.append("Leather")
    p.append((-0.012 - cushion - 0.004, top - 0.008))
    p.append((-0.012 - cushion - 0.03, top - 0.005))
    mats += ["Wood", "Wood"]
    return p, mats


def turned_leg(mb, x, y, h, mat="Wood", foot="Gold"):
    prof = [(0.0, 0.0), (0.035, 0.0), (0.04, 0.02), (0.03, 0.05), (0.024, 0.09), (0.03, 0.14),
            (0.022, 0.3), (0.028, h * 0.62), (0.036, h * 0.7), (0.026, h * 0.78), (0.04, h - 0.02),
            (0.045, h), (0.0, h)]
    mats = [foot, foot, foot] + [mat] * (len(prof) - 4)
    mb.lathe(prof, mats, 18, at(x, y, 0))


# ------------------------------------------------------------------ ruleta

## Medidas que usa el juego (casino_3d.gd) para mover la bola
RW_TRACK_R = 0.3705     # centro de la bola rodando por la pista
RW_TRACK_Z = 0.069
RW_POCKET_R = 0.2035    # centro de la bola en su casilla
RW_POCKET_Z = 0.0255
RW_BALL_R = 0.0095
ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22,
         18, 29, 7, 28, 12, 35, 3, 26]
REDS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}
DA = TAU / 37.0


def pocket_angle(i):
    """Centro de la casilla i (en el orden de la rueda, en sentido horario empezando por el 0 en +Y)."""
    return math.pi / 2 - i * DA


def make_roulette():
    # ---- caja fija: madera, pista de la bola y los rombos cromados
    mb = MB()
    prof = [(0.36, -0.002), (0.415, -0.002), (0.415, 0.07), (0.413, 0.085), (0.405, 0.095), (0.394, 0.099),
            (0.386, 0.097), (0.382, 0.09), (0.38, 0.066), (0.376, 0.06), (0.368, 0.059), (0.33, 0.052),
            (0.29, 0.04), (0.268, 0.031), (0.266, 0.012), (0.255, 0.006)]
    mats = ["WoodDark", "Wood", "Wood", "Gold", "Gold", "Gold", "Wood", "WoodDark", "WoodDark", "WoodDark",
            "WoodDark", "WoodDark", "WoodDark", "Black", "Black"]
    mb.lathe(prof, mats, 96)
    slope = math.atan2(0.052 - 0.04, 0.33 - 0.29)
    for k in range(8):
        a = k * TAU / 8 + DA * 0.5
        r = 0.31
        z = 0.046
        xf = at(r * math.cos(a), r * math.sin(a), z, a) @ Matrix.Rotation(-slope, 4, 'Y')
        L, W = (0.034, 0.012) if k % 2 == 0 else (0.012, 0.03)
        top = mb.vert(xf @ Vector((0, 0, 0.007)))
        q = [mb.vert(xf @ Vector(p)) for p in ((L / 2, 0, 0), (0, W / 2, 0), (-L / 2, 0, 0), (0, -W / 2, 0))]
        for i in range(4):
            mb.face([q[i], q[(i + 1) % 4], top], "Chrome")
        mb.face([q[3], q[2], q[1], q[0]], "Chrome")
    bowl = mb.build("RW_Bowl", sharp=30)

    # ---- plato que gira
    mb = MB()
    mb.lathe([(0.262, 0.004), (0.262, 0.03), (0.26, 0.034), (0.257, 0.035)], "Gold", 148)
    # aro de los números: u = ángulo / 2π (antihorario desde +X), v = 0 dentro y 1 fuera
    mb.lathe([(0.257, 0.035), (0.222, 0.029)], "RW_Numbers", 148, uv='polar', vflip=True)
    mb.lathe([(0.222, 0.029), (0.2215, 0.016)], "Chrome", 148)

    def pmat(i):
        num = ORDER[i % 37]
        return "RW_Green" if num == 0 else ("RW_Red" if num in REDS else "RW_Black")
    # suelo de las casillas, del color de su número: el sector k (de 4 por casilla, en sentido antihorario
    # desde el borde de arriba de la casilla 0) es de la casilla (147 - k) // 4
    a1 = pocket_angle(0) + DA / 2
    mb.lathe([(0.2215, 0.016), (0.185, 0.016)], "RW_Black", 148, a0=a1 - TAU, a1=a1,
             seg_mat=lambda k: pmat((147 - k) // 4))
    # pared interior y cono de madera
    mb.lathe([(0.185, 0.016), (0.183, 0.03), (0.172, 0.036), (0.12, 0.052), (0.075, 0.066), (0.06, 0.07)],
             ["Chrome", "Gold", "RW_Cone", "RW_Cone", "Gold"], 96)
    for i in range(37):
        mb.box((0.2035, 0.0, 0.0235), (0.037, 0.0026, 0.015), "Chrome", at(0, 0, 0, pocket_angle(i) + DA / 2))
    # torreta central con la cruz
    mb.lathe([(0.06, 0.07), (0.05, 0.074), (0.03, 0.078), (0.016, 0.086), (0.011, 0.1), (0.015, 0.108),
              (0.009, 0.12), (0.013, 0.128), (0.012, 0.136), (0.006, 0.142), (0.0, 0.146)], "Gold", 24)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, 0.122)) + d * 0.008, Vector((0, 0, 0.123)) + d * 0.04, Vector((0, 0, 0.128)) + d * 0.066]
        mb.tube(pts, [0.0045, 0.0038, 0.0034], "Gold", 10)
        mb.sphere(tuple(Vector((0, 0, 0.13)) + d * 0.072), 0.0075, "Gold", 12, 8)
    rotor = mb.build("RW_Rotor", sharp=30)

    mb = MB()
    mb.sphere((0, 0, 0), RW_BALL_R, "Ivory", 18, 12)
    ball = mb.build("RW_Ball", sharp=80)
    return [bowl, rotor, ball]


def make_dolly():
    mb = MB()
    mb.lathe([(0.0, 0.0), (0.018, 0.0), (0.018, 0.004), (0.012, 0.008), (0.006, 0.016), (0.0045, 0.03)], "Gold", 20)
    mb.lathe([(0.0045, 0.03), (0.014, 0.036), (0.016, 0.046), (0.01, 0.056), (0.0, 0.06)], "Crystal", 8)
    return [mb.build("Dolly", sharp=40)]


# ------------------------------------------------------------------ mesas

def make_roulette_table():
    mb = MB()
    # (el radio de las esquinas tiene que ser mayor que lo que entra el cojín: si no, el borde del paño se cruza)
    W, D, R = 2.8, 1.3, 0.24
    path = rrect(W, D, R, 8)
    prof, mats = rail_profile()
    mb.sweep(path, prof, mats)
    mb.ngon(offset_path(path, -0.165), TOP - 0.003, "Felt", uv_rect=(-W / 2, -D / 2, W / 2, D / 2))
    mb.ngon(offset_path(path, -0.08), TOP - 0.17, "WoodDark", down=True)
    for sx in (-1, 1):
        for sy in (-1, 1):
            turned_leg(mb, sx * (W / 2 - 0.25), sy * (D / 2 - 0.22), TOP - 0.17)
    return [mb.build("RT_Table", sharp=40)]


BJ_R = 1.08
BJ_CY = 0.38


def make_blackjack_table():
    mb = MB()
    R, cy = BJ_R, BJ_CY
    n = 40
    arc = [(R * math.cos(math.pi + math.pi * k / n), cy + R * math.sin(math.pi + math.pi * k / n)) for k in range(n + 1)]
    # contorno: la curva de los jugadores y el lado recto del crupier (de vuelta)
    path = arc + [(R * 0.33, cy), (-R * 0.33, cy)]
    apron = [(-0.08, TOP - 0.17), (0.0, TOP - 0.17), (0.0, TOP - 0.03), (-0.006, TOP - 0.015), (-0.03, TOP - 0.006)]
    mb.sweep(path, apron, ["WoodDark", "Wood", "Wood", "Wood"])
    # cojín de cuero solo en la curva de los jugadores
    c = 0.13
    cush = []
    for k in range(10):
        a = math.pi * k / 9
        cush.append((-0.03 - c / 2 + math.cos(a) * c / 2, TOP - 0.006 + math.sin(a) * 0.045))
    cush.append((-0.03 - c - 0.004, TOP - 0.004))
    mb.sweep(arc, cush, "Leather", closed=False)
    mb.ngon(offset_path(path, -0.03), TOP - 0.008, "Felt", uv_rect=(-R, cy - R, R, cy))
    mb.ngon(offset_path(path, -0.08), TOP - 0.17, "WoodDark", down=True)
    for sx in (-0.55, 0.55):
        mb.lathe([(0.0, 0.0), (0.26, 0.0), (0.26, 0.03), (0.2, 0.05), (0.08, 0.09), (0.06, 0.14), (0.06, TOP - 0.2),
                  (0.12, TOP - 0.18), (0.12, TOP - 0.17), (0.0, TOP - 0.17)],
                 ["Gold", "Gold", "WoodDark", "WoodDark", "WoodDark", "WoodDark", "Gold", "Gold", "Gold"], 32,
                 at(sx, cy - 0.45, 0))
    table = mb.build("BJ_Table", sharp=40)

    # bandeja de fichas del crupier (8 canales)
    mb = MB()
    mb.box((0, 0, 0.012), (0.52, 0.13, 0.024), "WoodDark")
    for k in range(9):
        mb.box((-0.24 + k * 0.06, 0, 0.028), (0.006, 0.13, 0.01), "Chrome")
    mb.box((0, -0.068, 0.028), (0.52, 0.006, 0.012), "Chrome")
    mb.box((0, 0.068, 0.03), (0.52, 0.006, 0.016), "Chrome")
    tray = mb.build("BJ_Tray", loc=(0, cy - 0.09, TOP), sharp=40)

    # sabot: caja inclinada con la boca hacia el crupier y la pala de acero delante
    mb = MB()
    sh = [(-0.06, -0.16), (0.06, -0.16), (0.06, 0.12), (-0.06, 0.12)]
    lo = [Vector((x, y, 0.0)) for (x, y) in sh]
    hi = [Vector((x, y, 0.05 + 0.05 * (y + 0.16) / 0.28)) for (x, y) in sh]
    mb.face_n(lo, "WoodDark", (0, 0, -1))
    mb.face_n(hi, "WoodDark", (0, 0, 1))
    for i in range(4):
        j = (i + 1) % 4
        mid = (lo[i] + lo[j]) * 0.5
        mb.face_n([lo[i], lo[j], hi[j], hi[i]], "WoodDark", (mid.x, mid.y, 0.0))
    mb.box((0, -0.162, 0.03), (0.1, 0.006, 0.05), "Chrome")
    mb.box((0, -0.02, 0.0745), (0.105, 0.22, 0.004), "Black", Matrix.Rotation(math.atan2(0.05, 0.28), 4, 'X'))
    shoe = mb.build("BJ_Shoe", loc=(0.62, cy - 0.16, TOP), sharp=30)

    mb = MB()
    mb.box((0, 0, 0.004), (0.09, 0.13, 0.008), "WoodDark")
    mb.box((0, 0.062, 0.04), (0.09, 0.006, 0.07), "Glass")
    mb.box((-0.044, 0, 0.04), (0.004, 0.13, 0.07), "Glass")
    mb.box((0.044, 0, 0.04), (0.004, 0.13, 0.07), "Glass")
    disc = mb.build("BJ_Discard", loc=(-0.62, cy - 0.14, TOP), sharp=30)
    return [table, tray, shoe, disc]


def make_poker_table():
    mb = MB()
    W, D = 2.5, 1.3
    path = rrect(W, D, D / 2, 16)
    prof, mats = rail_profile()
    mb.sweep(path, prof, mats)
    mb.ngon(offset_path(path, -0.165), TOP - 0.003, "Felt", uv_rect=(-W / 2, -D / 2, W / 2, D / 2))
    mb.ngon(offset_path(path, -0.08), TOP - 0.17, "WoodDark", down=True)
    for sx in (-0.55, 0.55):
        mb.lathe([(0.0, 0.0), (0.28, 0.0), (0.28, 0.03), (0.2, 0.05), (0.08, 0.1), (0.07, 0.15), (0.07, TOP - 0.2),
                  (0.14, TOP - 0.18), (0.14, TOP - 0.17), (0.0, TOP - 0.17)],
                 ["Gold", "Gold", "WoodDark", "WoodDark", "WoodDark", "WoodDark", "Gold", "Gold", "Gold"], 32,
                 at(sx, 0, 0))
    return [mb.build("PK_Table", sharp=40)]


# ------------------------------------------------------------------ tragaperras

SL_REEL_R = 0.118
SL_REEL_W = 0.128
SL_REEL_X = (-0.152, 0.0, 0.152)
SL_REEL_Y = -0.02
SL_REEL_Z = 1.2
SL_W = 0.64


def make_slot():
    mb = MB()
    W = SL_W
    # zócalo cromado y cuerpo bajo, con el panel de la barriga (dibujo del juego)
    mb.box((0, 0, 0.04), (W + 0.04, 0.6, 0.08), "Chrome")
    mb.box((0, 0.02, 0.5), (W, 0.56, 0.84), "SL_Body")
    mb.box((0, -0.262, 0.5), (W - 0.08, 0.008, 0.6), "Gold")
    mb.face_n([(-0.27, -0.267, 0.22), (0.27, -0.267, 0.22), (0.27, -0.267, 0.78), (-0.27, -0.267, 0.78)], "SL_Belly",
              (0, -1, 0), [(0, 1), (1, 1), (1, 0), (0, 0)])
    # bandeja de monedas
    mb.box((0, -0.3, 0.14), (0.4, 0.09, 0.012), "Chrome")
    mb.box((0, -0.343, 0.18), (0.4, 0.006, 0.08), "Chrome")
    for sx in (-1, 1):
        mb.box((sx * 0.2, -0.3, 0.18), (0.006, 0.09, 0.08), "Chrome")
    # pupitre de los botones, inclinado
    d0, d1 = -0.38, -0.24
    mb.face_n([(-W / 2, d0, 0.92), (W / 2, d0, 0.92), (W / 2, d1, 0.99), (-W / 2, d1, 0.99)], "SL_Deck", (0, -0.45, 1))
    mb.face_n([(-W / 2, d0, 0.86), (W / 2, d0, 0.86), (W / 2, d0, 0.92), (-W / 2, d0, 0.92)], "Chrome", (0, -1, 0))
    for sx in (-1, 1):
        x = sx * W / 2
        mb.face_n([(x, d0, 0.86), (x, d1, 0.92), (x, d1, 0.99), (x, d0, 0.92)], "SL_Body", (sx, 0, 0))
    mb.box((0, -0.31, 0.89), (W, 0.14, 0.06), "SL_Body")
    tilt = math.atan2(0.07, 0.14)
    for i, x in enumerate((-0.17, -0.02, 0.15)):
        xf = Matrix.Translation((x, -0.31, 0.955)) @ Matrix.Rotation(tilt, 4, 'X')
        big = i == 2
        mb.cyl((0, 0, 0), 0.04 if big else 0.028, 0.012, "Chrome", 20, xf)
        mb.cyl((0, 0, 0.012), 0.033 if big else 0.022, 0.014, "SL_Btn", 20, xf, r_top=0.03 if big else 0.02)
    # cuerpo de los rodillos: laterales, fondo oscuro y marco cromado de la ventana
    z0, z1 = 0.99, 1.43
    for sx in (-1, 1):
        mb.box((sx * (W / 2 - 0.03), 0.02, (z0 + z1) / 2), (0.06, 0.56, z1 - z0), "SL_Body")
    mb.box((0, 0.2, (z0 + z1) / 2), (W - 0.1, 0.12, z1 - z0), "SL_Inner")
    mb.box((0, 0.02, z0 + 0.01), (W - 0.1, 0.4, 0.02), "SL_Inner")
    mb.box((0, 0.02, z1 - 0.01), (W - 0.1, 0.4, 0.02), "SL_Inner")
    mb.box((0, -0.22, z0 + 0.04), (W, 0.06, 0.1), "SL_Body")
    mb.box((0, -0.22, z1 - 0.04), (W, 0.06, 0.1), "SL_Body")
    fz0, fz1, fx = 1.07, 1.35, 0.245
    for (cx, cz, sx, sz) in ((0, fz0 - 0.012, 2 * fx + 0.05, 0.024), (0, fz1 + 0.012, 2 * fx + 0.05, 0.024),
                             (-fx - 0.012, (fz0 + fz1) / 2, 0.024, fz1 - fz0 + 0.048), (fx + 0.012, (fz0 + fz1) / 2, 0.024, fz1 - fz0 + 0.048)):
        mb.box((cx, -0.256, cz), (sx, 0.022, sz), "Chrome")
    for sx in (-1, 1):
        mb.box((sx * (fx + 0.03), -0.22, (fz0 + fz1) / 2), (0.05, 0.06, fz1 - fz0), "SL_Body")
    for x in (-0.076, 0.076):
        mb.box((x, -0.09, (fz0 + fz1) / 2), (0.01, 0.12, fz1 - fz0), "SL_Inner")
    # línea de premio y cristal
    mb.box((0, -0.168, SL_REEL_Z), (2 * fx, 0.003, 0.004), "SL_Payline")
    mb.face_n([(-fx, -0.236, fz0), (fx, -0.236, fz0), (fx, -0.236, fz1), (-fx, -0.236, fz1)], "Glass", (0, -1, 0))
    # caja de arriba con el letrero
    mb.box((0, 0.02, 1.58), (W, 0.56, 0.3), "SL_Body")
    mb.face_n([(-0.27, -0.262, 1.46), (0.27, -0.262, 1.46), (0.27, -0.262, 1.7), (-0.27, -0.262, 1.7)], "SL_Sign",
              (0, -1, 0), [(0, 1), (1, 1), (1, 0), (0, 0)])
    mb.box((0, -0.258, 1.445), (W, 0.02, 0.02), "Chrome")
    # remate en arco con el escudo (UV plana) y una tira de bombillas
    n = 24
    ah = W / 2 * 0.55
    arc = [(W / 2 * math.cos(math.pi * k / n), 1.73 + ah * math.sin(math.pi * k / n)) for k in range(n + 1)]
    for k in range(n):
        (xa, za), (xb, zb) = arc[k], arc[k + 1]
        mid = ((xa + xb) / 2, 0.0, (za + zb) / 2 - 1.73)
        mb.face_n([(xa, -0.26, za), (xb, -0.26, zb), (xb, 0.3, zb), (xa, 0.3, za)], "SL_Body", mid)
        uv = [(0.5, 1.0), (0.5 + xa / W, 1.0 - (za - 1.73) / ah), (0.5 + xb / W, 1.0 - (zb - 1.73) / ah)]
        mb.face_n([(0.0, -0.26, 1.73), (xa, -0.26, za), (xb, -0.26, zb)], "SL_Crest", (0, -1, 0), uv)
        mb.face_n([(0.0, 0.3, 1.73), (xa, 0.3, za), (xb, 0.3, zb)], "SL_Body", (0, 1, 0))
    mb.box((0, 0.02, 1.731), (W + 0.02, 0.58, 0.012), "Chrome")
    mb.tube([(x * 0.985, -0.262, 1.73 + (z - 1.73) * 0.985) for (x, z) in arc], 0.012, "SL_Lights", 8)
    for k in range(1, n, 2):
        x, z = arc[k]
        mb.sphere((x * 0.985, -0.272, 1.73 + (z - 1.73) * 0.985), 0.014, "Bulb", 10, 6)
    # bisagra de la palanca (lado derecho)
    mb.cyl((0, 0, 0), 0.05, 0.03, "Chrome", 24, Matrix.Translation((W / 2, SL_REEL_Y, 1.08)) @ Matrix.Rotation(math.pi / 2, 4, 'Y'))
    cab = mb.build("SL_Cabinet", sharp=35)

    reels = []
    for i, x in enumerate(SL_REEL_X):
        mb = MB()
        # cilindro con el eje en X: u = de izquierda a derecha, v = la vuelta (hacia abajo por delante)
        xf = Matrix.Rotation(math.pi / 2, 4, 'Y')
        mb.lathe([(SL_REEL_R, -SL_REEL_W / 2), (SL_REEL_R, SL_REEL_W / 2)], "SL_Reel", 72, xf, uv='polar', swap=True)
        mb.lathe([(SL_REEL_R, SL_REEL_W / 2), (0.0, SL_REEL_W / 2)], "SL_Inner", 36, xf)
        mb.lathe([(0.0, -SL_REEL_W / 2), (SL_REEL_R, -SL_REEL_W / 2)], "SL_Inner", 36, xf)
        reels.append(mb.build("SL_Reel_%d" % i, loc=(x, SL_REEL_Y, SL_REEL_Z), sharp=40))

    mb = MB()
    mb.cyl((0.0, 0, 0), 0.032, 0.04, "Chrome", 20, Matrix.Rotation(math.pi / 2, 4, 'Y'))
    mb.tube([(0.03, 0, 0), (0.05, 0, 0.02), (0.06, 0, 0.12), (0.062, 0, 0.3), (0.062, 0, 0.42)], 0.011, "Chrome", 12)
    mb.sphere((0.062, 0, 0.45), 0.036, "SL_Knob", 20, 12)
    lever = mb.build("SL_Lever", loc=(W / 2 + 0.03, SL_REEL_Y, 1.08), sharp=40)
    return [cab] + reels + [lever]


# ------------------------------------------------------------------ fichas

CHIP_R = 0.02
CHIP_H = 0.0034


def make_chip():
    mb = MB()
    n = 32
    spot = lambda k: "ChipSpot" if (k // 2) % 2 == 0 else "ChipBody"
    # canto: tramos alternos (8 marcas blancas)
    for k in range(n):
        a0 = TAU * k / n
        a1 = TAU * (k + 1) / n
        q = [mb.vert((CHIP_R * math.cos(a), CHIP_R * math.sin(a), z)) for (a, z) in ((a0, 0.0003), (a1, 0.0003), (a1, CHIP_H - 0.0003), (a0, CHIP_H - 0.0003))]
        mb.face(q, spot(k))
    for up in (True, False):
        z = CHIP_H if up else 0.0
        zz = CHIP_H - 0.0003 if up else 0.0003
        if up:
            mb.lathe([(CHIP_R, zz), (CHIP_R - 0.0004, z)], "ChipBody", n)
            mb.lathe([(CHIP_R - 0.0004, z), (0.0145, z)], "ChipBody", n, seg_mat=spot)
        else:
            mb.lathe([(CHIP_R - 0.0004, z), (CHIP_R, zz)], "ChipBody", n)
            mb.lathe([(0.0145, z), (CHIP_R - 0.0004, z)], "ChipBody", n, seg_mat=spot)
        # centro con UV plana (el juego pone el valor)
        pts = []
        uvs = []
        for k in range(n):
            a = TAU * k / n
            x, y = 0.0145 * math.cos(a), 0.0145 * math.sin(a)
            pts.append((x, y, z))
            uvs.append((0.5 + x / 0.029, 0.5 - y / 0.029))
        mb.face_n(pts, "ChipInlay", (0, 0, 1 if up else -1), uvs)
    return [mb.build("Chip", sharp=50)]


# ------------------------------------------------------------------ salón

def make_chandelier():
    mb = MB()
    # columna central de latón (cuelga del techo: z = 0 es el enganche)
    mb.lathe([(0.0, -1.62), (0.06, -1.6), (0.1, -1.52), (0.07, -1.44), (0.05, -1.3), (0.09, -1.22), (0.06, -1.1),
              (0.035, -0.95), (0.05, -0.8), (0.03, -0.62), (0.02, -0.4), (0.03, -0.1), (0.08, -0.05), (0.12, 0.0),
              (0.0, 0.0)], "Gold", 24)
    tiers = [(8, 0.42, -1.25, 0.10), (12, 0.66, -1.12, 0.13), (16, 0.86, -0.98, 0.16)]
    for ti, (n, R, z, lift) in enumerate(tiers):
        tp = []
        for k in range(n):
            a = TAU * (k + 0.5 * ti) / n
            d = Vector((math.cos(a), math.sin(a), 0))
            base = Vector((0, 0, z - 0.1))
            pts = [base + d * 0.06, base + d * (R * 0.35) + Vector((0, 0, -0.07)), base + d * (R * 0.7) + Vector((0, 0, -0.02)),
                   base + d * R + Vector((0, 0, lift * 0.5)), base + d * R + Vector((0, 0, lift))]
            mb.tube(pts, [0.012, 0.011, 0.01, 0.009, 0.009], "Gold", 8)
            tip = base + d * R + Vector((0, 0, lift))
            mb.lathe([(0.0, 0.0), (0.03, 0.005), (0.045, 0.02), (0.05, 0.03), (0.02, 0.032), (0.0, 0.032)], "Gold", 14,
                     Matrix.Translation(tip))
            mb.cyl(tuple(tip + Vector((0, 0, 0.032))), 0.014, 0.085, "Ivory", 12)
            mb.lathe([(0.0, 0.0), (0.012, 0.012), (0.014, 0.03), (0.008, 0.05), (0.0, 0.062)], "Bulb", 10,
                     Matrix.Translation(tip + Vector((0, 0, 0.117))))
            # gota de cristal colgando de la arandela
            mb.tube([tip + Vector((0, 0, -0.005)), tip + Vector((0, 0, -0.04))], 0.0015, "Gold", 4, caps=False)
            mb.lathe([(0.0, 0.0), (0.012, 0.03), (0.016, 0.05), (0.0, 0.07)], "Crystal", 6,
                     Matrix.Translation(tip + Vector((0, 0, -0.11))))
            tp.append(tip)
        # guirnaldas de cristales entre puntas vecinas
        for k in range(n):
            p0 = tp[k]
            p1 = tp[(k + 1) % n]
            for j in range(1, 7):
                t = j / 7
                p = p0.lerp(p1, t) + Vector((0, 0, -0.12 * math.sin(math.pi * t) - 0.01))
                s = 0.011
                xf = Matrix.Translation(p) @ Matrix.Rotation(t * 3.1 + k, 4, 'Z')
                v = [mb.vert(xf @ Vector(q)) for q in ((0, 0, s * 1.6), (s, 0, 0), (0, s, 0), (-s, 0, 0), (0, -s, 0), (0, 0, -s * 1.6))]
                for i in range(4):
                    mb.face([v[0], v[1 + i], v[1 + (i + 1) % 4]], "Crystal")
                    mb.face([v[5], v[1 + (i + 1) % 4], v[1 + i]], "Crystal")
    # corona de cristales colgantes bajo el piso de abajo
    for k in range(24):
        a = TAU * k / 24
        p = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, -1.52))
        mb.lathe([(0.0, 0.0), (0.01, 0.04), (0.014, 0.07), (0.0, 0.1)], "Crystal", 6, Matrix.Translation(p))
    mb.lathe([(0.0, -1.5), (0.18, -1.48), (0.32, -1.42), (0.34, -1.4), (0.0, -1.38)], "Gold", 32)
    return [mb.build("Chandelier", sharp=40)]


def make_column(h=4.6):
    mb = MB()
    # basa: plinto cuadrado, toro y escocia
    mb.box((0, 0, 0.09), (0.66, 0.66, 0.18), "Marble")
    mb.lathe([(0.0, 0.18), (0.3, 0.18), (0.31, 0.21), (0.3, 0.25), (0.27, 0.27), (0.26, 0.3), (0.28, 0.32),
              (0.27, 0.35), (0.24, 0.37)], ["Marble", "Marble", "Gold", "Gold", "Marble", "Marble", "Marble", "Marble"], 40)
    # fuste estriado con un poco de éntasis
    nf = 20
    seg = nf * 6
    rings = []
    zs = [0.37, 1.2, 2.4, h - 0.62]
    for z in zs:
        t = (z - zs[0]) / (zs[-1] - zs[0])
        R = 0.235 - 0.03 * t * t
        ring = []
        for k in range(seg):
            a = TAU * k / seg
            fl = max(0.0, math.cos(nf * a)) ** 3
            ring.append(mb.vert(((R - 0.014 * fl) * math.cos(a), (R - 0.014 * fl) * math.sin(a), z)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            k1 = (k + 1) % seg
            mb.face([rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]], "Marble")
    # capitel: collarino dorado, campana con volutas y ábaco
    zc = h - 0.62
    mb.lathe([(0.205, zc), (0.225, zc + 0.02), (0.22, zc + 0.05), (0.205, zc + 0.07), (0.23, zc + 0.2),
              (0.29, zc + 0.36), (0.33, zc + 0.44), (0.0, zc + 0.44)], ["Gold", "Gold", "Gold", "Marble", "Marble", "Gold", "Gold"], 40)
    for k in range(8):
        a = TAU * k / 8
        d = Vector((math.cos(a), math.sin(a), 0))
        pts = [Vector((0, 0, zc + 0.1)) + d * 0.22, Vector((0, 0, zc + 0.28)) + d * 0.27, Vector((0, 0, zc + 0.4)) + d * 0.33,
               Vector((0, 0, zc + 0.38)) + d * 0.36]
        mb.tube(pts, 0.016, "Gold", 8)
    mb.box((0, 0, zc + 0.5), (0.74, 0.74, 0.12), "Marble")
    mb.box((0, 0, zc + 0.585), (0.78, 0.78, 0.05), "Gold")
    return [mb.build("Column", sharp=40)]


def make_chair():
    mb = MB()
    # patas algo abiertas, asiento de terciopelo con canto dorado y respaldo de medallón
    for (x, y) in ((-0.21, -0.2), (0.21, -0.2), (-0.2, 0.2), (0.2, 0.2)):
        mb.tube([(x * 1.12, y * 1.12, 0.0), (x * 1.05, y * 1.05, 0.2), (x, y, 0.44)], [0.016, 0.019, 0.021], "Gold", 10)
    mb.box((0, 0, 0.46), (0.5, 0.48, 0.04), "Gold")
    sp = rrect(0.48, 0.46, 0.06, 4)
    mb.sweep(sp, [(0.0, 0.47), (0.01, 0.5), (0.0, 0.53), (-0.04, 0.545)], "Velvet")
    mb.ngon(offset_path(sp, -0.04), 0.545, "Velvet")
    for sx in (-1, 1):
        mb.tube([(sx * 0.2, 0.2, 0.46), (sx * 0.21, 0.22, 0.7), (sx * 0.19, 0.24, 0.98)], 0.017, "Gold", 10)
    oval = [(0.18 * math.cos(TAU * k / 32), 0.235, 0.84 + 0.17 * math.sin(TAU * k / 32)) for k in range(33)]
    mb.tube(oval, 0.018, "Gold", 10, caps=False)
    mb.face_n([(0.165 * math.cos(TAU * k / 32), 0.228, 0.84 + 0.155 * math.sin(TAU * k / 32)) for k in range(32)], "Velvet", (0, -1, 0))
    mb.face_n([(0.165 * math.cos(TAU * k / 32), 0.242, 0.84 + 0.155 * math.sin(TAU * k / 32)) for k in range(32)], "Velvet", (0, 1, 0))
    mb.sphere((0, 0.235, 1.03), 0.025, "Gold", 12, 8)
    return [mb.build("Chair", sharp=40)]


def make_stool():
    mb = MB()
    mb.lathe([(0.0, 0.0), (0.24, 0.0), (0.24, 0.025), (0.12, 0.05), (0.04, 0.07), (0.035, 0.66), (0.08, 0.68),
              (0.0, 0.69)], ["Gold", "Gold", "Gold", "Gold", "Chrome", "Gold", "Gold"], 28)
    ring = [(0.21 * math.cos(TAU * k / 32), 0.21 * math.sin(TAU * k / 32), 0.3) for k in range(33)]
    mb.tube(ring, 0.011, "Gold", 8, caps=False)
    for k in range(4):
        a = TAU * k / 4 + 0.4
        mb.tube([(0.035 * math.cos(a), 0.035 * math.sin(a), 0.3), (0.21 * math.cos(a), 0.21 * math.sin(a), 0.3)], 0.008, "Gold", 6)
    mb.lathe([(0.0, 0.68), (0.2, 0.68), (0.22, 0.7), (0.22, 0.74), (0.2, 0.77), (0.0, 0.78)], "Velvet", 32)
    # respaldo bajo, detrás (+Y)
    arc = [(0.2 * math.cos(math.pi * 0.2 + math.pi * 0.6 * k / 16), 0.2 * math.sin(math.pi * 0.2 + math.pi * 0.6 * k / 16)) for k in range(17)]
    mb.tube([(x, y, 0.98) for (x, y) in arc], 0.03, "Velvet", 10)
    for k in (2, 8, 14):
        x, y = arc[k]
        mb.tube([(x * 0.95, y * 0.95, 0.76), (x, y, 0.97)], 0.01, "Gold", 8)
    return [mb.build("Stool", sharp=40)]


def make_stanchion_rope():
    mb = MB()
    mb.lathe([(0.0, 0.0), (0.14, 0.0), (0.14, 0.02), (0.1, 0.04), (0.03, 0.06), (0.022, 0.08), (0.02, 0.9),
              (0.03, 0.91), (0.035, 0.93), (0.025, 0.95), (0.03, 0.97), (0.0, 1.0)], "Gold", 24)
    post = mb.build("Stanchion", sharp=40)
    mb = MB()
    pts = [(k / 20 * 1.2 - 0.6, 0.0, 0.93 - 0.18 * math.sin(math.pi * k / 20)) for k in range(21)]
    mb.tube(pts, 0.018, "Velvet", 10)
    rope = mb.build("Rope", sharp=60)
    return [post, rope]


def make_cashier():
    mb = MB()
    # mostrador de madera con balda de mármol y la reja de latón de la ventanilla
    mb.box((0, 0, 0.55), (1.6, 0.6, 1.1), "Wood")
    mb.box((0, -0.04, 1.12), (1.7, 0.72, 0.04), "Marble")
    for sx in (-1, 1):
        mb.box((sx * 0.75, 0, 1.7), (0.1, 0.5, 1.16), "Wood")
    mb.box((0, 0, 2.3), (1.6, 0.5, 0.08), "Wood")
    mb.box((0, -0.26, 2.42), (1.2, 0.04, 0.18), "Sign")
    for k in range(17):
        mb.cyl((-0.64 + k * 0.08, 0.0, 1.14), 0.006, 1.12, "Gold", 8)
    for z in (1.5, 1.95):
        mb.box((0, 0, z), (1.32, 0.02, 0.012), "Gold")
    mb.box((0, -0.302, 0.6), (1.4, 0.004, 0.9), "WoodDark")
    return [mb.build("Cashier", sharp=40, bevel=0.004)]


# ------------------------------------------------------------------ montaje

def build_all():
    objs = []
    for f in (make_roulette, make_dolly, make_roulette_table, make_blackjack_table, make_poker_table, make_slot,
              make_chip, make_chandelier, make_column, make_chair, make_stool, make_stanchion_rope, make_cashier):
        objs += f()
    return objs


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    opts = dict(filepath=path, export_format='GLB', export_yup=True, export_apply=True, export_texcoords=True,
                export_normals=True, export_materials='EXPORT', export_animations=False, export_cameras=False,
                export_lights=False, export_extras=False)
    try:
        bpy.ops.export_scene.gltf(**opts)
    except TypeError as e:
        print("GLTF opts fallback:", e)
        for k in ("export_extras", "export_lights", "export_cameras"):
            opts.pop(k, None)
        bpy.ops.export_scene.gltf(**opts)


def preview(objs, path):
    """Hojas de vista previa con luz de estudio: todo junto y primeros planos."""
    col = bpy.data.collections.new("preview")
    SCN.collection.children.link(col)
    for ob in list(SCN.collection.objects):
        ob.hide_render = True
    wheel = Vector((-0.02, 0.0, 0.8))
    layout = {
        "RW_Bowl": wheel, "RW_Rotor": wheel, "RW_Ball": wheel + Vector((RW_TRACK_R * math.cos(1.0), RW_TRACK_R * math.sin(1.0), RW_TRACK_Z)),
        "Dolly": Vector((1.3, -0.25, 0.797)), "RT_Table": Vector((0.8, 0.0, 0.0)),
        "PK_Table": Vector((6.6, 0.4, 0.0)), "SL_Cabinet": Vector((-1.9, 0.0, 0.0)),
        "Chandelier": Vector((2.2, 1.6, 3.6)), "Column": Vector((-3.2, 1.2, 0.0)), "Chair": Vector((2.4, -1.4, 0.0)),
        "Stool": Vector((3.6, -1.9, 0.0)), "Stanchion": Vector((8.2, -0.6, 0.0)), "Rope": Vector((8.8, -0.6, 0.0)),
        "Cashier": Vector((10.2, 1.0, 0.0)),
    }
    bj = Vector((3.7, -0.4, 0.0))
    slot = layout["SL_Cabinet"]
    for ob in objs:
        c = None
        if ob.name in layout:
            c = ob.copy()
            c.location = layout[ob.name]
        elif ob.name.startswith("BJ_"):
            c = ob.copy()
            c.location = bj + ob.location
        elif ob.name.startswith("SL_"):
            c = ob.copy()
            c.location = slot + ob.location
        if c is not None:
            col.objects.link(c)
            c.hide_render = False
    chip = bpy.data.objects.get("Chip")
    for i in range(14):
        c = chip.copy()
        col.objects.link(c)
        c.hide_render = False
        c.location = (1.6 + (i // 7) * 0.05, -0.3, 0.797 + (i % 7) * CHIP_H)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    SCN.collection.objects.link(cam)
    SCN.camera = cam
    # EEVEE y Workbench necesitan contexto GPU y en modo -b pueden cerrar Blender; Cycles en CPU siempre funciona
    SCN.render.engine = 'CYCLES'
    SCN.cycles.device = 'CPU'
    SCN.cycles.samples = 20
    SCN.cycles.use_denoising = True
    SCN.render.resolution_x = 1280
    SCN.render.resolution_y = 720
    world = bpy.data.worlds.new("w")
    world.color = (0.35, 0.35, 0.38)
    try:
        world.use_nodes = True
        bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
        bg.inputs[0].default_value = (0.32, 0.32, 0.36, 1.0)
        bg.inputs[1].default_value = 0.8
    except Exception:
        pass
    SCN.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN'))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(30))
    SCN.collection.objects.link(sun)
    for (x, y, z, e) in ((1.0, -2.5, 3.5, 900.0), (4.0, -2.0, 3.0, 700.0), (-2.0, -2.0, 3.0, 600.0)):
        lt = bpy.data.objects.new("area", bpy.data.lights.new("area", 'AREA'))
        lt.data.energy = e
        lt.data.size = 2.5
        lt.location = (x, y, z)
        lt.rotation_euler = (math.radians(35), 0, 0)
        SCN.collection.objects.link(lt)
    shots = [("", (3.6, -9.5, 4.6), (68, 0, 0), 24),
             ("_ruleta", (0.0, -1.0, 1.75), (48, 0, 0), 38),
             ("_blackjack", (3.7, -2.6, 2.1), (58, 0, 0), 30),
             ("_tragaperras", (-1.75, -2.6, 1.15), (90, 0, -4), 32),
             ("_lampara", (2.2, -3.4, 2.75), (90, 0, 0), 36)]
    for suffix, loc, rot, lens in shots:
        cam.location = loc
        cam.rotation_euler = tuple(math.radians(a) for a in rot)
        cam.data.lens = lens
        SCN.render.filepath = path.replace(".png", suffix + ".png")
        bpy.ops.render.render(write_still=True)


OBJS = build_all()
export(OUT)
print("Escrito:", OUT, "objetos:", [o.name for o in OBJS])
if PREVIEW:
    preview(OBJS, PREVIEW)
    print("Vista previa:", PREVIEW)
