-----------------------------------------------------------------------
-- Su-27 Radio (WW) v0.2: the УКВ / КВ channel windows on ED's radio panel
-- Two 7-segment digits per window, drawn over ED's printed "88" (each
-- digit cell 13.8 x 19.2 mm, its "8" about 7.4 x 14.4 mm in the middle).
-- Values from LDR/ldr_device.lua: RAD_<U|K><1|2><A..G> = 1 lit.
-- Units: 1 = 50 mm (anchors RAD_C/B/R), x right, y up; 0 = midway between
-- the windows (panel mm 5.79, 14.02).
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
SetScale(FOV)

local OX, OY, UNIT = 5.79, 14.02, 50.0
local function u(x_mm, y_mm) return (x_mm - OX) / UNIT, (y_mm - OY) / UNIT end

local function col(r, g, b, a) return MakeMaterial(nil, {r, g, b, a or 255}) end
local SEG  = col(120, 255, 228)
local HALO = col(60, 200, 180, 55)

local n_el = 0
local function poly(pts, mat, param, additive)
	local v, idx = {}, {}
	for i, p in ipairs(pts) do
		local x, y = u(p[1], p[2]); v[i] = {x, y}
	end
	for i = 2, #v - 1 do idx[#idx + 1] = 0; idx[#idx + 1] = i - 1; idx[#idx + 1] = i end
	n_el = n_el + 1
	local e = CreateElement "ceMeshPoly"
	e.name = "rad_" .. n_el
	e.primitivetype = "triangles"
	e.vertices = v
	e.indices = idx
	e.material = mat
	e.init_pos = {0, 0, 0}
	e.additive_alpha = additive or false
	e.use_mipfilter = true
	e.element_params = {param}
	e.controllers = {{"parameter_in_range", 0, 0.5, 1.5}}
	Add(e)
end

-- one segment of a digit centred at (cx, cy); y up (mm)
local DW, DH, T, G, SL = 7.2, 14.2, 1.7, 0.3, 0.07
local function seg_shape(s, cx, cy, grow)
	local l, r, top, mid, bot = cx - DW / 2, cx + DW / 2, cy + DH / 2, cy, cy - DH / 2
	local t = T + (grow or 0)
	local function hseg(x0, x1, y)
		x0, x1 = x0 + G, x1 - G
		return {{x0, y}, {x0 + t / 2, y + t / 2}, {x1 - t / 2, y + t / 2}, {x1, y}, {x1 - t / 2, y - t / 2}, {x0 + t / 2, y - t / 2}}
	end
	local function vseg(x, y0, y1)          -- y0 top, y1 bottom
		y0, y1 = y0 - G, y1 + G
		return {{x, y0}, {x + t / 2, y0 - t / 2}, {x + t / 2, y1 + t / 2}, {x, y1}, {x - t / 2, y1 + t / 2}, {x - t / 2, y0 - t / 2}}
	end
	local p = ({
		a = function() return hseg(l, r, top) end,
		g = function() return hseg(l, r, mid) end,
		d = function() return hseg(l, r, bot) end,
		f = function() return vseg(l, top, mid) end,
		b = function() return vseg(r, top, mid) end,
		e = function() return vseg(l, mid, bot) end,
		c = function() return vseg(r, mid, bot) end,
	})[s]()
	for _, q in ipairs(p) do q[1] = q[1] + SL * (q[2] - cy) end      -- lean right
	return p
end

-- digit cells: УКВ window (inboard) and КВ window (outboard), panel mm
local CELLS = {
	U = {34.86, 48.69},
	K = {-37.11, -23.27},
}
-- (v1.3 test 16: the Su-33 has its own windows on the MFD's side unit, in
-- this same layout, so no Su-33 shift any more)
local SEGS = {"a", "b", "c", "d", "e", "f", "g"}
for w, xs in pairs(CELLS) do
	for d = 1, 2 do
		for _, s in ipairs(SEGS) do
			local prm = "RAD_" .. w .. d .. s:upper()
			poly(seg_shape(s, xs[d], OY, 0.9), HALO, prm, true)
			poly(seg_shape(s, xs[d], OY), SEG, prm)
		end
	end
end
