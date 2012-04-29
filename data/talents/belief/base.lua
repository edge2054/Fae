-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009, 2010, 2011, 2012 Nicolas Casalini
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
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

newTalentType{ type="belief/base", name = "belief", hide = true, description = "The basic talents that define belief." }

newTalent{
	name = "Belief Pool",
	type = {"belief/base", 1},
	info = "Allows me to have a belief resource pool and manipulate reality with the power of my imagination.",
	mode = "passive",
	hide = true,
	no_unlearn_last = true,
	on_learn = function(self, t)
		local set_belief = self:getReason()
		self:incBelief(-set_belief)
	end,
}