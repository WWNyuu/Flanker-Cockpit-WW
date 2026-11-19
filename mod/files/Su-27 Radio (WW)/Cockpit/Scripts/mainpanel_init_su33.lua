-- Su-27 Radio (WW): the add-on's model for the Su-33 (v1.3 test 9).
-- Same parts as SU27_LDR.edm, each group on its own fit arguments 870-884.
-- Loads Shapes/SU27_LDR.edm into the cockpit (the loader plate on the right
-- console wall), the way the F-15C SIT add-on loads F15C_SIT.edm.
-- Its animations: argument 801 = КАССЕТА knob, 802 = ЗАГР button (DCS moves
-- them itself on click, see clickabledata.lua).

shape_name = "SU33_LDR"

local controllers = LoRegisterPanelControls()

need_to_be_closed = true -- close lua state after initialization
