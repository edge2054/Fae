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

local Talents = require("engine.interface.ActorTalents")

newEntity{
	define_as = "BASE_NPC_goblin",
	type = "humanoid", subtype = "goblin",
	display = "g", color=colors.WHITE,
	desc = [[Ugly and green!]],

	--sound_killed
	--sound_damaged
	--sound_combat

	sound_random = {"monsters/goblins/goblin-%d", 1, 15, vol=0.5},
	
	ai = "dumb_talented_simple", ai_state = { talent_in=3, },
	stats = { offense = 4, defense = 2, damage = 1, armor = 2 },
	body = { INVEN = 10, MAINHAND = 1,},
	
}

newEntity{ base = "BASE_NPC_goblin",
	name = "goblin warrior", color=colors.GREEN,
	level_range = {1, 4}, exp_worth = 1,
	rarity = 4,
	max_life = resolvers.rngavg(5,9),
	equipment = resolvers.equip{
		{type="weapon", subtype="handaxe", name="an old rusty hatchet"},
	},
}

newEntity{ base = "BASE_NPC_goblin",
	name = "armoured goblin warrior", color=colors.AQUAMARINE,
	level_range = {6, 10}, exp_worth = 1,
	rarity = 4,
	max_life = resolvers.rngavg(10,12),
}
