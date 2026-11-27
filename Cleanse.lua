-- Cleanse (LibBound Cleanse.lua): group members carrying a debuff you can remove, one click each,
-- plus a mouseover cleanse key. Cleanse removes Poison, Disease and Magic; Purify only Poison and
-- Disease. The best one you know is used. The frame, the options page and `/lb ignore` are LibBound's.
local _, ns = ...
if not ns.isPaladin then return end -- not a paladin: load nothing (see Core.lua)
local Bound = LibStub("LibBound-1.0")

Bound.InstallCleanse(ns, {
	title = "Cleanse",
	buttons = {
		{ list = { 1152, 4987 }, -- Purify, Cleanse
			types = { { Poison = true, Disease = true }, { Poison = true, Disease = true, Magic = true } } },
	},
})
