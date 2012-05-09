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
require "engine.Actor"
require "engine.Autolevel"
require "engine.interface.ActorStats"
require "engine.interface.ActorResource"
require "engine.interface.ActorInventory"
require "engine.interface.ActorTemporaryEffects"
require "engine.interface.ActorLife"
require "engine.interface.ActorProject"
require "engine.interface.ActorLevel"
require "engine.interface.ActorTalents"
require "engine.interface.ActorFOV"
require "mod.class.interface.Combat"
local Map = require "engine.Map"

module(..., package.seeall, class.inherit(
	engine.Actor,
	engine.interface.ActorInventory,
	engine.interface.ActorTemporaryEffects,
	engine.interface.ActorLife,
	engine.interface.ActorProject,
	engine.interface.ActorLevel,
	engine.interface.ActorStats,
	engine.interface.ActorTalents,
	engine.interface.ActorResource,
	engine.interface.ActorFOV,
	mod.class.interface.Combat
))

function _M:init(t, no_default)
	-- define some base values
	self.energyBase = 0
	self.moves_this_turn = 0 -- We use this for motion blur and combat effects
	
	-- Resources
	t.max_dreaming = t.max_dreaming or 1
	t.max_reason = t.max_reason or 1
	t.max_actions = t.max_actions or 20
		
	-- Default regen
	t.life_regen = t.life_regen or 0.1
	t.life_regen_pool = t.life_regen_pool or 0
	t.dreaming_regen = t.dreaming_regen or 1
	t.reason_regen = t.reason_regen or 1
	t.actions_regen = t.actions_regen or 100 -- Action Points reset to full each turn.  Don't give actors bonus regen
	
	
	engine.Actor.init(self, t, no_default)
	engine.interface.ActorInventory.init(self, t)
	engine.interface.ActorTemporaryEffects.init(self, t)
	engine.interface.ActorLife.init(self, t)
	engine.interface.ActorProject.init(self, t)
	engine.interface.ActorTalents.init(self, t)
	engine.interface.ActorResource.init(self, t)
	engine.interface.ActorStats.init(self, t)
	engine.interface.ActorLevel.init(self, t)
	engine.interface.ActorFOV.init(self, t)
end

function _M:actBase()
	self.energyBase = self.energyBase - game.energy_to_act
	-- Cooldown talents
	self:cooldownTalents()
	-- Regen resources, life, etc..
	self:regenResources()
	self:attr("moves_this_turn", 0, true)
	if self.life < self.max_life and self.life_regen > 0 then
		self:regenLife()
	end

	-- Compute timed effects
	self:timedEffects()
end

function _M:act()
	if not engine.Actor.act(self) then return end

	self.changed = true

	-- Still enough energy to act ?
	if self.energy.value < game.energy_to_act then return false end
	
	return true
end

function _M:move(x, y, force)
	local moved = false
	local ox, oy = self.x, self.y
	if force or self:enoughEnergy() then
		moved = engine.Actor.move(self, x, y, force)
		if not force and moved and (self.x ~= ox or self.y ~= oy) and not self.did_energy then
			-- Spend actions
			self:useActionPoints(10)
			self:attr("moves_this_turn", 1)
			self.changed = true
		end
	end
	-- smooth movement
	if moved and not force and ox and oy and (ox ~= self.x or oy ~= self.y) and config.settings.fae.smooth_move > 0 then
		local blur = 0
		if self:attr("moves_this_turn") and self:attr("moves_this_turn") > 0 then
			blur = blur + self.moves_this_turn
		end
		if blur > 0 then
			self:setMoveAnim(ox, oy, config.settings.fae.smooth_move, blur)
		end
	end
	self.did_energy = nil
	return moved
end

--- Call when added to a level
-- Ensures nothing bizzare happens from our life regen method and allows us to do neat things with NPCs
function _M:addedToLevel(level, x, y)
	if not self._rst_full then self:resetToFull() self._rst_full = true end -- Only do it once, the first time we come into being
	self:check("on_added_to_level", level, x, y)
end

function _M:resetToFull()
	if self.dead then return end
	self.life = self.max_life
	self.actions = self.max_actions
end

--- Regenerate life 
--  Life regen only ticks when the life_regen_pool is a whole number
--  This is mostly because I'm OCD and want whole numbers!!
function _M:regenLife()
	-- Increase the pool size
	self.life_regen_pool = self.life_regen_pool + self.life_regen
	-- If the pool is greater then 1 we heal
	if self.life_regen_pool >= 1 then
		-- round it down
		local regen_now = math.floor(self.life_regen_pool)
		-- but keep the decimal
		self.life_regen_pool = self.life_regen_pool - regen_now
		-- and regen
		self.life = util.bound(self.life + regen_now, self.die_at, self.max_life)
	end
end

-- Life Modifier
-- Reduce combat pools by a percentage when wounded
-- Also can color the Life display as Life goes down
function _M:getLifeModifier(color_it)
	local missing_life = self.max_life - self.life
	local color = 'WHITE'
	local modifier = 1
	
	if missing_life ~= 0 then
		if missing_life <= self.max_life * 0.25 then
			color = 'YELLOW'
			modifier = 0.9
		elseif missing_life <= self.max_life * 0.5 then
			color = 'ORANGE'
			modifier = 0.8
		elseif missing_life <= self.max_life * 0.75 then
			color = 'RED'
			modifier = 0.7
		else
			color = 'DARK_RED'
			modifier = 0.6
		end
	end
	
	if color_it then
		return color
	else
		return modifier
	end
end

-- We use action points instead of energy to simulate multiple actions per turn
-- When action points hit 0 we end our turn
function _M:useActionPoints(value)
	self:incActions(-value)
	if self:getActions() <= 0 then
		self:useEnergy()
	end	
end


-- TODO: VERBOSE when holding down control?
-- Some of this is just for debugging for now
function _M:tooltip()
	return ([[#%s#%s#LAST#
Offense %s
Defense %s
Damage  %s
Armor   %s
Life    %s/%s
actions %s/%s]]):format(self:getLifeModifier(true), self.name, self:getOffense(), self:getDefense(), self:getDamage(), self:getArmor(), self.life, self.max_life, self:getActions(), self:getMaxActions())
--	self:getDisplayString(),
--	self.level,
--	self.life, self.life * 100 / self.max_life,
--	self:getStr(),
--	self:getDex(),
--	self:getCon(),
--	self.desc or ""
	
end

function _M:onTakeHit(value, src)
	return value
end

function _M:die(src)
	engine.interface.ActorLife.die(self, src)

	-- Gives the killer some exp for the kill
	if src and src.gainExp then
		src:gainExp(self:worthExp(src))
	end

	return true
end

function _M:levelup()
	self.max_life = self.max_life + 2

	-- Heal upon new level
	self.life = self.max_life
end

--- Notifies a change of stat value
function _M:onStatChange(stat, v)
	if stat == self.STAT_CON then
		self.max_life = self.max_life + 2
	end
end

function _M:attack(target)
	self:bumpInto(target)
end


--- Called before a talent is used
-- Check the actor can cast it
-- @param ab the talent (not the id, the table)
-- @return true to continue, false to stop
function _M:preUseTalent(ab, silent)
	if not self:enoughEnergy() then print("fail energy") return false end

	if ab.mode == "sustained" then
		if ab.sustain_reason then
			game.logPlayer(self, "You do not have enough reason to activate %s.", ab.name)
			return false
		end
	else
		if ab.dreaming then
			game.logPlayer(self, "You do not have enough reason to cast %s.", ab.name)
			return false
		end
	end

	if not silent then
		-- Allow for silent talents
		if ab.message ~= nil then
			if ab.message then
				game.logSeen(self, "%s", self:useTalentMessage(ab))
			end
		elseif ab.mode == "sustained" and not self:isTalentActive(ab.id) then
			game.logSeen(self, "%s activates %s.", self.name:capitalize(), ab.name)
		elseif ab.mode == "sustained" and self:isTalentActive(ab.id) then
			game.logSeen(self, "%s deactivates %s.", self.name:capitalize(), ab.name)
		else
			game.logSeen(self, "%s uses %s.", self.name:capitalize(), ab.name)
		end
	end
	return true
end

--- Called before a talent is used
-- Check if it must use a turn, mana, stamina, ...
-- @param ab the talent (not the id, the table)
-- @param ret the return of the talent action
-- @return true to continue, false to stop
function _M:postUseTalent(ab, ret)
	if not ret then return end

	self:useEnergy()

	if ab.mode == "sustained" then
		if not self:isTalentActive(ab.id) then
			if ab.sustain_reason then

			end
		else
			if ab.sustain_reason then

			end
		end
	else
		if ab.dreaming then

		end
	end

	return true
end

--- Return the full description of a talent
-- You may overload it to add more data (like reason usage, ...)
function _M:getTalentFullDescription(t)
	local d = {}

	if t.mode == "passive" then d[#d+1] = "#6fff83#Use mode: #00FF00#Passive"
	elseif t.mode == "sustained" then d[#d+1] = "#6fff83#Use mode: #00FF00#Sustained"
	else d[#d+1] = "#6fff83#Use mode: #00FF00#Activated"
	end

	if t.reason or t.sustain_reason then d[#d+1] = "#6fff83#Reason cost: #7fffd4#"..(t.reason or t.sustain_reason) end
	if self:getTalentRange(t) > 1 then d[#d+1] = "#6fff83#Range: #FFFFFF#"..self:getTalentRange(t)
	else d[#d+1] = "#6fff83#Range: #FFFFFF#melee/personal"
	end
	if t.cooldown then d[#d+1] = "#6fff83#Cooldown: #FFFFFF#"..t.cooldown end

	return table.concat(d, "\n").."\n#6fff83#Description: #FFFFFF#"..t.info(self, t)
end

--- How much experience is this actor worth
-- @param target to whom is the exp rewarded
-- @return the experience rewarded
function _M:worthExp(target)
	if not target.level or self.level < target.level - 3 then return 0 end

	local mult = 2
	if self.unique then mult = 6
	elseif self.egoed then mult = 3 end
	return self.level * mult * self.exp_worth
end

--- Can the actor see the target actor
-- This does not check LOS or such, only the actual ability to see it.<br/>
-- Check for telepathy, invisibility, stealth, ...
function _M:canSee(actor, def, def_pct)
	if not actor then return false, 0 end

	-- Check for stealth. Checks against the target cunning and level
	if actor:attr("stealth") and actor ~= self then
		local def = self.level / 2 + self:getCun(25)
		local hit, chance = self:checkHit(def, actor:attr("stealth") + (actor:attr("inc_stealth") or 0), 0, 100)
		if not hit then
			return false, chance
		end
	end

	if def ~= nil then
		return def, def_pct
	else
		return true, 100
	end
end

--- Dice Functions
-- Basic Success Test
function _M:doSuccessTest(pool)
	local successes = 0
	local dice = pool
	while dice > 0 and successes < pool do
		local roll = rng.dice(1, 10)
		if roll >= 6 then
			successes = successes + 1
		end
		if roll < 10 then
			dice = dice - 1
		end
	end
	
	print(("%s rolled %dd10.  %d successes achieved."):format(self.name:capitalize(), pool, successes))
	return successes
end

--- Can the target be applied some effects
-- @param what a string describing what is being tried
function _M:canBe(what)
	if what == "poison" and rng.percent(100 * (self:attr("poison_immune") or 0)) then return false end
	if what == "cut" and rng.percent(100 * (self:attr("cut_immune") or 0)) then return false end
	if what == "confusion" and rng.percent(100 * (self:attr("confusion_immune") or 0)) then return false end
	if what == "blind" and rng.percent(100 * (self:attr("blind_immune") or 0)) then return false end
	if what == "stun" and rng.percent(100 * (self:attr("stun_immune") or 0)) then return false end
	if what == "fear" and rng.percent(100 * (self:attr("fear_immune") or 0)) then return false end
	if what == "knockback" and rng.percent(100 * (self:attr("knockback_immune") or 0)) then return false end
	if what == "instakill" and rng.percent(100 * (self:attr("instakill_immune") or 0)) then return false end
	return true
end

-- COPY/PASTED FROM ENGINE, CHANGED HEX X AND WIDTH FOR TACTICAL BORDERS -- tiger_eye
--- Attach or remove a display callback
-- Defines particles to display
function _M:defineDisplayCallback()
	if not self._mo then return end

	local ps = self:getParticlesList()

	local f_self = nil
	local f_danger = nil
	local f_friend = nil
	local f_enemy = nil
	local f_neutral = nil

	self._mo:displayCallback(function(x, y, w, h)
		local e
		for i = 1, #ps do
			e = ps[i]
			e:checkDisplay()
			if e.ps:isAlive() then e.ps:toScreen(x + w / 2, y + h / 2, true, w / game.level.map.tile_w)
			else self:removeParticles(e)
			end
		end

		-- Tactical info
		if game.level and game.level.map.view_faction then
			local map = game.level.map

			if not f_self then
				f_self = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_self)
				f_danger = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_danger)
				f_friend = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_friend)
				f_enemy = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_enemy)
				f_neutral = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_neutral)
			end

			if self.faction then
				local friend
				if not map.actor_player then friend = Faction:factionReaction(map.view_faction, self.faction)
				else friend = map.actor_player:reactionToward(self) end

				-- CHANGED HERE -- tiger_eye
				hex_factor = 1 / (2*math.sqrt(0.75)-1)
				hex_width = hex_factor*w
				hex_x = x-0.5*(hex_width-w)
				if self == map.actor_player then
					f_self:toScreen(hex_x, y, hex_width, h)
				elseif map:faction_danger_check(self) then
					f_danger:toScreen(hex_x, y, hex_width, h)
				elseif friend > 0 then
					f_friend:toScreen(hex_x, y, hex_width, h)
				elseif friend < 0 then
					f_enemy:toScreen(hex_x, y, hex_width, h)
				else
					f_neutral:toScreen(hex_x, y, hex_width, h)
				end
			end
		end
		return true
	end)
end