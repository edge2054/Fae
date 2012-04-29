-- Fae
-- Copyright (C) 2012 Eric Wykoff
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Eric Wykoff "edge2054"
-- edge2054@gmail.com


-- These are place holders and need to be re-written
--[=[newEntity{
    define_as = "BASE_BATTLEAXE",
    slot = "MAINHAND",
    slot_forbid = "OFFHAND",
    type = "weapon", subtype="battleaxe",
    display = "/", color=colors.SLATE,
    encumber = 3,
    rarity = 3,
    name = "a generic battleaxe",
    desc = [[t4modules massive two-handed battleaxes.]],
}

newEntity{
	define_as = "BASE_BOW",
	slot = "LAUNCHER",
	type = "weapon", subtype = "ranged",
	display = "}", color=colors.UMBER,
	encumber = 4,
	rarity = 5,
	combat = { sound = "actions/arrow", sound_miss = "actions/arrow",},
	desc = [[Bows are used to shoot arrows at your foes.]],
}

newEntity{
	define_as = "BASE_ARROW",
	slot = "QUIVER",
	type = "ammo", subtype = "arrow",
	display = "{", color=colors.UMBER,
	encumber = 0.03,
	rarity = 11,
	desc = [[Arrows are used with bows to pierce your foes to death.]],
	stacking = true,
}

newEntity{ 
	base = "BASE_BATTLEAXE",
    name = "iron battleaxe",
    level_range = {1, 10},
    require = { stat = { str=10 }, },
    cost = 5,
    combat = {
        dam = 10,
    },
}

newEntity{
	base = "BASE_BOW",
	name = "basic bow",
	level_range = {1, 10},
	require = { stat = { dex=10}, },
	cost = 5,
	combat = {
		dam = 10,
	},
}

newEntity{
	base = "BASE_ARROW",
	name = "wood arrow",
	level_range = {1, 10},
	require = { stat = { dex=10}, },
	cost = 0.05,
	combat = {
		dam = 10,
	},
}]=]