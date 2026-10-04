local wezterm = require("wezterm")

wezterm.on("update-right-status", function(window)
	window:set_right_status(wezterm.format({
		--		{ Attribute = { Intensity = "Bold" } },
		{ Text = wezterm.strftime(" %A, %d %B %Y %I:%M %p ") },
	}))
end)


local config = {
	automatically_reload_config = true,
	color_scheme = "tokyonight",
	window_padding = {
		left = 10,
		right = 10,
		top = 10,
		bottom = 10,
	},
	inactive_pane_hsb = {
		hue = 1.0,
		saturation = 1.0,
		brightness = 1.0,
	},
	line_height = 1.0,
	enable_scroll_bar = true,
	window_decorations = "RESIZE",
	window_close_confirmation = "NeverPrompt",
	tab_bar_at_bottom = true,
	use_fancy_tab_bar = false,
	show_new_tab_button_in_tab_bar = false,
	window_background_opacity = 0.85,
	font_size = 14.0,
	font = wezterm.font 'Fira Code',
	hide_mouse_cursor_when_typing = true,
	--	window_background_image = '/Users/bfh/.config/wezterm/anime.gif',
	window_background_image_hsb = {
		brightness = 0.1,
		hue = 1.0,
		saturation = 0.8,
	},
	launch_menu = {},
	leader = { key="a", mods="CTRL" },
	disable_default_key_bindings = true,
	keys = {
		{ key = "a", mods = "LEADER|CTRL", action=wezterm.action{SendString="\x01"}},
		{ key = "-", mods = "LEADER", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
		{ key = "\\", mods = "LEADER", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
		{ key = "z", mods = "LEADER", action="TogglePaneZoomState"},
		{ key = "c", mods = "LEADER", action=wezterm.action{SpawnTab="CurrentPaneDomain"}},
		{ key = "h", mods = "LEADER", action=wezterm.action{ActivatePaneDirection="Left"}},
		{ key = "j", mods = "LEADER", action=wezterm.action{ActivatePaneDirection="Down"}},
		{ key = "k", mods = "LEADER", action=wezterm.action{ActivatePaneDirection="Up"}},
		{ key = "l", mods = "LEADER", action=wezterm.action{ActivatePaneDirection="Right"}},
		{ key = "H", mods = "LEADER|SHIFT", action=wezterm.action{AdjustPaneSize={"Left", 10}}},
		{ key = "J", mods = "LEADER|SHIFT", action=wezterm.action{AdjustPaneSize={"Down", 10}}},
		{ key = "K", mods = "LEADER|SHIFT", action=wezterm.action{AdjustPaneSize={"Up", 10}}},
		{ key = "L", mods = "LEADER|SHIFT", action=wezterm.action{AdjustPaneSize={"Right", 10}}},
		{ key = "1", mods = "LEADER", action=wezterm.action{ActivateTab=0}},
		{ key = "2", mods = "LEADER", action=wezterm.action{ActivateTab=1}},
		{ key = "3", mods = "LEADER", action=wezterm.action{ActivateTab=2}},
		{ key = "4", mods = "LEADER", action=wezterm.action{ActivateTab=3}},
		{ key = "5", mods = "LEADER", action=wezterm.action{ActivateTab=4}},
		{ key = "6", mods = "LEADER", action=wezterm.action{ActivateTab=5}},
		{ key = "7", mods = "LEADER", action=wezterm.action{ActivateTab=6}},
		{ key = "8", mods = "LEADER", action=wezterm.action{ActivateTab=7}},
		{ key = "9", mods = "LEADER", action=wezterm.action{ActivateTab=8}},
		{ key = "x", mods = "LEADER", action=wezterm.action{CloseCurrentPane={confirm=false}}},
		{ key = "v", mods = "LEADER|SHIFT", action=wezterm.action{PasteFrom="Clipboard"}},
		{ key = "c", mods = "LEADER|SHIFT", action=wezterm.action{CopyTo="ClipboardAndPrimarySelection"}},
	},
	set_environment_variables = {},
}

return config
