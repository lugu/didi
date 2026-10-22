-- LLM integration for didi mod (Google Gemini API)
-- Provides /llm and /llm_key chat commands, plus medieval building & magic helpers.

return function(http)
	local mod_storage = core.get_mod_storage()
	local modpath = core.get_modpath(core.get_current_modname())

	-- Retrieve the Gemini API key from mod_storage, gemini_key.txt, minetest.conf, or environment
	local function get_api_key()
		local key = mod_storage:get_string("gemini_api_key")
		if key and key ~= "" then
			return key:match("^%s*(.-)%s*$")
		end

		local f = io.open(modpath .. "/gemini_key.txt", "r")
		if f then
			local content = f:read("*a")
			f:close()
			if content then
				content = content:match("^%s*(.-)%s*$")
				if content ~= "" then
					return content
				end
			end
		end

		key = core.settings:get("didi.gemini_api_key") or core.settings:get("gemini_api_key")
		if key and key ~= "" then
			return key:match("^%s*(.-)%s*$")
		end

		if _G.os and _G.os.getenv then
			local env_key = _G.os.getenv("GEMINI_API_KEY")
			if env_key and env_key ~= "" then
				return env_key:match("^%s*(.-)%s*$")
			end
		end

		return nil
	end

	-- Smart block name resolution for VoxeLibre / Mineclonia / Minetest Game
	local BLOCK_CANDIDATES = {
		air = { "air" },
		stone = { "mcl_core:stone", "default:stone" },
		cobble = { "mcl_core:cobble", "default:cobble" },
		cobblestone = { "mcl_core:cobble", "default:cobble" },
		mossycobble = { "mcl_core:mossycobble", "default:mossycobble" },
		stonebrick = { "mcl_core:stonebrick", "default:stonebrick" },
		stone_bricks = { "mcl_core:stonebrick", "default:stonebrick" },
		mossy_stonebrick = { "mcl_core:stonebrickmossy", "mcl_core:mossycobble", "default:stonebrick" },
		cracked_stonebrick = { "mcl_core:stonebrickcracked", "mcl_core:stonebrick", "default:stonebrick" },
		chiseled_stonebrick = { "mcl_core:stonebrickcarved", "mcl_core:stonebrick", "default:stonebrick" },
		wood = { "mcl_core:wood", "mcl_trees:wood_oak", "default:wood" },
		oak_planks = { "mcl_core:wood", "mcl_trees:wood_oak", "default:wood" },
		spruce_planks = { "mcl_core:sprucewood", "mcl_trees:wood_spruce", "mcl_core:wood", "default:pine_wood" },
		dark_oak_planks = { "mcl_core:darkwood", "mcl_trees:wood_dark_oak", "mcl_core:wood", "default:wood" },
		log = { "mcl_core:tree", "mcl_trees:tree_oak", "default:tree" },
		oak_log = { "mcl_core:tree", "mcl_trees:tree_oak", "default:tree" },
		spruce_log = { "mcl_core:sprucetree", "mcl_trees:tree_spruce", "mcl_core:tree", "default:pine_tree" },
		glass = { "mcl_core:glass", "default:glass" },
		fence = { "mcl_fences:oak_fence", "mcl_fences:fence", "default:fence_wood" },
		iron_bars = { "mcl_panes:bar_flat", "mcl_panes:bar", "mcl_fences:oak_fence", "default:fence_wood" },
		wall = { "mcl_walls:stonebrick", "mcl_walls:cobble", "mcl_core:stonebrick", "default:stonebrick" },
		torch = { "mcl_torches:torch", "default:torch" },
		lantern = { "mcl_lanterns:lantern_floor", "mcl_nether:glowstone", "mcl_torches:torch", "default:meselamp" },
		glowstone = { "mcl_nether:glowstone", "default:meselamp", "mcl_core:goldblock" },
		water = { "mcl_core:water_source", "default:water_source" },
		lava = { "mcl_core:lava_source", "default:lava_source" },
		fire = { "mcl_fire:fire", "fire:basic_flame", "mcl_torches:torch" },
		gold = { "mcl_core:goldblock", "default:goldblock" },
		iron = { "mcl_core:ironblock", "default:steelblock" },
		diamond = { "mcl_core:diamondblock", "default:diamondblock" },
		obsidian = { "mcl_core:obsidian", "default:obsidian" },
		red_wool = { "mcl_wool:red", "wool:red" },
		blue_wool = { "mcl_wool:blue", "wool:blue" },
		white_wool = { "mcl_wool:white", "wool:white" },
		black_wool = { "mcl_wool:black", "wool:black" },
		yellow_wool = { "mcl_wool:yellow", "wool:yellow" },
		dirt = { "mcl_core:dirt", "default:dirt" },
		grass = { "mcl_core:dirt_with_grass", "default:dirt_with_grass" },
		sand = { "mcl_core:sand", "default:sand" },
		bookshelf = { "mcl_books:bookshelf", "default:bookshelf" },
		cannon = { "didi:cannon" },
		crystal = { "didi:crystal" },
	}

	local function resolve_node(name)
		if not name or name == "" then
			return "air"
		end
		if name == "air" or core.registered_nodes[name] then
			return name
		end

		local short = name:gsub("^minecraft:", ""):gsub("^default:", ""):gsub("^mcl_core:", ""):lower()
		local candidates = BLOCK_CANDIDATES[short] or BLOCK_CANDIDATES[name:lower()]
		if candidates then
			for _, cand in ipairs(candidates) do
				if core.registered_nodes[cand] then
					return cand
				end
			end
		end

		-- Search registered nodes by suffix
		for reg_name, _ in pairs(core.registered_nodes) do
			if reg_name:lower():match(":" .. short .. "$") then
				return reg_name
			end
		end

		-- Fallback to stonebrick / cobble / crystal so we never place an unknown node
		for _, fallback in ipairs({ "mcl_core:stonebrick", "mcl_core:cobble", "default:stonebrick", "default:stone", "didi:crystal" }) do
			if core.registered_nodes[fallback] then
				return fallback
			end
		end
		return "air"
	end

	local ENTITY_CANDIDATES = {
		zombie = { "mobs_mc:zombie" },
		skeleton = { "mobs_mc:skeleton" },
		spider = { "mobs_mc:spider" },
		creeper = { "mobs_mc:creeper" },
		witch = { "mobs_mc:witch" },
		evoker = { "mobs_mc:evoker" },
		vindicator = { "mobs_mc:vindicator" },
		pillager = { "mobs_mc:pillager" },
		villager = { "mobs_mc:villager" },
		iron_golem = { "mobs_mc:iron_golem" },
		horse = { "mobs_mc:horse" },
		wolf = { "mobs_mc:wolf" },
		sheep = { "mobs_mc:sheep" },
		cow = { "mobs_mc:cow" },
		pig = { "mobs_mc:pig" },
		ender_dragon = { "mobs_mc:enderdragon" },
		dragon = { "mobs_mc:enderdragon" },
		bullet = { "didi:bullet" },
		fireball = { "didi:fireball" },
	}

	local function resolve_entity(name)
		if not name or name == "" then
			return nil
		end
		if core.registered_entities[name] then
			return name
		end
		local short = name:gsub("^minecraft:", ""):gsub("^mobs_mc:", ""):lower()
		local candidates = ENTITY_CANDIDATES[short]
		if candidates then
			for _, cand in ipairs(candidates) do
				if core.registered_entities[cand] then
					return cand
				end
			end
		end
		for reg_name, _ in pairs(core.registered_entities) do
			if reg_name:lower():match(":" .. short .. "$") then
				return reg_name
			end
		end
		return nil
	end

	-- Magical explosion helper
	local function trigger_magic_explosion(world_pos, radius)
		radius = math.min(math.max(tonumber(radius) or 3, 1), 8)
		core.add_particlespawner({
			amount = 80,
			time = 0.2,
			minpos = vector.subtract(world_pos, radius * 0.5),
			maxpos = vector.add(world_pos, radius * 0.5),
			minvel = vector.new(-6, -2, -6),
			maxvel = vector.new(6, 8, 6),
			minexptime = 0.4,
			maxexptime = 1.2,
			minsize = 2,
			maxsize = 5,
			texture = "crystal_block.png",
		})

		local r_int = math.floor(radius)
		local to_clear = {}
		for dx = -r_int, r_int do
			for dy = -r_int, r_int do
				for dz = -r_int, r_int do
					if dx * dx + dy * dy + dz * dz <= radius * radius then
						local p = vector.offset(world_pos, dx, dy, dz)
						local n = core.get_node(p).name
						if n ~= "air" and n ~= "ignore" then
							table.insert(to_clear, p)
						end
					end
				end
			end
		end
		if #to_clear > 0 then
			core.bulk_set_node(to_clear, { name = "air" })
		end

		for _, obj in ipairs(core.get_objects_inside_radius(world_pos, radius + 1.5)) do
			local ent = obj:get_luaentity()
			if obj:is_player() or (ent and ent.name ~= "__builtin:item") then
				obj:set_hp(math.max(0, obj:get_hp() - 8))
			end
		end
	end

	-- Register magical fireball entity (didi:fireball)
	local Fireball = {
		initial_properties = {
			visual = "sprite",
			textures = { "crystal_block.png" },
			physical = true,
			collide_with_objects = true,
			collisionbox = { -0.25, -0.25, -0.25, 0.25, 0.25, 0.25 },
			visual_size = { x = 0.6, y = 0.6 },
			glow = 14,
		},
		_age = 0,
		_shooter = nil,
	}

	function Fireball:on_step(dtime, moveresult)
		self._age = (self._age or 0) + dtime
		local pos = self.object:get_pos()
		if not pos or self._age > 6 then
			self.object:remove()
			return
		end

		core.add_particlespawner({
			amount = 4,
			time = 0.05,
			minpos = vector.subtract(pos, 0.1),
			maxpos = vector.add(pos, 0.1),
			minvel = vector.new(-0.5, -0.5, -0.5),
			maxvel = vector.new(0.5, 0.5, 0.5),
			minexptime = 0.2,
			maxexptime = 0.5,
			minsize = 1.5,
			maxsize = 3,
			texture = "crystal_block.png",
			glow = 14,
		})

		local hit = false
		if moveresult and moveresult.collides then
			for _, col in ipairs(moveresult.collisions or {}) do
				if col.type == "node" then
					hit = true
					break
				elseif col.type == "object" and col.object then
					if not (col.object:is_player() and col.object:get_player_name() == self._shooter) then
						hit = true
						break
					end
				end
			end
		end

		if hit or self.object:get_velocity() == vector.zero() then
			trigger_magic_explosion(pos, 2.5)
			self.object:remove()
		end
	end

	core.register_entity("didi:fireball", Fireball)

	-- Build the sandboxed environment with medieval & magic helpers for a given player
	local create_llm_env
	local execute_llm_code

	create_llm_env = function(player_name)
		local player = core.get_player_by_name(player_name)
		if not player then
			return nil
		end

		local player_pos = vector.round(player:get_pos())
		local look = player:get_look_dir()

		local forward
		if math.abs(look.x) > math.abs(look.z) then
			forward = vector.new(look.x > 0 and 1 or -1, 0, 0)
		else
			forward = vector.new(0, 0, look.z > 0 and 1 or -1)
		end
		local right = vector.new(forward.z, 0, -forward.x)

		local function to_world(f, u, r)
			return vector.new(
				player_pos.x + forward.x * math.floor(f + 0.5) + right.x * math.floor(r + 0.5),
				player_pos.y + math.floor(u + 0.5),
				player_pos.z + forward.z * math.floor(f + 0.5) + right.z * math.floor(r + 0.5)
			)
		end

		local function place(f, u, r, block)
			local node_name = resolve_node(block)
			core.set_node(to_world(f, u, r), { name = node_name })
		end

		local function get_block(f, u, r)
			return core.get_node(to_world(f, u, r)).name
		end

		local function box(f1, u1, r1, f2, u2, r2, block)
			local node_name = resolve_node(block)
			local min_f, max_f = math.min(f1, f2), math.max(f1, f2)
			local min_u, max_u = math.min(u1, u2), math.max(u1, u2)
			local min_r, max_r = math.min(r1, r2), math.max(r1, r2)
			-- Guard against huge accidental volumes
			if (max_f - min_f + 1) * (max_u - min_u + 1) * (max_r - min_r + 1) > 120000 then
				return
			end
			local positions = {}
			for f = min_f, max_f do
				for u = min_u, max_u do
					for r = min_r, max_r do
						table.insert(positions, to_world(f, u, r))
					end
				end
			end
			if #positions > 0 then
				core.bulk_set_node(positions, { name = node_name })
			end
		end

		local function clear(f1, u1, r1, f2, u2, r2)
			box(f1, u1, r1, f2, u2, r2, "air")
		end

		local function hollow_box(f1, u1, r1, f2, u2, r2, block, has_roof, has_floor)
			local min_f, max_f = math.min(f1, f2), math.max(f1, f2)
			local min_u, max_u = math.min(u1, u2), math.max(u1, u2)
			local min_r, max_r = math.min(r1, r2), math.max(r1, r2)
			box(min_f, min_u, min_r, max_f, max_u, max_r, block)
			local inner_u1 = (has_floor == false) and min_u or (min_u + 1)
			local inner_u2 = (has_roof == false) and max_u or (max_u - 1)
			if max_f - min_f >= 2 and max_r - min_r >= 2 and inner_u2 >= inner_u1 then
				clear(min_f + 1, inner_u1, min_r + 1, max_f - 1, inner_u2, max_r - 1)
			end
		end

		local function battlements(f1, r1, f2, r2, u, block)
			local min_f, max_f = math.min(f1, f2), math.max(f1, f2)
			local min_r, max_r = math.min(r1, r2), math.max(r1, r2)
			for f = min_f, max_f do
				if (f - min_f) % 2 == 0 then
					place(f, u, min_r, block)
					place(f, u, max_r, block)
				end
			end
			for r = min_r, max_r do
				if (r - min_r) % 2 == 0 then
					place(min_f, u, r, block)
					place(max_f, u, r, block)
				end
			end
		end

		local function cylinder(f_center, u_base, r_center, radius, height, block, hollow)
			local node_name = resolve_node(block)
			radius = math.min(math.max(tonumber(radius) or 3, 1), 25)
			height = math.min(math.max(tonumber(height) or 6, 1), 60)
			local r_int = math.ceil(radius)
			local wall_positions = {}
			local air_positions = {}
			for u = u_base, u_base + height - 1 do
				for df = -r_int, r_int do
					for dr = -r_int, r_int do
						local dist = math.sqrt(df * df + dr * dr)
						if dist <= radius + 0.35 then
							if hollow and dist < radius - 0.75 then
								table.insert(air_positions, to_world(f_center + df, u, r_center + dr))
							else
								table.insert(wall_positions, to_world(f_center + df, u, r_center + dr))
							end
						end
					end
				end
			end
			if #wall_positions > 0 then
				core.bulk_set_node(wall_positions, { name = node_name })
			end
			if #air_positions > 0 then
				core.bulk_set_node(air_positions, { name = "air" })
			end
		end

		local function cone(f_center, u_base, r_center, radius, height, block)
			local node_name = resolve_node(block)
			radius = math.min(math.max(tonumber(radius) or 4, 1), 25)
			height = math.min(math.max(tonumber(height) or 5, 1), 40)
			local positions = {}
			for dy = 0, height - 1 do
				local cur_r = radius * (1 - dy / height)
				local r_int = math.ceil(cur_r)
				for df = -r_int, r_int do
					for dr = -r_int, r_int do
						if math.sqrt(df * df + dr * dr) <= cur_r + 0.35 then
							table.insert(positions, to_world(f_center + df, u_base + dy, r_center + dr))
						end
					end
				end
			end
			if #positions > 0 then
				core.bulk_set_node(positions, { name = node_name })
			end
		end

		local function spawn(f, u, r, entity_name)
			local ent = resolve_entity(entity_name)
			if ent then
				return core.add_entity(to_world(f, u, r), ent)
			end
			return nil
		end

		local function shoot_fireball(speed)
			local p = core.get_player_by_name(player_name)
			if not p then
				return
			end
			local shoot_dir = p:get_look_dir()
			local start_pos = vector.offset(p:get_pos(), 0, 1.5, 0)
			start_pos = vector.add(start_pos, vector.multiply(shoot_dir, 1.2))
			local obj = core.add_entity(start_pos, "didi:fireball")
			if obj then
				local luaent = obj:get_luaentity()
				if luaent then
					luaent._shooter = player_name
				end
				obj:set_velocity(vector.multiply(shoot_dir, tonumber(speed) or 18))
			end
		end

		local function lightning(f, u, r)
			local wpos = to_world(f, u, r)
			core.add_particlespawner({
				amount = 100,
				time = 0.15,
				minpos = vector.offset(wpos, -0.3, 0, -0.3),
				maxpos = vector.offset(wpos, 0.3, 12, 0.3),
				minvel = vector.new(-1, -20, -1),
				maxvel = vector.new(1, -5, 1),
				minexptime = 0.2,
				maxexptime = 0.5,
				minsize = 3,
				maxsize = 6,
				texture = "crystal_block.png",
				glow = 14,
			})
			local fire_node = resolve_node("fire")
			if core.get_node(wpos).name == "air" then
				core.set_node(wpos, { name = fire_node })
			end
			for _, obj in ipairs(core.get_objects_inside_radius(wpos, 4)) do
				if not (obj:is_player() and obj:get_player_name() == player_name) then
					obj:set_hp(math.max(0, obj:get_hp() - 10))
				end
			end
		end

		local function explosion(f, u, r, radius)
			trigger_magic_explosion(to_world(f, u, r), radius)
		end

		local function heal(amount)
			local p = core.get_player_by_name(player_name)
			if p then
				p:set_hp(p:get_hp() + (tonumber(amount) or 20))
			end
		end

		local function give_item(itemstring)
			local p = core.get_player_by_name(player_name)
			if p then
				p:get_inventory():add_item("main", itemstring)
			end
		end

		local function give_magic_wand(title, spell_lua_code)
			local p = core.get_player_by_name(player_name)
			if not p then
				return
			end
			local stack = _G.ItemStack("didi:magic_wand")
			local meta = stack:get_meta()
			meta:set_string("description", title or "Bâton Magique")
			if spell_lua_code and spell_lua_code ~= "" then
				meta:set_string("didi_spell_code", spell_lua_code)
			end
			p:get_inventory():add_item("main", stack)
		end

		local function say(msg)
			core.chat_send_player(player_name, core.colorize("#55ffff", "[GOD] ") .. tostring(msg))
		end

		local env = {
			-- Coordinate & building helpers
			to_world = to_world,
			place = place,
			get_block = get_block,
			box = box,
			clear = clear,
			hollow_box = hollow_box,
			battlements = battlements,
			cylinder = cylinder,
			cone = cone,
			resolve_node = resolve_node,
			-- Magic & entity helpers
			spawn = spawn,
			shoot_fireball = shoot_fireball,
			lightning = lightning,
			explosion = explosion,
			heal = heal,
			give_item = give_item,
			give_magic_wand = give_magic_wand,
			say = say,
			-- Standard Lua & Luanti globals
			player = player,
			player_name = player_name,
			pos = player_pos,
			forward = forward,
			right = right,
			core = core,
			vector = vector,
			ItemStack = _G.ItemStack,
			math = math,
			table = table,
			string = string,
			ipairs = ipairs,
			pairs = pairs,
			tonumber = tonumber,
			tostring = tostring,
			print = print,
		}
		return env
	end

	execute_llm_code = function(player_name, code)
		-- Strip markdown code blocks if present
		code = code:gsub("^%s*```[%w_]*%s*\n", ""):gsub("\n%s*```%s*$", "")
		code = code:gsub("^%s*```%s*", ""):gsub("%s*```%s*$", "")

		local env = create_llm_env(player_name)
		if not env then
			return false
		end

		local fn, load_err
		if _G.loadstring then
			fn, load_err = _G.loadstring(code)
			if fn and _G.setfenv then
				_G.setfenv(fn, env)
			end
		else
			fn, load_err = load(code, "god", "t", env)
		end

		if not fn then
			core.chat_send_player(
				player_name,
				core.colorize("#ff5555", "[GOD] Erreur de syntaxe Lua : " .. tostring(load_err))
			)
			return false
		end

		local ok, run_err = pcall(fn)
		if not ok then
			core.chat_send_player(
				player_name,
				core.colorize("#ff5555", "[GOD] Erreur d'exécution : " .. tostring(run_err))
			)
			return false
		end
		return true
	end

	-- Register the Magic Wand item (didi:magic_wand)
	core.register_craftitem("didi:magic_wand", {
		description = "Bâton Magique du Moyen-Âge",
		inventory_image = "selector.png",
		stack_max = 1,
		on_use = function(itemstack, user)
			if not user or not user:is_player() then
				return itemstack
			end
			local player_name = user:get_player_name()
			local spell_code = itemstack:get_meta():get_string("didi_spell_code")
			if spell_code and spell_code ~= "" then
				execute_llm_code(player_name, spell_code)
			else
				local env = create_llm_env(player_name)
				if env then
					env.shoot_fireball(20)
				end
			end
			return itemstack
		end,
	})

	local SYSTEM_PROMPT = [[
Tu es un architecte et mage expert dans Luanti (Minetest / VoxeLibre) spécialisé dans le Moyen-Âge (châteaux, tours, donjons, pont-levis, villages médiévaux) et la magie.
L'utilisateur t'envoie une demande via la commande `/god`.
Tu dois répondre UNIQUEMENT avec du code Lua exécutable (sans texte avant ni après, sans balises markdown ```lua).

Système de coordonnées locales relatif au joueur `(f, u, r)` :
- `f` (forward) : distance DEVANT le joueur. `f = 6` est à 6 blocs devant lui. Construis toujours les structures devant le joueur (par exemple entre `f = 6` et `f = 30`).
- `u` (up) : hauteur par rapport aux pieds du joueur (`u = 0` est le niveau du sol, `u = -1` est les fondations).
- `r` (right) : décalage gauche/droite (`r = 0` est centré face au joueur, `r < 0` est à gauche, `r > 0` est à droite).

Fonctions disponibles directement dans ton code Lua :
- `place(f, u, r, block)` : place un bloc en `(f, u, r)`.
- `box(f1, u1, r1, f2, u2, r2, block)` : remplit un pavé plein de `(f1, u1, r1)` à `(f2, u2, r2)`.
- `clear(f1, u1, r1, f2, u2, r2)` : vide la zone avec `"air"`.
- `hollow_box(f1, u1, r1, f2, u2, r2, block, has_roof, has_floor)` : construit des murs creux (idéal pour remparts, salles, donjons).
- `battlements(f1, r1, f2, r2, u, block)` : ajoute des créneaux médiévaux (1 bloc sur 2) sur le contour `(f1, r1)` à `(f2, r2)` à la hauteur `u`.
- `cylinder(f_center, u_base, r_center, radius, height, block, hollow)` : construit une tour ronde (mets `hollow = true` pour une tour creuse).
- `cone(f_center, u_base, r_center, radius, height, block)` : construit un toit pointu conique au sommet d'une tour.
- `spawn(f, u, r, entity_name)` : fait apparaître une entité (`"zombie"`, `"skeleton"`, `"witch"`, `"villager"`, `"iron_golem"`, `"horse"`, `"wolf"`, `"dragon"`).
- `shoot_fireball(speed)` : tire une boule de feu magique explosive.
- `lightning(f, u, r)` : fait tomber la foudre magique en `(f, u, r)`.
- `explosion(f, u, r, radius)` : crée une explosion magique en `(f, u, r)`.
- `heal(amount)` : soigne le joueur.
- `give_magic_wand(title, spell_lua_code)` : donne au joueur un bâton magique personnalisé qui exécutera la chaîne `spell_lua_code` à chaque clic gauche !
- `say(message)` : affiche un court message en français au joueur dans le chat.

Noms de blocs recommandés :
`"stonebrick"`, `"mossy_stonebrick"`, `"cracked_stonebrick"`, `"chiseled_stonebrick"`, `"cobble"`, `"stone"`, `"oak_planks"`, `"spruce_planks"`, `"dark_oak_planks"`, `"oak_log"`, `"spruce_log"`, `"fence"`, `"iron_bars"`, `"glass"`, `"torch"`, `"lantern"`, `"glowstone"`, `"water"`, `"lava"`, `"fire"`, `"gold"`, `"iron"`, `"obsidian"`, `"red_wool"`, `"blue_wool"`, `"white_wool"`, `"bookshelf"`, `"cannon"`, `"crystal"`, `"air"`.

Conseils pour les châteaux et constructions médiévales :
- Fais des constructions détaillées et impressionnantes : douves d'eau (`"water"`), pont en bois (`"spruce_planks"`), 4 tours d'angle rondes (`cylinder(..., true)`) coiffées de toits pointus (`cone(...)`), remparts en `"stonebrick"` avec créneaux (`battlements(...)`), une grande porte avec herse en `"iron_bars"`, un donjon central (`hollow_box(...)`), des drapeaux en `"red_wool"` et de l'éclairage (`"lantern"` ou `"torch"`).
- Termine toujours ton script par un appel à `say("...")` expliquant brièvement ce que tu as créé.
]]

	-- Command to set Gemini API key in-game
	core.register_chatcommand("god_key", {
		params = "<cle_api_gemini>",
		description = "Configure la clé API Google Gemini pour la commande /god",
		func = function(_, param)
			local key = (param or ""):match("^%s*(.-)%s*$")
			if key == "" then
				return false, "Utilisation : /god_key <ta_cle_api_gemini>"
			end
			mod_storage:set_string("gemini_api_key", key)
			return true, core.colorize("#55ff55", "[GOD] Clé API Gemini enregistrée avec succès !")
		end,
	})

	local function call_gemini(name, body, api_key, model, is_retry)
		local url = "https://generativelanguage.googleapis.com/v1beta/models/"
			.. model
			.. ":generateContent?key="
			.. api_key

		http.fetch({
			url = url,
			method = "POST",
			extra_headers = { "Content-Type: application/json" },
			data = body,
			timeout = 180,
		}, function(res)
			local parsed = res.data and core.parse_json(res.data) or nil

			if not res.succeeded or res.code ~= 200 then
				local err_msg = parsed and parsed.error and parsed.error.message
					or ("Code HTTP " .. tostring(res.code))

				-- If the API tells us to use a newer model, switch to it automatically and retry
				local suggested_model = not is_retry and tostring(err_msg):match("use models/([%w%-%._]+)")
				if suggested_model and suggested_model ~= model then
					mod_storage:set_string("gemini_model", suggested_model)
					call_gemini(name, body, api_key, suggested_model, true)
					return
				end

				core.chat_send_player(
					name,
					core.colorize("#ff5555", "[GOD] Erreur Gemini : " .. tostring(err_msg))
				)
				return
			end

			if
				not parsed
				or not parsed.candidates
				or not parsed.candidates[1]
				or not parsed.candidates[1].content
				or not parsed.candidates[1].content.parts
				or not parsed.candidates[1].content.parts[1]
			then
				core.chat_send_player(
					name,
					core.colorize("#ff5555", "[GOD] Réponse Gemini invalide.")
				)
				return
			end

			local lua_code = parsed.candidates[1].content.parts[1].text or ""
			execute_llm_code(name, lua_code)
		end)
	end

	-- Main /god command
	core.register_chatcommand("god", {
		params = "<demande>",
		description = "Demande au LLM de créer quelque chose (ex: /god fais un chateau devant moi)",
		func = function(name, param)
			local prompt = (param or ""):match("^%s*(.-)%s*$")
			if prompt == "" then
				return false, "Utilisation : /god <ta demande> (ex: /god fais un chateau devant moi)"
			end

			if not http then
				return false,
					core.colorize(
						"#ff5555",
						"[GOD] L'API HTTP n'est pas activée pour le mod 'didi'. Ajoute 'secure.http_mods = didi' dans ~/.minetest/minetest.conf puis relance Luanti."
					)
			end

			local api_key = get_api_key()
			if not api_key then
				return false,
					core.colorize(
						"#ffaa00",
						"[GOD] Aucune clé API Gemini trouvée. Tape `/god_key <ta_cle_api>` dans le chat (ou mets ta clé dans ~/.minetest/mods/didi/gemini_key.txt)."
					)
			end

			local stored_model = mod_storage:get_string("gemini_model")
			local model = core.settings:get("didi.gemini_model")
				or (stored_model ~= "" and stored_model)
				or "gemini-3.8-flash"

			local body = core.write_json({
				system_instruction = {
					parts = { { text = SYSTEM_PROMPT } },
				},
				contents = {
					{
						role = "user",
						parts = { { text = prompt } },
					},
				},
				generationConfig = {
					temperature = 0.4,
				},
			})

			core.chat_send_player(
				name,
				core.colorize("#ffff55", "[GOD] Invocation en cours : \"" .. prompt .. "\"...")
			)

			call_gemini(name, body, api_key, model, false)
			return true
		end,
	})
end
