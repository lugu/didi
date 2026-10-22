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

local http = core.request_http_api()

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

local S = core.get_translator(core.get_current_modname())
local C = core.colorize
local F = core.formspec_escape

local DISPENSER_COOLDOWN = 0.19

local dispenser_formspec
if _G.mcl_formspec then
	dispenser_formspec = table.concat({
		"formspec_version[4]",
		"size[11.75,10.425]",

		"label[4.125,0.375;" .. F(C(_G.mcl_formspec.label_color, S("Dispenser"))) .. "]",

		_G.mcl_formspec.get_itemslot_bg_v4(4.125, 0.75, 3, 3),
		"list[context;main;4.125,0.75;3,3;]",

		"label[0.375,4.7;" .. F(C(_G.mcl_formspec.label_color, S("Inventory"))) .. "]",

		_G.mcl_formspec.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
		"list[current_player;main;0.375,5.1;9,3;9]",

		_G.mcl_formspec.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
		"list[current_player;main;0.375,9.05;9,1;]",

		"listring[context;main]",
		"listring[current_player;main]",
	})
else
	dispenser_formspec = table.concat({
		"size[8,9]",
		"label[2.5,0;Dispenser]",
		"list[context;main;2.5,0.5;3,3;]",
		"list[current_player;main;0,5;8,4;]",
		"listring[context;main]",
		"listring[current_player;main]",
	})
end

local function setup_dispenser(pos)
	local meta = core.get_meta(pos)
	meta:set_string("formspec", dispenser_formspec)
	local inv = meta:get_inventory()
	inv:set_size("main", 9)
end

local function orientate_dispenser(pos, placer)
	if not placer then
		return
	end

	local pitch_deg = placer:get_look_vertical() * (180 / math.pi)
	local node = core.get_node(pos)
	if pitch_deg > 55 then
		core.swap_node(pos, { name = "didi:cannon_up", param2 = node.param2 })
	elseif pitch_deg < -55 then
		core.swap_node(pos, { name = "didi:cannon_down", param2 = node.param2 })
	end
end

local function drop_dispensed_item(pos, droppos, dropitem, inv, stack_id, stack)
	local pos_variation = 100
	droppos = vector.offset(
		droppos,
		math.random(-pos_variation, pos_variation) / 1000,
		math.random(-pos_variation, pos_variation) / 1000,
		math.random(-pos_variation, pos_variation) / 1000
	)
	local item_entity = core.add_item(droppos, dropitem)
	if item_entity then
		local drop_vel = vector.subtract(droppos, pos)
		local speed = 3
		item_entity:set_velocity(vector.multiply(drop_vel, speed))
	end
	stack:take_item()
	inv:set_stack("main", stack_id, stack)
end

local function activate_cannon(pos)
	local node = core.get_node(pos)
	local meta = core.get_meta(pos)
	local inv = meta:get_inventory()

	local droppos, dropdir
	if node.name == "didi:cannon_up" then
		dropdir = vector.new(0, 1, 0)
		droppos = vector.offset(pos, 0, 1, 0)
	elseif node.name == "didi:cannon_down" then
		dropdir = vector.new(0, -1, 0)
		droppos = vector.offset(pos, 0, -1, 0)
	else
		dropdir = vector.multiply(core.facedir_to_dir(node.param2 % 32), -1)
		droppos = vector.add(pos, dropdir)
	end

	local dropnode = core.get_node(droppos)
	local dropnodedef = core.registered_nodes[dropnode.name]
	if not dropnodedef then
		dropnodedef = core.registered_nodes["mapgen_stone"]
	end

	local stacks = {}
	for i = 1, inv:get_size("main") do
		local stack = inv:get_stack("main", i)
		if not stack:is_empty() then
			table.insert(stacks, { stack = stack, stackpos = i })
		end
	end

	if #stacks < 1 then
		return
	end

	local r = math.random(1, #stacks)
	local stack = stacks[r].stack
	local dropitem = _G.ItemStack(stack)
	dropitem:set_count(1)
	local stack_id = stacks[r].stackpos
	local iname = stack:get_name()
	local stackdef = core.registered_items[iname]

	if not stackdef then
		return
	end

	local igroups = stackdef.groups or {}

	-- Dispense item on luaentity (if supported by entity)
	for _, obj in ipairs(core.get_objects_inside_radius(droppos, 1)) do
		local ent = obj:get_luaentity()
		if ent and ent._on_dispense then
			local obj_pos = obj:get_pos()
			local od_ret = ent:_on_dispense(stack, obj_pos, droppos, dropnode, dropdir)
			if od_ret then
				inv:set_stack("main", stack_id, od_ret)
				if _G.mcl_redstone and _G.mcl_redstone.update_comparators then
					_G.mcl_redstone.update_comparators(pos)
				end
				return
			end
		end
	end

	-- Armor, mob heads and pumpkins
	if igroups.armor and _G.mcl_armor then
		local droppos_below = vector.offset(droppos, 0, -1, 0)
		for _, objs in ipairs({
			core.get_objects_inside_radius(droppos, 1),
			core.get_objects_inside_radius(droppos_below, 1),
		}) do
			for _, obj in ipairs(objs) do
				stack = _G.mcl_armor.equip(stack, obj)
				if stack:is_empty() then
					break
				end
			end
			if stack:is_empty() then
				break
			end
		end

		if not stack:is_empty() then
			if igroups.head or iname == "mcl_farming:pumpkin_face" then
				if dropnodedef and dropnodedef.buildable_to then
					core.set_node(droppos, { name = iname, param2 = node.param2 % 32 })
					stack:take_item()
				end
			end
		end

		inv:set_stack("main", stack_id, stack)

	-- Use shears on sheep / snowmen / mooshrooms
	elseif igroups.shears then
		for _, obj in pairs(core.get_objects_inside_radius(droppos, 1)) do
			local entity = obj:get_luaentity()
			if entity and not entity.child and not entity.gotten then
				local entname = entity.name
				local ent_pos = obj:get_pos()
				local used, texture = false, nil
				if entname == "mobs_mc:sheep" then
					if entity.drops and entity.drops[2] then
						core.add_item(ent_pos, entity.drops[2].name .. " " .. math.random(1, 3))
					end
					if not entity.color then
						entity.color = "unicolor_white"
					end
					entity.base_texture = { "blank.png", "mobs_mc_sheep.png" }
					texture = entity.base_texture
					entity.drops = {
						{ name = "mcl_mobitems:mutton", chance = 1, min = 1, max = 2 },
					}
					used = true
				elseif entname == "mobs_mc:snowman" then
					texture = {
						"mobs_mc_snowman.png",
						"blank.png", "blank.png",
						"blank.png", "blank.png",
						"blank.png", "blank.png",
					}
					used = true
				elseif entname == "mobs_mc:mooshroom" and _G.mcl_util then
					local mush_pos = vector.offset(ent_pos, 0, 1.4, 0)
					if entity.base_texture and entity.base_texture[1] == "mobs_mc_mooshroom_brown.png" then
						core.add_item(mush_pos, "mcl_mushrooms:mushroom_brown 5")
					else
						core.add_item(mush_pos, "mcl_mushrooms:mushroom_red 5")
					end
					obj = _G.mcl_util.replace_mob(obj, "mobs_mc:cow")
					entity = obj:get_luaentity()
					used = true
				end
				if used then
					obj:set_properties({ textures = texture })
					entity.gotten = true
					core.sound_play("mcl_tools_shears_cut", { pos = ent_pos }, true)
					if stackdef._mcl_diggroups and stackdef._mcl_diggroups.shearsy then
						stack:add_wear(65535 / stackdef._mcl_diggroups.shearsy.uses)
					end
					if _G.tt and _G.tt.reload_itemstack_description then
						_G.tt.reload_itemstack_description(stack)
					end
					inv:set_stack("main", stack_id, stack)
					break
				end
			end
		end

	-- Spawn Egg
	elseif igroups.spawn_egg then
		if dropnodedef and not dropnodedef.walkable then
			core.add_entity(droppos, stack:get_name())
			stack:take_item()
			inv:set_stack("main", stack_id, stack)
		end

	-- Generalized dispension (arrows, splash/lingering potions, TNT, buckets, fire charges, etc.)
	elseif dropnodedef and (not dropnodedef.walkable or stackdef._dispense_into_walkable) then
		local dispense_fn = stackdef._on_dispense
		local dispense_item = dropitem

		-- Also allow regular drinkable potions to be dispensed like splash potions
		if not dispense_fn and core.registered_items[iname .. "_splash"] then
			local splash_def = core.registered_items[iname .. "_splash"]
			if splash_def._on_dispense then
				dispense_fn = splash_def._on_dispense
				dispense_item = _G.ItemStack(iname .. "_splash")
				dispense_item:get_meta():from_table(dropitem:get_meta():to_table())
			end
		end

		if dispense_fn then
			local od_ret = dispense_fn(dispense_item, pos, droppos, dropnode, dropdir)
			if od_ret then
				local newcount = stack:get_count() - 1
				stack:set_count(newcount)
				inv:set_stack("main", stack_id, stack)
				if newcount == 0 then
					inv:set_stack("main", stack_id, od_ret)
				elseif inv:room_for_item("main", od_ret) then
					inv:add_item("main", od_ret)
				else
					drop_dispensed_item(pos, droppos, od_ret, inv, stack_id, stack)
				end
			else
				stack:take_item()
				inv:set_stack("main", stack_id, stack)
			end
		else
			drop_dispensed_item(pos, droppos, dropitem, inv, stack_id, stack)
		end
	end

	if _G.mcl_redstone and _G.mcl_redstone.update_comparators then
		_G.mcl_redstone.update_comparators(pos)
	end
end

local cannon_def = {
	description = "Le cannon d'Yvain",
	_tt_help = S("9 inventory slots") .. "\n" .. S("Launches item when powered by redstone power"),
	is_ground_content = false,
	sounds = _G.mcl_sounds and _G.mcl_sounds.node_sound_stone_defaults() or nil,
	groups = { pickaxey = 1, container = 2, material_stone = 1, dispenser = 1, cracky = 1 },
	paramtype2 = "facedir",
	on_construct = setup_dispenser,
	after_place_node = function(pos, placer)
		setup_dispenser(pos)
		orientate_dispenser(pos, placer)
	end,
	after_dig_node = function(pos, _, oldmetadata)
		local meta = core.get_meta(pos)
		local meta2 = meta:to_table()
		meta:from_table(oldmetadata)
		local inv = meta:get_inventory()
		for i = 1, inv:get_size("main") do
			local stack = inv:get_stack("main", i)
			if not stack:is_empty() then
				core.add_item(
					vector.offset(pos, math.random(0, 10) / 10 - 0.5, 0, math.random(0, 10) / 10 - 0.5),
					stack
				)
			end
		end
		meta:from_table(meta2)
	end,
	allow_metadata_inventory_move = function(pos, _, _, _, _, count, player)
		local name = player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return 0
		else
			return count
		end
	end,
	allow_metadata_inventory_take = function(pos, _, _, stack, player)
		local name = player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return 0
		else
			return stack:get_count()
		end
	end,
	allow_metadata_inventory_put = function(pos, _, _, stack, player)
		local name = player:get_player_name()
		if core.is_protected(pos, name) then
			core.record_protection_violation(pos, name)
			return 0
		else
			return stack:get_count()
		end
	end,
	on_metadata_inventory_put = function(pos)
		if _G.mcl_redstone and _G.mcl_redstone.update_comparators then
			_G.mcl_redstone.update_comparators(pos)
		end
	end,
	on_metadata_inventory_take = function(pos)
		if _G.mcl_redstone and _G.mcl_redstone.update_comparators then
			_G.mcl_redstone.update_comparators(pos)
		end
	end,
	on_rotate = _G.screwdriver and _G.screwdriver.rotate_simple or nil,
	_mcl_blast_resistance = 3.5,
	_mcl_hardness = 3.5,
	-- VoxeLibre / MineClone2 redstone (mesecons)
	mesecons = {
		effector = {
			action_on = function(pos)
				local meta = core.get_meta(pos)
				local gametime = core.get_gametime()
				if gametime and gametime < meta:get_float("cooldown") then
					return
				end
				if gametime then
					meta:set_float("cooldown", gametime + DISPENSER_COOLDOWN)
				end
				activate_cannon(pos)
			end,
			rules = _G.mesecon and _G.mesecon.rules and _G.mesecon.rules.alldirs or nil,
		},
	},
	-- Mineclonia redstone (mcl_redstone)
	_mcl_redstone = {
		connects_to = function()
			return true
		end,
		update = function(pos, node)
			local oldpowered = math.floor(node.param2 / 32) ~= 0
			local powered = _G.mcl_redstone.get_power(pos) ~= 0
			if powered and not oldpowered then
				activate_cannon(pos)
			end
			return {
				name = node.name,
				param2 = node.param2 % 32 + (powered and 32 or 0),
			}
		end,
	},
}

-- Horizontal dispenser cannon
local horizontal_def = table.copy(cannon_def)
horizontal_def.tiles = {
	"default_furnace_top.png",
	"default_furnace_bottom.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"mcl_dispensers_dispenser_front_horizontal.png",
}
core.register_node("didi:cannon", horizontal_def)

-- Downwards-facing dispenser cannon
local down_def = table.copy(cannon_def)
down_def.description = S("Downwards-Facing Dispenser")
down_def.after_place_node = setup_dispenser
down_def.tiles = {
	"default_furnace_top.png",
	"mcl_dispensers_dispenser_front_vertical.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
}
down_def.groups = {
	pickaxey = 1,
	container = 2,
	not_in_creative_inventory = 1,
	material_stone = 1,
	dispenser = 1,
	cracky = 1,
}
down_def._doc_items_create_entry = false
down_def.drop = "didi:cannon"
core.register_node("didi:cannon_down", down_def)

-- Upwards-facing dispenser cannon
local up_def = table.copy(down_def)
up_def.description = S("Upwards-Facing Dispenser")
up_def.tiles = {
	"mcl_dispensers_dispenser_front_vertical.png",
	"default_furnace_bottom.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
	"default_furnace_side.png",
}
core.register_node("didi:cannon_up", up_def)

-- Original Minecraft Dispenser crafting recipe:
-- 7 Cobblestone, 1 Bow in the center, 1 Redstone dust at the bottom center
local redstone_item = core.registered_items["mcl_redstone:redstone"] and "mcl_redstone:redstone"
	or "mesecons:redstone"

local cannon_recipe = {
	{ "mcl_core:cobble", "mcl_core:cobble", "mcl_core:cobble" },
	{ "mcl_core:cobble", "mcl_bows:bow", "mcl_core:cobble" },
	{ "mcl_core:cobble", redstone_item, "mcl_core:cobble" },
}

core.clear_craft({ recipe = cannon_recipe })
core.register_craft({
	output = "didi:cannon",
	recipe = cannon_recipe,
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
	_damage = 4, -- damage points the bullet inflicts
}

function Bullet:on_step(dtime, moveresult)
	-- make the bullet disapear once it has hit an obstacle
	if self.object:get_velocity() == vector.zero() then
		self.object:set_hp(0)
	end

	-- Check for collisions with other objects.
	if moveresult and moveresult.collisions then
		for _, collision in ipairs(moveresult.collisions) do
			if collision.type == "object" and collision.object then
				local collided_object = collision.object
				local collided_entity = collided_object:get_luaentity()

				-- Check if the collided object is a player or an NPC.
				if collided_object:is_player() or (collided_entity and collided_entity.name ~= "__builtin:item") then
					-- Deal damage to the collided object.
					collided_object:set_hp(collided_object:get_hp() - self._damage)
					-- Remove the bullet after hitting a target.
					self.object:set_hp(0)
					return -- Exit the function to prevent multiple hits from one bullet.
				end
			end
		end
	end
end

core.register_entity("didi:bullet", Bullet)

-- Load LLM commands & medieval/magic builders (/llm, /llm_key, didi:magic_wand)
dofile(core.get_modpath(core.get_current_modname()) .. "/llm.lua")(http)
