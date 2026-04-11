-- Define copper dust
minetest.register_craftitem("minetest_lava_crucible:copper_dust", {
    description = "Copper dust",
    groups = {mineral_dust=1}
})

-- Define the recipe to create copper dust
minetest.register_craft({
    type = "shapeless",
    output = "minetest_lava_crucible:copper_dust",
    recipe = {"default:copper_lump"}
})

-- Define a recipe to allow copper ingots to be melted back into copper lumps
minetest.register_craft({
    type = "cooking",
    output = "default:copper_lump 1",
    recipe = "default:copper_ingot",
    cooktime = 1
})

-- Optional moreores support
if minetest.get_modpath("moreores") then
    -- Tin dust
    minetest.register_craftitem("minetest_lava_crucible:tin_dust", {
        description = "Tin dust",
        groups = {mineral_dust=1}
    })
    minetest.register_craft({
        type = "shapeless",
        output = "minetest_lava_crucible:tin_dust",
        recipe = {"moreores:tin_lump"}
    })
    minetest.register_craft({
        type = "cooking",
        output = "moreores:tin_lump 1",
        recipe = "moreores:tin_ingot",
        cooktime = 1
    })

    -- Silver dust
    minetest.register_craftitem("minetest_lava_crucible:silver_dust", {
        description = "Silver dust",
        groups = {mineral_dust=1}
    })
    minetest.register_craft({
        type = "shapeless",
        output = "minetest_lava_crucible:silver_dust",
        recipe = {"moreores:silver_lump"}
    })
    minetest.register_craft({
        type = "cooking",
        output = "moreores:silver_lump 1",
        recipe = "moreores:silver_ingot",
        cooktime = 1
    })

    -- Mithril dust
    minetest.register_craftitem("minetest_lava_crucible:mithril_dust", {
        description = "Mithril dust",
        groups = {mineral_dust=1}
    })
    minetest.register_craft({
        type = "shapeless",
        output = "minetest_lava_crucible:mithril_dust",
        recipe = {"moreores:mithril_lump"}
    })
    minetest.register_craft({
        type = "cooking",
        output = "moreores:mithril_lump 1",
        recipe = "moreores:mithril_ingot",
        cooktime = 1
    })
end


