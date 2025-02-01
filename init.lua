print("Welcome to didi - from the mod")
-- Documentation: https://api.luanti.org/mods/
-- Book: https://rubenwardy.com/minetest_modding_book/en/

minetest.register_node("didi:crystal", {
	description = "Le crystal d'Orion",
	tiles = {
		"crystal_block.png",
	},
        is_ground_content = true,
        groups = {cracky = 1},
        -- Use the drop property to drop something a specific item.
        -- drop = "didi:crystal_fragments"
        on_construct = function (pos, node)
            -- set a random number between 0 and 9 in the meta data of the node
            local meta = core.get_meta(pos)
            meta:set_int("random_number", math.random(0,9))
            print("crystal on_construct" .. meta:get_int("random_number"))
        end,
        on_destruct = function (pos, node)
            -- get the random number from the meta data of the node
            local meta = core.get_meta(pos)
            local random_number = meta:get_int("random_number")
            print("crystal on_destruct" .. random_number)
            -- drop a specific item based on the random number
            if random_number == 0 then
                minetest.add_item(pos, "mobs_mc:diamond_horse_armor")
            elseif random_number == 1 then
                minetest.add_item(pos, "mcl_tools:pick_diamond")
            elseif random_number == 2 then
                minetest.add_item(pos, "mcl_core:apple_gold_enchanted")
            elseif random_number == 3 then
                minetest.add_item(pos, "mcl_mobitems:nautilus_shell")
            elseif random_number == 4 then
                minetest.add_item(pos, "mcl_raw_ores:raw_iron_block")
            elseif random_number == 5 then
                minetest.add_item(pos, "mcl_tools:pick_netherite")
            elseif random_number == 6 then
                minetest.add_item(pos, "mcl_mobs:nametag")
            elseif random_number == 7 then
                minetest.add_item(pos, "mcl_nether:netherite_ingot")
            elseif random_number == 8 then
                minetest.add_item(pos, "mcl_mobitems:nautilus_shell")
            elseif random_number == 9 then
                minetest.add_item(pos, "mcl_core:dirt ")
            end
        end,
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            if clicker:is_player() then
                print("crystal on_rightclick")
            end
        end,
})
minetest.register_node("didi:cannon", {
	description = "Le cannon d'Yvain",
        drawtype = "mesh",
        mesh = "cannon.glb",
        -- collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
        -- visual_scale = 1,
        -- paramtype2 = "facedir",
	tiles = {
		"cannon_block_2.png",
	},
        is_ground_content = true,
        groups = {cracky = 1},
})
-- register a method to be called when the block is destroyed.
