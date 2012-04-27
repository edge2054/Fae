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

newBirthDescriptor{
	type = "base",
	name = "base",
	desc = {
	},
		
	copy = {
		lite = 3,
		max_life = 100,
		max_rage = 100,
		life_regen = 1,
		desc = "I find myself lost.  A stranger in a strange land.  My only hope is to press forward and find a way home.",
	},
	body = { INVEN = 10, MAINHAND = 1, OFFHAND = 1, BODY = 1, LAUNCHER = 1, QUIVER = 1},
}

newBirthDescriptor{
	type = "role",
	name = "Rogue",
	desc =
	{
		"I find myself lost.  A stranger in a strange land.  My only hope is to press forward and find a way home.",
	},
}
