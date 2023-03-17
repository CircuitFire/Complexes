
--[[
fuel
    .parent
    .fuel
        .prototype
        .temp
    .needed -- items required to burn
    .match -- optional "tries to match input or output need of the complex"
        .type = "input" (match with available fuel item), "output" (match with needed output power)
        .item_name
        .item_type
        .level
    
]]

Fuel = {}

function Fuel:new(factory, fuel, match)
    local new = table.deepcopy(self)

    local level = 1
    if factory.match ~= nil then
        level = factory.match.level + 1
    end

    new.parent = factory
    new.fuel = fuel
    new.match = {
        type = match,
        item_name = fuel.name
        item_type = fuel.type
        level = level
    }
    
    return new
end

function Fuel:get_recipe(time)
    local input = {}

    input[self.match.item_name] = {
        type = self.match.item_type
        amount = self.needed
    }

    return {
        input = input,
        output = {},
    }
end

function Fuel:value()
    if self.match.prototype.fuel_value > 0 then
        return self.fuel.prototype.fuel_value
    else
        return self.fuel.temp * self.fuel.heat_capacity
    end
end

function Fuel:match_speed(item, time)
    -- game.print("match speed: amount: " .. amount)
    local amount = item.amount
    local value = self:value()
    local required = self.parent.current_fuel / value

    if self.match.type == "input" and required > amount then
        required = amount
    end

    self.needed = required

    self.parent.current_fuel = self.parent.current_fuel - (required * value)
    return self.needed
end