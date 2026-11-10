"""Procedural 3D fit visualisation of two polyester down jackets on a 168 cm mannequin.

Run:  blender -b -P render/jackets.py -- <short|long> <out_dir> [samples] [scale%]
Units are metres, Z up, the mannequin faces -Y.
"""
import bpy, bmesh, math, sys, os
import numpy as np
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
VARIANT = argv[0] if argv else "short"
OUT = argv[1] if len(argv) > 1 else "renders"
SAMPLES = int(argv[2]) if len(argv) > 2 else 128
SCALE = int(argv[3]) if len(argv) > 3 else 100

HEM = {"short": 0.90, "long": 0.57}[VARIANT]  # short: hip bones, long: ~10 cm above knee (knee ~0.47)
FABRIC_SRGB = {"short": (232, 32, 42), "long": (232, 222, 184)}[VARIANT]  # scarlet / milky swatches

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
RIG = bpy.data.objects.new("Rig", None)
scene.collection.objects.link(RIG)


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def make_mat(name, rgb, rough=0.4, sheen=0.0, spec=0.5, bump=0.0, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*[srgb_to_lin(c) for c in rgb], 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    p.inputs["Specular IOR Level"].default_value = spec
    p.inputs["Sheen Weight"].default_value = sheen
    if bump:
        tc = nt.nodes.new("ShaderNodeTexCoord")
        nz = nt.nodes.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = 22
        nz.inputs["Detail"].default_value = 6
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        b.inputs["Distance"].default_value = 0.004
        nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
        nt.links.new(nz.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


FABRIC = make_mat("Polyester", FABRIC_SRGB, rough=0.36, sheen=0.25, spec=0.55, bump=0.12)
DARK = tuple(int(c * 0.82) for c in FABRIC_SRGB)
CORD = make_mat("Cord", DARK, rough=0.6)
SNAP = make_mat("Snap", (200, 200, 205), rough=0.25, metal=1.0)
LABEL = make_mat("Label", (40, 40, 42), rough=0.7)
SKIN = make_mat("Mannequin", (150, 152, 156), rough=0.45, spec=0.4)


# ---------------------------------------------------------------- mesh helpers
def add_obj(name, verts, faces, mat, solid=None, sub=1, offset=-1.0):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], faces)
    me.update()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.parent = RIG
    me.materials.append(mat)
    if solid:
        s = ob.modifiers.new("Solidify", "SOLIDIFY")
        s.thickness = solid
        s.offset = offset
    if sub:
        s = ob.modifiers.new("Subsurf", "SUBSURF")
        s.levels = sub
        s.render_levels = sub
    return ob


def grid_faces(rows, cols, closed=True):
    f = []
    for i in range(rows - 1):
        for j in range(cols if closed else cols - 1):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            f.append((a, b, b + cols, a + cols))
    return f


def ellipsoid(name, center, radii, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24)
    ob = bpy.context.active_object
    ob.name = name
    ob.location = center
    ob.scale = radii
    ob.rotation_euler = Euler(rot)
    ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.parent = RIG
    return ob


def box(name, center, size, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add()
    ob = bpy.context.active_object
    ob.name = name
    ob.location = center
    ob.scale = [s / 2 for s in size]
    ob.rotation_euler = Euler(rot)
    ob.data.materials.append(mat)
    bv = ob.modifiers.new("Bevel", "BEVEL")
    bv.width = min(size) * 0.35
    bv.segments = 3
    ob.parent = RIG
    return ob


def smooth_profile(table, zs, sigma=0.015):
    t = np.array(table, float)
    step = zs[1] - zs[0]
    k = int(3 * sigma / step) + 1
    ker = np.exp(-0.5 * ((np.arange(-k, k + 1) * step) / sigma) ** 2)
    ker /= ker.sum()
    out = []
    for i in range(1, t.shape[1]):
        v = np.interp(zs, t[:, 0], t[:, i])
        out.append(np.convolve(np.pad(v, k, mode="edge"), ker, "valid"))
    return out


def ring(z, w, df, db, n, e):
    t = np.linspace(0, 2 * np.pi, n, endpoint=False)
    c, s = np.cos(t), np.sin(t)
    x = w * np.sign(c) * np.abs(c) ** (2 / e)
    d = np.where(s < 0, df, db)
    y = d * np.sign(s) * np.abs(s) ** (2 / e)
    return np.stack([x, y, np.full(n, z)], 1)


def front_y(x, w, df, e):
    """y of a superellipse ring's front surface at lateral offset x."""
    c = min(abs(x) / w, 0.999) ** (e / 2)
    return -df * (1 - c * c) ** (1 / e)


def quilt(u, h, amp):
    return amp * np.abs(np.sin(np.pi * ((u / h) % 1.0))) ** 0.5


def loft_body(name, table, z0, z1, mat, n=128, e=2.4, step=0.005, q_h=0, q_amp=0, q_fade=None,
              solid=None, sub=1, sigma=0.015):
    zs = np.arange(z0, z1 + 1e-9, step)
    W, DF, DB = smooth_profile(table, zs, sigma)
    q = quilt(zs - z0, q_h, q_amp) if q_amp else np.zeros_like(zs)
    fade = np.ones_like(zs)
    if q_fade:
        a, b = q_fade
        fade = np.clip((b - zs) / (b - a), 0, 1)
        q *= fade
    verts = np.concatenate([ring(z, w + qq, df + qq, db + qq, n, e) for z, w, df, db, qq in zip(zs, W, DF, DB, q)])
    add_obj(name, verts, grid_faces(len(zs), n), mat, solid=solid, sub=sub)
    return lambda z: (np.interp(z, zs, W), np.interp(z, zs, DF), np.interp(z, zs, DB), q_amp * np.interp(z, zs, fade))


def chaikin(P, it=3):
    for _ in range(it):
        Q = [P[0]]
        for i in range(len(P) - 1):
            Q += [0.75 * P[i] + 0.25 * P[i + 1], 0.25 * P[i] + 0.75 * P[i + 1]]
        Q.append(P[-1])
        P = np.array(Q)
    return P


def tube(name, ctrl, mat, n=64, step=0.005, q_h=0, q_amp=0, cap_start=False, cap_end=False,
         solid=None, sub=1):
    P = chaikin(np.array(ctrl, float))
    seg = np.linalg.norm(np.diff(P[:, :3], axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    ss = np.linspace(0, s[-1], max(2, int(s[-1] / step) + 1))
    P = np.stack([np.interp(ss, s, P[:, i]) for i in range(4)], 1)
    C, R = P[:, :3], P[:, 3].copy()
    if q_amp:
        R += quilt(ss[-1] - ss, q_h, q_amp)  # seams counted from the cuff end
    T = np.gradient(C, axis=0)
    T /= np.linalg.norm(T, axis=1)[:, None]
    ref = np.array([0.0, 1.0, 0.0]) if abs(T[0][1]) < 0.9 else np.array([1.0, 0, 0])
    N = ref - ref.dot(T[0]) * T[0]
    N /= np.linalg.norm(N)
    rows = []
    for i in range(len(C)):
        N = N - N.dot(T[i]) * T[i]
        N /= np.linalg.norm(N)
        rows.append((C[i], R[i], N.copy(), np.cross(T[i], N)))
    m = 8

    def cap(row, t, sign):
        c, r, nn, bb = row
        out = []
        for k in range(1, m + 1):
            ph = (k / m) * (math.pi / 2) * 0.985
            out.append((c + sign * t * r * math.sin(ph), r * math.cos(ph), nn, bb))
        return out

    if cap_start:
        rows = cap(rows[0], T[0], -1)[::-1] + rows
    if cap_end:
        rows = rows + cap(rows[-1], T[-1], 1)
    a = np.linspace(0, 2 * np.pi, n, endpoint=False)
    verts = np.concatenate([c + r * (np.cos(a)[:, None] * nn + np.sin(a)[:, None] * bb) for c, r, nn, bb in rows])
    return add_obj(name, verts, grid_faces(len(rows), n), mat, solid=solid, sub=sub)


# ---------------------------------------------------------------- mannequin (168 cm)
torso_tab = [(0.74, .06, .04, .05), (0.76, .14, .07, .08), (0.80, .168, .085, .105), (0.88, .175, .085, .115),
             (0.96, .16, .08, .10), (1.04, .13, .075, .08), (1.12, .14, .085, .08), (1.20, .155, .115, .085),
             (1.27, .165, .09, .085), (1.33, .175, .075, .075), (1.37, .155, .06, .06), (1.40, .10, .05, .05),
             (1.42, .055, .045, .045)]
loft_body("Mannequin_torso", torso_tab, 0.74, 1.42, SKIN, n=96, e=2.2, step=0.008)
tube("Mannequin_neck", [(0, 0, 1.36, .05), (0, .002, 1.45, .049), (0, .005, 1.52, .048)], SKIN, n=48)
ellipsoid("Mannequin_head", (0, -0.005, 1.575), (.075, .092, .112), SKIN, rot=(math.radians(-6), 0, 0))
for sx in (-1, 1):
    tube(f"Mannequin_arm_{sx}", [(sx * .12, 0, 1.36, .05), (sx * .20, .005, 1.20, .045), (sx * .25, .01, 1.07, .038),
                                 (sx * .29, 0, .94, .033), (sx * .32, -.01, .83, .026), (sx * .325, -.01, .80, .025)],
         SKIN, n=48, cap_start=True)
    ellipsoid(f"Mannequin_hand_{sx}", (sx * .343, -.012, .735), (.014, .03, .078), SKIN, rot=(0, -sx * math.radians(16), 0))
    tube(f"Mannequin_leg_{sx}", [(sx * .085, .005, .88, .095), (sx * .088, .005, .72, .085), (sx * .093, 0, .56, .064),
                                 (sx * .096, -.005, .47, .053), (sx * .097, 0, .37, .055), (sx * .10, 0, .12, .032),
                                 (sx * .10, 0, .05, .03)],
         SKIN, n=48)
    ellipsoid(f"Mannequin_foot_{sx}", (sx * .10, -.05, .035), (.042, .12, .035), SKIN)

# ---------------------------------------------------------------- jacket
E = 2.6
body_tab = [(0.50, .245, .155, .165), (0.75, .24, .150, .165), (0.92, .235, .150, .165), (1.05, .228, .148, .15),
            (1.20, .228, .160, .142), (1.30, .235, .140, .135), (1.36, .232, .12, .12), (1.40, .20, .10, .10),
            (1.43, .13, .09, .09), (1.45, .085, .075, .08)]
Q_H, Q_AMP = (0.10, 0.014) if VARIANT == "short" else (0.11, 0.014)
dims = loft_body("Jacket_body", body_tab, HEM, 1.45, FABRIC, n=144, e=E, step=0.004, q_h=Q_H, q_amp=Q_AMP,
                 q_fade=(1.33, 1.40), solid=0.012)


def surface_y(x, z, lift=0.0):
    w, df, _, qa = dims(z)
    return front_y(x, w + qa, df + qa, E) - lift


# placket strip along centre front
def placket_y(z):
    w, df, _, qa = dims(z)
    return -(df + qa * 0.55) - 0.002


zs = np.arange(HEM, 1.44, 0.01)
pv = []
for z in zs:
    pv += [(-.02, placket_y(z), z), (.02, placket_y(z), z)]
add_obj("Placket", pv, grid_faces(len(zs), 2, closed=False), FABRIC, solid=0.004, sub=1, offset=0)

# snap buttons
snaps = [1.40, 1.25, 1.10, 0.95, 0.80, 0.65] if VARIANT == "long" else [1.38, 1.26, 1.14, 1.02]
for i, z in enumerate(snaps):
    ellipsoid(f"Snap_{i}", (0, placket_y(z) - 0.006, z), (.011, .004, .011), SNAP)

# slanted welt pockets, bottoms flare outwards
pz, pl = (0.855, 0.17) if VARIANT == "long" else (1.02, 0.14)
for sx in (-1, 1):
    x = sx * 0.125
    slope = (surface_y(x + sx * .005, pz) - surface_y(x, pz)) / .005
    box(f"Welt_{sx}", (x, surface_y(x, pz, 0.004), pz), (.02, .008, pl), FABRIC,
        rot=(0, sx * math.radians(14), math.atan(slope) * sx))

# hem drawcord with stoppers + label tab
for sx in (-1, 1):
    y0 = surface_y(0, HEM + .01, 0.006)
    tube(f"Cord_{sx}", [(sx * .012, y0, HEM + .012, .0035), (sx * .016, y0 - .004, HEM - .04, .0035),
                        (sx * .02, y0 - .002, HEM - .12, .0035)], CORD, n=16)
    tube(f"Stopper_{sx}", [(sx * .02, y0 - .002, HEM - .11, .008), (sx * .021, y0 - .002, HEM - .135, .008)],
         CORD, n=24, cap_start=True, cap_end=True)
box("Label", (.17, surface_y(.17, HEM + .035, .003), HEM + .035), (.05, .006, .018), LABEL)

# sleeves: drop shoulder, quilted, elastic cuff
for sx in (-1, 1):
    tube(f"Sleeve_{sx}", [(sx * .165, 0, 1.33, .085), (sx * .23, 0, 1.21, .09), (sx * .265, .008, 1.08, .085),
                          (sx * .295, 0, .95, .078), (sx * .318, -.008, .86, .07), (sx * .325, -.01, .835, .06),
                          (sx * .328, -.01, .825, .05)],
         FABRIC, n=96, step=0.004, q_h=0.085, q_amp=Q_AMP * 0.9, cap_start=True, solid=0.01)
    tube(f"Cuff_{sx}", [(sx * .327, -.01, .835, .045), (sx * .331, -.01, .81, .044), (sx * .334, -.01, .79, .043)],
         FABRIC, n=64, solid=0.008)

if VARIANT == "long":
    # shirt collar: stand + fall with points
    tube("Collar_stand", [(0, .004, 1.43, .083), (0, .004, 1.465, .08), (0, .004, 1.495, .077)], FABRIC, n=96,
         solid=0.006)
    g = math.radians(14)
    angs = np.linspace(-math.pi / 2 + g, 3 * math.pi / 2 - g, 120)
    rows = []
    for (zt, dr, drop, out) in [(1.50, .083, 0, 0), (1.485, .097, .01, .005), (1.455, .108, .03, .012),
                                (1.44, .112, .038, .016)]:
        r = []
        for k, a in enumerate(angs):
            u = k / (len(angs) - 1)
            f = max(0.0, 1 - min(u, 1 - u) / 0.14) ** 2
            rr = dr + out * f
            r.append((rr * math.cos(a), .004 + rr * 1.02 * math.sin(a), zt - drop * f))
        rows += r
    add_obj("Collar_fall", rows, grid_faces(4, len(angs), closed=False), FABRIC, solid=0.006, sub=2, offset=0)
else:
    # funnel collar with two snaps, hood worn up
    funnel = loft_body("Collar_funnel", [(1.415, .10, .085, .09), (1.46, .095, .095, .10), (1.535, .10, .108, .105)],
                       1.415, 1.535, FABRIC, n=128, e=2.2, step=0.004, q_h=0.06, q_amp=0.006, solid=0.016, sigma=0.01)
    for i, z in enumerate([1.455, 1.50]):
        ellipsoid(f"Collar_snap_{i}", (0, -funnel(z)[1] - 0.006, z), (.01, .004, .01), SNAP)
    c, rad = np.array([0, .012, 1.59]), np.array([.112, .135, .148])
    a0 = math.radians(50)
    al = np.linspace(a0, math.pi, 64)
    be = np.linspace(0, 2 * np.pi, 112, endpoint=False)
    verts, keep = [], []
    for a in al:
        for b in be:
            d = np.array([math.sin(a) * math.cos(b), -math.cos(a), math.sin(a) * math.sin(b)])
            verts.append(c + d * rad)
            keep.append(d[2] > -0.72)
    faces = [f for f in grid_faces(len(al), len(be)) if all(keep[v] for v in f)]
    add_obj("Hood", verts, faces, FABRIC, solid=0.025, sub=2)
    seam = [tuple(c + np.array([0, -math.cos(a), math.sin(a)]) * rad) + (.0035,) for a in np.linspace(a0, 2.6, 8)]
    tube("Hood_seam", seam, FABRIC, n=12)

# ---------------------------------------------------------------- studio
bpy.ops.mesh.primitive_plane_add(size=12)
floor = bpy.context.active_object
floor.is_shadow_catcher = True

world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.8, 0.82, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22


def area_light(name, loc, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    ob = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


area_light("Key", (-2.6, -3.6, 3.4), 420, 3.0)
area_light("Fill", (3.2, -2.8, 1.6), 150, 3.0)
area_light("Rim", (0.5, 3.8, 3.2), 260, 2.5)

cd = bpy.data.cameras.new("Cam")
cd.lens = 100
cd.sensor_fit = "VERTICAL"
cd.sensor_height = 36
cam = bpy.data.objects.new("Cam", cd)
scene.collection.objects.link(cam)
cam.location = (0, -5.4, 0.92)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = 1000
scene.render.resolution_y = 1400
scene.render.resolution_percentage = SCALE
# Standard keeps the swatch colours saturated (AgX turns scarlet pink)
scene.view_settings.view_transform = "Standard"
scene.view_settings.exposure = {"short": -0.4, "long": -0.85}[VARIANT]
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(os.path.join(OUT, f"{VARIANT}.blend")))
for view, rz in [("front", 0), ("side", 90), ("back", 180)]:
    RIG.rotation_euler = (0, 0, math.radians(rz))
    scene.render.filepath = os.path.abspath(os.path.join(OUT, f"{VARIANT}_{view}.png"))
    bpy.ops.render.render(write_still=True)
