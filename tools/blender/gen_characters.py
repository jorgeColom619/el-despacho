"""Genera art/characters/visitor.glb: visitantes low-poly del despacho 3D y de los escenarios.

Un solo esqueleto compartido con todas las piezas (cuerpos H/M, cabezas, caras con blend shapes,
peinados, barbas, gafas, corbata, perlas, uniforme) y las animaciones idle / walk / talk, más las de los
escenarios 3D: sit, sit_talk, sit_write, sit_raise, sit_clap, clap, sit_table, sit_table_talk, photo,
kneel_photo y operate, y los gestos point, laugh, cheer, lectern, lectern_talk, sit_protest, sit_cheer,
sit_laugh, sit_table_nod, sit_table_no, sit_table_cross, sit_table_read, sit_table_sign, sit_table_offer,
sit_table_laugh y sit_table_gavel. visitor_3d.gd enseña las piezas y colorea los materiales según el `look`.
Junto a él escribe crowd.glb: diputados sentados, estáticos y simplificados, para el fondo del hemiciclo.

Uso:
  blender -b --factory-startup -P tools/blender/gen_characters.py -- [salida.glb] [carpeta_previews]
  (PREVIEW_ONLY=stage: solo la hoja de posturas de los escenarios)
"""
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = ARGS[0] if ARGS else os.path.join(ROOT, "art", "characters", "visitor.glb")
PREVIEW = ARGS[1] if len(ARGS) > 1 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
SCN = bpy.context.scene


# ------------------------------------------------------------------ utilidades

def clamp(x, a=0.0, b=1.0):
    return a if x < a else b if x > b else x


def sstep(e0, e1, x):
    t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def interp(pts, x):
    if x <= pts[0][0]:
        return pts[0][1]
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        if x <= x1:
            return lerp(y0, y1, (x - x0) / (x1 - x0))
    return pts[-1][1]


def lump(p, f=17.0):
    return math.sin(f * p.x + 1.3) * math.sin(f * 0.9 * p.y + 0.7) * math.sin(f * 1.1 * p.z + 2.1)


def ellipse(cx, cz, rx, rz, n):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cz + rz * math.sin(2 * math.pi * i / n)) for i in range(n)]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def to_linear(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ------------------------------------------------------------------ materiales

DEFAULT_COL = {
    "Skin": "e6bc98", "Suit": "222f4a", "Trousers": "1d2842", "Lapel": "1b2540", "Shirt": "f2f2f2",
    "Tie": "7a1f2b", "Shoes": "0d0b0a", "Button": "15110e", "Hair": "3b2a20", "HairTie": "1a1716",
    "Stubble": "a88466", "Brow": "32241b", "Sclera": "f4f1ea", "Iris": "3b2a20", "Pupil": "0d0a09",
    "Glint": "ffffff", "Lid": "1f1512", "Lip": "b07a68", "MouthIn": "3a1414", "Teeth": "eeeae0",
    "Frame": "1f1a1a", "Gold": "c9a55c", "Pearl": "f3ead6", "Cap": "3f4a32", "CapBand": "1f2419",
    "Visor": "141611", "Rib1": "b8262e", "Rib2": "2d5a9e", "Rib3": "e9c46a", "Rib4": "3a9d5d",
    "Flag0": "1d3557", "Flag1": "e9c46a", "Flag2": "1d3557",
}


def _bsdf(m):
    return next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)


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
    if _bsdf(m) is None:
        b = nt.nodes.new('ShaderNodeBsdfPrincipled')
        out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(b.outputs[0], out.inputs[0])
    set_col(m, hexrgb(DEFAULT_COL.get(name, "888888")), 0.7, 0.0)
    return m


def set_col(m, rgb, rough=None, metal=None):
    lin = to_linear(rgb)
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*lin, 1.0)
    if rough is not None:
        b.inputs["Roughness"].default_value = rough
    if metal is not None:
        b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*lin, 1.0)


# ------------------------------------------------------------------ constructor de mallas

class Surf:
    """Superficie de referencia para pegar piezas por delante (rayos en +Y)."""

    def __init__(self, mb):
        self.bvh = BVHTree.FromBMesh(mb.bm)

    def at(self, x, z, off):
        loc = self.bvh.ray_cast(Vector((x, -1.0, z)), Vector((0, 1, 0)))[0]
        if loc is None:
            return Vector((x, 0.0, z))
        return Vector((loc.x, loc.y - off, loc.z))

    def down(self, x, y):
        loc = self.bvh.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))[0]
        return loc.z if loc is not None else 0.0


class MB:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.groups, self.mats = [], []
        self.keys = {}
        self.rest = {}
        self.smooth = False
        self.xf = None

    def _g(self, b):
        if b not in self.groups:
            self.groups.append(b)
        return self.groups.index(b)

    def _m(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def tag(self, verts, mat, w):
        mi = self._m(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = mi
            f.smooth = self.smooth
        for v in verts:
            ws = w(v.co) if callable(w) else {w: 1.0}
            tot = sum(ws.values())
            for b, x in ws.items():
                if x > 1e-4:
                    v[self.dl][self._g(b)] = x / tot
        return verts

    def ico(self, mat, w, sub, fn):
        vs = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=1.0)["verts"]
        for v in vs:
            v.co = fn(v.co.normalized())
        return self.tag(vs, mat, w)

    def ellip(self, c, r, mat, w, sub=2, bump=0.0):
        c = Vector(c)

        def fn(p):
            q = Vector((p.x * r[0], p.y * r[1], p.z * r[2]))
            if bump:
                q *= 1 + bump * lump(p, 14.0)
            return c + q
        return self.ico(mat, w, sub, fn)

    def box(self, c, size, mat, w, rot=(0, 0, 0)):
        vs = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        m = Matrix.Translation(Vector(c)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*size, 1.0))
        for v in vs:
            v.co = m @ v.co
        return self.tag(vs, mat, w)

    def sweep(self, path, radii, mat, w, seg=8, closed=False, caps=True, up=None, sq=2.0):
        path = [Vector(p) for p in path]
        n = len(path)
        rings = []
        for i, p in enumerate(path):
            if closed:
                t = path[(i + 1) % n] - path[i - 1]
            else:
                t = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
            t.normalize()
            ref = Vector(up) if up else (Vector((0, -1, 0)) if abs(t.y) < 0.9 else Vector((0, 0, 1)))
            nr = (ref - t * ref.dot(t)).normalized()
            bn = t.cross(nr)
            r = radii[i]
            rx, ry = (r, r) if isinstance(r, (int, float)) else r
            ring = []
            for k in range(seg):
                a = 2 * math.pi * k / seg
                c, s = math.cos(a), math.sin(a)
                if sq != 2.0:
                    c = math.copysign(abs(c) ** (2 / sq), c)
                    s = math.copysign(abs(s) ** (2 / sq), s)
                ring.append(self.bm.verts.new(p + nr * (c * ry) + bn * (s * rx)))
            rings.append(ring)
        faces = []
        for i in range(n if closed else n - 1):
            a, b = rings[i], rings[(i + 1) % n]
            for k in range(seg):
                faces.append(self.bm.faces.new((a[k], a[(k + 1) % seg], b[(k + 1) % seg], b[k])))
        if caps and not closed:
            faces.append(self.bm.faces.new(rings[0]))
            faces.append(self.bm.faces.new(rings[-1]))
        verts = [v for r in rings for v in r]
        cen = sum((v.co for v in verts), Vector()) / len(verts)
        for f in faces:
            f.normal_update()
        bad = sum(1 for f in faces if f.normal.dot(f.calc_center_median() - cen) < 0)
        if bad * 2 > len(faces):
            for f in faces:
                f.normal_flip()
        return self.tag(verts, mat, w)

    def loft(self, rings, mat, w, seg=12, sq=2.0, caps=True):
        path = [(r[4] if len(r) > 4 else 0.0, r[3], r[0]) for r in rings]
        return self.sweep(path, [(r[1], r[2]) for r in rings], mat, w, seg=seg, caps=caps, sq=sq, up=(0, -1, 0))

    # piezas pegadas a una superficie (mirando a -Y)
    def vert(self, surf, x, z, off):
        v = self.bm.verts.new(surf.at(x, z, off))
        self.rest[v] = (x, z, surf, off)
        return v

    def orient(self, faces):
        for f in faces:
            f.normal_update()
        big = max(faces, key=lambda f: f.calc_area())
        if big.normal.y > 0:
            for f in faces:
                f.normal_flip()

    def decal(self, surf, poly, off, mat, w, sub=1, rings=2):
        """Polígono convexo (x, z) pegado a `surf`; anillos concéntricos para que siga la curvatura."""
        pts = []
        n = len(poly)
        for i in range(n):
            (x0, z0), (x1, z1) = poly[i], poly[(i + 1) % n]
            for k in range(sub):
                pts.append((lerp(x0, x1, k / sub), lerp(z0, z1, k / sub)))
        cx = sum(p[0] for p in pts) / len(pts)
        cz = sum(p[1] for p in pts) / len(pts)
        layers = []
        for r in range(rings):
            s = 1 - r / rings
            layers.append([self.vert(surf, lerp(cx, x, s), lerp(cz, z, s), off) for x, z in pts])
        c = self.vert(surf, cx, cz, off)
        m = len(pts)
        faces = []
        for a, b in zip(layers, layers[1:]):
            for i in range(m):
                j = (i + 1) % m
                faces.append(self.bm.faces.new((a[i], a[j], b[j], b[i])))
        for i in range(m):
            faces.append(self.bm.faces.new((layers[-1][i], layers[-1][(i + 1) % m], c)))
        self.orient(faces)
        vs = [v for ly in layers for v in ly] + [c]
        self.tag(vs, mat, w)
        return vs

    def strip(self, surf, rows, off, mat, w):
        vr = [[self.vert(surf, x, z, off) for x, z in row] for row in rows]
        faces = []
        for a, b in zip(vr, vr[1:]):
            for i in range(len(a) - 1):
                faces.append(self.bm.faces.new((a[i], a[i + 1], b[i + 1], b[i])))
        self.orient(faces)
        self.tag([v for r in vr for v in r], mat, w)
        return vr

    def kmove(self, key, v, dx, dz):
        x, z, surf, off = self.rest[v]
        self.keys[key][v] = surf.at(x + dx, z + dz, off) - v.co

    def to_object(self, rig):
        if self.xf:
            moved = set()
            for v in self.bm.verts:
                if self.xf(v.co):
                    v.co = head_xf(v.co)
                    moved.add(v)
            for offs in self.keys.values():
                for v in offs:
                    if v in moved:
                        offs[v] = offs[v] * HEAD_K
        me = bpy.data.meshes.new(self.name)
        self.bm.verts.index_update()
        self.bm.to_mesh(me)
        ob = bpy.data.objects.new(self.name, me)
        SCN.collection.objects.link(ob)
        for m in self.mats:
            me.materials.append(get_mat(m))
        for g in self.groups:
            ob.vertex_groups.new(name=g)
        if self.keys:
            ob.shape_key_add(name="Basis", from_mix=False)
            for k, offs in self.keys.items():
                sk = ob.shape_key_add(name=k, from_mix=False)
                for v, o in offs.items():
                    sk.data[v.index].co = v.co + o
        ob.parent = rig
        ob.modifiers.new("Armature", 'ARMATURE').object = rig
        self.bm.free()
        return ob


# ------------------------------------------------------------------ esqueleto
# Blender Z arriba, el personaje mira a -Y; .L = +X (su izquierda).

def _bones():
    b = [
        ("root", None, (0, 0, 0), (0, 0, 0.1), False),
        ("hips", "root", (0, 0, 0.93), (0, 0, 1.05), False),
        ("spine", "hips", (0, 0, 1.05), (0, 0, 1.22), True),
        ("chest", "spine", (0, 0, 1.22), (0, 0.005, 1.44), True),
        ("neck", "chest", (0, 0.005, 1.44), (0, 0.01, 1.535), True),
        ("head", "neck", (0, 0.01, 1.535), (0, 0.01, 1.79), True),
    ]
    for s, sd in ((1, "L"), (-1, "R")):
        b += [
            (f"upper_arm.{sd}", "chest", (0.198 * s, 0.01, 1.405), (0.225 * s, 0.025, 1.135), False),
            (f"forearm.{sd}", f"upper_arm.{sd}", (0.225 * s, 0.025, 1.135), (0.235 * s, 0.0, 0.895), True),
            (f"hand.{sd}", f"forearm.{sd}", (0.235 * s, 0.0, 0.895), (0.236 * s, -0.005, 0.79), True),
            (f"thigh.{sd}", "hips", (0.088 * s, 0.0, 0.92), (0.092 * s, -0.005, 0.50), False),
            (f"shin.{sd}", f"thigh.{sd}", (0.092 * s, -0.005, 0.50), (0.095 * s, 0.01, 0.085), True),
            (f"foot.{sd}", f"shin.{sd}", (0.095 * s, 0.01, 0.085), (0.097 * s, -0.11, 0.025), True),
        ]
    return b


def make_rig():
    arm = bpy.data.armatures.new("Rig")
    rig = bpy.data.objects.new("Rig", arm)
    SCN.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    for name, parent, h, t, conn in _bones():
        eb = arm.edit_bones.new(name)
        eb.head, eb.tail = h, t
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = conn
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.bones["root"].use_deform = False
    return rig


# ------------------------------------------------------------------ cabeza

RX, RY, RZ = 0.093, 0.104, 0.128
HC = Vector((0.0, 0.006, 1.655))
# todo lo de la cabeza se modela a escala real y al final se agranda (estilo low-poly cabezón suave)
HEAD_K, HEAD_P, HEAD_DZ = 1.1, Vector((0.0, 0.01, 1.535)), -0.015


def head_xf(co):
    return HEAD_P + (co - HEAD_P) * HEAD_K + Vector((0.0, 0.0, HEAD_DZ))


def ALL(co):
    return True
EX, EZ = 0.0355, 1.660
JAW = {
    "m": dict(side=[(-1, 0.0), (-0.95, 0.45), (-0.8, 0.68), (-0.6, 0.87), (-0.3, 0.975), (0, 1.0)],
              front=[(-1, 0.0), (-0.95, 0.6), (-0.85, 0.8), (-0.7, 0.9), (-0.4, 0.97), (0, 1.0)]),
    "f": dict(side=[(-1, 0.0), (-0.95, 0.34), (-0.8, 0.56), (-0.6, 0.8), (-0.3, 0.955), (0, 1.0)],
              front=[(-1, 0.0), (-0.95, 0.5), (-0.85, 0.74), (-0.7, 0.88), (-0.4, 0.97), (0, 1.0)]),
}
BACK = [(-1, 0.0), (-0.7, 0.55), (-0.4, 0.84), (0, 1.0)]


def head_point(p, g="m"):
    x, y, z = p.x, p.y, p.z
    if z >= 0:
        k = math.sqrt(max(0.0, 1 - z * z))
        ks, kf, kb = k, k, k ** 0.8
        zz = HC.z + z * RZ
    else:
        ks, kf, kb = interp(JAW[g]["side"], z), interp(JAW[g]["front"], z), interp(BACK, z)
        zz = HC.z + RZ * (z if z > -0.8 else -0.8 + (z + 0.8) * 0.45)
    h = math.hypot(x, y)
    cx, cy = (x / h, y / h) if h > 1e-6 else (0.0, 0.0)
    return Vector((HC.x + cx * RX * ks, HC.y + cy * RY * (0.94 * kf if cy < 0 else 1.05 * kb), zz))


_SURF = {}


def head_surf(g):
    if g not in _SURF:
        ref = MB("ref")
        ref.ico("Skin", "head", 4, lambda p: head_point(p, g))
        _SURF[g] = Surf(ref)
    return _SURF[g]


def build_head(g, rig):
    mb = MB("Head_" + g.upper())
    mb.xf = ALL
    k = 0.84 if g == "f" else 0.92
    mb.smooth = True
    mb.ico("Skin", "head", 4, lambda p: head_point(p, g))
    surf = head_surf(g)

    def ys(z):
        return surf.at(0.0, z, 0.0).y
    mb.sweep([(0, ys(1.676) - 0.002, 1.676), (0, ys(1.651) - 0.009 * k, 1.651),
              (0, ys(1.626) - 0.017 * k, 1.625), (0, ys(1.612) - 0.009 * k, 1.611)],
             [(0.005 * k, 0.004), (0.0068 * k, 0.0085 * k), (0.0115 * k, 0.011 * k), (0.0092 * k, 0.007 * k)],
             "Skin", "head", seg=6)
    for s in (-1, 1):
        mb.ellip((s * 0.0905, 0.016, 1.646), (0.011, 0.019, 0.028), "Skin", "head", sub=2)
    kn = 0.88 if g == "f" else 1.0
    mb.sweep([(0, 0.008, 1.425), (0, 0.010, 1.50), (0, 0.012, 1.585)],
             [(0.046 * kn, 0.05 * kn)] * 3, "Skin", "neck", seg=10)
    return mb.to_object(rig)


FACE_KEYS = ["blink", "talk", "smile", "frown", "angry", "sad", "surprise"]


def build_face(g, rig):
    surf = head_surf(g)
    mb = MB("Face_" + g.upper())
    mb.xf = ALL
    mb.keys = {k: {} for k in FACE_KEYS}
    H = "head"
    f = g == "f"
    zc = EZ - 0.0025
    for s in (-1, 1):
        cx = s * EX
        # ojo: esclerótica, iris, pupila y brillo
        sclera = mb.decal(surf, ellipse(cx, EZ, 0.0155, 0.0095, 16), 0.0008, "Sclera", H)
        eye = list(sclera)
        eye += mb.decal(surf, ellipse(cx, EZ - 0.0006, 0.0078, 0.0078, 12), 0.0014, "Iris", H)
        eye += mb.decal(surf, ellipse(cx, EZ - 0.0006, 0.0036, 0.0036, 8), 0.0019, "Pupil", H)
        eye += mb.decal(surf, ellipse(cx - 0.0026, EZ + 0.0024, 0.0013, 0.0013, 6), 0.0024, "Glint", H)
        for v in eye:
            z = mb.rest[v][1]
            mb.kmove("blink", v, 0.0, (zc - z) * 0.94)
        for v in sclera:
            z = mb.rest[v][1]
            mb.kmove("surprise", v, 0.0, (z - EZ) * 0.2)
        # párpado superior
        n = 11
        arc, top, bot = [], [], []
        for i in range(n):
            th = math.pi * (1 - i / (n - 1))
            x, z = cx + 0.0168 * math.cos(th), EZ + 0.0104 * math.sin(th)
            ht = (0.0012 if f else 0.0008) + (0.0004 if f else 0.0003) * math.sin(th)
            arc.append(z)
            top.append((x, z + ht))
            bot.append((x, z - ht))
        for row in mb.strip(surf, [top, bot], 0.0028, "Lid", H):
            for i, v in enumerate(row):
                mb.kmove("blink", v, 0.0, (zc - arc[i]) * 0.94)
                mb.kmove("surprise", v, 0.0, (arc[i] - EZ) * 0.2)
        if f:
            xo = cx + s * 0.0168
            for v in mb.decal(surf, [(xo - s * 0.002, EZ + 0.0012), (xo + s * 0.0052, EZ + 0.0052), (xo + s * 0.001, EZ - 0.0004)], 0.0028, "Lid", H):
                mb.kmove("blink", v, 0.0, (zc - EZ) * 0.94)
        # ceja
        n = 7
        top, bot, ts = [], [], []
        for i in range(n):
            t = i / (n - 1)
            x = s * (0.0125 + 0.043 * t)
            z = 1.6885 + 0.0072 * math.sin(math.pi * (0.12 + 0.8 * t)) - 0.0022 * t
            h = lerp(0.0034, 0.0019, t) * (0.62 if f else 1.0)
            top.append((x, z + h))
            bot.append((x, z - h))
            ts.append(t)
        for row in mb.strip(surf, [top, bot], 0.0023, "Brow", H):
            for i, v in enumerate(row):
                t = ts[i]
                mb.kmove("angry", v, -s * 0.0016 * (1 - t), -0.0062 * (1 - t) + 0.0012 * t)
                mb.kmove("sad", v, 0.0, 0.0052 * (1 - t) ** 1.5 - 0.0012 * t)
                mb.kmove("surprise", v, 0.0, 0.0065 - 0.001 * t)
    # boca: labios, interior oscuro y dientes
    mz = 1.5995 if f else 1.598
    hw = 0.0225 if f else 0.024
    n = 13
    us = [lerp(-1, 1, i / (n - 1)) for i in range(n)]
    tu = us[2:-2]

    def line(u):
        return mz + 0.0009 * (1 - u * u)

    def hu(u):
        return (0.0005 + 0.0031 * (1 - u ** 4)) if f else (0.0004 + 0.0019 * (1 - u ** 4))

    def hl(u):
        return (0.0005 + 0.0038 * (1 - u * u) ** 0.8) if f else (0.0004 + 0.0024 * (1 - u * u) ** 0.8)

    up = mb.strip(surf, [[(u * hw, line(u) + hu(u)) for u in us], [(u * hw, line(u)) for u in us]], 0.0022, "Lip", H)
    lo = mb.strip(surf, [[(u * hw, line(u)) for u in us], [(u * hw, line(u) - hl(u)) for u in us]], 0.0022, "Lip", H)
    mi = mb.strip(surf, [[(u * hw * 0.97, line(u) + 0.0006) for u in us], [(u * hw * 0.97, line(u) - 0.0006) for u in us]], 0.0026, "MouthIn", H)
    te = mb.strip(surf, [[(u * hw * 0.85, line(u) + 0.0006) for u in tu], [(u * hw * 0.85, line(u) + 0.0004) for u in tu]], 0.0029, "Teeth", H)
    rows = [(up[0], us, "U"), (up[1], us, "U"), (mi[0], us, "U"), (te[0], tu, "U"),
            (lo[0], us, "L"), (lo[1], us, "L"), (mi[1], us, "L"), (te[1], tu, "T")]
    for row, uu, kind in rows:
        for v, u in zip(row, uu):
            q = 1 - u * u
            d, r = 0.0125 * q ** 0.9, 0.0014 * q
            dz = r if kind == "U" else (-d if kind == "L" else r - 0.0034 * q ** 0.5)
            mb.kmove("talk", v, -0.0015 * u, dz)
            mb.kmove("smile", v, 0.0032 * u, 0.0074 * u * u - 0.0008)
            mb.kmove("frown", v, -0.001 * u, -0.0056 * u * u + 0.0009)
            sz = 0.0018 * q if kind == "U" else (-0.0095 * q ** 0.5 if kind == "L" else 0.0018 * q - 0.0022 * q ** 0.5)
            mb.kmove("surprise", v, -0.0075 * u, sz)
    return mb.to_object(rig)


# ------------------------------------------------------------------ cuerpo

TORSO = {
    "m": [(0.79, 0.178, 0.118, 0.004), (0.86, 0.172, 0.114, 0.002), (0.95, 0.166, 0.108, 0.0),
          (1.04, 0.165, 0.106, 0.0), (1.15, 0.180, 0.113, -0.003), (1.26, 0.198, 0.122, -0.006),
          (1.34, 0.210, 0.120, -0.002), (1.40, 0.206, 0.112, 0.004), (1.44, 0.172, 0.095, 0.006),
          (1.465, 0.10, 0.072, 0.008)],
    "f": [(0.80, 0.168, 0.112, 0.004), (0.88, 0.162, 0.106, 0.002), (0.98, 0.148, 0.096, 0.0),
          (1.05, 0.142, 0.094, 0.0), (1.15, 0.160, 0.108, -0.006), (1.25, 0.176, 0.124, -0.014),
          (1.33, 0.188, 0.112, -0.004), (1.39, 0.194, 0.104, 0.002), (1.43, 0.165, 0.09, 0.006),
          (1.46, 0.09, 0.068, 0.008)],
}


def torso_w(co):
    z = co.z
    if z < 1.13:
        t = sstep(0.98, 1.06, z)
        return {"hips": 1 - t, "spine": t}
    t = sstep(1.20, 1.28, z)
    return {"spine": 1 - t, "chest": t}


def arm_w(sd):
    def f(co):
        t = sstep(1.11, 1.16, co.z)
        return {f"upper_arm.{sd}": t, f"forearm.{sd}": 1 - t}
    return f


def leg_w(sd):
    def f(co):
        t = sstep(0.47, 0.53, co.z)
        return {f"thigh.{sd}": t, f"shin.{sd}": 1 - t}
    return f


_TSURF = {}


def torso_surf(g):
    if g not in _TSURF:
        ref = MB("ref")
        ref.loft(TORSO[g], "Suit", torso_w, seg=12, sq=2.6)
        _TSURF[g] = Surf(ref)
    return _TSURF[g]


def build_body(g, rig):
    mb = MB("Body_" + g.upper())
    f = g == "f"
    k = 0.86 if f else 1.0
    kl = 0.9 if f else 1.0
    surf = torso_surf(g)
    mb.loft(TORSO[g], "Suit", torso_w, seg=12, sq=2.6)
    # pecho de la camisa / blusa y solapas
    vb, vw = (1.30, 0.05) if f else (1.17, 0.058)
    mb.decal(surf, [(-vw, 1.448), (vw, 1.448), (0.0, vb)], 0.0025, "Shirt", torso_w, sub=10, rings=5)
    for s in (-1, 1):
        top, bot = Vector((s * vw, 1.448)), Vector((0.0, vb))
        d = (bot - top).normalized()
        out = Vector((d.y, -d.x))
        if out.x * s < 0:
            out = -out
        rows = [[], [], []]
        for i in range(13):
            t = lerp(0.0, 0.92, i / 12)
            p = top + (bot - top) * t
            wdt = lerp(0.026, 0.008, t) if f else lerp(0.034, 0.012, t)
            for r, row in enumerate(rows):
                q = p + out * (wdt * r / 2)
                row.append((q.x, q.y))
        mb.strip(surf, rows, 0.0042, "Lapel", torso_w)
    for bz in ((1.17,) if f else (1.135, 1.055)):
        mb.ellip(surf.at(0.0, bz, -0.002), (0.0065, 0.0065, 0.0065), "Button", torso_w, sub=1)
    if not f:
        mb.sweep([(0, 0.008, 1.428), (0, 0.010, 1.492)], [(0.058, 0.062), (0.052, 0.057)], "Shirt", "chest", seg=10, caps=False)
    for s, sd in ((1, "L"), (-1, "R")):
        # brazo (manga), puño, mano
        path = [(0.172 * s, 0.008, 1.418), (0.196 * s, 0.01, 1.392), (0.212 * s, 0.018, 1.27),
                (0.225 * s, 0.025, 1.135), (0.231 * s, 0.014, 1.01), (0.235 * s, 0.0, 0.895)]
        radii = [(0.044 * k, 0.046 * k), (0.052 * k, 0.055 * k), (0.049 * k, 0.052 * k),
                 (0.043 * k, 0.045 * k), (0.04 * k, 0.041 * k), (0.036 * k, 0.037 * k)]
        mb.sweep(path, radii, "Suit", arm_w(sd), seg=8)
        w = Vector((0.235 * s, 0.0, 0.895))
        mb.sweep([w + Vector((0, 0, 0.008)), w - Vector((0, 0, 0.012))], [(0.031 * k, 0.032 * k)] * 2, "Shirt", f"forearm.{sd}", seg=8)
        mb.ellip(w + Vector((0, -0.006, -0.07 * k)), (0.017 * k, 0.039 * k, 0.07 * k), "Skin", f"hand.{sd}", sub=2)
        mb.ellip(w + Vector((-s * 0.009, -0.034 * k, -0.042 * k)), (0.011 * k, 0.012 * k, 0.028 * k), "Skin", f"hand.{sd}", sub=1)
        # pierna (pantalón) y zapato
        lp = [(0.088 * s, 0.0, 0.97), (0.089 * s, 0.0, 0.86), (0.091 * s, -0.004, 0.68), (0.092 * s, -0.005, 0.50),
              (0.094 * s, 0.003, 0.30), (0.095 * s, 0.008, 0.10), (0.095 * s, 0.009, 0.075)]
        lr = [(0.084, 0.088), (0.083, 0.087), (0.072, 0.076), (0.06, 0.064), (0.055, 0.058), (0.052, 0.054), (0.05, 0.052)]
        mb.sweep(lp, [(a * kl, b * kl) for a, b in lr], "Trousers", leg_w(sd), seg=10)
        ks = 0.88 if f else 1.0
        sp = [(0.097 * s, 0.05, 0.045), (0.097 * s, 0.01, 0.045), (0.098 * s, -0.06 * ks, 0.04),
              (0.098 * s, -0.115 * ks, 0.032), (0.098 * s, -0.135 * ks, 0.028)]
        sr = [(0.036, 0.04), (0.044, 0.042), (0.047, 0.037), (0.04, 0.03), (0.026, 0.022)]
        shoe = mb.sweep(sp, [(a * ks, b * (0.9 if f else 1.0)) for a, b in sr], "Shoes", f"foot.{sd}", seg=10)
        for v in shoe:
            v.co.z = max(v.co.z, 0.0)
    return mb.to_object(rig)


def build_tie(rig):
    surf = torso_surf("m")
    mb = MB("Tie")
    mb.decal(surf, [(-0.0115, 1.447), (0.0115, 1.447), (0.0085, 1.424), (-0.0085, 1.424)], 0.0058, "Tie", torso_w, sub=3, rings=3)
    mb.decal(surf, [(-0.0085, 1.424), (0.0085, 1.424), (0.0165, 1.272), (0.0, 1.238), (-0.0165, 1.272)], 0.0052, "Tie", torso_w, sub=6, rings=4)
    return mb.to_object(rig)


def build_pearls(rig):
    surf = torso_surf("f")
    mb = MB("Pearls")
    for i in range(13):
        a = lerp(-1.25, 1.25, i / 12)
        p = surf.at(0.05 * math.sin(a), 1.452 - 0.05 * math.cos(a), 0.004)
        mb.ellip(p, (0.0052, 0.0052, 0.0052), "Pearl", "chest", sub=2)
    return mb.to_object(rig)


def build_uniform(rig):
    mb = MB("Uniform")
    mb.xf = lambda co: co.z > 1.6
    cy = 0.0125
    mb.loft([(1.712, 0.086, 0.095, cy), (1.75, 0.089, 0.098, cy)], "CapBand", "head", seg=16, caps=False)
    crown = mb.loft([(1.749, 0.088, 0.097, cy), (1.785, 0.104, 0.12, cy - 0.004), (1.797, 0.099, 0.114, cy - 0.004)], "Cap", "head", seg=16)
    for v in crown:
        if v.co.z > 1.78:
            v.co.z += 0.016 * max(0.0, -(v.co.y - cy) / 0.12)
    inner, outer = [], []
    for i in range(11):
        th = math.radians(lerp(-78, 78, i / 10))
        p = Vector((0.087 * math.sin(th), cy - 0.096 * math.cos(th), 1.714))
        d = Vector((p.x, p.y - cy, 0)).normalized()
        q = p + d * (0.05 * math.cos(th) ** 1.5) + Vector((0, 0, -0.016 * math.cos(th)))
        inner.append(mb.bm.verts.new(p))
        outer.append(mb.bm.verts.new(q))
    faces = [mb.bm.faces.new((inner[i], inner[i + 1], outer[i + 1], outer[i])) for i in range(10)]
    res = bmesh.ops.solidify(mb.bm, geom=faces, thickness=0.004)
    visor = set(inner + outer) | {e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)}
    mb.tag(list(visor), "Visor", "head")
    mb.ellip((0.0, cy - 0.0985, 1.748), (0.0115, 0.004, 0.0115), "Gold", "head", sub=2)
    surf = torso_surf("m")
    for s in (-1, 1):
        x = 0.155 * s
        mb.box((x, 0.004, surf.down(x, 0.004) + 0.004), (0.085, 0.056, 0.01), "Gold", "chest", rot=(0, 0.2 * s, 0))
    for i, (x, z) in enumerate([(0.085, 1.335), (0.103, 1.335), (0.121, 1.335), (0.094, 1.321), (0.112, 1.321)]):
        p = surf.at(x, z, 0.0018)
        mb.box(p, (0.0155, 0.004, 0.0095), f"Rib{i % 4 + 1}", "chest")
    return mb.to_object(rig)


def rect(cx, cz, hw, hh):
    return [(cx - hw, cz - hh), (cx + hw, cz - hh), (cx + hw, cz + hh), (cx - hw, cz + hh)]


def build_accessories(rig):
    """Accesorios de la tienda (look["acc"]): pin, banda y medalla, con los colores de la bandera
    en los materiales Flag0/Flag1/Flag2. Una versión por cuerpo porque el pecho no es igual."""
    up = Vector((0.0, 1.0, 0.0))
    for g in ("m", "f"):
        gu, f = g.upper(), g == "f"
        surf = torso_surf(g)
        # pin en la solapa izquierda
        mb = MB(f"Acc_pin_{gu}")
        cx, cz = (0.0448, 1.4003) if f else (0.0554, 1.367)
        hw, hh = (0.012, 0.0078) if f else (0.0135, 0.0088)
        mb.decal(surf, rect(cx, cz, hw + 0.0014, hh + 0.0014), 0.0056, "Gold", torso_w, sub=2)
        mb.decal(surf, rect(cx, cz, hw, hh), 0.0062, "Flag0", torso_w, sub=2)
        mb.decal(surf, rect(cx, cz, hw, hh / 3), 0.0066, "Flag1", torso_w, sub=2)
        mb.to_object(rig)
        # Gran Cruz: cinta con los colores y estrella dorada de ocho puntas
        mb = MB(f"Acc_medalla_{gu}")
        mx = 0.088 if f else 0.092
        r0, r1 = (1.39, 1.355) if f else (1.396, 1.36)
        mb.decal(surf, rect(mx, (r0 + r1) / 2, 0.017, (r0 - r1) / 2), 0.0045, "Flag0", torso_w, sub=2)
        mb.decal(surf, rect(mx, (r0 + r1) / 2, 0.0056, (r0 - r1) / 2), 0.005, "Flag1", torso_w, sub=2)
        sc = r1 - 0.02
        star = []
        for i in range(16):
            r = 0.024 if i % 2 == 0 else 0.0105
            a = -math.pi / 2 + math.pi * i / 8
            star.append((mx + r * math.cos(a), sc + r * math.sin(a)))
        mb.decal(surf, star, 0.0058, "Gold", torso_w, rings=1)
        mb.decal(surf, ellipse(mx, sc, 0.0065, 0.0065, 10), 0.0064, "Flag0", torso_w)
        mb.to_object(rig)
        # banda presidencial: del hombro izquierdo a la cadera derecha, rodeando el torso
        mb = MB(f"Acc_banda_{gu}")
        top, bot = Vector((0.11, 0.0, 1.452)), Vector((-0.165, 0.0, 0.97))
        d1 = (bot - top).normalized()
        nrm = d1.cross(up).normalized()
        mid = (top + bot) / 2
        strands = [-0.044, -0.039, -0.013, 0.013, 0.039, 0.044]
        mats = ["Gold", "Flag0", "Flag1", "Flag2", "Gold"]
        n = 64
        rows = []
        for s in strands:
            o = mid + nrm * s
            row = []
            for k in range(n):
                th = 2 * math.pi * k / n
                dv = d1 * math.cos(th) + up * math.sin(th)
                loc = surf.bvh.ray_cast(o, dv)[0]
                p = (loc if loc is not None else o + dv * 0.15) + dv * 0.0068
                row.append(mb.bm.verts.new(p))
            rows.append(row)
        for j, mat in enumerate(mats):
            mi = mb._m(mat)
            a, b = rows[j], rows[j + 1]
            for k in range(n):
                k2 = (k + 1) % n
                fc = mb.bm.faces.new((a[k], a[k2], b[k2], b[k]))
                fc.material_index = mi
                fc.normal_update()
                c = fc.calc_center_median()
                if fc.normal.dot(c - (mid + nrm * nrm.dot(c - mid))) < 0:
                    fc.normal_flip()
        for row in rows:
            for v in row:
                for bn, x in torso_w(v.co).items():
                    if x > 1e-4:
                        v[mb.dl][mb._g(bn)] = x
        mb.to_object(rig)


# ------------------------------------------------------------------ pelo y barba

HL = {
    "std": [(0.0, 0.64), (0.45, 0.6), (0.85, 0.45), (1.25, 0.30), (1.55, 0.24), (1.75, 0.20), (2.0, 0.0), (2.4, -0.42), (3.2, -0.62)],
    "high": [(0.0, 0.74), (0.35, 0.74), (0.6, 0.66), (0.9, 0.5), (1.25, 0.32), (1.55, 0.25), (1.75, 0.2), (2.0, 0.0), (2.4, -0.42), (3.2, -0.62)],
    "low": [(0.0, 0.56), (0.45, 0.54), (0.85, 0.40), (1.25, 0.22), (1.55, 0.02), (1.75, -0.06), (2.0, -0.2), (2.4, -0.55), (3.2, -0.78)],
    "drape": [(0.0, 0.62), (0.5, 0.58), (0.8, 0.30), (0.95, 0.0), (1.0, -1.0), (3.2, -1.0)],
    "bangs": [(0.0, 0.40), (0.5, 0.38), (0.75, 0.22), (0.85, 0.0), (0.9, -1.0), (3.2, -1.0)],
}


def shell(table, side, top, fall=0.24, extra=None):
    """Casquete de pelo: grosor `side` en los laterales que sube a `top` en la coronilla y se
    afina hasta meterse bajo la piel en la línea de nacimiento (tabla HL)."""
    hl = HL[table]

    def f(p, e, a):
        d = e - interp(hl, abs(a))
        if d < -0.3:
            return None
        t = lerp(side, top, sstep(0.1, 1.15, e)) + (extra(p, e, a) if extra else 0.0)
        return lerp(-0.003, t, sstep(0.0, fall, d))
    return f


def horseshoe(upper, th=0.008):
    def f(p, e, a):
        aa = abs(a)
        lo, hi = interp(HL["std"], aa), interp(upper, aa)
        if aa < 0.95 or e > hi + 0.25 or e < lo - 0.25:
            return None
        s = sstep(0.0, 0.07, e - lo) * sstep(0.0, 0.07, hi - e) * sstep(1.1, 1.35, aa)
        return lerp(-0.003, th, s)
    return f


def hair_w(co):
    t = sstep(1.42, 1.56, co.z)
    return {"head": t, "chest": 1 - t}


def hair_mesh(name, shell_fn, drape=None):
    mb = MB(name)
    mb.xf = ALL
    vs = bmesh.ops.create_icosphere(mb.bm, subdivisions=5, radius=1.0)["verts"]
    kill = []
    for v in vs:
        p = v.co.normalized()
        e, a = math.asin(clamp(p.z, -1.0, 1.0)), math.atan2(p.x, -p.y)
        # las melenas se afinan junto a la cara para no parecer una capucha
        edge = lerp(0.35, 1.0, max(sstep(drape["open"] - 0.1, drape["open"] + 0.5, abs(a)), sstep(0.55, 0.95, e))) if drape else 1.0
        if drape and p.z < 0:
            if abs(a) < drape["open"] or p.z < -0.985:
                kill.append(v)
                continue
            eq = head_point(Vector((p.x, p.y, 0.0)).normalized())
            hd = Vector((eq.x - HC.x, eq.y - HC.y, 0.0))
            r = (hd.length + drape["t"](p, e, a) * edge) * (1 + drape["flare"] * -p.z)
            v.co = Vector((HC.x, HC.y, HC.z + p.z * drape["L"])) + hd.normalized() * r
            continue
        t = shell_fn(p, e, a)
        if t is None:
            kill.append(v)
            continue
        if t > 0:
            t *= edge
        h = head_point(p)
        v.co = h + (h - HC).normalized() * t
    bmesh.ops.delete(mb.bm, geom=kill, context='VERTS')
    mb.tag(list(mb.bm.verts), "Hair", hair_w)
    return mb


def build_hairs(rig):
    def wave(p, e, a):
        return 0.008 * math.sin(7 * a + 9 * p.z)

    def curl(p, e, a):
        return 0.014 * lump(p, 20.0)
    bald = horseshoe([(1.1, 0.30), (1.75, 0.42), (2.4, 0.40), (3.2, 0.32)])
    balding_hs = horseshoe([(1.1, 0.45), (1.75, 0.58), (2.4, 0.60), (3.2, 0.55)])

    def balding(p, e, a):
        vals = [balding_hs(p, e, a)]
        if e > 0.7:
            vals.append(lerp(-0.003, 0.0022, sstep(0.86, 1.0, e)))
        vals = [x for x in vals if x is not None]
        return max(vals) if vals else None

    def comb(p, e, a):
        return 0.0018 * math.sin(18 * a) * sstep(0.5, 0.9, e) * sstep(1.45, 1.15, e)

    def part(a0, depth=0.006):
        return lambda p, e, a: -depth * math.exp(-((a - a0) / 0.07) ** 2) * sstep(0.5, 0.8, e) * sstep(1.45, 1.2, e)

    styles = {
        "short": (shell("std", 0.0045, 0.016, extra=lambda p, e, a: 0.005 * sstep(0.45, 0.9, math.cos(a)) * sstep(0.6, 0.85, e) * sstep(1.3, 1.0, e)), None),
        "side": (shell("std", 0.005, 0.018, extra=lambda p, e, a: part(0.42, 0.009)(p, e, a) + 0.006 * sstep(0.42, -0.5, a) * sstep(0.4, 0.95, e) + comb(p, e, a)), None),
        "slick": (shell("high", 0.004, 0.012, fall=0.28, extra=comb), None),
        "buzz": (shell("std", 0.003, 0.0038, fall=0.06), None),
        "bald": (bald, None),
        "balding": (balding, None),
        "wavy": (shell("low", 0.009, 0.026, extra=lambda p, e, a: 0.005 * math.sin(9 * a + 7 * e)), None),
        "curly": (shell("low", 0.015, 0.036, extra=lambda p, e, a: 0.012 * lump(p, 22.0)), None),
        "bun": (shell("std", 0.004, 0.008), None),
        "ponytail": (shell("std", 0.004, 0.008), None),
        "bob": (shell("bangs", 0.018, 0.024, extra=part(0.0, 0.004)), dict(open=0.85, L=0.115, flare=0.12, t=lambda p, e, a: 0.018)),
        "long": (shell("drape", 0.014, 0.018, extra=part(0.0)), dict(open=0.95, L=0.34, flare=0.22, t=lambda p, e, a: 0.014)),
        "wavy_f": (shell("drape", 0.02, 0.024, extra=lambda p, e, a: wave(p, e, a) + part(0.2)(p, e, a)), dict(open=0.95, L=0.28, flare=0.3, t=lambda p, e, a: 0.02 + wave(p, e, a))),
        "curly_f": (shell("drape", 0.03, 0.038, extra=curl), dict(open=0.98, L=0.17, flare=0.35, t=lambda p, e, a: 0.03 + curl(p, e, a))),
    }
    for name, (fn, drape) in styles.items():
        mb = hair_mesh("Hair_" + name, fn, drape)
        if name == "bun":
            mb.ellip(HC + Vector((0.0, 0.062, 0.128)), (0.046, 0.042, 0.04), "Hair", "head", sub=3, bump=0.06)
        if name == "ponytail":
            mb.sweep([(0, 0.095, 1.715), (0, 0.118, 1.69), (0, 0.135, 1.64), (0, 0.14, 1.58), (0, 0.135, 1.51), (0, 0.125, 1.465)],
                     [0.022, 0.03, 0.03, 0.025, 0.018, 0.008], "Hair", hair_w, seg=8)
            mb.ellip((0.0, 0.121, 1.688), (0.025, 0.014, 0.012), "HairTie", "head", sub=2)
        mb.to_object(rig)


def beard_mesh(name, fn, mat="Hair"):
    mb = MB(name)
    mb.xf = ALL
    vs =bmesh.ops.create_icosphere(mb.bm, subdivisions=5, radius=1.0)["verts"]
    kill = []
    for v in vs:
        p = v.co.normalized()
        h = head_point(p)
        r = fn(h, p)
        if r is None:
            kill.append(v)
            continue
        t, dz = r
        v.co = h + (h - HC).normalized() * t + Vector((0, 0, dz))
    bmesh.ops.delete(mb.bm, geom=kill, context='VERTS')
    mb.tag(list(mb.bm.verts), mat, "head")
    return mb


def beard_region(h, p, zl_pts, hole):
    if p.y > 0.45 or h.z > 1.70:
        return None
    zl = interp(zl_pts, abs(h.x))
    if zl - h.z < -0.012:
        return None
    s = sstep(0.0, 0.006, zl - h.z)
    hx, hz, cz = hole
    s *= sstep(1.0, 1.3, (h.x / hx) ** 2 + ((h.z - cz) / hz) ** 2)
    s *= sstep(0.42, 0.22, p.y)
    return s


def add_mustache(mb, big):
    surf = head_surf("m")
    wd = 0.034 if big else 0.031
    path, radii = [], []
    for i in range(9):
        u = lerp(-1, 1, i / 8)
        x = u * wd
        z = 1.6078 + 0.0018 * (1 - u * u) - 0.0065 * u ** 4
        path.append((x, surf.at(x, z, 0.0).y - 0.0035, z))
        radii.append(((0.0062 if big else 0.0052) * (1 - 0.65 * u * u), 0.0042))
    mb.sweep(path, radii, "Hair", "head", seg=6)


def build_beards(rig):
    zl_stub = [(0.0, 1.611), (0.03, 1.611), (0.055, 1.613), (0.075, 1.626), (0.095, 1.65)]
    zl_full = [(0.0, 1.613), (0.03, 1.618), (0.055, 1.63), (0.075, 1.648), (0.095, 1.668)]

    def stubble(h, p):
        s = beard_region(h, p, zl_stub, (0.031, 0.0105, 1.597))
        return None if s is None else (lerp(-0.002, 0.0011, s), 0.0)

    def full(h, p):
        s = beard_region(h, p, zl_full, (0.0265, 0.0115, 1.5945))
        if s is None:
            return None
        return (lerp(-0.003, 0.0095 + 0.010 * sstep(1.585, 1.55, h.z), s), -0.012 * sstep(1.575, 1.545, h.z) * s)

    def goatee(h, p):
        if p.y > 0.0 or h.z > 1.6:
            return None
        s = sstep(0.036, 0.027, abs(h.x)) * sstep(1.5895, 1.5845, h.z)
        if s <= 0 and (abs(h.x) > 0.05 or h.z > 1.595):
            return None
        return (lerp(-0.002, 0.0065, s), -0.008 * sstep(1.57, 1.545, h.z) * s)

    beard_mesh("Beard_stubble", stubble, "Stubble").to_object(rig)
    beard_mesh("Beard_full", full).to_object(rig)
    mb = beard_mesh("Beard_goatee", goatee)
    add_mustache(mb, False)
    mb.to_object(rig)
    mb = MB("Beard_mustache")
    mb.xf = ALL
    add_mustache(mb, True)
    mb.to_object(rig)


def build_glasses(kind, rig):
    surf = head_surf("m")
    mb = MB(f"Glasses_{kind}")
    mb.xf = ALL
    yf = surf.at(EX, EZ, 0.0).y - 0.012
    hw = 0.0205 if kind == 1 else 0.0245
    for s in (-1, 1):
        cx = s * EX
        if kind == 1:
            path = [(cx + hw * math.cos(a), yf, EZ + hw * math.sin(a)) for a in (2 * math.pi * i / 18 for i in range(18))]
        else:
            hh, rc = 0.0165, 0.005
            path = []
            for qx, qz, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
                ccx, ccz = cx + qx * (hw - rc), EZ + qz * (hh - rc)
                for j in range(4):
                    a = math.radians(a0 + 90 * j / 3)
                    path.append((ccx + rc * math.cos(a), yf, ccz + rc * math.sin(a)))
        mb.sweep(path, [0.0016] * len(path), "Frame", "head", seg=5, closed=True)
        ow = cx + s * hw
        mb.sweep([(ow, yf, EZ + 0.004), (s * 0.075, yf + 0.006, EZ + 0.006), (s * 0.097, yf + 0.03, EZ + 0.006),
                  (s * 0.099, 0.02, EZ + 0.002), (s * 0.097, 0.034, EZ - 0.014)], [0.0014] * 5, "Frame", "head", seg=4)
    iw = EX - hw
    mb.sweep([(-iw, yf, EZ + 0.003), (0.0, yf - 0.0015, EZ + 0.006), (iw, yf, EZ + 0.003)], [0.0014] * 3, "Frame", "head", seg=4)
    return mb.to_object(rig)


# ------------------------------------------------------------------ animaciones

AX = {"X": Vector((1, 0, 0)), "Y": Vector((0, 1, 0)), "Z": Vector((0, 0, 1))}


def lq(rig, bone, rots):
    r = rig.data.bones[bone].matrix_local.to_quaternion()
    q = Quaternion()
    for ax, deg in rots:
        q = Quaternion(AX[ax], math.radians(deg)) @ q
    return r.inverted() @ q @ r


def mirror(pose):
    out = {}
    for b, rots in pose.items():
        nb = b[:-1] + ("R" if b.endswith("L") else "L") if b[-2:] in (".L", ".R") else b
        out[nb] = [(ax, -d if ax in "YZ" else d) for ax, d in rots]
    return out


def make_action(rig, name, keys, hips_z=None):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    bones = [b.name for b in rig.data.bones if b.name != "root"]
    hips = rig.pose.bones["hips"]
    hr = rig.data.bones["hips"].matrix_local.to_quaternion().inverted()
    for fr in sorted(keys):
        for b in bones:
            pb = rig.pose.bones[b]
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = lq(rig, b, keys[fr].get(b, []))
            pb.keyframe_insert("rotation_quaternion", frame=fr, group=b)
        hips.location = hr @ Vector((0, 0, (hips_z or {}).get(fr, 0.0)))
        hips.keyframe_insert("location", frame=fr, group="hips")
    tr = rig.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 0, act)
    if hasattr(st, "action_slot") and len(getattr(act, "slots", [])) > 0 and st.action_slot is None:
        st.action_slot = act.slots[0]
    rig.animation_data.action = None
    return act


def build_anims(rig):
    rig.animation_data_create()
    base = {"spine": [("X", 1)], "forearm.L": [("X", -10)], "forearm.R": [("X", -10)],
            "upper_arm.L": [("Y", -3)], "upper_arm.R": [("Y", 3)]}

    def pose(**kw):
        d = {b: list(r) for b, r in base.items()}
        for b, r in kw.items():
            d[b.replace("_L", ".L").replace("_R", ".R")] = r
        return d

    idle = {
        0: pose(head=[("X", 2)]),
        24: pose(chest=[("X", -1.5)], head=[("X", 1), ("Y", 1.5)], upper_arm_L=[("Y", -4), ("X", 1)]),
        48: pose(head=[("X", 2), ("Z", 3)]),
        72: pose(chest=[("X", -1.2)], head=[("X", 1.5), ("Y", -1.5)], upper_arm_R=[("Y", 4), ("X", 1)]),
    }
    idle[96] = idle[0]
    make_action(rig, "idle", idle)

    c0 = {"thigh.L": [("X", -22)], "shin.L": [("X", 6)], "foot.L": [("X", -8)],
          "thigh.R": [("X", 20)], "shin.R": [("X", 14)], "foot.R": [("X", 14)],
          "upper_arm.L": [("X", 16), ("Y", -3)], "forearm.L": [("X", -12)],
          "upper_arm.R": [("X", -16), ("Y", 3)], "forearm.R": [("X", -28)],
          "hips": [("Z", -5)], "spine": [("X", 3)], "chest": [("Z", 9)], "head": [("Z", -4)]}
    c6 = {"thigh.L": [("X", 2)], "shin.L": [("X", 6)], "foot.L": [("X", 0)],
          "thigh.R": [("X", -12)], "shin.R": [("X", 42)], "foot.R": [("X", 2)],
          "upper_arm.L": [("Y", -3)], "forearm.L": [("X", -18)],
          "upper_arm.R": [("Y", 3)], "forearm.R": [("X", -18)], "spine": [("X", 3)]}
    walk = {0: c0, 6: c6, 12: mirror(c0), 18: mirror(c6), 24: c0}
    make_action(rig, "walk", walk, hips_z={0: -0.026, 6: 0.004, 12: -0.026, 18: 0.004, 24: -0.026})

    # gesticula con la derecha (antebrazo hacia el centro del cuerpo) y de vez en cuando con la izquierda
    talk = {
        0: pose(upper_arm_R=[("X", -6), ("Y", 5), ("Z", 18)], forearm_R=[("X", -48)], forearm_L=[("X", -14)], head=[("X", 1)]),
        12: pose(upper_arm_R=[("X", -10), ("Y", 9), ("Z", 26)], forearm_R=[("X", -62), ("Z", -10)], forearm_L=[("X", -14)], head=[("X", 3.5), ("Z", 2)], chest=[("Z", -3)]),
        24: pose(upper_arm_R=[("X", -7), ("Y", 5), ("Z", 20)], forearm_R=[("X", -52)], forearm_L=[("X", -14)], head=[("X", -0.5)]),
        36: pose(upper_arm_R=[("X", -12), ("Y", 10), ("Z", 28)], forearm_R=[("X", -66), ("Z", 8)], upper_arm_L=[("X", -6), ("Y", -5), ("Z", -18)], forearm_L=[("X", -40)], head=[("X", 3), ("Z", -2)], chest=[("Z", 2)]),
        48: pose(upper_arm_R=[("X", -5), ("Y", 5), ("Z", 16)], forearm_R=[("X", -44)], forearm_L=[("X", -16)], head=[("X", 0.5)]),
        60: pose(upper_arm_R=[("X", -9), ("Y", 7), ("Z", 24)], forearm_R=[("X", -58), ("Z", -6)], forearm_L=[("X", -14)], head=[("X", 3), ("Z", 2)]),
    }
    talk[72] = talk[0]
    make_action(rig, "talk", talk)
    build_stage_anims(rig, base)
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


# ------------------------------------------------------------------ posturas de los escenarios 3D
# Rueda de prensa, negociación y Congreso. Sentado: asiento a 0,45 m bajo la cadera, muslos en horizontal
# y espinillas casi en vertical; en la mesa, antebrazos sobre el tablero (0,76 m).

SIT_Z = -0.42
KNEEL_Z = -0.46


def build_stage_anims(rig, base):
    sit = {"spine": [("X", -2)], "chest": [("X", 2)], "head": [("X", 3)],
           "thigh.L": [("X", -84), ("Z", 6)], "shin.L": [("X", 80)], "foot.L": [("X", 4)],
           "upper_arm.L": [("X", -14), ("Y", 4)], "forearm.L": [("X", -62), ("Z", -14)]}
    sit.update(mirror({b: r for b, r in sit.items() if b.endswith(".L")}))

    def make(src, **kw):
        d = {b: list(r) for b, r in src.items()}
        for b, r in kw.items():
            d[b.replace("_L", ".L").replace("_R", ".R")] = r
        return d

    def seat(**kw):
        return make(sit, **kw)

    def stand(**kw):
        return make(base, **kw)

    def both(d, bone, rots):
        """La misma postura en los dos lados (la derecha, en espejo)."""
        d[bone + ".L"] = rots
        d.update(mirror({bone + ".L": rots}))
        return d

    def seated(name, keys):
        make_action(rig, name, keys, hips_z={fr: SIT_Z for fr in keys})

    # sentado, quieto
    k = {0: seat(), 48: seat(chest=[("X", 3.5)], head=[("X", 4), ("Z", 5)])}
    k[96] = k[0]
    seated("sit", k)

    # sentado, hablando: gesticula con la derecha
    k = {
        0: seat(upper_arm_R=[("X", -10), ("Y", 5), ("Z", 18)], forearm_R=[("X", -52)], head=[("X", 2)]),
        12: seat(upper_arm_R=[("X", -16), ("Y", 9), ("Z", 26)], forearm_R=[("X", -66), ("Z", -10)], head=[("X", 4), ("Z", 2)], chest=[("X", 2), ("Z", -3)]),
        24: seat(upper_arm_R=[("X", -12), ("Y", 5), ("Z", 20)], forearm_R=[("X", -56)], head=[("X", 1)]),
        36: seat(upper_arm_R=[("X", -18), ("Y", 10), ("Z", 28)], forearm_R=[("X", -70), ("Z", 8)], upper_arm_L=[("X", -16), ("Y", -2), ("Z", -14)], forearm_L=[("X", -50)], head=[("X", 3), ("Z", -2)]),
        48: seat(upper_arm_R=[("X", -9), ("Y", 5), ("Z", 16)], forearm_R=[("X", -48)], head=[("X", 1.5)]),
    }
    k[60] = k[0]
    seated("sit_talk", k)

    # sentado tomando notas: libreta en el regazo, la mano derecha escribe
    def notes(dz, dx):
        d = seat(head=[("X", 14)], chest=[("X", 5)])
        both(d, "upper_arm", [("X", -20), ("Y", 8)])
        both(d, "forearm", [("X", -78), ("Z", -20)])
        d["forearm.R"] = [("X", -78 + dx), ("Z", 20 + dz)]
        return d
    k = {0: notes(0, 0), 6: notes(-5, 3), 12: notes(2, -2), 18: notes(-4, 2)}
    k[24] = k[0]
    seated("sit_write", k)

    # sentado con la mano alzada para preguntar
    k = {0: seat(upper_arm_R=[("X", -166), ("Z", -6)], forearm_R=[("X", -14)], head=[("X", -2)], chest=[("Z", 3)]),
         20: seat(upper_arm_R=[("X", -170), ("Z", 5)], forearm_R=[("X", -20)], head=[("X", -1)], chest=[("Z", 2)])}
    k[40] = k[0]
    seated("sit_raise", k)

    # aplausos: manos que se juntan y se separan delante del pecho
    def clap(d, closed):
        both(d, "upper_arm", [("X", -38), ("Y", 22)])
        both(d, "forearm", [("X", -72), ("Z", -34 if closed else -10)])
        both(d, "hand", [("X", 10)])
        return d
    k = {fr: clap(seat(head=[("X", 1)]), i % 2 == 0) for i, fr in enumerate(range(0, 17, 4))}
    seated("sit_clap", k)
    k = {fr: clap(stand(head=[("X", 1)]), i % 2 == 0) for i, fr in enumerate(range(0, 17, 4))}
    make_action(rig, "clap", k)

    # en la mesa de negociación: antebrazos sobre el tablero, algo inclinado hacia delante
    def table(**kw):
        d = seat(spine=[("X", 6)], chest=[("X", 3)], head=[("X", -4)])
        both(d, "upper_arm", [("X", -30), ("Y", 8)])
        both(d, "forearm", [("X", -60), ("Z", -26)])
        for b, r in kw.items():
            d[b.replace("_L", ".L").replace("_R", ".R")] = r
        return d
    k = {0: table(), 48: table(head=[("X", -2), ("Z", 4)], chest=[("X", 4)])}
    k[96] = k[0]
    seated("sit_table", k)
    k = {
        0: table(upper_arm_R=[("X", -40), ("Y", 4), ("Z", 14)], forearm_R=[("X", -78), ("Z", -4)]),
        12: table(upper_arm_R=[("X", -46), ("Y", 8), ("Z", 22)], forearm_R=[("X", -92), ("Z", 6)], head=[("X", -2), ("Z", 2)]),
        24: table(upper_arm_R=[("X", -42), ("Y", 4), ("Z", 16)], forearm_R=[("X", -82)]),
        36: table(upper_arm_R=[("X", -50), ("Y", 10), ("Z", 26)], forearm_R=[("X", -96), ("Z", 10)], forearm_L=[("X", -70), ("Z", -12)], head=[("X", -5), ("Z", -2)]),
    }
    k[48] = k[0]
    seated("sit_table_talk", k)

    # fotógrafos: la cámara delante de la cara, de pie o con una rodilla en el suelo
    def camera(d):
        both(d, "upper_arm", [("X", -60), ("Y", 26)])
        both(d, "forearm", [("X", -100), ("Z", -42)])
        both(d, "hand", [("X", -24)])
        d["head"] = [("X", 4)]
        return d
    k = {0: camera(stand()), 30: camera(stand(chest=[("Z", 4)]))}
    k[60] = k[0]
    make_action(rig, "photo", k)
    kneel = {"spine": [("X", 8)], "thigh.L": [("X", -88), ("Z", 4)], "shin.L": [("X", 88)], "foot.L": [("X", 0)],
             "thigh.R": [("X", 4), ("Z", -4)], "shin.R": [("X", 96)], "foot.R": [("X", 44)]}
    k = {0: camera(make(kneel)), 30: camera(make(kneel, chest=[("Z", -4)]))}
    k[60] = k[0]
    make_action(rig, "kneel_photo", k, hips_z={fr: KNEEL_Z for fr in k})

    # operador de cámara de televisión: manos en los mandos, la vista en el visor
    def operate(d):
        both(d, "upper_arm", [("X", -16), ("Y", 6)])
        both(d, "forearm", [("X", -48), ("Z", -6)])
        d["upper_arm.R"] = [("X", -10), ("Y", -14)]
        d["head"] = [("X", 6)]
        return d
    k = {0: operate(stand()), 48: operate(stand(chest=[("Z", -3)]))}
    k[96] = k[0]
    make_action(rig, "operate", k)
    build_reaction_anims(rig, stand, seat, both, seated)


# ------------------------------------------------------------------ gestos de los escenarios 3D
# El líder de la oposición señala y se ríe, las bancadas se ponen en pie o abuchean, el presidente apoya las manos en
# el atril, la presidenta de la Cámara da con el mazo y, en la mesa de negociación, el otro líder asiente, niega, se
# cruza de brazos, lee la propuesta, la firma, tiende la mano o se ríe.

def build_reaction_anims(rig, stand, seat, both, seated):
    def put(d, **kw):
        for b, r in kw.items():
            d[b.replace("_L", ".L").replace("_R", ".R")] = r
        return d

    def loop(name, poses, step, make=None):
        k = {i * step: p for i, p in enumerate(poses)}
        k[len(poses) * step] = poses[0]
        (make or (lambda n, kk: make_action(rig, n, kk)))(name, k)

    # de pie, señalando con el brazo derecho estirado; cada pocos fotogramas, un golpe de énfasis
    def point(j):
        return stand(upper_arm_R=[("X", -76 - 14 * j), ("Y", 4), ("Z", 4)], forearm_R=[("X", -6 - 18 * j)], hand_R=[("X", -10)],
                     chest=[("X", -1), ("Z", -5)], head=[("X", -5 + 3 * j), ("Z", -3)],
                     upper_arm_L=[("X", -6), ("Y", -8)], forearm_L=[("X", -34)])
    loop("point", [point(0), point(1), point(0.2), point(0.8)], 9)

    # de pie, riéndose: echa la cabeza atrás con las manos en la tripa y los hombros dando sacudidas
    def laugh(t):
        d = stand(spine=[("X", -3)], chest=[("X", -5 - 3 * t)], head=[("X", -15 - 5 * t)])
        both(d, "upper_arm", [("X", -14), ("Y", 4)])
        both(d, "forearm", [("X", -72), ("Z", -32)])
        return d
    loop("laugh", [laugh(0), laugh(1)], 4)

    # de pie, celebrando con los brazos en alto
    def cheer(t):
        d = stand(head=[("X", -8)], chest=[("X", -2)])
        both(d, "upper_arm", [("X", -150 + 10 * t), ("Y", -18)])
        both(d, "forearm", [("X", -18 - 32 * t)])
        return d
    loop("cheer", [cheer(0), cheer(1)], 6)

    # de pie en el atril: las dos manos apoyadas en el tablero (a 1,1 m)
    def lect(**kw):
        d = stand(chest=[("X", 4)], head=[("X", 2)])
        both(d, "upper_arm", [("X", -28), ("Y", -10)])
        both(d, "forearm", [("X", -46), ("Z", -14)])
        both(d, "hand", [("X", -20)])
        return put(d, **kw)
    loop("lectern", [lect(), lect(chest=[("X", 5.5)], head=[("X", 3), ("Z", 4)])], 48)
    loop("lectern_talk", [
        lect(upper_arm_R=[("X", -40), ("Y", 8), ("Z", 16)], forearm_R=[("X", -62)], head=[("X", 0)]),
        lect(upper_arm_R=[("X", -52), ("Y", 12), ("Z", 26)], forearm_R=[("X", -80), ("Z", -10)], head=[("X", -2), ("Z", 3)]),
        lect(upper_arm_R=[("X", -42), ("Y", 8), ("Z", 18)], forearm_R=[("X", -66)], head=[("X", 1)]),
        lect(upper_arm_R=[("X", -56), ("Y", 12), ("Z", 30)], forearm_R=[("X", -86), ("Z", 8)], head=[("X", -1), ("Z", -3)]),
    ], 12)

    # sentados: abuchear agitando el brazo, celebrar con los puños en alto y reírse
    def protest(t):
        return seat(upper_arm_R=[("X", -124), ("Y", 10)], forearm_R=[("X", -34), ("Z", -26 + 52 * t)], hand_R=[("X", -10)],
                    head=[("X", -4), ("Z", -8 + 16 * t)], chest=[("X", -2)])
    loop("sit_protest", [protest(0), protest(1)], 6, seated)

    def scheer(t):
        return seat(head=[("X", -6)], upper_arm_R=[("X", -150 + 12 * t), ("Y", 14)], forearm_R=[("X", -25 - 35 * t)],
                    upper_arm_L=[("X", -140 + 12 * (1 - t)), ("Y", -14)], forearm_L=[("X", -25 - 35 * (1 - t))])
    loop("sit_cheer", [scheer(0), scheer(1)], 6, seated)

    def slaugh(t):
        d = seat(spine=[("X", -4)], chest=[("X", -4 - 3 * t)], head=[("X", -14 - 5 * t)])
        both(d, "upper_arm", [("X", -16), ("Y", 4)])
        both(d, "forearm", [("X", -70), ("Z", -28)])
        return d
    loop("sit_laugh", [slaugh(0), slaugh(1)], 4, seated)

    # en la mesa (antebrazos sobre el tablero, como sit_table)
    def table(**kw):
        d = seat(spine=[("X", 6)], chest=[("X", 3)], head=[("X", -4)])
        both(d, "upper_arm", [("X", -30), ("Y", 8)])
        both(d, "forearm", [("X", -60), ("Z", -26)])
        return put(d, **kw)
    loop("sit_table_nod", [table(head=[("X", -6)]), table(head=[("X", 11)])], 8, seated)
    loop("sit_table_no", [table(head=[("X", 1), ("Z", -15)]), table(head=[("X", 1), ("Z", 15)])], 7, seated)

    def cross(**kw):
        d = seat(spine=[("X", -5)], chest=[("X", -2)], head=[("X", -3)],
                 upper_arm_L=[("X", -34), ("Y", 10)], forearm_L=[("X", -92), ("Z", -62)],
                 upper_arm_R=[("X", -30), ("Y", -10)], forearm_R=[("X", -84), ("Z", 58)])
        return put(d, **kw)
    loop("sit_table_cross", [cross(), cross(head=[("X", -1), ("Z", 6)])], 48, seated)

    def read(**kw):
        d = seat(spine=[("X", 4)], chest=[("X", 2)], head=[("X", 17)])
        both(d, "upper_arm", [("X", -40), ("Y", 10)])
        both(d, "forearm", [("X", -72), ("Z", -30)])
        both(d, "hand", [("X", -30)])
        return put(d, **kw)
    loop("sit_table_read", [read(), read(head=[("X", 19), ("Z", 4)]), read(head=[("X", 16), ("Z", -4)])], 30, seated)

    def sign(dz):
        return table(head=[("X", 20)], chest=[("X", 6)], upper_arm_R=[("X", -34), ("Y", 4)], forearm_R=[("X", -64), ("Z", 30 + dz)])
    loop("sit_table_sign", [sign(0), sign(-8), sign(4), sign(-6), sign(2), sign(-9)], 4, seated)

    def offer(t):
        return table(chest=[("X", 6 + 2 * t)], upper_arm_R=[("X", -72 - 4 * t), ("Y", 4), ("Z", 6)], forearm_R=[("X", -14)],
                     hand_R=[("X", 6)], head=[("X", -6)])
    loop("sit_table_offer", [offer(0), offer(1)], 24, seated)

    def tlaugh(t):
        return table(spine=[("X", -2)], chest=[("X", -4 - 3 * t)], head=[("X", -16 - 5 * t)])
    loop("sit_table_laugh", [tlaugh(0), tlaugh(1)], 4, seated)

    def gavel(up):
        return table(upper_arm_R=[("X", -46 - 30 * up), ("Y", 6), ("Z", 8)], forearm_R=[("X", -70 - 40 * up)], head=[("X", 4)])
    loop("sit_table_gavel", [gavel(1), gavel(0), gavel(1), gavel(0), gavel(1), gavel(1)], 5, seated)


# ------------------------------------------------------------------ montaje y exportación

def build_all():
    rig = make_rig()
    for g in ("m", "f"):
        build_body(g, rig)
        build_head(g, rig)
        build_face(g, rig)
    build_tie(rig)
    build_pearls(rig)
    build_uniform(rig)
    build_accessories(rig)
    build_hairs(rig)
    build_beards(rig)
    build_glasses(1, rig)
    build_glasses(2, rig)
    build_anims(rig)
    return rig


def export(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    opts = dict(filepath=path, export_format='GLB', export_yup=True, export_apply=False,
                export_texcoords=False, export_normals=True, export_materials='EXPORT',
                export_skins=True, export_morph=True, export_morph_normal=False,
                export_animations=True, export_animation_mode='ACTIONS', export_force_sampling=True,
                export_anim_single_armature=True, export_reset_pose_bones=True, export_def_bones=False,
                export_cameras=False, export_lights=False)
    try:
        bpy.ops.export_scene.gltf(**opts)
    except TypeError as e:
        print("GLTF opts fallback:", e)
        for k in ("export_morph_normal", "export_anim_single_armature", "export_reset_pose_bones", "export_def_bones"):
            opts.pop(k, None)
        bpy.ops.export_scene.gltf(**opts)


def verify(path):
    import json
    import struct
    with open(path, "rb") as fh:
        data = fh.read()
    ln = struct.unpack("<I", data[12:16])[0]
    js = json.loads(data[20:20 + ln])
    print("GLB bytes:", len(data))
    print("animations:", [a.get("name") for a in js.get("animations", [])])
    for m in js.get("meshes", []):
        tn = m.get("extras", {}).get("targetNames", [])
        print("mesh:", m.get("name"), "prims:", len(m["primitives"]), "targets:", tn)
    print("skins:", len(js.get("skins", [])), "joints:", len(js["skins"][0]["joints"]) if js.get("skins") else 0)


# ------------------------------------------------------------------ previews

SKIN = ["f1d3bd", "e6bc98", "d4a276", "b67f56", "8d5a3b", "5e3b26"]
HAIR = ["1c1816", "3b2a20", "6b4a2f", "8a4b2a", "c9a46a", "9a9a98", "dcd8d0"]
LOOKS = [
    {"g": "f", "skin": 1, "hair": "bob", "hc": 1, "glasses": 2, "suit": "243653", "shirt": "e8e4dc", "tie": "", "age": 1, "eyes": "5a4632"},
    {"g": "m", "skin": 0, "hair": "balding", "hc": 5, "glasses": 1, "suit": "3a3d44", "shirt": "f2f2f2", "tie": "7a1f2b", "age": 2, "beard": "none", "eyes": "4d6a80"},
    {"g": "f", "skin": 2, "hair": "bun", "hc": 0, "glasses": 0, "suit": "1f2124", "shirt": "d9d9d9", "tie": "", "age": 1, "eyes": "3b2a20"},
    {"g": "m", "skin": 2, "hair": "buzz", "hc": 5, "glasses": 0, "suit": "3f4a32", "shirt": "d8d2b8", "tie": "2b2f22", "age": 2, "beard": "mustache", "uniform": True, "eyes": "3b2a20"},
    {"g": "f", "skin": 3, "hair": "curly", "hc": 0, "glasses": 0, "suit": "2e5f6b", "shirt": "f5f5f5", "tie": "", "age": 0, "eyes": "2a1c14"},
    {"g": "m", "skin": 3, "hair": "wavy", "hc": 1, "glasses": 0, "suit": "2a4a5a", "shirt": "f0f0f0", "tie": "1aa39a", "age": 1, "beard": "stubble", "eyes": "2a1c14"},
    {"g": "f", "skin": 1, "hair": "long", "hc": 4, "glasses": 0, "suit": "2b3e66", "shirt": "fafafa", "tie": "", "age": 0, "eyes": "4d6a80"},
    {"g": "m", "skin": 0, "hair": "slick", "hc": 6, "glasses": 0, "suit": "22252c", "shirt": "ffffff", "tie": "b08a3e", "age": 2, "beard": "none", "eyes": "4d6a80"},
    {"g": "m", "skin": 3, "hair": "short", "hc": 0, "glasses": 0, "suit": "e9e4d8", "shirt": "ffffff", "tie": "", "age": 1, "beard": "full", "eyes": "2a1c14"},
    {"g": "f", "skin": 2, "hair": "wavy", "hc": 3, "glasses": 0, "suit": "5a1f2a", "shirt": "f3ece6", "tie": "", "age": 1, "eyes": "3b2a20"},
    {"g": "m", "skin": 1, "hair": "side", "hc": 5, "glasses": 0, "suit": "1b2c52", "shirt": "f4f6fa", "tie": "2f6fd6", "age": 1, "beard": "none", "eyes": "4d6a80"},
    {"g": "f", "skin": 5, "hair": "ponytail", "hc": 0, "glasses": 0, "suit": "2f6b4a", "shirt": "f2e6c8", "tie": "", "age": 1, "eyes": "2a1c14"},
    {"g": "m", "skin": 4, "hair": "bald", "hc": 0, "glasses": 2, "suit": "2a2c30", "shirt": "e0e0e0", "tie": "22262b", "age": 2, "beard": "goatee", "eyes": "2a1c14"},
    {"g": "m", "skin": 1, "hair": "curly", "hc": 3, "glasses": 0, "suit": "4a3a5a", "shirt": "ffffff", "tie": "c9a55c", "age": 0, "beard": "none", "eyes": "3b2a20"},
]


def defaults(l):
    d = {"g": "m", "skin": 1, "hair": "short", "hc": 1, "glasses": 0, "suit": "243653", "shirt": "f2f2f2", "tie": "7a1f2b",
         "age": 1, "beard": "none", "eyes": "3b2a20", "uniform": False}
    d.update(l)
    if d["g"] == "f" and "tie" not in l:
        d["tie"] = ""
    return d


def dark(c, a):
    return tuple(x * (1 - a) for x in c)


def mix(c1, c2, t):
    return tuple(lerp(x, y, t) for x, y in zip(c1, c2))


def look_mats(l):
    skin = hexrgb(SKIN[l["skin"]])
    hair = hexrgb(HAIR[l["hc"]])
    suit = hexrgb(l["suit"])
    f = l["g"] == "f"
    brow = dark(hexrgb(HAIR[5]), 0.2) if l["hair"] in ("bald", "balding") and l["hc"] >= 5 else dark(hair, 0.15)
    gold = hexrgb("c9a55c")
    return {
        "Skin": (skin, 0.6, 0.0), "Suit": (dark(suit, 0.08), 0.75, 0.0), "Trousers": (dark(suit, 0.2), 0.75, 0.0),
        "Lapel": (dark(suit, 0.25), 0.7, 0.0), "Shirt": (hexrgb(l["shirt"]), 0.6, 0.0),
        "Tie": (hexrgb(l["tie"] or "7a1f2b"), 0.5, 0.0), "Shoes": (hexrgb("0d0b0a"), 0.35, 0.0),
        "Button": (gold, 0.35, 0.8) if l["uniform"] else (hexrgb("15110e"), 0.5, 0.0),
        "Hair": (hair, 0.45 if l["hair"] == "slick" else 0.8, 0.0), "HairTie": (hexrgb("1a1716"), 0.6, 0.0),
        "Stubble": (mix(skin, dark(hair, 0.3), 0.22), 0.8, 0.0), "Brow": (brow, 0.8, 0.0),
        "Sclera": (hexrgb("f4f1ea"), 0.4, 0.0), "Iris": (hexrgb(l["eyes"]), 0.3, 0.0), "Pupil": (hexrgb("0d0a09"), 0.3, 0.0),
        "Glint": ((1, 1, 1), 0.2, 0.0), "Lid": (hexrgb("1f1512"), 0.6, 0.0),
        "Lip": (mix(dark(skin, 0.28), hexrgb("b0504f"), 0.45 if f else 0.2), 0.5, 0.0),
        "MouthIn": (hexrgb("3a1414"), 0.8, 0.0), "Teeth": (hexrgb("eeeae0"), 0.4, 0.0),
        "Frame": (hexrgb("1f1a1a"), 0.4, 0.3), "Gold": (gold, 0.35, 0.8), "Pearl": (hexrgb("f3ead6"), 0.3, 0.0),
        "Cap": (suit, 0.75, 0.0), "CapBand": (hexrgb("1f2419"), 0.7, 0.0), "Visor": (hexrgb("141611"), 0.25, 0.0),
    }


def apply_look(rig, l):
    l = defaults(l)
    g = l["g"]
    vis = look_parts(l)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in vis
    for n, (c, r, m) in look_mats(l).items():
        if n in bpy.data.materials:
            set_col(bpy.data.materials[n], c, r, m)
    rig.scale = (0.96,) * 3 if g == "f" else (1.0,) * 3


def look_parts(l):
    """Piezas del modelo que lleva un aspecto (las mismas que enseña visitor_3d.gd)."""
    g = l["g"]
    names = {o.name for o in bpy.data.objects}
    vis = {"Body_" + g.upper(), "Head_" + g.upper(), "Face_" + g.upper()}
    hn = "Hair_%s_f" % l["hair"]
    vis.add(hn if g == "f" and hn in names else "Hair_" + l["hair"])
    if g == "m" and l["beard"] != "none":
        vis.add("Beard_" + l["beard"])
    if l["glasses"]:
        vis.add("Glasses_%d" % l["glasses"])
    if l["tie"]:
        vis.add("Tie")
    if g == "f" and not l["tie"] and l["age"] >= 1 and not l["uniform"]:
        vis.add("Pearls")
    if l["uniform"]:
        vis.add("Uniform")
    if l.get("acc"):
        vis.add("Acc_%s_%s" % (l["acc"], g.upper()))
    return vis


def set_keys(vals):
    for o in bpy.data.objects:
        if o.type == 'MESH' and o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks[1:]:
                kb.value = vals.get(kb.name, 0.0)


def previews(rig, folder):
    os.makedirs(folder, exist_ok=True)
    # EEVEE necesita contexto GPU y en modo -b puede cerrar Blender; Cycles en CPU siempre funciona
    SCN.render.engine = 'CYCLES'
    SCN.cycles.device = 'CPU'
    SCN.cycles.samples = 24
    SCN.cycles.use_denoising = True
    SCN.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new("W")
    SCN.world = world
    world.color = (0.2, 0.2, 0.22)
    try:
        world.use_nodes = True
    except Exception:
        pass
    if world.node_tree:
        bg = next((n for n in world.node_tree.nodes if n.type == 'BACKGROUND'), None)
        if bg:
            bg.inputs[0].default_value = (0.2, 0.2, 0.22, 1)
            bg.inputs[1].default_value = 1.0
    for rot, en in (((math.radians(55), 0, math.radians(30)), 3.2), ((math.radians(70), 0, math.radians(-120)), 1.2)):
        ld = bpy.data.lights.new("sun", 'SUN')
        ld.energy = en
        lo = bpy.data.objects.new("sun", ld)
        lo.rotation_euler = rot
        SCN.collection.objects.link(lo)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    SCN.collection.objects.link(cam)
    SCN.camera = cam
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True

    def shot(path, loc, target, lens, res):
        cam.location = loc
        cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
        cam.data.lens = lens
        SCN.render.resolution_x, SCN.render.resolution_y = res
        SCN.render.filepath = path
        bpy.ops.render.render(write_still=True)
        return path

    def act(name, frame):
        rig.animation_data.action = bpy.data.actions[name]
        SCN.frame_set(frame)

    if os.environ.get("PREVIEW_ONLY") == "stage":
        stage_previews(rig, folder, shot, act)
        return
    act("idle", 0)
    set_keys({})
    # accesorios de la tienda (sobre el aspecto del presidente)
    row, row2 = [], []
    for g, base in (("m", LOOKS[10]), ("f", LOOKS[9])):
        for acc in ("pin", "medalla", "banda"):
            l = dict(base, acc=acc)
            apply_look(rig, l)
            tag = f"{g}_{acc}"
            row.append(shot(os.path.join(folder, f"a_{tag}.png"), (0.32, -1.05, 1.36), (0.02, 0, 1.3), 50, (230, 300)))
            row2.append(shot(os.path.join(folder, f"ab_{tag}.png"), (1.0, -2.9, 1.2), (0, 0, 1.0), 50, (230, 330)))
    make_sheet([row, row2], os.path.join(folder, "sheet_acc.png"))
    if os.environ.get("PREVIEW_ONLY") == "acc":
        return
    for sheet_i, chunk in enumerate((LOOKS[:7], LOOKS[7:])):
        bodies, heads = [], []
        for i, l in enumerate(chunk):
            apply_look(rig, l)
            bodies.append(shot(os.path.join(folder, f"b{sheet_i}_{i}.png"), (1.1, -3.4, 1.15), (0, 0, 0.9), 50, (230, 420)))
            heads.append(shot(os.path.join(folder, f"h{sheet_i}_{i}.png"), (0.2, -0.78, 1.69), (0, 0, 1.645), 70, (230, 230)))
        make_sheet([bodies, heads], os.path.join(folder, f"sheet_{sheet_i}.png"))
    # expresiones
    apply_look(rig, LOOKS[5])
    exprs = [{}, {"blink": 1}, {"talk": 1}, {"smile": 1}, {"smile": 0.6, "talk": 0.5}, {"angry": 1, "frown": 0.6}, {"sad": 1, "frown": 1}, {"surprise": 1}]
    row = []
    for i, e in enumerate(exprs):
        set_keys(e)
        row.append(shot(os.path.join(folder, f"e{i}.png"), (0.0, -0.6, 1.64), (0, 0, 1.635), 85, (200, 200)))
    set_keys({})
    apply_look(rig, LOOKS[6])
    row2 = []
    for i, e in enumerate(exprs):
        set_keys(e)
        row2.append(shot(os.path.join(folder, f"ef{i}.png"), (0.0, -0.6, 1.64), (0, 0, 1.635), 85, (200, 200)))
    set_keys({})
    make_sheet([row, row2], os.path.join(folder, "sheet_faces.png"))
    # poses
    row = []
    for l in (LOOKS[1], LOOKS[6]):
        apply_look(rig, l)
        for name, fr in (("walk", 0), ("walk", 6), ("talk", 12)):
            act(name, fr)
            row.append(shot(os.path.join(folder, f"p{len(row)}.png"), (3.2, -1.2, 1.0), (0, 0, 0.88), 50, (230, 400)))
    row2 = []
    for i, l in enumerate((LOOKS[1], LOOKS[0], LOOKS[3])):
        apply_look(rig, l)
        act("talk", 12)
        row2.append(shot(os.path.join(folder, f"t{i}.png"), (0.9, -2.6, 1.3), (0, 0, 1.15), 50, (230, 400)))
        act("idle", 0)
        row2.append(shot(os.path.join(folder, f"c{i}.png"), (0.15, -1.0, 1.42), (0, 0, 1.4), 60, (230, 400)))
    make_sheet([row, row2], os.path.join(folder, "sheet_poses.png"))
    act("idle", 0)


def stage_previews(rig, folder, shot, act):
    """Posturas de los escenarios 3D con una silla (asiento a 0,45 m) y una mesa (0,76 m) de referencia."""
    def prop(name, loc, size, col):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
        ob = bpy.context.active_object
        ob.name = name
        ob.scale = size
        m = bpy.data.materials.new(name)
        set_col(m, col, 0.6, 0.0)
        ob.data.materials.append(m)
        return ob
    chair = [prop("seat", (0, -0.1, 0.225), (0.46, 0.46, 0.45), (0.35, 0.12, 0.1)),
             prop("back", (0, 0.16, 0.7), (0.46, 0.06, 0.5), (0.35, 0.12, 0.1))]
    table = [prop("table", (0, -0.75, 0.74), (1.3, 0.9, 0.04), (0.3, 0.2, 0.12))]
    poses = [("sit", 0, "c"), ("sit_talk", 12, "c"), ("sit_write", 6, "c"), ("sit_raise", 0, "c"), ("sit_clap", 0, "c"),
             ("sit_clap", 4, "c"), ("sit_table", 0, "ct"), ("sit_table_talk", 12, "ct"), ("clap", 0, ""), ("photo", 0, ""),
             ("kneel_photo", 0, ""), ("operate", 0, "")]
    if os.environ.get("PREVIEW_SET") == "gestos":
        poses = [("point", 9, ""), ("laugh", 4, ""), ("cheer", 6, ""), ("lectern", 0, ""), ("lectern_talk", 12, ""),
                 ("sit_protest", 6, "c"), ("sit_cheer", 6, "c"), ("sit_laugh", 4, "c"), ("sit_table_nod", 8, "ct"),
                 ("sit_table_no", 7, "ct"), ("sit_table_cross", 0, "ct"), ("sit_table_read", 0, "ct"), ("sit_table_sign", 4, "ct"),
                 ("sit_table_offer", 0, "ct"), ("sit_table_laugh", 4, "ct"), ("sit_table_gavel", 0, "ct"), ("sit_table_gavel", 5, "ct")]
    rows = []
    for li, l in enumerate((LOOKS[1], LOOKS[6])):
        apply_look(rig, l)
        side, front = [], []
        for i, (name, fr, props) in enumerate(poses):
            for o in chair:
                o.hide_render = "c" not in props
            for o in table:
                o.hide_render = "t" not in props
            act(name, fr)
            side.append(shot(os.path.join(folder, f"s{li}_{i}.png"), (2.6, -1.6, 1.1), (0, -0.2, 0.75), 50, (200, 300)))
            front.append(shot(os.path.join(folder, f"f{li}_{i}.png"), (0.5, -3.0, 1.3), (0, -0.2, 0.8), 50, (200, 300)))
        rows += [side, front]
    make_sheet(rows, os.path.join(folder, "sheet_stage.png"))
    for o in chair + table:
        bpy.data.objects.remove(o)


def make_sheet(rows, out):
    data = []
    for row in rows:
        ims = []
        for p in row:
            im = bpy.data.images.load(p)
            w, h = im.size
            a = np.empty(w * h * 4, dtype=np.float32)
            im.pixels.foreach_get(a)
            ims.append(a.reshape(h, w, 4)[::-1])
            bpy.data.images.remove(im)
        data.append(np.concatenate(ims, axis=1))
    wmax = max(r.shape[1] for r in data)
    data = [np.pad(r, ((0, 0), (0, wmax - r.shape[1]), (0, 0)), constant_values=1.0) for r in data]
    full = np.ascontiguousarray(np.concatenate(data, axis=0)[::-1])
    img = bpy.data.images.new("sheet", full.shape[1], full.shape[0], alpha=True)
    img.pixels.foreach_set(full.ravel())
    img.filepath_raw = out
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)
    print("sheet:", out)


# ------------------------------------------------------------------ público lejano (crowd.glb)
# Diputados de las filas de atrás del hemiciclo: mallas estáticas ya sentadas, simplificadas y con las piezas
# agrupadas por tipo de material, para que Godot las pinte por instancia (stages3d/crowd_3d.gd).

CROWD_CATS = ["Suit", "Trousers", "Skin", "Hair", "Shirt", "Dark", "Tie", "Light"]
CROWD_MAP = {"Suit": "Suit", "Lapel": "Suit", "Cap": "Suit", "Trousers": "Trousers", "Skin": "Skin", "Stubble": "Skin",
             "Lip": "Skin", "Hair": "Hair", "Brow": "Hair", "Shirt": "Shirt", "Tie": "Tie", "Gold": "Tie", "Flag0": "Tie",
             "Flag1": "Tie", "Flag2": "Tie", "Sclera": "Light", "Teeth": "Light", "Glint": "Light", "Pearl": "Light"}
CROWD = [("Seated_M", {"g": "m", "hair": "short"}),
         ("Seated_MB", {"g": "m", "hair": "balding", "glasses": 1, "tie": "22262b"}),
         ("Seated_F", {"g": "f", "hair": "bob", "age": 0}),
         ("Seated_FL", {"g": "f", "hair": "long", "age": 0})]


def export_crowd(rig, path, ratio=0.3):
    for tr in rig.animation_data.nla_tracks:
        tr.mute = True
    rig.animation_data.action = bpy.data.actions["sit"]
    mats = []
    for c in CROWD_CATS:
        m = bpy.data.materials.new("C_" + c)
        set_col(m, (0.5, 0.5, 0.5), 0.7, 0.0)
        mats.append(m)
    made = []
    for name, look in CROWD:
        l = defaults(look)
        rig.scale = (0.96,) * 3 if l["g"] == "f" else (1.0,) * 3
        SCN.frame_set(0)
        bpy.context.view_layer.update()
        dg = bpy.context.evaluated_depsgraph_get()
        bm = bmesh.new()
        for pn in sorted(look_parts(l)):
            ob = bpy.data.objects.get(pn)
            if ob is None:
                continue
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg), preserve_all_data_layers=False, depsgraph=dg)
            me.transform(ob.matrix_world)
            for p in me.polygons:
                mn = me.materials[p.material_index].name if p.material_index < len(me.materials) else ""
                p.material_index = CROWD_CATS.index(CROWD_MAP.get(mn, "Dark"))
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        mesh = bpy.data.meshes.new(name + "_full")
        bm.to_mesh(mesh)
        bm.free()
        for m in mats:
            mesh.materials.append(m)
        ob = bpy.data.objects.new(name, mesh)
        SCN.collection.objects.link(ob)
        ob.modifiers.new("dec", 'DECIMATE').ratio = ratio
        bpy.context.view_layer.update()
        low = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
        low.name = name
        ob.modifiers.clear()
        ob.data = low
        print("crowd:", name, "tris:", sum(len(p.vertices) - 2 for p in low.polygons), "de", sum(len(p.vertices) - 2 for p in mesh.polygons))
        made.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in made:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=False,
                              export_texcoords=False, export_normals=True, export_materials='EXPORT', export_skins=False,
                              export_morph=False, export_animations=False, export_cameras=False, export_lights=False)
    for ob in made:
        bpy.data.objects.remove(ob)
    rig.animation_data.action = None
    for tr in rig.animation_data.nla_tracks:
        tr.mute = False
    rig.scale = (1.0,) * 3
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()


RIG = build_all()
export(OUT)
verify(OUT)
export_crowd(RIG, os.path.join(os.path.dirname(OUT), "crowd.glb"))
if PREVIEW:
    previews(RIG, PREVIEW)
