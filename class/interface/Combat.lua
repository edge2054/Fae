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

--[[Fae Combat System
	Fae's combat system revolves around successes.  Virtually everything is an oppossed roll between the attacker and the targets dice pools.
	Primarily Offense vs. Defense, Damage vs. Armor, and Dreaming vs. Reason.
	Offense vs. Defense can crit if the number of successes is greater than the defense pool resulting in extra dice being added to the Damage vs. Armor check.
	Dice that roll 10 or higher also explode, being rolled once more and adding to the success total (up to a maximum number of successes equal to the pool size).
	In order to bias the game towards combat resolution oppossed rolls which result in a tie (0 net successes) will fudge the roll and return 1 success.
	Generally dice are rolled as (pool size)d10 against a target of 6 but these numbers can be modified (though effects that do so are extremely rare).
]]

--- Checks what to do with the target
--  Talk ? attack ? displace ?
function _M:bumpInto(target)
	local reaction = self:reactionToward(target)
	if reaction < 0 then
		-- Cleave targets if we have enough action points
		if self:getActions() >= 2 then
			return self:cleaveTargets(target)
		else
			return self:attackTarget(target)
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

-- Cleave if we have enough action points
-- Attacks foes adjacent to both you and your target
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
	
	-- Attack hostile targets
	self:attackTarget(target, true)
	if self:getActions() / 2 >= 2 then
		if lt_hostile then
			self:attackTarget(lt, true)
		end
		if rt_hostile then
			self:attackTarget(rt, true)
		end
	else
		if lt_hostile and rng.chance(2) then
			self:attackTarget(lt, true)
		elseif rt_hostile then
			self:attackTarget(rt, true)
		end
	end
	
	self:useEnergy(game.energy_to_act)
end

-- Attack with all available weapons
function _M:attackTarget(target, no_energy)
	local successes, dam
	local mainhand, offhand
	-- Kinda sloppy but we pass the string and recall getWeaponFromSlot later instead of passing the whole weapon
	-- This is so we can ask later if the weapon is in the offhand without passing another argument
	if self:getWeaponFromSlot("MAINHAND") then
		successes, crit, dam = self:attackTargetWith(target, "MAINHAND")
		mainhand = true
	end
	if self:getWeaponFromSlot("OFFHAND") then
		successes, crit, dam = self:attackTargetWith(target, "OFFHAND")
		offhand = true
	end
	-- If we didn't attack with a mainhand or offhand weapon we can always do an unarmed attack
	-- Even if our hands are full (at least for now)
	if not (mainhand or offhand) then
		successes, crit, dam = self:attackTargetWith(target)
	end
	
	if not no_energy then
		self:useEnergy(game.energy_to_act)
	end
	return successes, crit, dam
end

-- Attack with one weapon
function _M:attackTargetWith(target, weapon_slot)
	-- Set some variables for our flyers
	local dam = 0
	-- Do we hit?  Is it a crit?
	local offense_pool, defense_pool = self:getDicePool(target, "offense", weapon_slot), target:getDicePool(self, "defense")
	local successes, crit = self:doOpposedTest(self, target, offense_pool, defense_pool)
	-- If we hit we resolve damage
	if successes >= 0 then
		local damage_pool, armor_pool = self:getDicePool(target, "damage", weapon_slot), target:getDicePool(self, "armor")
		-- Did we crit?  Bonus damage
		if crit then
			damage_pool.dice = damage_pool.dice + successes
		end
		-- Get the damage as a number
		dam = self:doOpposedTest(self, target, damage_pool, armor_pool)
		-- And apply it
		if dam > 0 then
			DamageType:get(DamageType.PHYSICAL).projector(self, target.x, target.y, DamageType.PHYSICAL, dam, crit)
		end
	end
	
	-- Now do our  flyers!!
	-- We only call this if the damage is over 0, otherwise the projector handles it
	if dam == 0 then
		self:doCombatFlyers(target, successes)
	end

	-- We use up our own energy
--	self:useEnergy(game.energy_to_act)
	return successes, crit, dam
end

-- Converts actor stats into a table to pass easily to other functions
function _M:getDicePool(actor, stat, weapon_slot)
	local define_pool = {
		-- Get Combat Modified Stats; these functions return table values
		offense		=	self:getCombatOffense(actor, weapon_slot),
		defense		=	self:getCombatDefense(actor),
		armor		= 	self:getCombatArmor(actor),
		damage		=	self:getCombatDamage(actor, weapon_slot),
		dreaming	= 	self:getCombatDreaming(actor), 
		reason		=	self:getCombatReason(actor),
	}
	return define_pool[stat]
end

--- Dice Functions
--- Basic Success Test
--  Returns a number of successes based on how many dice equal or exceed the target number
-- 	Dice that roll 10 or higher are rolled again, potentially producing more successes but no more then the base pool size
function _M:doSuccessTest(t)
	local successes = 0
	local dice = t.dice or 1
	local sides = t.sides or 10
	local target_number = 6 + (t.modifier or 0)
--	print(("%s rolling %dd%d dice..."):format(self.name:capitalize(), t.dice, t.sides))
	while dice > 0 and successes < t.dice do
		local roll = rng.dice(1, sides)
	--	print("Roll: ", roll)
		if roll >= target_number then
			successes = successes + 1
		end
		if roll < 10 then
			dice = dice - 1
		else
	--		print("A die exploded and was added back into the pool!")
		end
	--	print("Dice Left: ", dice)
	end
	
	print(("%s rolled %dd%d against target number %d.  %d successes achieved."):format(self.name:capitalize(), t.dice, sides, target_number, successes))
	return successes
end

--- Oppossed Success Test
--  Rolls attacker's and target's dice pools
--  Returns net attacker successes and crit (when attacker's net successes exceed the target's pool)
function _M:doOpposedTest(self, target, self_pool, target_pool, get_negative)
	local self_successes = self:doSuccessTest(self_pool)
	local target_successes = target:doSuccessTest(target_pool)
	local net_successes = self_successes - target_successes
	
	-- Fudge ties towards success to bias combat towards resolution
	if self_successes > 1 and net_successes == 0 then
		net_successes = 1
	end
	
	-- Does the test crit?
	-- Used for damage resolution
	local crit = false
	if net_successes > target_pool.dice then
		crit = true
	end
	
	-- ensures we only return positive values or 0
	-- if we need a negative we'll have to pass the method the get_negative argument
	if not get_negative then
		net_successes = math.max(0, net_successes)
	end
	
	return net_successes, crit
end

--- Total Dice Roll
--  This is just a short cut and doesn't do anything rng.dice doesn't
--  Rolls a dice pool and returns the sum
function _M:doTotalDiceRoll(pool)
	return rng.dice(pool.dice, pool.sides)
end

-- Gets a weapon from a slot, takes a string and returns the weapon table
function _M:getWeaponFromSlot(weapon_slot)
	if not weapon_slot or not self:getInven(weapon_slot) then return end
	local weapon = self:getInven(weapon_slot)[1]
	if not weapon or not weapon.combat then
		return nil
	end
	return weapon
end

-- Combat Modified stat calls; returns a table
-- Most combat modifiers should be calculated here.
-- Offense
function _M:getCombatOffense(target, weapon_slot)
	-- Base values
	local dice = self:getOffense()
	local sides = self.offense_sides
	local modifier = self.offense_modifier
	
	-- Using a weapon?
	local weapon = self:getWeaponFromSlot(weapon_slot)
	
	-- Action Point modifiers?
	local action_modifier = self:getMaxActions() - self:getActions()
	
	-- Weapon modifiers
	if weapon then
		weapon = weapon.combat
		if weapon.offense_bonus then
			dice = dice + weapon.offense_bonus
		elseif weapon.offense then
			dice = weapon.offense
		end
	end
	
	-- Charge/Circle modifiers
	-- Did we move this turn?
	if (self.old_x ~= self.x or self.old_y ~= self.y) and action_modifier > 0 then
		-- Was it a charge? (Harder to hit)
		if core.fov.distance(self.old_x, self.old_y, target.x, target.y) > 1 then 
			modifier = modifier + action_modifier
		else
			-- If not charge, circle (for easier hit)
			modifier = modifier - action_modifier
		end	
	end
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

-- Defense
function _M:getCombatDefense(src)
	-- Base values
	local dice = self:getDefense()
	local sides = self.defense_sides
	local modifier = self.defense_modifier
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

-- Damage
function _M:getCombatDamage(target, weapon_slot)
	-- Base values
	local dice = self:getDamage()
	local sides = self.damage_sides
	local modifier = self.damage_modifier
	
	-- Using a weapon?
	local weapon = self:getWeaponFromSlot(weapon_slot)
	
	-- Action Point modifiers?
	local action_modifier = self:getMaxActions() - self:getActions()
	
	-- Weapon modifiers
	if weapon then
		weapon = weapon.combat
		-- some weapons, like swords, add to the base damage value
		if weapon.damage_bonus then
			dice = dice + weapon.damage_bonus
		-- some weapons, like guns, over write the base damage value
		elseif weapon.damage then
			dice = weapon.damage
		end
	-- Unarmed damage bonus?  Used for claws and what not
	elseif self:attr("unarmed_damage_bonus") then
		dice = dice + self:attr("unarmed_damage_bonus")
	end
	
	-- Charge/Circle modifiers
	-- Did we move this turn?
	if (self.old_x ~= self.x or self.old_y ~= self.y) and action_modifier > 0 then
		-- Was it a charge? (Easier to deal damage)
		if core.fov.distance(self.old_x, self.old_y, target.x, target.y) > 1 then 
			modifier = modifier - action_modifier
			if self == game.player then
				game.logSeen(self, "I charged %s.", target.name:capitalize())
			end
		else
			-- If not charge, circle (Harder to deal damage)
			modifier = modifier + action_modifier
			if self == game.player then
				game.logSeen(self, "I circled %s.", target.name:capitalize())
			end
		end	
	end
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

--Armor
function _M:getCombatArmor(src)
	-- Base values
	local dice = self:getArmor()
	local sides = self.armor_sides
	local modifier = self.armor_modifier
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

-- Dreaming
function _M:getCombatDreaming(target)
	-- Base values
	local dice = self:getDreaming()
	local sides = self.dreaming_sides
	local modifier = self.dreaming_modifier
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

-- Reason
function _M:getCombatReason(src)
	-- Base values
	local dice = self:getReason()
	local sides = self.reason_sides
	local modifier = self.reason_modifier
	
	local pack_table = {dice = dice, sides = sides, modifier = modifier}
	return pack_table
end

--- Combat Flyers; produces varying flyers based on combat results
--  This does not do damage flyers; those are done in damage_types.lua
function _M:doCombatFlyers(target, successes)
	local sx, sy = game.level.map:getTileToScreen(target.x, target.y)
	if successes > 0  then
		if self == game.player then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked...", {255,0,255})
			game.logSeen(target, "%s soaked my attack.", target.name:capitalize())
		elseif target == game.player then
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Soaked!", {0, 255, 0})
			game.logSeen(target, "I soaked %s's attack.", self.name)
		end
	elseif self == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Missed...", {255,0,255})
		game.logSeen(target, "%s dodged my attack.", target.name:capitalize())
	elseif target == game.player then
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, -3, "Dodged!", {0, 255, 0})
		game.logSeen(target, "I dodged %s's attack.", self.name)
	end
end
