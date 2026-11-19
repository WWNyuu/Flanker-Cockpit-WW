-----------------------------------------------------------------------
-- Su-27 MFD (WW) 1.3 MFI: SA page additions (as the MiG-29 MFI SA): IAS /
-- GS box top left, heading box top middle, altitude box top right, the
-- range (green) under it, the steerpoint under that, the intercept block
-- (left 3 INTC) and short messages. The scope itself (rings, contacts,
-- route, bullseye) is mfd_page.lua's SA page, in the MFI colours.
-----------------------------------------------------------------------
function S27MFI_SA_PAGE(D, U)
	local K, MK, T, S, N, box = U.K, U.MK, U.T, U.S, U.N, U.box
	local r = "mf_sa"
	D.simple(r, "sit_root", {0, 0, 0}, {"S27MFD_PAGE"}, {D.vis(0, SIT.PG.SIT - 0.5, SIT.PG.SIT + 0.5)})
	local TB = U.TXM
	local Y1, Y2 = 0.655, 0.585
	-- paper under the boxes (the scope runs under them)
	local function bg(n, x0, y0, x1, y1) U.rect(r, n, x0, y0, x1, y1, MK.paper) end
	bg("bg_l", -0.755, 0.545, -0.34, 0.695)
	box(r, "box_l", -0.5475, 0.62, 0.415, 0.15, MK.black)
	T(r, "ias", -0.74, Y1, "SA_IAS", K.black, TB)
	T(r, "gs", -0.74, Y2, "SA_GS", K.black, TB)
	-- heading box: only with the jet in the middle (decentred: the box on
	-- the arc's top, mfd_mfi_scope.lua), as the MiG-29 MFI
	D.simple(r .. "_hc", r, {0, 0, 0}, {"S27MFD_CENTER"}, {D.vis(0, 0.5, 1.5)})
	U.rect(r .. "_hc", "bg_h", -0.13, 0.585, 0.13, 0.695, MK.paper)
	box(r .. "_hc", "box_h", 0, 0.64, 0.26, 0.11, MK.black)
	N(r .. "_hc", "hdg", 0, 0.64, "SA_HDG", K.black, U.TXL, "CenterCenter", nil, "%03.0f")
	bg("bg_a", 0.34, 0.585, 0.755, 0.695)
	box(r, "box_a", 0.5475, 0.64, 0.415, 0.11, MK.black)
	T(r, "alt", 0.74, 0.6425, "SA_ALT", K.black, TB, "RightCenter")
	-- range scale: dark green, thick font, x 1.2 (MiG-29 MFI round 27)
	T(r, "rng", 0.745, 0.52, "SA_RNG", U.KB.dkgreen, U.TRNG, "RightCenter")
	T(r, "wp1", 0.745, 0.435, "SA_WP1", K.cyan, U.TXC, "RightCenter")
	T(r, "wp2", 0.745, 0.375, "SA_WP2", K.cyan, U.TXC, "RightCenter")
	-- intercept block (left 3 INTC on): the target, then heading / time
	D.simple(r .. "_ic", r, {0, 0, 0}, {"S27MFD_M_INTC"}, {D.vis(0, 0.5, 1.5)})
	U.rect(r .. "_ic", "bg", -0.755, -0.40, -0.20, -0.24, MK.paper)
	box(r .. "_ic", "box", -0.4775, -0.32, 0.555, 0.16, MK.red)
	T(r .. "_ic", "t1", -0.74, -0.28, "SA_INTC1", K.red, U.TXC)
	T(r .. "_ic", "t2", -0.74, -0.355, "SA_INTC2", K.black, U.TXC)
	-- message (MARK / DEL / NEXT / RNG ...), a moment
	D.simple(r .. "_ms", r, {0, 0, 0}, {"S27MFD_M_SA_TOASTON"}, {D.vis(0, 0.5, 1.5)})
	U.rect(r .. "_ms", "bg", -0.36, 0.25, 0.36, 0.33, MK.paper)
	box(r .. "_ms", "box", 0, 0.29, 0.72, 0.08, MK.amber)
	T(r .. "_ms", "t", 0, 0.29, "SA_TOAST", K.amber, U.TXC, "CenterCenter")
end
