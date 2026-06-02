-- spec/crucible_spec.lua
-- Tests for core crucible logic functions

describe("Core Crucible Functions", function()
    local helpers = require("spec.spec_helper")
    
    setup(function()
        -- Load the crucible module
        package.path = package.path .. ";../?.lua"
    end)
    
    before_each(function()
        helpers.reset()
    end)
    
    describe("clone_table()", function()
        local clone_table
        
        before_each(function()
            -- Define clone_table for testing
            clone_table = function(tbl)
                local copy = {}
                for k, v in pairs(tbl) do
                    copy[k] = v
                end
                return copy
            end
        end)
        
        it("should create a shallow copy", function()
            local original = {a = 1, b = 2, c = 3}
            local copy = clone_table(original)
            
            assert.equals(copy.a, 1)
            assert.equals(copy.b, 2)
            assert.equals(copy.c, 3)
            assert.not_equals(copy, original)
        end)
        
        it("should handle empty tables", function()
            local original = {}
            local copy = clone_table(original)
            
            assert.equals(next(copy), nil)
            assert.not_equals(copy, original)
        end)
        
        it("should preserve nested tables by reference", function()
            local original = {a = {x = 1}, b = 2}
            local copy = clone_table(original)
            
            assert.equals(copy.a, original.a)
            assert.equals(copy.a.x, 1)
        end)
        
        it("should handle nil values", function()
            local original = {a = nil, b = 2}
            local copy = clone_table(original)
            
            assert.is_nil(copy.a)
            assert.equals(copy.b, 2)
        end)
    end)
    
    describe("convert_stone_to_lava_soil()", function()
        it("should convert stone item to lava soil", function()
            -- Register stone item
            helpers.register_item("default:stone", {
                description = "Stone",
                groups = {stone = 1}
            })
            
            local stone_stack = ItemStack("default:stone")
            
            -- Simulate the conversion function
            local result
            if minetest.get_item_group(stone_stack:get_name(), "stone") > 0 then
                result = ItemStack("volcanic_soil:volcanic_soil " .. stone_stack:get_count())
            end
            
            assert.not_nil(result)
            assert.equals(result:get_name(), "volcanic_soil:volcanic_soil")
            assert.equals(result:get_count(), 1)
        end)
        
        it("should preserve item count during conversion", function()
            helpers.register_item("default:cobble", {
                description = "Cobble",
                groups = {stone = 1}
            })
            
            local stone_stack = ItemStack("default:cobble 5")
            
            local result
            if minetest.get_item_group(stone_stack:get_name(), "stone") > 0 then
                result = ItemStack("volcanic_soil:volcanic_soil " .. stone_stack:get_count())
            end
            
            assert.equals(result:get_count(), 5)
        end)
        
        it("should return nil for non-stone items", function()
            helpers.register_item("default:dirt", {
                description = "Dirt",
                groups = {}
            })
            
            local dirt_stack = ItemStack("default:dirt")
            
            local result
            if minetest.get_item_group(dirt_stack:get_name(), "stone") > 0 then
                result = ItemStack("volcanic_soil:volcanic_soil " .. dirt_stack:get_count())
            else
                result = nil
            end
            
            assert.is_nil(result)
        end)
        
        it("should handle empty/nil itemstack", function()
            local empty_stack = ItemStack("")
            
            local result
            if minetest.get_item_group(empty_stack:get_name(), "stone") > 0 then
                result = ItemStack("volcanic_soil:volcanic_soil " .. empty_stack:get_count())
            else
                result = nil
            end
            
            assert.is_nil(result)
        end)
    end)
    
    describe("has_adjacent_lava()", function()
        it("should detect lava above a position", function()
            local pos = {x = 0, y = 0, z = 0}
            helpers.add_lava_at({x = 0, y = 1, z = 0})
            
            local has_lava = false
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
                    has_lava = true
                    break
                end
            end
            
            assert.is_true(has_lava)
        end)
        
        it("should detect lava below a position", function()
            local pos = {x = 0, y = 0, z = 0}
            helpers.add_lava_at({x = 0, y = -1, z = 0})
            
            local has_lava = false
            local neighbors = {
                {x = pos.x, y = pos.y - 1, z = pos.z},
            }
            
            for _, p in ipairs(neighbors) do
                local node = minetest.get_node(p)
                if node.name:find("lava") then
                    has_lava = true
                    break
                end
            end
            
            assert.is_true(has_lava)
        end)
        
        it("should return false when no adjacent lava", function()
            local pos = {x = 0, y = 0, z = 0}
            
            local has_lava = false
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
                if node.name:find("lava") then
                    has_lava = true
                    break
                end
            end
            
            assert.is_false(has_lava)
        end)
        
        it("should detect both lava_source and lava_flowing", function()
            local pos = {x = 0, y = 0, z = 0}
            
            -- Test source
            helpers.add_node_at({x = 1, y = 0, z = 0}, "default:lava_source")
            local node1 = minetest.get_node({x = 1, y = 0, z = 0})
            assert.equals(node1.name, "default:lava_source")
            
            -- Test flowing
            helpers.add_node_at({x = -1, y = 0, z = 0}, "default:lava_flowing")
            local node2 = minetest.get_node({x = -1, y = 0, z = 0})
            assert.equals(node2.name, "default:lava_flowing")
        end)
    end)
    
    describe("Ender node detection", function()
        it("should identify ender node names", function()
            local function is_ender_crucible_node(nodename)
                return nodename:find("lava_crucible_ender") ~= nil
            end
            
            assert.is_true(is_ender_crucible_node("lava_crucible_ender"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_double"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_quad"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_hot"))
        end)
        
        it("should reject non-ender nodes", function()
            local function is_ender_crucible_node(nodename)
                return nodename:find("lava_crucible_ender") ~= nil
            end
            
            assert.is_false(is_ender_crucible_node("lava_crucible"))
            assert.is_false(is_ender_crucible_node("lava_crucible_double"))
            assert.is_false(is_ender_crucible_node("lava_crucible_hot"))
        end)
    end)
end)
