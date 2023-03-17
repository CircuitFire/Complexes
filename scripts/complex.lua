require("util")
require("scripts.factory")

--[[
complex
    .name
    .time
    .fluid_pips[name]
        .in_out     -- "input", "output"
        .positions[]
            .side   -- "top", "bottom", "left", "right"
            .number -- starts at top left increases going down/right
    .factories[name]
    .sub_recipes[]
        .name
        .time

recipe
    .input[name]
        .type
        .amount
    .output[name]
        .type
        .amount
]]

local function filter_entities(entities)
    local proto_filter = {
        ["assembling-machine"] = true,
        ["furnace"]            = true,
    }
    
    local list = {}

    for index, entity in pairs(entities) do
        if entity.prototype.type == "entity-ghost" and proto_filter[entity.ghost_type] then
            table.insert(list, entity)
        elseif proto_filter[entity.prototype.type] then
            table.insert(list, entity)
        end
    end

    return list
end

local function clean_recipe(recipe)
    local remove = {}

    for name, data in pairs(recipe.output) do
        local amount = data.amount
        if recipe.input[name] ~= nil then
            if recipe.input[name].amount < amount then
                recipe.output[name].amount = amount - recipe.input[name].amount
                recipe.input[name] = nil
            elseif recipe.input[name].amount > amount then
                recipe.input[name].amount = recipe.input[name].amount - amount
                remove[name] = true
            else
                recipe.input[name] = nil
                remove[name] = true
            end
        end
    end

    for name, _ in pairs(remove) do
        recipe.output[name] = nil
    end
end

Complex = {
    name = "",
    time = 1,
    factories = {},
    sub_recipes = {},
}

function Complex:from_blueprint(entities)
    local new = table.deepcopy(self)

    for index, entity in pairs(filter_entities(entities)) do
        local id = Factory.entity_id(entity)
        if new.factories[id] == nil then
            new.factories[id] = Factory:from_entity(entity)
        else
            new.factories[id]:inc_count(1)
        end
    end

    return new
end

function Complex:fancy_names()
    local data = {
        names = {},
        indexes = {},
    }

    for factory_name, factory in pairs(self.factories) do
        local recipe_formatted
        if factory.recipe.name == "nil" then
            recipe_formatted = "[virtual-signal=signal-red]"
        else
            recipe_formatted = "[recipe=" .. factory.recipe.name .. "]"
        end

        local name = string.format("[entity=%s] -> %s", factory.prototype.name, recipe_formatted)

        if table_size(factory.modules) ~= 0 then
            name = name .. " ("
            for module, count in pairs(factory.modules) do
                name = name .. " [img=item." .. module .. "]: " .. count
            end
            name = name .. " )"
        end
        
        table.insert(data.names, name)
        table.insert(data.indexes, factory_name)
    end

    return data
end

function Complex:get_recipe(index)
    local recipe = {
        input = {},
        output = {},
    }

    local later = {}
    
    for name, factory in pairs(self.factories) do
        local match = factory.match

        if match ~= nil then
            if later[match.level] == nil then later[match.level] = {} end
            table.insert(later[match.level], factory)
        else
            Helper.merge_recipes(recipe, factory:get_recipe(self.time))
        end

        if index ~= nil then 
            for _, fuel in pairs(factory:get_fuel_list(self.time, index)) do
                table.insert(later[fuel.match.level], fuel)
            end
        end
    end
    
    clean_recipe(recipe)

    local flip = {
        input = "output",
        output = "input"
    }

    for _, level in pairs(later) do
        for _, factory in pairs(level) do
            local match = factory.match
            -- game.print("test: " .. serpent.block(match, {maxlevel=2}))
            local type = flip[match.type]
            local item = recipe[type][match.item_name]

            if factory:match_speed(item, self.time) > 0 then
                Helper.merge_recipes(recipe, factory:get_recipe(self.time))
                clean_recipe(recipe)
            end
        end
    end

    return recipe
end

function Complex:get_fluids()
    local fluids = {
        input = {},
        output = {},
    }

    local recipe = self:get_recipe()

    for name, item in pairs(recipe.input) do
        if item.type == "fluid" then
            fluids.input[name] = true
        end
    end
    for name, item in pairs(recipe.output) do
        if item.type == "fluid" then
            fluids.output[name] = true
        end
    end

    for _, factory in pairs(self.factories) do
        if factory.power.type == "fluid" and factory.power.fuels ~= nil then
            for _, level in pairs(factory.power.fuels) do
                for _, fuel in pairs(level) do
                    fluids.input[fuel.prototype.name] = true
                end
            end
        end
    end

    return fluids
end

function Complex:need_fuels()
    for name, factory in pairs(self.factories) do
        local type = factory.power.type
        if type == "burner" or type == "fluid" then
            return true
        end
    end

    return false
end

function Complex:multiple_recipes()
    return #self.sub_recipes > 0
end

function Complex:size()
    local factories = {}
    local size = {
        tiles = 0,
        min = {x = 3, y = 3},
    }

    for factory_name, factory in pairs(recipe.factories) do
        local name = factory.prototype.name

        if factories[name] == nil then
            factories[name] = factory:get_size()
            if size.min.x < factories[name].x then
                size.min.x = factories[name].x
            end
            if size.min.y < factories[name].y then
                size.min.y = factories[name].y
            end
        end

        size.tiles = size.tiles + (factories[name].tiles * factory.count)
    end

    local d-- = self.dimensions
    if d == nil or (d.x * d.y) < size.tiles or d.x < size.min.x or d.y < size.min.y then
        d = {
            x = math.ceil(math.sqrt(size.tiles))
            y = math.ceil(size.tiles / d.x)
        }
        --self.dimensions = d
    end

    size.dimensions = d

    return size
end

function Complex:new_recipe()
    local factory = {
        name = self.name .. "recipe " .. #self.sub_recipes + 1,
        time = 1,
        factories = {},
    }

    table.insert(self.sub_recipes, factory)
end

function Complex:craft()
    local craft = {}
    local need_fuel = false

    for factory_name, factory in pairs(self.factories) do
        if factory:needs_fuel() then needs_fuel = true end

        for name, data in pairs(factory:get_craft()) do
            Helper.add_item_to_list(craft, name, data)
        end
    end

    if needs_fuel and !self:multiple_recipes() then
        self:new_recipe()
    elseif 
        self.sub_recipes = {}
    end

    return craft
end

function Complex:check_complete()
    if name == nil or name == "" then return false end

    return true
end

function Complex:internal_name()
    return "complex-" .. string.gsub(self.name, " ", "-")
end