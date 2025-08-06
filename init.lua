print("    *              *         ")
print("    *    *         *    *    ")
print("    *              *         ")
print("*** *   **     *** *   **    ")
print("   **    *    *   **    *    ")
print("    *    *    *    *    *    ")
print("    *    *    *    *    *    ")
print("   **    *    *   **    *    ")
print("*** *  *****   *** *  *****  ")

-- Documentation: https://api.luanti.org/mods/
-- Book: https://rubenwardy.com/core_modding_book/en/
-- Course: https://www.codecademy.com/courses/learn-lua/lessons/introduction-to-lua/exercises/review

-- TODO: make a chest
-- local chestusage = "To access its inventory, rightclick it. When broken, the items will drop out."
--
-- require(core.get_modpath("mcl_chests"))
--
-- mcl_chests.register_chest("didi:foam_chest", {
-- 	desc = "Chest",
-- 	longdesc = "Chests are containers which provide 27 inventory slots. Chests can be turned into large chests with "
-- 		.. "double the capacity by placing two chests next to each other.",
-- 	usagehelp = chestusage,
-- 	tt_help = "27 inventory slots\nCan be combined to a large chest",
-- 	tiles = {
-- 		small = mcl_chests.tiles.chest_normal_small,
-- 		double = mcl_chests.tiles.chest_normal_double,
-- 		inv = {
-- 			"foam_block.png",
-- 			"foam_block.png",
-- 			"foam_block.png",
-- 			"foam_block.png",
-- 			"foam_block.png",
-- 			"foam_block.png",
-- 		},
-- 	},
-- 	groups = {
-- 		handy = 1,
-- 		axey = 1,
-- 		material_wood = 1,
-- 		flammable = -1,
-- 	},
-- 	sounds = { mcl_sounds.node_sound_wood_defaults() },
-- 	hardness = 2.5,
-- 	hidden = false,
-- })

-- Dragon head
core.register_craftitem("didi:dragon_head", {
	description = "Dragon Head from Orion",
	inventory_image = "dragon_item.png",
	visual = "mesh",
	mesh = "dragon_head.glb",
	textures = {
		"dragon_white.png",
		"dragon_black.png",
	},
})

local function get_chest_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec = "size[8,9]" .. "list[context;main;0,0;8,4;]" .. "list[current_player;main;0,5;8,4;]"
	return formspec
end

core.register_node("didi:crystal", {
	description = "Le crystal d'Orion",
	paramtype2 = "facedir",
	tiles = {
		"crystal_block.png",
	},
	groups = { dig_immediate = 2, choppy = 3 },
	-- Use the drop property to drop something a specific item.
	-- drop = "didi:crystal_fragments"
	on_construct = function(pos, node)
		-- set a random number between 0 and 9 in the meta data of the node
		local meta = core.get_meta(pos)
		meta:set_int("random_number", math.random(0, 9))
		print("crystal on_construct" .. meta:get_int("random_number"))
	end,
	on_rightclick = function(pos, node, clicker)
		local meta = core.get_meta(pos)
		local random_number = meta:get_int("random_number")
		local player_name = clicker:get_player_name()
		-- if random_number ~= 8 then
		-- 	core.chat_send_player(player_name, core.colorize("#ff0000", "Wrong crystal!"))
		-- 	core.log("action", player_name .. " tried to access the wrong chest")
		-- 	return
		-- end
		core.show_formspec(player_name, "didi:crystal", get_chest_formspec(pos))
	end,
})

core.register_node("didi:selector", {
	description = "Le selecteur de coffres du tresor d'Orion",
	drawtype = "glasslike",
	tiles = {
		"selector.png",
	},
	on_construct = function(pos, node)
		-- set a random number between 0 and 9 in the meta data of the node
		local meta = core.get_meta(pos)
		local direction = (math.random() > 0.5) and 1 or -1
		meta:set_int("selection_direction", direction)
	end,
	groups = { cracky = 3, stone = 1 },
	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		print("selector on_rightclick")

		-- decide the direction based on the state of the selector.
		local meta = core.get_meta(pos)
		local direction = meta:get_int("selection_direction")

		-- swith the value of direction so the next time the blocks appear
		-- on the other side.
		local direction = -1 * direction
		meta:set_int("selection_direction", direction)

		-- Create 5 blocks of type didi:crystal on current direction.
		for i = 1, 5 do
			local crystal_pos = pos + vector.new(direction * i, 0, 0)
			core.set_node(crystal_pos, { name = "didi:crystal" })
		end
		for i = 1, 5 do
			local crystal_pos = pos + vector.new(direction * -i, 0, 0)
			core.set_node(crystal_pos, { name = "air" })
		end
	end,
})

core.register_node("didi:cannon", {
	description = "Le cannon d'Yvain",
	drawtype = "mesh",
	mesh = "cannon.glb",
	tiles = {
		"cannon_block_3.png",
	},
	is_ground_content = true,
	groups = { cracky = 1 },

	on_construct = function(pos, node)
		-- store direction to shoot the bullet
		local meta = core.get_meta(pos)
		meta:set_int("bullet_direction_x", 1)
		meta:set_int("bullet_direction_z", 0)
	end,

	on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
		print("cannon on_rightclick")
		-- decide which direction to shoot
		local meta = core.get_meta(pos)
		local x = meta:get_int("bullet_direction_x")
		local z = meta:get_int("bullet_direction_z")
		local bullet_direction = vector.new(x, 0, z)

		-- cannon change direction each times it shoots.
		meta:set_int("bullet_direction_x", -z)
		meta:set_int("bullet_direction_z", x)

		-- create the bullet
		local bullet_pos = vector.add(pos, bullet_direction * 0.5)
		local obj = core.add_entity(bullet_pos, "didi:bullet", nil)
		local velocity = obj:get_luaentity()._velocity
		obj:set_velocity(bullet_direction * velocity)
	end,
})

-- Bullet entity
-- Moves forward until it hits an obstacle.
local Bullet = {
	initial_properties = {
		visual = "mesh",
		mesh = "bullet.glb",
		textures = { "bullet_rust.png" },
		physical = true,
		collide_with_objects = true,
		collisionbox = { -0.3, -0.3, -0.3, 0.3, 0.3, 0.3 },
		-- FIXME: are those properties really needed?
		hp_max = 1,
		visual_size = { x = 0.4, y = 0.4 },
		spritediv = { x = 1, y = 1 },
		initial_sprite_basepos = { x = 0, y = 0 },
	},
	_velocity = 8, -- speed of the bullet
	_max_distance = 100, -- how far the bullet goes
}

function Bullet:on_step(dtime)
	-- make the bullet disapear once it has hit an obstacle
	if self.object:get_velocity() == vector.zero() then
		self.object:set_hp(0)
	end
end

core.register_entity("didi:bullet", Bullet)
