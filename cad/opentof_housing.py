"""OpenToF sensor housing with an integrated Veriflite-style trampoline clip.

Generates cad/OpenToF_Housing.FCStd plus printable STLs in cad/stl/. All dimensions are in mm and live
in the PARAMETERS block below: change them and re-run, don't edit the FCStd by hand.

Run headless (from the repo root):
    "C:\\Program Files\\FreeCAD 1.0\\bin\\freecadcmd.exe" cad/opentof_housing.py
or open it in the FreeCAD GUI via Macro > Macros... > Execute.

Coordinate system (body as printed, clip flat on the bed):
    x = 0      outer face of the clip's straight arm; +x = towards the housing / the floor when mounted
    +y         towards the clip's closed end (away from the trampoline); the USB-C port is on the +y end
    +z         print direction (up); the lid closes the +z side
"""
import math
import os

import FreeCAD as App
import Mesh
import Part

V = App.Vector

# ---------------------------------------------------------------- PARAMETERS
# Clearances / walls
CLR = 0.3            # general fit clearance per side for parts dropped into pockets
WALL = 1.6           # outer walls
WALL_ARM = 1.6       # wall between clip arm and cavity
FLOOR = 1.6
LID_T = 2.0

# Battery: FE602045 LiPo (docs/hardware/AKKU_SOLD333278_DB-EN.pdf), max dimensions
BAT_L, BAT_W, BAT_T = 45.5, 20.2, 6.1
BAT_TAB_SPACE = 6.0  # room at the USB end for the (bent) tabs, protection circuit and solder joints

# Seeed XIAO MG24 Sense (standard XIAO outline). Verify PCB_T / USB_OVERHANG with calipers.
PCB_L, PCB_W, PCB_T = 21.0, 17.8, 1.2
PCB_TOP_H = 3.3      # tallest part on the component side (the USB-C receptacle)
USB_OVERHANG = 1.2   # how far the USB-C receptacle sticks out past the PCB edge
USB_W, USB_H = 8.94, 3.26
WIRE_GAP = 1.6       # between battery and PCB underside (BAT pads + wires)
PCB_GROOVE_DEPTH = 0.8

# USB-C opening: through hole for the receptacle + outer recess for the plug overmold
USB_HOLE = (9.8, 4.0, 1.5)      # width (z), height (x), corner radius
USB_RECESS = (12.6, 6.8, 2.5)
USB_RECESS_DEPTH = 0.8

# LED window: thin membrane in the floor-facing (+x) wall so the charge/user LEDs shine through.
# Position measured from the PCB's USB edge along -y; the LEDs sit next to the USB-C receptacle.
LED_WIN_Y = (0.5, 5.5)          # from USB edge of the PCB
LED_WIN_Z = 15.0                # window length along z, centred on the PCB
LED_WIN_MEMBRANE = 0.6

# M2 screws with captive hex nuts (ISO 4762 / DIN 912 M2x8 + ISO 4032 / DIN 934 M2)
SCREW_CLEAR_D = 2.4
NUT_AF = 4.0 + 0.3              # across flats + clearance
NUT_SLOT_H = 2.0
NUT_TOP = 3.4                   # nut slot ceiling below the box rim
SCREW_LEN = 8.0
BOSS = 7.0                      # square boss size

# Clip
CLIP_H = 20.0                   # extrusion height, same as the Veriflite mount
LOOP_RELIEF = 0.6               # gap between box and clip loop so the hinge can still flex
LOOP_RELIEF_START = 46.6        # y from where the box no longer touches the arm (loop starts at y=48.6)
BOX_Y0 = 0.3                    # box starts just above the lead-in flare (flare fillet starts at y=0)
FUSE_OVERLAP = 0.5

# Lid
LID_LIP_H = 1.5
LID_LIP_W = 1.0
LID_LIP_CLR = 0.25
FORK_LEN_Y = 8.0
FORK_T = 1.0

# Veriflite clip profile, taken from cad/Veriflite.stl (section at z=3), rotated by -5.1 deg so the
# straight arm's outer face lies on x=0 (y 0..48.6). Closed CCW polygon.
CLIP_PROFILE = [
    (-10.843, 50.963), (-10.422, 51.350), (-9.953, 51.678), (-9.446, 51.944),
    (-8.881, 52.149), (-8.161, 52.293), (-7.589, 52.320), (-7.019, 52.273),
    (-6.459, 52.152), (-5.920, 51.960), (-5.410, 51.699), (-4.791, 51.253),
    (-4.383, 50.852), (-4.030, 50.401), (-3.739, 49.909), (-3.514, 49.382),
    (-3.359, 48.831), (-3.264, 47.883), (-3.376, 46.937), (-3.610, 46.211),
    (-4.579, 43.913), (-4.316, 39.277), (-2.603, 39.276), (-2.622, -0.672),
    (-2.583, -1.295), (-2.467, -1.908), (-2.276, -2.502), (-2.012, -3.067),
    (-1.555, -3.762), (-1.140, -4.228), (2.879, -8.207), (3.942, -8.278),
    (4.233, -8.194), (4.517, -7.997), (4.717, -7.716), (4.809, -7.383),
    (4.709, -6.358), (1.462, -3.143), (0.922, -2.511), (0.577, -1.959),
    (0.254, -1.222), (0.048, -0.416), (0.0, 0.204), (0.0, 48.638),
    (-0.197, 49.790), (-0.552, 50.865), (-0.993, 51.761), (-1.662, 52.739),
    (-2.441, 53.575), (-3.217, 54.203), (-4.067, 54.726), (-5.141, 55.193),
    (-6.260, 55.489), (-7.416, 55.614), (-8.580, 55.563), (-9.561, 55.381),
    (-10.511, 55.072), (-11.543, 54.569), (-12.513, 53.899), (-13.246, 53.221),
    (-13.885, 52.454), (-14.419, 51.611), (-14.840, 50.706), (-15.140, 49.754),
    (-16.596, 31.485), (-16.659, 29.886), (-16.643, 29.086), (-16.525, 27.595),
    (-16.258, 25.910), (-15.877, 24.356), (-5.254, -7.673), (-5.140, -7.908),
    (-4.970, -8.105), (-4.754, -8.251), (-4.508, -8.337), (-4.119, -8.341),
    (-3.795, -8.218), (-3.505, -7.959), (-3.336, -7.608), (-3.215, -4.654),
    (-3.253, -4.063), (-3.360, -3.481), (-12.025, 22.651), (-12.473, 24.210),
    (-12.650, 25.002), (-12.906, 26.603), (-12.985, 27.411), (-13.045, 29.031),
    (-12.602, 39.383), (-10.995, 45.045), (-11.456, 45.689), (-11.839, 46.530),
    (-12.020, 47.300), (-12.054, 48.224), (-11.935, 48.978), (-11.689, 49.699),
    (-11.321, 50.368),
]

# ---------------------------------------------------------------- DERIVED LAYOUT
# Cavity, in cavity-local coordinates (origin = inner corner at arm side / flare end / floor).
X_BAT1 = BAT_T + 2 * CLR                      # battery slot along x: [0, X_BAT1]
X_PCB0 = X_BAT1 + WIRE_GAP                    # PCB underside
X_PCB1 = X_PCB0 + PCB_T                       # PCB component side
CAV_X = X_PCB1 + PCB_TOP_H + 0.4
CAV_Z = BAT_W + 2 * CLR
Y_BAT0 = BOSS                                 # end block with two screws at the flare end
CAV_Y = Y_BAT0 + BAT_L + 2 * CLR + BAT_TAB_SPACE
Y_PCB1 = CAV_Y - USB_OVERHANG                 # PCB USB edge -> receptacle front flush with inner wall
Y_PCB0 = Y_PCB1 - PCB_L
Z_PCB0 = -PCB_GROOVE_DEPTH                    # PCB bottom edge sits in a floor groove
Z_PCB1 = Z_PCB0 + PCB_W

# Cavity-local -> global offset
OX, OY, OZ = WALL_ARM, BOX_Y0 + WALL, FLOOR
BOX_X = WALL_ARM + CAV_X + WALL
BOX_Y = CAV_Y + 2 * WALL
BOX_Z = FLOOR + CAV_Z

# Screw axes (cavity-local x, y)
B3_Y0 = Y_PCB0 - 0.3 - BOSS
SCREWS = [
    (X_BAT1 / 2, BOSS / 2, +1),                           # nut slot opens towards +y (battery bay)
    ((X_BAT1 + CAV_X) / 2 + 0.3, BOSS / 2, +1),           # opens towards +y (free bay)
    ((X_BAT1 + CAV_X) / 2 + 0.3, B3_Y0 + BOSS / 2, -1),   # opens towards -y (free bay)
]


def box(x0, y0, z0, dx, dy, dz):
    return Part.makeBox(dx, dy, dz, V(x0, y0, z0))


def cbox(x0, y0, z0, dx, dy, dz):
    """Box given in cavity-local coordinates."""
    return box(OX + x0, OY + y0, OZ + z0, dx, dy, dz)


def rounded_rect_prism(cx, cz, w_z, h_x, r, y0, depth):
    """Rounded rectangle in the x-z plane (centre cx/cz), extruded along +y from y0."""
    r = min(r, w_z / 2 - 1e-3, h_x / 2 - 1e-3)
    core = box(cx - h_x / 2 + r, y0, cz - w_z / 2, h_x - 2 * r, depth, w_z)
    core = core.fuse(box(cx - h_x / 2, y0, cz - w_z / 2 + r, h_x, depth, w_z - 2 * r))
    for sx in (-1, 1):
        for sz in (-1, 1):
            c = Part.makeCylinder(r, depth, V(cx + sx * (h_x / 2 - r), y0, cz + sz * (w_z / 2 - r)), V(0, 1, 0))
            core = core.fuse(c)
    return core.removeSplitter()


def make_clip():
    pts = [V(x, y, 0) for x, y in CLIP_PROFILE]
    wire = Part.makePolygon(pts + [pts[0]])
    return Part.Face(wire).extrude(V(0, 0, CLIP_H))


def make_body():
    outer = box(0, BOX_Y0, 0, BOX_X, BOX_Y, BOX_Z)
    # keep the clip loop free: from LOOP_RELIEF_START on the box stays LOOP_RELIEF away from the arm
    outer = outer.cut(box(-1, LOOP_RELIEF_START, -1, 1 + LOOP_RELIEF, BOX_Y, BOX_Z + 2))
    # overlap into the arm where the box is fused to it (the arm is at x <= 0)
    outer = outer.fuse(box(-FUSE_OVERLAP, BOX_Y0, 0, FUSE_OVERLAP + 0.01,
                           LOOP_RELIEF_START - BOX_Y0, BOX_Z))
    body = outer.fuse(make_clip())

    # cavity
    cav = cbox(0, 0, 0, CAV_X, CAV_Y, CAV_Z + 1)
    body = body.cut(cav)

    # bosses: end block (two screws) + one boss in front of the PCB
    body = body.fuse(cbox(0, 0, 0, CAV_X, BOSS, CAV_Z))
    body = body.fuse(cbox(X_BAT1 + 0.3, B3_Y0, 0, CAV_X - X_BAT1 - 0.3, BOSS, CAV_Z))

    # screw holes + side nut slots
    for sx, sy, direction in SCREWS:
        hole_depth = SCREW_LEN - LID_T + 1.0
        body = body.cut(Part.makeCylinder(SCREW_CLEAR_D / 2, hole_depth + 1,
                                          V(OX + sx, OY + sy, BOX_Z - hole_depth), V(0, 0, 1)))
        z0 = BOX_Z - NUT_TOP - NUT_SLOT_H
        if direction > 0:
            slot = box(OX + sx - NUT_AF / 2, OY + sy - NUT_AF / 2, z0, NUT_AF, BOSS, NUT_SLOT_H)
        else:
            slot = box(OX + sx - NUT_AF / 2, OY + sy + NUT_AF / 2 - BOSS, z0, NUT_AF, BOSS, NUT_SLOT_H)
        body = body.cut(slot)

    # PCB floor groove
    body = body.cut(cbox(X_PCB0 - 0.2, Y_PCB0 - 0.3, Z_PCB0, PCB_T + 0.4, PCB_L + 0.6 + USB_OVERHANG, 1.0))

    # USB-C: through hole + outer recess in the +y end wall
    ucx = OX + X_PCB1 + USB_H / 2
    ucz = OZ + (Z_PCB0 + Z_PCB1) / 2
    y_wall = OY + CAV_Y
    body = body.cut(rounded_rect_prism(ucx, ucz, USB_HOLE[0], USB_HOLE[1], USB_HOLE[2], y_wall - 0.5, WALL + 1))
    body = body.cut(rounded_rect_prism(ucx, ucz, USB_RECESS[0], USB_RECESS[1], USB_RECESS[2],
                                       y_wall + WALL - USB_RECESS_DEPTH, USB_RECESS_DEPTH + 1))

    # LED window: thin membrane in the +x wall, pocketed from the inside
    win_y0 = OY + Y_PCB1 - LED_WIN_Y[1]
    win_z0 = ucz - LED_WIN_Z / 2
    body = body.cut(box(OX + CAV_X - 0.1, win_y0, win_z0, WALL - LED_WIN_MEMBRANE + 0.1,
                        LED_WIN_Y[1] - LED_WIN_Y[0], LED_WIN_Z))

    return body.removeSplitter()


def make_lid():
    """Lid in assembled position (sits on the box rim at z = BOX_Z)."""
    lid = box(0, BOX_Y0, BOX_Z, BOX_X, BOX_Y, LID_T)
    # locating lip along the +x wall and the USB end wall (the battery fills the arm side up to the rim),
    # cut away at the boss in front of the PCB
    c = LID_LIP_CLR
    lip = cbox(CAV_X - c - LID_LIP_W, BOSS + c, CAV_Z - LID_LIP_H, LID_LIP_W, CAV_Y - BOSS - 2 * c, LID_LIP_H)
    lip = lip.fuse(cbox(c, CAV_Y - c - LID_LIP_W, CAV_Z - LID_LIP_H, CAV_X - 2 * c, LID_LIP_W, LID_LIP_H))
    lip = lip.cut(cbox(X_BAT1, B3_Y0 - c, CAV_Z - LID_LIP_H - 1, CAV_X, BOSS + 2 * c, LID_LIP_H + 2))
    lid = lid.fuse(lip)
    # fork that holds the PCB's top edge
    fy = (Y_PCB0 + Y_PCB1) / 2 - FORK_LEN_Y / 2
    lid = lid.fuse(cbox(X_PCB0 - 0.2 - FORK_T, fy, Z_PCB1 - 1.0, FORK_T, FORK_LEN_Y, CAV_Z - Z_PCB1 + 1.0))
    lid = lid.fuse(cbox(X_PCB1 + 0.2, fy, Z_PCB1 - 0.5, FORK_T, FORK_LEN_Y, CAV_Z - Z_PCB1 + 0.5))
    for sx, sy, _ in SCREWS:
        lid = lid.cut(Part.makeCylinder(SCREW_CLEAR_D / 2, LID_T + 2, V(OX + sx, OY + sy, BOX_Z - 1), V(0, 0, 1)))
    return lid.removeSplitter()


def make_dummies():
    bat = cbox(CLR, Y_BAT0 + CLR, CLR, BAT_T, BAT_L, BAT_W)
    pcb = cbox(X_PCB0, Y_PCB0, Z_PCB0, PCB_T, PCB_L, PCB_W)
    zc = (Z_PCB0 + Z_PCB1) / 2
    usb = cbox(X_PCB1, Y_PCB1 - 7.35 + USB_OVERHANG, zc - USB_W / 2, USB_H, 7.35, USB_W)
    return bat, pcb.fuse(usb)


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    stl_dir = os.path.join(here, "stl")
    os.makedirs(stl_dir, exist_ok=True)

    body = make_body()
    lid = make_lid()
    bat, board = make_dummies()

    for name, shape in (("body", body), ("lid", lid)):
        if not shape.isValid():
            raise RuntimeError(f"{name} shape is invalid")
    if body.common(lid).Volume > 1e-3:
        raise RuntimeError(f"lid intersects body: {body.common(lid).Volume:.3f} mm^3")
    for name, part in (("battery", bat), ("board", board)):
        for other_name, other in (("body", body), ("lid", lid)):
            v = part.common(other).Volume
            if v > 1e-3:
                raise RuntimeError(f"{name} intersects {other_name}: {v:.3f} mm^3")

    doc = App.newDocument("OpenToF_Housing")
    for name, shape, color in (("Body", body, (0.9, 0.5, 0.1)), ("Lid", lid, (0.2, 0.5, 0.9)),
                               ("Battery_ref", bat, (0.3, 0.3, 0.3)), ("XIAO_ref", board, (0.1, 0.6, 0.2))):
        obj = doc.addObject("Part::Feature", name)
        obj.Shape = shape
        if App.GuiUp:
            obj.ViewObject.ShapeColor = color
    doc.recompute()
    doc.saveAs(os.path.join(here, "OpenToF_Housing.FCStd"))

    def export(shape, filename):
        mesh = Mesh.Mesh()
        mesh.addFacets(shape.tessellate(0.02))
        mesh.write(os.path.join(stl_dir, filename))

    export(body, "OpenToF_Housing_Body.stl")
    # lid printed upside down: flip and put on the bed
    lid_print = lid.copy()
    lid_print.rotate(V(0, 0, 0), V(1, 0, 0), 180)
    lid_print.translate(V(0, 0, -lid_print.BoundBox.ZMin))
    export(lid_print, "OpenToF_Housing_Lid.stl")

    bb = body.BoundBox
    print(f"body bbox: {bb.XLength:.1f} x {bb.YLength:.1f} x {bb.ZLength:.1f} mm, vol {body.Volume:.0f} mm^3")
    print(f"box: {BOX_X:.1f} x {BOX_Y:.1f} x {BOX_Z + LID_T:.1f} mm incl. lid; cavity {CAV_X:.1f} x {CAV_Y:.1f} x {CAV_Z:.1f}")
    print(f"lid vol {lid.Volume:.0f} mm^3; screws: {len(SCREWS)}x M2x{SCREW_LEN:.0f}")
    print("OK")


main()
