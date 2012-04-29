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
	-- Set some variables for our flyers
	local hit = false
	local dam = 0
	-- Do we hit?  Is it a crit?
	local successes, crit = self:doOpposedTest(self, target, self.combat.offense, target.combat.defense)
	-- If we hit we resolve damage
	if successes >= 0 then
		hit = true
		local damage = table.clone(self.combat.damage)
		local armor = table.clone(target.combat.armor)
		-- Did we crit?  Bonus damage
		if crit then
			damage.dice = damage.dice + successes
		end
		-- Get the damage
		dam = self:doOpposedTest(self, target, damage, armor)
		-- And apply it
		if dam > 0 then
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, math.max(0, dam), crit)
		end
	end
	
	-- Now do our combat flyers!!
	-- We only call this if the damage is over 0, otherwise the projector will handle it
	if dam == 0 then
		self:doCombatFlyers(self, target, hit)
	end

	-- We use up our own energy
	self:useEnergy(game.energy_to_act)
end

-- Returns a number of successes based on how many dice equal or exceed the target number
-- Dice defaults to 1; Sides to 6, Target Number to 4
function _M:getSuccesses(t)
	local successes = 0
	local dice = t.dice or 1
	local sides = t.sides or 6
	local target_number = t.base_target_number or 4
	for i = 1, dice do
		if rng.dice(1, sides) >= target_number then
			successes = successes + 1
		end
	end
	print(("%s rolling %sd%s against target number %s.  %s successes achieved."):format(self.name:capitalize (), dice, sides, target_number, successes))
	return successes
end

-- This is basically an oppossed dice check
function _M:doOpposedTest(self, target, self_offense, target_defense)
	local attack_roll = self:getSuccesses(self_offense)
	local defense_roll = target:getSuccesses(target_defense)
	local successes = attack_roll - defense_roll
	-- Fudge 0s to bias towards combat resolution
	if successes == 0 then
		successes = 1
	end
	
	-- Does the test crit?
	-- Used for damage resolution
	local crit = false
	if successes > target_defense.dice then
		crit = true
	end
	
	return successes, crit
end

function _M:doCombatFlyers(self, target, hit)
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	if hit then
	if self == game.player and damage <= 0 then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked...", {255,0,255})
		elseif target == game.player and damage <= 0 then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked!", {0, 255, 0})
		end
	elseif self == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Missed...", {255,0,255})
	elseif target == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Dodged!", {0, 255, 0})
	end
end
