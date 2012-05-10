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
require "mod.class.Actor"
require "mod.class.Object"
require "mod.class.interface.PlayerExplore"
require "engine.interface.PlayerRest"
require "engine.interface.PlayerRun"
require "engine.interface.PlayerSlide"
require "engine.interface.PlayerMouse"
require "engine.interface.PlayerHotkeys"
local Map = require "engine.Map"
local Dialog = require "engine.Dialog"
local ActorTalents = require "engine.interface.ActorTalents"
local DeathDialog = require "mod.dialogs.DeathDialog"
local Astar = require"engine.Astar"
local DirectPath = require"engine.DirectPath"
local Particles = require "engine.Particles"

--- Defines the player
-- It is a normal actor, with some redefined methods to handle user interaction.<br/>
-- It is also able to run and rest and use hotkeys
module(..., package.seeall, class.inherit(
	mod.class.Actor,
	mod.class.interface.PlayerExplore,
	engine.interface.PlayerRest,
	engine.interface.PlayerRun,
	engine.interface.PlayerSlide,
	engine.interface.PlayerMouse,
	engine.interface.PlayerHotkeys
))

function _M:init(t, no_default)
	t.display=t.display or '@'
	t.color_r=t.color_r or 240
	t.color_g=t.color_g or 240
	t.color_b=t.color_b or 240

	t.player = true
	t.type = t.type or "humanoid"
	t.subtype = t.subtype or "player"
	t.faction = t.faction or "players"
	
	t.lite = t.lite or 0
	
	t.old_life = 0
	
	t.max_dreaming = 5
	t.max_reason = 5

	mod.class.Actor.init(self, t, no_default)
	engine.interface.PlayerHotkeys.init(self, t)

	self.descriptor = {}
end

function _M:move(x, y, force)
	local ox, oy = self.x, self.y
	local moved = mod.class.Actor.move(self, x, y, force)
	
	if not force and ox == self.x and oy == self.y and self.doPlayerSlide then
		self.doPlayerSlide = nil
		tx, ty = self:tryPlayerSlide(x, y, false)
		if tx then moved = self:move(tx, ty, false) end
	end
	self.doPlayerSlide = nil
	
	if moved then
		game.level.map:moveViewSurround(self.x, self.y, 8, 8)
	end
	
	return moved
end

function _M:act()
	if not mod.class.Actor.act(self) then return end
	
	-- Funky shader things !
	self:updateMainShader()

	self.old_life = self.life

	-- Resting ? Running ? Otherwise pause
	if not self:restStep() and not self:runStep() and self.player  then
		game.paused = true
	end
end

-- Precompute FOV form, for speed
local fovdist = {}
for i = 0, 30 * 30 do
	fovdist[i] = math.max((20 - math.sqrt(i)) / 14, 0.6)
end

function _M:playerFOV()
	-- Clean FOV before computing it
	game.level.map:cleanFOV()
	-- Compute both the normal and the lite FOV, using cache
	self:computeFOV(self.sight or 20, "block_sight", function(x, y, dx, dy, sqdist)
		game.level.map:apply(x, y, fovdist[sqdist])
	end, true, false, true)
	self:computeFOV(self.lite, "block_sight", function(x, y, dx, dy, sqdist) game.level.map:applyLite(x, y) end, true, true, true)
end

--- Called before taking a hit, overload mod.class.Actor:onTakeHit() to stop resting and running
function _M:onTakeHit(value, src)
	-- Stop running and Resting
	self:runStop("taken damage")
	self:restStop("taken damage")
	
	-- Toss out a low health flyer at 30%, 20%, and every time we're hit while at 10% or less
	local ret = mod.class.Actor.onTakeHit(self, value, src)
	local thirty_percent = self.old_life > self.max_life * 0.3 and self.life - ret <= self.max_life * 0.3
	local twenty_percent = self.old_life > self.max_life * 0.2 and self.life - ret <= self.max_life * 0.2
	local under_ten_percent = self.life - ret <= self.max_life * 0.1
	if thirty_percent or twenty_percent or under_ten_percent then
		local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
		local messages = { "I don't feel well...", "I'll need healing very soon!", "I'm not going to make it..." }
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, 2, rng.table(messages), {255,0,0}, true)
	end
	
	return ret
end

function _M:die(src)
	if self.game_ender then
		engine.interface.ActorLife.die(self, src)
		game.paused = true
		self.energy.value = game.energy_to_act
		game:registerDialog(DeathDialog.new(self))
	else
		mod.class.Actor.die(self, src)
	end
end

-- Item management
function _M:playerPickup()
    -- If 2 or more objects, display a pickup dialog, otherwise just picks up
    if game.level.map:getObject(self.x, self.y, 2) then
        local d d = self:showPickupFloor("Pickup", nil, function(o, item)
            self:pickupFloor(item, true)
            self.changed = true
            d:used()
        end)
    else
        self:pickupFloor(1, true)
        self:sortInven()
        self:useActionPoints()
		self.changed = true
    end
end

function _M:playerDrop()
    local inven = self:getInven(self.INVEN_INVEN)
    local d d = self:showInventory("Drop object", inven, nil, function(o, item)
        self:dropFloor(inven, item, true, true)
        self:sortInven(inven)
        self:useActionPoints()
        self.changed = true
        return true
    end)
end

function _M:doWear(inven, item, o)
    self:removeObject(inven, item, true)
    local ro = self:wearObject(o, true, true)
    if ro then
        if type(ro) == "table" then self:addObject(inven, ro) end
    elseif not ro then
        self:addObject(inven, o)
    end
    self:sortInven()
    self:useActionPoints()
    self.changed = true
end

function _M:doTakeoff(inven, item, o)
    if self:takeoffObject(inven, item) then
        self:addObject(self.INVEN_INVEN, o)
    end
    self:sortInven()
    self:useActionPoints()
    self.changed = true
end

function _M:playerUseItem(object, item, inven)
    local use_fct = function(o, inven, item)
        if not o then return end
        local co = coroutine.create(function()
            self.changed = true

            local used, ret = o:use(self, nil, inven, item)
            if not used then return end
            if ret and ret == "destroy" then
                if o.multicharge and o.multicharge > 1 then
                    o.multicharge = o.multicharge - 1
                else
                    local _, del = self:removeObject(self:getInven(inven), item)
                    if del then
                        game.log("You have no more %s.", o:getName{no_count=true, do_color=true})
                    else
                        game.log("You have %s.", o:getName{do_color=true})
                    end
                    self:sortInven(self:getInven(inven))
                end
                return true
            end

            self.changed = true
        end)
        local ok, ret = coroutine.resume(co)
        if not ok and ret then print(debug.traceback(co)) error(ret) end
        return true
    end

    if object and item then return use_fct(object, inven, item) end

    self:showEquipInven("Use object",
        function(o)
            return o:canUseObject()
        end,
        use_fct
    )
end

--- Notify the player of available cooldowns
function _M:onTalentCooledDown(tid)
	local t = self:getTalentFromId(tid)

	local x, y = game.level.map:getTileToScreen(self.x, self.y)
	game.flyers:add(x, y, 30, -0.3, -3.5, ("%s available"):format(t.name:capitalize()), {0,255,00})
	game.log("#00ff00#Talent %s is ready to use.", t.name)
end

function _M:levelup()
	mod.class.Actor.levelup(self)

	local x, y = game.level.map:getTileToScreen(self.x, self.y)
	game.flyers:add(x, y, 80, 0.5, -2, "LEVEL UP!", {0,255,255})
	game.log("#00ffff#Welcome to level %d.", self.level)
end

--- Tries to get a target from the user
function _M:getTarget(typ)
	return game:targetGetForPlayer(typ)
end

--- Sets the current target
function _M:setTarget(target)
	return game:targetSetForPlayer(target)
end


local function spotHostiles(self)
	local seen = {}
	if not self.x then return seen end

	-- Check for visible monsters, only see LOS actors, so telepathy wont prevent resting
	core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, self.sight or 10, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
		local actor = game.level.map(x, y, game.level.map.ACTOR)
		if actor and self:reactionToward(actor) < 0 and self:canSee(actor) and game.level.map.seens(x, y) then
			seen[#seen + 1] = {x=x,y=y,actor=actor}
		end
	end, nil)
	return seen
end

--- Can we continue resting ?
-- We can rest if no hostiles are in sight, and if we need life(and their regen rates allows them to fully regen)
function _M:restCheck()
	local spotted = spotHostiles(self)
	if #spotted > 0 then return false, "hostile spotted" end

	-- Check life, make sure it CAN go up, otherwise we will never stop
	if self.life < self.max_life and self.life_regen> 0 then return true end

	return false, "life at maximum"
end

-- Superload runStep to drop a game.paused = false in for Action Points to work
local previous_runStep = _M.runStep
function _M:runStep()
	game.paused = false
	return previous_runStep(self)
end

--- Can we continue running?
-- We can run if no hostiles are in sight, and if we no interesting terrains are next to us
function _M:runCheck(ignore_memory)
	local spotted = spotHostiles(self)
	if #spotted > 0 then return false, "hostile spotted" end

	-- Notice any noticeable terrain
	local noticed = false
	self:runScan(function(x, y, what)
		-- Objects are always interesting, only on curent spot
		if what == "self" and not game.level.map.attrs(x, y, "obj_seen") then
			local obj = game.level.map:getObject(x, y, 1)
			if obj then
				noticed = "object seen"
				if not ignore_memory then game.level.map.attrs(x, y, "obj_seen", true) end
				return
			end
		end
		-- Only notice interesting terrains
		local grid = game.level.map(x, y, Map.TERRAIN)
		if grid and grid.notice and not (self.running and self.running.path and (game.level.map.attrs(x, y, "noticed")
				or (what ~= self and (self.running.explore and grid.door_opened                     -- safe door
				or #self.running.path == self.running.cnt and (self.running.explore == "exit"       -- auto-explore onto exit
				or not self.running.explore and grid.change_level))                                 -- A* onto exit
				or #self.running.path - self.running.cnt < 2 and (self.running.explore == "portal"  -- auto-explore onto portal
				or not self.running.explore and grid.orb_portal)                                    -- A* onto portal
				or self.running.cnt < 3 and grid.orb_portal and                                     -- path from portal
				game.level.map:checkEntity(self.running.path[1].x, self.running.path[1].y, Map.TERRAIN, "orb_portal"))))
		then
			if self.running and self.running.explore and self.running.path and self.running.explore ~= "unseen" and self.running.cnt == #self.running.path + 1 then
				noticed = "at " .. self.running.explore
			else
				noticed = "interesting terrain"
			end
			-- let's only remember and ignore standard interesting terrain
			if not ignore_memory and (grid.change_level or grid.orb_portal) then game.level.map.attrs(x, y, "noticed", true) end
			return
		end
	end)
	if noticed then return false, noticed end

	self:playerFOV()

	return engine.interface.PlayerRun.runCheck(self)
end

--- Move with the mouse
-- We just feed our spotHostile to the interface mouseMove
function _M:mouseMove(tmx, tmy, force_move)
	local astar_check = function(x, y)
		-- Dont do traps
		local trap = game.level.map(x, y, Map.TRAP)
		if trap and trap:knownBy(self) and trap:canTrigger(x, y, self, true) then return false end

		-- Dont go where you cant breath
		if not self:attr("no_breath") then
			local air_level, air_condition = game.level.map:checkEntity(x, y, Map.TERRAIN, "air_level"), game.level.map:checkEntity(x, y, Map.TERRAIN, "air_condition")
			if air_level then
				if not air_condition or not self.can_breath[air_condition] or self.can_breath[air_condition] <= 0 then
					return false
				end
			end
		end
		return true
	end
	return engine.interface.PlayerMouse.mouseMove(self, tmx, tmy, function() local spotted = spotHostiles(self) ; return #spotted > 0 end, {recheck=true, astar_check=astar_check}, force_move)
end

--- Called after running a step
function _M:runMoved()
	self:playerFOV()
	--[[if self.running and self.running.explore then
		game.level.map:particleEmitter(self.x, self.y, 1, "dust_trail")
	end]]
end

--- Called after stopping running
function _M:runStopped()
	game.level.map.clean_fov = true
	self:playerFOV()
	local spotted = spotHostiles(self)
	if #spotted > 0 then
		for _, node in ipairs(spotted) do
		--	node.actor:addParticles(engine.Particles.new("notice_enemy", 1))
		end
	end

	-- if you stop at an object (such as on a trap), then mark it as seen
	local obj = game.level.map:getObject(x, y, 1)
	if obj then game.level.map.attrs(x, y, "obj_seen", true) end
end

-- Sets the save file name?
function _M:setName(name)
	self.name = name
	game.save_name = name
end

--- Funky shader stuff
function _M:updateMainShader()
	if game.fbo_shader then
		if self.life ~= self.old_life then
			if self.life < self.max_life * 0.3 then
				game.fbo_shader:setUniform("hp_warning", 1 - (self.life / self.max_life))
			else
				game.fbo_shader:setUniform("hp_warning", 0)
			end
		end
	end
end
