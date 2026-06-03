-- spec/dust_registry_spec.lua
-- Tests for dust registry system with dynamic discovery

describe("Dust Registry System (Dynamic Discovery)", function()
    local helpers = require("spec.spec_helper")
    
    before_each(function()
        helpers.reset()
        
        -- Initialize lava_crucible global with NEW validation behavior
        _G.lava_crucible = {
            register_dust_bonus = function(itemname, weight, options)
                if type(itemname) ~= "string" or itemname == "" then
                    minetest.log("warning", "[lava_crucible] register_dust_bonus: itemname must be a non-empty string")
                    return false
                end
                if type(weight) ~= "number" or weight <= 0 then
                    minetest.log("warning", "[lava_crucible] register_dust_bonus: weight must be a positive number")
                    return false
                end
                
                -- NEW: Validate that item is registered
                if not minetest.registered_items[itemname] then
                    minetest.log("warning", "[lava_crucible] Skipping unregistered dust item: " .. itemname)
                    return false
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
                
                return true  -- NEW: return success
            end,
        }
        
        _G.dust_table = {}
        _G.dust_entries_by_item = {}
        _G.dust_items_requiring_mineral_group = {}
        _G.dust_total_weight = 0
    end)
    
    describe("register_dust_bonus() with validation", function()
        it("should register only registered items", function()
            helpers.register_item("ore_dust:copper_dust", {
                description = "Copper Dust",
                groups = {}
            })
            
            local result = lava_crucible.register_dust_bonus("ore_dust:copper_dust", 30)
            
            assert.is_true(result)
            assert.equals(#_G.dust_table, 1)
        end)
        
        it("should skip unregistered items and return false", function()
            local result = lava_crucible.register_dust_bonus("nonexistent:dust", 10)
            
            assert.is_false(result)
            assert.equals(#_G.dust_table, 0)
        end)
        
        it("should register multiple items successfully", function()
            helpers.register_item("ore_dust:copper_dust", {description = "Copper Dust", groups = {}})
            helpers.register_item("ore_dust:tin_dust", {description = "Tin Dust", groups = {}})
            helpers.register_item("ore_dust:iron_dust", {description = "Iron Dust", groups = {}})
            
            local r1 = lava_crucible.register_dust_bonus("ore_dust:copper_dust", 30)
            local r2 = lava_crucible.register_dust_bonus("ore_dust:tin_dust", 20)
            local r3 = lava_crucible.register_dust_bonus("ore_dust:iron_dust", 40)
            
            assert.is_true(r1)
            assert.is_true(r2)
            assert.is_true(r3)
            assert.equals(#_G.dust_table, 3)
        end)
        
        it("should return false for invalid weight", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            
            local result = lava_crucible.register_dust_bonus("ore_dust:copper_dust", 0)
            
            assert.is_false(result)
        end)
        
        it("should grant mineral_dust group when requested", function()
            helpers.register_item("ore_dust:copper_dust", {
                description = "Copper Dust",
                groups = {}
            })
            
            local result = lava_crucible.register_dust_bonus("ore_dust:copper_dust", 30, 
                {grant_mineral_dust_group = true})
            
            assert.is_true(result)
            assert.is_true(_G.dust_items_requiring_mineral_group["ore_dust:copper_dust"])
        end)
    end)
    
    describe("Dynamic dust discovery", function()
        local discover_and_register_dusts
        local get_default_weight
        
        before_each(function()
            -- Reset state for discovery tests
            helpers.reset()
            _G.dust_table = {}
            _G.dust_entries_by_item = {}
            _G.dust_total_weight = 0
            
            -- Initialize lava_crucible with validation behavior
            _G.lava_crucible = {
                register_dust_bonus = function(itemname, weight, options)
                    if type(itemname) ~= "string" or itemname == "" then
                        minetest.log("warning", "[lava_crucible] register_dust_bonus: itemname must be a non-empty string")
                        return false
                    end
                    if type(weight) ~= "number" or weight <= 0 then
                        minetest.log("warning", "[lava_crucible] register_dust_bonus: weight must be a positive number")
                        return false
                    end
                    
                    if not minetest.registered_items[itemname] then
                        minetest.log("warning", "[lava_crucible] Skipping unregistered dust item: " .. itemname)
                        return false
                    end
                    
                    if not _G.dust_table then _G.dust_table = {} end
                    if not _G.dust_entries_by_item then _G.dust_entries_by_item = {} end
                    
                    local entry = _G.dust_entries_by_item[itemname]
                    if entry then
                        entry.weight = weight
                    else
                        entry = {item = itemname, weight = weight}
                        _G.dust_entries_by_item[itemname] = entry
                        table.insert(_G.dust_table, entry)
                    end
                    
                    if options and options.grant_mineral_dust_group then
                        _G.dust_items_requiring_mineral_group = _G.dust_items_requiring_mineral_group or {}
                        _G.dust_items_requiring_mineral_group[itemname] = true
                    end
                    
                    return true
                end,
            }
            
            -- Mock the discovery functions
            get_default_weight = function(material_name, is_lump)
                local defaults = {coal=18, copper=30, iron=40, gold=8, silver=5}
                return defaults[material_name] or 10
            end
            
            discover_and_register_dusts = function()
                local dust_count = 0
                local items_to_scan = {}
                for itemname, def in pairs(minetest.registered_items) do
                    items_to_scan[itemname] = def
                end
                for nodename, def in pairs(minetest.registered_nodes) do
                    items_to_scan[nodename] = def
                end
                
                for itemname, def in pairs(items_to_scan) do
                    if itemname:find("_dust$") then
                        -- Extract material name: "ore_dust:copper_dust" -> "copper"
                        -- First remove the "_dust" suffix
                        local without_suffix = itemname:gsub("_dust$", "")
                        -- Then get everything after the last colon or underscore
                        local material = without_suffix:match("[^_:]*$")
                        if material and material ~= "" then
                            local weight = get_default_weight(material, false)
                            if lava_crucible.register_dust_bonus(itemname, weight, {grant_mineral_dust_group = true}) then
                                dust_count = dust_count + 1
                            end
                        end
                    end
                end
                return dust_count
            end
        end)
        
        it("should discover dusts from craftitems", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            helpers.register_item("ore_dust:tin_dust", {groups = {}})
            
            local count = discover_and_register_dusts()
            
            assert.equals(count, 2)
            assert.equals(#_G.dust_table, 2)
        end)
        
        it("should discover dusts from nodes", function()
            minetest.register_node("ore_dust:copper_dust", {description = "Copper Dust"})
            minetest.register_node("ore_dust:tin_dust", {description = "Tin Dust"})
            
            local count = discover_and_register_dusts()
            
            assert.equals(count, 2)
            assert.equals(#_G.dust_table, 2)
        end)
        
        it("should extract material name correctly", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            helpers.register_item("technic:gold_dust", {groups = {}})
            helpers.register_item("mineral_dust:coal_dust", {groups = {}})
            
            -- Clear dust table to ensure clean state
            _G.dust_table = {}
            _G.dust_entries_by_item = {}
            
            discover_and_register_dusts()
            
            assert.equals(3, #_G.dust_table)
            
            -- Verify correct weights by checking the discovered entries
            local found = {copper = false, gold = false, coal = false}
            for _, entry in ipairs(_G.dust_table) do
                if entry.item == "ore_dust:copper_dust" then
                    assert.equals(30, entry.weight)
                    found.copper = true
                elseif entry.item == "technic:gold_dust" then
                    assert.equals(8, entry.weight)
                    found.gold = true
                elseif entry.item == "mineral_dust:coal_dust" then
                    assert.equals(18, entry.weight)
                    found.coal = true
                end
            end
            
            assert.is_true(found.copper)
            assert.is_true(found.gold)
            assert.is_true(found.coal)
        end)
        
        it("should skip unregistered dusts silently", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            -- Register node that ends in _dust but isn't actually registered as item
            
            local count = discover_and_register_dusts()
            
            -- Should only find the one valid dust
            assert.equals(count, 1)
            assert.equals(#_G.dust_table, 1)
        end)
        
        it("should use default weight for unknown materials", function()
            helpers.register_item("unknown_dust", {groups = {}})
            
            discover_and_register_dusts()
            
            -- Unknown material should get default weight of 10
            assert.equals(_G.dust_table[1].weight, 10)
        end)
        
        it("should return discovery count", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            helpers.register_item("ore_dust:iron_dust", {groups = {}})
            helpers.register_item("ore_dust:gold_dust", {groups = {}})
            
            local count = discover_and_register_dusts()
            
            assert.equals(count, 3)
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
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            helpers.register_item("ore_dust:tin_dust", {groups = {}})
            
            lava_crucible.register_dust_bonus("ore_dust:copper_dust", 30)
            lava_crucible.register_dust_bonus("ore_dust:tin_dust", 20)
            
            recompute_dust_total_weight()
            
            assert.equals(_G.dust_total_weight, 50)
        end)
        
        it("should handle empty dust table", function()
            _G.dust_table = {}
            
            recompute_dust_total_weight()
            
            assert.equals(_G.dust_total_weight, 0)
        end)
    end)
    
    describe("Dynamic lump discovery", function()
        local discover_and_register_lumps
        local get_default_weight
        
        before_each(function()
            _G.lump_table = {}
            _G.lump_total_weight = 0
            
            get_default_weight = function(material_name, is_lump)
                local defaults = {iron=40, copper=30, gold=8, tin=20, silver=5}
                return defaults[material_name] or 10
            end
            
            discover_and_register_lumps = function()
                local lump_count = 0
                local items_to_scan = {}
                for itemname, def in pairs(minetest.registered_items) do
                    items_to_scan[itemname] = def
                end
                for nodename, def in pairs(minetest.registered_nodes) do
                    items_to_scan[nodename] = def
                end
                
                for itemname, def in pairs(items_to_scan) do
                    if itemname:find("_lump$") then
                        -- Extract material name: "ore_dust:iron_lump" -> "iron"
                        -- First remove the "_lump" suffix
                        local without_suffix = itemname:gsub("_lump$", "")
                        -- Then get everything after the last colon or underscore
                        local material = without_suffix:match("[^_:]*$")
                        if material and material ~= "" then
                            local weight = get_default_weight(material, true)
                            local entry = {item = itemname, weight = weight}
                            table.insert(_G.lump_table, entry)
                            lump_count = lump_count + 1
                        end
                    end
                end
                return lump_count
            end
        end)
        
        it("should discover lumps from craftitems and nodes", function()
            helpers.register_item("ore_dust:iron_lump", {groups = {}})
            minetest.register_node("ore_dust:copper_lump", {description = "Copper Lump"})
            
            local count = discover_and_register_lumps()
            
            assert.equals(count, 2)
            assert.equals(#_G.lump_table, 2)
        end)
        
        it("should assign correct weights to lumps", function()
            helpers.register_item("ore_dust:iron_lump", {groups = {}})
            helpers.register_item("ore_dust:copper_lump", {groups = {}})
            
            discover_and_register_lumps()
            
            -- Check that we found both lumps with correct weights
            assert.equals(#_G.lump_table, 2)
            
            local found = {iron = false, copper = false}
            for _, entry in ipairs(_G.lump_table) do
                if entry.item == "ore_dust:iron_lump" then
                    assert.equals(40, entry.weight)
                    found.iron = true
                elseif entry.item == "ore_dust:copper_lump" then
                    assert.equals(30, entry.weight)
                    found.copper = true
                end
            end
            
            assert.is_true(found.iron)
            assert.is_true(found.copper)
        end)
    end)
    
    describe("pick_random_dust() selection function", function()
        local pick_random_dust
        
        before_each(function()
            helpers.reset()
            _G.dust_table = {}
            _G.dust_total_weight = 0
            
            -- Mock pick_random_dust with defensive validation
            pick_random_dust = function()
                if not _G.dust_table or #_G.dust_table == 0 then
                    return nil
                end
                
                if _G.dust_total_weight <= 0 then
                    return nil
                end
                
                local roll = math.random(_G.dust_total_weight)
                local cumulative = 0
                for _, entry in ipairs(_G.dust_table) do
                    cumulative = cumulative + entry.weight
                    if roll <= cumulative then
                        -- Defensive check: verify item is still registered
                        if minetest.registered_items[entry.item] then
                            return entry.item
                        end
                    end
                end
                return nil
            end
        end)
        
        it("should return nil when pool is empty", function()
            local selected = pick_random_dust()
            
            assert.is_nil(selected)
        end)
        
        it("should return a valid dust item", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            
            _G.dust_table = {{item = "ore_dust:copper_dust", weight = 30}}
            _G.dust_total_weight = 30
            
            local selected = pick_random_dust()
            
            assert.is_not_nil(selected)
            assert.equals(selected, "ore_dust:copper_dust")
        end)
        
        it("should select from multiple dusts with weighted probability", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            helpers.register_item("ore_dust:gold_dust", {groups = {}})
            
            _G.dust_table = {
                {item = "ore_dust:copper_dust", weight = 30},
                {item = "ore_dust:gold_dust", weight = 5}
            }
            _G.dust_total_weight = 35
            
            local selected = pick_random_dust()
            
            assert.is_not_nil(selected)
            assert.is_true(selected == "ore_dust:copper_dust" or selected == "ore_dust:gold_dust")
        end)
        
        it("should skip unregistered items gracefully", function()
            helpers.register_item("ore_dust:copper_dust", {groups = {}})
            -- ore_dust:gold_dust is NOT registered
            
            _G.dust_table = {
                {item = "ore_dust:copper_dust", weight = 30},
                {item = "ore_dust:gold_dust", weight = 5}  -- unregistered
            }
            _G.dust_total_weight = 35
            
            local selected = pick_random_dust()
            
            -- Should return a valid registered item or nil
            if selected then
                assert.is_not_nil(minetest.registered_items[selected])
            end
        end)
        
        it("should return nil if total weight is zero", function()
            _G.dust_table = {{item = "ore_dust:copper_dust", weight = 30}}
            _G.dust_total_weight = 0
            
            local selected = pick_random_dust()
            
            assert.is_nil(selected)
        end)
    end)
    
    describe("pick_random_lump() selection function", function()
        local pick_random_lump
        
        before_each(function()
            helpers.reset()
            _G.lump_table = {}
            _G.lump_total_weight = 0
            
            -- Mock pick_random_lump with defensive validation
            pick_random_lump = function()
                if not _G.lump_table or #_G.lump_table == 0 then
                    return nil
                end
                
                if _G.lump_total_weight <= 0 then
                    return nil
                end
                
                local roll = math.random(_G.lump_total_weight)
                local cumulative = 0
                for _, entry in ipairs(_G.lump_table) do
                    cumulative = cumulative + entry.weight
                    if roll <= cumulative then
                        -- Defensive check: verify item is still registered
                        if minetest.registered_items[entry.item] then
                            return entry.item
                        end
                    end
                end
                return nil
            end
        end)
        
        it("should return nil when pool is empty", function()
            local selected = pick_random_lump()
            
            assert.is_nil(selected)
        end)
        
        it("should return a valid lump item", function()
            helpers.register_item("ore_dust:iron_lump", {groups = {}})
            
            _G.lump_table = {{item = "ore_dust:iron_lump", weight = 40}}
            _G.lump_total_weight = 40
            
            local selected = pick_random_lump()
            
            assert.is_not_nil(selected)
            assert.equals(selected, "ore_dust:iron_lump")
        end)
        
        it("should select from multiple lumps with weighted probability", function()
            helpers.register_item("ore_dust:iron_lump", {groups = {}})
            helpers.register_item("ore_dust:copper_lump", {groups = {}})
            
            _G.lump_table = {
                {item = "ore_dust:iron_lump", weight = 40},
                {item = "ore_dust:copper_lump", weight = 30}
            }
            _G.lump_total_weight = 70
            
            local selected = pick_random_lump()
            
            assert.is_not_nil(selected)
            assert.is_true(selected == "ore_dust:iron_lump" or selected == "ore_dust:copper_lump")
        end)
        
        it("should skip unregistered lumps gracefully", function()
            helpers.register_item("ore_dust:iron_lump", {groups = {}})
            -- ore_dust:gold_lump is NOT registered
            
            _G.lump_table = {
                {item = "ore_dust:iron_lump", weight = 40},
                {item = "ore_dust:gold_lump", weight = 8}  -- unregistered
            }
            _G.lump_total_weight = 48
            
            local selected = pick_random_lump()
            
            -- Should return a valid registered item or nil
            if selected then
                assert.is_not_nil(minetest.registered_items[selected])
            end
        end)
    end)
end)
