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

function _M:doCombatFlyers(target, flyer)
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	
	if flyer == "Low Action Points" then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, flyer, {255,0,255}, true)
		game.logPlayer("I don't have enough actions to do that.")
	elseif self == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, ("%s..."):format(flyer), {255,0,255})
		game.logPlayer(target, "%s dodged my attack.", target.name:capitalize())
	elseif target == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, ("%s!"):format(flyer), {0, 255, 0})
		game.logPlayer(target, "I dodged %s's attack.", self.name)
	end
end

-- Attack chain
function _M:doCombatOffense(target, modifier)
	-- get our base pool
	local pool = self:getOffense() + (modifier or 0)
	-- Penalty for being wounded?  Multiplicative so do last
	pool = math.ceil(pool * self:getLifeModifier())
	local successes = self:doSuccessTest(pool)
	if successes > 0 then
		target:doCombatDefense(self, successes)
	else
		self:doCombatFlyers(target, "Missed")
	end
end

function _M:doCombatDefense(src, opposed)
	local pool = self:getDefense()
	local successes = self:doSuccessTest(pool)
	local net_successes = (oppossed and oppossed - successes) or successes
	-- hit? Ties go to the attacker
	if net_successes >= 0 then
		-- crit?
		if net_successes > pool then
			src:doCombatDamage(self, net_succeses)
		else
			src:doCombatDamage(self)
		end
	else
		src:doCombatFlyers(self, "Missed")
	end
end

function _M:doCombatDamage(target, modifier)
	local pool = self:getDamage() + (modifier or 0)
	local successes = self:doSuccessTest(pool)
	if successes > 0 then
		-- did we crit earlier?
		local crit = false
		if modifier then
			crit = true
		end
		target:doCombatArmor(self, successes, crit)
	else
		self:doCombatFlyers(target, "Soaked")
	end
end

function _M:doCombatArmor(src, opposed, crit)
	local pool = self:getArmor()
	local successes = self:doSuccessTest(pool)
	local net_successes = (oppossed and oppossed - successes) or successes
	-- hit? Ties go to the attacker
	if net_successes > 0 then
		DamageType:get(DamageType.PHYSICAL).projector(src, self.x, self.y, DamageType.PHYSICAL, net_successes, crit)
	else
		src:doCombatFlyers(self, "Soaked")
	end
end