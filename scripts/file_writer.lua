local function new_file(player, file, data)
    game.write_file(file, data, false, player.index)
end

local function append_file(player, file, data)
    game.write_file(file, data, true, player.index)
end

local function complex_items(recipe, in_out)
    local output = ""

    for name, data in pairs(recipe[in_out]) do
        output = output .. "\n                " .. string.format(
            [[{type = "%s", name = "%s", amount = "%s"},]],
            data.type,
            name,
            data.amount
        )
    end

    return output
end

local function complex_recipes(complex)
    local output = ""

    for _, data in pairs(complex:get_recipes()) do
        output = output .. "\n    " .. string.format(
[[Generate.recipe({
        recipe = {
            name = "%s",
            category = name,
            time = %s,
            ingredients = {%s
            },
            results = {%s
            }
        }
    }),
]],
            data.name,
            data.time,
            complex_items(data.recipe, "inputs"),
            complex_items(data.recipe, "outputs")
        )
    end

    return output
end

local function write_local(player, complexes, path, filename)
    local items = ""
    local recipes = ""

    for _, complex in pairs(complexes) do
        items = string.format([[%s\n%s=%s]], items, complex:internal_name(), complex.name)
        recipes = string.format([[%s\n%s=%s]], recipes, complex:internal_name(), complex.name)
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

local function write_complex(player, complex, path)
    if path == nil then
        path = "complexes/"
        write_local(player, {complex}, path, complex.name)
    end
    local name = complex:internal_name()
    local size = complex:size()

    local craft = ""

    for name, data in pairs() do
        craft = string.format([[%s\n{type = "%s", name = "%s", amount = %s},]], craft, data.type, name, data.amount)
    end

    local write = string.format(
[[
local name = "%s"

data:extend({
    Generate.entity({
        name = name,
        size = { %s, %s },
    }),
    Generate.item({
        name = name,
    }),
    Generate.recipe({
        complex = {
            name = name,
            time = 10,
            ingredients = {%s
            },
        },
    }),
    Generate.recipe_category({
        name = name,
    }),
    -- Complex Recipes%s
})
]],
        name,
        size.dimensions.x,
        size.dimensions.y,
        complex:craft(),
        complex_recipes(complex)
    )

    new_file(player, path .. complex:internal_name() .. ".lua", write)
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
        player.name,
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
        "require(\"__Complexes__.complex_gen\")\n\n--Complexes--"
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