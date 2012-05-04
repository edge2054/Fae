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

-- Basic starting gear.  Most of this is very rare in the faery realms and very valuable.
newEntity{
    define_as = "BASE_PISTOL",
    slot = "MAINHAND", offslot = "OFFHAND",
	offslot_multiplier = { offense = 0.5, damage = 1 },
    type = "weapon", subtype="gun",
    display = "}", color=colors.SLATE,
	ranged = "gun",
	combat = { sound = "actions/gunshot", sound_miss = "actions/gunshot",},
	rarity = 20,
    weight = 2,
    name = "a generic pistol",
    desc = [[I point, pull the trigger, and things die.  Great ain't it?.]],
}

newEntity{ 
	base = "BASE_PISTOL",
    name = "SIG P228",
    level_range = {1, 50},
    cost = 500,  -- Guns are very expensive in fae
	ammo_type = "9mm", 
	clip_size = 13,
	range_fall_off = 10,
	combat = {
		damage = 10,
	}
}