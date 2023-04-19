[[
recipe
    .input[name]
        .type                    -- "item", "fluid", "heat"
        .amount                  -- only item, heat
        .temps["min-max"]        -- only fluids
            .amount
            .is_fuel 
            .minimum_temperature
            .maximum_temperature
    .output[name]
        .type                    -- "item", "fluid", "heat"
        .amount                  -- only item, heat
        .temps["temp"]           -- only fluids
            .amount
            .temperature
]]

Recipe = {
    input = {},
    output = {},
}

function Recipe:new()
    return table.deepcopy(self)
end

local function merge(self, other)
    for name, data in pairs(input) do
        if self[name] == nil then
            self[name] = data
        else
            if data.type ~= "fluid" then
                self[name].amount = self[name].amount + other.amount
            else
                for temp_name, temp in pairs(data.temps) do
                    if self.temps[temp_name] == nil then
                        self.temps[temp_name] = temp
                    else
                        self.temps[temp_name].amount = self.temps[temp_name].amount + temp.amount
                    end
                end
            end
        end
    end
end

function Recipe:merge(other)
    merge(self.input, other.input)
    merge(self.output, other.output)
end

function Recipe:sort_temps()
    for _, data in pairs(self.input) do
        if data.type == "fluid" then
            table.sort(data.temps, function(a, b) a.minimum_temperature < b.minimum_temperature end)
        end
    end
    for _, data in pairs(self.output) do
        if data.type == "fluid" then
            table.sort(data.temps, function(a, b) a.temperature < b.temperature end)
        end
    end
end

local function simplify(input, output)
    if output.amount > input.amount then
        return output.amount - input.amount, "output"
    end
    if output.amount < input.amount then
        return input.amount - output.amount, "input"
    end
end

local function insert_temp(table, old, new_amount)
    local insert = table.deepcopy(old)
    insert.amount = new_amount
    table.insert(table, insert)
end

local function simplify_fluid(inputs, outputs)
    local temp_outputs = table.deepcopy(outputs)
    local temp_inputs = table.deepcopy(inputs)

    local new_input = {type="fluid", temps = {}}
    local new_output = {type="fluid", temps = {}}

    local i = 1
    for name, data in pairs(temp_outputs) do
        local input = temp_inputs[i]

        while input ~= nil and data.amount > 0 do
            if data.temperature >= input.minimum_temperature and data.temperature <= input.maximum_temperature then
                local new_amount, type = simplify(self.input[name], data)
                
                if type == "output" then
                    --if "output" then it means that input amount was smaller so move on to the next input temp and reduce the output amount
                    insert_temp(new_output.temps, data, new_amount)
                    
                    data.amount = new_amount
                    i = i + 1
                    input = temp_inputs[i]
                elseif type == "input" then
                    --if "input" then it means that output amount was smaller so move on to the next output temp and reduce the input amount
                    insert_temp(new_input.temps, input, new_amount)

                    input.amount = new_amount
                    data.amount = 0
                end

            else
                insert_temp(new_output.temps, data, new_amount)
                data.amount = 0
            end
        end
    end

    if new_input.temps[1] == nil then new_input = nil end
    if new_output.temps[1] == nil then new_output = nil end

    return new_input, new_output
end

function Recipe:clean()
    local new = Recipe:new()
    
    for name, data in pairs(self.output) do
        if self.input[name] == nil then
            new.output[name] = data
        else
            if data.type ~= "fluid" then
                local new_amount, type = simplify(self.input[name], data)
                if type then new[type][name] = {type=data.type, amount=new_amount} end
            else
                local input, output = simplify_fluid(self.input[name].temps, data.temps)
                new.input[name] = input
                new.output[name] = output
            end
        end
    end
end

function Complex:get_type(type)
    local out = {
        input = {},
        output = {},
    }

    for name, item in pairs(self.input) do
        if item.type == type then
            out.input[name] = true
        end
    end
    for name, item in pairs(self.output) do
        if item.type == type then
            out.output[name] = true
        end
    end

    return out
end