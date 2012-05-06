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

-- This file loads the game module, and loads data
local KeyBind = require "engine.KeyBind"
local DamageType = require "engine.DamageType"
local ActorInventory = require "engine.interface.ActorInventory"
local ActorStats = require "engine.interface.ActorStats"
local ActorResource = require "engine.interface.ActorResource"
local ActorTalents = require "engine.interface.ActorTalents"
local ActorAI = require "engine.interface.ActorAI"
local ActorLevel = require "engine.interface.ActorLevel"
local ActorTemporaryEffects = require "engine.interface.ActorTemporaryEffects"
local Birther = require "engine.Birther"
local Map = require "engine.Map"

-- Init settings
config.settings.fae = config.settings.fae or {}
config.settings.fae.autosave = true
if not config.settings.fae.smooth_move then config.settings.fae.smooth_move = 3 end

-- Useful keybinds
KeyBind:load("move,hotkeys,inventory,actions,interface,debug")

-- Damage types
DamageType:loadDefinition("/data/damage_types.lua")

-- Additional entities resolvers
dofile("/mod/resolvers.lua")

-- Talents
ActorTalents:loadDefinition("/data/talents.lua")

-- Timed Effects
ActorTemporaryEffects:loadDefinition("/data/timed_effects.lua")

-- Actor inventory
ActorInventory:defineInventory("MAINHAND", "Wielded in main hand", true, "I wield most weapons with this hand.")
ActorInventory:defineInventory("OFFHAND", "Held or wielded in off hand", true, "I can hold a light or use a shield in my off-hand.  Some weapons require both hands for me to use.")
ActorInventory:defineInventory("BODY", "Main armor", true, "Armor protects me from physical attacks. Heavier armor may slow me down.")
ActorInventory:defineInventory("SHOOTER", "Shooter", true, "My ranged weapon.")
ActorInventory:defineInventory("AMMO", "Ammo", true, "My readied ammo.")

-- Actor stats
ActorStats:defineStat("Offense","offense", 1, 1, 100, "Offense is my ability to land an attack.")
ActorStats:defineStat("Defense","defense", 1, 1, 100, "Defense is my ability to avoid an attack.")
ActorStats:defineStat("Damage",	"damage", 1, 1, 100, "Damage is my ability to kill things once I land an attack.  Generally this comes from my equipment rather than skill.")
ActorStats:defineStat("Armor",	"armor", 1, 1, 100, "Armor is my ability to avoid damage once an attack has landed.  Generally this comes from my equipment rather than skill.")

-- Actor Resources
ActorResource:defineResource("Dreaming", "dreaming", nil, "dreaming_regen", "Dreaming represents my sense of wonder and imagination.  The higher it is the harder my fae magic will be to resist.")
ActorResource:defineResource("Reason", "reason", nil, "reason_regen", "Reason represents my logic and higher thinking.  I use this to avoid fae magic and puzzle out problems.")
ActorResource:defineResource("Movement", "movement", nil, "movement_regen", "Movement represents how far I can move.")

-- Actor AIs
ActorAI:loadDefinition("/engine/ai/")

-- Birther descriptor
Birther:loadDefinition("/data/birth/descriptors.lua")

-- For smooth movement
Map.smooth_scroll = 3

-- Enable hex mode
core.fov.set_algorithm("hex")

-- Wall-sliding
config.settings.player_slide = true

-- Makes ASCII on ASCII work somehow.  Just doing what DarkGod told me to do.... (and copying what Darren did :P)
Map.updateMapDisplay = function (self, x, y, mos)
	local g = self(x, y, self.TERRAIN)
	local gb = nil
	local o = self(x, y, self.OBJECT)
	local a = self(x, y, self.ACTOR)
	--local t = self(x, y, self.TRAP)
	local p = self(x, y, self.PROJECTILE)
	if g then
		-- Update path caches from path strings
		for i = 1, #self.path_strings do
			local ps = self.path_strings[i]
			self._fovcache.path_caches[ps]:set(x, y, g:check("block_move", x, y, ps, false, true))
		end

		g:getMapObjects(self.tiles, mos, 1)
		g:setupMinimapInfo(g._mo, self)
		if g.default_tile then gb = g.default_tile end
	end
	if t then
      -- Handles trap being known
		if not self.actor_player or t:knownBy(self.actor_player) then
			t:getMapObjects(self.tiles, mos, 3)
			t:setupMinimapInfo(t._mo, self)
		else
			t = nil
		end
	end
	if o then
		o:getMapObjects(self.tiles, mos, 3)
		o:setupMinimapInfo(o._mo, self)
		if self.object_stack_count then
			local mo = o:getMapStackMO(self, x, y)
			if mo then mos[5] = mo end
		end
	end
	if a then
		-- Handles invisibility and telepathy and other such things
		if not self.actor_player or self.actor_player:canSee(a) then
			a:getMapObjects(self.tiles, mos, 3)
			a:setupMinimapInfo(a._mo, self)
		end
	end
	if p then
		p:getMapObjects(self.tiles, mos, 3)
		p:setupMinimapInfo(p._mo, self)
	end

	--if gb and not p and (not a or (self.actor_player and not self.actor_player.fov.actors[a])) then
	if gb and not p and not t and not o and (not a or not self.actor_player:canSee(a)) then
		gb:getMapObjects(self.tiles, mos, 3)
	end
end

return {require "mod.class.Game" }
