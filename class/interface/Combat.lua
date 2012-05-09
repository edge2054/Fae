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

--- Interface to add combat system
module(..., package.seeall, class.make)

--- Checks what to do with the target
--  Talk ? attack ? displace ?
function _M:bumpInto(target)
	local reaction = self:reactionToward(target)
	if reaction < 0 then
		if self:getActions() >= 20 then
			self:doCombatOffense(target)
			self:useActionPoints(20)
		-- Give the player the chance to do something else
		elseif self == game.player then
			self:doCombatFlyers(self, "Low Action Points")
		-- But make the AI end it's turn
		else
			self:useActionPoints(self:getActions())
		end
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

-- We handle all our fancy combat flyers right here
function _M:doCombatFlyers(target, flyer, combat_log)
	-- location of our flyers
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	
	-- And throw them out
	if flyer == "Low Action Points" then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, flyer, {255,0,255}, true)
		game.logPlayer("I don't have enough actions to do that.")
	elseif self == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, ("%s..."):format(flyer), {255,0,255})
		game.logPlayer(target, "%s %s my attack.", target.name:capitalize(), combat_log)
	elseif target == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, ("%s!"):format(flyer), {0, 255, 0})
		game.logPlayer(target, "I %s %s's attack.", , combat_log, self.name)
	end
end

-- Attack with one weapon
function _M:attackTargetWith(target, offense_modifer, damage_modifier)

	-- Do we have any passed modifiers?
	local offense_modifier = offense_modifier or 0
	local damage_modifier = damage_modifier or 0
	
	-- Do we hit?  Is it a crit?
	local hit, crit = self:doOppossedTest(self:getCombatOffense(), target:getCombatDefense())
	
	-- Hit?
	if hit > 0 then
		-- Crit?
		if crit then
			damage_modifier = damage_modifier + hit
		end

		-- Roll for damage
		local dam = self:doOppossedTest(self:getCombatDamage(damage_modifier), target:getCombatArmor())
		
		-- If we deal damage apply it, otherwise throw out a soak flyer
		if dam > 0 then
			DamageType:get(DamageType.PHYSICAL).projector(src, self.x, self.y, DamageType.PHYSICAL, dam, crit)
		else
			self:doCombatFlyers(target, "Soaked", "soaked")
		end
	else
		-- If we miss, throw out a miss flyer
		self:doCombatFlyers(target, "Missed", "missed")
	end
	
end

-- Attack chain
function _M:getCombatOffense(modifier)
	-- Grab our base
	local pool = self:getOffense()
	
	-- Low on life?  Do last since it's multiplicative
	pool = math.ceil(pool * self:getLifeModifier())
	
	return pool
end

function _M:getCombatDefense()
	-- Grab our base
	local pool = self:getDefense()
	
	return pool
end

function _M:doCombatDamage(modifier)
	-- Grab our base
	local pool = self:getDamage()
	
	-- Low on life?  Do last since it's multiplicative
	pool = math.ceil(pool * self:getLifeModifier())
	
	return pool
end

function _M:doCombatArmor()
	-- Grab our base
	local pool = self:getArmor()
	
	return pool
end

--  Oppossed Success Test (sorry Adam, but it's an interface function)
--  Rolls attacker's and target's dice pools
--  Returns net attacker successes and crit (when attacker's successes exceed the target's pool)
function _M:doOpposedTest(self_pool, target_pool, get_negative)
	-- Roll some computer dice just to make Grey Happy!
	local self_successes = self:doSuccessTest(self_pool)
	local target_successes = target:doSuccessTest(target_pool)
	
	-- Compare our results
	local net_successes = self_successes - target_successes
	
	-- Fudge ties towards the attacker for faster combat resolution
	if self_successes > 1 and net_successes == 0 then
		net_successes = 1
	end
	
	-- Does the test crit?
	-- Used for damage resolution
	local crit = false
	if self_successes > target_pool then
		crit = true
	end
	
	-- ensures we only return positive values or 0
	-- if we need a negative we'll have to pass the method the get_negative argument
	if not get_negative then
		net_successes = math.max(0, net_successes)
	end
	
	-- Alright, return our net dice and if we landed a crit
	return net_successes, crit
end