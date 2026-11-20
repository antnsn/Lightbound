-- Lightbound's skins on LibBound: the gold class skin and Lightbound's own Blizzard and Flat
-- versions (kept as they were, so nothing changes for people using them). LibBound turns them
-- into ns.UI, the cards and the option widgets.
local _, ns = ...
if not ns.isPaladin then return end
local Bound = LibStub("LibBound-1.0")

local FRIZ, ARIALN, MORPHEUS = "Fonts\\FRIZQT__.TTF", "Fonts\\ARIALN.TTF", "Fonts\\MORPHEUS.TTF"

local SKINS = {}
SKINS.lightbound = {
	name = "Lightbound",
	-- ui: options text; title: frame titles; narrow: rows, timers, counts; card: reminder cards
	font = { ui = FRIZ, title = FRIZ, narrow = ARIALN, card = MORPHEUS },
	color = {
		-- options and blessings windows
		bg = { 0, 0, 0, 0 },
		side = { 0, 0, 0, 0.35 },
		header = { 0, 0, 0, 0.30 },
		border = { 0.55, 0.42, 0.20, 0.9 },
		hover = { 0.30, 0.22, 0.10, 1 },
		selected = { 0.30, 0.195, 0.085, 1 },
		text = { 0.95, 0.92, 0.85 },
		dim = { 0.72, 0.68, 0.60 },
		accent = { 1.00, 0.82, 0.00 },
		track = { 0.24, 0.18, 0.11, 1 },
		button = { 0.10, 0.075, 0.05, 1 },
		navGlow = { 1, 0.75, 0.25, 0.75 },
		-- small frames (cleanse, requests, overview, cooldowns, DI)
		row = { 0.165, 0.125, 0.082, 0.8 },
		rowWarn = { 0.40, 0.30, 0.05, 0.5 },  -- running low
		rowBad = { 0.45, 0.08, 0.10, 0.55 },  -- missing
		highlight = { 1, 1, 1, 0.08 },
		cell = { 0.16, 0.16, 0.16, 0.85 },  -- cleanse grid: a cell with nothing to remove
		cdText = { 1, 0.9, 0.5 },
		-- proc and tracker icons: the glow behind them (alpha per use)
		glow = { 1, 0.85, 0.3 },
		-- unlock grid
		gridLine = { 1, 1, 1, 0.08 },
		gridCentre = { 1, 0.82, 0, 0.45 },
	},
	-- tooltip-style box for small frames
	box = {
		backdrop = {
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 14,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		},
		bg = { 0.06, 0.045, 0.03 },
		border = { 0.85, 0.68, 0.30, 1 },
	},
	-- the big windows: gold dialog frame and title plate
	dialog = {
		backdrop = {
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 11, top = 12, bottom = 11 },
		},
		outset = 10,
		under = { 0.045, 0.032, 0.02, 1 }, -- the dialog background is see-through on its own
		plate = "Interface\\DialogFrame\\UI-DialogBox-Header",
	},
	tex = {
		check = "Interface\\Buttons\\UI-CheckBox-Up",
		checkMark = "Interface\\Buttons\\UI-CheckBox-Check",
		checkHighlight = "Interface\\Buttons\\UI-CheckBox-Highlight",
		slider = {
			bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
			edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
			tile = true, tileSize = 8, edgeSize = 8,
			insets = { left = 3, right = 3, top = 6, bottom = 6 },
		},
		sliderThumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal",
		navHighlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
		statusbar = "Interface\\TargetingFrame\\UI-StatusBar",
	},
	-- reminder cards on the emblem
	card = {
		panel = { 0.055, 0.043, 0.035, 0.92 },
		gilt = { 0.67, 0.53, 0.24, 1 },
		giltFaint = { 0.47, 0.37, 0.17, 0.9 },
		light = { 1, 0.86, 0.45, 0.09 },
		rays = { 1, 0.84, 0.43 },
		raysFaded = { 0.75, 0.71, 0.63 },
		title = { 1, 0.84, 0.38 },
		status = { 0.92, 0.88, 0.78 },
		urgent = { 1, 0.55, 0.42 },
		glowEdge = { 1, 0.84, 0.38, 1 }, -- edge colour while glowing, for skins without the sunburst
		burst = "Sunburst", studs = "Stud", ring = "Ring", round = true, -- the medallion's ornaments
	},
	-- "blizzard": the game's own buttons, check boxes and sliders; "flat": plain 1px boxes
	widgets = "blizzard",
}

local Derive = Bound.DeriveSkin

-- Classic Blizzard: tooltip and dialog frames in the game's own grey and silver, white text.
SKINS.blizzard = Derive(SKINS.lightbound, {
	name = "Blizzard",
	font = { card = FRIZ },
	color = {
		border = { 0.45, 0.45, 0.45, 0.9 },
		hover = { 0.22, 0.22, 0.24, 1 },
		selected = { 0.20, 0.20, 0.26, 1 },
		text = { 1, 1, 1 },
		dim = { 0.66, 0.66, 0.66 },
		track = { 0.2, 0.2, 0.2, 1 },
		button = { 0.08, 0.08, 0.09, 1 },
		navGlow = { 1, 0.82, 0, 0.55 },
		row = { 0.12, 0.12, 0.14, 0.8 },
		rowWarn = { 0.38, 0.30, 0.04, 0.55 },
		rowBad = { 0.42, 0.06, 0.06, 0.55 },
		cell = { 0.14, 0.14, 0.15, 0.85 },
		cdText = { 1, 1, 1 },
		glow = { 1, 0.82, 0 },
	},
	box = { bg = { 0.04, 0.04, 0.08 }, border = { 0.8, 0.8, 0.8, 1 } },
	dialog = {
		backdrop = {
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 11, top = 12, bottom = 11 },
		},
		under = { 0.02, 0.02, 0.03, 1 },
	},
	card = {
		panel = { 0.04, 0.04, 0.07, 0.92 },
		gilt = { 0.62, 0.62, 0.62, 1 },
		giltFaint = { 0.30, 0.30, 0.32, 0.9 },
		light = { 1, 1, 1, 0.04 },
		rays = { 1, 0.9, 0.6 },
		title = { 1, 0.82, 0 },
		status = { 1, 1, 1 },
		urgent = { 1, 0.35, 0.3 },
		glowEdge = { 1, 0.82, 0, 1 },
		studs = false,
		raysFaded = { 0.75, 0.71, 0.63 },
	},
})

-- Flat: 1px black edges on dark grey, Arial Narrow throughout, gold kept as the one accent.
-- Sits well next to EllesmereUI and ElvUI.
local WHITE = "Interface\\Buttons\\WHITE8x8"
local FLAT_BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
SKINS.flat = Derive(SKINS.lightbound, {
	name = "Flat",
	font = { ui = ARIALN, title = ARIALN, card = ARIALN },
	color = {
		side = { 0, 0, 0, 0.25 },
		header = { 0, 0, 0, 0.25 },
		border = { 0, 0, 0, 1 },
		hover = { 0.22, 0.22, 0.22, 1 },
		selected = { 0.20, 0.20, 0.20, 1 },
		text = { 0.92, 0.92, 0.92 },
		dim = { 0.58, 0.58, 0.58 },
		accent = { 0.96, 0.78, 0.36 },
		track = { 0.16, 0.16, 0.16, 1 },
		button = { 0.13, 0.13, 0.13, 1 },
		navGlow = { 1, 1, 1, 0.06 },
		row = { 0.12, 0.12, 0.12, 0.9 },
		rowWarn = { 0.36, 0.28, 0.04, 0.7 },
		rowBad = { 0.40, 0.05, 0.07, 0.7 },
		highlight = { 1, 1, 1, 0.06 },
		cell = { 0.12, 0.12, 0.12, 0.9 },
		cdText = { 1, 1, 1 },
		glow = { 0.96, 0.78, 0.36 },
	},
	box = { backdrop = FLAT_BACKDROP, bg = { 0.06, 0.06, 0.06 }, border = { 0, 0, 0, 1 } },
	dialog = {
		backdrop = FLAT_BACKDROP,
		outset = 1,
		bg = { 0.06, 0.06, 0.06, 0.97 },
		border = { 0, 0, 0, 1 },
		under = { 0.06, 0.06, 0.06, 1 },
		plate = false,
	},
	tex = {
		slider = FLAT_BACKDROP,
		sliderThumb = WHITE,
		navHighlight = WHITE,
		statusbar = WHITE,
	},
	card = {
		panel = { 0.06, 0.06, 0.06, 0.92 },
		gilt = { 0, 0, 0, 1 },
		giltFaint = { 0.16, 0.16, 0.16, 1 },
		light = { 1, 1, 1, 0 },
		title = { 0.96, 0.78, 0.36 },
		status = { 0.86, 0.86, 0.86 },
		urgent = { 1, 0.4, 0.35 },
		glowEdge = { 0.96, 0.78, 0.36, 1 },
		burst = false, studs = false, ring = false, round = false,
	},
	widgets = "flat",
})

Bound.InstallSkin(ns, {
	skins = SKINS,
	order = { "lightbound", "blizzard", "flat" },
	default = "lightbound",
	about = { lightbound = "Warm gold frames, the emblem cards with their slow light." },
})
Bound.InstallBuffTimers(ns)
Bound.InstallMinimap(ns, {
	rightClick = function() if ns.ToggleRaidWindow then ns.ToggleRaidWindow() end end,
	rightClickText = "Right-click: blessings",
})
