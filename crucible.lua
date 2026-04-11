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

minetest.register_node("minetest_lava_crucible:lava_crucible", {
    description = "A crucible that is used by placing it over lava",
    is_ground_content = false,
    groups = {cracky = 1},
    tiles = {
        "crucible_top.png", -- up
        "crucible_bottom.png", -- down
        "crucible_side.png", -- right
        "crucible_side.png", -- left
        "crucible_side.png", -- back
        "crucible_side.png", -- front
    },
    node_box = {
        type = "fixed",
        fixed = cbox,
    },
    allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        return count
    end,
    
    allow_metadata_inventory_put = function(pos, listname, index, stack, player)
        return stack:get_count()
    end,
    
    allow_metadata_inventory_take = function(pos, listname, index, stack, player)
        return stack:get_count()
    end,
    
    on_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
        minetest.log("action", "[lava_crucible] Inventory moved at " .. minetest.pos_to_string(pos))
    end,
    
    on_metadata_inventory_put = function(pos, listname, index, stack, player)
        minetest.log("action", "[lava_crucible] Item added to inventory at " .. minetest.pos_to_string(pos))
    end,
    
    on_metadata_inventory_take = function(pos, listname, index, stack, player)
        minetest.log("action", "[lava_crucible] Item taken from inventory at " .. minetest.pos_to_string(pos))
    end,

    on_punch = function(pos, node, puncher, pointed_thing)
        -- Check if the player is holding a stone item
        local wielded_item = puncher:get_wielded_item()
        if wielded_item:is_empty() then
            return
        end
        
        if minetest.get_item_group(wielded_item:get_name(), "stone") > 0 then
            -- Get the inventory
            local meta = minetest.get_meta(pos)
            local inv = meta:get_inventory()
            
            -- Create a new ItemStack with the same contents
            local item_to_add = ItemStack(wielded_item:get_name() .. " " .. wielded_item:get_count())
            
            -- Try to add stone to the input slot
            local leftover = inv:add_item("input", item_to_add)
            
            if leftover:get_count() == item_to_add:get_count() then
                -- Nothing was added
                minetest.chat_send_player(puncher:get_player_name(), "The input slot is full!")
            else
                -- Some or all items were added, remove from player
                puncher:get_inventory():remove_item("main", wielded_item)
                local added_count = item_to_add:get_count() - leftover:get_count()
                minetest.log("action", "[lava_crucible] Added " .. added_count .. " stone to input slot at " .. minetest.pos_to_string(pos))
            end
        end
    end,

    on_construct = function(pos)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Lava Crucible")
        local inv = meta:get_inventory()
        inv:set_size("input", 1)
        inv:set_size("output", 1)
    end,

    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local meta = minetest.get_meta(pos)
        
        -- Use raw coordinates for the nodemeta reference and add background images for visibility
        local formspec = "size[6,4]" ..
            "label[0.5,0.3;Lava Crucible]" ..
            "label[0.5,1;Input:]" ..
            "image[0.5,1.5;1,1;default:gui_slot.png]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";input;0.5,1.5;1,1;0]" ..
            "label[3,1;Output:]" ..
            "image[3,1.5;1,1;default:gui_slot.png]" ..
            "list[nodemeta:" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ";output;3,1.5;1,1;0]"
        
        minetest.show_formspec(clicker:get_player_name(), "minetest_lava_crucible:crucible_gui", formspec)
    end,
})

minetest.register_abm({
	nodenames = {"minetest_lava_crucible:lava_crucible"},
	neighbors = {"default:lava_flowing", "default:lava_source"},
	interval = 10.0, -- Run every 10 seconds
    chance = 1,
    catch_up = true, -- Generate items that would have been generated while player was not present
    action = function(pos, node, active_object_count, active_object_count_wider)
        minetest.log("action", "[lava_crucible] Checking for stone in input slot at " .. minetest.pos_to_string(pos))
        
        -- Get the crucible inventory
        local meta = minetest.get_meta(pos)
        local inv = meta:get_inventory()
        
        -- Get input and output stacks
        local input_stack = inv:get_stack("input", 1)
        local output_stack = inv:get_stack("output", 1)
        
        -- Check if input is empty
        if input_stack:is_empty() then
            minetest.log("action", "[lava_crucible] Input slot is empty")
            return
        end
        
        -- Check if input is stone
        if minetest.get_item_group(input_stack:get_name(), "stone") <= 0 then
            minetest.log("action", "[lava_crucible] Input item is not stone: " .. input_stack:get_name())
            return
        end
        
        -- Check if output slot has room
        if not output_stack:is_empty() then
            minetest.log("action", "[lava_crucible] Output slot is full")
            return
        end
        
        -- Convert stone to lava_soil
        local lava_soil_count = input_stack:get_count()
        local lava_soil_stack = ItemStack("minetest_lava_crucible:lava_soil " .. lava_soil_count)
        
        -- Move converted items to output slot
        inv:set_stack("output", 1, lava_soil_stack)
        
        -- Clear input slot
        inv:set_stack("input", 1, ItemStack(""))
        
        minetest.log("action", "[lava_crucible] Converted " .. lava_soil_count .. " stone to lava_soil at " .. minetest.pos_to_string(pos))
        
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
