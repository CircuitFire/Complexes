local function new_file(player, file, data)
    game.write_file(file, data, false, player)
end

local function append_file(player, file, data)
    game.write_file(file, data, true, player)
end

local function write_local(player, complexes, path, filename)
    local items = ""
    local recipes = ""

    for _, complex in pairs(complexes) do
        items = string.format("%s\n%s=%s", items, complex:internal_name(), complex.name)
        for _, recipe in pairs(complex:get_recipes()) do
            local name = complex:get_recipe_data(recipe.index).name
            recipes = string.format("%s\n%s=%s", recipes, "complex-" .. string.gsub(name, " ", "-"), name)
        end
    end

    local write = string.format(
[[
[item-name]%s

[entity-name]%s

[recipe-name]%s
]],
        items,
        items,
        recipes
    )

    new_file(player, path .. filename .. ".cfg", write)
end

local function gen_pipe_connection(pipe, size, fluid, in_out)
    local width = (size.x / 2) + 0.5
    local hight = (size.y / 2) + 0.5

    local connections = {}

    for _, con in pairs(pipe.positions) do
        local pos
        if con.side == "bottom" then
            pos = {(con.offset) - width, -hight}
        elseif con.side == "top" then
            pos = {(con.offset) - width, hight}
        elseif con.side == "right" then
            pos = {width, (con.offset) - hight}
        else
            pos = {-width, (con.offset) - hight}
        end

        table.insert(connections, pos)
    end

    local passthrough = ""
    local div = 100
    if pipe.passthrough then
        passthrough = "\n    passthrough = true,"
        div = 75
    end

    return string.format(
[[%sComplex_Gen.pipe_connection{
    type = "%s",%s
    base_area = %s,
    connections = %s
},]],
        "\n",
        in_out,
        passthrough,
        (fluid.amount * 2) / div,
        string.gsub(serpent.block(connections, {indent = '    '}), "\n", "\n    ")
    )
end

--wanted this to be like the others but cant because graphics information is not available during run time so it has to be calculated during start up.
local function gen_entity(complex, name, size, pollution, fluids)
    local power = complex:power()
    local power_type = "electric"
    if power.usage == 0 then
        power.usage = 1
        power_type = "void"
    end
    local prototype = game.entity_prototypes[complex.graphics]

    local fluid_boxes = ""

    for _, data in pairs(fluids.input) do
        fluid_boxes = fluid_boxes .. string.gsub(gen_pipe_connection(complex.pipes[data.name], size, data, "input"), "\n", "\n    ")
    end
    for _, data in pairs(fluids.output) do
        fluid_boxes = fluid_boxes .. string.gsub(gen_pipe_connection(complex.pipes[data.name], size, data, "output"), "\n", "\n    ")
    end
    for i = 1, fluids.max_fuels do
        fluid_boxes = fluid_boxes .. string.gsub(gen_pipe_connection(complex.pipes["Fuel Input #"..i], size, fluids.fuel[i], "input"), "\n", "\n    ")
    end

    return string.format(
[[
local entity = table.deepcopy(data.raw["%s"]["%s"])
local name = "%s"

---------------------------------------------  Entity  ---------------------------------------------
entity.type = "assembling-machine"
entity.name = name
entity.max_health = %s
entity.minable = {
    mining_time = 1,
    result = name
}
entity.energy_usage = "%sW"
entity.energy_source = {
    emissions_per_minute = %s,
    drain = "%sW",
    type = "%s",
    usage_priority = "secondary-input"
}
entity.module_specification = nil
entity.allowed_effects = nil
entity.crafting_categories = {name}
entity.crafting_speed = 1
entity.fast_replaceable_group = nil
entity.next_upgrade = nil
entity.fluid_boxes = {%s
}

Complex_Gen.scale_graphics(entity, {x=%s, y=%s})
data:extend{entity}

]],
        prototype.type,
        prototype.name,
        name,
        size.area * 30,
        power.usage,
        pollution,
        power.drain,
        power_type,
        fluid_boxes,
        size.x,
        size.y
    )
end

local function gen_item()
    return string.format(
[[
---------------------------------------------  Item  ---------------------------------------------
data:extend{{
    type = "item",
    name = name,
    place_result = name,
    icon = entity.icon,
    icon_size = 64,
    stack_size = 1,
    subgroup = "complex",
    order = "[" .. name .. "]",
}}

]]
    )
end

local function gen_category()
    return string.format(
[[
---------------------------------------------  Recipe Category  ---------------------------------------------
data:extend{
    {
        type = "recipe-category",
        name = name
    },
    {
        type = "item-subgroup",
        name = name,
        group = "complex",
        order = "c[" .. name .. "]"
    },
}

]]
    )
end

local function gen_recipe(complex)
    local craft = {}
    for name, data in pairs(complex:craft()) do
        if data.amount > 0 then table.insert(craft, {name=name, amount=data.amount, type=data.type}) end
    end

    return string.format(
[[
---------------------------------------------  Complex Recipe  ---------------------------------------------
data:extend{{
    type = "recipe",
    name = name,
    category = "complexAssembler",
    subgroup = name,
    order = "a[" .. name .. "]",
    icon = entity.icon,
    icon_size = 64,
    enabled = true,
    energy_required = 10,
    result = name,
    ingredients = %s
}}

Complex_Gen.update_complex_assembler(name)

]],
        string.gsub(serpent.block(craft, {indent = '    '}), "\n", "\n    ")
    )
end

local function insert_fluid(recipe, list, input)
    for _, fluid in pairs(input) do
        local name = fluid.name
        local fluid = recipe[name]
        if fluid then
            for _, temp in pairs(fluid.temps) do
                local temp = {
                    name=name,
                    amount=temp.amount,
                    type=fluid.type,
                    minimum_temperature=temp.minimum_temperature,
                    maximum_temperature=temp.maximum_temperature,
                    temperature=temp.temperature,
                }

                if temp.temperature == game.fluid_prototypes[name].default_temperature then
                    temp.temperature = nil
                end

                table.insert(list, temp)
            end
        end
    end
end

local function gen_recipes(name, complex, pollution, fluids, graphics)
    local recipes = ""

    for _, recipe in pairs(complex:get_recipes()) do
        local recipe_data = complex:get_recipe_data(recipe.index)
        local recipe = recipe.recipe
        local input = {}
        local output = {}

        --input liquids
        insert_fluid(recipe.input, input, fluids.input)

        --input liquid fuels
        insert_fluid(recipe.input, input, fluids.fuel)

        --output liquids
        insert_fluid(recipe.output, output, fluids.output)


        --rest of inputs
        for name, data in pairs(recipe.input) do
            if data.type == "item" then table.insert(input, {name=name, amount=data.amount}) end
        end
        --rest of outputs
        for name, data in pairs(recipe.output) do
            if data.type == "item" then table.insert(output, {name=name, amount=data.amount}) end
        end

        local icon = "icon = entity.icon"
        if next(recipe.output) ~= nil then
            local largest
            local count = 0
            for name, data in pairs(recipe.output) do
                local amount = recipe:amount("output", name)
                if count < amount then
                    count = amount
                    largest = name
                end
            end
            icon = string.format([[main_product = "%s"]], largest)
        end

        recipes = recipes .. string.format(
[[
    {
        type = "recipe",
        name = "%s",
        category = name,
        subgroup = name,
        order = "b[" .. name .. "]",
        %s,
        icon_size = 64,
        enabled = true,
        energy_required = %s,
        emissions_multiplier = %s,
        ingredients = %s,
        results = %s
    },
]],
            complex:internal_name() .. "-" .. string.gsub(recipe_data.name, " ", "-"),
            icon,
            recipe_data.time,
            complex:pollution(recipe.index) / pollution,
            string.gsub(serpent.block(input, {indent = '    '}), "\n", "\n        "),
            string.gsub(serpent.block(output, {indent = '    '}), "\n", "\n        ")
        )
    end
    
    return string.format(
[[
---------------------------------------------  Recipes  ---------------------------------------------
data:extend{
%s}]],
        recipes
    )
end

local function write_complex(player, complex, path)
    if path == nil then
        path = "complexes/"
        write_local(player, {complex}, path, complex.name)
    end

    local name = complex:internal_name()
    local size = complex:size()
    local pollution = complex:pollution()
    local fluids = complex:rank_fluids()
    
    local file = path .. complex:internal_name() .. ".lua"
    --Entity
    new_file(player, file, gen_entity(complex, name, size, pollution, fluids))
    --Item
    append_file(player, file, gen_item())
    --Recipe Category
    append_file(player, file, gen_category())
    --Recipe
    append_file(player, file, gen_recipe(complex))
    --Complex Recipes
    append_file(player, file, gen_recipes(name, complex, pollution, fluids, graphics))
end

local function info(player, complex_mod)
    local mods = ""

    for name, version in pairs(script.active_mods) do
        if name ~= complex_mod.name then
            mods = mods .. "\n        \"" .. name .. "\","
        end
    end

    return string.format(
[[{
    "name": "%s",
    "version": "0.0.1",
    "factorio_version": "1.1",
    "title": "%s",
    "author": "%s",
    "description": "Adds new complexes.",
    "dependencies": [%s
    ]
}]],
        complex_mod.name,
        complex_mod.name,
        game.get_player(player).name,
        mods:sub(1, -2)
    )
end

local function write_mod(player, complex_mod)
    game.remove_path(complex_mod.name)

    --local
    write_local(player, complex_mod.complexes, complex_mod.name .. "/locale/en/", "locale")

    --data
    new_file(
        player,
        complex_mod.name .. "/data.lua",
        "require(\"__Complexes__.complex_gen\")\nrequire(\"__base__.prototypes.entity.pipecovers\")\n\n--Complexes--"
    )

    --info
    new_file(
        player,
        complex_mod.name .. "/info.json",
        info(player, complex_mod)
    )

    --complexes
    for num, complex in pairs(complex_mod.complexes) do
        write_complex(player, complex, complex_mod.name .. "/complexes/")
        append_file(player, complex_mod.name .. "/data.lua", "\nrequire(\"complexes." .. complex:internal_name() .. "\")")
    end
end

File_Writer = {
    complex = write_complex,
    mod = write_mod,
}