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

newEntity{
	define_as = "HEX_BASE",
	display_scale=1/3,
	display_w=8,
	display_h=3,
	display_x=-1,
}

newEntity{
	define_as = "GRASS",
	type = "floor", subtype = "forest",
	name = "grass",
	image="terrain/grass_gradient1.png",
	--default_tile=class.new{_noalpha=false, display = '', color_r=185, color_g=205, color_b=185},
	display='', back_color={r=140, g=200, b=140},
	always_remember = true,
	base = "HEX_BASE",
}

newEntity{
	define_as = "TREE",
	type = "wall", subtype = "forest",
	name = "tree",
	image="terrain/tree1.png",
	default_tile=class.new{_noalpha=false, display = '#', color_r=105, color_g=205, color_b=105},
	display='', back_color={r=60, g=150, b=60},
	always_remember = true,
	does_block_move = true,
	can_pass = {pass_tree=1},
	block_sight = true,
	dig = "GRASS",
	base = "HEX_BASE",
}

newEntity{
	define_as = "DOWN_FOREST",
	subtype = "forest",
	name = "a path deeper into the forest",
	image="terrain/grass2.png",
	default_tile=class.new{_noalpha=false, display = '>', color_r=130, color_g=255, color_b=30},
	display='', back_color={r=100, g=180, b=100},
	notice = true,
	always_remember = true,
	change_level = 1,
	base = "HEX_BASE",
}

newEntity{
	define_as = "UP_FOREST",
	subtype = "forest",
	name = "back the way I came",
	image="terrain/grass2.png",
	default_tile=class.new{_noalpha=false, display = '<', color_r=130, color_g=255, color_b=30},
	display='', back_color={r=100, g=180, b=100},
	notice = true,
	always_remember = true,
	change_level = -1,
	base = "HEX_BASE",
}

