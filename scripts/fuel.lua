require("scripts.recipe")
--[[
fuel
    .parent
    .needed                     -- items required to burn (generated during match_speed)
    .burner
    .fuel
        .prototype
        .maximum_temperature    -- only fluid
    .match                      -- optional "tries to match input or output need of the complex"
        .in_out = "input" (match with available input item), "output" (match with needed output item)
        .level
        .type                   -- item type
        .get
            .name
            .temperature
            .maximum_temperature
            .minimum_temperature
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

    local get = {
        name = fuel_name,
    }

    local fuel = {}
    if factory.power.type == "item" then
        new.burner = true
        fuel.prototype = game.item_prototypes[fuel_name]
    else
        new.burner = factory.power.burner
        fuel.prototype = game.fluid_prototypes[fuel_name]
        if not new.burner then
            fuel.maximum_temperature = factory.power.maximum_temperature
            get.maximum_temperature = fuel.prototype.default_temperature
        end
    end

    new.parent = factory
    new.fuel = fuel
    new.match = {
        in_out = "output",
        level = level,
        type = factory.power.type,
        get = get,
    }
    
    return new
end

function Fuel:get_recipe(time)
    local recipe = Recipe:new()

    recipe:set(
        "input", {name = self.match.get.name},
        {
            type = self.match.type,
            amount = self.needed,
            maximum_temperature = self.fuel.maximum_temperature,
        }
    )

    local result = self.fuel.prototype.burnt_result
    if result ~= nil then
        recipe:set(
            "output", {name = result.name},
            {
                type = "item",
                amount = self.needed,
            }
        )
    end

    return recipe
end

function Fuel:value()
    if self.burner then
        return self.fuel.prototype.fuel_value
    else
        return self.match.get.minimum_temperature * self.fuel.heat_capacity
    end
end

function Fuel:match_speed(item, time)
    -- game.print("match speed: amount: " .. amount)
    local amount = 0
    if item ~= nil then amount = item.amount end

    local value = self:value()
    local required = self.parent.current_fuel / value

    if self.match.in_out == "input" and required > amount then
        required = amount
    end

    self.needed = required

    self.parent.current_fuel = self.parent.current_fuel - (required * value)
    return self.needed
end

function Fuel:set_level(new)
    if new <= ((self.parent.match and self.parent.match.level) or 0) then return true end
    self.match.level = new
end

function Fuel:provided_value()
    return self.needed * self:value()
end

function Fuel:pollution_mod()
    return fuel.prototype.fuel_emissions_multiplier
end

function Fuel:name()
    return string.format("[%s=%s]", self.match.type, self.match.get.name)
end

