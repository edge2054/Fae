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

local Dialog = require "engine.ui.Dialog"
local Talents = require "engine.interface.ActorTalents"
local SurfaceZone = require "engine.ui.SurfaceZone"
local Stats = require "engine.interface.ActorStats"
local Textzone = require "engine.ui.Textzone"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(actor)
    self.actor = actor
    
    self.font = core.display.newFont("/data/font/DroidSansMono.ttf", 14)
    Dialog.init(self, "Character Sheet: "..self.actor.name, math.max(game.w * 0.7, 950), 500, nil, nil, font)
    
    self.c_desc = SurfaceZone.new{width=self.iw, height=self.ih,alpha=0}

    self:loadUI{
        {left=0, top=0, ui=self.c_desc},
    }
    
    self:setupUI()
    
    self:drawDialog()
    
    self.key:addBind("EXIT", function() cs_player_dup = game.player:clone() game:unregisterDialog(self) end)
end

function _M:drawDialog()
    local player = self.actor
    local s = self.c_desc.s

    s:erase(0,0,0,0)

    local h = 0
    local w = 0

    h = 0
    w = 0
    s:drawStringBlended(self.font, "Name   : "..(player.name or "Unnamed"), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Role   : "..(player.descriptor.role), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Life   : "..(player.life), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Belief : "..(player.belief), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Reason : "..(player.reason), w, h, 255, 255, 255, true) h = h + self.font_h + 4

        
    h = h + self.font_h + 4 -- Adds an empty row
    
    h = 0
    w = self.w * 0.25 
	
    -- Dice pools
	local offense 	= player.offense
	local defense 	= player.defense
	local damage	= player.damage
	local armor		= player.armor
	
	s:drawStringBlended(self.font, "Offense : "..(offense.dice).."d"..(offense.sides), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Defense : "..(defense.dice).."d"..(defense.sides), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Damage  : "..(damage.dice).."d"..(damage.sides), w, h, 255, 255, 255, true) h = h + self.font_h + 4
	s:drawStringBlended(self.font, "Armor   : "..(armor.dice).."d"..(armor.sides), w, h, 255, 255, 255, true) h = h + self.font_h + 4
    
    self.c_desc:generate()
    self.changed = false
end