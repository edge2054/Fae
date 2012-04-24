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

local Entity = require "engine.Entity"

local oldNewTalent = Talents.newTalent
Talents.newTalent = function(self, t)
	assert(engine.interface.ActorTalents.talents_types_def[t.type[1]], "No talent category "..tostring(t.type[1]).." for talent "..t.name)

	if not t.image then
		t.image = "talents/"..(t.short_name or t.name):lower():gsub("[^a-z0-9_]", "_")..".png"
	end
	if fs.exists("/data/gfx/"..t.image) then t.display_entity = Entity.new{image=t.image, is_talent=true}
	else t.display_entity = Entity.new{image="talents/default.png", is_talent=true}
	end
	return oldNewTalent(self, t)
end

newTalentType{ type="role/combat", name = "combat", description = "Combat techniques" }

newTalent{
	name = "Kick",
	type = {"role/combat", 1},
	points = 1,
	cooldown = 6,
	power = 2,
	range = 1,
	action = function(self, t)
		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		target:knockback(self.x, self.y, 2 + self:getDex())
		return true
	end,
	info = function(self, t)
		return "Kick!"
	end,
}

newTalent{
	name = "Acid Spray",
	type = {"role/combat", 1},
	points = 1,
	cooldown = 6,
	power = 2,
	range = 6,
	action = function(self, t)
		local tg = {type="ball", range=self:getTalentRange(t), radius=1, talent=t}
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		self:project(tg, x, y, DamageType.ACID, 1 + self:getDex(), {type="acid"})
		return true
	end,
	info = function(self, t)
		return "Zshhhhhhhhh!"
	end,
}

