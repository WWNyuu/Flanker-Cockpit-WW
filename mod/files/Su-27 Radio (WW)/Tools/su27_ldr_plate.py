# Su-27 Radio (WW) - data loader plate (ВВОД ДАННЫХ), build + export script (v14)
# =============================================================================
# For Blender 4.2 LTS with ED's official EDM exporter (io_scene_edm) enabled.
# Same routine as the F-15C SIT plate script:
#   1. File > New > General  (an empty file: this script DELETES everything in
#      the current scene, because the exporter exports the whole scene)
#   2. Scripting tab > New > paste this script > Run Script
#   3. Window > Toggle System Console shows what it did. Read the
#      "ANIMATION" lines: they say whether the knob and button animations got
#      their DCS arguments.
#
# It builds the plate on top of ED's blank cover plate on the right console
# wall (beside the pilot's right hip), position read from ED's own
# Cockpit_SU-27.EDM:
#   * LDR_PLATE                 the plate, 165 x 71 x 2 mm, chamfered edges
#   * LDR_SCREW_1..4            screw heads
#   * LDR_SEL (+ LDR_SEL_PIVOT) КАССЕТА selector, turns with argument 801
#   * LDR_BTN (+ LDR_BTN_PIVOT) ЗАГР button, moves in with argument 802
#   * LDR_GUARD                 red guard ring around the button
#   * LDR_WIN_BEZEL             frame of the В РАБОТЕ window
#   * LDR_LAMP_GO / _NOGO       ГОТОВ / ОТКАЗ lamp lenses + LDR_BEZEL_GO / _NOGO
#   * v6: RAD_UKV_KNOB / RAD_KV_KNOB (+ _PIVOT): our КАНАЛ knobs over ED's
#     static ones on the УКВ / КВ radio panel (left console), arguments
#     803 / 804, 20 channels; anchors RAD_C / RAD_B / RAD_R for the window
#     digits; click boxes RAD_UKV_CLICK / RAD_KV_CLICK
#   * v9: RAD_VUKV_KNOB / RAD_VKV_KNOB (+ _PIVOT): ГРОМК (volume) knobs over
#     ED's, arguments 805 / 806; click boxes RAD_VUKV_CLICK / RAD_VKV_CLICK
#   * v8: CRD_CARD: our radio channel card over ED's (right canopy rail),
#     printed texture su27_crd_card.png; anchors CRD_C / CRD_B / CRD_R for
#     the handwriting
#   * v10: the MFD (multifunction display) over ED's HDD, right of the front
#     panel: MFD_BOX (bezel + sides + screen recess; stows with argument
#     840), 20 soft keys MFD_OSB_L1..L5 / B1..B5 / R1..R5 / T1..T5 (pressed
#     with arguments 811..830), MFD_PWR (argument 831), rockers MFD_BRT /
#     MFD_DN; anchors MFD_C / MFD_B / MFD_R for the page; click boxes
#     MFD_OSB_*_CLICK, MFD_PWR_CLICK, MFD_BRT_UP/DN_CLICK, MFD_DN_D/N_CLICK;
#     click boxes KP_* on ED's ЦЕЛИ / ИСТРЕБИТЕЛИ keypad (right console)
#     for typing into the MFD; texture su27_mfd_bezel.png
#   * v13 (Su-33 only): no parts on ED's panels any more. A control unit
#     (POD_BODY) sits on the MFD's top edge (v14; v13: right edge), tilted
#     POD_TILT deg back toward the pilot, as part of the MFD: keypad POD_KEY_* (click boxes KP_*_CLICK),
#     the УКВ / КВ knobs + channel windows (RAD_*, RAD_S size) and the loader
#     plate (LDR_*, PLATE_S size). Texture su33_pod.png (Tools/pod_texture.py)
#   * connectors LDR_C / LDR_B / LDR_R: anchors of the indicator that lights
#     the window digits and the lamps; LDR_SEL_CLICK / LDR_LOAD_CLICK: click
#     boxes
# then exports straight into the mod folder.

import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

# ---------------------------------------------------------------------------
# SETTINGS
# ---------------------------------------------------------------------------
MOD_DIR = os.path.join(os.path.expanduser("~"), "Saved Games", "DCS", "Mods", "tech", "Su-27 Radio (WW)")
# v12: which jet this model is for. "Su-27" (also the J-11A) builds
# SU27_LDR.edm as before. "Su-33" builds SU33_LDR.edm: the same parts at the
# same points, each group (loader plate, radio knobs, keypad click boxes,
# channel card, MFD) moved by SU33_SHIFT and movable live in DCS with
# Su33_fine_tune.lua in the mod folder (arguments FIT_ARGS, +-FIT_RANGE m).
AIRCRAFT = "Su-27"
# metres in the DCS cockpit frame: (forward, up, right). Copy the numbers the
# log Saved Games\DCS\Logs\su27radio_fit.log prints after tuning.
SU33_SHIFT = {
    "LDR": (0.0, 0.0, 0.0),        # loader plate (ВВОД ДАННЫХ)
    "RAD": (0.0401, 0.0018, 0.0116),   # test 10: УКВ / КВ knobs + digits 40 mm forward, 12 mm inboard on the panel
    "KP":  (0.0985, 0.0017, -0.0391),  # test 15: keypad click boxes (test 13/14 - half a key = 12.5 mm left)
    "CRD": (0.0, 0.0, 0.0),        # radio channel card
    "MFD": (-0.0326, 0.0088, -0.0136),  # test 11: MFD (test 10 + 10 mm toward the pilot, 8 mm up)
}
# v13: in the Su-33 the loader, radio and keypad sit on the side unit and move
# with the MFD (its SU33_SHIFT and its Su33_fine_tune.lua line); LDR / RAD /
# KP shifts no longer do anything there.
FIT_ARGS = {"LDR": 870, "RAD": 873, "KP": 876, "CRD": 879, "MFD": 882}   # forward, up, right = arg, +1, +2
FIT_RANGE = 0.30                   # must match Cockpit/Scripts/LDR/fit_device.lua
EDM_NAME = "SU33_LDR" if AIRCRAFT == "Su-33" else "SU27_LDR"   # mainpanel_init.lua picks it by jet
TEXTURE = "su27_ldr_plate.png"     # in MOD_DIR\Textures (made with the mod, not by this script)

ARG_SEL = 801                      # must match clickabledata.lua / ldr_config.lua
ARG_BTN = 802
ARG_UKV = 803                      # УКВ (R-800, SRS radio 1) КАНАЛ knob
ARG_KV = 804                       # КВ (R-864, SRS radio 2) КАНАЛ knob
ARG_VOL_UKV = 805                  # v9: УКВ ГРОМК (volume) knob
ARG_VOL_KV = 806                   # v9: КВ ГРОМК knob
RAD_TEXTURE = "su27_rad_knobs.png"
CRD_TEXTURE = "su27_crd_card.png"
MFD_TEXTURE = "su27_mfd_bezel.png"  # v10: made with the mod (Tools/mfd_texture.py)

# v10: the MFD. Frame on ED's HDD screen glass (Cockpit_SU-27.EDM): a point
# on it and its axes as the pilot sees it (right, up, normal toward the
# pilot). The unit's positions below are mm in this frame.
MFD_ORIGIN = (0.75440, -0.33460, 0.25770)
MFD_RIGHT  = (-0.10820, 0.00000, 0.99410)
MFD_UP     = (0.30430, 0.95200, 0.03310)
MFD_NORMAL = (-0.94640, 0.30610, -0.10300)
MFD_A0, MFD_A1, MFD_B0, MFD_B1 = -104.0, 96.0, -106.0, 84.0   # bezel outline (200 x 190 mm)
MFD_CH = 30.0                     # top-right corner cut (clears the coaming)
MFD_HF, MFD_HB = 72.0, -40.0      # front face / back of the sides, mm in front of ED's HDD glass
MFD_SCR = (-80.0, 72.0, -83.0, 61.0)   # screen a0, a1, b0, b1 (152 x 144 mm)
MFD_SCR_D = 2.0                   # screen 2 mm behind the bezel face
MFD_PXMM, MFD_TEX = 10.0, 2048    # face art: 10 px per mm, texture 2048 x 2048
MFD_SW = {"paint": 0, "cap": 200, "capside": 400, "screen": 600, "metal": 800, "rocker": 1000, "edge": 1200}
ARG_OSB0 = 811                    # soft keys: L1-L5 811-815, B1-B5 816-820, R1-R5 821-825, T1-T5 826-830
ARG_PWR = 831
ARG_STOW = 840                    # 0 = in place, 1 = folded away (ED's HDD shows again)
# ED's keypad (right console, ЦЕЛИ 1-10 / ВВОД / СБРОС, ИСТРЕБИТЕЛИ 1-4 / ГР):
# key-top centres and the panel's axes, from Cockpit_SU-27.EDM
KP_RIGHT  = (-0.03160, 0.25700, 0.96590)
KP_FWD    = (0.99250, 0.12210, 0.00000)
KP_NORMAL = (-0.11800, 0.95870, -0.25890)
KP_KEYS = {
    "C1": (0.58690, -0.69330, 0.32560), "C2": (0.58400, -0.68710, 0.34970), "C3": (0.58320, -0.68070, 0.37390),
    "C4": (0.58210, -0.67430, 0.39800), "C5": (0.58160, -0.66790, 0.42190), "C6": (0.56280, -0.69620, 0.32560),
    "C7": (0.56190, -0.68990, 0.34940), "C8": (0.56110, -0.68340, 0.37390), "C9": (0.56030, -0.67700, 0.39800),
    "C10": (0.55970, -0.67050, 0.42220), "ENT": (0.58080, -0.66130, 0.44660), "RST": (0.55870, -0.66400, 0.44660),
    "F1": (0.52550, -0.69870, 0.33260), "F2": (0.52470, -0.69290, 0.35440), "F3": (0.52400, -0.68710, 0.37610),
    "F4": (0.52330, -0.68130, 0.39790), "GR": (0.52270, -0.67480, 0.42210),
}

# v8: ED's radio channel card (КАНАЛЫ РАДИОСВЯЗИ, right canopy rail), from
# Cockpit_SU-27.EDM: its centre and axes (right = aft, tilted ~8 deg; normal
# toward the pilot). Ours: 148.4 x 52.6 mm, 0.4 mm in front of it.
CRD_CENTRE = (-0.04800, -0.28319, 0.35997)
CRD_RIGHT  = (-0.99050, 0.13680, -0.01300)
CRD_UP     = (0.13710, 0.99060, -0.00120)
CRD_NORMAL = (0.01270, -0.00290, -0.99990)
CRD_W, CRD_H = 148.4, 52.6       # mm
CRD_GAP = 0.4                    # mm in front of ED's card
CRD_PXMM = 13.6                  # card texture px per mm (2048 x 1024)

# v6: ED's УКВ / КВ radio panel (left console), from Cockpit_SU-27.EDM: a
# point on its face and its axes as the pilot reads it (right = inboard,
# up = forward, normal = out of the panel). Positions below are mm in this
# frame.
RAD_ORIGIN = (0.18830, -0.72772, -0.40495)
RAD_RIGHT  = (0.03154, -0.25689, 0.96593)
RAD_UP     = (0.99255, 0.12187, 0.00000)
RAD_NORMAL = (-0.11772, 0.95873, 0.25882)
RAD_KNOBS = {"UKV": (41.85, -19.95), "KV": (-30.05, -19.90)}   # ED's КАНАЛ knob centres
# ED's knob: skirt r 13.7 mm (h 0-4), body r 10.4 mm up to h 22.1, pointer
# fin out to r 15.2 mm (h 10-22). Ours must hide it in every position:
RAD_KNOB_R = 15.8                  # mm
# v9: ED's ГРОМК knobs (static): cylinder r 7.48 mm, h 2.7 - 14.3 mm, a bar
# with a white line across the top. Ours covers it: r 7.8, top 14.7 + bar.
RAD_VOL = {"VUKV": (84.42, 12.45), "VKV": (-3.18, 10.82)}
RAD_VOL_R = 7.8
RAD_VOL_H = 14.7
RAD_VOL_ANG0 = 225.0               # pointer at volume 0 (7:30), deg from panel right, anticlockwise
RAD_VOL_SWEEP = 270.0              # to volume 1 (4:30), clockwise
RAD_KNOB_H = 22.6                  # mm (top face)
RAD_WIN_Y = 14.02                  # window digit cells: centre height (mm)
RAD_WIN_H = -1.48                  # ED's window glass, mm below the panel face
RAD_ANCHOR_X = 5.79                # midway between the two windows

# ED's blank cover plate (Cockpit_SU-27.EDM, the screwed cover below the
# two-switch panel on the right console wall). v2: exact values from the
# cover's own face - its centre, its right edge direction (from its texture
# mapping) and its face normal. v1 estimated the axes from the corners and
# came out turned ~1.7 deg in the plane of the wall.
# DCS cockpit axes: X forward, Y up, Z right; origin = pilot's eye point.
COVER_CENTRE = (-0.21928, -0.71473, 0.54548)
COVER_RIGHT  = (-0.99610, -0.07240, 0.04950)   # plate right, as the pilot sees it (aft)
COVER_NORMAL = (-0.08600, 0.70200, -0.70700)   # out of the wall, toward the pilot

LIFT = 0.0006                      # our plate's back this far off ED's cover (no flicker)
PLATE_T = 0.0020                   # plate thickness
SHIFT = (0.0, 0.0)                 # move the whole plate (m): right, up - if it sits off the cover
GLOW_H = 0.0016                    # indicator plane (lamp glow, window digits) above the plate face

TEST_HEADLESS = False              # (set by the test harness, leave False)

# v14 (Su-33): the control unit on the MFD's top edge (mm). Its face starts at
# the MFD's front face on the bezel's top edge (left of the corner cut) and
# leans POD_TILT deg back toward the pilot. Left: keypad; right: radio over
# the loader plate. (v13 hung it on the right edge: it clipped into the
# Su-33's canopy.)
POD = (AIRCRAFT == "Su-33")
POD_W, POD_H, POD_D = 170.0, 88.0, 20.0
POD_TILT = 10.0
POD_A0 = MFD_A0                    # MFD frame a of its left edge (its right edge = the corner cut)
POD_TEXTURE = "su33_pod.png"       # Tools/pod_texture.py: face art 10 px/mm from (0, 0), key tops, swatches
POD_PXMM, POD_TEX = 10.0, 2048
POD_SW = {"paint": 0, "capside": 200, "black": 400, "edge": 600}
POD_KEYS = [("C1", 841), ("C2", 842), ("C3", 843), ("C4", 844), ("C5", 845), ("C6", 846), ("C7", 847),
            ("C8", 848), ("C9", 849), ("RST", 852), ("C10", 850), ("ENT", 851)]   # 3 x 4, argument = clickabledata
POD_KEY_X = (15.0, 37.0, 59.0)
POD_KEY_Y = (20.0, 37.0, 54.0, 71.0)
POD_KEY_W, POD_KEY_H, POD_KEY_Z = 18.0, 11.0, 4.0
POD_KEY_ATLAS = (0, 1000)          # key tops in the texture: x + col * 200, y + row * 130 (px)
POD_RAD_X, POD_RAD_Y = 121.0, 24.0     # centre of the radio block (pod mm from the left / top)
POD_LDR_X, POD_LDR_Y = 121.0, 66.6     # centre of the loader plate
PLATE_S = 0.5 if POD else 1.0      # loader plate size (0.5: 82.5 x 35.5 mm)
RAD_S = 0.56 if POD else 1.0       # radio block size (the Su-27 panel layout, 0.56: 77 x 37 mm)
RAD_LC = (23.2, -2.9)              # radio layout centre, Su-27 panel mm
if POD:
    _n = Vector(MFD_NORMAL).normalized()
    _r = Vector(MFD_RIGHT); _r = (_r - _n * _r.dot(_n)).normalized()
    _u = _n.cross(_r).normalized()
    _t = math.radians(POD_TILT)
    POD_R = _r
    POD_U = (_u * math.cos(_t) + _n * math.sin(_t)).normalized()
    POD_N = (-_u * math.sin(_t) + _n * math.cos(_t)).normalized()
    # face's bottom-left corner = on the MFD's top edge, at its front face
    _bl = Vector(MFD_ORIGIN) + _r * (POD_A0 / 1000) + _u * (MFD_B1 / 1000) + _n * (MFD_HF / 1000)
    POD_O = _bl + POD_U * (POD_H / 1000)
    def PODP(x_mm, y_mm, h_mm=0.0):
        """control unit point: mm from its face's left / top edge, h mm out of the face"""
        return POD_O + POD_R * (x_mm / 1000) - POD_U * (y_mm / 1000) + POD_N * (h_mm / 1000)
    # the loader plate and the radio block on the unit's face
    COVER_CENTRE = tuple(PODP(POD_LDR_X, POD_LDR_Y))
    COVER_RIGHT = tuple(POD_R)
    COVER_NORMAL = tuple(POD_N)
    RAD_RIGHT, RAD_UP, RAD_NORMAL = tuple(POD_R), tuple(POD_U), tuple(POD_N)
    RAD_ORIGIN = tuple(PODP(POD_RAD_X, POD_RAD_Y) - (POD_R * RAD_LC[0] + POD_U * RAD_LC[1]) * (RAD_S / 1000))
    RAD_WIN_H = 0.3                # digits just above the face (black window printed + raised frame)

# --- layout, mm on the plate (x from the left edge, y from the top edge) ---
PW, PH = 165.0, 71.0
SCREWS = [(5.0, 5.0), (160.0, 5.0), (5.0, 66.0), (160.0, 66.0)]
SCREW_R = 2.6
KNOB = (34.0, 41.0); KNOB_R = 10.0
KNOB_ANG0 = 210.0; KNOB_STEP = -40.0; KNOB_STEPS = 7          # МИС, 1..6
WIN = (96.0, 27.0); WIN_W, WIN_H = 30.0, 16.0
BTN = (99.0, 55.5); BTN_GUARD_R = 6.3; BTN_R = 4.3
LAMP_GO = (145.0, 25.0); LAMP_NOGO = (145.0, 48.5); LAMP_R = 4.2; LAMP_BEZEL_R = 5.6
# texture atlas (2048 x 1024): artwork 12 px/mm top-left, swatches below
TEX_W, TEX_H, PXMM = 2048, 1024, 12.0
SW_Y0, SW_Y1 = 872, 1022
SWATCH = {'paint': (0, 190), 'black': (200, 390), 'chrome': (400, 590), 'red': (600, 790),
          'lens_go': (800, 990), 'lens_nogo': (1000, 1190), 'white': (1200, 1390),
          'screw': (1400, 1560), 'pointer': (1580, 2040)}

# ---------------------------------------------------------------------------
# plate frame
# ---------------------------------------------------------------------------
def to_bl(v):
    """DCS cockpit (x fwd, y up, z right) -> Blender for ED's exporter
    (X fwd, Y left, Z up). Same as the F-15C SIT plate script."""
    x, y, z = v
    return Vector((x, -z, y))

# test 11: in the Su-33 the plate lies on the blank panel on the right
# console top, behind the КОНТРОЛЬ НАПРЯЖЕН panel (guessed from screenshots):
# right = aft, face up and a little toward the pilot
W = Vector(COVER_NORMAL).normalized()
U = Vector(COVER_RIGHT)
U = (U - W * U.dot(W)).normalized()                # right, exactly in the wall's plane
V = W.cross(U).normalized()                        # up
CEN = Vector(COVER_CENTRE)
CEN = CEN + U * SHIFT[0] + V * SHIFT[1]

def P(x_mm, y_mm, h=0.0):
    """plate point (mm from the left / top edge), h metres above our plate's back
    (v13: everything PLATE_S times as big, around the plate centre)"""
    s = PLATE_S
    return CEN + U * ((x_mm - PW / 2) * s / 1000) + V * ((PH / 2 - y_mm) * s / 1000) + W * (LIFT + h * s)

def frame_matrix(pos_dcs, scale=1.0):
    """Blender matrix: local X = plate right, Y = plate up, Z = out (plate normal)"""
    u, v, w = to_bl(U), to_bl(V), to_bl(W)
    m = Matrix(((u.x, v.x, w.x, 0), (u.y, v.y, w.y, 0), (u.z, v.z, w.z, 0), (0, 0, 0, 1)))
    m = m @ Matrix.Diagonal((scale, scale, scale, 1))
    m.translation = to_bl(pos_dcs)
    return m

# ---------------------------------------------------------------------------
# clear the scene
# ---------------------------------------------------------------------------
for o in list(bpy.context.scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if "LDR_" in a.name or "RAD_" in a.name:
        bpy.data.actions.remove(a)
coll = bpy.context.scene.collection

# ---------------------------------------------------------------------------
# material (one texture atlas for the whole plate)
# ---------------------------------------------------------------------------
def make_mat(mat_name, texture):
    """EDM Default material with one texture (v6: a function, two materials)"""
    tex_path = os.path.join(MOD_DIR, "Textures", texture)
    img = bpy.data.images.get(texture)
    if img is None:
        if os.path.exists(tex_path):
            img = bpy.data.images.load(tex_path)
        else:
            print("  !! texture not found:", tex_path, "- the model is built, but untextured in Blender")
            img = bpy.data.images.new(texture, 8, 8)
            img.filepath_raw = tex_path
    old = bpy.data.materials.get(mat_name)
    if old:
        bpy.data.materials.remove(old)
    m = bpy.data.materials.new(mat_name)
    m.use_nodes = True
    nt = m.node_tree
    for nd in list(nt.nodes):
        if nd.type != "OUTPUT_MATERIAL":
            nt.nodes.remove(nd)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.location = (-300, 100)
    try:
        from materials.material_default import DefaultMaterial
        from materials.materials import build_material_descriptions
        grp = nt.nodes.new(type=DefaultMaterial.node_group_name)
        grp.post_init(build_material_descriptions()[DefaultMaterial.name])
        grp.location = (100, 100)
        nt.links.new(tex.outputs["Color"], grp.inputs["Base Color"])
        print("EDM Default material created:", mat_name)
        return m, True
    except Exception as e:
        print("  (no EDM exporter material:", repr(e), ") - using a plain material")
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.6
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return m, False

mat, edm_ok = make_mat("LDR_MAT", TEXTURE)
rad_mat, _ = make_mat("RAD_MAT", RAD_TEXTURE)
crd_mat, _ = make_mat("CRD_MAT", CRD_TEXTURE)
mfd_mat, _ = make_mat("MFD_MAT", MFD_TEXTURE)

# ---------------------------------------------------------------------------
# mesh helpers (local mm coordinates: x right, y up, z out; built around the
# object's origin, then placed with frame_matrix)
# ---------------------------------------------------------------------------
def uv_art(x_mm, y_mm):
    """artwork point (plate mm, y from top) -> UV"""
    return (x_mm * PXMM / TEX_W, 1.0 - y_mm * PXMM / TEX_H)

def uv_sw(name, s=0.5, t=0.5):
    x0, x1 = SWATCH[name]
    return ((x0 + 4 + s * (x1 - x0 - 8)) / TEX_W, 1.0 - (SW_Y0 + 4 + t * (SW_Y1 - SW_Y0 - 8)) / TEX_H)

GS = 1.0                      # v13: size of what MB builds next (PLATE_S / RAD_S)
class MB:
    """small bmesh builder with one UV layer"""
    def __init__(self, material=None, s=None):
        self.material = material
        self.s = GS if s is None else s
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
    def face(self, pts, uvs):
        vs = [self.bm.verts.new(Vector(p) * (self.s / 1000.0)) for p in pts]
        f = self.bm.faces.new(vs)
        for loop, uv in zip(f.loops, uvs):
            loop[self.uv].uv = uv
        return f
    def done(self, name, matrix, parent=None):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-7)
        self.bm.normal_update()
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        for p in me.polygons:
            p.use_smooth = False
        ob = bpy.data.objects.new(name, me)
        coll.objects.link(ob)
        me.materials.append(self.material or mat)
        if parent:
            ob.parent = parent
            ob.matrix_parent_inverse = Matrix.Identity(4)
            ob.matrix_basis = Matrix.Identity(4)
        else:
            ob.matrix_world = matrix
        return ob

def cyl(mb, r, z0, z1, segs, side_sw, top=None, dome=0.0, bottom=False, r_top=None):
    """cylinder around local (0,0); top: None, ('sw', name) flat swatch, or
    ('disc', name) the swatch square mapped across the top"""
    r_top = r if r_top is None else r_top
    ring0 = [(r * math.cos(2 * math.pi * i / segs), r * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    ring1 = [(r_top * math.cos(2 * math.pi * i / segs), r_top * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        a, b = ring0[i], ring0[j]
        c, d = ring1[j], ring1[i]
        mb.face([(a[0], a[1], z0), (b[0], b[1], z0), (c[0], c[1], z1), (d[0], d[1], z1)],
                [uv_sw(side_sw, i / segs, 1), uv_sw(side_sw, j / segs, 1), uv_sw(side_sw, j / segs, 0), uv_sw(side_sw, i / segs, 0)])
    if top:
        kind, sw = top
        def tuv(x, y):
            if kind == 'disc':
                return uv_sw(sw, 0.5 + x / (2 * r_top), 0.5 - y / (2 * r_top))
            return uv_sw(sw)
        if dome > 0:
            # one ring of faces up to the dome, then a fan
            rr = r_top * 0.65
            ring2 = [(rr * math.cos(2 * math.pi * i / segs), rr * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
            for i in range(segs):
                j = (i + 1) % segs
                mb.face([(ring1[i][0], ring1[i][1], z1), (ring1[j][0], ring1[j][1], z1),
                         (ring2[j][0], ring2[j][1], z1 + dome * 0.7), (ring2[i][0], ring2[i][1], z1 + dome * 0.7)],
                        [tuv(*ring1[i]), tuv(*ring1[j]), tuv(*ring2[j]), tuv(*ring2[i])])
            for i in range(segs):
                j = (i + 1) % segs
                mb.face([(ring2[i][0], ring2[i][1], z1 + dome * 0.7), (ring2[j][0], ring2[j][1], z1 + dome * 0.7), (0, 0, z1 + dome)],
                        [tuv(*ring2[i]), tuv(*ring2[j]), tuv(0, 0)])
        else:
            mb.face([(p[0], p[1], z1) for p in ring1], [tuv(*p) for p in ring1])
    if bottom:
        mb.face([(p[0], p[1], z0) for p in reversed(ring0)], [uv_sw(side_sw)] * segs)

def annulus(mb, r_in, r_out, z0, z1, segs, sw):
    """ring with height (guard, bezel): outer wall, top, inner wall"""
    oi = [(r_out * math.cos(2 * math.pi * i / segs), r_out * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    ii = [(r_in * math.cos(2 * math.pi * i / segs), r_in * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        mb.face([(*oi[i], z0), (*oi[j], z0), (*oi[j], z1), (*oi[i], z1)],
                [uv_sw(sw, i / segs, 1), uv_sw(sw, j / segs, 1), uv_sw(sw, j / segs, 0), uv_sw(sw, i / segs, 0)])
        mb.face([(*oi[i], z1), (*oi[j], z1), (*ii[j], z1), (*ii[i], z1)],
                [uv_sw(sw, i / segs, .05), uv_sw(sw, j / segs, .05), uv_sw(sw, j / segs, .15), uv_sw(sw, i / segs, .15)])
        mb.face([(*ii[i], z1), (*ii[j], z1), (*ii[j], z0), (*ii[i], z0)],
                [uv_sw(sw, i / segs, 0), uv_sw(sw, j / segs, 0), uv_sw(sw, j / segs, 1), uv_sw(sw, i / segs, 1)])

def box(mb, x0, x1, y0, y1, z0, z1, top_uv, side_sw):
    """box; top_uv: function (x, y) -> uv for the top face"""
    c = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    mb.face([(*p, z1) for p in c], [top_uv(*p) for p in c])
    for i in range(4):
        a, b = c[i], c[(i + 1) % 4]
        mb.face([(*a, z0), (*b, z0), (*b, z1), (*a, z1)], [uv_sw(side_sw, 0, 1), uv_sw(side_sw, 1, 1), uv_sw(side_sw, 1, 0), uv_sw(side_sw, 0, 0)])

# ---------------------------------------------------------------------------
# the plate: chamfered slab; the face carries the artwork
# ---------------------------------------------------------------------------
T = PLATE_T * 1000            # mm
CH = 0.6                      # chamfer (mm)
GS = PLATE_S
mb = MB()
hw, hh = PW / 2, PH / 2
def art_local(x, y):          # local (centre origin, y up) -> artwork uv
    return uv_art(x + hw, hh - y)
face = [(-hw + CH, -hh + CH), (hw - CH, -hh + CH), (hw - CH, hh - CH), (-hw + CH, hh - CH)]
mid = [(-hw, -hh), (hw, -hh), (hw, hh), (-hw, hh)]
mb.face([(*p, T) for p in face], [art_local(*p) for p in face])
for i in range(4):
    a, b = face[i], face[(i + 1) % 4]
    c, d = mid[(i + 1) % 4], mid[i]
    mb.face([(*d, T - CH), (*c, T - CH), (*b, T), (*a, T)], [art_local(*d), art_local(*c), art_local(*b), art_local(*a)])
    mb.face([(*d, 0), (*c, 0), (*c, T - CH), (*d, T - CH)], [uv_sw('paint', 0, 1), uv_sw('paint', 1, 1), uv_sw('paint', 1, 0), uv_sw('paint', 0, 0)])
plate = mb.done("LDR_PLATE", frame_matrix(P(PW / 2, PH / 2, 0)))
FACE_H = PLATE_T              # plate face height (m above the plate back)

# screws
for k, (sx, sy) in enumerate(SCREWS, 1):
    mb = MB()
    cyl(mb, SCREW_R, 0, 0.5, 16, 'chrome', top=('disc', 'screw'), dome=0.5)
    mb.done(f"LDR_SCREW_{k}", frame_matrix(P(sx, sy, FACE_H)))

# window bezel (raised frame around the dark window)
mb = MB()
bw = 1.6
x0, x1, y0, y1 = -WIN_W / 2, WIN_W / 2, -WIN_H / 2, WIN_H / 2
for (a0, a1, b0, b1) in [(x0 - bw, x1 + bw, y1, y1 + bw), (x0 - bw, x1 + bw, y0 - bw, y0),
                         (x0 - bw, x0, y0, y1), (x1, x1 + bw, y0, y1)]:
    box(mb, a0, a1, b0, b1, 0, 1.4, lambda x, y: uv_sw('black'), 'black')
mb.done("LDR_WIN_BEZEL", frame_matrix(P(WIN[0], WIN[1], FACE_H)))

# lamps: chrome bezel + tinted lens (the indicator lights them)
for name, pos, lens in (("GO", LAMP_GO, 'lens_go'), ("NOGO", LAMP_NOGO, 'lens_nogo')):
    mb = MB()
    annulus(mb, LAMP_R, LAMP_BEZEL_R, 0, 1.6, 24, 'chrome')
    mb.done(f"LDR_BEZEL_{name}", frame_matrix(P(pos[0], pos[1], FACE_H)))
    mb = MB()
    cyl(mb, LAMP_R, 0, 1.0, 24, lens, top=('sw', lens), dome=0.5)
    mb.done(f"LDR_LAMP_{name}", frame_matrix(P(pos[0], pos[1], FACE_H)))

# guard ring around the button
mb = MB()
annulus(mb, BTN_R + 0.5, BTN_GUARD_R, 0, 2.6, 28, 'red')
mb.done("LDR_GUARD", frame_matrix(P(BTN[0], BTN[1], FACE_H)))

# ---------------------------------------------------------------------------
# moving parts: a static pivot (empty) + the animated part as its child
# ---------------------------------------------------------------------------
def pivot(name, pos):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.01
    coll.objects.link(e)
    e.matrix_world = frame_matrix(pos)
    return e

# selector knob: skirt + pointer bar (pointer along local +X at rotation 0)
sel_pivot = pivot("LDR_SEL_PIVOT", P(KNOB[0], KNOB[1], FACE_H))
mb = MB()
cyl(mb, KNOB_R, 0, 1.2, 40, 'black', r_top=KNOB_R)
cyl(mb, KNOB_R, 1.2, 4.5, 40, 'black', top=('sw', 'black'), r_top=KNOB_R * 0.93)
L, Wd = KNOB_R * 1.12, 3.4
box(mb, -L, L, -Wd, Wd, 4.5, 10.0, lambda x, y: uv_sw('pointer', (x + L) / (2 * L), 0.5 - y / (2 * Wd) * 0.9), 'black')
knob = mb.done("LDR_SEL", None, parent=sel_pivot)

# button cap
btn_pivot = pivot("LDR_BTN_PIVOT", P(BTN[0], BTN[1], FACE_H))
mb = MB()
cyl(mb, BTN_R, 0, 3.6, 28, 'black', top=('sw', 'black'), dome=0.9)
button = mb.done("LDR_BTN", None, parent=btn_pivot)
GS = 1.0

# ---------------------------------------------------------------------------
# v6: КАНАЛ knobs on ED's УКВ / КВ radio panel
# ---------------------------------------------------------------------------
RN_ = Vector(RAD_NORMAL).normalized()
RR_ = Vector(RAD_RIGHT)
RR_ = (RR_ - RN_ * RR_.dot(RN_)).normalized()
RU_ = RN_.cross(RR_).normalized()
RO_ = Vector(RAD_ORIGIN)

def RP(x_mm, y_mm, h_mm=0.0):
    s = RAD_S / 1000              # v13: RAD_S times as big (the side unit)
    return RO_ + RR_ * (x_mm * s) + RU_ * (y_mm * s) + RN_ * (h_mm * s)

def rad_matrix(pos_dcs, scale=1.0):
    u, v, w = to_bl(RR_), to_bl(RU_), to_bl(RN_)
    m = Matrix(((u.x, v.x, w.x, 0), (u.y, v.y, w.y, 0), (u.z, v.z, w.z, 0), (0, 0, 0, 1)))
    m = m @ Matrix.Diagonal((scale, scale, scale, 1))
    m.translation = to_bl(pos_dcs)
    return m

RK = {"knurl": (0, 511, 0, 255), "black": (0, 255, 256, 511), "white": (256, 511, 256, 511), "top": (512, 1023, 0, 511)}
def uv_rk(region, s=0.5, t=0.5):
    x0, x1, y0, y1 = RK[region]
    return ((x0 + 3 + s * (x1 - x0 - 6)) / 1024.0, 1.0 - (y0 + 3 + t * (y1 - y0 - 6)) / 512.0)

def radio_knob(name, pivot_obj):
    """barrel knob, knurled, pointer on top along local +X at rotation 0"""
    mb = MB(rad_mat)
    R0, H0, CH = RAD_KNOB_R, RAD_KNOB_H, 1.0
    segs = 48
    ring = [(R0 * math.cos(2 * math.pi * i / segs), R0 * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    rt = R0 - CH
    ring_t = [(rt * math.cos(2 * math.pi * i / segs), rt * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        a, b = ring[i], ring[j]
        mb.face([(a[0], a[1], 0.3), (b[0], b[1], 0.3), (b[0], b[1], H0 - CH), (a[0], a[1], H0 - CH)],
                [uv_rk("knurl", 0, 1), uv_rk("knurl", 1, 1), uv_rk("knurl", 1, 0), uv_rk("knurl", 0, 0)])
        c, d = ring_t[j], ring_t[i]
        mb.face([(a[0], a[1], H0 - CH), (b[0], b[1], H0 - CH), (c[0], c[1], H0), (d[0], d[1], H0)],
                [uv_rk("black")] * 4)
    def tuv(x, y):
        return uv_rk("top", 0.5 + x / (2 * rt), 0.5 - y / (2 * rt))
    mb.face([(p[0], p[1], H0) for p in ring_t], [tuv(*p) for p in ring_t])
    return mb.done(name, None, parent=pivot_obj)

def volume_knob(name, pivot_obj):
    """v9: small ГРОМК knob: black cylinder, a bar across the top with the
    white pointer line and arrow along local +X at rotation 0"""
    mb = MB(rad_mat)
    R0, H0, CH = RAD_VOL_R, RAD_VOL_H, 0.6
    BW, BL, BH = 1.9, RAD_VOL_R - 0.5, 2.0          # bar half-width, half-length, height (mm)
    segs = 36
    rt = R0 - CH
    ring = [(R0 * math.cos(2 * math.pi * i / segs), R0 * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    ring_t = [(rt * math.cos(2 * math.pi * i / segs), rt * math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for i in range(segs):
        j = (i + 1) % segs
        a, b = ring[i], ring[j]
        mb.face([(a[0], a[1], 0.3), (b[0], b[1], 0.3), (b[0], b[1], H0 - CH), (a[0], a[1], H0 - CH)],
                [uv_rk("knurl", 0.2, 1), uv_rk("knurl", 0.8, 1), uv_rk("knurl", 0.8, 0), uv_rk("knurl", 0.2, 0)])
        c, d = ring_t[j], ring_t[i]
        mb.face([(a[0], a[1], H0 - CH), (b[0], b[1], H0 - CH), (c[0], c[1], H0), (d[0], d[1], H0)],
                [uv_rk("black")] * 4)
    def tuv(x, y):
        return uv_rk("top", 0.5 + x / (2 * BL), 0.5 - y / (2 * BL))
    mb.face([(p[0], p[1], H0) for p in ring_t], [uv_rk("black")] * len(ring_t))
    # the bar: top carries the pointer (texture "top" squeezed onto it), sides black
    zt = H0 + BH
    mb.face([(-BL, -BW, zt), (BL, -BW, zt), (BL, BW, zt), (-BL, BW, zt)], [tuv(-BL, -BW), tuv(BL, -BW), tuv(BL, BW), tuv(-BL, BW)])
    for (x0, y0), (x1, y1) in (((-BL, -BW), (BL, -BW)), ((BL, -BW), (BL, BW)), ((BL, BW), (-BL, BW)), ((-BL, BW), (-BL, -BW))):
        mb.face([(x0, y0, H0 - 0.05), (x1, y1, H0 - 0.05), (x1, y1, zt), (x0, y0, zt)], [uv_rk("black")] * 4)
    return mb.done(name, None, parent=pivot_obj)

def rad_pivot(name, pos):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.01
    coll.objects.link(e)
    e.matrix_world = rad_matrix(pos)
    return e

GS = RAD_S
rad_knobs = {}
for key, (kx, ky) in RAD_KNOBS.items():
    pv = rad_pivot(f"RAD_{key}_PIVOT", RP(kx, ky, 0.0))
    rad_knobs[key] = radio_knob(f"RAD_{key}_KNOB", pv)

vol_knobs = {}
for key, (kx, ky) in RAD_VOL.items():
    pv = rad_pivot(f"RAD_{key}_PIVOT", RP(kx, ky, 0.0))
    vol_knobs[key] = volume_knob(f"RAD_{key}_KNOB", pv)

# v13 (side unit): raised frames round the two channel windows (the window
# itself is printed black on the unit's face); digit cells as rad_page.lua
RAD_WINS = {"K": (-37.11, -23.27), "U": (34.86, 48.69)}
if POD:
    for wk, (c1, c2) in RAD_WINS.items():
        cx, cy = (c1 + c2) / 2, RAD_WIN_Y
        hw_, hh_, bw_ = 13.8 + 0.4, 9.6 + 0.4, 2.0
        mb = MB()
        for (a0, a1, b0, b1) in [(-hw_ - bw_, hw_ + bw_, hh_, hh_ + bw_), (-hw_ - bw_, hw_ + bw_, -hh_ - bw_, -hh_),
                                 (-hw_ - bw_, -hw_, -hh_, hh_), (hw_, hw_ + bw_, -hh_, hh_)]:
            box(mb, a0, a1, b0, b1, 0, 1.8, lambda x, y: uv_sw('black'), 'black')
        mb.done(f"RAD_WIN_{wk}", rad_matrix(RP(cx, cy, 0.0)))
GS = 1.0

# ---------------------------------------------------------------------------
# v8: radio channel card
# ---------------------------------------------------------------------------
CN_ = Vector(CRD_NORMAL).normalized()
CR_ = Vector(CRD_RIGHT)
CR_ = (CR_ - CN_ * CR_.dot(CN_)).normalized()
CU_ = CN_.cross(CR_).normalized()
CC_ = Vector(CRD_CENTRE)

def CP(x_mm, y_mm, h_mm=0.0):
    """card point: mm from the card's left / top edge, h mm toward the pilot"""
    return CC_ + CR_ * ((x_mm - CRD_W / 2) / 1000) + CU_ * ((CRD_H / 2 - y_mm) / 1000) + CN_ * (h_mm / 1000)

mb = MB(crd_mat)
corners = [(0, CRD_H), (CRD_W, CRD_H), (CRD_W, 0), (0, 0)]      # BL, BR, TR, TL (counter-clockwise from the pilot)
mb.bm.verts.ensure_lookup_table()
vs = [mb.bm.verts.new(to_bl(CP(x, y, CRD_GAP))) for x, y in corners]
f = mb.bm.faces.new(vs)
for loop, (x, y) in zip(f.loops, corners):
    loop[mb.uv].uv = (x * CRD_PXMM / 2048.0, 1.0 - y * CRD_PXMM / 1024.0)
mb.bm.normal_update()
if f.normal.dot(to_bl(CN_)) < 0:
    f.normal_flip()
me = bpy.data.meshes.new("CRD_CARD")
mb.bm.to_mesh(me); mb.bm.free()
card_obj = bpy.data.objects.new("CRD_CARD", me)
coll.objects.link(card_obj)
me.materials.append(crd_mat)


# ---------------------------------------------------------------------------
# v10: the MFD over ED's HDD
# ---------------------------------------------------------------------------
MN_ = Vector(MFD_NORMAL).normalized()
MR_ = Vector(MFD_RIGHT)
MR_ = (MR_ - MN_ * MR_.dot(MN_)).normalized()
MU_ = MN_.cross(MR_).normalized()
MO_ = Vector(MFD_ORIGIN)

def MP(a_mm, b_mm, h_mm=0.0):
    return MO_ + MR_ * (a_mm / 1000) + MU_ * (b_mm / 1000) + MN_ * (h_mm / 1000)

MFD_ROT = Matrix((to_bl(MR_), to_bl(MU_), to_bl(MN_))).transposed()
def mfd_matrix(pos_dcs):
    m = MFD_ROT.to_4x4()
    m.translation = to_bl(pos_dcs)
    return m

# the box's origin: back centre (the unit shrinks into ED's HDD when stowed)
MFD_OA, MFD_OB = (MFD_A0 + MFD_A1) / 2, (MFD_B0 + MFD_B1) / 2
def ML(a, b, h):                  # MFD frame mm -> box-local mm
    return (a - MFD_OA, b - MFD_OB, h - MFD_HB)

def uv_face(a, b):                # face art: bezel x from the left, y from the top, 10 px / mm
    return ((a - MFD_A0) * MFD_PXMM / MFD_TEX, 1.0 - (MFD_B1 - b) * MFD_PXMM / MFD_TEX)

def uv_msw(name, s=0.5, t=0.5):
    x0 = MFD_SW[name]
    return ((x0 + 6 + s * 177) / MFD_TEX, 1.0 - (1926 + t * 107) / MFD_TEX)

mb = MB(mfd_mat)
A0, A1, B0, B1, HF, HB = MFD_A0, MFD_A1, MFD_B0, MFD_B1, MFD_HF, MFD_HB
sa0, sa1, sb0, sb1 = MFD_SCR
cb = A1 - MFD_CH                  # chamfer starts on the top edge
a_ch = cb + (B1 - sb1)            # chamfer crosses b = sb1 here
front = [
    [(A0, B0), (A1, B0), (A1, sb0), (A0, sb0)],                                   # bottom strip
    [(A0, sb0), (sa0, sb0), (sa0, sb1), (A0, sb1)],                               # left strip
    [(sa1, sb0), (A1, sb0), (A1, B1 - MFD_CH), (a_ch, sb1), (sa1, sb1)],          # right strip
    [(A0, sb1), (cb, sb1), (cb, B1), (A0, B1)],                                   # top strip
    [(cb, sb1), (a_ch, sb1), (cb, B1)],                                           # under the corner cut
]
for poly_ in front:
    mb.face([ML(a, b, HF) for a, b in poly_], [uv_face(a, b) for a, b in poly_])
# screen floor (the page is drawn on it) and its walls
sd = HF - MFD_SCR_D
scr = [(sa0, sb0), (sa1, sb0), (sa1, sb1), (sa0, sb1)]
mb.face([ML(a, b, sd) for a, b in scr], [uv_msw('screen', i % 2, i // 2) for i in range(4)])
for i in range(4):
    (pa, pb), (qa, qb) = scr[i], scr[(i + 1) % 4]
    mb.face([ML(qa, qb, sd), ML(pa, pb, sd), ML(pa, pb, HF), ML(qa, qb, HF)],
            [uv_msw('edge', 0, 1), uv_msw('edge', 1, 1), uv_msw('edge', 1, 0), uv_msw('edge', 0, 0)])
# sides, back to HB
outline = [(A0, B0), (A1, B0), (A1, B1 - MFD_CH), (cb, B1), (A0, B1)]
for i in range(len(outline)):
    (pa, pb), (qa, qb) = outline[i], outline[(i + 1) % len(outline)]
    mb.face([ML(pa, pb, HB), ML(qa, qb, HB), ML(qa, qb, HF), ML(pa, pb, HF)],
            [uv_msw('paint', 0, 1), uv_msw('paint', 1, 1), uv_msw('paint', 1, 0), uv_msw('paint', 0, 0)])
mfd_box = mb.done("MFD_BOX", mfd_matrix(MP(MFD_OA, MFD_OB, MFD_HB)))

def mfd_child(obj, world):
    obj.parent = mfd_box
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_world = world
    return obj

def mfd_pivot(name, a, b):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "ARROWS"
    e.empty_display_size = 0.01
    coll.objects.link(e)
    bpy.context.view_layer.update()
    return mfd_child(e, mfd_matrix(MP(a, b, MFD_HF)))

def cap(mb_, w, h, z):
    """button cap, local mm around its pivot (z up = toward the pilot)"""
    x0, x1, y0, y1 = -w / 2, w / 2, -h / 2, h / 2
    mb_.face([(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)],
             [uv_msw('cap', 0, 1), uv_msw('cap', 1, 1), uv_msw('cap', 1, 0), uv_msw('cap', 0, 0)])
    q = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for i in range(4):
        (ax, ay), (bx, by) = q[i], q[(i + 1) % 4]
        mb_.face([(ax, ay, -1.0), (bx, by, -1.0), (bx, by, z), (ax, ay, z)],
                 [uv_msw('capside', 0, 1), uv_msw('capside', 1, 1), uv_msw('capside', 1, 0), uv_msw('capside', 0, 0)])

# bezel x / y (mm from the left / top edge, as the texture) -> frame a / b
def BZ(x, y):
    return MFD_A0 + x, MFD_B1 - y

OSB = {}                          # name -> (a, b, w, h, argument)
SXL, SYT, SWD, SHT = 24.0, 23.0, 152.0, 144.0      # screen in bezel mm
for i in range(5):
    x = SXL + SWD * (i + 0.5) / 5
    y = SYT + SHT * (i + 1) / 6
    OSB[f"L{i + 1}"] = (*BZ(SXL / 2, y), 8.0, 10.0, ARG_OSB0 + i)
    OSB[f"B{i + 1}"] = (*BZ(x, SYT + SHT + (190 - SYT - SHT) / 2), 11.0, 8.0, ARG_OSB0 + 5 + i)
    OSB[f"R{i + 1}"] = (*BZ(SXL + SWD + (200 - SXL - SWD) / 2, y), 8.0, 10.0, ARG_OSB0 + 10 + i)
    OSB[f"T{i + 1}"] = (*BZ(x, SYT / 2 + 0.6), 11.0, 8.0, ARG_OSB0 + 15 + i)
osb_objs = {}
for name, (a, b, w, h, arg) in OSB.items():
    pv = mfd_pivot(f"MFD_OSB_{name}_PIVOT", a, b)
    mb = MB(mfd_mat)
    cap(mb, w, h, 3.0)
    osb_objs[name] = mb.done(f"MFD_OSB_{name}", None, parent=pv)
# ВКЛ (power) push button
PWR_AB = BZ(12.0, 12.6)
pv = mfd_pivot("MFD_PWR_PIVOT", *PWR_AB)
mb = MB(mfd_mat)
cap(mb, 6.4, 6.4, 3.2)
pwr_obj = mb.done("MFD_PWR", None, parent=pv)
# rockers (ЯРК + / -, ДЕНЬ / НОЧЬ): fixed caps, the clicks are on their halves
ROCK = {"BRT": BZ(12.0, 160.5), "DN": BZ(188.0, 160.5)}
for name, (a, b) in ROCK.items():
    pv = mfd_pivot(f"MFD_{name}_PIVOT", a, b)
    mb = MB(mfd_mat)
    cap(mb, 6.8, 12.0, 3.0)
    mb.done(f"MFD_{name}", None, parent=pv)

# ---------------------------------------------------------------------------
# v13 (Su-33): the control unit - housing and keypad (the loader plate and the
# radio block above already sit on its face)
# ---------------------------------------------------------------------------
pod_keys = {}
if POD:
    pod_mat, _ = make_mat("POD_MAT", POD_TEXTURE)
    POD_ROT = Matrix((to_bl(POD_R), to_bl(POD_U), to_bl(POD_N))).transposed()
    def pod_matrix(pos_dcs):
        m = POD_ROT.to_4x4()
        m.translation = to_bl(pos_dcs)
        return m
    def uv_pod(x, y):             # face art: pod mm from the left / top edge
        return (x * POD_PXMM / POD_TEX, 1.0 - y * POD_PXMM / POD_TEX)
    def uv_psw(name, s_=0.5, t_=0.5):
        x0 = POD_SW[name]
        return ((x0 + 6 + s_ * 177) / POD_TEX, 1.0 - (1906 + t_ * 127) / POD_TEX)
    # housing, local mm: x right, y up from the face's top-left corner, z out
    # of the face; chamfered front edge, sides back to -POD_D
    mb = MB(pod_mat, 1.0)
    PC = 1.5
    f_in = [(PC, -POD_H + PC), (POD_W - PC, -POD_H + PC), (POD_W - PC, -PC), (PC, -PC)]
    f_out = [(0, -POD_H), (POD_W, -POD_H), (POD_W, 0), (0, 0)]
    mb.face([(x, y, 0) for x, y in f_in], [uv_pod(x, -y) for x, y in f_in])
    for i in range(4):
        a, b = f_in[i], f_in[(i + 1) % 4]
        c, d = f_out[(i + 1) % 4], f_out[i]
        mb.face([(*d, -PC), (*c, -PC), (*b, 0), (*a, 0)], [uv_psw('edge', 0, 1), uv_psw('edge', 1, 1), uv_psw('edge', 1, 0), uv_psw('edge', 0, 0)])
        mb.face([(*d, -POD_D), (*c, -POD_D), (*c, -PC), (*d, -PC)], [uv_psw('paint', 0, 1), uv_psw('paint', 1, 1), uv_psw('paint', 1, 0), uv_psw('paint', 0, 0)])
    mb.face([(x, y, -POD_D) for x, y in reversed(f_out)], [uv_psw('paint')] * 4)
    mb.done("POD_BODY", pod_matrix(PODP(0, 0, 0)))
    # keys: cap top = its own square of the texture (POD_KEY_ATLAS + col * 200,
    # y row * 130, 180 x 110 px), sides dark
    for i, (name, arg) in enumerate(POD_KEYS):
        x, y = POD_KEY_X[i % 3], POD_KEY_Y[i // 3]
        e = bpy.data.objects.new(f"POD_KEY_{name}_PIVOT", None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.01
        coll.objects.link(e)
        e.matrix_world = pod_matrix(PODP(x, y, 0))
        u0, v0 = POD_KEY_ATLAS[0] + (i % 3) * 200, POD_KEY_ATLAS[1] + (i // 3) * 130
        def kuv(px, py):
            return ((u0 + px) / POD_TEX, 1.0 - (v0 + py) / POD_TEX)
        mb = MB(pod_mat, 1.0)
        kw, kh, kz = POD_KEY_W / 2, POD_KEY_H / 2, POD_KEY_Z
        q = [(-kw, -kh), (kw, -kh), (kw, kh), (-kw, kh)]
        mb.face([(qx, qy, kz) for qx, qy in q], [kuv((qx + kw) * 10, (kh - qy) * 10) for qx, qy in q])
        for j in range(4):
            (ax, ay), (bx, by) = q[j], q[(j + 1) % 4]
            mb.face([(ax, ay, -1.0), (bx, by, -1.0), (bx, by, kz), (ax, ay, kz)],
                    [uv_psw('capside', 0, 1), uv_psw('capside', 1, 1), uv_psw('capside', 1, 0), uv_psw('capside', 0, 0)])
        pod_keys[name] = (mb.done(f"POD_KEY_{name}", None, parent=e), arg)

# ---------------------------------------------------------------------------
# animations -> DCS arguments
# ---------------------------------------------------------------------------
# v5: ED's exporter rules, read from its own code (io_scene_edm):
#   * the argument is the number the ACTION'S NAME starts with:
#     "801_LDR_SEL" -> argument 801 (utils.extract_arg_number, ^(\d+)(_.+)?)
#   * argument value = frame / 100 - 1: frame 100 = 0.0, frame 110 = 0.1,
#     frame 200 = 1.0 (animation.fcurves_animation)
#   * only rotation / location / scale channels of the object itself count
# (v2-v4 looked for an argument setting that does not exist; edm.set_argument
# only mutes/unmutes animations for previewing in Blender.)
import re
ARG_RE = re.compile(r'^(\d+)(_.+)?')

def frame_of(value):
    return 100.0 + 100.0 * value

def animate(obj, name, keys, arg):
    """keys: list of (argument value, data_path, index, value)"""
    obj.animation_data_create()
    act = bpy.data.actions.new(f"{arg}_{name}")
    obj.animation_data.action = act
    for av, path, idx, val in keys:
        if path == "rotation_euler":
            obj.rotation_euler[idx] = val
        elif path == "scale":
            obj.scale[idx] = val
        else:
            obj.location[idx] = val
        obj.keyframe_insert(data_path=path, index=idx, frame=frame_of(av))
    for fc in act.fcurves:
        fc.mute = False
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    m = ARG_RE.match(act.name)
    got = int(m.group(1)) if m else -1
    frames = sorted({kp.co[0] for fc in act.fcurves for kp in fc.keyframe_points})
    ok = (got == arg)
    print(f"ANIMATION {act.name}: argument {got}{'' if ok else '  !! WRONG (wanted %d)' % arg}, "
          f"keys at argument {[round(f / 100 - 1, 2) for f in frames]}")
    return act

# selector: 0.0 = МИС, 0.1 = 1 ... 0.6 = 6, held to 1.0
k = []
for st in range(KNOB_STEPS):
    a = st / 10.0
    ang = math.radians(KNOB_ANG0 + st * KNOB_STEP)
    if st > 0:
        k.append((a - 0.02, "rotation_euler", 2, ang))      # v7: detents, every position keeps its key
    k.append((a + 0.02, "rotation_euler", 2, ang) if st < KNOB_STEPS - 1 else (a, "rotation_euler", 2, ang))
k.insert(0, (0.0, "rotation_euler", 2, math.radians(KNOB_ANG0)))
k.append((1.0, "rotation_euler", 2, math.radians(KNOB_ANG0 + (KNOB_STEPS - 1) * KNOB_STEP)))
knob.rotation_mode = "XYZ"
animate(knob, "LDR_SEL", k, ARG_SEL)
# button: 0 = out, 1 = pressed 1.6 mm in
animate(button, "LDR_BTN", [(0.0, "location", 2, 0.0), (1.0, "location", 2, -0.0016 * PLATE_S)], ARG_BTN)
# v6: КАНАЛ knobs - channel n (1..20) at argument (n-1) x 0.05, 18 deg per
# step clockwise; channel 5 points left, 10 up, 15 right, 20 down (ED's
# scale). Argument 1.0 = one full turn = channel 1 again (the knob cycles).
def chan_angle(n):
    return math.radians(270.0 - 18.0 * n)
for key, arg in (("UKV", ARG_UKV), ("KV", ARG_KV)):
    kn = rad_knobs[key]
    kn.rotation_mode = "XYZ"
    # v7: each channel held flat for +-0.01 around its value (a detent), so
    # the exporter keeps a key at every channel: v6's keys were thinned to
    # channel 1 -> 11, exactly 180 deg apart, and DCS could turn that the
    # wrong way. The knob only ever sits on the exact values.
    kk = [(0.0, "rotation_euler", 2, chan_angle(1)), (0.01, "rotation_euler", 2, chan_angle(1))]
    for n in range(2, 21):
        a = (n - 1) * 0.05
        kk.append((a - 0.01, "rotation_euler", 2, chan_angle(n)))
        kk.append((a + 0.01, "rotation_euler", 2, chan_angle(n)))
    kk.append((0.99, "rotation_euler", 2, chan_angle(21)))
    kk.append((1.0, "rotation_euler", 2, chan_angle(21)))
    animate(kn, f"RAD_{key}", kk, arg)
# v9: ГРОМК knobs - volume 0 .. 1 in steps of 0.05, 13.5 deg per step,
# clockwise. Each step held flat for +-0.01 (detents, as v7: whole frames), so the
# exporter keeps a key every 13.5 deg and never takes a 270 deg span the
# short way round.
def vol_angle(v):
    return math.radians(RAD_VOL_ANG0 - RAD_VOL_SWEEP * v)
for key, arg in (("VUKV", ARG_VOL_UKV), ("VKV", ARG_VOL_KV)):
    kn = vol_knobs[key]
    kn.rotation_mode = "XYZ"
    kk = [(0.0, "rotation_euler", 2, vol_angle(0.0)), (0.01, "rotation_euler", 2, vol_angle(0.0))]
    for n in range(1, 20):
        v = n * 0.05
        kk.append((v - 0.01, "rotation_euler", 2, vol_angle(v)))
        kk.append((v + 0.01, "rotation_euler", 2, vol_angle(v)))
    kk.append((0.99, "rotation_euler", 2, vol_angle(1.0)))
    kk.append((1.0, "rotation_euler", 2, vol_angle(1.0)))
    animate(kn, f"RAD_{key}", kk, arg)
# v10: MFD soft keys and ВКЛ: 0 = out, 1 = pressed 1.5 mm in
for name, obj in osb_objs.items():
    animate(obj, f"MFD_OSB_{name}", [(0.0, "location", 2, 0.0), (1.0, "location", 2, -0.0015)], OSB[name][4])
for name, (obj, arg) in pod_keys.items():
    animate(obj, f"POD_KEY_{name}", [(0.0, "location", 2, 0.0), (1.0, "location", 2, -0.0015)], arg)
animate(pwr_obj, "MFD_PWR", [(0.0, "location", 2, 0.0), (1.0, "location", 2, -0.0015)], ARG_PWR)
# v10: stow - the whole unit (and its children) shrinks into ED's HDD
animate(mfd_box, "MFD_STOW", [(0.0, "scale", 0, 1.0), (0.0, "scale", 1, 1.0), (0.0, "scale", 2, 1.0),
                              (1.0, "scale", 0, 0.001), (1.0, "scale", 1, 0.001), (1.0, "scale", 2, 0.001)], ARG_STOW)
bpy.context.scene.frame_start = 0
bpy.context.scene.frame_end = 200
bpy.context.scene.frame_set(100)      # argument 0: knob on МИС, button out

# ---------------------------------------------------------------------------
# connectors
# ---------------------------------------------------------------------------
def set_edm_type(obj, kind):
    p = getattr(obj, "EDMProps", None)
    if p is None or not hasattr(p, "SPECIAL_TYPE"):
        if not TEST_HEADLESS:
            print("  !! EDMProps missing - is the EDM exporter enabled?")
        return False
    try:
        p.SPECIAL_TYPE = kind
        return True
    except Exception as e:
        print("  !! could not set", obj.name, "to", kind, ":", e)
        return False

def connector(name, pos, half, rot=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "CUBE"
    e.empty_display_size = 1.0
    coll.objects.link(e)
    if rot is None:
        e.matrix_world = frame_matrix(pos, half)
    else:
        m = (rot @ Matrix.Diagonal((half, half, half))).to_4x4()
        m.translation = to_bl(pos)
        e.matrix_world = m
    set_edm_type(e, "CONNECTOR")
    return e

# Indicator anchors. Orientation rule taken from the F-15C SIT plate (ED's
# own MFD anchors): local X = screen right, local Y = screen DOWN, local
# Z = INTO the screen. The anchors span a square (half-size = half the plate
# width), so the indicator's units are the same both ways: 1 unit = 82.5 mm.
ANCHOR_ROT = Matrix((to_bl(U), to_bl(-V), to_bl(-W))).transposed()
HALF = PW / 2 / 1000 * PLATE_S
c_pt = P(PW / 2, PH / 2, FACE_H + GLOW_H)
connector("LDR_C", c_pt, 0.004, ANCHOR_ROT)
connector("LDR_B", c_pt - V * HALF, 0.004, ANCHOR_ROT)
connector("LDR_R", c_pt + U * HALF, 0.004, ANCHOR_ROT)
# click boxes (half-sizes in metres)
connector("LDR_SEL_CLICK", P(KNOB[0], KNOB[1], FACE_H + 0.005), 0.012 * PLATE_S)
connector("LDR_LOAD_CLICK", P(BTN[0], BTN[1], FACE_H + 0.003), 0.0068 * PLATE_S)
# v6: radio window anchors (square, half-size 50 mm, so 1 unit = 50 mm),
# on ED's window glass, centred between the two windows; same orientation
# rule as LDR_C/B/R
RAD_ANCHOR_ROT = Matrix((to_bl(RR_), to_bl(-RU_), to_bl(-RN_))).transposed()
RAD_HALF = 0.050 * RAD_S
rc = RP(RAD_ANCHOR_X, RAD_WIN_Y, RAD_WIN_H + 0.12)
connector("RAD_C", rc, 0.004, RAD_ANCHOR_ROT)
connector("RAD_B", rc - RU_ * RAD_HALF, 0.004, RAD_ANCHOR_ROT)
connector("RAD_R", rc + RR_ * RAD_HALF, 0.004, RAD_ANCHOR_ROT)
RAD_ROT = Matrix((to_bl(RR_), to_bl(RU_), to_bl(RN_))).transposed()
for key, (kx, ky) in RAD_KNOBS.items():
    connector(f"RAD_{key}_CLICK", RP(kx, ky, RAD_KNOB_H / 2), 0.0165 * RAD_S, RAD_ROT)
for key, (kx, ky) in RAD_VOL.items():
    connector(f"RAD_{key}_CLICK", RP(kx, ky, RAD_VOL_H / 2), 0.0085 * RAD_S, RAD_ROT)
# v8: card anchors (square, half-size = half the card width: 1 unit = 74.2 mm)
CRD_ANCHOR_ROT = Matrix((to_bl(CR_), to_bl(-CU_), to_bl(-CN_))).transposed()
CRD_HALF = CRD_W / 2 / 1000
cc = CP(CRD_W / 2, CRD_H / 2, CRD_GAP + 0.2)
connector("CRD_C", cc, 0.004, CRD_ANCHOR_ROT)
connector("CRD_B", cc - CU_ * CRD_HALF, 0.004, CRD_ANCHOR_ROT)
connector("CRD_R", cc + CR_ * CRD_HALF, 0.004, CRD_ANCHOR_ROT)
# v11: MFD page anchors (square, half-size 88.9 mm: 1 page unit = 88.9 mm =
# SIT.G in MFD/mfd_config.lua, so the 152 x 144 mm screen is +-0.855 x
# +-0.81 units), on the screen floor; same orientation rule as LDR_C/B/R
MFD_ANCHOR_ROT = Matrix((to_bl(MR_), to_bl(-MU_), to_bl(-MN_))).transposed()
MFD_HALF = 0.0889                     # must match SIT.G (mfd_config.lua)
mc = MP((MFD_SCR[0] + MFD_SCR[1]) / 2, (MFD_SCR[2] + MFD_SCR[3]) / 2, MFD_HF - MFD_SCR_D + 0.3)
n_mfd = 0
def mfd_conn(name, pos, half, rot):
    global n_mfd
    e = connector(name, pos, half, rot)
    w = e.matrix_world.copy()
    e.parent = mfd_box
    e.matrix_parent_inverse = Matrix.Identity(4)
    e.matrix_world = w
    n_mfd += 1
    return e
bpy.context.view_layer.update()
mfd_conn("MFD_C", mc, 0.004, MFD_ANCHOR_ROT)
mfd_conn("MFD_B", mc - MU_ * MFD_HALF, 0.004, MFD_ANCHOR_ROT)
mfd_conn("MFD_R", mc + MR_ * MFD_HALF, 0.004, MFD_ANCHOR_ROT)
for name, (a, b, w, h, arg) in OSB.items():
    mfd_conn(f"MFD_OSB_{name}_CLICK", MP(a, b, MFD_HF + 2.0), max(w, h) / 2 / 1000 + 0.0005, MFD_ROT)
mfd_conn("MFD_PWR_CLICK", MP(*PWR_AB, MFD_HF + 2.0), 0.0045, MFD_ROT)
for name, (a, b) in ROCK.items():
    up_, dn_ = ("UP", "DN") if name == "BRT" else ("D", "N")
    mfd_conn(f"MFD_{name}_{up_}_CLICK", MP(a, b + 3.2, MFD_HF + 2.0), 0.0032, MFD_ROT)
    mfd_conn(f"MFD_{name}_{dn_}_CLICK", MP(a, b - 3.2, MFD_HF + 2.0), 0.0032, MFD_ROT)
# v10: ED's ЦЕЛИ / ИСТРЕБИТЕЛИ keypad (not part of the MFD: stays when stowed)
KN_ = Vector(KP_NORMAL).normalized()
KR_ = Vector(KP_RIGHT); KR_ = (KR_ - KN_ * KR_.dot(KN_)).normalized()
KF_ = KN_.cross(KR_).normalized()
KP_ROT = Matrix((to_bl(KR_), to_bl(KF_), to_bl(KN_))).transposed()
n_kp = 0
if POD:
    # v13: the side unit's own keys
    for i, (name, arg) in enumerate(POD_KEYS):
        x, y = POD_KEY_X[i % 3], POD_KEY_Y[i // 3]
        connector(f"KP_{name}_CLICK", PODP(x, y, POD_KEY_Z), 0.0095, POD_ROT)
        n_kp += 1
else:
    for name, pos in KP_KEYS.items():
        connector(f"KP_{name}_CLICK", Vector(pos) + KN_ * 0.003, 0.0095, KP_ROT)
        n_kp += 1
print(f"{15 + n_mfd + n_kp} connectors built")


# ---------------------------------------------------------------------------
# v12 (Su-33 only): every group hangs on its own chain of three empties:
# a fixed shift (SU33_SHIFT) and live offsets forward / up / right driven by
# the FIT_ARGS (argument -1..1 = -FIT_RANGE..+FIT_RANGE metres)
# ---------------------------------------------------------------------------
# v13: the side unit's parts become part of the MFD (they move, fit and stow
# with it)
n_pod = 0
if POD:
    bpy.context.view_layer.update()
    for ob in [o for o in coll.objects if o.parent is None and o.name.split("_")[0] in ("LDR", "RAD", "KP", "POD")]:
        w = ob.matrix_world.copy()
        ob.parent = mfd_box
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_world = w
        n_pod += 1
    bpy.context.view_layer.update()
    print("side unit:", n_pod, "parts on the MFD")

n_fit = 0
if AIRCRAFT == "Su-33":
    bpy.context.view_layer.update()
    tops = [ob for ob in coll.objects if ob.parent is None]
    for grp, arg0 in FIT_ARGS.items():
        members = [ob for ob in tops if ob.name.startswith(grp + "_")]
        if not members:
            print("FIT", grp, ": no parts")
            continue
        fx, fu, fr = SU33_SHIFT.get(grp, (0.0, 0.0, 0.0))
        base = bpy.data.objects.new(f"FIT_{grp}_BASE", None)
        coll.objects.link(base)
        base.location = to_bl((fx, fu, fr))
        prev = base
        for k, (axis, idx, sgn) in enumerate((("FWD", 0, 1.0), ("UP", 2, 1.0), ("RIGHT", 1, -1.0))):
            e = bpy.data.objects.new(f"FIT_{grp}_{axis}", None)
            coll.objects.link(e)
            e.parent = prev
            e.matrix_parent_inverse = Matrix.Identity(4)
            animate(e, f"FIT_{grp}_{axis}", [(-1.0, "location", idx, -sgn * FIT_RANGE), (0.0, "location", idx, 0.0),
                                             (1.0, "location", idx, sgn * FIT_RANGE)], arg0 + k)
            prev = e
        for ob in members:
            ob.parent = prev
            ob.matrix_parent_inverse = Matrix.Identity(4)   # its matrix_basis (= its old place) stays: moves with the chain
        n_fit += len(members)
        print("FIT", grp, ":", len(members), "parts, shift", (fx, fu, fr), "arguments", arg0, "..", arg0 + 2)
    bpy.context.scene.frame_set(100)

# ---------------------------------------------------------------------------
# export
# ---------------------------------------------------------------------------
shapes = os.path.join(MOD_DIR, "Shapes")
out = os.path.join(shapes, EDM_NAME + ".edm")
if edm_ok:
    os.makedirs(shapes, exist_ok=True)
    try:
        bpy.ops.edm.export(filepath=out)
        print("EXPORTED:", out)
        # v10: tells the add-on that this model has the MFD (its anchors and
        # click boxes); without this file the MFD stays switched off
        with open(os.path.join(shapes, EDM_NAME + "_MFD.txt"), "w") as f_:
            f_.write(EDM_NAME + ".edm v14: MFD, keypad click boxes" + (", control unit on top" if n_pod else "") + (", Su-33 fit arguments" if n_fit else "") + "\n")
        print("MFD marker written")
    except Exception as e:
        print("  !! export failed:", e)
        print("     Try File > Export > Eagle Dynamics Model (.edm) to", out)
elif not TEST_HEADLESS:
    print("Fix the material (see above), then File > Export > Eagle Dynamics Model (.edm) to", out)
print("done")
