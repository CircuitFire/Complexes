
--[[
fuel
    .parent
    .fuel
        .prototype
        .temperature
    .needed -- items required to burn
    .match -- optional "tries to match input or output need of the complex"
        .type = "input" (match with available fuel item), "output" (match with needed output power)
        .item_name
        .item_type
        .level
]]

Fuel = {}

function Fuel.__index(table, index)
    return getmetatable(table)[index]
end


function Fuel:new(factory, fuel_name)
    local new = {}
    setmetatable(new, self)

    local level = 1
    if factory.match ~= nil then
        level = factory.match.level + 1
    end

    local fuel = {}
    if factory.power.type == "item" then
        fuel.prototype = game.item_prototypes[fuel_name]
    else
        fuel.prototype = game.fluid_prototypes[fuel_name]
        fuel.temperature = fuel.prototype.default_temperature
    end

    new.parent = factory
    new.fuel = fuel
    new.match = {
        type = "output",
        item_name = fuel_name,
        item_type = factory.power.type,
        level = level,
    }
    
    return new
end

function Fuel:get_recipe(time)
    local input = {}

    input[self.match.item_name] = {
        type = self.match.item_type,
        amount = self.needed,
    }

    return {
        input = input,
        output = {},
    }
end

function Fuel:value()
    if self.fuel.prototype.fuel_value > 0 then
        return self.fuel.prototype.fuel_value
    else
        return self.fuel.temp * self.fuel.heat_capacity
    end
end

function Fuel:match_speed(item, time)
    -- game.print("match speed: amount: " .. amount)
    local amount = 0
    if item ~= nil then amount = item.amount end

    local value = self:value()
    local required = self.parent.current_fuel / value

    if self.match.type == "input" and required > amount then
        required = amount
    end

    self.needed = required

    self.parent.current_fuel = self.parent.current_fuel - (required * value)
    return self.needed
end

function Fuel:provided_value()
    return self.needed * self:value()
end

function Fuel:pollution_mod()
    return fuel.prototype.fuel_emissions_multiplier
end

function Fuel:name()
    return string.format("[%s=%s]", self.match.item_type, self.match.item_name)
end

