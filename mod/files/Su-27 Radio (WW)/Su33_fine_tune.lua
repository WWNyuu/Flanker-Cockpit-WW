-- Su-27 Radio (WW): live fit of the add-on's parts in the Su-33.
-- Only works with the Su-33 model (SU33_LDR.edm, built with
-- Tools\su27_ldr_plate.py and AIRCRAFT = "Su-33").
-- Edit, save, and look: DCS reads this file once a second while you sit in
-- the Su-33 (the sim must be running, not paused).
-- Metres, added to where the part is now:
--   forward (+ = away from you), up (+ = up), right (+ = to your right)
-- Allowed: -0.30 .. 0.30. Saved Games\DCS\Logs\su27radio_fit.log shows
-- the numbers to keep.
-- Check the click boxes too (MFD keys, side unit) - they may only move
-- once the numbers are built into the model.
-- Since test 16 the keypad, the УКВ / КВ knobs and the loader sit on the
-- MFD's side unit: the MFD line moves all of them. LDR / RAD / KP do nothing.

LDR = { forward = 0.00, up = 0.00, right = 0.00 }   -- (unused since test 16)
RAD = { forward = 0.00, up = 0.00, right = 0.00 }   -- (unused since test 16)
KP  = { forward = 0.00, up = 0.00, right = 0.00 }   -- (unused since test 16)
CRD = { forward = 0.00, up = 0.00, right = 0.00 }   -- radio channel card
MFD = { forward = 0.00, up = 0.00, right = 0.00 }   -- the MFD with its side unit
