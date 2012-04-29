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

require "engine.class"
local DamageType = require "engine.DamageType"
local Map = require "engine.Map"
local Target = require "engine.Target"
local Talents = require "engine.interface.ActorTalents"

--- Interface to add ToME combat system
module(..., package.seeall, class.make)

--- Checks what to do with the target
-- Talk ? attack ? displace ?
function _M:bumpInto(target)
	local reaction = self:reactionToward(target)
	if reaction < 0 then
		return self:attackTarget(target)
	elseif reaction >= 0 then
		if self.move_others then
			-- Displace
			game.level.map:remove(self.x, self.y, Map.ACTOR)
			game.level.map:remove(target.x, target.y, Map.ACTOR)
			game.level.map(self.x, self.y, Map.ACTOR, target)
			game.level.map(target.x, target.y, Map.ACTOR, self)
			self.x, self.y, target.x, target.y = target.x, target.y, self.x, self.y
		end
	end
end

--- Makes the death happen!
function _M:attackTarget(target, mult)
	-- For our flyers
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	-- Check hit
	local successes = self:checkHit(self, target)
	if successes >= 0 then
		local dam = self:getDamage(self, target, successes)
		if dam > 0 then
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, math.max(0, dam))
		elseif self == game.player then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked...", {255,0,255})
		elseif target == game.player then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked!", {0, 255, 0})
		end
	elseif self == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Missed...", {255,0,255})
	elseif target == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Dodged!", {0, 255, 0})
	end
		
	-- We use up our own energy
	self:useEnergy(game.energy_to_act)
end

function _M:checkHit(self, target)
	local attack_roll = self:getSuccesses(self:getOffense())
	local defense_roll = target:getSuccesses(target:getDefense())
	local successes = attack_roll - defense_roll
	return successes
end

function _M:getDamage(self, target, hit_bonus)
	local damage_dice = self:getOffense() + hit_bonus
	local damage_roll = self:getSuccesses(damage_dice) 
	local armor_dice = target:getArmor()
	local armor_roll = target:getSuccesses(armor_dice)
	local damage = math.max(0, damage_roll - armor_roll)
	return damage
end				

function _M:getSuccesses(dice, sides, target_number)
	local successes = 0
	local dice = dice or 1
	local sides = sides or 6
	local target_number = target_number or sides/2 + 1
	for i = 1, dice do
		if rng.dice(1, sides) >= target_number then
			successes = successes + 1
		end
	end
	print(("[ROLLING] %sd%s against target number %s, successes %s"):format(dice, sides, target_number, successes))
	return successes
end
