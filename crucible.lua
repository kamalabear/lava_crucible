-- Define crucible

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

-- Define lava soil
minetest.register_node("minetest_lava_crucible:lava_soil", {
    description = "Lava Soil",
    is_ground_content = true,
    groups = { cracky = 1 },
    stack_max = 99,  -- Add this line to specify maximum stack size
    tiles = {
		{
			name = "lava_soil.png",
			backface_culling = false,
			animation = {
				type = "vertical_frames",
				aspect_w = 16,
				aspect_h = 16,
				length = 6.0,
			},
		},
    },
})

-- Function to convert stone to lava soil
function convert_stone_to_lava_soil(itemstack)
    -- Check if the item is a stone
    if minetest.get_item_group(itemstack:get_name(), "stone") > 0 then
        return ItemStack("minetest_lava_crucible:lava_soil " .. itemstack:get_count())
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

local function crucible_input_empty(meta)
    local inv = meta:get_inventory()
    for i = 1, inv:get_size("input") do
        if not inv:get_stack("input", i):is_empty() then return false end
    end
    return true
end

local function crucible_output_has_items(meta)
    local inv = meta:get_inventory()
    for i = 1, inv:get_size("soil_output") do
        if not inv:get_stack("soil_output", i):is_empty() then return true end
    end
    for i = 1, inv:get_size("dust_output") do
        if not inv:get_stack("dust_output", i):is_empty() then return true end
    end
    return false
end

local function crucible_has_contents(meta)
    if not crucible_input_empty(meta) then return true end
    return crucible_output_has_items(meta)
end

local function update_crucible_state(pos)
    local node = minetest.get_node(pos)
    local meta = minetest.get_meta(pos)
    local lava = has_adjacent_lava(pos)
    local input_empty = crucible_input_empty(meta)
    local output_full = crucible_output_has_items(meta)

    local is_quad = node.name:find("_quad") ~= nil
    local is_double = node.name:find("_double") ~= nil
    local prefix
    if is_quad then
        prefix = "minetest_lava_crucible:lava_crucible_quad"
    elseif is_double then
        prefix = "minetest_lava_crucible:lava_crucible_double"
    else
        prefix = "minetest_lava_crucible:lava_crucible"
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

-- Weighted dust table: higher weight = more common
local dust_table = {
    {item = "ore_dust:iron_dust",    weight = 40},
    {item = "ore_dust:copper_dust",  weight = 30},
    {item = "ore_dust:gold_dust",    weight = 8},
    {item = "ore_dust:diamond_dust", weight = 1},
}
if minetest.get_modpath("moreores") then
    table.insert(dust_table, {item = "ore_dust:tin_dust",    weight = 20})
    table.insert(dust_table, {item = "ore_dust:silver_dust", weight = 5})
    table.insert(dust_table, {item = "ore_dust:mithril_dust",weight = 2})
end

local dust_total_weight = 0
for _, entry in ipairs(dust_table) do
    dust_total_weight = dust_total_weight + entry.weight
end

local function pick_random_dust()
    local roll = math.random() * dust_total_weight
    local cumulative = 0
    for _, entry in ipairs(dust_table) do
        cumulative = cumulative + entry.weight
        if roll <= cumulative then
            return entry.item
        end
    end
    return dust_table[#dust_table].item
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
        if minetest.get_item_group(wielded_item:get_name(), "stone") > 0 then
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
        inv:set_size("soil_output", 1)
        inv:set_size("dust_output", #dust_table)
    end,
    on_timer = function(pos, elapsed)
        if not has_adjacent_lava(pos) then return false end
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local input_stack = inv:get_stack("input", 1)
        if input_stack:is_empty() then return false end
        if minetest.get_item_group(input_stack:get_name(), "stone") <= 0 then return false end
        local leftover = inv:add_item("soil_output", ItemStack("minetest_lava_crucible:lava_soil 1"))
        if leftover:get_count() > 0 then
            return true  -- soil_output full, retry after interval
        end
        input_stack:take_item(1)
        inv:set_stack("input", 1, input_stack)
        if math.random() < dust_chance then
            inv:add_item("dust_output", ItemStack(pick_random_dust() .. " 1"))
        end
        update_crucible_state(pos)
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
        local dust_cols = math.min(#dust_table, 8)
        local dust_rows = math.ceil(#dust_table / dust_cols)
        local formspec = "size[9,8.5]" ..
            "bgcolor[#080808BB;true]" ..
            "background9[0,0;9,8.5;gui_formbg.png;true;10]" ..
            "label[0.5,0.3;Lava Crucible]" ..
            "label[0.5,1;Input:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;0.5,1.5;1,1;]" ..
            "label[2.5,0.3;Soil Output:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";soil_output;2.5,1;1,1;]" ..
            "label[0.5,2.8;Ore Dust:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";dust_output;0.5,3.3;" .. dust_cols .. "," .. dust_rows .. ";]" ..
            "label[0.5,4.5;Player Inventory:]" ..
            "list[current_player;main;0.5,5;8,3;]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";soil_output]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";dust_output]"
        minetest.show_formspec(clicker:get_player_name(), "minetest_lava_crucible:crucible_gui", formspec)
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
end
crucible_double_common.on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Double Lava Crucible")
    local inv = meta:get_inventory()
    inv:set_size("input", 2)
    inv:set_size("soil_output", 2)
    inv:set_size("dust_output", #dust_table * 2)
end
crucible_double_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    for i = 1, inv:get_size("input") do
        local input_stack = inv:get_stack("input", i)
        if not input_stack:is_empty() and minetest.get_item_group(input_stack:get_name(), "stone") > 0 then
            local leftover = inv:add_item("soil_output", ItemStack("minetest_lava_crucible:lava_soil 1"))
            if leftover:get_count() == 0 then
                input_stack:take_item(1)
                inv:set_stack("input", i, input_stack)
                if math.random() < dust_chance then
                    inv:add_item("dust_output", ItemStack(pick_random_dust() .. " 1"))
                end
            end
        end
    end
    update_crucible_state(pos)
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
    local dust_count = #dust_table * 2
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
        "list[nodemeta:" .. pnode .. ";soil_output;3.5,1.5;2,1;]" ..
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
    minetest.show_formspec(clicker:get_player_name(), "minetest_lava_crucible:crucible_gui", formspec)
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
minetest.register_node("minetest_lava_crucible:lava_crucible", cold_crucible)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_hot", hot_crucible)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_hot_empty", hot_crucible_empty)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_hot_done", hot_crucible_done)

local cold_crucible_double = clone_table(crucible_double_common)
cold_crucible_double.tiles = {
    "crucible_top.png",
    "crucible_bottom.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
    "crucible_side.png",
}
minetest.register_node("minetest_lava_crucible:lava_crucible_double", cold_crucible_double)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_double_hot", hot_crucible_double)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_double_hot_empty", hot_crucible_double_empty)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_double_hot_done", hot_crucible_double_done)

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
end
crucible_quad_common.on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Quad Lava Crucible")
    local inv = meta:get_inventory()
    inv:set_size("input", 4)
    inv:set_size("soil_output", 4)
    inv:set_size("dust_output", #dust_table * 4)
end
crucible_quad_common.on_timer = function(pos, elapsed)
    if not has_adjacent_lava(pos) then return false end
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    for i = 1, inv:get_size("input") do
        local input_stack = inv:get_stack("input", i)
        if not input_stack:is_empty() and minetest.get_item_group(input_stack:get_name(), "stone") > 0 then
            local leftover = inv:add_item("soil_output", ItemStack("minetest_lava_crucible:lava_soil 1"))
            if leftover:get_count() == 0 then
                input_stack:take_item(1)
                inv:set_stack("input", i, input_stack)
                if math.random() < dust_chance then
                    inv:add_item("dust_output", ItemStack(pick_random_dust() .. " 1"))
                end
            end
        end
    end
    update_crucible_state(pos)
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
    local dust_count = #dust_table * 4
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
        "list[nodemeta:" .. pnode .. ";soil_output;0.5,3.3;4,1;]" ..
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
    minetest.show_formspec(clicker:get_player_name(), "minetest_lava_crucible:crucible_gui", formspec)
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
minetest.register_node("minetest_lava_crucible:lava_crucible_quad", cold_crucible_quad)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_quad_hot", hot_crucible_quad)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_quad_hot_empty", hot_crucible_quad_empty)

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
minetest.register_node("minetest_lava_crucible:lava_crucible_quad_hot_done", hot_crucible_quad_done)

minetest.register_abm({
    nodenames = {
        "minetest_lava_crucible:lava_crucible",
        "minetest_lava_crucible:lava_crucible_hot",
        "minetest_lava_crucible:lava_crucible_hot_done",
        "minetest_lava_crucible:lava_crucible_hot_empty",
        "minetest_lava_crucible:lava_crucible_double",
        "minetest_lava_crucible:lava_crucible_double_hot",
        "minetest_lava_crucible:lava_crucible_double_hot_done",
        "minetest_lava_crucible:lava_crucible_double_hot_empty",
        "minetest_lava_crucible:lava_crucible_quad",
        "minetest_lava_crucible:lava_crucible_quad_hot",
        "minetest_lava_crucible:lava_crucible_quad_hot_done",
        "minetest_lava_crucible:lava_crucible_quad_hot_empty",
    },
    neighbors = {"default:lava_flowing", "default:lava_source"},
    interval = conversion_interval,
    chance = 1,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
        update_crucible_state(pos)
        local meta = minetest.get_meta(pos)
        if not crucible_input_empty(meta) then
            local timer = minetest.get_node_timer(pos)
            if not timer:is_started() then
                timer:start(conversion_interval)
            end
        end
    end,
})

-- Define the recipe to create a crucible:
-- clay_lump, none, clay_lump
-- clay_lump, metal_dust, clay_lump
-- none, clay_lump, none
minetest.register_craft({
    type = "shaped",
    output = "minetest_lava_crucible:lava_crucible 1",
    recipe = {
        {"default:clay_lump","","default:clay_lump"},
        {"default:clay_lump","group:mineral_dust","default:clay_lump"},
        {"","default:clay_lump",""}
    }
})

minetest.register_craft({
    type = "shaped",
    output = "minetest_lava_crucible:lava_crucible_double 1",
    recipe = {
        {"minetest_lava_crucible:lava_crucible", "minetest_lava_crucible:lava_crucible"},
    }
})

minetest.register_craft({
    type = "shaped",
    output = "minetest_lava_crucible:lava_crucible_quad 1",
    recipe = {
        {"minetest_lava_crucible:lava_crucible_double", "minetest_lava_crucible:lava_crucible_double"},
    }
})

-- Formspec handler for the crucible GUI
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "minetest_lava_crucible:crucible_gui" then
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

-- minetest.register_node("minetest_lava_crucible:crucible", {
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
