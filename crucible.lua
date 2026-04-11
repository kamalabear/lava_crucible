-- Define crucible

local cbox = {
    {-0.5,  0.5, -0.5, -0.4, -0.4, -0.5}, -- North
    { 0.5,  0.5, -0.5,  0.4, -0.4, -0.5}, -- South
    {-0.5,  0.5, -0.5, -0.5, -0.4,  0.4}, -- East
    { 0.5,  0.5, -0.5,  0.5, -0.4,  0.4}, -- West
    {-0.5, -0.5, -0.5,  0.4, -0.4,  0.4}, -- Bottom
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

local function crucible_has_contents(meta)
    local inv = meta:get_inventory()
    return not inv:get_stack("input", 1):is_empty() or not inv:get_stack("output", 1):is_empty()
end

local function should_be_hot(pos)
    local meta = minetest.get_meta(pos)
    return crucible_has_contents(meta) and has_adjacent_lava(pos)
end

local function update_crucible_state(pos)
    local node = minetest.get_node(pos)
    local hot = should_be_hot(pos)
    if hot and node.name ~= "minetest_lava_crucible:lava_crucible_hot" then
        minetest.swap_node(pos, {name = "minetest_lava_crucible:lava_crucible_hot", param2 = node.param2})
    elseif not hot and node.name ~= "minetest_lava_crucible:lava_crucible" then
        minetest.swap_node(pos, {name = "minetest_lava_crucible:lava_crucible", param2 = node.param2})
    end
end

local crucible_common = {
    description = "A crucible that is used by placing it over lava",
    is_ground_content = false,
    groups = {cracky = 1},
    node_box = {
        type = "fixed",
        fixed = cbox,
    },
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        if to_list == "output" then
            return 0
        end
        return count
    end,
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        if listname == "output" then
            return 0
        end
        return stack:get_count()
    end,
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
        return stack:get_count()
    end,
    on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        update_crucible_state(pos)
    end,
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        update_crucible_state(pos)
    end,
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
        update_crucible_state(pos)
    end,
    on_punch = function(pos, node, puncher, pointed_thing)
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
            end
        end
    end,
    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Lava Crucible")
        local inv = meta:get_inventory()
        inv:set_size("input", 1)
        inv:set_size("output", 4)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local formspec = "size[9,7]" ..
            "bgcolor[#080808BB;true]" ..
            "background9[0,0;9,7;gui_formbg.png;true;10]" ..
            "label[0.5,0.3;Lava Crucible]" ..
            "label[0.5,1;Input:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;0.5,1.5;1,1;]" ..
            "label[3,1;Output:]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";output;3,1.5;4,1;]" ..
            "label[0.5,3;Player Inventory:]" ..
            "list[current_player;main;0.5,3.5;8,3;]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input]" ..
            "listring[current_player;main]" ..
            "listring[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";output]"
        minetest.show_formspec(clicker:get_player_name(), "minetest_lava_crucible:crucible_gui", formspec)
    end,
}

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
    "crucible_top_hot.png",
    "crucible_bottom_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
    "crucible_side_hot.png",
}
hot_crucible.light_source = 10
minetest.register_node("minetest_lava_crucible:lava_crucible_hot", hot_crucible)

minetest.register_abm({
    nodenames = {"minetest_lava_crucible:lava_crucible", "minetest_lava_crucible:lava_crucible_hot"},
    neighbors = {"default:lava_flowing", "default:lava_source"},
    interval = 10.0,
    chance = 1,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
        update_crucible_state(pos)
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        local input_stack = inv:get_stack("input", 1)
        if input_stack:is_empty() then
            return
        end
        if minetest.get_item_group(input_stack:get_name(), "stone") <= 0 then
            return
        end
        local lava_soil_count = input_stack:get_count()
        local lava_soil_stack = ItemStack("minetest_lava_crucible:lava_soil " .. lava_soil_count)
        local leftover = inv:add_item("output", lava_soil_stack)
        if leftover:get_count() > 0 then
            return
        end
        inv:set_stack("input", 1, ItemStack(""))
        update_crucible_state(pos)
        return true
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
