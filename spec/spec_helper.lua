-- spec/spec_helper.lua
-- Comprehensive Minetest API mocks for unit testing

local function setup_minetest_mocks()
    _G.minetest = _G.minetest or {}
    
    -- Item registries
    _G.minetest.registered_items = {}
    _G.minetest.registered_craftitems = {}
    _G.minetest.registered_nodes = {}
    _G.minetest.registered_recipes = {}
    _G.minetest.registered_tools = {}
    
    -- Mock get_item_group(itemname, group) -> strength
    function _G.minetest.get_item_group(itemname, group)
        if not itemname then return 0 end
        local def = _G.minetest.registered_items[itemname]
        if def and def.groups and def.groups[group] then
            return def.groups[group]
        end
        return 0
    end
    
    -- Mock override_item(itemname, def)
    function _G.minetest.override_item(itemname, def)
        if not itemname or not _G.minetest.registered_items[itemname] then
            return
        end
        
        local item_def = _G.minetest.registered_items[itemname]
        for k, v in pairs(def) do
            if k == "groups" then
                -- Merge groups
                item_def.groups = item_def.groups or {}
                for gname, gval in pairs(v) do
                    item_def.groups[gname] = gval
                end
            else
                item_def[k] = v
            end
        end
    end
    
    -- Mock ItemStack class
    function _G.ItemStack(str)
        local obj = {
            name = "air",
            count = 0,
            _string = str,
        }
        
        if str and str ~= "" then
            -- Parse "itemname count" format
            local name, count = str:match("^([^ ]+) (%d+)$")
            if name then
                obj.name = name
                obj.count = tonumber(count) or 1
            else
                -- Just itemname
                obj.name = str
                obj.count = 1
            end
        end
        
        function obj:get_name()
            return self.name
        end
        
        function obj:get_count()
            return self.count
        end
        
        function obj:set_count(count)
            self.count = math.max(0, count or 0)
        end
        
        function obj:is_empty()
            return self.name == "air" or self.count == 0
        end
        
        function obj:to_string()
            if self:is_empty() then return "" end
            return self.name .. " " .. self.count
        end
        
        return obj
    end
    
    -- Mock serialize/deserialize (simple Lua table serialization)
    local function simple_serialize(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                if type(v) == "table" then
                    -- Nested tables become comma-separated strings
                    local nested_parts = {}
                    for i, item in ipairs(v) do
                        table.insert(nested_parts, tostring(item))
                    end
                    table.insert(parts, k .. "=" .. table.concat(nested_parts, "|"))
                else
                    table.insert(parts, k .. "=" .. tostring(v))
                end
            end
            return table.concat(parts, "\n")
        end
        return tostring(obj)
    end
    
    local function simple_deserialize(str)
        if not str or str == "" then return nil end
        local result = {}
        for line in str:gmatch("[^\n]+") do
            local k, v = line:match("^(.+)=(.+)$")
            if k and v then
                if v:find("|") then
                    -- Was a nested table
                    local parts = {}
                    for part in v:gmatch("[^|]+") do
                        table.insert(parts, part)
                    end
                    result[k] = parts
                else
                    result[k] = v
                end
            end
        end
        return result
    end
    
    function _G.minetest.serialize(obj)
        return simple_serialize(obj)
    end
    
    function _G.minetest.deserialize(str)
        return simple_deserialize(str)
    end
    
    -- Mock logging
    function _G.minetest.log(level, msg)
        if level then
            print("[" .. level .. "] " .. msg)
        else
            print(msg)
        end
    end
    
    -- Mock pos_to_string
    function _G.minetest.pos_to_string(pos)
        if not pos then return "(0,0,0)" end
        return "(" .. (pos.x or 0) .. "," .. (pos.y or 0) .. "," .. (pos.z or 0) .. ")"
    end
    
    -- Mock get_node (uses test_world)
    function _G.minetest.get_node(pos)
        if not _G.test_world then _G.test_world = {} end
        local key = minetest.pos_to_string(pos)
        return _G.test_world[key] or {name = "air"}
    end
    
    -- Mock mod storage (persistent data)
    local mod_storage_data = {}
    function _G.minetest.get_mod_storage()
        return {
            set_string = function(key, value)
                mod_storage_data[key] = value
            end,
            get_string = function(key)
                return mod_storage_data[key] or ""
            end,
            set_int = function(key, value)
                mod_storage_data[key] = tostring(value)
            end,
            get_int = function(key)
                local val = mod_storage_data[key]
                return val and tonumber(val) or 0
            end,
            clear = function()
                for k in pairs(mod_storage_data) do
                    mod_storage_data[k] = nil
                end
            end,
        }
    end
    
    -- Mock register_on_mods_loaded callbacks
    _G.minetest._mod_callbacks = {}
    function _G.minetest.register_on_mods_loaded(callback)
        if type(callback) == "function" then
            table.insert(_G.minetest._mod_callbacks, callback)
        end
    end
    
    -- Helper: trigger callbacks for testing
    function _G.minetest.trigger_mods_loaded()
        for _, cb in ipairs(_G.minetest._mod_callbacks) do
            cb()
        end
    end
    
    -- Mock register_node
    function _G.minetest.register_node(name, def)
        if not name or name == "" then return end
        def = def or {}
        _G.minetest.registered_nodes[name] = def
        _G.minetest.registered_items[name] = def
    end
    
    -- Mock register_craftitem
    function _G.minetest.register_craftitem(name, def)
        if not name or name == "" then return end
        def = def or {}
        _G.minetest.registered_craftitems[name] = def
        _G.minetest.registered_items[name] = def
    end
    
    -- Mock register_craft
    function _G.minetest.register_craft(def)
        if def and def.output then
            table.insert(_G.minetest.registered_recipes, def)
        end
    end
end

-- Helper functions exposed for tests
local function reset_test_env()
    _G.minetest.registered_items = {}
    _G.minetest.registered_craftitems = {}
    _G.minetest.registered_nodes = {}
    _G.minetest.registered_recipes = {}
    _G.minetest._mod_callbacks = {}
    _G.minetest.get_mod_storage():clear()
    _G.test_world = {}
    _G.lava_crucible = nil
end

local function register_test_item(itemname, def)
    def = def or {
        description = itemname,
        groups = {},
    }
    _G.minetest.registered_items[itemname] = def
    return def
end

local function add_lava_at(pos)
    if not _G.test_world then _G.test_world = {} end
    local key = minetest.pos_to_string(pos)
    _G.test_world[key] = {name = "default:lava_source"}
end

local function add_node_at(pos, nodename)
    if not _G.test_world then _G.test_world = {} end
    local key = minetest.pos_to_string(pos)
    _G.test_world[key] = {name = nodename}
end

-- Mock inventory for testing
local function mock_inventory(input_slots, output_slots)
    local inv = {
        input = {},
        soil_output = {},
        dust_output = {},
    }
    
    -- Initialize input slots
    for i = 1, (input_slots or 1) do
        inv.input[i] = ItemStack("")
    end
    
    -- Initialize output slots
    for i = 1, (output_slots or 1) do
        inv.soil_output[i] = ItemStack("")
        inv.dust_output[i] = ItemStack("")
    end
    
    function inv:get_size(listname)
        if listname == "input" then
            return #self.input
        elseif listname == "soil_output" then
            return #self.soil_output
        elseif listname == "dust_output" then
            return #self.dust_output
        end
        return 0
    end
    
    function inv:get_stack(listname, i)
        if listname == "input" then
            return self.input[i] or ItemStack("")
        elseif listname == "soil_output" then
            return self.soil_output[i] or ItemStack("")
        elseif listname == "dust_output" then
            return self.dust_output[i] or ItemStack("")
        end
        return ItemStack("")
    end
    
    function inv:set_stack(listname, i, stack)
        if listname == "input" then
            self.input[i] = stack
        elseif listname == "soil_output" then
            self.soil_output[i] = stack
        elseif listname == "dust_output" then
            self.dust_output[i] = stack
        end
    end
    
    function inv:set_size(listname, size)
        if listname == "input" then
            while #self.input < size do
                table.insert(self.input, ItemStack(""))
            end
            while #self.input > size do
                table.remove(self.input)
            end
        elseif listname == "soil_output" then
            while #self.soil_output < size do
                table.insert(self.soil_output, ItemStack(""))
            end
            while #self.soil_output > size do
                table.remove(self.soil_output)
            end
        elseif listname == "dust_output" then
            while #self.dust_output < size do
                table.insert(self.dust_output, ItemStack(""))
            end
            while #self.dust_output > size do
                table.remove(self.dust_output)
            end
        end
    end
    
    return inv
end

-- Setup on module load
setup_minetest_mocks()

-- Export helpers
return {
    reset = reset_test_env,
    register_item = register_test_item,
    add_lava_at = add_lava_at,
    add_node_at = add_node_at,
    mock_inventory = mock_inventory,
}
