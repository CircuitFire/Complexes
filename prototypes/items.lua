
local function gen_icon(img)
    return {
        {
            icon = img,
            icon_size = 64,
        },
        {
            icon = "__base__/graphics/icons/assembling-machine-3.png",
            icon_size = 64,
            scale = 0.25,
            shift = {-10, -10}
        },
    }
end

local function gen_item(name, icon)
    return {
        type = "item",
        name = name,
        icon_size = 64,
        icons = gen_icon(icon),
        subgroup = "intermediate-product",
        order = "b[" .. name.. "]",
        stack_size = 100
    }
end

data:extend({
    gen_item("complex-structure", "__base__/graphics/icons/low-density-structure.png"),
    gen_item("complex-power", "__base__/graphics/icons/substation.png"),
    gen_item("complex-item-logistics", "__base__/graphics/icons/express-underground-belt.png"),
    gen_item("complex-fluid-logistics", "__base__/graphics/icons/pump.png"),
    gen_item("complex-heat-logistics", "__base__/graphics/icons/heat-pipe.png"),
})

local function gen_recipe(name, inputs)
    return {
        type = "recipe",
        name = name,
        enabled = true,
        subgroup = "complexAssembler",
        energy_required=1,
        ingredients = inputs,
        results = {{
            amount = 1,
            name = name,
            type = "item"
        }},
    }
end

data:extend({
    gen_recipe(
        "complex-structure",
        {
            {
                amount = 100,
                name = "concrete",
                type = "item"
            },
            {
                amount = 100,
                name = "steel-plate",
                type = "item"
            },
        }
    ),
    gen_recipe(
        "complex-power",
        {
            {
                amount = 1,
                name = "substation",
                type = "item"
            },
        }
    ),
    gen_recipe(
        "complex-item-logistics",
        {
            {
                amount = 10,
                name = "express-transport-belt",
                type = "item"
            },
            {
                amount = 1,
                name = "express-splitter",
                type = "item"
            },
            {
                amount = 2,
                name = "express-underground-belt",
                type = "item"
            },
            {
                amount = 6,
                name = "stack-filter-inserter",
                type = "item"
            },
        }
    ),
    gen_recipe(
        "complex-fluid-logistics",
        {
            {
                amount = 1,
                name = "pump",
                type = "item"
            },
            {
                amount = 50,
                name = "pipe",
                type = "item"
            },
            {
                amount = 10,
                name = "pipe-to-ground",
                type = "item"
            },
        }
    ),
    gen_recipe(
        "complex-heat-logistics",
        {
            {
                amount = 10,
                name = "heat-pipe",
                type = "item"
            },
        }
    ),
})