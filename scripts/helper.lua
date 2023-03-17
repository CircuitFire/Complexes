
Helper = {}

function Helper.add_count_to_list(list, name, count)
    if list[name] == nil then
        list[name] = count
    else
        list[name] = list[name] + count
    end
end

function Helper.add_item_to_list(list, name, new)
    if list[name] == nil then
        list[name] = new
    else
        list[name].amount = list[name].amount + new.amount
    end
end

function Helper.merge_recipes(main, new)
    for name, data in pairs(new.input) do
        Helper.add_item_to_list(main.input, name, data)
    end
    for name, data in pairs(new.output) do
        Helper.add_item_to_list(main.output, name, data)
    end
end