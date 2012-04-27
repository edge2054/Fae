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
require "engine.Object"
require "engine.interface.ObjectActivable"

local Stats = require("engine.interface.ActorStats")
local Talents = require("engine.interface.ActorTalents")
local DamageType = require("engine.DamageType")

module(..., package.seeall, class.inherit(
    engine.Object,
    engine.interface.ObjectActivable,
    engine.interface.ActorTalents
))

function _M:init(t, no_default)
    t.encumber = t.encumber or 0

    engine.Object.init(self, t, no_default)
    engine.interface.ObjectActivable.init(self, t)
    engine.interface.ActorTalents.init(self, t)
end

function _M:canAct()
    if self.power_regen or self.use_talent then return true end
    return false
end

function _M:act()
    self:regenPower()
    self:cooldownTalents()
    self:useEnergy()
end

function _M:use(who, typ, inven, item)
    inven = who:getInven(inven)

    if self:wornInven() and not self.wielded and not self.use_no_wear then
        game.logPlayer(who, "You must wear this object to use it!")
        return
    end

    local types = {}
    if self:canUseObject() then types[#types+1] = "use" end

    if not typ and #types == 1 then typ = types[1] end

    if typ == "use" then
        local ret = {self:useObject(who, inven, item)}
        if ret[1] then
            if self.use_sound then game:playSoundNear(who, self.use_sound) end
            who:useEnergy(game.energy_to_act * (inven.use_speed or 1))
        end
        return unpack(ret)
    end
end

--- Returns a tooltip for the object
-- TODO: Clean this up for Fae, it's copy/pasta from Run from the Shadows
-- It works but all these description functions are ugly as fuck without borders
function _M:tooltip()
	local str = self:getDesc{do_color=true}
	return str
end

--- Describes an attribute, to expand object name
function _M:descAttribute(attr)

	if attr == "STATBONUS" then
		local stat, i = next(self.wielder.inc_stats)
		return i > 0 and "+"..i or tostring(i)
	elseif attr == "COMBAT" then
		local c = self.combat
		return c.dam.."-"..(c.dam*(c.damrange or 1.1)).." m, "..(c.apr or 0).." apr"
	elseif attr == "ARMOR" then
		return (self.wielder and self.wielder.combat_def or 0).." def, "..(self.wielder and self.wielder.combat_armor or 0).." armor"
	elseif attr == "ATTACK" then
		return (self.wielder and self.wielder.combat_atk or 0).." attack, "..(self.wielder and self.wielder.combat_apr or 0).." apr, "..(self.wielder and self.wielder.combat_dam or 0).." power"
	end
end

--- Gets the full name of the object
function _M:getName(t)
	t = t or {}
	local qty = self:getNumber()
	local name = self.name

	-- To extend later
	name = name:gsub("~", ""):gsub("&", "a"):gsub("#([^#]+)#", function(attr)
		return self:descAttribute(attr)
	end)

	if not t.no_add_name and self.add_name and self:isIdentified() then
		name = name .. self.add_name:gsub("#([^#]+)#", function(attr)
			return self:descAttribute(attr)
		end)
	end

		if qty == 1 or t.no_count then return name
		else return qty.." "..name
		end

end

--- Gets the full textual desc of the object without the name and requirements
function _M:getTextualDesc()
	local desc = tstring{}

	desc:add(true)
   
    if self.multicharge then desc:add(("%d remaining"):format(self.multicharge or 0), true) end

	local desc_wielder = function(w)
		if w.base_dam then desc:add("Damage: "..w.base_dam.." to "..w.max_dam, true) end
		if w.defence then desc:add(("Defence +%d"):format(w.defence or 0), true) end
		if w.life_regen then desc:add(("Regen +%d"):format(w.life_regen or 0), true) end
    end
   
	if self.wielder then
		desc:add({"color","SANDY_BROWN"}, "When equipped:", {"color", "LAST"}, true)
		desc_wielder(self.wielder)
	end

	local use_desc = self:getUseDesc()
	if use_desc then desc:add(use_desc) end

	return desc
end

--- Gets the full desc of the object
function _M:getDesc(name_param)
	local desc = tstring{}
	name_param = name_param or {}
	name_param.do_color = true

		desc:merge(self:getName(name_param):toTString())
		desc:add({"color", "WHITE"}, true)
		desc:add(true)
		desc:add({"color", "ANTIQUE_WHITE"})
		desc:merge(self.desc:toTString())
		desc:add(true)
		desc:add(true)
		desc:add({"color", "WHITE"})

	local reqs = self:getRequirementDesc(game.player)
	if reqs then
		desc:add(true)
		desc:merge(reqs)
	end

	desc:add(true, true)
	desc:merge(self:getTextualDesc())

	return desc
end

local type_sort = {
	potion = 1,
    scroll = 2,
	weapon = 100,
	shield = 101,
}

--- Sorting by type function
-- By default, sort by type name
function _M:getTypeOrder()
	if self.type and type_sort[self.type] then
		return type_sort[self.type]
	else
		return 99999
	end
end

--- Sorting by type function
-- By default, sort by subtype name
function _M:getSubtypeOrder()
	return self.subtype or ""
end


--- Can it stacks with others of its kind ?
function _M:canStack(o)
	return engine.Object.canStack(self, o)
end
