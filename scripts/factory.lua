require("scripts.helper")
require("scripts.fuel")

--[[
factory
    .count
    .current_fuel -- temp value for calculating 
    .match -- optional "tries to match input or output need of the complex"
        .type = "input" (match with available input item), "output" (match with needed output item)
        .item_name
        .item_type
        .level
    .power
        .type = "electric", "item", "fluid", "heat", "none"
        .usage
        .emissions
        .drain           -- only "electric"
        .fuel_categories -- only "item"
        .effectivity     -- only "item", "fluid"
        .burner          -- only "fluid"
        .filter          -- only "fluid"
        .temp            -- only "fluid"
        .fuels[sub_recipe][] -> Fuel -- only "item", "fluid"
    .recipe
        .name
        .time
        .pollution_mod
        .input
        .output
        .catalyst
    .prototype
    .craft
    .modules
    .modifiers
        .clock
        .consumption
        .speed
        .productivity
        .pollution
]]

---------------------------------------------  Helper Functions  ---------------------------------------------
local function calc_modifiers(modules)
    local modifiers = {
        clock = 1,
        consumption = 1,
        speed = 1,
        productivity = 1,
        pollution = 1,
    }

    for module, count in pairs(modules) do
        for effect, data in pairs(game.item_prototypes[module].module_effects) do
            if data.bonus ~= nil then
                modifiers[effect] = modifiers[effect] + (data.bonus * count)
            end
        end
    end

    for mod, amount in pairs(modifiers) do
        if modifiers[mod] < -0.8 then modifiers[mod] = -0.8 end
    end

    return modifiers
end

local function module_list(entity)
    if entity.prototype.type == "entity-ghost" then
        return table.deepcopy(entity.item_requests)
    else
        local inven = entity.get_module_inventory()
        
        if inven == nil then return {} end
    
        return inven.get_contents()
    end
end

local function get_prototype(entity)
    if entity.prototype.type == "entity-ghost" then
        return entity.ghost_prototype
    else
        return entity.prototype
    end
end

local function simplify_power(prototype)
    local usage = prototype.energy_usage * 60
    if usage == nil then return {type = "none"} end

    local source = prototype.electric_energy_source_prototype
    if source ~= nil then

        return {
            type = "electric",
            usage = usage,
            emissions = source.emissions * usage * 60,
            drain = source.drain * 60,
        }
    end

    source = prototype.burner_prototype
    if source ~= nil then

        return {
            type = "item",
            usage = usage,
            emissions = source.emissions * usage * 60,
            fuel_categories = source.fuel_categories,
            effectivity = source.effectivity,
            fuels = {}
        }
    end

    source = prototype.fluid_energy_source_prototype
    if source ~= nil then

        return {
            type = "fluid",
            usage = usage,
            emissions = source.emissions * usage * 60,
            burner = source.burns_fluid,
            filter = source.fluid_box.filter,
            temp = source.maximum_temperature,
            effectivity = source.effectivity,
            fuels = {}
        }
    end

    source = prototype.heat_energy_source_prototype
    if source ~= nil then

        return {
            type = "heat",
            usage = usage,
            emissions = source.emissions * usage * 60,
        }
    end

    return {type = "none"}
end

local function simplify_recipe(recipe)
    local r = {
        name = recipe.name,
        time = recipe.energy,
        pollution_mod = recipe.prototype.emissions_multiplier,
        input = {},
        output = {},
        catalyst = {},
    }

    for index, input in pairs(recipe.ingredients) do
        r.input[input.name] = {type = input.type, amount = input.amount}
        if input.type == "fluid" then
            r.input[input.name].minimum_temperature = input.minimum_temperature
            r.input[input.name].maximum_temperature = input.maximum_temperature
        end

        if input.catalyst_amount ~= nil then
            r.catalyst[input.name] = {type = input.type, amount = input.catalyst_amount}
        end
    end
    
    for index, output in pairs(recipe.products) do
        local amount
        if output.amount ~= nil then
            amount = output.amount
        else
            amount = (output.amount_min + output.amount_max) / 2
        end

        if output.probability ~= nil then
            amount = amount * output.probability 
        end

        -- game.print(output.name .. ": amount = " .. amount)
        r.output[output.name] = {type = output.type, amount = amount}
        if output.type == "fluid" and output.temperature ~= nil then
            r.output[output.name].temperature = output.temperature
        end
    end

    for name, catalyst in pairs(r.catalyst) do
        r.input[name].amount = r.input[name].amount - catalyst.amount
        r.output[name].amount = r.output[name].amount - catalyst.amount

        if r.input[name].amount == 0 then r.input[name] = nil end
        if r.output[name].amount == 0 then r.output[name] = nil end
    end

    return r
end

local function recipe_data(entity, power)
    local recipe = entity.get_recipe()
    if recipe ~= nil then
        return simplify_recipe(recipe)
    end

    if entity.prototype.type == "furnace" then
        recipe = entity.previous_recipe
        if recipe ~= nil then
            return simplify_recipe(recipe)
        end
    end

    if entity.prototype.type == "boiler" then
        
    end

    if entity.prototype.type == "reactor" then
        
    end

    return {
        name = "nil",
        time = 1,
        pollution_mod = 1,
        input = {},
        output = {},
        catalyst = {},
    }
end

local function recipe_name(entity)
    local recipe = entity.get_recipe()
    if recipe ~= nil then
        return recipe.name
    end

    if entity.prototype.type == "furnace" then
        recipe = entity.previous_recipe
        if recipe ~= nil then
            return recipe.name
        end
    end

    return {
        recipe = "nil"
    }
end

---------------------------------------------  Public Functions  ---------------------------------------------

Factory = {}

function Factory.__index(table, index)
    return getmetatable(table)[index]
end

function Factory.entity_id(entity)
    local name
    if entity.prototype.type == "entity-ghost" then
        name = entity.ghost_name
    else
        name = entity.name
    end

    name = string.format("%s(%s)", name, recipe_name(entity))

    for module, count in pairs(module_list(entity)) do
        name = name .. "-" .. module .. ":" .. count
    end

    return name
end

function Factory:from_entity(entity, count)
    local new = {}
    setmetatable(new, self)

    if count ~= nil then
        new.count = count
    else
        new.count = 1
    end

    new.prototype = get_prototype(entity)
    new.modules = module_list(entity)
    new.modifiers = calc_modifiers(new.modules)
    new.power = simplify_power(new.prototype)
    new.recipe = recipe_data(entity, new.power)

    -- game.print("power: " .. serpent.block(new.power))

    return new
end

function Factory:inc_count(count)
    self.count = self.count + count
end

function Factory:get_input_speed()
    return self.count * self.prototype.crafting_speed * self.modifiers.speed
end

function Factory:get_output_speed()
    return self:get_input_speed() * self.modifiers.productivity
end

function Factory:get_clocked_input_speed()
    return self:get_input_speed() * self.modifiers.clock
end

function Factory:get_clocked_output_speed()
    return self:get_output_speed() * self.modifiers.clock
end

function Factory:needs_fuel()
    return self.power.type == "item" or self.power.type == "fluid"
end

function Factory:get_pollution(time, level)
    local base = self.count * self.modifiers.clock * self.power.emissions * self.modifiers.consumption * self.modifiers.pollution * self.recipe.pollution_mod

    if self:needs_fuel() and level ~= nil then
        local power = self:fuel_requirement(time)
        local new = 0

        for _, fuel in pairs(self.fuel_components(level)) do
            -- add pollution based on the percentage of power that the fuel provides and their pollution modifier.
            new = new + ((power / fuel:provided_value()) * base * fuel:pollution_mod())
        end

        return new
    else
        return base
    end
end

function Factory:get_power()
    local power = self.power

    if power.type == "electric" then
        return {
            usage = self.count * self.modifiers.clock * power.usage,
            drain = self.count * self.modifiers.clock * power.drain,
        }
    end

    return {
        usage = 0,
        drain = 0,
    }
end

function Factory:get_craft()
    local craft = {}
    -- game.print("test: " .. serpent.block(self))

    for item, data in pairs(self.recipe.catalyst) do
        Helper.add_item_to_list(craft, item, {type="item", amount=data.amount * self.count})
    end

    for _, stack in pairs(self.prototype.items_to_place_this) do
        local count = stack.count
        if count == nil then count = 1 end

        Helper.add_item_to_list(craft, stack.name, {type="item", amount=count * self.count})
    end

    return craft
end

function Factory:get_size()
    local b = self.prototype.selection_box
    local x = math.ceil(b.right_bottom.x - b.left_top.x)
    local y = math.ceil(b.right_bottom.y - b.left_top.y)

    return {
        x = x,
        y = y,
        area = x * y
    }
end

function Factory:get_recipe(time)
    local in_speed  = (self:get_clocked_input_speed() * time) / self.recipe.time
    local out_speed = (self:get_clocked_output_speed() * time) / self.recipe.time

    local recipe = {
        input = {},
        output = {},
    }

    for name, data in pairs(self.recipe.input) do
        Helper.add_item_to_list(recipe.input, name, {type=data.type, amount=in_speed * data.amount})
    end

    for name, data in pairs(self.recipe.output) do
        Helper.add_item_to_list(recipe.output, name, {type=data.type, amount=out_speed * data.amount})
    end

    return recipe
end

function Factory:match_speed(item, time)
    -- game.print("match speed: amount: " .. amount)
    if item == nil then
        self.modifiers.clock = 0
        return self.modifiers.clock
    end

    local amount = item.amount
    local type = self.match.type
    local item = self.match.item_name
    local speed

    if type == "input" then
        speed = (self:get_input_speed() * time) / self.recipe.time
    else
        speed = (self:get_output_speed() * time) / self.recipe.time
    end

    local max = self.recipe[type][item].amount * speed

    local new_clock = amount / max

    if new_clock > 1 then new_clock = 1 end

    self.modifiers.clock = new_clock
    return new_clock
end

function Factory:add_fuel_list()
    if self.power.fuels ~= nil then
        table.insert(self.power.fuels, {})
    end
end

function Factory:remove_fuel_list(level)
    if self.power.fuels ~= nil then
        table.remove(self.power.fuels, level)
    end
end

function Factory:get_fuel_list(time, level)
    if self.power.fuels ~= nil then
        self.current_fuel = self:fuel_requirement(time)
        return self:fuel_components(level)
    end
    return {}
end

function Factory:fuel_requirement(time)
    local power = self.power
    return (self.count * self.modifiers.clock * power.usage * time) / power.effectivity
end

function Factory:fuel_components(level)
    if self.power.fuels[level] == nil then self.power.fuels[level] = {} end
    return self.power.fuels[level]
end

function Factory:add_fuel(level, name)
    table.insert(self.power.fuels[level], Fuel:new(self, name))
end

function Factory:remove_fuel(level, index)
    table.remove(self.power.fuels[level], index)
end