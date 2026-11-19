# Su-27 radio channel card: one layout for the printed texture, the Blender
# script and the Lua indicator. mm, x from the card's left edge, y from its top.
CW, CH = 148.4, 52.6          # card (ED's is 147.4 x 51.6; 0.5 mm more each side)
# ED's card holder covers ~7 mm at each end: everything printed / written
# stays between x = 8 and 140.4
TITLE_Y = (1.6, 7.4)
HEAD_Y = (7.4, 12.0)
ROW0, ROW_H, ROWS = 12.0, 3.85, 10   # 10 rows per half -> ends at 50.5
HALF_X = (8.0, 74.2)          # left edge of each half
HALF_W = 66.2
COLS = [0.0, 6.8, 21.0, 45.2, 66.2]   # within a half: № | ЧАСТОТА | РАДИОСТАНЦИЯ | ПОЗЫВНОЙ
PXMM = 13.6                   # card texture: 2018 x 715 px used of 2048 x 1024
TEX_W, TEX_H = 2048, 1024
