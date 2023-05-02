require("util")
require("scripts.factory")
require("scripts.recipe")

--[[
complex
    .name
    .time
    .floors
    .graphics
    .pipes[name]
        .in_out      -- "input", "output"
        .passthrough -- optional overrides in_out
        .positions[]
            .side   -- "top", "bottom", "left", "right"
            .offset -- starts at top left increases going down/right
    .factories[name]
    .sub_recipes[]
        .name
        .time

recipe
    .heat
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
        ["boiler"]             = true,
        ["reactor"]            = true,
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

Complex = {}

function Complex.__index(table, index)
    return getmetatable(table)[index]
end

function Complex:from_blueprint(entities)
    local new = {
        name = "",
        time = 1,
        floors = 1,
        pipes = {},
        factories = {},
        sub_recipes = {},
    }
    setmetatable(new, self)

    for index, entity in pairs(filter_entities(entities)) do
        local id = Factory.entity_id(entity)
        if new.factories[id] == nil then
            new.factories[id] = Factory:from_entity(entity)
        else
            new.factories[id]:inc_count(1)
        end
    end

    if new:needs_fuel() then
        new:new_recipe()
    end

    return new
end

function Complex:get_recipe(index, overwrite_time)
    local recipe = Recipe:new()

    local later = {}
    local time = self.time
    if index ~= nil then time = self.sub_recipes[index].time end
    if overwrite_time then time = overwrite_time end
    
    for name, factory in pairs(self.factories) do
        local match = factory.match

        if match ~= nil then
            if later[match.level] == nil then later[match.level] = {} end
            table.insert(later[match.level], factory)
        else
            local temp = factory:get_recipe(time)
            -- game.print("here: " .. serpent.block(temp.input))
            recipe:merge(temp)
        end

        if index ~= nil then 
            for _, fuel in pairs(factory:get_fuel_list(time, index)) do
                if later[fuel.match.level] == nil then later[fuel.match.level] = {} end
                table.insert(later[fuel.match.level], fuel)
            end
        end
    end

    for _, level in pairs(later) do
        for _, factory in pairs(level) do
            local match = factory.match
            local item = recipe:get_clean(Recipe.flip(match.in_out), match.get)

            if factory:match_speed(item, time) > 0 then
                local temp = factory:get_recipe(time)
                -- game.print("test: " .. serpent.block(temp))
                recipe:merge(temp)
            end
        end
    end

    return recipe
end

function Complex:get_recipes()
    if self:multiple_recipes() then
        local list = {}

        for index, _ in pairs(self.sub_recipes) do
            table.insert(list, {index=index, recipe=self:get_recipe(index):clean()})
        end

        return list
    else
        return {{recipe=self:get_recipe():clean()}}
    end
end

function Complex:get_recipe_data(index)
    if index == nil then return {name=self.name.." recipe", time=self.time} end
    return {name=self.sub_recipes[index].name, time=self.sub_recipes[index].time}
end

function Complex:get_fluids()
    local fluids = {
        input = {},
        output = {},
        fuel = {},
        max_fuels = 0
    }

    local recipe = self:get_recipe():clean()

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
                local recipe_fuels = 0

                for _, fuel in pairs(level) do
                    if fluids.input[fuel.prototype.name] == nil then
                        fluids.fuel[fuel.prototype.name] = true
                    else
                        recipe_fuels = 1 + recipe_fuels
                    end
                end

                if fluids.max_fuels > recipe_fuels then fluids.max_fuels = recipe_fuels end
            end
        end
    end

    return fluids
end

local function init_count(fluids, ranked)
    for name, _ in pairs(fluids) do
        table.insert(ranked, {name=name, amount=0})
    end
end

local function check_bigger(ranked, recipe, in_out)
    for index, data in pairs(ranked) do
        if data.amount < recipe:amount(in_out, data.name) then data.amount = recipe:amount(in_out, data.name) end
    end
end

local function sort_func(a, b)
    return a.amount > b.amount
end

function Complex:rank_fluids()
    local fluids = self:get_fluids()
    local ranked = {
        input = {},
        output = {},
        fuel = {},
        max_fuels = fluids.max_fuels
    }

    init_count(fluids.input, ranked.input)
    init_count(fluids.output, ranked.output)
    init_count(fluids.fuel, ranked.fuel)

    local recipes = self:get_recipes()

    check_bigger(ranked.output, recipes[1].recipe, "output")
    for _, recipe in pairs(recipes) do
        check_bigger(ranked.input, recipe.recipe, "input")
        check_bigger(ranked.fuel, recipe.recipe, "input")
    end

    table.sort(ranked.input, sort_func)
    table.sort(ranked.output, sort_func)
    table.sort(ranked.fuel, sort_func)

    return ranked
end

function Complex:find_free_place(side)
    local filled = {}
    local largest = 0

    for _, pipe in pairs(self.pipes) do
        for _, position in pairs(pipe.positions) do
            if position.side == side then
                filled[position.offset] = true
                if position.offset > largest then largest = position.offset end
            end
        end
    end

    if table_size(filled) == largest then
        return largest + 1
    end

    for i=0, largest - 1 do
        if filled[i] == nil then
            return i
        end
    end
end

function Complex:init_pipe_config(fluid, in_out)
    local config = self.pipes[fluid]
    if config ~= nil then return end

    local side
    if in_out == "input" then
        side = "top"
    else
        side = "bottom"
    end

    local offset = self:find_free_place(side)

    self.pipes[fluid] = {
        in_out = in_out,
        positions = {
            {
                side = side,
                offset = offset,
            }
        },
    }
end

function Complex:add_connection(fluid, index)
    local positions = self.pipes[fluid].positions
    if index == nil then index = #positions end
    local side = positions[index].side
    local offset = self:find_free_place(side)

    table.insert(positions, {side=side, offset=offset})
end

function Complex:remove_factory(factory)
    self.factories[factory] = nil

    if self:needs_fuel() == false then
        self.sub_recipes = {}
    end
end

function Complex:remove_connection(fluid, index)
    local positions = self.pipes[fluid].positions
    table.remove(positions, index)
end

function Complex:fuel_factories()
    local list = {}

    for name, factory in pairs(self.factories) do
        if factory:needs_fuel() then
            list[name] = factory
        end
    end

    return list
end

function Complex:needs_fuel()
    for name, factory in pairs(self.factories) do
        if factory:needs_fuel() then
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
        area = 0,
        min = {x = 3, y = 3},
    }

    for factory_name, factory in pairs(self.factories) do
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

        size.area = size.area + (factories[name].area * factory.count)
    end

    local x = math.ceil(math.sqrt(size.area / self.floors))
    size.x = x
    size.y = x

    return size
end

function Complex:new_recipe()
    local new = {
        name = self.name .. " recipe " .. #self.sub_recipes + 1,
        time = 1,
    }

    table.insert(self.sub_recipes, new)
end

function Complex:remove_recipe(index)
    for _, factory in pairs(self.factories) do
        factory:remove_fuel(index)
    end

    table.remove(self.sub_recipes, index)
end

function Complex:logistics()
    local log = self:get_recipe(nil, 1):logistics()

    for index, _ in pairs(self.sub_recipes) do
        local new = self:get_recipe(index, 1):logistics()
        if log.external.item  < new.external.item  then log.external.item  = new.external.item end
        if log.external.fluid < new.external.fluid then log.external.fluid = new.external.fluid end
        if log.external.heat < new.external.heat   then log.external.heat = new.external.heat end
        if log.internal.item  < new.internal.item  then log.internal.item  = new.internal.item end
        if log.internal.fluid < new.internal.fluid then log.internal.fluid = new.internal.fluid end
        if log.internal.heat < new.internal.heat   then log.internal.heat = new.internal.heat end
    end

    return log
end

function Complex:craft()
    local craft = {}
    local needs_fuel = false

    for factory_name, factory in pairs(self.factories) do
        if factory:needs_fuel() then needs_fuel = true end

        for name, data in pairs(factory:get_craft()) do
            Helper.add_item_to_list(craft, name, data)
        end
    end

    local size = self:size()
    local logistics = self:logistics()
    -- game.print(serpent.block(logistics))

    local structure = settings.global["complex-structure"].value
    local multiplier = settings.global["complex-structure-floor-multiplier"].value
    local power = settings.global["complex-power"].value
    local iil = settings.global["complex-internal-item-logistics"].value
    local ifl = settings.global["complex-internal-fluid-logistics"].value
    local eil = settings.global["complex-external-item-logistics"].value
    local efl = settings.global["complex-external-fluid-logistics"].value

    local hil = settings.global["complex-external-fluid-logistics"].value * 1000000

    -- game.print("internal item:" .. tostring(logistics.internal.item / iil))
    -- game.print("internal fluid:" .. tostring(logistics.internal.fluid / ifl))
    -- game.print("external item:" .. tostring(logistics.external.item / eil))
    -- game.print("external fluid:" .. tostring(logistics.external.fluid / efl))

    Helper.add_item_to_list(craft, "complex-structure", {type="item", amount=math.ceil((size.area / structure) * ((multiplier * self.floors) - (multiplier - 1)))})
    Helper.add_item_to_list(craft, "complex-power", {type="item", amount=math.ceil(size.area / power)})
    Helper.add_item_to_list(craft, "complex-item-logistics", {type="item", amount=math.ceil((logistics.internal.item / iil) + (logistics.external.item / eil))})
    Helper.add_item_to_list(craft, "complex-fluid-logistics", {type="item", amount=math.ceil((logistics.internal.fluid / ifl) + (logistics.external.fluid / efl))})
    Helper.add_item_to_list(craft, "complex-heat-logistics", {type="item", amount=math.ceil((logistics.internal.heat + logistics.internal.heat)/ hil)})

    return craft
end

function Complex:power()
    local power = {
        usage = 0,
        drain = 0
    }

    for _, factory in pairs(self.factories) do
        local new = factory:get_power()
        power.usage = power.usage + new.usage
        power.drain = power.drain + new.drain
    end

    return power
end

function Complex:pollution(level)
    local total = 0
    local time = self.time
    if level ~= nil then time = self.sub_recipes[level].time end

    for _, factory in pairs(self.factories) do
        total = total + factory:get_pollution(time, level)
    end

    return total
end

local function heat_check(recipe)
    if (recipe.input["complex-heat"] ~= nil and recipe.input["complex-heat"].amount > 0) or
       (recipe.output["complex-heat"] ~= nil and recipe.output["complex-heat"].amount > 0) then 
        return true, {"complex-heat"}
    end
end

local function item_check(recipe)
    for name, data in pairs(recipe.input) do
        if data.type == "item" and data.amount ~= math.ceil(data.amount) then
            return true, {"complex-item-fraction", "input", name}
        end
    end
    for name, data in pairs(recipe.output) do
        if data.type == "item" and data.amount ~= math.ceil(data.amount) then
            return true, {"complex-item-fraction", "output", name}
        end
    end
end

function Complex:check_error()
    if self.name == nil or self.name == "" then return true, {"complex-name"} end

    if self.graphics == nil then return true, {"complex-graphics"} end

    local recipe = self:get_recipe():clean()
    local er, error = heat_check(recipe)
    if er then return er, error end

    local er, error = item_check(recipe)
    if er then return er, error end

    if self:multiple_recipes() then
        local fuel = self:fuel_factories()

        for index, _ in pairs(self.sub_recipes) do
            local recipe = self:get_recipe(index):clean()
            local er, error = heat_check(recipe)
            if er then return er, error end
            
            local er, error = item_check(recipe)
            if er then return er, error end

            for name, factory in pairs(fuel) do
                if factory.current_fuel ~= 0 then
                    return true, {"complex-fuel-missing", self.sub_recipes[index].name, name}
                end
            end
        end
    end
end

function Complex:internal_name()
    return "complex-" .. string.gsub(self.name, " ", "-")
end