# Su-27 data loader plate (ВВОД ДАННЫХ): one layout for the texture, the
# Blender script and the Lua indicator. Plate coordinates in mm, x from the
# left edge, y from the top edge, as the pilot sees the plate.
PW, PH = 165.0, 71.0          # plate (covers ED's 163 x 69 mm blank cover)
SCREWS = [(5.0, 5.0), (160.0, 5.0), (5.0, 66.0), (160.0, 66.0)]
SCREW_R = 2.6

TITLE = (82.5, 7.2)

KNOB = (34.0, 41.0)            # КАССЕТА selector
KNOB_R = 10.0                  # skirt radius
KNOB_POS = ['МИС', '1', '2', '3', '4', '5', '6']
KNOB_ANG0 = 210.0              # angle (deg, CCW from plate right) of МИС
KNOB_STEP = -40.0              # each step clockwise
KNOB_SCALE_R = 18.5            # numbers
KNOB_LABEL = (34.0, 65.0)

DIV_X = (67.0, 125.0)
DIV_Y = (15.0, 65.0)

WIN = (96.0, 27.0)             # В РАБОТЕ window centre
WIN_W, WIN_H = 30.0, 16.0
WIN_LABEL = (96.0, 41.5)

BTN = (99.0, 55.5)             # ЗАГР button
BTN_GUARD_R = 6.3
BTN_R = 4.3
BTN_LABEL = (80.0, 55.5)

LAMP_R = 4.2
LAMP_BEZEL_R = 5.6
LAMP_GO = (145.0, 25.0)
LAMP_GO_LABEL = (145.0, 36.0)
LAMP_NOGO = (145.0, 48.5)
LAMP_NOGO_LABEL = (145.0, 59.5)

# texture atlas
TEX_W, TEX_H = 2048, 1024
PXMM = 12.0                    # front artwork: 12 px per mm -> 1980 x 852 px
SW_Y0, SW_Y1 = 872, 1022       # swatch strip
SWATCH = {                     # name: (x0, x1)
    'paint': (0, 190), 'black': (200, 390), 'chrome': (400, 590), 'red': (600, 790),
    'lens_go': (800, 990), 'lens_nogo': (1000, 1190), 'white': (1200, 1390),
    'screw': (1400, 1560), 'pointer': (1580, 2040),
}
