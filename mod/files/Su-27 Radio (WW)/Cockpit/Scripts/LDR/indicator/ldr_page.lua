-----------------------------------------------------------------------
-- Su-27 Radio (WW): what lights up on the loader plate
--   * В РАБОТЕ window: two 7-segment VFD digits (blue-green, like the
--     Soviet IV tubes), unlit segments faintly visible
--   * ГОТОВ / ОТКАЗ lamps: glow over the lenses
--   * LDR.ALIGN_TEST: a frame along the plate edges + a corner marker
-- Values from LDR/ldr_device.lua as parameters LDR_*.
-- Units: 1 = 82.5 mm (half the plate width), x right, y up, 0 = plate centre.
-----------------------------------------------------------------------
dofile(LockOn_Options.common_script_path .. "elements_defs.lua")
dofile(LockOn_Options.script_path .. "LDR/ldr_config.lua")
SetScale(FOV)

local function col(r, g, b, a) return MakeMaterial(nil, {r, g, b, a or 255}) end
local M = {
	ghost   = col(5, 10, 9),       -- unlit segments: DCS draws them much brighter than they read here
	seg     = col(120, 255, 228),
	seg_halo = col(60, 200, 180, 60),
	go      = col(120, 255, 120, 235),
	go_halo = col(60, 255, 60, 70),
	nogo    = col(255, 70, 50, 235),
	nogo_halo = col(255, 40, 20, 70),
	align   = col(255, 0, 255, 220),
}

local n_el = 0
local function poly(pts_mm, mat, param, additive)
	-- convex polygon (plate mm) -> triangle fan
	local v, idx = {}, {}
	for i, p in ipairs(pts_mm) do
		local x, y = LDR.u(p[1], p[2])
		v[i] = {x, y}
	end
	for i = 2, #v - 1 do
		idx[#idx + 1] = 0; idx[#idx + 1] = i - 1; idx[#idx + 1] = i
	end
	n_el = n_el + 1
	local e = CreateElement "ceMeshPoly"
	e.name = "ldr_" .. n_el
	e.primitivetype = "triangles"
	e.vertices = v
	e.indices = idx
	e.material = mat
	e.init_pos = {0, 0, 0}
	e.additive_alpha = additive or false
	e.use_mipfilter = true
	if param then
		e.element_params = {param}
		e.controllers = {{"parameter_in_range", 0, 0.5, 1.5}}
	end
	Add(e)
	return e
end

local function disc(cx, cy, r, mat, param, additive)
	local pts = {}
	for i = 0, 23 do
		local a = 2 * math.pi * i / 24
		pts[#pts + 1] = {cx + r * math.cos(a), cy + r * math.sin(a)}
	end
	return poly(pts, mat, param, additive)
end

---------------------------------------------------------------------------
-- window digits
---------------------------------------------------------------------------
local DW, DH, T, G, SL = 6.4, 11.4, 1.3, 0.25, 0.08     -- digit width / height, stroke, gap, slant
local function seg_shape(s, cx, cy, grow)
	local l, r, top, mid, bot = cx - DW / 2, cx + DW / 2, cy - DH / 2, cy, cy + DH / 2
	local t = T + (grow or 0)
	local function hseg(x0, x1, y)
		x0, x1 = x0 + G, x1 - G
		return {{x0, y}, {x0 + t / 2, y - t / 2}, {x1 - t / 2, y - t / 2}, {x1, y}, {x1 - t / 2, y + t / 2}, {x0 + t / 2, y + t / 2}}
	end
	local function vseg(x, y0, y1)
		y0, y1 = y0 + G, y1 - G
		return {{x, y0}, {x + t / 2, y0 + t / 2}, {x + t / 2, y1 - t / 2}, {x, y1}, {x - t / 2, y1 - t / 2}, {x - t / 2, y0 + t / 2}}
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
	for _, q in ipairs(p) do q[1] = q[1] + SL * (cy - q[2]) end      -- lean right, like the tubes
	return p
end

local WX, WY = LDR.WIN[1], LDR.WIN[2]
local DIGIT_X = {WX - 5.4, WX + 5.4}
local SEGS = {"a", "b", "c", "d", "e", "f", "g"}
for d = 1, 2 do
	for _, s in ipairs(SEGS) do poly(seg_shape(s, DIGIT_X[d], WY), M.ghost) end
end
for d = 1, 2 do
	for _, s in ipairs(SEGS) do
		local prm = "LDR_S" .. d .. s:upper()
		poly(seg_shape(s, DIGIT_X[d], WY, 0.9), M.seg_halo, prm, true)
		poly(seg_shape(s, DIGIT_X[d], WY), M.seg, prm)
	end
end

---------------------------------------------------------------------------
-- lamps
---------------------------------------------------------------------------
local R = LDR.LAMP_R
disc(LDR.LAMP_GO[1], LDR.LAMP_GO[2], R * 1.9, M.go_halo, "LDR_GO", true)
disc(LDR.LAMP_GO[1], LDR.LAMP_GO[2], R * 0.95, M.go, "LDR_GO")
disc(LDR.LAMP_NOGO[1], LDR.LAMP_NOGO[2], R * 1.9, M.nogo_halo, "LDR_NOGO", true)
disc(LDR.LAMP_NOGO[1], LDR.LAMP_NOGO[2], R * 0.95, M.nogo, "LDR_NOGO")

---------------------------------------------------------------------------
-- alignment test: frame 1 mm inside the plate edges, triangle in the
-- top-left corner (if the triangle shows top-RIGHT or bottom-left, the
-- indicator is mirrored)
---------------------------------------------------------------------------
local W_, H_, L = LDR.PW, LDR.PH, 0.5
poly({{1, 1}, {W_ - 1, 1}, {W_ - 1, 1 + L}, {1, 1 + L}}, M.align, "LDR_ALIGN")
poly({{1, H_ - 1 - L}, {W_ - 1, H_ - 1 - L}, {W_ - 1, H_ - 1}, {1, H_ - 1}}, M.align, "LDR_ALIGN")
poly({{1, 1}, {1 + L, 1}, {1 + L, H_ - 1}, {1, H_ - 1}}, M.align, "LDR_ALIGN")
poly({{W_ - 1 - L, 1}, {W_ - 1, 1}, {W_ - 1, H_ - 1}, {W_ - 1 - L, H_ - 1}}, M.align, "LDR_ALIGN")
poly({{2, 2}, {14, 2}, {2, 14}}, M.align, "LDR_ALIGN")
