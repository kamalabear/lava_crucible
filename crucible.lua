-- Define crucible
print("[lava_crucible] Loading crucible.lua - Recipe registration debugging enabled")

-- Single crucible: half height (walls reach y=0.0)
local cbox = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},  -- Bottom
    {-0.5, -0.4, -0.5, -0.4,  0.0,  0.5},  -- West wall
    { 0.4, -0.4, -0.5,  0.5,  0.0,  0.5},  -- East wall
    {-0.4, -0.4, -0.5,  0.4,  0.0, -0.4},  -- North wall
    {-0.4, -0.4,  0.4,  0.4,  0.0,  0.5},  -- South wall
}

-- Double crucible: three-quarter height (walls reach y=0.25)
local cbox_double = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},
    {-0.5, -0.4, -0.5, -0.4,  0.25,  0.5},
    { 0.4, -0.4, -0.5,  0.5,  0.25,  0.5},
    {-0.4, -0.4, -0.5,  0.4,  0.25, -0.4},
    {-0.4, -0.4,  0.4,  0.4,  0.25,  0.5},
}

-- Quad crucible: full height (walls reach y=0.5)
local cbox_quad = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},
    {-0.5, -0.4, -0.5, -0.4,  0.5,  0.5},
    { 0.4, -0.4, -0.5,  0.5,  0.5,  0.5},
    {-0.4, -0.4, -0.5,  0.4,  0.5, -0.4},
    {-0.4, -0.4,  0.4,  0.4,  0.5,  0.5},
}

-- Filled variants: same walls + interior fill slab
local cbox_filled = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},
    {-0.5, -0.4, -0.5, -0.4,  0.0,  0.5},
    { 0.4, -0.4, -0.5,  0.5,  0.0,  0.5},
    {-0.4, -0.4, -0.5,  0.4,  0.0, -0.4},
    {-0.4, -0.4,  0.4,  0.4,  0.0,  0.5},
    {-0.4, -0.4, -0.4,  0.4, -0.05, 0.4},  -- fill
}
local cbox_double_filled = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},
    {-0.5, -0.4, -0.5, -0.4,  0.25,  0.5},
    { 0.4, -0.4, -0.5,  0.5,  0.25,  0.5},
    {-0.4, -0.4, -0.5,  0.4,  0.25, -0.4},
    {-0.4, -0.4,  0.4,  0.4,  0.25,  0.5},
    {-0.4, -0.4, -0.4,  0.4,  0.20, 0.4},  -- fill
}
local cbox_quad_filled = {
    {-0.5, -0.5, -0.5,  0.5, -0.4,  0.5},
    {-0.5, -0.4, -0.5, -0.4,  0.5,  0.5},
    { 0.4, -0.4, -0.5,  0.5,  0.5,  0.5},
    {-0.4, -0.4, -0.5,  0.4,  0.5, -0.4},
    {-0.4, -0.4,  0.4,  0.4,  0.5,  0.5},
    {-0.4, -0.4, -0.4,  0.4,  0.45, 0.4},  -- fill
}

-- Lava soil node is now defined in the volcanic_soil mod
-- lava_crucible outputs volcanic_soil:volcanic_soil from stone conversion

-- Function to convert stone to volcanic soil (now provided by volcanic_soil mod)
function convert_stone_to_lava_soil(itemstack)
    -- Check if the item is a stone
    if minetest.get_item_group(itemstack:get_name(), "stone") > 0 then
        return ItemStack("volcanic_soil:volcanic_soil " .. itemstack:get_count())
    end
    return nil
end

local function clone_table(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

local function has_adjacent_lava(pos)
    local neighbors = {
        {x = pos.x + 1, y = pos.y, z = pos.z},
        {x = pos.x - 1, y = pos.y, z = pos.z},
        {x = pos.x, y = pos.y + 1, z = pos.z},
        {x = pos.x, y = pos.y - 1, z = pos.z},
        {x = pos.x, y = pos.y, z = pos.z + 1},
        {x = pos.x, y = pos.y, z = pos.z - 1},
    }
    for _, p in ipairs(neighbors) do
        local node = minetest.get_node(p)
        if node.name == "default:lava_source" or node.name == "default:lava_flowing" then
            return true
        end
    end
    return false
end

local function is_ender_crucible_node(nodename)
    return nodename:find("lava_crucible_ender") ~= nil
end

local function get_ender_tier(nodename)
    if nodename:find("lava_crucible_ender_quad")   then return "quad"
    elseif nodename:find("lava_crucible_ender_double") then return "double"
    else return "single" end
end

local lava_crucible = rawget(_G, "lava_crucible") or {}
_G.lava_crucible = lava_crucible

local dust_table = {}
local dust_entries_by_item = {}
local dust_items_requiring_mineral_group = {}
local dust_total_weight = 0
local lump_table = {}
local lump_total_weight = 0
local mod_storage = minetest.get_mod_storage()
local ender_users_seen = {}

local function recompute_dust_total_weight()
    dust_total_weight = 0
    for _, entry in ipairs(dust_table) do
        dust_total_weight = dust_total_weight + entry.weight
    end
end

function lava_crucible.register_dust_bonus(itemname, weight, options)
    if type(itemname) ~= "string" or itemname == "" then
        minetest.log("warning", "[lava_crucible] register_dust_bonus: itemname must be a non-empty string")
        return false
    end
    if type(weight) ~= "number" or weight <= 0 then
        minetest.log("warning", "[lava_crucible] register_dust_bonus: weight must be a positive number")
        return false
    end

    -- Validate that the item is registered
    if not minetest.registered_items[itemname] then
        minetest.log("warning", "[lava_crucible] Skipping unregistered dust item: " .. itemname)
        return false
    end

    local entry = dust_entries_by_item[itemname]
    if entry then
        entry.weight = weight
    else
        entry = {item = itemname, weight = weight}
        dust_entries_by_item[itemname] = entry
        table.insert(dust_table, entry)
    end

    if options and options.grant_mineral_dust_group then
        dust_items_requiring_mineral_group[itemname] = true
    end
    
    return true
end

local function apply_mineral_dust_overrides()
    for itemname in pairs(dust_items_requiring_mineral_group) do
        local def = minetest.registered_items[itemname]
        if def then
            local groups = clone_table(def.groups or {})
            if groups.mineral_dust ~= 1 then
                groups.mineral_dust = 1
                minetest.override_item(itemname, {groups = groups})
            end
        else
            minetest.log("warning", "[lava_crucible] Unable to add mineral_dust group to unregistered item " .. itemname)
        end
    end
end

local function save_ender_users_seen()
    local users = {}
    for playername, _ in pairs(ender_users_seen) do
        table.insert(users, playername)
    end
    mod_storage:set_string("ender_users_seen", minetest.serialize(users))
end

do
    local raw_users = mod_storage:get_string("ender_users_seen")
    if raw_users and raw_users ~= "" then
        local ok, users = pcall(minetest.deserialize, raw_users)
        if ok and type(users) == "table" then
            for _, playername in ipairs(users) do
                if type(playername) == "string" and playername ~= "" then
                    ender_users_seen[playername] = true
                end
            end
        end
    end
end

local function mark_ender_user(playername)
    if playername and playername ~= "" and not ender_users_seen[playername] then
        ender_users_seen[playername] = true
        save_ender_users_seen()
    end
end

local function serialize_inv_list(inv, listname)
    local out = {}
    for i = 1, inv:get_size(listname) do
        out[i] = inv:get_stack(listname, i):to_string()
    end
    return out
end

local function save_ender_inventory(playername, inv, tier)
    if not playername or playername == "" or not inv then
        return
    end

    local key = (tier == "double" and "ender_double_inv:"
              or tier == "quad"   and "ender_quad_inv:"
              or                      "ender_inv:") .. playername
    local payload = {
        input = serialize_inv_list(inv, "input"),
        soil_output = serialize_inv_list(inv, "soil_output"),
        dust_output = serialize_inv_list(inv, "dust_output"),
    }

    mod_storage:set_string(key, minetest.serialize(payload))
end

local function load_ender_inventory(playername, inv, tier)
    local key = (tier == "double" and "ender_double_inv:"
              or tier == "quad"   and "ender_quad_inv:"
              or                      "ender_inv:") .. playername
    local raw = mod_storage:get_string(key)
    if not raw or raw == "" then
        return
    end

    local ok, payload = pcall(minetest.deserialize, raw)
    if not ok or type(payload) ~= "table" then
        return
    end

    local list_names = {"input", "soil_output", "dust_output"}
    for _, listname in ipairs(list_names) do
        local list = payload[listname]
        if type(list) == "table" then
            for i = 1, inv:get_size(listname) do
                local stack_str = list[i] or ""
                inv:set_stack(listname, i, ItemStack(stack_str))
            end
        end
    end
end

local function inventory_input_empty(inv)
    for i = 1, inv:get_size("input") do
        if not inv:get_stack("input", i):is_empty() then return false end
    end
    return true
end

local function inventory_output_has_items(inv)
    for i = 1, inv:get_size("soil_output") do
        if not inv:get_stack("soil_output", i):is_empty() then return true end
    end
    for i = 1, inv:get_size("dust_output") do
        if not inv:get_stack("dust_output", i):is_empty() then return true end
    end
    return false
end

local function get_ender_inventory(playername, tier)
    tier = tier or "single"
    if not playername or playername == "" then
        return nil
    end

    mark_ender_user(playername)

    local inv_name, input_slots, soil_slots, dust_slots
            if tier == "double" then
                inv_name    = "lava_crucible:ender_double_" .. playername
                input_slots = 2; soil_slots = 4; dust_slots = #dust_table * 1
    elseif tier == "quad" then
        inv_name    = "lava_crucible:ender_quad_" .. playername
        input_slots = 4; soil_slots = 8; dust_slots = #dust_table * 2
    else
        inv_name    = "lava_crucible:ender_" .. playername
        input_slots = 1; soil_slots = 2; dust_slots = math.ceil(#dust_table / 2)
    end

    local inv = minetest.get_inventory({type = "detached", name = inv_name})
    if not inv then
        inv = minetest.create_detached_inventory(inv_name, {
            on_put = function(_, listname, index, stack, player)
                local v = minetest.get_inventory({type = "detached", name = inv_name})
                if v then save_ender_inventory(playername, v, tier) end
            end,
            on_take = function(_, listname, index, stack, player)
                local v = minetest.get_inventory({type = "detached", name = inv_name})
                if v then save_ender_inventory(playername, v, tier) end
            end,
            on_move = function(_, from_list, from_index, to_list, to_index, count, player)
                local v = minetest.get_inventory({type = "detached", name = inv_name})
                if v then save_ender_inventory(playername, v, tier) end
            end,
        })
        inv:set_size("input",       input_slots)
        inv:set_size("soil_output", soil_slots)
        inv:set_size("dust_output", dust_slots)
        load_ender_inventory(playername, inv, tier)
    end

    return inv
end

local function get_ender_inventory_state(playername, tier)
    local inv = get_ender_inventory(playername, tier)
    if not inv then
        return false, false
    end

    return not inventory_input_empty(inv), inventory_output_has_items(inv)
end

local function get_processing_inventory(node, meta)
    if is_ender_crucible_node(node.name) then
        return nil
    end
    return meta:get_inventory()
end

local function crucible_input_empty(meta)
    return inventory_input_empty(meta:get_inventory())
end

local function crucible_output_has_items(meta)
    return inventory_output_has_items(meta:get_inventory())
end

local function crucible_has_contents(meta)
    if not crucible_input_empty(meta) then return true end
    return crucible_output_has_items(meta)
end

local function update_crucible_state(pos)
    local node = minetest.get_node(pos)
    local meta = minetest.get_meta(pos)
    local lava = has_adjacent_lava(pos)
    local is_ender = is_ender_crucible_node(node.name)

    local input_empty = true
    local output_full = false

    if is_ender then
        local active_player = meta:get_string("ender_user")
        local any_input, any_output = get_ender_inventory_state(active_player, get_ender_tier(node.name))
        input_empty = not any_input
        output_full = any_output
    else
        local inv = get_processing_inventory(node, meta)
        if inv then
            input_empty = inventory_input_empty(inv)
            output_full = inventory_output_has_items(inv)
        end
    end

    local is_quad = node.name:find("_quad") ~= nil
    local is_double = node.name:find("_double") ~= nil
    local prefix
    if node.name:find("lava_crucible_ender_quad") then
        prefix = "lava_crucible:lava_crucible_ender_quad"
    elseif node.name:find("lava_crucible_ender_double") then
        prefix = "lava_crucible:lava_crucible_ender_double"
    elseif is_ender then
        prefix = "lava_crucible:lava_crucible_ender"
    elseif is_quad then
        prefix = "lava_crucible:lava_crucible_quad"
    elseif is_double then
        prefix = "lava_crucible:lava_crucible_double"
    else
        prefix = "lava_crucible:lava_crucible"
    end
    local target
    if not lava then
        target = prefix
    elseif not input_empty then
        target = prefix .. "_hot"
    elseif output_full then
        target = prefix .. "_hot_done"
    else
        target = prefix .. "_hot_empty"
    end

    if node.name ~= target then
        minetest.swap_node(pos, {name = target, param2 = node.param2})
    end
end

local conversion_interval = tonumber(minetest.settings:get("lava_crucible_conversion_interval")) or 10.0
local dust_chance = tonumber(minetest.settings:get("lava_crucible_dust_chance")) or 0.5

local function is_compressed_stone(itemname)
    return string.find(itemname, "_compressed") ~= nil
end

local function is_valid_crucible_input(itemname)
    return minetest.get_item_group(itemname, "stone") > 0 or is_compressed_stone(itemname)
end

-- ABM-driven drop-in behaviour: the ABM at the end of this file
-- calls `collect_dropped_stone(pos)` once per second to gather
-- valid stone item entities dropped slightly above the crucible
-- into the `input` inventory. Keep `USAGE.md` and `bugs/BUG_5_RCA.md`
-- in sync when changing this behaviour.
local function collect_dropped_stone(pos)
    local node = minetest.get_node(pos)
    if is_ender_crucible_node(node.name) then
        return
    end

    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local inserted_any = false
    local search_pos = {x = pos.x, y = pos.y + 0.6, z = pos.z}

    for _, obj in ipairs(minetest.get_objects_inside_radius(search_pos, 0.9)) do
        local ent = obj:get_luaentity()
        if ent and ent.name == "__builtin:item" and ent.itemstring then
            local stack = ItemStack(ent.itemstring)
            if not stack:is_empty() and is_valid_crucible_input(stack:get_name()) then
                local leftover = inv:add_item("input", stack)
                if leftover:get_count() < stack:get_count() then
                    inserted_any = true
                    if leftover:is_empty() then
                        obj:remove()
                    else
                        if ent.set_item then
                            ent:set_item(leftover:to_string())
                        else
                            ent.itemstring = leftover:to_string()
                        end
                    end
                end
            end
        end
    end

    if inserted_any then
        update_crucible_state(pos)
        if has_adjacent_lava(pos) then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                timer:start(conversion_interval)
            end
        end
    end
end

local function refresh_ender_user_from_nearby_player(pos)
    local node = minetest.get_node(pos)
    if not is_ender_crucible_node(node.name) then
        return
    end

    local nearest_name
    local nearest_dist2
    local search_pos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
    for _, obj in ipairs(minetest.get_objects_inside_radius(search_pos, 3.0)) do
        if obj:is_player() then
            local pname = obj:get_player_name()
            if pname and pname ~= "" then
                local ppos = obj:get_pos()
                local dx = ppos.x - pos.x
                local dy = ppos.y - pos.y
                local dz = ppos.z - pos.z
                local dist2 = dx * dx + dy * dy + dz * dz
                if not nearest_dist2 or dist2 < nearest_dist2 then
                    nearest_dist2 = dist2
                    nearest_name = pname
                end
            end
        end
    end

    if not nearest_name then
        return
    end

    local meta = minetest.get_meta(pos)
    local current = meta:get_string("ender_user")
    if nearest_name ~= current then
        meta:set_string("ender_user", nearest_name)
    end

    mark_ender_user(nearest_name)
    update_crucible_state(pos)

    if has_adjacent_lava(pos) then
        local any_input, _ = get_ender_inventory_state(nearest_name, get_ender_tier(node.name))
        if any_input then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                timer:start(conversion_interval)
            end
        end
    end
end

-- Default weight assignments based on material rarity (can be overridden later)
-- These are sensible defaults used when automatically discovering dusts
local dust_weight_defaults = {
    coal = 18,
    copper = 30,
    iron = 40,
    gold = 8,
    silver = 5,
    tin = 20,
    lead = 16,
    zinc = 16,
    chromium = 6,
    sulfur = 6,
    mithril = 2,
    diamond = 1,
    pyrite = 4,
    nether = 3,
}

local lump_weight_defaults = {
    iron = 40,
    copper = 30,
    gold = 8,
    tin = 20,
    silver = 5,
    mithril = 2,
    diamond = 1,
}

-- Function to get default weight for a dust/lump by material name
local function get_default_weight(material_name, is_lump)
    local defaults = is_lump and lump_weight_defaults or dust_weight_defaults
    return defaults[material_name] or 10  -- Default to 10 if material unknown
end

-- Dynamically discover dusts at mod load time
local function discover_and_register_dusts()
    print("[lava_crucible] Discovering dust items...")
    local dust_count = 0
    local scanned_count = 0
    
    -- Scan both registered items AND registered nodes
    -- (some mods register dusts as nodes, not craftitems)
    local items_to_scan = {}
    for itemname, def in pairs(minetest.registered_items) do
        items_to_scan[itemname] = def
    end
    for nodename, def in pairs(minetest.registered_nodes) do
        items_to_scan[nodename] = def
    end
    
    -- Process scanned items for dusts
    for itemname, def in pairs(items_to_scan) do
        if itemname:find("_dust$") then
            scanned_count = scanned_count + 1
            -- Extract material name by finding the last underscore and removing "_dust"
            -- e.g., "ore_dust:copper_dust" -> "copper", "technic:coal_dust" -> "coal"
            local material = itemname:match("([^_:]*)[_:]?([^_:]*)_dust$") or ""
            -- Use the rightmost part before _dust as the material name
            material = itemname:gsub(".*[_:]", ""):gsub("_dust$", "")
            
            if material ~= "" then
                local weight = get_default_weight(material, false)
                
                if lava_crucible.register_dust_bonus(itemname, weight, {grant_mineral_dust_group = true}) then
                    dust_count = dust_count + 1
                    minetest.log("verbose", "[lava_crucible] Auto-registered dust: " .. itemname .. 
                        " (material: " .. material .. ", weight: " .. weight .. ")")
                end
            else
                minetest.log("verbose", "[lava_crucible] Skipped dust with unparseable name: " .. itemname)
            end
        end
    end
    
    minetest.log("action", "[lava_crucible] Discovered and registered " .. dust_count .. 
        " dust items (scanned " .. scanned_count .. ")")
end

-- Dynamically discover lumps at mod load time  
local function discover_and_register_lumps()
    print("[lava_crucible] Discovering lump items...")
    local lump_count = 0
    local scanned_count = 0
    
    -- Scan both registered items AND registered nodes
    local items_to_scan = {}
    for itemname, def in pairs(minetest.registered_items) do
        items_to_scan[itemname] = def
    end
    for nodename, def in pairs(minetest.registered_nodes) do
        items_to_scan[nodename] = def
    end
    
    -- Process scanned items for lumps
    for itemname, def in pairs(items_to_scan) do
        if itemname:find("_lump$") then
            scanned_count = scanned_count + 1
            -- Extract material name by finding the rightmost part before _lump
            local material = itemname:gsub(".*[_:]", ""):gsub("_lump$", "")
            
            if material ~= "" then
                local weight = get_default_weight(material, true)
                
                local entry = {item = itemname, weight = weight}
                table.insert(lump_table, entry)
                lump_count = lump_count + 1
                minetest.log("verbose", "[lava_crucible] Auto-registered lump: " .. itemname .. 
                    " (material: " .. material .. ", weight: " .. weight .. ")")
            else
                minetest.log("verbose", "[lava_crucible] Skipped lump with unparseable name: " .. itemname)
            end
        end
    end
    
    minetest.log("action", "[lava_crucible] Discovered and registered " .. lump_count .. 
        " lump items (scanned " .. scanned_count .. ")")
end


-- Discovery happens at mods_loaded time
minetest.register_on_mods_loaded(function()
    discover_and_register_dusts()
    
    -- Discover lumps
    discover_and_register_lumps()
    
    -- Compute lump total weight
    lump_total_weight = 0
    for _, entry in ipairs(lump_table) do
        lump_total_weight = lump_total_weight + entry.weight
    end
    
    minetest.log("action", "[lava_crucible] Lump pool total weight: " .. lump_total_weight)
    
    -- Apply dust overrides and finalize dust pool
    apply_mineral_dust_overrides()
    recompute_dust_total_weight()
    
    minetest.log("action", "[lava_crucible] Dust pool total weight: " .. dust_total_weight)
end)

local function pick_random_dust()
    if #dust_table == 0 or dust_total_weight <= 0 then
        return nil
    end

    local roll = math.random() * dust_total_weight
    local cumulative = 0
    for _, entry in ipairs(dust_table) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            -- Defensive check: ensure item is registered
            if minetest.registered_items[entry.item] then
                return entry.item
            else
                minetest.log("warning", "[lava_crucible] Dust item no longer registered: " .. entry.item)
                return nil
            end
        end
    end
    
    -- Fallback: try to return last item if it's registered
    local last_item = dust_table[#dust_table]
    if last_item and minetest.registered_items[last_item.item] then
        return last_item.item
    end
    return nil
end

local function pick_random_lump()
    if #lump_table == 0 or lump_total_weight <= 0 then
        return nil
    end

    local roll = math.random() * lump_total_weight
    local cumulative = 0
    for _, entry in ipairs(lump_table) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            -- Defensive check: ensure item is registered
            if minetest.registered_items[entry.item] then
                return entry.item
            else
                minetest.log("warning", "[lava_crucible] Lump item no longer registered: " .. entry.item)
                return nil
            end
        end
    end
    
    -- Fallback: try to return last item if it's registered
    local last_item = lump_table[#lump_table]
    if last_item and minetest.registered_items[last_item.item] then
        return last_item.item
    end
    return nil
end

local function process_input_stack(inv, slot)
    local input_stack = inv:get_stack("input", slot)
    if input_stack:is_empty() then
        return false, false
    end

    local itemname = input_stack:get_name()
    local soil_count = 1
    local bonus_item

    if is_compressed_stone(itemname) then
        soil_count = 9
        if math.random() < 0.5 then
            bonus_item = pick_random_lump()
        else
            bonus_item = pick_random_dust()
        end
    elseif minetest.get_item_group(itemname, "stone") > 0 then
        soil_count = 1
        bonus_item = pick_random_dust()
    else
        return false, false
    end

    local leftover = inv:add_item("soil_output", ItemStack("volcanic_soil:volcanic_soil " .. soil_count))
    if leftover:get_count() > 0 then
        return false, true
    end

    input_stack:take_item(1)
    inv:set_stack("input", slot, input_stack)

    if bonus_item and math.random() < dust_chance then
        inv:add_item("dust_output", ItemStack(bonus_item .. " 1"))
    end

    return true, false
end

local crucible_common = {
    description = "A crucible that is used by placing it over lava",
    is_ground_content = false,
    groups = {cracky = 1},
    drawtype = "nodebox",
    paramtype = "light",
    node_box = {
        type = "fixed",
        fixed = cbox,
    },
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        if placer and placer:is_player() then
            local meta = minetest.get_meta(pos)
            meta:set_string("owner", placer:get_player_name())
            meta:set_string("infotext", "Lava Crucible (owned by " .. placer:get_player_name() .. ")")
        end
        -- Normalize state immediately after placement in case a hot/done
        -- variant was placed directly (e.g. via /giveme). This ensures the
        -- visible node reflects actual adjacent lava presence.
        pcall(function()
            update_crucible_state(pos)
            if has_adjacent_lava(pos) then
                local meta = minetest.get_meta(pos)
                local inv = meta:get_inventory()
                if inv and not inventory_input_empty(inv) then
                    local timer = minetest.get_node_timer(pos)
                    if not timer:is_started() then timer:start(conversion_interval) end
                end
            end
        end)
    end,
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        if to_list == "soil_output" or to_list == "dust_output" then
            return 0
        end
        local owner = minetest.get_meta(pos):get_string("owner")
        if owner ~= "" and player:get_player_name() ~= owner then return 0 end
        return count
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        if listname == "soil_output" or listname == "dust_output" then
            return 0
        end
        local owner = minetest.get_meta(pos):get_string("owner")
        if owner ~= "" and player:get_player_name() ~= owner then return 0 end
        return stack:get_count()
    end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
        local owner = minetest.get_meta(pos):get_string("owner")
        if owner ~= "" and player:get_player_name() ~= owner then return 0 end
        return stack:get_count()
    end,
    on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        update_crucible_state(pos)
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        update_crucible_state(pos)
        if listname == "input" and has_adjacent_lava(pos) then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                timer:start(conversion_interval)
            end
        end
    end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
        update_crucible_state(pos)
    end,
    on_punch = function(pos, node, puncher, pointed_thing)
        local owner = minetest.get_meta(pos):get_string("owner")
        if owner ~= "" and puncher:get_player_name() ~= owner then
            minetest.chat_send_player(puncher:get_player_name(), "This crucible belongs to " .. owner .. ".")
            return
        end
        local wielded_item = puncher:get_wielded_item()
        if wielded_item:is_empty() then
            return
        end
        if is_valid_crucible_input(wielded_item:get_name()) then
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            local item_to_add = ItemStack(wielded_item:get_name() .. " " .. wielded_item:get_count())
            local leftover = inv:add_item("input", item_to_add)
            if leftover:get_count() == item_to_add:get_count() then
                minetest.chat_send_player(puncher:get_player_name(), "The input slot is full!")
            else
                puncher:get_inventory():remove_item("main", wielded_item)
                update_crucible_state(pos)
                if has_adjacent_lava(pos) then
                    local timer = minetest.get_node_timer(pos)
                    if not timer:is_started() then
                        timer:start(conversion_interval)
                    end
                end
            end
        end
    end,
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Lava Crucible")
        local inv = meta:get_inventory()
        inv:set_size("input", 1)
            inv:set_size("soil_output", 2)
            inv:set_size("dust_output", math.ceil(#dust_table / 2))
    end,
    on_timer = function(pos, elapsed)
        if not has_adjacent_lava(pos) then return false end
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local input_stack = inv:get_stack("input", 1)
        if input_stack:is_empty() then return false end
        local converted, blocked = process_input_stack(inv, 1)
        if not converted and not blocked then return false end
        update_crucible_state(pos)
        if blocked then return true end
        return not inv:get_stack("input", 1):is_empty()
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local meta = minetest.get_meta(pos)
        local owner = meta:get_string("owner")
        if owner ~= "" and clicker:get_player_name() ~= owner then
            minetest.chat_send_player(clicker:get_player_name(), "This crucible belongs to " .. owner .. ".")
            return
        end
        local inv = meta:get_inventory()
        local dust_count = math.ceil(#dust_table / 2)
        local dust_cols = math.min(dust_count, 8)
        local dust_rows = math.ceil(dust_count / dust_cols)
        local dust_y = 3.3
        local inv_label_y = dust_y + dust_rows + 0.4
        local inv_y = inv_label_y + 0.5
        local form_h = inv_y + 3.2
        local formspec = "size[9," .. form_h .. "]" ..
            "bgcolor[#080808BB;true]" ..
            "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
            "label[0.5,0.3;Lava Crucible]" ..
            "label[0.5,1;Input:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;0.5,1.5;1,1;]" ..
            "label[2.5,0.3;Soil Output:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";soil_output;2.5,1;2,1;]" ..
            "label[0.5," .. (dust_y - 0.4) .. ";Ore Dust:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
            "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
            "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";soil_output]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";dust_output]"
        minetest.show_formspec(clicker:get_player_name(), "lava_crucible:crucible_gui", formspec)
    end,
}

-- Double Lava Crucible: 2 input slots, 2 soil output slots, double dust slots
local crucible_double_common = clone_table(crucible_common)
crucible_double_common.description = "Double Lava Crucible"
crucible_double_common.node_box = { type = "fixed", fixed = cbox_double }
crucible_double_common.after_place_node = function(pos, placer, itemstack, pointed_thing)
    if placer and placer:is_player() then
        local meta = minetest.get_meta(pos)
        meta:set_string("owner", placer:get_player_name())
        meta:set_string("infotext", "Double Lava Crucible (owned by " .. placer:get_player_name() .. ")")
    end
    pcall(function()
        update_crucible_state(pos)
        if has_adjacent_lava(pos) then
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            if inv and not inventory_input_empty(inv) then
                local timer = minetest.get_node_timer(pos)
                if not timer:is_started() then timer:start(conversion_interval) end
            end
        end
    end)
end
crucible_double_common.on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Double Lava Crucible")
    local inv = meta:get_inventory()
    inv:set_size("input", 2)
    inv:set_size("soil_output", 4)
    inv:set_size("dust_output", #dust_table * 1)
end
crucible_double_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local blocked = false
    for i = 1, inv:get_size("input") do
        local _, slot_blocked = process_input_stack(inv, i)
        blocked = blocked or slot_blocked
    end
    update_crucible_state(pos)
    if blocked then return true end
    return not crucible_input_empty(meta)
end
crucible_double_common.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if owner ~= "" and clicker:get_player_name() ~= owner then
        minetest.chat_send_player(clicker:get_player_name(), "This crucible belongs to " .. owner .. ".")
        return
    end
    local pnode = pos.x .. "," .. pos.y .. "," .. pos.z
    local dust_count = #dust_table * 1
    local dust_cols = math.min(dust_count, 8)
    local dust_rows = math.ceil(dust_count / dust_cols)
    local dust_y = 3.3
    local inv_label_y = dust_y + dust_rows + 0.4
    local inv_y = inv_label_y + 0.5
    local form_h = inv_y + 3.2
    local formspec = "size[9," .. form_h .. "]" ..
        "bgcolor[#080808BB;true]" ..
        "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
        "label[0.5,0.3;Double Lava Crucible]" ..
        "label[0.5,1;Input:]" ..
        "list[nodemeta:" .. pnode .. ";input;0.5,1.5;2,1;]" ..
        "label[3.5,1;Soil Output:]" ..
        "list[nodemeta:" .. pnode .. ";soil_output;3.5,1.5;4,1;]" ..
        "label[0.5," .. (dust_y - 0.4) .. ";Ore Dust:]" ..
        "list[nodemeta:" .. pnode .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
        "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
        "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";input]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";soil_output]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";dust_output]"
    minetest.show_formspec(clicker:get_player_name(), "lava_crucible:crucible_gui", formspec)
end

local cold_crucible = clone_table(crucible_common)
cold_crucible.tiles = {
    "crucible_top.png",
    "crucible_bottom.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
}
minetest.register_node("lava_crucible:lava_crucible", cold_crucible)

local hot_crucible = clone_table(crucible_common)
hot_crucible.tiles = {
    {
        name = "crucible_top_hot.png",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible.light_source = 10
hot_crucible.node_box = { type = "fixed", fixed = cbox_filled }
hot_crucible.groups = hot_crucible.groups or {}
hot_crucible.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_hot", hot_crucible)

local hot_crucible_empty = clone_table(crucible_common)
hot_crucible_empty.tiles = {
    "crucible_top_hot_empty.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_empty.light_source = 7
hot_crucible_empty.groups = hot_crucible_empty.groups or {}
hot_crucible_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_hot_empty", hot_crucible_empty)

local hot_crucible_done = clone_table(crucible_common)
hot_crucible_done.tiles = {
    "crucible_top_hot_done.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_done.light_source = 7
hot_crucible_done.groups = hot_crucible_done.groups or {}
hot_crucible_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_hot_done", hot_crucible_done)

local crucible_ender_common = clone_table(crucible_common)
crucible_ender_common.description = "Ender Lava Crucible"
crucible_ender_common.after_place_node = function(pos, placer, itemstack, pointed_thing)
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", "")
    meta:set_string("infotext", "Ender Lava Crucible")
    pcall(function()
        update_crucible_state(pos)
        if has_adjacent_lava(pos) then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then timer:start(conversion_interval) end
        end
    end)
end
crucible_ender_common.on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", "")
    meta:set_string("infotext", "Ender Lava Crucible")
end
crucible_ender_common.on_punch = function(pos, node, puncher, pointed_thing)
    if not puncher or not puncher:is_player() then
        return
    end

    local wielded_item = puncher:get_wielded_item()
    if wielded_item:is_empty() or not is_valid_crucible_input(wielded_item:get_name()) then
        return
    end

    local pname = puncher:get_player_name()
    mark_ender_user(pname)
    local inv = get_ender_inventory(pname, "single")
    if not inv then
        return
    end

    local item_to_add = ItemStack(wielded_item:get_name() .. " " .. wielded_item:get_count())
    local leftover = inv:add_item("input", item_to_add)
    if leftover:get_count() == item_to_add:get_count() then
        minetest.chat_send_player(pname, "The input slot is full!")
        return
    end

    puncher:get_inventory():remove_item("main", wielded_item)
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)
    save_ender_inventory(pname, inv, "single")
    update_crucible_state(pos)

    if has_adjacent_lava(pos) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then
            timer:start(conversion_interval)
        end
    end
end
crucible_ender_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end

    local blocked = false
    local any_input = false

    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "single")
        if inv and not inventory_input_empty(inv) then
            any_input = true
            local _, slot_blocked = process_input_stack(inv, 1)
            blocked = blocked or slot_blocked
            save_ender_inventory(playername, inv, "single")
        end
    end

    update_crucible_state(pos)

    if not any_input then
        return false
    end
    if blocked then return true end

    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "single")
        if inv and not inventory_input_empty(inv) then
            return true
        end
    end

    return false
end
crucible_ender_common.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    if not clicker or not clicker:is_player() then
        return
    end

    local pname = clicker:get_player_name()
    mark_ender_user(pname)
    local inv_name = "lava_crucible:ender_" .. pname
    local inv = get_ender_inventory(pname, "single")
    if not inv then
        return
    end

    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)

    local dust_count = math.ceil(#dust_table / 2)
    local dust_cols = math.min(dust_count, 8)
    local dust_rows = math.ceil(dust_count / dust_cols)
    local dust_y = 3.3
    local inv_label_y = dust_y + dust_rows + 0.4
    local inv_y = inv_label_y + 0.5
    local form_h = inv_y + 3.2
    local formspec = "size[9," .. form_h .. "]" ..
        "bgcolor[#080808BB;true]" ..
        "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
        "label[0.5,0.3;Ender Lava Crucible]" ..
        "label[0.5,1;Input:]" ..
        "list[detached:" .. inv_name .. ";input;0.5,1.5;1,1;]" ..
        "label[2.5,0.3;Soil Output:]" ..
        "list[detached:" .. inv_name .. ";soil_output;2.5,1;2,1;]" ..
        "label[0.5," .. (dust_y - 0.4) .. ";Ore Dust:]" ..
        "list[detached:" .. inv_name .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
        "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
        "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";input]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";soil_output]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";dust_output]"
    minetest.show_formspec(clicker:get_player_name(), "lava_crucible:crucible_gui", formspec)

    update_crucible_state(pos)
    if has_adjacent_lava(pos) and not inventory_input_empty(inv) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then
            timer:start(conversion_interval)
        end
    end
end

local cold_ender_crucible = clone_table(crucible_ender_common)
cold_ender_crucible.tiles = {
    "crucible_top.png^[colorize:#49305f:85",
    "crucible_bottom.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
}
minetest.register_node("lava_crucible:lava_crucible_ender", cold_ender_crucible)

local hot_ender_crucible = clone_table(crucible_ender_common)
hot_ender_crucible.tiles = {
    {
        name = "crucible_top_hot.png^[colorize:#3f245f:75",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_crucible.light_source = 10
hot_ender_crucible.node_box = { type = "fixed", fixed = cbox_filled }
hot_ender_crucible.groups = hot_ender_crucible.groups or {}
hot_ender_crucible.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_hot", hot_ender_crucible)

local hot_ender_crucible_empty = clone_table(crucible_ender_common)
hot_ender_crucible_empty.tiles = {
    "crucible_top_hot_empty.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_crucible_empty.light_source = 7
hot_ender_crucible_empty.groups = hot_ender_crucible_empty.groups or {}
hot_ender_crucible_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_hot_empty", hot_ender_crucible_empty)

local hot_ender_crucible_done = clone_table(crucible_ender_common)
hot_ender_crucible_done.tiles = {
    "crucible_top_hot_done.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_crucible_done.light_source = 7
hot_ender_crucible_done.groups = hot_ender_crucible_done.groups or {}
hot_ender_crucible_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_hot_done", hot_ender_crucible_done)

-- Double Ender Lava Crucible: 2 input/output slots, per-player shared ender inventory
local crucible_ender_double_common = clone_table(crucible_ender_common)
crucible_ender_double_common.description = "Double Ender Lava Crucible"
crucible_ender_double_common.node_box = { type = "fixed", fixed = cbox_double }
crucible_ender_double_common.on_punch = function(pos, node, puncher, pointed_thing)
    if not puncher or not puncher:is_player() then return end
    local wielded_item = puncher:get_wielded_item()
    if wielded_item:is_empty() or not is_valid_crucible_input(wielded_item:get_name()) then return end
    local pname = puncher:get_player_name()
    mark_ender_user(pname)
    local inv = get_ender_inventory(pname, "double")
    if not inv then return end
    local item_to_add = ItemStack(wielded_item:get_name() .. " " .. wielded_item:get_count())
    local leftover = inv:add_item("input", item_to_add)
    if leftover:get_count() == item_to_add:get_count() then
        minetest.chat_send_player(pname, "The input slots are full!")
        return
    end
    puncher:get_inventory():remove_item("main", wielded_item)
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)
    save_ender_inventory(pname, inv, "double")
    update_crucible_state(pos)
    if has_adjacent_lava(pos) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then timer:start(conversion_interval) end
    end
end
crucible_ender_double_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local blocked = false
    local any_input = false
    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "double")
        if inv and not inventory_input_empty(inv) then
            any_input = true
            for i = 1, inv:get_size("input") do
                local _, slot_blocked = process_input_stack(inv, i)
                blocked = blocked or slot_blocked
            end
            save_ender_inventory(playername, inv, "double")
        end
    end
    update_crucible_state(pos)
    if not any_input then return false end
    if blocked then return true end
    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "double")
        if inv and not inventory_input_empty(inv) then return true end
    end
    return false
end
crucible_ender_double_common.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    if not clicker or not clicker:is_player() then return end
    local pname = clicker:get_player_name()
    mark_ender_user(pname)
    local inv_name = "lava_crucible:ender_double_" .. pname
    local inv = get_ender_inventory(pname, "double")
    if not inv then return end
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)
    local dust_count = #dust_table * 1
    local dust_cols = math.min(dust_count, 8)
    local dust_rows = math.ceil(dust_count / dust_cols)
    local dust_y = 3.3
    local inv_label_y = dust_y + dust_rows + 0.4
    local inv_y = inv_label_y + 0.5
    local form_h = inv_y + 3.2
    local formspec = "size[9," .. form_h .. "]" ..
        "bgcolor[#080808BB;true]" ..
        "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
        "label[0.5,0.3;Double Ender Lava Crucible]" ..
        "label[0.5,1;Input:]" ..
        "list[detached:" .. inv_name .. ";input;0.5,1.5;2,1;]" ..
        "label[3.5,1;Soil Output:]" ..
        "list[detached:" .. inv_name .. ";soil_output;3.5,1.5;4,1;]" ..
        "label[0.5,2.8;Ore Dust:]" ..
        "list[detached:" .. inv_name .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
        "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
        "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";input]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";soil_output]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";dust_output]"
    minetest.show_formspec(pname, "lava_crucible:crucible_gui", formspec)
    update_crucible_state(pos)
    if has_adjacent_lava(pos) and not inventory_input_empty(inv) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then timer:start(conversion_interval) end
    end
end

local cold_ender_double_crucible = clone_table(crucible_ender_double_common)
cold_ender_double_crucible.tiles = {
    "crucible_top.png^[colorize:#49305f:85",
    "crucible_bottom.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
}
minetest.register_node("lava_crucible:lava_crucible_ender_double", cold_ender_double_crucible)

local hot_ender_double_crucible = clone_table(crucible_ender_double_common)
hot_ender_double_crucible.tiles = {
    {
        name = "crucible_top_hot.png^[colorize:#3f245f:75",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_double_crucible.light_source = 10
hot_ender_double_crucible.node_box = { type = "fixed", fixed = cbox_double_filled }
hot_ender_double_crucible.groups = hot_ender_double_crucible.groups or {}
hot_ender_double_crucible.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_double_hot", hot_ender_double_crucible)

local hot_ender_double_crucible_empty = clone_table(crucible_ender_double_common)
hot_ender_double_crucible_empty.tiles = {
    "crucible_top_hot_empty.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_double_crucible_empty.light_source = 7
hot_ender_double_crucible_empty.groups = hot_ender_double_crucible_empty.groups or {}
hot_ender_double_crucible_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_double_hot_empty", hot_ender_double_crucible_empty)

local hot_ender_double_crucible_done = clone_table(crucible_ender_double_common)
hot_ender_double_crucible_done.tiles = {
    "crucible_top_hot_done.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_double_crucible_done.light_source = 7
hot_ender_double_crucible_done.groups = hot_ender_double_crucible_done.groups or {}
hot_ender_double_crucible_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_double_hot_done", hot_ender_double_crucible_done)

-- Quad Ender Lava Crucible: 4 input/output slots, per-player shared ender inventory
local crucible_ender_quad_common = clone_table(crucible_ender_common)
crucible_ender_quad_common.description = "Quad Ender Lava Crucible"
crucible_ender_quad_common.node_box = { type = "fixed", fixed = cbox_quad }
crucible_ender_quad_common.on_punch = function(pos, node, puncher, pointed_thing)
    if not puncher or not puncher:is_player() then return end
    local wielded_item = puncher:get_wielded_item()
    if wielded_item:is_empty() or not is_valid_crucible_input(wielded_item:get_name()) then return end
    local pname = puncher:get_player_name()
    mark_ender_user(pname)
    local inv = get_ender_inventory(pname, "quad")
    if not inv then return end
    local item_to_add = ItemStack(wielded_item:get_name() .. " " .. wielded_item:get_count())
    local leftover = inv:add_item("input", item_to_add)
    if leftover:get_count() == item_to_add:get_count() then
        minetest.chat_send_player(pname, "The input slots are full!")
        return
    end
    puncher:get_inventory():remove_item("main", wielded_item)
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)
    save_ender_inventory(pname, inv, "quad")
    update_crucible_state(pos)
    if has_adjacent_lava(pos) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then timer:start(conversion_interval) end
    end
end
crucible_ender_quad_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local blocked = false
    local any_input = false
    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "quad")
        if inv and not inventory_input_empty(inv) then
            any_input = true
            for i = 1, inv:get_size("input") do
                local _, slot_blocked = process_input_stack(inv, i)
                blocked = blocked or slot_blocked
            end
            save_ender_inventory(playername, inv, "quad")
        end
    end
    update_crucible_state(pos)
    if not any_input then return false end
    if blocked then return true end
    for playername, _ in pairs(ender_users_seen) do
        local inv = get_ender_inventory(playername, "quad")
        if inv and not inventory_input_empty(inv) then return true end
    end
    return false
end
crucible_ender_quad_common.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    if not clicker or not clicker:is_player() then return end
    local pname = clicker:get_player_name()
    mark_ender_user(pname)
    local inv_name = "lava_crucible:ender_quad_" .. pname
    local inv = get_ender_inventory(pname, "quad")
    if not inv then return end
    local meta = minetest.get_meta(pos)
    meta:set_string("ender_user", pname)
    local dust_count = #dust_table * 2
    local dust_cols = math.min(dust_count, 8)
    local dust_rows = math.ceil(dust_count / dust_cols)
    local dust_y = 5.0
    local inv_label_y = dust_y + dust_rows + 0.4
    local inv_y = inv_label_y + 0.5
    local form_h = inv_y + 3.2
    local formspec = "size[9," .. form_h .. "]" ..
        "bgcolor[#080808BB;true]" ..
        "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
        "label[0.5,0.3;Quad Ender Lava Crucible]" ..
        "label[0.5,1;Input:]" ..
        "list[detached:" .. inv_name .. ";input;0.5,1.5;4,1;]" ..
        "label[0.5,2.8;Soil Output:]" ..
        "list[detached:" .. inv_name .. ";soil_output;0.5,3.3;4,1;]" ..
        "label[0.5,4.6;Ore Dust:]" ..
        "list[detached:" .. inv_name .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
        "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
        "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";input]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";soil_output]" ..
        "listring[current_player;main]" ..
        "listring[detached:" .. inv_name .. ";dust_output]"
    minetest.show_formspec(pname, "lava_crucible:crucible_gui", formspec)
    update_crucible_state(pos)
    if has_adjacent_lava(pos) and not inventory_input_empty(inv) then
        local timer = minetest.get_node_timer(pos)
        if not timer:is_started() then timer:start(conversion_interval) end
    end
end

local cold_ender_quad_crucible = clone_table(crucible_ender_quad_common)
cold_ender_quad_crucible.tiles = {
    "crucible_top.png^[colorize:#49305f:85",
    "crucible_bottom.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
    "crucible_side.png^[colorize:#49305f:85",
}
minetest.register_node("lava_crucible:lava_crucible_ender_quad", cold_ender_quad_crucible)

local hot_ender_quad_crucible = clone_table(crucible_ender_quad_common)
hot_ender_quad_crucible.tiles = {
    {
        name = "crucible_top_hot.png^[colorize:#3f245f:75",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_quad_crucible.light_source = 10
hot_ender_quad_crucible.node_box = { type = "fixed", fixed = cbox_quad_filled }
hot_ender_quad_crucible.groups = hot_ender_quad_crucible.groups or {}
hot_ender_quad_crucible.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_quad_hot", hot_ender_quad_crucible)

local hot_ender_quad_crucible_empty = clone_table(crucible_ender_quad_common)
hot_ender_quad_crucible_empty.tiles = {
    "crucible_top_hot_empty.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_quad_crucible_empty.light_source = 7
hot_ender_quad_crucible_empty.groups = hot_ender_quad_crucible_empty.groups or {}
hot_ender_quad_crucible_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_quad_hot_empty", hot_ender_quad_crucible_empty)

local hot_ender_quad_crucible_done = clone_table(crucible_ender_quad_common)
hot_ender_quad_crucible_done.tiles = {
    "crucible_top_hot_done.png^[colorize:#3f245f:75",
    "crucible_bottom_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
    "crucible_side_hot.png^[colorize:#3f245f:75",
}
hot_ender_quad_crucible_done.light_source = 7
hot_ender_quad_crucible_done.groups = hot_ender_quad_crucible_done.groups or {}
hot_ender_quad_crucible_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_ender_quad_hot_done", hot_ender_quad_crucible_done)

local cold_crucible_double = clone_table(crucible_double_common)
cold_crucible_double.tiles = {
    "crucible_top.png",
    "crucible_bottom.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
}
minetest.register_node("lava_crucible:lava_crucible_double", cold_crucible_double)

local hot_crucible_double = clone_table(crucible_double_common)
hot_crucible_double.tiles = {
    {
        name = "crucible_top_hot.png",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_double.light_source = 10
hot_crucible_double.node_box = { type = "fixed", fixed = cbox_double_filled }
hot_crucible_double.groups = hot_crucible_double.groups or {}
hot_crucible_double.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_double_hot", hot_crucible_double)

local hot_crucible_double_empty = clone_table(crucible_double_common)
hot_crucible_double_empty.tiles = {
    "crucible_top_hot_empty.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_double_empty.light_source = 7
hot_crucible_double_empty.groups = hot_crucible_double_empty.groups or {}
hot_crucible_double_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_double_hot_empty", hot_crucible_double_empty)

local hot_crucible_double_done = clone_table(crucible_double_common)
hot_crucible_double_done.tiles = {
    "crucible_top_hot_done.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_double_done.light_source = 7
hot_crucible_double_done.groups = hot_crucible_double_done.groups or {}
hot_crucible_double_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_double_hot_done", hot_crucible_double_done)

-- Quad Lava Crucible: 4 input slots, 4 soil output slots, 4x dust slots
local crucible_quad_common = clone_table(crucible_common)
crucible_quad_common.description = "Quad Lava Crucible"
crucible_quad_common.node_box = { type = "fixed", fixed = cbox_quad }
crucible_quad_common.after_place_node = function(pos, placer, itemstack, pointed_thing)
    if placer and placer:is_player() then
        local meta = minetest.get_meta(pos)
        meta:set_string("owner", placer:get_player_name())
        meta:set_string("infotext", "Quad Lava Crucible (owned by " .. placer:get_player_name() .. ")")
    end
    pcall(function()
        update_crucible_state(pos)
        if has_adjacent_lava(pos) then
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            if inv and not inventory_input_empty(inv) then
                local timer = minetest.get_node_timer(pos)
                if not timer:is_started() then timer:start(conversion_interval) end
            end
        end
    end)
end
crucible_quad_common.on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Quad Lava Crucible")
    local inv = meta:get_inventory()
    inv:set_size("input", 4)
    inv:set_size("soil_output", 8)
    inv:set_size("dust_output", #dust_table * 2)
end
crucible_quad_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local blocked = false
    for i = 1, inv:get_size("input") do
        local _, slot_blocked = process_input_stack(inv, i)
        blocked = blocked or slot_blocked
    end
    update_crucible_state(pos)
    if blocked then return true end
    return not crucible_input_empty(meta)
end
crucible_quad_common.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
    local meta = minetest.get_meta(pos)
    local owner = meta:get_string("owner")
    if owner ~= "" and clicker:get_player_name() ~= owner then
        minetest.chat_send_player(clicker:get_player_name(), "This crucible belongs to " .. owner .. ".")
        return
    end
    local pnode = pos.x .. "," .. pos.y .. "," .. pos.z
    local dust_count = #dust_table * 2
    local dust_cols = math.min(dust_count, 8)
    local dust_rows = math.ceil(dust_count / dust_cols)
    local dust_y = 5.0
    local inv_label_y = dust_y + dust_rows + 0.4
    local inv_y = inv_label_y + 0.5
    local form_h = inv_y + 3.2
    local formspec = "size[9," .. form_h .. "]" ..
        "bgcolor[#080808BB;true]" ..
        "background9[0,0;9," .. form_h .. ";gui_formbg.png;true;10]" ..
        "label[0.5,0.3;Quad Lava Crucible]" ..
        "label[0.5,1;Input:]" ..
        "list[nodemeta:" .. pnode .. ";input;0.5,1.5;4,1;]" ..
        "label[0.5,2.8;Soil Output:]" ..
        "list[nodemeta:" .. pnode .. ";soil_output;0.5,3.3;8,1;]" ..
        "label[0.5,4.6;Ore Dust:]" ..
        "list[nodemeta:" .. pnode .. ";dust_output;0.5," .. dust_y .. ";" .. dust_cols .. "," .. dust_rows .. ";]" ..
        "label[0.5," .. inv_label_y .. ";Player Inventory:]" ..
        "list[current_player;main;0.5," .. inv_y .. ";8,3;]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";input]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";soil_output]" ..
        "listring[current_player;main]" ..
        "listring[nodemeta:" .. pnode .. ";dust_output]"
    minetest.show_formspec(clicker:get_player_name(), "lava_crucible:crucible_gui", formspec)
end

local cold_crucible_quad = clone_table(crucible_quad_common)
cold_crucible_quad.tiles = {
    "crucible_top.png",
    "crucible_bottom.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
}
minetest.register_node("lava_crucible:lava_crucible_quad", cold_crucible_quad)

local hot_crucible_quad = clone_table(crucible_quad_common)
hot_crucible_quad.tiles = {
    {
        name = "crucible_top_hot.png",
        animation = {
            type = "vertical_frames",
            aspect_w = 128,
            aspect_h = 128,
            length = 4.5,
        },
    },
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_quad.light_source = 10
hot_crucible_quad.node_box = { type = "fixed", fixed = cbox_quad_filled }
hot_crucible_quad.groups = hot_crucible_quad.groups or {}
hot_crucible_quad.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_quad_hot", hot_crucible_quad)

local hot_crucible_quad_empty = clone_table(crucible_quad_common)
hot_crucible_quad_empty.tiles = {
    "crucible_top_hot_empty.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_quad_empty.light_source = 7
hot_crucible_quad_empty.groups = hot_crucible_quad_empty.groups or {}
hot_crucible_quad_empty.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_quad_hot_empty", hot_crucible_quad_empty)

local hot_crucible_quad_done = clone_table(crucible_quad_common)
hot_crucible_quad_done.tiles = {
    "crucible_top_hot_done.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible_quad_done.light_source = 7
hot_crucible_quad_done.groups = hot_crucible_quad_done.groups or {}
hot_crucible_quad_done.groups.not_in_creative_inventory = 1
minetest.register_node("lava_crucible:lava_crucible_quad_hot_done", hot_crucible_quad_done)

local active_crucible_nodes = {
    "lava_crucible:lava_crucible",
    "lava_crucible:lava_crucible_hot",
    "lava_crucible:lava_crucible_hot_done",
    "lava_crucible:lava_crucible_hot_empty",
    "lava_crucible:lava_crucible_ender",
    "lava_crucible:lava_crucible_ender_hot",
    "lava_crucible:lava_crucible_ender_hot_done",
    "lava_crucible:lava_crucible_ender_hot_empty",
    "lava_crucible:lava_crucible_ender_double",
    "lava_crucible:lava_crucible_ender_double_hot",
    "lava_crucible:lava_crucible_ender_double_hot_done",
    "lava_crucible:lava_crucible_ender_double_hot_empty",
    "lava_crucible:lava_crucible_ender_quad",
    "lava_crucible:lava_crucible_ender_quad_hot",
    "lava_crucible:lava_crucible_ender_quad_hot_done",
    "lava_crucible:lava_crucible_ender_quad_hot_empty",
    "lava_crucible:lava_crucible_double",
    "lava_crucible:lava_crucible_double_hot",
    "lava_crucible:lava_crucible_double_hot_done",
    "lava_crucible:lava_crucible_double_hot_empty",
    "lava_crucible:lava_crucible_quad",
    "lava_crucible:lava_crucible_quad_hot",
    "lava_crucible:lava_crucible_quad_hot_done",
    "lava_crucible:lava_crucible_quad_hot_empty",
}

minetest.register_abm({
    nodenames = active_crucible_nodes,
    neighbors = {"default:lava_flowing", "default:lava_source"},
    interval = conversion_interval,
    chance = 1,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
        update_crucible_state(pos)
        local should_start = false

        if is_ender_crucible_node(node.name) then
            local meta = minetest.get_meta(pos)
            local any_input, _ = get_ender_inventory_state(meta:get_string("ender_user"), get_ender_tier(node.name))
            should_start = any_input
        else
            local meta = minetest.get_meta(pos)
            local inv = get_processing_inventory(node, meta)
            should_start = inv and not inventory_input_empty(inv)
        end

        if should_start then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                timer:start(conversion_interval)
            end
        end
    end,
})

minetest.register_abm({
    nodenames = active_crucible_nodes,
    interval = 1,
    chance = 1,
    catch_up = false,
    action = function(pos, node, active_object_count, active_object_count_wider)
        if is_ender_crucible_node(node.name) then
            refresh_ender_user_from_nearby_player(pos)
        else
            collect_dropped_stone(pos)
        end
    end,
})

-- Clay Graphite: clay mixed with coal, used as the body material for crucibles
minetest.register_craftitem("lava_crucible:clay_graphite", {
    description = "Clay Graphite",
    inventory_image = "clay_graphite.png",
})

minetest.register_craft({
    type = "shapeless",
    output = "lava_crucible:clay_graphite",
    recipe = {"default:clay_lump", "default:coal_lump"},
})

minetest.register_craftitem("lava_crucible:obsidian_clay", {
    description = "Obsidian Clay",
    inventory_image = "clay_graphite.png^[colorize:#3a1f4f:95",
})

minetest.register_craft({
    type = "shapeless",
    output = "lava_crucible:obsidian_clay",
    recipe = {"default:clay_lump", "ore_dust:obsidian_dust"},
})

print("[lava_crucible] ========== REGISTERING UNCURED NODES AND RECIPES ==========")

-- Uncured Crucible: shaped from Clay Graphite, must be baked before use
print("[lava_crucible] Registering uncured_crucible node...")
minetest.register_node("lava_crucible:uncured_crucible", {
    description = "Uncured Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png",
        "crucible_uncured_bottom.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
    },
    node_box = { type = "fixed", fixed = cbox },
})
print("[lava_crucible] ✓ uncured_crucible node registered")

-- clay_graphite, none,          clay_graphite
-- clay_graphite, none,  clay_graphite
-- none,          clay_graphite, none
minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_crucible 1",
    recipe = {
        {"lava_crucible:clay_graphite", "",                          "lava_crucible:clay_graphite"},
        {"lava_crucible:clay_graphite", "",        "lava_crucible:clay_graphite"},
        {"",                                     "lava_crucible:clay_graphite", ""},
    }
})

-- Bake the uncured crucible in a furnace to produce a usable crucible
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible 1",
    recipe = "lava_crucible:uncured_crucible",
    cooktime = 15,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_crucible")

print("[lava_crucible] Registering uncured_ender_crucible node...")
minetest.register_node("lava_crucible:uncured_ender_crucible", {
    description = "Uncured Ender Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png^[colorize:#49305f:85",
        "crucible_uncured_bottom.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
    },
    node_box = { type = "fixed", fixed = cbox },
})
print("[lava_crucible] ✓ uncured_ender_crucible node registered")

minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_ender_crucible 1",
    recipe = {
        {"lava_crucible:obsidian_clay", "",                         "lava_crucible:obsidian_clay"},
        {"lava_crucible:obsidian_clay", "",                         "lava_crucible:obsidian_clay"},
        {"",                             "lava_crucible:obsidian_clay", ""},
    }
})

print("[lava_crucible] Registering cooking recipe: uncured_ender_crucible → lava_crucible_ender (15s)")
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible_ender 1",
    recipe = "lava_crucible:uncured_ender_crucible",
    cooktime = 15,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_ender_crucible")

-- Uncured Double Ender Crucible: 5 uncured ender crucibles in a cup shape, then baked
print("[lava_crucible] Registering uncured_ender_double_crucible node...")
minetest.register_node("lava_crucible:uncured_ender_double_crucible", {
    description = "Uncured Double Ender Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png^[colorize:#49305f:85",
        "crucible_uncured_bottom.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
    },
    node_box = { type = "fixed", fixed = cbox_double },
})
print("[lava_crucible] ✓ uncured_ender_double_crucible node registered")

minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_ender_double_crucible 1",
    recipe = {
        {"lava_crucible:uncured_ender_crucible", "",                                        "lava_crucible:uncured_ender_crucible"},
        {"lava_crucible:uncured_ender_crucible", "",                                        "lava_crucible:uncured_ender_crucible"},
        {"",                                     "lava_crucible:uncured_ender_crucible",    ""},
    }
})

print("[lava_crucible] Registering cooking recipe: uncured_ender_double_crucible → lava_crucible_ender_double (20s)")
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible_ender_double 1",
    recipe = "lava_crucible:uncured_ender_double_crucible",
    cooktime = 20,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_ender_double_crucible")

-- Uncured Quad Ender Crucible: 5 uncured double ender crucibles in a cup shape, then baked
print("[lava_crucible] Registering uncured_ender_quad_crucible node...")
minetest.register_node("lava_crucible:uncured_ender_quad_crucible", {
    description = "Uncured Quad Ender Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png^[colorize:#49305f:85",
        "crucible_uncured_bottom.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
        "crucible_uncured_side.png^[colorize:#49305f:85",
    },
    node_box = { type = "fixed", fixed = cbox_quad },
})
print("[lava_crucible] ✓ uncured_ender_quad_crucible node registered")

minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_ender_quad_crucible 1",
    recipe = {
        {"lava_crucible:uncured_ender_double_crucible", "",                                              "lava_crucible:uncured_ender_double_crucible"},
        {"lava_crucible:uncured_ender_double_crucible", "",                                              "lava_crucible:uncured_ender_double_crucible"},
        {"",                                            "lava_crucible:uncured_ender_double_crucible",   ""},
    }
})

print("[lava_crucible] Registering cooking recipe: uncured_ender_quad_crucible → lava_crucible_ender_quad (25s)")
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible_ender_quad 1",
    recipe = "lava_crucible:uncured_ender_quad_crucible",
    cooktime = 25,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_ender_quad_crucible")

-- Uncured Double Crucible: 5 uncured crucibles in a cup shape, then baked
print("[lava_crucible] Registering uncured_double_crucible node...")
minetest.register_node("lava_crucible:uncured_double_crucible", {
    description = "Uncured Double Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png",
        "crucible_uncured_bottom.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
    },
    node_box = { type = "fixed", fixed = cbox_double },
})
print("[lava_crucible] ✓ uncured_double_crucible node registered")

minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_double_crucible 1",
    recipe = {
        {"lava_crucible:uncured_crucible", "",                                   "lava_crucible:uncured_crucible"},
        {"lava_crucible:uncured_crucible", "",                                   "lava_crucible:uncured_crucible"},
        {"",                                        "lava_crucible:uncured_crucible", ""},
    }
})

print("[lava_crucible] Registering cooking recipe: uncured_double_crucible → lava_crucible_double (20s)")
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible_double 1",
    recipe = "lava_crucible:uncured_double_crucible",
    cooktime = 20,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_double_crucible")

-- Uncured Quad Crucible: 5 uncured double crucibles in a cup shape, then baked
print("[lava_crucible] Registering uncured_quad_crucible node...")
minetest.register_node("lava_crucible:uncured_quad_crucible", {
    description = "Uncured Quad Crucible",
    drawtype = "nodebox",
    paramtype = "light",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_uncured_top.png",
        "crucible_uncured_bottom.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
        "crucible_uncured_side.png",
    },
    node_box = { type = "fixed", fixed = cbox_quad },
})
print("[lava_crucible] ✓ uncured_quad_crucible node registered")

minetest.register_craft({
    type = "shaped",
    output = "lava_crucible:uncured_quad_crucible 1",
    recipe = {
        {"lava_crucible:uncured_double_crucible", "",                                          "lava_crucible:uncured_double_crucible"},
        {"lava_crucible:uncured_double_crucible", "",                                          "lava_crucible:uncured_double_crucible"},
        {"",                                               "lava_crucible:uncured_double_crucible", ""},
    }
})

print("[lava_crucible] Registering cooking recipe: uncured_quad_crucible → lava_crucible_quad (25s)")
minetest.register_craft({
    type = "cooking",
    output = "lava_crucible:lava_crucible_quad 1",
    recipe = "lava_crucible:uncured_quad_crucible",
    cooktime = 25,
})
print("[lava_crucible] ✓ Cooking recipe registered: uncured_quad_crucible")

-- Backward compatibility: map old item/node names to the new lava_crucible namespace
local legacy_names = {
    "lava_soil",
    "lava_crucible",
    "lava_crucible_hot",
    "lava_crucible_hot_empty",
    "lava_crucible_hot_done",
    "lava_crucible_double",
    "lava_crucible_double_hot",
    "lava_crucible_double_hot_empty",
    "lava_crucible_double_hot_done",
    "lava_crucible_quad",
    "lava_crucible_quad_hot",
    "lava_crucible_quad_hot_empty",
    "lava_crucible_quad_hot_done",
    "clay_graphite",
    "uncured_crucible",
    "uncured_double_crucible",
    "uncured_quad_crucible",
}

for _, name in ipairs(legacy_names) do
    minetest.register_alias("minetest_lava_crucible:" .. name, "lava_crucible:" .. name)
end

-- Formspec handler for the crucible GUI
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "lava_crucible:crucible_gui" then
        -- Formspec is closed, nothing action needed
        return true
    end
end)


-- Put cobble into the inventory for processing

-- Define the processing of rock into fertile soil
-- minetest.register_abm({

-- })

-- Define the random generation of mineral fragments




-- **** Example of getting image from another mod ****
-- local bucket_image = minetest.registered_craftitems["bucket:bucket_empty"].inventory_image

-- minetest.register_node("lava_crucible:crucible", {
--     description = "Lava Crucible",
--     tiles = {
--         bucket_image,
--         bucket_image,
--         bucket_image,
--         bucket_image,
--         bucket_image,
--         bucket_image
--     },
--     groups = {crumbly = 1, cracky = 1},
--     -- is_ground_content = false,
--     -- sunlight_propagates = false,
--     walkable = true,  -- If true, objects collide with node
--     pointable = true,  -- If true, can be pointed at
--     diggable = true,  -- If false, can never be dug
--     -- can_dig = function(pos)
--     --     return true
--     -- end,
--         -- Returns true if node can be dug, or false if not.
--         -- default: nil
    
-- })

-- DEBUG: Verify all recipes were registered
print("[lava_crucible] ========== RECIPE REGISTRATION VERIFICATION ==========")
local recipes_to_verify = {
    "uncured_crucible",
    "uncured_ender_crucible", 
    "uncured_double_crucible",
    "uncured_ender_double_crucible",
    "uncured_quad_crucible",
    "uncured_ender_quad_crucible"
}

print("[lava_crucible] Checking if uncured nodes exist in registry...")
for _, node_name in ipairs(recipes_to_verify) do
    local full_name = "lava_crucible:" .. node_name
    if minetest.registered_nodes[full_name] then
        print("[lava_crucible] ✓ Node registered: " .. full_name)
    else
        print("[lava_crucible] ✗ ERROR: Node NOT found in registry: " .. full_name)
    end
end

print("[lava_crucible] ========== END VERIFICATION ==========")
