
---------------------------------------------  Entities  ---------------------------------------------
local entity_template = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-3"])
entity_template.fluid_boxes = nil
entity_template.crafting_categories = nil
entity_template.module_specification = nil
entity_template.fast_replaceable_group = nil
entity_template.crafting_speed = 1

local entity_functions = {
    name = function(new, input)
        new.name = input
        new.crafting_categories = {input}
        new.minable = {result = input, mining_time = 1}
    end,
    size = function(new, input)
        local x = input[1]/2
        local y = input[2]/2

        local box = {
            {-x, -y},
            {x, y}
        }

        local scale = new.animation.layers[1].scale
        if scale == nil then scale = 1 end
        local hr_scale = new.animation.layers[1].hr_version.scale
        if hr_scale == nil then hr_scale = 1 end

        local new_scale = (input[1]/3) * scale
        local new_hr_scale = (input[1]/3) * hr_scale

        new.drawing_box = box
        new.selection_box = box
        new.collision_box = {
            {0.5-x, 0.5-y},
            {x-0.5, y-0.5}
        }
        new.animation.layers[1].scale = new_scale
        new.animation.layers[2].scale = new_scale
        new.animation.layers[1].hr_version.scale = new_hr_scale
        new.animation.layers[2].hr_version.scale = new_hr_scale
    end,
    power = function(new, input)

    end,
}

---------------------------------------------  Items  ---------------------------------------------
local item_template = table.deepcopy(data.raw["item"]["assembling-machine-3"])

local item_functions = {
    name = function(new, input)
        new.name = input
        new.place_result = input
    end
}

---------------------------------------------  Recipes  ---------------------------------------------
local recipe_template = table.deepcopy(data.raw["recipe"]["assembling-machine-3"])
recipe_template.energy_required = 1
recipe_template.enabled = true
recipe_template.category = nil
recipe_template.ingredients = {}
recipe_template.results = {}

local function add_to_list(new, input, in_out)
    if input[in_out] ~= nil then
        for _, data in pairs(input[in_out]) do
            table.insert(new[in_out], {type = data.type, name = data.name, amount = data.amount})
        end
    end
end

local recipe_functions = {
    complex = function(new, input)
        new.name = input.name
        if input.time ~= nil then
            new.energy_required = input.time
        end
        new.category = "complexAssembler"
        new.results = {
            {type = "item", name = input.name, amount = 1},
        }
        add_to_list(new, input, "ingredients")
    end,
    recipe = function(new, input)
        new.name = input.name
        if input.time ~= nil then
            new.energy_required = input.time
        end
        new.category = input.category
        add_to_list(new, input, "results")
        add_to_list(new, input, "ingredients")
    end
}

---------------------------------------------  Recipe Categories  ---------------------------------------------
local recipe_category_template = {type = "recipe-category"}

local recipe_category_functions = {
    name = function(new, input)
        new.name = input
    end
}


local function generate(template, functions, input)
    local new = table.deepcopy(template)
    local basic = input.basic
    input.basic = nil

    for index, data in pairs(input) do
        if functions[index] ~= nil then
            functions[index](new, data)
        end
    end

    if basic ~= nil then
        for index, data in pairs(basic) do
            new[index] = data
        end
    end

    return new
end


---------------------------------------------  Public Functions  ---------------------------------------------
Generate = {}

function Generate.entity(input)
    return generate(entity_template, entity_functions, input)
end

function Generate.item(input)
    return generate(item_template, item_functions, input)
end

function Generate.recipe(input)
    return generate(recipe_template, recipe_functions, input)
end

function Generate.recipe_category(input)
    return generate(recipe_category_template, recipe_category_functions, input)
end