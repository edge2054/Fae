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
	desc =	{
		"I find myself lost.  A stranger in a strange land.  My only hope is to press forward and find a way home.",
	},
		
	copy = {
		lite = 3,
		life = 20,
		max_life = 20,
		belief = 2,
		reason = 3,
	},
	talents = {
		-- For easy testing; remove later
		[ActorTalents.T_KICK] = 1,
		[ActorTalents.T_ACID_SPRAY] = 1,
	},
	
	body = { INVEN = 10, MAINHAND = 1, OFFHAND = 1, BODY = 1, SHOOTER = 1, AMMO = 1},
}

newBirthDescriptor{
	type = "role",
	name = "Hiker",
	desc =	{
		"While exploring some old trails I stumbled upon an area of forest unlike anything I would have ever imagined",
	},
}

newBirthDescriptor{
	type = "role",
	name = "Hippie",
	desc =	{
		"What a strange trip this has been",
		
		"#GOLD#The hippie
	},
}

newBirthDescriptor{
	type = "role",
	name = "Hunter",
	desc =	{
		"These woods look old and untouched, I can only imagine the game I might find back here.",
	},
}
