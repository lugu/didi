-- Unit tests for llm.lua (/god, /god_key, /god_undo, /god_reset, origin capture, world context, multi-turn memory)

local function create_mock_env()
	local world_nodes = {}
	local registered_privileges = {}
	local registered_chatcommands = {}
	local registered_entities = {
		["mobs_mc:zombie"] = {},
		["didi:fireball"] = {},
	}
	local registered_craftitems = {}
	local registered_nodes = {
		["air"] = {},
		["mcl_core:stone"] = {},
		["mcl_core:stonebrick"] = {},
		["mcl_core:cobble"] = {},
		["mcl_core:dirt_with_grass"] = {},
		["mcl_core:water_source"] = {},
		["mcl_fire:fire"] = {},
		["mcl_trees:wood_spruce"] = {},
		["didi:crystal"] = {},
	}
	local mod_storage_data = {}
	local chat_messages = {}
	local spawned_entities = {}
	local players = {}
	local http_requests = {}

	local function pos_key(pos)
		return string.format("%d,%d,%d", math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
	end

	_G.vector = {
		new = function(x, y, z)
			return { x = x, y = y, z = z }
		end,
		round = function(v)
			return {
				x = math.floor(v.x + 0.5),
				y = math.floor(v.y + 0.5),
				z = math.floor(v.z + 0.5),
			}
		end,
		offset = function(v, dx, dy, dz)
			return { x = v.x + dx, y = v.y + dy, z = v.z + dz }
		end,
		add = function(a, b)
			if type(b) == "number" then
				return { x = a.x + b, y = a.y + b, z = a.z + b }
			end
			return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
		end,
		subtract = function(a, b)
			if type(b) == "number" then
				return { x = a.x - b, y = a.y - b, z = a.z - b }
			end
			return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
		end,
		multiply = function(v, s)
			return { x = v.x * s, y = v.y * s, z = v.z * s }
		end,
		zero = function()
			return { x = 0, y = 0, z = 0 }
		end,
	}

	_G.core = {
		registered_nodes = registered_nodes,
		registered_entities = registered_entities,
		settings = {
			get = function()
				return nil
			end,
		},
		get_current_modname = function()
			return "didi"
		end,
		get_modpath = function()
			return "."
		end,
		get_mod_storage = function()
			return {
				get_string = function(_, k)
					return mod_storage_data[k] or ""
				end,
				set_string = function(_, k, v)
					mod_storage_data[k] = v
				end,
			}
		end,
		colorize = function(_, text)
			return text
		end,
		chat_send_player = function(name, msg)
			table.insert(chat_messages, { name = name, msg = msg })
		end,
		register_privilege = function(name, def)
			registered_privileges[name] = def
		end,
		register_chatcommand = function(name, def)
			registered_chatcommands[name] = def
		end,
		register_entity = function(name, def)
			registered_entities[name] = def
		end,
		register_craftitem = function(name, def)
			registered_craftitems[name] = def
		end,
		get_node = function(pos)
			local n = world_nodes[pos_key(pos)]
			if n then
				return { name = n.name, param1 = n.param1 or 0, param2 = n.param2 or 0 }
			end
			return { name = "air", param1 = 0, param2 = 0 }
		end,
		set_node = function(pos, node)
			world_nodes[pos_key(pos)] = {
				name = node.name,
				param1 = node.param1 or 0,
				param2 = node.param2 or 0,
			}
		end,
		bulk_set_node = function(positions, node)
			for _, p in ipairs(positions) do
				_G.core.set_node(p, node)
			end
		end,
		add_entity = function(pos, name)
			local ent_obj = {
				pos = { x = pos.x, y = pos.y, z = pos.z },
				name = name,
				removed = false,
				luaentity = {},
				remove = function(self)
					self.removed = true
				end,
				get_luaentity = function(self)
					return self.luaentity
				end,
				set_velocity = function(self, vel)
					self.velocity = vel
				end,
			}
			table.insert(spawned_entities, ent_obj)
			return ent_obj
		end,
		add_particlespawner = function() end,
		get_objects_inside_radius = function()
			return {}
		end,
		get_player_by_name = function(name)
			return players[name]
		end,
		write_json = function(tbl)
			-- Minimal serializer for test inspection
			local function ser(val)
				if type(val) == "string" then
					return string.format("%q", val)
				elseif type(val) == "number" or type(val) == "boolean" then
					return tostring(val)
				elseif type(val) == "table" then
					local is_arr = (#val > 0)
					local parts = {}
					if is_arr then
						for i = 1, #val do
							table.insert(parts, ser(val[i]))
						end
						return "[" .. table.concat(parts, ",") .. "]"
					else
						for k, v in pairs(val) do
							table.insert(parts, string.format("%q:%s", k, ser(v)))
						end
						return "{" .. table.concat(parts, ",") .. "}"
					end
				end
				return "null"
			end
			return ser(tbl)
		end,
		parse_json = function(data)
			return data
		end,
	}

	local http = {
		fetch = function(req, callback)
			table.insert(http_requests, { req = req, callback = callback })
		end,
	}

	local function set_player(name, pos, look_dir)
		players[name] = {
			_pos = pos,
			_look_dir = look_dir,
			_hp = 20,
			get_player_name = function()
				return name
			end,
			is_player = function()
				return true
			end,
			get_pos = function(self)
				return self._pos
			end,
			get_look_dir = function(self)
				return self._look_dir
			end,
			get_hp = function(self)
				return self._hp
			end,
			set_hp = function(self, hp)
				self._hp = hp
			end,
		}
		return players[name]
	end

	local llm = dofile("./llm.lua")(http)

	return {
		llm = llm,
		world_nodes = world_nodes,
		registered_privileges = registered_privileges,
		registered_chatcommands = registered_chatcommands,
		mod_storage_data = mod_storage_data,
		chat_messages = chat_messages,
		spawned_entities = spawned_entities,
		players = players,
		http_requests = http_requests,
		set_player = set_player,
	}
end

-- Test 1: Permissions on /god, /god_key, /god_undo, /god_reset
do
	local env = create_mock_env()
	local priv = env.registered_privileges["god"]
	assert(priv ~= nil, "god privilege must be registered")
	assert(priv.give_to_singleplayer == false, "god privilege must not be granted to singleplayer by default")
	assert(priv.give_to_admin == false, "god privilege must not be granted to admin by default")

	for _, cmd_name in ipairs({ "god", "god_key", "god_undo", "god_reset" }) do
		local cmd = env.registered_chatcommands[cmd_name]
		assert(cmd ~= nil, "/" .. cmd_name .. " command must be registered")
		assert(cmd.privs and cmd.privs.god == true, "/" .. cmd_name .. " must require the 'god' privilege")
	end
	print("[PASS] Test 1: Privilege 'god' and command permissions")
end

-- Test 2: /god_undo restores blocks (including overwritten blocks & metadata params) and removes entities
do
	local env = create_mock_env()
	env.set_player("alice", { x = 10, y = 5, z = 20 }, { x = 0, y = 0, z = 1 }) -- facing +Z

	-- Pre-populate some existing terrain blocks with param2 orientation
	core.set_node({ x = 10, y = 5, z = 26 }, { name = "mcl_core:dirt_with_grass", param1 = 15, param2 = 3 })
	core.set_node({ x = 10, y = 6, z = 26 }, { name = "didi:crystal", param1 = 0, param2 = 2 })

	-- Nothing to undo initially
	local ok_empty = env.registered_chatcommands["god_undo"].func("alice")
	assert(ok_empty == false, "god_undo on empty history should return false")

	-- Execute LLM script that builds a hollow box (which first fills with stonebrick then clears interior)
	-- and spawns a zombie
	local script = [[
		hollow_box(5, 0, -1, 7, 2, 1, "stonebrick", true, true)
		spawn(6, 1, 0, "zombie")
	]]
	local exec_ok = env.llm.execute_llm_code("alice", script)
	assert(exec_ok == true, "execute_llm_code should succeed")

	-- Verify the blocks were changed and entity was spawned
	assert(core.get_node({ x = 10, y = 5, z = 26 }).name == "mcl_core:stonebrick", "floor should be stonebrick")
	assert(core.get_node({ x = 10, y = 6, z = 26 }).name == "air", "interior should be cleared to air")
	assert(#env.spawned_entities == 1 and not env.spawned_entities[1].removed, "zombie should be spawned")

	-- Now run /god_undo
	local undo_ok, undo_msg = env.registered_chatcommands["god_undo"].func("alice")
	assert(undo_ok == true, "god_undo should succeed: " .. tostring(undo_msg))

	-- Verify original blocks (and their param1/param2) and air are restored
	local restored_ground = core.get_node({ x = 10, y = 5, z = 26 })
	assert(restored_ground.name == "mcl_core:dirt_with_grass", "ground should be restored to dirt_with_grass")
	assert(restored_ground.param1 == 15 and restored_ground.param2 == 3, "param1/param2 should be preserved")

	local restored_crystal = core.get_node({ x = 10, y = 6, z = 26 })
	assert(restored_crystal.name == "didi:crystal", "interior crystal overwritten twice (box+clear) must be restored")
	assert(restored_crystal.param2 == 2, "crystal param2 should be preserved")

	assert(core.get_node({ x = 10, y = 7, z = 26 }).name == "air", "roof should be back to air")
	assert(env.spawned_entities[1].removed == true, "spawned zombie should be removed on undo")

	-- Second undo should report nothing left to undo
	local undo_again = env.registered_chatcommands["god_undo"].func("alice")
	assert(undo_again == false, "second god_undo should return false")
	print("[PASS] Test 2: /god_undo restores original blocks and removes spawned entities")
end

-- Test 3: Origin snapshot at invocation time (player moves while LLM is thinking)
do
	local env = create_mock_env()
	env.registered_chatcommands["god_key"].func("alice", "test-api-key")
	local player = env.set_player("alice", { x = 100, y = 10, z = 200 }, { x = 1, y = 0, z = 0 }) -- facing +X

	-- Player invokes /god at (100, 10, 200) facing +X
	local cmd_ok = env.registered_chatcommands["god"].func("alice", "place un crystal devant moi")
	assert(cmd_ok == true, "/god invocation should succeed")
	assert(#env.http_requests == 1, "one HTTP request should be queued")

	-- Simulate player walking far away and turning to +Z while waiting for the LLM response
	player._pos = { x = -500, y = 80, z = -900 }
	player._look_dir = { x = 0, y = 0, z = 1 }

	-- Now the HTTP response arrives from Gemini
	env.http_requests[1].callback({
		succeeded = true,
		code = 200,
		data = {
			candidates = {
				{
					content = {
						parts = {
							{ text = 'place(6, 0, 0, "crystal")' },
						},
					},
				},
			},
		},
	})

	-- The crystal must be placed 6 blocks in front of the ORIGINAL position (100 + 6, 10, 200)
	assert(
		core.get_node({ x = 106, y = 10, z = 200 }).name == "didi:crystal",
		"block must be placed at the position where the player invoked /god"
	)
	assert(
		core.get_node({ x = -500, y = 80, z = -894 }).name == "air",
		"block must NOT be placed at the player's new position"
	)
	print("[PASS] Test 3: Build appears at invocation origin even after player moves away")
end

-- Test 4: World Context & Multi-turn Memory (and sync with /god_undo and /god_reset)
do
	local env = create_mock_env()
	env.registered_chatcommands["god_key"].func("alice", "test-api-key")
	local player = env.set_player("alice", { x = 0, y = 10, z = 0 }, { x = 0, y = 0, z = 1 }) -- facing +Z

	-- Build a terrain floor at y = 9 (which is u = -1) in front of the player
	for z = 1, 25 do
		for x = -8, 8 do
			core.set_node({ x = x, y = 9, z = z }, { name = "mcl_core:dirt_with_grass" })
		end
	end
	-- Put a target block in line of sight at (0, 11, 5)
	core.set_node({ x = 0, y = 11, z = 5 }, { name = "didi:crystal" })

	-- Turn 1: /god fais une tour
	env.registered_chatcommands["god"].func("alice", "fais une tour")
	assert(#env.http_requests == 1, "Turn 1 HTTP request sent")
	local req1_body = env.http_requests[1].req.data
	assert(req1_body:find("mcl_core:dirt_with_grass", 1, true), "World context should include dominant surface block")
	assert(req1_body:find("didi:crystal en (f=5, u=1, r=0)", 1, true), "World context should include raycast target")
	assert(req1_body:find("min u=-1", 1, true), "World context should include ground elevation")

	-- Complete Turn 1
	env.http_requests[1].callback({
		succeeded = true,
		code = 200,
		data = {
			candidates = {
				{
					content = {
						parts = {
							{ text = 'cylinder(10, 0, 0, 3, 8, "stonebrick", true)' },
						},
					},
				},
			},
		},
	})
	assert(#env.llm.conversation_history["alice"] == 1, "Conversation history should have 1 turn")

	-- Player moves 4 blocks forward (z = 4) and invokes Turn 2: /god ajoute un toit
	player._pos = { x = 0, y = 10, z = 4 }
	env.registered_chatcommands["god"].func("alice", "ajoute un toit")
	assert(#env.http_requests == 2, "Turn 2 HTTP request sent")
	local req2_body = env.http_requests[2].req.data

	-- Verify Turn 2 includes Turn 1's model code and the relative offset of Turn 1's origin
	assert(
		req2_body:find("cylinder(10, 0, 0, 3, 8", 1, true),
		"Turn 2 request should include Turn 1 model code in multi-turn contents"
	)
	assert(
		req2_body:find("Origine de la commande précédente dans le repère actuel : (f=-4, u=0, r=0)", 1, true),
		"Turn 2 world context should report relative offset of Turn 1 origin"
	)

	-- Complete Turn 2
	env.http_requests[2].callback({
		succeeded = true,
		code = 200,
		data = {
			candidates = {
				{
					content = {
						parts = {
							{ text = 'cone(6, 8, 0, 4, 5, "spruce_planks")' },
						},
					},
				},
			},
		},
	})
	assert(#env.llm.conversation_history["alice"] == 2, "Conversation history should have 2 turns")

	-- Undoing Turn 2 should also pop Turn 2 from conversation history
	env.registered_chatcommands["god_undo"].func("alice")
	assert(#env.llm.conversation_history["alice"] == 1, "/god_undo should pop the undone turn from conversation history")

	-- /god_reset should clear conversation history
	env.registered_chatcommands["god_reset"].func("alice")
	assert(#env.llm.conversation_history["alice"] == 0, "/god_reset should clear conversation history")
	print("[PASS] Test 4: World context, multi-turn memory, /god_undo sync, and /god_reset")
end

-- Test 5: Multi-step LIFO undo across cylinder, cone, battlements, lightning, explosion, and failed scripts
do
	local env = create_mock_env()
	env.set_player("bob", { x = 0, y = 0, z = 0 }, { x = 0, y = 0, z = 1 })

	-- Seed a stone block that will be blown up by explosion
	core.set_node({ x = 0, y = 0, z = 10 }, { name = "mcl_core:stone", param2 = 1 })

	-- Step A: explosion + lightning
	assert(env.llm.execute_llm_code("bob", [[
		explosion(10, 0, 0, 2)
		lightning(8, 0, 0)
	]]))
	assert(core.get_node({ x = 0, y = 0, z = 10 }).name == "air", "explosion should clear stone")
	assert(core.get_node({ x = 0, y = 0, z = 8 }).name == "mcl_fire:fire", "lightning should place fire")

	-- Step B: script that places a block then errors mid-way
	local ok_err = env.llm.execute_llm_code("bob", [[
		place(5, 0, 0, "crystal")
		error("boom")
	]])
	assert(ok_err == false, "script with error() should return false")
	assert(core.get_node({ x = 0, y = 0, z = 5 }).name == "didi:crystal", "partial block was placed before error")

	-- Undo Step B (the partial failed script)
	local u1 = env.registered_chatcommands["god_undo"].func("bob")
	assert(u1 == true, "undo of partial failed script should succeed")
	assert(core.get_node({ x = 0, y = 0, z = 5 }).name == "air", "partial block should be undone")
	assert(core.get_node({ x = 0, y = 0, z = 10 }).name == "air", "Step A changes should still be present")

	-- Undo Step A (explosion + lightning)
	local u2 = env.registered_chatcommands["god_undo"].func("bob")
	assert(u2 == true, "undo of Step A should succeed")
	assert(core.get_node({ x = 0, y = 0, z = 10 }).name == "mcl_core:stone", "exploded stone should be restored")
	assert(core.get_node({ x = 0, y = 0, z = 8 }).name == "air", "lightning fire should be restored to air")
	print("[PASS] Test 5: Multi-step LIFO undo across explosion, lightning, and partial runtime errors")
end

print("All tests passed successfully!")
