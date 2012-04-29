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

-- The basic stuff used to damage a grid
setDefaultProjector(function(src, x, y, type, dam)
	local target = game.level.map(x, y, Map.ACTOR)
	if target then
		if src == game.player then
			game.logSeen(target, "I hit %s for %s%0.2f %s damage#LAST#.", target.name, DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		elseif target == game.player then
			game.logSeen(target, "%s hit me for %s%0.2f %s damage#LAST#.", src.name:capitalize(), DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		else
			game.logSeen(target, "%s hits %s for %s%0.2f %s damage#LAST#.", src.name:capitalize(), target.name, DamageType:get(type).text_color or "#aaaaaa#", dam, DamageType:get(type).name)
		end
		local sx, sy = game.level.map:getTileToScreen(x, y)
		if target:takeHit(dam, src) then
			if src == game.player or target == game.player then
				game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Kill!", {255,0,255})
			end
		else
			if src == game.player then
				game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, tostring(-math.ceil(dam)), {0,255,0})
			elseif target == game.player then
				game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, tostring(-math.ceil(dam)), {255,0,0})
			end
		end
		return dam
	end
	return 0
end)

newDamageType{
	name = "physical", type = "PHYSICAL",
}

-- Acid destroys potions
newDamageType{
	name = "acid", type = "ACID", text_color = "#GREEN#",
}
