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

local loadIfNot = function(f)
	if loaded[f] then return end
	load(f, entity_mod)
end

-- Misc
loadIfNot("/data/general/objects/starting-gear.lua")

-- These are place holders and need to be re-written
newEntity{
    define_as = "BASE_HANDAXE",
    slot = "MAINHAND", offslot = "OFFHAND",
    --slot_forbid = "OFFHAND",
    type = "weapon", subtype="handaxe",
    display = "/", color=colors.SLATE,
  --  encumber = 3,
    rarity = 3,
	combat = { sound_hit = {"weapons/swing-%d", 1, 3, vol=1}},
    name = "a generic handaxe",
    desc = [[A basic hand-axe.]],
}

newEntity{ 
	base = "BASE_HANDAXE",
    name = "an old rusty hatchet",
	display = "/", color= {r=172, g=56, b=56},
    level_range = {1, 10},
    cost = 5,
    combat = {
		offense = 0,
		damage = 4,
    },
}