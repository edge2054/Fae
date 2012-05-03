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
require "engine.interface.GameMusic"
require "engine.interface.GameSound"
require "engine.GameTurnBased"
require "engine.interface.GameTargeting"
require "engine.KeyBind"
local Savefile = require "engine.Savefile"
local DamageType = require "engine.DamageType"
local Zone = require "engine.Zone"
local Map = require "engine.Map"
local Level = require "engine.Level"
local Birther = require "engine.Birther"
local Shader = require "engine.Shader"

local Grid = require "mod.class.Grid"
local Actor = require "mod.class.Actor"
local Player = require "mod.class.Player"
local NPC = require "mod.class.NPC"

local PlayerDisplay = require "mod.class.PlayerDisplay"
local HotkeysIconsDisplay = require "engine.HotkeysIconsDisplay"
local LogDisplay = require "engine.LogDisplay"

local DebugConsole = require "engine.DebugConsole"
local FlyingText = require "engine.FlyingText"
local Tooltip = require "mod.class.Tooltip"

local QuitDialog = require "mod.dialogs.Quit"

module(..., package.seeall, class.inherit(engine.GameTurnBased, engine.interface.GameMusic, engine.interface.GameSound, engine.interface.GameTargeting))

-- Tell the engine that we have a fullscreen shader that supports gamma correction
support_shader_gamma = true

function _M:init()
	engine.GameTurnBased.init(self, engine.KeyBind.new(), 1000, 100)
	engine.interface.GameMusic.init(self)
	engine.interface.GameSound.init(self)

	-- Pause at birth
	self.paused = true

	-- Same init as when loaded from a savefile
	self:loaded()
end

function _M:run()
	-- UI
	self.player_display = PlayerDisplay.new(10, 0, self.w, self.h)
	self.logdisplay = LogDisplay.new(0, self.h * 0.8, self.w * 0.5, self.h * 0.2, nil, nil, nil, {255,255,255}, {30,30,30})
	self.hotkeys_display_icons = HotkeysIconsDisplay.new(nil, self.w *0.01, self.h * 0.91, self.w, 0, {255,255,255}, "/data/font/DroidSansMono.ttf", 10, game.h * 0.07, game.h * 0.07)
	self.hotkeys_display_icons:enableShadow(0.6)
	self.tooltip = Tooltip.new(nil, nil, {255,255,255}, {30,30,30})

	--UI Elements (frames and what not)
	self.ui_texture_bar = {core.display.loadImage("/data/gfx/ui/texture_bar_grey.png"):glTexture()}
	
	-- Flyers
	local flysize = 16
	self.flyers = FlyingText.new("/data/font/DroidSansMono.ttf", flysize, "/data/font/DroidSansMono.ttf", flysize + 3)
	self.flyers:enableShadow(0.6)
	self:setFlyingText(self.flyers)

	-- Game Log
	self.log = function(style, ...) if type(style) == "number" then self.logdisplay(...) else self.logdisplay(style, ...) end end
	self.logSeen = function(e, style, ...) if e and self.level.map.seens(e.x, e.y) then self.log(style, ...) end end
	self.logPlayer = function(e, style, ...) if e == self.player then self.log(style, ...) end end

	self.log("Welcome to #00FF00#Fae!")

	-- Setup inputs
	self:setupCommands()
	self:setupMouse()

	-- Starting from here we create a new game
	if not self.player then self:newGame() end

	self.hotkeys_display_icons.actor = self.player

	-- Setup the targetting system
	engine.interface.GameTargeting.init(self)

	-- Ok everything is good to go, activate the game in the engine!
	self:setCurrent()

	if self.level then self:setupDisplayMode() end
end

function _M:newGame()
	self.player = Player.new{name=self.player_name, game_ender=true}
	Map:setViewerActor(self.player)
	self:setupDisplayMode()

	self.creating_player = true
	local birth = Birther.new(nil, self.player, {"base", "role"}, function()
		self:changeLevel(1, "dungeon")
		print("[PLAYER BIRTH] resolve...")
		self.player:resolve()
		self.player:resolve(nil, true)
		self.player.energy.value = self.energy_to_act
		self.paused = true
		self.creating_player = false
		print("[PLAYER BIRTH] resolved!")
		self.player.changed = true
	end)
	self:registerDialog(birth)
end

function _M:loaded()
	engine.GameTurnBased.loaded(self)
	Zone:setup{npc_class="mod.class.NPC", grid_class="mod.class.Grid", object_class="mod.class.Object"}
	Map:setViewerActor(self.player)
	local th = 48
	local tw = math.floor(math.sqrt(0.75) * (th + 0.5))
	Map:setViewPort(0, 0, self.w, self.h * 0.90, tw, th, "/data/font/DroidSansMono.ttf", 48, true)
	engine.interface.GameMusic.loaded(self)
	engine.interface.GameSound.loaded(self)
	self:playMusic()
	self.key = engine.KeyBind.new()
end

function _M:setupDisplayMode()
--	print("[DISPLAY MODE] 32x32 ASCII/background")
	local th = 48
	local tw = math.floor(math.sqrt(0.75) * (th + 0.5))
	Map:setViewPort(0, 0, self.w, self.h * 0.90, tw, th, "/data/font/DroidSansMono.ttf", 48, true)
	Map:resetTiles()
	Map.tiles.use_images = true

	if self.level then
		self.level.map:recreate()
		engine.interface.GameTargeting.init(self)
		self.level.map:moveViewSurround(self.player.x, self.player.y, 8, 8)
	end
	self:createFBOs()
end

function _M:createFBOs()
	-- Create the framebuffer
	self.fbo = core.display.newFBO(Map.viewport.width, Map.viewport.height)
	if self.fbo then self.fbo_shader = Shader.new("main_fbo") if not self.fbo_shader.shad then self.fbo = nil self.fbo_shader = nil end end
	if self.player then self.player:updateMainShader() end

	self.full_fbo = core.display.newFBO(self.w, self.h)
	if self.full_fbo then self.full_fbo_shader = Shader.new("full_fbo") if not self.full_fbo_shader.shad then self.full_fbo = nil self.full_fbo_shader = nil end end
	
	self:setGamma(config.settings.gamma_correction / 100)

--	self.mm_fbo = core.display.newFBO(200, 200)
--	if self.mm_fbo then self.mm_fbo_shader = Shader.new("mm_fbo") if not self.mm_fbo_shader.shad then self.mm_fbo = nil self.mm_fbo_shader = nil end end
end


function _M:save()
	return class.save(self, self:defaultSavedFields{}, true)
end

function _M:getSaveDescription()
	return {
		name = self.player.name,
		description = ([[%s the %s is exploring %s.]]):format(game.player.name, game.player.descriptor.role, self.zone.name),
	}
end

function _M:leaveLevel(level, lev, old_lev)
	if level:hasEntity(self.player) then
		level.exited = level.exited or {}
		if lev > old_lev then
			level.exited.down = {x=self.player.x, y=self.player.y}
		else
			level.exited.up = {x=self.player.x, y=self.player.y}
		end
		level.last_turn = game.turn
		level:removeEntity(self.player)
	end
end

function _M:changeLevel(lev, zone)
	local old_lev = (self.level and not zone) and self.level.level or -1000
	if zone then
		if self.zone then
			self.zone:leaveLevel(false, lev, old_lev)
			self.zone:leave()
		end
		if type(zone) == "string" then
			self.zone = Zone.new(zone)
		else
			self.zone = zone
		end
	end
	self.zone:getLevel(self, lev, old_lev)
	
	-- Add the music
	local musics = {}
	if self.zone.ambient_music then
		if type(self.zone.ambient_music) == "string" then musics[#musics+1] = self.zone.ambient_music
		elseif type(self.zone.ambient_music) == "table" then for i, name in ipairs(self.zone.ambient_music) do musics[#musics+1] = name end
		elseif type(self.zone.ambient_music) == "function" then for i, name in ipairs{self.zone.ambient_music()} do musics[#musics+1] = name end
		end
	end
	self:playAndStopMusic(unpack(musics))

	if lev > old_lev then
		self.player:move(self.level.default_up.x, self.level.default_up.y, true)
	else
		self.player:move(self.level.default_down.x, self.level.default_down.y, true)
	end
	self.level:addEntity(self.player)
end



function _M:getPlayer()
	return self.player
end

--- Says if this savefile is usable or not
function _M:isLoadable()
	return not self:getPlayer(true).dead
end

function _M:tick()
	if self.level then
		self:targetOnTick()

		engine.GameTurnBased.tick(self)
		-- Fun stuff: this can make the game realtime, although calling it in display() will make it work better
		-- (since display is on a set FPS while tick() ticks as much as possible
		-- engine.GameEnergyBased.tick(self)
	end
	-- When paused (waiting for player input) we return true: this means we wont be called again until an event wakes us
	if self.paused and not savefile_pipe.saving then return true end
end

--- Called every game turns
-- Does nothing, you can override it
function _M:onTurn()
	-- The following happens only every 10 game turns (once for every turn of 1 mod speed actors)
	if self.turn % 10 ~= 0 then return end

	-- Process overlay effects
	self.level.map:processEffects()
end

-- A nice function for playing sound at a position without to much hassle (thanks Darkgod :) )
function _M:playSoundNear(who, name)
	if who and self.level.map.seens(who.x, who.y) then
		local pos = {x=0,y=0,z=0}
		if self.player and self.player.x then pos.x, pos.y = who.x - self.player.x, who.y - self.player.y end
		self:playSound(name, pos)
	end
end

function _M:display(nb_keyframe)
	-- If switching resolution, blank everything but the dialog
	if self.change_res_dialog then engine.GameTurnBased.display(self, nb_keyframe) return end
	if self.full_fbo then self.full_fbo:use(true) end

	-- Now the map, if any
	if self.level and self.level.map and self.level.map.finished then
		-- Display the map and compute FOV for the player if needed
		if self.level.map.changed then
			self.player:playerFOV()
		end

		local map = game.level.map
		-- Display using Framebuffer, so that we can use shaders and all
		if self.fbo then
			 self.fbo:use(true)
				map:display(0, 0, nb_keyframe)
				--map._map:drawSeensTexture(0, 0, nb_keyframes) -- uncomment to enable smooth fog of war
			 self.fbo:use(false, self.full_fbo)
			 self.fbo:toScreen(map.display_x, map.display_y, map.viewport.width, map.viewport.height, self.fbo_shader.shad)

			 if self.target then self.target:display() end

		  -- Basic display; no FBOs
		  else
			 map:display(nil, nil, nb_keyframe)
			 if self.target then self.target:display() end
		  end

		-- And the minimap
		--self.level.map:minimapDisplay(self.w - 200, 20, util.bound(self.player.x - 25, 0, self.level.map.w - 50), util.bound(self.player.y - 25, 0, self.level.map.h - 50), 50, 50, 0.6)
	end

	-- We display the player's interface
	self.ui_texture_bar[1]:toScreen(0, self.h * 0.9, self.w * 1.5, self.h * 0.15)
	self.player_display:toScreen(nb_keyframe)
	self.hotkeys_display_icons:toScreen()
	

	if self.player then self.player.changed = false end

	-- Tooltip is displayed over all else
	self:targetDisplayTooltip()

	engine.GameTurnBased.display(self, nb_keyframe)
	if self.full_fbo then
      self.full_fbo:use(false)
      self.full_fbo:toScreen(0, 0, self.w, self.h, self.full_fbo_shader.shad)
   end
end

--- Setup the keybinds
function _M:setupCommands()
	-- Make targeting work
	self.normal_key = self.key
	self:targetSetupKey()

	-- One key handled for normal function
	self.key:unicodeInput(true)
	self.key:addBinds
	{
		-- Movements
		MOVE_LEFT = function() self.player:moveDir(4) end,
		MOVE_RIGHT = function() self.player:moveDir(6) end,
		MOVE_UP = function() self.player:moveDir(8) end,
		MOVE_DOWN = function() self.player:moveDir(2) end,
		MOVE_LEFT_UP = function() self.player:moveDir(7) end,
		MOVE_LEFT_DOWN = function() self.player:moveDir(1) end,
		MOVE_RIGHT_UP = function() self.player:moveDir(9) end,
		MOVE_RIGHT_DOWN = function() self.player:moveDir(3) end,
		MOVE_STAY = function() self.player:useEnergy() end,
		
		RUN = function()
			self.log("Run in which direction?")
			local co = coroutine.create(function()
				local x, y = self.player:getTarget{type="hit", no_restrict=true, range=1, immediate_keys=true, default_target=self.player}
				if x and y then self.player:runInit(util.getDir(x, y, self.player.x, self.player.y)) end
			end)
			local ok, err = coroutine.resume(co)
			if not ok and err then print(debug.traceback(co)) error(err) end
		end,

		RUN_AUTO = function()
			if self.level and self.zone then
				local seen = {}
				-- Check for visible monsters.  Only see LOS actors, so telepathy wont prevent it
				core.fov.calc_circle(self.player.x, self.player.y, self.level.map.w, self.level.map.h, self.player.sight or 10,
					function(_, x, y) return self.level.map:opaque(x, y) end,
					function(_, x, y)
						local actor = self.level.map(x, y, self.level.map.ACTOR)
						if actor and actor ~= self.player and self.player:reactionToward(actor) < 0 and
							self.player:canSee(actor) and self.level.map.seens(x, y) then seen[#seen + 1] = {x=x, y=y, actor=actor} end
					end, nil)
				if self.zone.no_autoexplore or self.level.no_autoexplore then
					self.log("You may not auto-explore this level.")
				elseif #seen > 0 then
					self.log("You may not auto-explore with enemies in sight!")
					for _, node in ipairs(seen) do
					--	node.actor:addParticles(engine.Particles.new("notice_enemy", 1))
					end
				elseif not self.player:autoExplore() then
					self.log("There is nowhere left to explore.")
				end
			end
		end,

		RUN_LEFT = function() self.player:runInit(4) end,
		RUN_RIGHT = function() self.player:runInit(6) end,
		RUN_UP = function() self.player:runInit(8) end,
		RUN_DOWN = function() self.player:runInit(2) end,
		RUN_LEFT_UP = function() self.player:runInit(7) end,
		RUN_LEFT_DOWN = function() self.player:runInit(1) end,
		RUN_RIGHT_UP = function() self.player:runInit(9) end,
		RUN_RIGHT_DOWN = function() self.player:runInit(3) end,

		-- Hotkeys
		HOTKEY_1 = function() self.player:activateHotkey(1) end,
		HOTKEY_2 = function() self.player:activateHotkey(2) end,
		HOTKEY_3 = function() self.player:activateHotkey(3) end,
		HOTKEY_4 = function() self.player:activateHotkey(4) end,
		HOTKEY_5 = function() self.player:activateHotkey(5) end,
		HOTKEY_6 = function() self.player:activateHotkey(6) end,
		HOTKEY_7 = function() self.player:activateHotkey(7) end,
		HOTKEY_8 = function() self.player:activateHotkey(8) end,
		HOTKEY_9 = function() self.player:activateHotkey(9) end,
		HOTKEY_10 = function() self.player:activateHotkey(10) end,
		HOTKEY_11 = function() self.player:activateHotkey(11) end,
		HOTKEY_12 = function() self.player:activateHotkey(12) end,
		HOTKEY_SECOND_1 = function() self.player:activateHotkey(13) end,
		HOTKEY_SECOND_2 = function() self.player:activateHotkey(14) end,
		HOTKEY_SECOND_3 = function() self.player:activateHotkey(15) end,
		HOTKEY_SECOND_4 = function() self.player:activateHotkey(16) end,
		HOTKEY_SECOND_5 = function() self.player:activateHotkey(17) end,
		HOTKEY_SECOND_6 = function() self.player:activateHotkey(18) end,
		HOTKEY_SECOND_7 = function() self.player:activateHotkey(19) end,
		HOTKEY_SECOND_8 = function() self.player:activateHotkey(20) end,
		HOTKEY_SECOND_9 = function() self.player:activateHotkey(21) end,
		HOTKEY_SECOND_10 = function() self.player:activateHotkey(22) end,
		HOTKEY_SECOND_11 = function() self.player:activateHotkey(23) end,
		HOTKEY_SECOND_12 = function() self.player:activateHotkey(24) end,
		HOTKEY_THIRD_1 = function() self.player:activateHotkey(25) end,
		HOTKEY_THIRD_2 = function() self.player:activateHotkey(26) end,
		HOTKEY_THIRD_3 = function() self.player:activateHotkey(27) end,
		HOTKEY_THIRD_4 = function() self.player:activateHotkey(28) end,
		HOTKEY_THIRD_5 = function() self.player:activateHotkey(29) end,
		HOTKEY_THIRD_6 = function() self.player:activateHotkey(30) end,
		HOTKEY_THIRD_7 = function() self.player:activateHotkey(31) end,
		HOTKEY_THIRD_8 = function() self.player:activateHotkey(32) end,
		HOTKEY_THIRD_9 = function() self.player:activateHotkey(33) end,
		HOTKEY_THIRD_10 = function() self.player:activateHotkey(34) end,
		HOTKEY_THIRD_11 = function() self.player:activateHotkey(35) end,
		HOTKEY_THIRD_12 = function() self.player:activateHotkey(36) end,
		HOTKEY_PREV_PAGE = function() self.player:prevHotkeyPage() end,
		HOTKEY_NEXT_PAGE = function() self.player:nextHotkeyPage() end,

		-- Item Management
		PICKUP_FLOOR = function()
			if self.player.no_inventory_access then return end
			self.player:playerPickup()
		end,
		DROP_FLOOR = function()
			if self.player.no_inventory_access then return end
			self.player:playerDrop()
		end,
		SHOW_INVENTORY = function()
			if self.player.no_inventory_access then return end
			local d
			d = self.player:showEquipInven("Inventory", nil, function(o, inven, item, button, event)
				if not o then return end
				local ud = require("mod.dialogs.UseItemDialog").new(event == "button", self.player, o, item, inven, function(_, _, _, stop)
					d:generate()
					d:generateList()
					if stop then self:unregisterDialog(d) end
				end)
				self:registerDialog(ud)
			end)
		end,
		
		-- Actions
		CHANGE_LEVEL = function()
			local e = self.level.map(self.player.x, self.player.y, Map.TERRAIN)
			if self.player:enoughEnergy() and e.change_level then
				self:changeLevel(e.change_zone and e.change_level or self.level.level + e.change_level, e.change_zone)
			else
				self.log("There is no way out of this level here.")
			end
		end,

		REST = function()
			self.player:restInit()
		end,

		USE_TALENTS = function()
			self.player:useTalents()
		end,

		SAVE_GAME = function()
			self:saveGame()
		end,

		SHOW_CHARACTER_SHEET = function()
			self:registerDialog(require("mod.dialogs.CharacterSheet").new(self.player))
		end,
		
		SHOW_MESSAGE_LOG = function()
			self.logdisplay:showLogDialog()
		end,

		-- Exit the game
		QUIT_GAME = function()
			self:onQuit()
		end,

		SCREENSHOT = function() self:saveScreenshot() end,

		EXIT = function()
			local menu menu = require("engine.dialogs.GameMenu").new{
				"resume",
				"keybinds",
				"video",
				"sound",
				"save",
				"quit"
			}
			self:registerDialog(menu)
		end,

		-- Lua console, you probably want to disable it for releases
		LUA_CONSOLE = function()
			self:registerDialog(DebugConsole.new())
		end,

		-- Toggle monster list
		TOGGLE_NPC_LIST = function()
			self.show_npc_list = not self.show_npc_list
			self.player.changed = true
		end,

		TACTICAL_DISPLAY = function()
			if Map.view_faction then
				self.always_target = nil
				Map:setViewerFaction(nil)
			else
				self.always_target = true
				Map:setViewerFaction("players")
			end
		end,

		LOOK_AROUND = function()
			local co = coroutine.create(function() self.player:getTarget{type="hit", no_restrict=true, range=2000} end)
			local ok, err = coroutine.resume(co)
			if not ok and err then print(debug.traceback(co)) error(err) end
		end,
	}
	self.key:setCurrent()
end

function _M:setupMouse(reset)
	if reset then self.mouse:reset() end
	self.mouse:registerZone(Map.display_x, Map.display_y, Map.viewport.width, Map.viewport.height, function(button, mx, my, xrel, yrel, bx, by, event)
		-- Handle targeting
		if self:targetMouse(button, mx, my, xrel, yrel, event) then return end

		-- Handle the mouse movement/scrolling
		self.player:mouseHandleDefault(self.key, self.key == self.normal_key, button, mx, my, xrel, yrel, event)
	end)
	-- Scroll message log
--[[	self.mouse:registerZone(self.logdisplay.display_x, self.logdisplay.display_y, self.w * 0.2, self.h * 0.2, function(button)
		if button == "wheelup" then self.logdisplay:scrollUp(1) end
		if button == "wheeldown" then self.logdisplay:scrollUp(-1) end
	end, {button=true})]]
	-- Use hotkeys with mouse
	self.mouse:registerZone(self.hotkeys_display_icons.display_x, self.hotkeys_display_icons.display_y, self.w, self.h * 0.1, function(button, mx, my, xrel, yrel, bx, by, event)
		self.hotkeys_display_icons:onMouse(button, mx, my, event == "button", function(text) self.tooltip:displayAtMap(nil, nil, self.w, self.h, tostring(text)) end)
	end)
	self.mouse:setCurrent()
end

--- Ask if we really want to close, if so, save the game first
function _M:onQuit()
	self.player:restStop()

	if not self.quit_dialog then
		self.quit_dialog = QuitDialog.new()
		self:registerDialog(self.quit_dialog)
	end
end

--- Requests the game to save
function _M:saveGame()
	-- savefile_pipe is created as a global by the engine
	savefile_pipe:push(self.save_name, "game", self)
	self.log("Saving game...")
end
