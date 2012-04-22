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

-- TODO: Change Font

require "engine.class"
local Tooltip = require "engine.Tooltip"
local Map = require "engine.Map"

module(..., package.seeall, class.inherit(Tooltip))

tooltip_bound_y2 = function() return game.h end

function _M:init(...)
	Tooltip.init(self, ...)
end

function _M:toScreen(x, y, nb_keyframes)
	-- We translate and scale opengl matrix to make the popup effect easily
	local ox, oy = math.floor(x), math.floor(y)
	x, y = ox, oy
	local hw, hh = math.floor(self.w / 2), math.floor(self.h / 2)
	local tx, ty = x + hw, y + hh
	x, y = -hw, -hh
	core.display.glTranslate(tx, ty, 0)

	-- Draw the frame and shadow
--	self:drawFrame(self.frame, x+1, y+1, 0, 0, 0, 0.3)
--	self:drawFrame(self.frame, x-3, y-3, 1, 1, 1, 0.75)

	-- UI elements
	local uih = 0
	for i = 1, #self.uis do
		local ui = self.uis[i]
		ui:display(x + 5, y + 5 + uih, nb_keyframes, ox + 5, oy + 5 + uih)
		uih = uih + ui.h
	end

	-- Restiore normal opengl matrix
	core.display.glTranslate(-tx, -ty, 0)
end

--- Gets the tooltips at the given map coord
function _M:getTooltipAtMap(tmx, tmy, mx, my)
	local tt = {}
	local seen = game.level.map.seens(tmx, tmy)
	local remember = game.level.map.remembers(tmx, tmy)
	tt[#tt+1] = seen and game.level.map:checkEntity(tmx, tmy, Map.PROJECTILE, "tooltip", game.level.map.actor_player) or nil
	tt[#tt+1] = seen and game.level.map:checkEntity(tmx, tmy, Map.ACTOR, "tooltip", game.level.map.actor_player) or nil
	tt[#tt+1] = (seen or remember) and game.level.map:checkEntity(tmx, tmy, Map.OBJECT, "tooltip", game.level.map.actor_player) or nil
	tt[#tt+1] = (seen or remember) and game.level.map:checkEntity(tmx, tmy, Map.TRAP, "tooltip", game.level.map.actor_player) or nil
	tt[#tt+1] = (seen or remember) and game.level.map:checkEntity(tmx, tmy, Map.TERRAIN, "tooltip", game.level.map.actor_player) or nil
	if #tt > 0 then
		local ts = tstring{}
		if self.add_map_str then ts:merge(self.add_map_str:toTString()) ts:add(true, "", true) end
		for i = 1, #tt do
			ts:merge(tt[i]:toTString())
			if i < #tt then ts:add(true, "", true) end
		end
		return ts
	end
	if self.add_map_str then return self.add_map_str:toTString() end
	return nil
end
