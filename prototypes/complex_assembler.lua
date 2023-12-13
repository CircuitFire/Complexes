require("__base__.prototypes.entity.pipecovers")
require("complex_gen")

local entity = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
local name = "complexAssembler"

---------------------------------------------  Entity  ---------------------------------------------
entity.type = "assembling-machine"
entity.name = name
entity.max_health = 2640
entity.minable = {
    mining_time = 1,
    result = name
}
entity.energy_usage = "3045000W"
entity.energy_source = {
    emissions_per_minute = 10,
    drain = "101500W",
    type = "electric",
    usage_priority = "secondary-input"
}
entity.module_specification = nil
entity.allowed_effects = nil
entity.crafting_categories = {name}
entity.crafting_speed = 1
entity.fast_replaceable_group = nil
entity.next_upgrade = nil
entity.fluid_boxes = {
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {-3, -5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {-1, -5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {1, -5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {3, -5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {-3, 5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {-1, 5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {1, 5},
        }
    },
    Complex_Gen.pipe_connection{
        type = "input",
        base_area = 10,
        connections = {
            {3, 5},
        }
    },
}

Complex_Gen.scale_graphics(entity, {x=9, y=9})
data:extend{entity}

---------------------------------------------  Item  ---------------------------------------------
data:extend{{
    type = "item",
    name = name,
    place_result = name,
    icon = entity.icon,
    icon_size = 64,
    stack_size = 1,
    subgroup = "complexAssembler",
    order = "a[" .. name .. "]",
}}

---------------------------------------------  Recipe Category  ---------------------------------------------
data:extend{
    {
        type = "recipe-category",
        name = name,
    },
    {
        type = "item-group",
        name = "complex",
        order = "z",
        icon = entity.icon,
        icon_size = 64,
    },
    {
        type = "item-subgroup",
        name = "complexAssembler",
        group = "complex",
        order = "a"
    },
    {
        type = "item-subgroup",
        name = "complex",
        group = "complex",
        order = "b"
    },
    {
        type = "item-subgroup",
        name = "complex-recipes",
        group = "complex",
        order = "c"
    },
}

---------------------------------------------  Complex Recipe  ---------------------------------------------
data:extend{{
    type = "recipe",
    name = name,
    icon = entity.icon,
    icon_size = 64,
    enabled = true,
    energy_required = 10,
    subgroup = "complexAssembler",
    result = name,
    ingredients = {
        {
            amount = 10,
            name = "assembling-machine-3",
        },
        {
            amount = 2,
            name = "roboport",
        },
        {
            amount = 50,
            name = "construction-robot",
        },
        {
            amount = 1,
            name = "complex-structure",
        },
        {
            amount = 1,
            name = "complex-power",
        },
        {
            amount = 2,
            name = "complex-item-logistics",
        },
        {
            amount = 2,
            name = "complex-fluid-logistics",
        }
    }
}}