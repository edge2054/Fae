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

-- We do our damage flyers and log here to keep setDefaultProjector clean(ish)
local function doDamageFlyers(src, x, y, type, dam, crit)
	local target = game.level.map(x, y, Map.ACTOR)
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	
	if target then
		local hit_type = "hit"
		if crit then hit_type = "crit" end
		if src == game.player then
			game.logSeen(target, "I %s %s for %s%d %s#LAST# damage.", hit_type, target.name, DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		elseif target == game.player then
			game.logSeen(target, "%s %s me for %s%d %s#LAST# damage.", src.name:capitalize(), hit_type, DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		else
			game.logSeen(target, "%s %s %s for %s%d %s#LAST# damage.", src.name:capitalize(), hit_type, target.name, DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		end
	
		if target:takeHit(dam, src) then
			if src == game.player or target == game.player then
				game.flyers:add(sx, sy, 45, (rng.range(0,2)-1) * 0.5, -3, "Kill("..tostring(-math.ceil(dam))..")", {200,10,10}, true)
				game.flyers:add(sx, sy, 100, (rng.range(0,2)-1) * 0.5, -3, "+"..tostring(target:worthExp(src)).." XP", {244,221,26})
			end
		elseif crit then
			if src == game.player or target == game.player then
				game.flyers:add(sx, sy, 45, (rng.range(0,2)-1) * 0.5, -3, "Crit("..tostring(-math.ceil(dam))..")", {200,10,10}, true)
			end
		else
			if src == game.player or target == game.player  then
				game.flyers:add(sx, sy, 45, (rng.range(0,2)-1) * 0.5, -3, tostring(-math.ceil(dam)), {188,11,49}, true)
			end
		end
	end
end

-- The basic stuff used to damage a grid
setDefaultProjector(function(src, x, y, type, dam, crit)
	local target = game.level.map(x, y, Map.ACTOR)
	if target then
		doDamageFlyers(src, x, y, type, dam, crit)
		return dam
	end
	return 0
end)

newDamageType{
	name = "physical", type = "PHYSICAL",
}

newDamageType{
	name = "acid", type = "ACID", text_color = "#GREEN#",
}
