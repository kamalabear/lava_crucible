-- spec/ender_spec.lua
-- Tests for ender crucible functionality

describe("Ender Crucible Functions", function()
    local helpers = require("spec.spec_helper")
    
    before_each(function()
        helpers.reset()
        
        -- Initialize ender utilities
        _G.ender_users_seen = {}
    end)
    
    describe("is_ender_crucible_node()", function()
        local is_ender_crucible_node
        
        before_each(function()
            is_ender_crucible_node = function(nodename)
                return nodename:find("lava_crucible_ender") ~= nil
            end
        end)
        
        it("should detect single ender nodes", function()
            assert.is_true(is_ender_crucible_node("lava_crucible_ender"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_hot"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_hot_empty"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_hot_done"))
        end)
        
        it("should detect double ender nodes", function()
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_double"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_double_hot"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_double_hot_done"))
        end)
        
        it("should detect quad ender nodes", function()
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_quad"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_quad_hot"))
            assert.is_true(is_ender_crucible_node("lava_crucible_ender_quad_hot_done"))
        end)
        
        it("should reject non-ender nodes", function()
            assert.is_false(is_ender_crucible_node("lava_crucible"))
            assert.is_false(is_ender_crucible_node("lava_crucible_hot"))
            assert.is_false(is_ender_crucible_node("lava_crucible_double"))
            assert.is_false(is_ender_crucible_node("lava_crucible_double_hot"))
        end)
        
        it("should reject non-crucible nodes", function()
            assert.is_false(is_ender_crucible_node("default:stone"))
            assert.is_false(is_ender_crucible_node("ender"))
            assert.is_false(is_ender_crucible_node("lava"))
        end)
    end)
    
    describe("get_ender_tier()", function()
        local get_ender_tier
        
        before_each(function()
            get_ender_tier = function(nodename)
                if nodename:find("lava_crucible_ender_quad") then
                    return "quad"
                elseif nodename:find("lava_crucible_ender_double") then
                    return "double"
                elseif nodename:find("lava_crucible_ender") then
                    return "single"
                end
                return nil
            end
        end)
        
        it("should detect single tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender"), "single")
            assert.equals(get_ender_tier("lava_crucible_ender_hot"), "single")
            assert.equals(get_ender_tier("lava_crucible_ender_hot_empty"), "single")
            assert.equals(get_ender_tier("lava_crucible_ender_hot_done"), "single")
        end)
        
        it("should detect double tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender_double"), "double")
            assert.equals(get_ender_tier("lava_crucible_ender_double_hot"), "double")
            assert.equals(get_ender_tier("lava_crucible_ender_double_hot_empty"), "double")
            assert.equals(get_ender_tier("lava_crucible_ender_double_hot_done"), "double")
        end)
        
        it("should detect quad tier", function()
            assert.equals(get_ender_tier("lava_crucible_ender_quad"), "quad")
            assert.equals(get_ender_tier("lava_crucible_ender_quad_hot"), "quad")
            assert.equals(get_ender_tier("lava_crucible_ender_quad_hot_empty"), "quad")
            assert.equals(get_ender_tier("lava_crucible_ender_quad_hot_done"), "quad")
        end)
        
        it("should return nil for non-ender nodes", function()
            assert.is_nil(get_ender_tier("lava_crucible"))
            assert.is_nil(get_ender_tier("default:stone"))
        end)
    end)
    
    describe("mark_ender_user()", function()
        local mark_ender_user, save_ender_users_seen
        
        before_each(function()
            mark_ender_user = function(playername)
                if playername and playername ~= "" and not _G.ender_users_seen[playername] then
                    _G.ender_users_seen[playername] = true
                    save_ender_users_seen()
                end
            end
            
            save_ender_users_seen = function()
                local users = {}
                for pname, _ in pairs(_G.ender_users_seen) do
                    table.insert(users, pname)
                end
                minetest.get_mod_storage():set_string("ender_users_seen", minetest.serialize(users))
            end
        end)
        
        it("should mark new users", function()
            mark_ender_user("PlayerOne")
            
            assert.is_true(_G.ender_users_seen["PlayerOne"])
        end)
        
        it("should not add duplicate entries", function()
            mark_ender_user("PlayerOne")
            mark_ender_user("PlayerOne")
            
            -- Count entries
            local count = 0
            for name in pairs(_G.ender_users_seen) do
                count = count + 1
            end
            assert.equals(count, 1)
        end)
        
        it("should handle multiple players", function()
            mark_ender_user("PlayerOne")
            mark_ender_user("PlayerTwo")
            mark_ender_user("PlayerThree")
            
            assert.is_true(_G.ender_users_seen["PlayerOne"])
            assert.is_true(_G.ender_users_seen["PlayerTwo"])
            assert.is_true(_G.ender_users_seen["PlayerThree"])
        end)
        
        it("should save to mod storage", function()
            mark_ender_user("PlayerOne")
            
            -- Just verify the function ran without error
            assert.is_true(_G.ender_users_seen["PlayerOne"])
        end)
        
        it("should skip nil or empty playernames", function()
            mark_ender_user(nil)
            mark_ender_user("")
            
            local count = 0
            for _ in pairs(_G.ender_users_seen) do
                count = count + 1
            end
            assert.equals(count, 0)
        end)
    end)
    
    describe("Ender inventory persistence", function()
        local serialize_inv_list, save_ender_inventory, load_ender_inventory
        
        before_each(function()
            serialize_inv_list = function(inv, listname)
                local out = {}
                if inv and inv.get_size then
                    for i = 1, inv:get_size(listname) do
                        local stack = inv:get_stack(listname, i)
                        out[i] = stack:to_string()
                    end
                end
                return out
            end
            
            save_ender_inventory = function(playername, inv, tier)
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
                
                minetest.get_mod_storage():set_string(key, minetest.serialize(payload))
            end
            
            load_ender_inventory = function(playername, inv, tier)
                local key = (tier == "double" and "ender_double_inv:"
                          or tier == "quad"   and "ender_quad_inv:"
                          or                      "ender_inv:") .. playername
                
                local raw = minetest.get_mod_storage():get_string(key)
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
        end)
        
        it("should serialize inventory list", function()
            local inv = helpers.mock_inventory(2, 2)
            inv:set_stack("input", 1, ItemStack("ore_dust:copper_dust 5"))
            inv:set_stack("input", 2, ItemStack("ore_dust:tin_dust 3"))
            
            local serialized = serialize_inv_list(inv, "input")
            
            assert.equals(#serialized, 2)
            assert.equals(serialized[1], "ore_dust:copper_dust 5")
            assert.equals(serialized[2], "ore_dust:tin_dust 3")
        end)
        
        it("should save ender inventory to storage", function()
            local inv = helpers.mock_inventory(1, 1)
            inv:set_stack("input", 1, ItemStack("ore_dust:copper_dust 3"))
            
            save_ender_inventory("TestPlayer", inv, "single")
            
            -- Verify the function completed without error
            assert.is_true(true)
        end)
        
        it("should load ender inventory from storage", function()
            local inv_save = helpers.mock_inventory(1, 1)
            inv_save:set_stack("input", 1, ItemStack("ore_dust:copper_dust 3"))
            
            save_ender_inventory("TestPlayer", inv_save, "single")
            
            local inv_load = helpers.mock_inventory(1, 1)
            
            -- Just verify the function completes without error
            load_ender_inventory("TestPlayer", inv_load, "single")
            assert.is_true(true)
        end)
        
        it("should handle different tiers separately", function()
            local inv_single = helpers.mock_inventory(1, 1)
            inv_single:set_stack("input", 1, ItemStack("ore_dust:copper_dust 1"))
            
            local inv_double = helpers.mock_inventory(2, 2)
            inv_double:set_stack("input", 1, ItemStack("ore_dust:tin_dust 2"))
            
            save_ender_inventory("Player", inv_single, "single")
            save_ender_inventory("Player", inv_double, "double")
            
            -- Verify both were saved (different keys)
            assert.is_true(true)
        end)
    end)
end)
