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

-- TODO: Move displays to the top of the screen

require "engine.class"
local Mouse = require "engine.Mouse"

module(..., package.seeall, class.make)

--[[function _M:init()
	self.font = core.display.newFont("/data/font/Monaco.TTF", 20)
	self.font_h = self.font:lineSkip()

	self.mouse = Mouse.new()

	local gw, gh = core.display.size()
	self:resize(1, gh - 40, gw, 40)
end]]

function _M:init(x, y, w, h, font, size)
	self.display_x = x
	self.display_y = y
	self.w, self.h = w, h
	self.bgcolor = bgcolor
	self.font = core.display.newFont(font or "/data/font/Monaco.TTF", size or 20)
	self.fontbig = core.display.newFont(font or "/data/font/Monaco.TTF", (size or 20) * 2)
	self.mouse = Mouse.new()
	self:resize(x, y, w, h)
end

--- Resize the display area
function _M:resize(x, y, w, h)
	self.display_x, self.display_y = x, y
	self.mouse.delegate_offset_x = x
	self.mouse.delegate_offset_y = y
	self.w, self.h = w, h
	self.font_w = self.font:size(" ")
--	self.surface_line = core.display.newSurface(w, self.font_h)
	self.bars_x = self.font_w * 9
	self.bars_w = self.w - self.bars_x - 5
	self.surface = core.display.newSurface(w, h)
	self.texture, self.texture_w, self.texture_h = self.surface:glTexture()

	self.items = {}
end

function _M:mouseTooltip(text, w, h, x, y, click)
--	self.mouse:registerZone(x, y, w, h, function(button, mx, my, xrel, yrel, bx, by, event)
--		game.tooltip_x, game.tooltip_y = 1, 1; game.tooltip:displayAtMap(nil, nil, game.w, game.h, text)
--		if click and event == "button" and button == "left" then
--			click()
--		end
--	end)
	return w, h
end

function _M:makeTexture(text, x, y, r, g, b, max_w)
	local s = self.surface
	s:drawColorStringBlended(self.font, text, x, y, r, g, b, true, max_w)
	return self.font:size(text)
end

function _M:makeTextureBar(text, nfmt, val, max, x, y, r, g, b, bar_col, bar_bgcol)
	local s = self.surface_line
	s:erase(0, 0, 0, 0)
	s:erase(bar_bgcol.r, bar_bgcol.g, bar_bgcol.b, 255, self.bars_x, h, self.bars_w, self.font_h)
	s:erase(bar_col.r, bar_col.g, bar_col.b, 255, self.bars_x, h, self.bars_w * val / max, self.font_h)

	s:drawColorStringBlended(self.font, text, 0, 0, r, g, b, true)
	s:drawColorStringBlended(self.font, (nfmt or "%d/%d"):format(val, max), self.bars_x, 0, r, g, b)

	local item = { s:glTexture() }
	item.x = x
	item.y = y
	item.w = self.w
	item.h = self.font_h
	self.items[#self.items+1] = item

	return item.w, item.h, item.x, item.y
end

-- Displays the stats
function _M:display()
	local player = game.player
	if not player or not player.changed or not game.level then return end

	self.mouse:reset()
	self.items = {}

	local s = self.surface
	s:erase(0, 0, 0, 0)

    local gw, gh = core.display.size()
	local w = 10  h = 0

    self:makeTexture(("Life: #%s#%d/%d   "):format(player:colorLife(), player.life, player.max_life), w, h, 220, 220, 255)
	
	w = 250
	
--[[	if player.raging then
		self:makeTexture(("RAGING: #RED#%d/%d   "):format(player.rage, player.max_rage), w, h, 255, 20, 20)
	else
		self:makeTexture(("Rage: #CRIMSON#%d/%d   "):format(player.rage, player.max_rage), w, h, 255, 220, 220)
	end
   
    w = 520
	
	self:makeTexture(player.stance[player.s].name, w, h, player.stance[player.s].color_r, player.stance[player.s].color_g, player.stance[player.s].color_b)]]
   
    w = gw - 400
   
	self:makeTexture(("%s"):format(game.zone.name), w, h, 240, 240, 120)

	s:updateTexture(self.texture)
end

function _M:toScreen()
	self:display()
	self.texture:toScreenFull(self.display_x, self.display_y, self.w, self.h, self.texture_w, self.texture_h)
end
