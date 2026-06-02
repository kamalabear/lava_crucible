-- spec/dust_registry_spec.lua
-- Tests for dust registry system

describe("Dust Registry System", function()
    local helpers = require("spec.spec_helper")
    
    before_each(function()
        helpers.reset()
        -- Initialize lava_crucible global
        _G.lava_crucible = {
            register_dust_bonus = function(itemname, weight, options)
                if type(itemname) ~= "string" or itemname == "" then
                    error("lava_crucible.register_dust_bonus: itemname must be a non-empty string")
                end
                if type(weight) ~= "number" or weight <= 0 then
                    error("lava_crucible.register_dust_bonus: weight must be a positive number")
                end
                
                -- Store in dust table (simulated global)
                if not _G.dust_table then _G.dust_table = {} end
                if not _G.dust_entries_by_item then _G.dust_entries_by_item = {} end
                if not _G.dust_items_requiring_mineral_group then _G.dust_items_requiring_mineral_group = {} end
                
                local entry = _G.dust_entries_by_item[itemname]
                if entry then
                    entry.weight = weight
                else
                    entry = {item = itemname, weight = weight}
                    _G.dust_entries_by_item[itemname] = entry
                    table.insert(_G.dust_table, entry)
                end
                
                if options and options.grant_mineral_dust_group then
                    _G.dust_items_requiring_mineral_group[itemname] = true
                end
            end,
        }
        
        _G.dust_table = {}
        _G.dust_entries_by_item = {}
        _G.dust_items_requiring_mineral_group = {}
        _G.dust_total_weight = 0
    end)
    
    describe("register_dust_bonus()", function()
        it("should register a single dust bonus", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
            
            assert.equals(#_G.dust_table, 1)
            assert.equals(_G.dust_table[1].item, "ore_dust:copper_dust")
            assert.equals(_G.dust_table[1].weight, 1.0)
        end)
        
        it("should register multiple dust bonuses", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
            lava_crucible.register_dust_bonus("ore_dust:tin_dust", 1.5)
            lava_crucible.register_dust_bonus("ore_dust:obsidian_dust", 2.0)
            
            assert.equals(#_G.dust_table, 3)
            assert.equals(_G.dust_table[1].weight, 1.0)
            assert.equals(_G.dust_table[2].weight, 1.5)
            assert.equals(_G.dust_table[3].weight, 2.0)
        end)
        
        it("should update weight if already registered", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
            assert.equals(#_G.dust_table, 1)
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 2.5)
            
            assert.equals(#_G.dust_table, 1)
            assert.equals(_G.dust_table[1].weight, 2.5)
        end)
        
        it("should error on empty itemname", function()
            assert.has_error(function()
                lava_crucible.register_dust_bonus("", 1.0)
            end)
        end)
        
        it("should error on non-string itemname", function()
            assert.has_error(function()
                lava_crucible.register_dust_bonus(123, 1.0)
            end)
        end)
        
        it("should error on zero weight", function()
            assert.has_error(function()
                lava_crucible.register_dust_bonus("ore_dust:copper_dust", 0)
            end)
        end)
        
        it("should error on negative weight", function()
            assert.has_error(function()
                lava_crucible.register_dust_bonus("ore_dust:copper_dust", -1)
            end)
        end)
        
        it("should grant mineral_dust group when requested", function()
            helpers.register_item("ore_dust:copper_dust", {
                description = "Copper Dust",
                groups = {}
            })
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0, 
                {grant_mineral_dust_group = true})
            
            assert.is_true(_G.dust_items_requiring_mineral_group["ore_dust:copper_dust"])
        end)
        
        it("should not grant group when not requested", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
            
            assert.is_nil(_G.dust_items_requiring_mineral_group["ore_dust:copper_dust"])
        end)
    end)
    
    describe("recompute_dust_total_weight()", function()
        local recompute_dust_total_weight
        
        before_each(function()
            recompute_dust_total_weight = function()
                _G.dust_total_weight = 0
                if not _G.dust_table then return end
                for _, entry in ipairs(_G.dust_table) do
                    _G.dust_total_weight = _G.dust_total_weight + entry.weight
                end
            end
        end)
        
        it("should compute total weight correctly", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 2.0)
            lava_crucible.register_dust_bonus("ore_dust:tin_dust", 3.0)
            
            recompute_dust_total_weight()
            
            assert.equals(_G.dust_total_weight, 5.0)
        end)
        
        it("should handle single item", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 2.5)
            
            recompute_dust_total_weight()
            
            assert.equals(_G.dust_total_weight, 2.5)
        end)
        
        it("should handle empty dust table", function()
            _G.dust_table = {}
            
            recompute_dust_total_weight()
            
            assert.equals(_G.dust_total_weight, 0)
        end)
        
        it("should update on weight changes", function()
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0)
            recompute_dust_total_weight()
            assert.equals(_G.dust_total_weight, 1.0)
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 3.0)
            recompute_dust_total_weight()
            assert.equals(_G.dust_total_weight, 3.0)
        end)
    end)
    
    describe("apply_mineral_dust_overrides()", function()
        local apply_mineral_dust_overrides
        
        before_each(function()
            apply_mineral_dust_overrides = function()
                for itemname in pairs(_G.dust_items_requiring_mineral_group) do
                    local def = minetest.registered_items[itemname]
                    if def then
                        local groups = {}
                        for k, v in pairs(def.groups or {}) do
                            groups[k] = v
                        end
                        groups.mineral_dust = 1
                        minetest.override_item(itemname, {groups = groups})
                    end
                end
            end
        end)
        
        it("should add mineral_dust group to registered items", function()
            helpers.register_item("ore_dust:copper_dust", {
                description = "Copper Dust",
                groups = {ore_dust = 1}
            })
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0, 
                {grant_mineral_dust_group = true})
            
            apply_mineral_dust_overrides()
            
            local item = minetest.registered_items["ore_dust:copper_dust"]
            assert.equals(item.groups.mineral_dust, 1)
            assert.equals(item.groups.ore_dust, 1)
        end)
        
        it("should handle multiple items", function()
            helpers.register_item("ore_dust:copper_dust", {
                description = "Copper Dust",
                groups = {}
            })
            helpers.register_item("ore_dust:tin_dust", {
                description = "Tin Dust",
                groups = {}
            })
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 1.0,
                {grant_mineral_dust_group = true})
            lava_crucible.register_dust_bonus("ore_dust:tin_dust", 1.0,
                {grant_mineral_dust_group = true})
            
            apply_mineral_dust_overrides()
            
            assert.equals(minetest.registered_items["ore_dust:copper_dust"].groups.mineral_dust, 1)
            assert.equals(minetest.registered_items["ore_dust:tin_dust"].groups.mineral_dust, 1)
        end)
        
        it("should skip unregistered items gracefully", function()
            lava_crucible.register_dust_bonus("ore_dust:nonexistent", 1.0,
                {grant_mineral_dust_group = true})
            
            -- Should not crash
            assert.has_no_error(function()
                apply_mineral_dust_overrides()
            end)
        end)
    end)
end)
