-- spec/inventory_spec.lua
-- Tests for inventory helper functions

describe("Inventory Helper Functions", function()
    local helpers = require("spec.spec_helper")
    
    before_each(function()
        helpers.reset()
    end)
    
    describe("inventory_input_empty()", function()
        local inventory_input_empty
        
        before_each(function()
            inventory_input_empty = function(inv)
                if not inv or not inv.get_size then return true end
                for i = 1, inv:get_size("input") do
                    local stack = inv:get_stack("input", i)
                    if stack and not stack:is_empty() then
                        return false
                    end
                end
                return true
            end
        end)
        
        it("should return true when all input slots empty", function()
            local inv = helpers.mock_inventory(3, 2)
            
            assert.is_true(inventory_input_empty(inv))
        end)
        
        it("should return false when input has items", function()
            local inv = helpers.mock_inventory(3, 2)
            inv:set_stack("input", 1, ItemStack("ore_dust:copper_dust 1"))
            
            assert.is_false(inventory_input_empty(inv))
        end)
        
        it("should return false when any input slot has items", function()
            local inv = helpers.mock_inventory(3, 2)
            inv:set_stack("input", 2, ItemStack("ore_dust:tin_dust 2"))
            
            assert.is_false(inventory_input_empty(inv))
        end)
        
        it("should handle nil inventory", function()
            assert.is_true(inventory_input_empty(nil))
        end)
        
        it("should handle single input slot", function()
            local inv = helpers.mock_inventory(1, 1)
            
            assert.is_true(inventory_input_empty(inv))
            
            inv:set_stack("input", 1, ItemStack("ore_dust:copper_dust 1"))
            assert.is_false(inventory_input_empty(inv))
        end)
    end)
    
    describe("inventory_output_has_items()", function()
        local inventory_output_has_items
        
        before_each(function()
            inventory_output_has_items = function(inv)
                if not inv or not inv.get_size then return false end
                
                for i = 1, inv:get_size("soil_output") do
                    local stack = inv:get_stack("soil_output", i)
                    if stack and not stack:is_empty() then
                        return true
                    end
                end
                
                for i = 1, inv:get_size("dust_output") do
                    local stack = inv:get_stack("dust_output", i)
                    if stack and not stack:is_empty() then
                        return true
                    end
                end
                
                return false
            end
        end)
        
        it("should return true when soil_output has items", function()
            local inv = helpers.mock_inventory(1, 2)
            inv:set_stack("soil_output", 1, ItemStack("volcanic_soil:volcanic_soil 1"))
            
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should return true when dust_output has items", function()
            local inv = helpers.mock_inventory(1, 2)
            inv:set_stack("dust_output", 1, ItemStack("ore_dust:copper_dust 1"))
            
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should return true when both outputs have items", function()
            local inv = helpers.mock_inventory(1, 2)
            inv:set_stack("soil_output", 1, ItemStack("volcanic_soil:volcanic_soil 1"))
            inv:set_stack("dust_output", 1, ItemStack("ore_dust:copper_dust 1"))
            
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should return false when all output slots empty", function()
            local inv = helpers.mock_inventory(1, 2)
            
            assert.is_false(inventory_output_has_items(inv))
        end)
        
        it("should return false with nil inventory", function()
            assert.is_false(inventory_output_has_items(nil))
        end)
        
        it("should detect items in multiple output slots", function()
            local inv = helpers.mock_inventory(1, 3)
            inv:set_stack("soil_output", 3, ItemStack("volcanic_soil:volcanic_soil 2"))
            
            assert.is_true(inventory_output_has_items(inv))
        end)
    end)
    
    describe("Inventory state checks", function()
        local inventory_input_empty, inventory_output_has_items
        
        before_each(function()
            inventory_input_empty = function(inv)
                if not inv or not inv.get_size then return true end
                for i = 1, inv:get_size("input") do
                    if not inv:get_stack("input", i):is_empty() then
                        return false
                    end
                end
                return true
            end
            
            inventory_output_has_items = function(inv)
                if not inv or not inv.get_size then return false end
                for i = 1, inv:get_size("soil_output") do
                    if not inv:get_stack("soil_output", i):is_empty() then
                        return true
                    end
                end
                for i = 1, inv:get_size("dust_output") do
                    if not inv:get_stack("dust_output", i):is_empty() then
                        return true
                    end
                end
                return false
            end
        end)
        
        it("should identify empty input + empty output (cold state)", function()
            local inv = helpers.mock_inventory(1, 1)
            
            assert.is_true(inventory_input_empty(inv))
            assert.is_false(inventory_output_has_items(inv))
        end)
        
        it("should identify filled input + empty output (heating state)", function()
            local inv = helpers.mock_inventory(1, 1)
            inv:set_stack("input", 1, ItemStack("default:stone 1"))
            
            assert.is_false(inventory_input_empty(inv))
            assert.is_false(inventory_output_has_items(inv))
        end)
        
        it("should identify empty input + filled output (done state)", function()
            local inv = helpers.mock_inventory(1, 1)
            inv:set_stack("soil_output", 1, ItemStack("volcanic_soil:volcanic_soil 1"))
            
            assert.is_true(inventory_input_empty(inv))
            assert.is_true(inventory_output_has_items(inv))
        end)
        
        it("should identify filled input + filled output (processing state)", function()
            local inv = helpers.mock_inventory(1, 1)
            inv:set_stack("input", 1, ItemStack("default:stone 1"))
            inv:set_stack("soil_output", 1, ItemStack("volcanic_soil:volcanic_soil 1"))
            
            assert.is_false(inventory_input_empty(inv))
            assert.is_true(inventory_output_has_items(inv))
        end)
    end)
    
    describe("Inventory stack operations", function()
        it("should get and set stacks", function()
            local inv = helpers.mock_inventory(2, 2)
            
            local stack = ItemStack("ore_dust:copper_dust 5")
            inv:set_stack("input", 1, stack)
            
            local retrieved = inv:get_stack("input", 1)
            assert.equals(retrieved:get_name(), "ore_dust:copper_dust")
            assert.equals(retrieved:get_count(), 5)
        end)
        
        it("should handle stack count changes", function()
            local inv = helpers.mock_inventory(1, 1)
            local stack = ItemStack("ore_dust:copper_dust 10")
            
            inv:set_stack("input", 1, stack)
            stack:set_count(5)
            inv:set_stack("input", 1, stack)
            
            local retrieved = inv:get_stack("input", 1)
            assert.equals(retrieved:get_count(), 5)
        end)
        
        it("should clear stacks correctly", function()
            local inv = helpers.mock_inventory(2, 2)
            inv:set_stack("input", 1, ItemStack("ore_dust:copper_dust 5"))
            inv:set_stack("input", 1, ItemStack(""))
            
            local cleared = inv:get_stack("input", 1)
            assert.is_true(cleared:is_empty())
        end)
    end)
    
    describe("Multi-tier inventory operations", function()
        it("should handle single tier (1 input, 1 output)", function()
            local inv = helpers.mock_inventory(1, 1)
            
            assert.equals(inv:get_size("input"), 1)
            assert.equals(inv:get_size("soil_output"), 1)
        end)
        
        it("should handle double tier (2 inputs, 2 outputs)", function()
            local inv = helpers.mock_inventory(2, 2)
            
            assert.equals(inv:get_size("input"), 2)
            assert.equals(inv:get_size("soil_output"), 2)
        end)
        
        it("should handle quad tier (4 inputs, 4 outputs)", function()
            local inv = helpers.mock_inventory(4, 4)
            
            assert.equals(inv:get_size("input"), 4)
            assert.equals(inv:get_size("soil_output"), 4)
        end)
        
        it("should process multiple input stacks", function()
            local inv = helpers.mock_inventory(3, 3)
            
            inv:set_stack("input", 1, ItemStack("default:stone 1"))
            inv:set_stack("input", 2, ItemStack("default:stone 1"))
            inv:set_stack("input", 3, ItemStack("default:stone 1"))
            
            local count = 0
            for i = 1, inv:get_size("input") do
                if not inv:get_stack("input", i):is_empty() then
                    count = count + 1
                end
            end
            
            assert.equals(count, 3)
        end)
        
        it("should distribute outputs across slots", function()
            local inv = helpers.mock_inventory(1, 4)
            
            inv:set_stack("soil_output", 1, ItemStack("volcanic_soil:volcanic_soil 1"))
            inv:set_stack("dust_output", 1, ItemStack("ore_dust:copper_dust 1"))
            inv:set_stack("dust_output", 2, ItemStack("ore_dust:tin_dust 1"))
            inv:set_stack("dust_output", 3, ItemStack("ore_dust:obsidian_dust 1"))
            
            local total = 0
            for i = 1, inv:get_size("soil_output") do
                if not inv:get_stack("soil_output", i):is_empty() then
                    total = total + 1
                end
            end
            for i = 1, inv:get_size("dust_output") do
                if not inv:get_stack("dust_output", i):is_empty() then
                    total = total + 1
                end
            end
            
            assert.equals(total, 4)
        end)
    end)
end)
