--[[
recipe
    .input[name]
        .type                    -- "item", "fluid", "heat"
        .amount                  -- only item, heat
        .temps["min-max"]        -- only fluids
            .amount
            .minimum_temperature
            .maximum_temperature
    .output[name]
        .type                    -- "item", "fluid", "heat"
        .amount                  -- only item, heat
        .temps["temp"]           -- only fluids
            .amount
            .temperature
]]

Recipe = {}

function Recipe:new()
    local new = {
        input = {},
        output = {},
    }
    setmetatable(new, self)

    return new
end

function Recipe.__index(table, index)
    return getmetatable(table)[index]
end

local function merge_side(first, other)
    for name, data in pairs(other) do
        if first[name] == nil then
            first[name] = data
        else
            if data.type ~= "fluid" then
                first[name].amount = first[name].amount + other.amount
            else
                for temp_name, temp in pairs(data.temps) do
                    if first[name].temps[temp_name] == nil then
                        first[name].temps[temp_name] = temp
                    else
                        first[name].temps[temp_name].amount = first[name].temps[temp_name].amount + temp.amount
                    end
                end
            end
        end
    end
end

function Recipe:merge(other)
    merge_side(self.input, other.input)
    merge_side(self.output, other.output)
end

local function sort_temp_range(list)
    table.sort(list, function(a, b)
        local a_min = a.minimum_temperature
        local b_min = b.minimum_temperature
        if a_min == nil then a_min = -math.huge end
        if b_min == nil then b_min = -math.huge end
        return a.minimum_temperature < b.minimum_temperature
    end)
end

local function sort_temp(list)
    table.sort(list, function(a, b)
        return a.temperature < b.temperature
    end)
end

--used in clean returns the difference in count between input and output
local function simplify(input, output)
    if output.amount > input.amount then
        return output.amount - input.amount, "output"
    end
    if output.amount < input.amount then
        return input.amount - output.amount, "input"
    end
end

local function insert_temp(list, in_out, old, new_amount)
    local insert = table.deepcopy(old)
    insert.amount = new_amount
    game.print(in_out .. ": " .. Recipe.temp_index(in_out, insert) .. ": " .. insert.amount)
    list[Recipe.temp_index(in_out, insert)] = insert
end

local function temp_in_range(temp, min, max)
    if min == nil then min = -math.huge end
    if max == nil then max = math.huge end
    return temp >= min and temp <= max
end

--like simplify but fluids have a list of temperatures that have to be handled individually.
local function simplify_fluid(inputs, outputs)
    local temp_outputs = table.deepcopy(outputs)
    local temp_inputs = {}
    for _, data in pairs(inputs) do
        table.insert(temp_inputs, data)
    end
    sort_temp_range(temp_inputs)

    local new_input = {type="fluid", temps = {}}
    local new_output = {type="fluid", temps = {}}

    local i = 1
    for name, data in pairs(temp_outputs) do
        local input = temp_inputs[i]

        while input ~= nil and data.amount > 0 do
            if temp_in_range(data.temperature, input.minimum_temperature, input.maximum_temperature) then
                local new_amount, in_out = simplify(input, data)
                
                if in_out == "output" then
                    --if "output" then it means that input amount was smaller so move on to the next input temp and reduce the output amount
                    insert_temp(new_output.temps, "output", data, new_amount)
                    
                    data.amount = new_amount
                    i = i + 1
                    input = temp_inputs[i]
                elseif in_out == "input" then
                    --if "input" then it means that output amount was smaller so move on to the next output temp and reduce the input amount
                    insert_temp(new_input.temps, "input", input, new_amount)

                    input.amount = new_amount
                    data.amount = 0
                else
                    --returning nether means that they fully cancelled each other out so increment both.
                    i = i + 1
                    input = temp_inputs[i]
                    data.amount = 0
                end

            else
                insert_temp(new_output.temps, "output", data, new_amount)
                data.amount = 0
            end
        end
    end
    
    if next(new_input.temps) == nil then new_input = nil end
    if next(new_output.temps) == nil then new_output = nil end

    return new_input, new_output
end

--gets total amount of fluid that can accept then temp
local function temp_ranges(fluid, temp)
    local amount = 0

    for _, data in pairs(fluid) do
        if temp_in_range(temp, data.minimum_temperature, data.maximum_temperature) then
            amount = amount + data.amount
        end
    end

    return amount
end

--gets total amount of fluid that can fulfill a temp range
local function ranges_temp(fluid, range)
    local amount = 0

    for _, data in pairs(fluid) do
        if temp_in_range(data.temperature, range.minimum_temperature, range.maximum_temperature) then
            amount = amount + data.amount
        end
    end

    return amount
end

--[[
    get
        .name
        .temp_range
        .temp
]]
function Recipe:get(in_out, get)
    if type(get) == "string" then get = {name = get} end
    -- game.print("get: " .. serpent.block(get))
    local item = self[in_out][get.name]
    if item == nil then return end

    local list = {
        type = item.type
    }

    if item.type ~= "fluid" or (get.temp_range == nil and get.temp == nil) then
        if self.amount == nil then game.print(serpent.block(self)) end
        list.amount = self:amount(in_out, get.name)
    else
        if in_out == "input" then
            if get.temp_range ~= nil then
                --copy data
                for name, info in pairs(item.temps[get.temp_range]) do
                    list[name] = info
                end
            else
                list.amount = temp_ranges(item.temps, get.temp)
            end
        else
            if get.temp ~= nil then
                --copy data
                for name, info in pairs(item.temps[get.temp]) do
                    list[name] = info
                end
            else
                list.amount = ranges_temp(item.temps, get.temp_range)
            end
        end
    end

    return list
end

function Recipe.temp_index(in_out, data)
    if in_out == "output" then
        return tostring(data.temperature)
    else
        return tostring(data.minimum_temperature) .. "-" .. tostring(data.maximum_temperature)
    end
end

--[[
    set
        .name
        .temp_index
    data
        .type
        .amount
        .temperature
        .minimum_temperature
        .maximum_temperature
]]
function Recipe:set(in_out, set, data)
    if type(set) == "string" then set = {name = set} end
    local list = self[in_out]

    if data.type ~= "fluid" then
        if list[set.name] == nil then
            list[set.name] = data
        else
            for name, info in pairs(data) do
                list[set.name][name] = info
            end
        end
    else
        if in_out == "output" and data.temperature == nil then data.temperature = game.fluid_prototypes[set.name].default_temperature end
        if set.temp_index == nil then set.temp_index = self.temp_index(in_out, data) end
        if list[set.name] == nil then
            list[set.name] = {
                type = data.type,
                temps = {},
            }
        end
    
        data.type = nil

        if list[set.name].temps[set.temp_index] == nil then
            list[set.name].temps[set.temp_index] = data
        else
            -- copy data
            for name, info in pairs(data) do
                list[set.name].temps[set.temp_index][name] = info
            end
        end
    end
end

function Recipe:get_clean(in_out, get)
    if type(set) == "string" then get = {name = set} end
    local search = self
    if self.output[get.name] ~= nil then
        local temp = self:clean_one(get.name)
        search = {
            output = { [get.name] = temp.output },
            input = { [get.name] = temp.input },
        }
        setmetatable(search, Recipe)
    end

    return self.get(search, in_out, get)
end

function Recipe.flip(in_out)
    local flip = {
        input = "output",
        output = "input"
    }
    return flip[in_out]
end

function Recipe:clean_one(name)
    local new = {}
    local data = self.output[name]

    if self.input[name] == nil then
        new.output = data
    else
        if data.type ~= "fluid" then
            local new_amount, type = simplify(self.input[name], data)
            if type then new[type] = {type=data.type, amount=new_amount} end
        else
            local input, output = simplify_fluid(self.input[name].temps, data.temps)
            new.input = input
            new.output = output
        end
    end

    return new
end

--returns a recipe with matching inputs and outputs cancelling each other out.
function Recipe:clean()
    local new = Recipe:new()
    
    for name, _ in pairs(self.output) do
        local out = self:clean_one(name)
        new.output[name] = out.output
        new.input[name] = out.input
    end

    for name, data in pairs(self.input) do
        if self.output[name] == nil then
            new.input[name] = table.deepcopy(data)
        end
    end

    return new
end

function Recipe:get_type(type)
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

function Recipe:amount(in_out, name)
    if self[in_out][name].type ~= "fluid" then return self[in_out][name].amount end

    local amount = 0
    for _, data in pairs(self[in_out][name].temps) do
        amount = amount + data.amount
    end

    return amount
end

function Recipe:logistics()
    local logistics = {
        external = {
            item = 0,
            fluid = 0,
            heat = 0
        },
        internal = {
            item = 0,
            fluid = 0,
            heat = 0
        },
    }

    local clean = self:clean()

    for name, data in pairs(self.input) do
        if clean.input[name] ~= nil then
            logistics.external[data.type] = logistics.external[data.type] + clean:amount("input", name)
            logistics.internal[data.type] = logistics.internal[data.type] + (self:amount("input", name) - clean:amount("input", name))
        else
            logistics.internal[data.type] = logistics.internal[data.type] + self:amount("input", name)
        end
    end

    for name, data in pairs(self.output) do
        if clean.output[name] ~= nil then
            logistics.external[data.type] = logistics.external[data.type] + clean:amount("output", name)
            logistics.internal[data.type] = logistics.internal[data.type] + (self:amount("output", name) - clean:amount("output", name))
        else
            logistics.internal[data.type] = logistics.internal[data.type] + self:amount("output", name)
        end
    end

    return logistics
end