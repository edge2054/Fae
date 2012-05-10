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
		-- Bump attacks cost ten actions points
		if self:getActions() >= 10 then
			self:attackTarget(target)
		-- Give the player the chance to do something else if something weird happens
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
function _M:doCombatFlyers(target, flyer)
	-- location of our flyers
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
		
	if type(flyer) == "table" then
		-- Combat Log
		if self == game.player then
			if flyer[1] and flyer[2] then
				game.logPlayer(target, "%s %s/%s my attack.", target.name:capitalize(), flyer[1], flyer[2])
			else
				game.logPlayer(target, "%s %s my attack.", target.name:capitalize(), flyer[1])
			end
		elseif target == game.player then
			if flyer[1] and flyer[2] then
				game.logPlayer(target, "I %s/%s %s's attack.", flyer[1], flyer[2], self.name)
			else
				game.logPlayer(target, "I %s %s's attack.", flyer[1], self.name)
			end
		end
		-- Flyers!!
		if flyer[1] and flyer[2] then
			game.flyers:add(sx, sy, 15, (rng.range(0,2)-1) * 0.5, -3, ("%s/%s"):format(flyer[1], flyer[2]), {200,160,160})
		else
			game.flyers:add(sx, sy, 15, (rng.range(0,2)-1) * 0.5, -3, ("%s"):format(flyer[1]), {200,160,160})
		end
	elseif type(flyer) == "string" then
		if flyer == "Low Action Points" then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, flyer, {255,0,255}, true)
			game.logPlayer("I don't have enough action points to do that.")
		end
	end
end

-- Attack with all available weapons
-- No energy argument is used for talents
function _M:attackTarget(target, no_actions)
	-- Grab our weapons
	local main_hand = self:getWeaponFromSlot("MAINHAND")
	local off_hand = self:getWeaponFromSlot("OFFHAND")

	local flyer = {}
	
	if main_hand or off_hand then
		-- Attack mainhand?
		if main_hand and main_hand.combat then
			local offense_modifier = main_hand.combat.offense or 0
			local damage_modifier = main_hand.combat.damage or 0
			local flyer_main = self:attackTargetWith(target, offense_modifier, damage_modifier, weapon)
			table.insert(flyer, flyer_main)
		end
		-- Attack offhand?
		if off_hand and off_hand.combat then
			local offense_modifier = off_hand.combat.offense or 0
			local damage_modifier = off_hand.combat.damage or 0
			local flyer_off = self:attackTargetWith(target, offense_modifier, damage_modifier, weapon)
			table.insert(flyer, flyer_off)
		end
	else
		-- If we didn't attack with a mainhand or offhand weapon we can always do an unarmed attack
		-- Even if our hands are full (at least for now)
		local flyer_unarmed = self:attackTargetWith(target, offense_modifier, damage_modifier)
		table.insert(flyer, flyer_unarmed)
	end
	
	if flyer[1] then
		self:doCombatFlyers(target, flyer)
	end
	
	if not no_actions then
		self:useActionPoints()
	end
end

-- Attack with one weapon
-- This is the meat of the combat interface
function _M:attackTargetWith(target, offense_modifer, damage_modifier, weapon)
	local flyers

	-- Do we have any passed modifiers from weapons or what not?
	local offense_modifier = offense_modifier or 0
	local damage_modifier = damage_modifier or 0
	
	-- Charge?  Circle?
	if self:attr("moved_this_turn") and self:attr("moved_this_turn") > 0 then
		local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
		if core.fov.distance(self.old_x, self.old_y, target.x, target.y) > 1 then 
			damage_modifier = damage_modifier + self:attr("moved_this_turn")
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, "Charge", {244,221,26})
		else
			offense_modifier = offense_modifier + self:attr("moved_this_turn")
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, "Circle", {244,221,26})
		end
	end
	
	-- Do we hit?  Is it a crit?
	local hit, crit = self:doOpposedTest(target, self:getCombatOffense(target, offense_modifier), target:getCombatDefense())
	
	-- Hit?
	if hit > 0 then
		-- Crit?
		if crit then
			damage_modifier = damage_modifier + hit
		end

		-- Roll for damage
		local dam = self:doOpposedTest(target, self:getCombatDamage(target, damage_modifier), target:getCombatArmor())
		
		-- If we deal damage apply it, otherwise throw out a soak flyer
		if dam > 0 then
			if weapon and weapon.sound_hit then
				game:playSoundNear(self, weapon.sound_hit)
			elseif self.sound_hit then
			else
				game:playSoundNear(self, {"pd/hits/hit%d", 1, 37})
			end
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, dam, crit)
		else
			flyers = "soaked"
		end
	else
		flyers = "dodged"
	end
	
	return flyers
end

-- Special attack functions
-- Cleave foes adjacent to both you and your target
function _M:cleaveTargets(target)
	-- Get adjacent hexes and search for viable targets
	local dir = util.getDir(target.x, target.y, self.x, self.y)
	if dir == 5 then return nil end
	local lx, ly = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).left)
	local rx, ry = util.coordAddDir(self.x, self.y, util.dirSides(dir, self.x, self.y).right)
	local lt, rt = game.level.map(lx, ly, Map.ACTOR), game.level.map(rx, ry, Map.ACTOR)
	local lt_hostile, rt_hostile = false, false
	if lt and self:reactionToward(lt) < 0 then
		lt_hostile = true
	end
	if rt and self:reactionToward(rt) < 0 then
		rt_hostile = true
	end
	
	-- Attack primary target
	self:attackTarget(target, true)
	-- check for viable secondary targets
	if lt_hostile or rt_hostile then
		-- if just one viable target attack it
		if lt_hostile and not rt_hostile then
			self:attackTarget(lt, true)
		elseif rt_hostile and not lt_hostile then
			self:attackTarget(rt, true)
		else
			self:attackTarget(lt, true)
			self:attackTarget(rt, true)
		end
	end
end

-- Combat Offense
function _M:getCombatOffense(target, modifier)
	-- Grab our base
	local pool = self:getOffense()
	if modifier then
		pool = pool + modifier
	end
		
	-- Low on life?  Do last since it's multiplicative
	pool = math.ceil(pool * self:getLifeModifier())
	
	return pool
end
-- Combat Defense
function _M:getCombatDefense()
	-- Grab our base
	local pool = self:getDefense()
	
	return pool
end
-- Combat Damage
function _M:getCombatDamage(target, modifier)
	-- Grab our base
	local pool = self:getDamage()
	if modifier then
		pool = pool + modifier
	end
	
	-- Low on life?  Do last since it's multiplicative
	pool = math.ceil(pool * self:getLifeModifier())
	
	return pool
end
-- Combat Armor
function _M:getCombatArmor()
	-- Grab our base
	local pool = self:getArmor()
	
	return pool
end

--  Oppossed Success Test (sorry Adam, but it's an interface function)
--  Rolls attacker's and target's dice pools
--  Returns net attacker successes and crit (when attacker's successes exceed the target's pool)
function _M:doOpposedTest(target, self_pool, target_pool, get_negative)
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