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


