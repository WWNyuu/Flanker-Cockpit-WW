-----------------------------------------------
-- Su-27 Radio (WW) 1.3 - data loader plate (ВВОД ДАННЫХ), УКВ / КВ radio panel (channel and volume), channel card and MFD for the
-- Flaming Cliffs Su-27 / J-11A. Hooks into the jet the same way the
-- F-15C SIT (WW) add-on hooks into the F-15C: add_plugin_systems().
-----------------------------------------------

declare_plugin("su27_radio",
{
	installed        = true,
	dirName          = current_mod_path,
	displayName      = _("Su-27 Radio (WW)"),
	shortName        = "su27_radio",
	fileMenuName     = "su27_radio",
	version          = "1.3.0",
	state            = "installed",
	developerName    = "nyuu",
	info             = "Data loader plate, radio presets and a retrofit MFD for the Flaming Cliffs Su-27",
	binaries         = {},
	load_immediately = true,
	Options =
	{
		{
			name   = _("Su-27 Radio"),
			nameId = "su27_radio",
			dir    = "Options",
		},
	},
})

mount_vfs_texture_path(current_mod_path .. "/Textures")
mount_vfs_model_path  (current_mod_path .. "/Shapes")

-- Adds this mod's Cockpit/Scripts to the Su-27's (and J-11A's) own
-- cockpit. The checkbox in Options > Special > Su-27 Radio switches it on/off.
add_plugin_systems('su27_radio', '*', current_mod_path .. '/Cockpit/Scripts/',
{
	["Su-27"] = { enable_options_key_for_unit = "su27_radio_enabled" },
	["J-11A"] = { enable_options_key_for_unit = "su27_radio_enabled" },
	-- v1.3 test 8: the Su-33 (own cockpit model; the Su-27 model is loaded as a first test)
	["Su-33"] = { enable_options_key_for_unit = "su27_radio_enabled" },
})

plugin_done()
