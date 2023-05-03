require("scripts.file_writer")
require("gui.gui_lib")

-- This is a horrible spaghetti mess that needs to be updated
---------------------------------------------  Helper Functions  ---------------------------------------------
local function player(event)
    return game.get_player(event.player_index)
end

local function player_global(event)
    return global.players[event.player_index]
end

local function window(event)
    return global.players[event.player_index].complex_window
end

local function update_size(window)
    local size = window.complex:size()
    window.size.caption={"complex.size", size.x, size.y}
end

local function fancy_names(factories)
    local data = {
        names = {},
        indexes = {},
    }

    for factory_name, factory in pairs(factories) do
        local recipe_formatted
        if factory.recipe.name == "nil" then
            recipe_formatted = "[virtual-signal=signal-red]"
        elseif factory.recipe.name == "nil boiler" then
            recipe_formatted = "[fluid=" .. next(factory.recipe.output) .. "]"
        elseif factory.recipe.name == "nil reactor" then
            recipe_formatted = "[img=tooltip-category-heat]"
        else
            recipe_formatted = "[recipe=" .. factory.recipe.name .. "]"
        end

        local level = ""
        if factory.match ~= nil then
            level = "Level: " .. factory.match.level
        end

        local name = string.format("[entity=%s]%s -> %s", factory.prototype.name, level, recipe_formatted)

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

---------------------------------------------  list Functions  ---------------------------------------------
local function update_factory_list(window)
    local factory_list = window.factory_list

    factory_list.clear_items()
    -- game.print("update" .. serpent.block(player_global.complex.recipes))
    local data = fancy_names(window.complex.factories)
    window.factory_indexes = data.indexes

    for _, name in pairs(data.names) do
        factory_list.add_item(name)
    end
end

local function update_craft_list(window)
    local craft_list = window.craft_list

    craft_list.clear_items()
    local craft = window.complex:craft()

    for name, data in pairs(craft) do
        craft_list.add_item(string.format("[%s=%s]: %s", data.type, name, data.amount))
    end

    update_size(window)
end

local function update_in_out_list(window)
    input_list = window.input_list
    output_list = window.output_list

    local selected
    if window.recipe_list ~= nil then
        selected = window.recipe_list.selected_index
    end

    local in_out_list = window.complex:get_recipe(selected):clean()

    -- game.print(serpent.block(in_out_list.input))

    input_list.clear_items()
    for name, data in pairs(in_out_list.input) do
        if data.type == "fluid" then
            for temp_index, temp in pairs(data.temps) do
                input_list.add_item("[" .. data.type .. "=" .. name .. "] temp range: (" .. temp_index .. "): " .. temp.amount)
            end
        elseif data.type == "heat" then
            input_list.add_item("[img=tooltip-category-heat]: " .. data.amount .. "MW")
        else
            input_list.add_item("[" .. data.type .. "=" .. name .. "]: " .. data.amount)
        end
    end

    output_list.clear_items()
    for name, data in pairs(in_out_list.output) do
        if data.type == "fluid" then
            for temp_index, temp in pairs(data.temps) do
                output_list.add_item("[" .. data.type .. "=" .. name .. "] temp range: (" .. temp_index .. "): " .. temp.amount)
            end
        elseif data.type == "heat" then
            output_list.add_item("[img=tooltip-category-heat]: " .. data.amount .. "MW")
        else
            output_list.add_item("[" .. data.type .. "=" .. name .. "]: " .. data.amount)
        end
    end
end

---------------------------------------------  Factory Editor Functions  ---------------------------------------------
local function normal_filters(window, top, factory)
    local input = {item={}, fluid={}}
    local output = {item={}, fluid={}}

    for name, data in pairs(factory.recipe.input) do
        local type = data.type
        if type == "heat" then type = "item" end
        table.insert(input[type], name)
    end

    for name, data in pairs(factory.recipe.output) do
        local type = data.type
        if type == "heat" then type = "item" end
        table.insert(output[type], name)
    end

    local current_filter = {
        input = {},
        output = {},
    }

    if factory.match then
        current_filter[factory.match.in_out][factory.match.type] = factory.match.get.name
    end

    if next(input.item) or next(input.fluid) then
        local input_box = top.add{type="flow", direction="horizontal"}
        input_box.add{type="label", caption={"complex.factory-editor-match-input"}}

        if next(input.item) then
            -- input_box.add{type="label", caption={"complex.factory-editor-match-item"}}
            window.factory_editor_filters.input_item = input_box.add{
                type="choose-elem-button",
                tags={func="match_update", type="input"},
                elem_type="item",
                item=current_filter.input.item,
                elem_filters={{filter="name", name=input.item}}
            }
        end
        if next(input.fluid) then
            -- input_box.add{type="label", caption={"complex.factory-editor-match-fluid"}}
            window.factory_editor_filters.input_fluid = input_box.add{
                type="choose-elem-button",
                tags={func="match_update", type="input"},
                elem_type="fluid",
                fluid=current_filter.input.fluid,
                elem_filters={{filter="name", name=input.fluid}}
            }
        end
    end
    
    if next(output.item) or next(output.fluid) then
        local output_box = top.add{type="flow", direction="horizontal"}
        output_box.add{type="label", caption={"complex.factory-editor-match-output"}}

        if next(output.item) then
            -- output_box.add{type="label", caption={"complex.factory-editor-match-item"}}
            window.factory_editor_filters.output_item = output_box.add{
                type="choose-elem-button",
                tags={func="match_update", type="output"},
                elem_type="item",
                item=current_filter.output.item,
                elem_filters={{filter="name", name=output.item}}
            }
        end
        if next(output.fluid) then
            -- output_box.add{type="label", caption={"complex.factory-editor-match-fluid"}}
            window.factory_editor_filters.output_fluid = output_box.add{
                type="choose-elem-button",
                tags={func="match_update", type="output"},
                elem_type="fluid",
                fluid=current_filter.output.fluid,
                elem_filters={{filter="name", name=output.fluid}}
            }
        end
    end
end

local function fuel_filters(window, top, factory)
    top.add{type="label", caption={"complex.fuel-match-type"}}
    top.add{
        type="switch",
        left_label_caption={"complex.match-need"},
        right_label_caption={"complex.match-available"},
        tags={func="update_fuel_match"}
    }
end

Events.switch_state_changed.update_fuel_match = function(event)
    local window = window(event)

    if event.element.switch_state == "left" then
        window.selected_factory.match.type = "output"
    else
        window.selected_factory.match.type = "input"
    end

    update_in_out_list(window)
end

--types "normal" "fuel"
local function factory_editor(window)
    if window.factory_editor ~= nil then
        window.factory_editor.destroy()
    end

    local factory = window.selected_factory
    if factory == nil then return end
    -- game.print("test: " .. serpent.block(factory))

    local type = window.selected_factory_type
    local box
    if type == "normal" then
        box = window.top_box
    else
        box = window.true_bottom_box
    end

    local top = box.add{type="flow", direction="vertical"}
    top.add{type="label", caption={"complex.factory-editor-" .. type}}

    if type == "normal" then
        local count = top.add{type="flow", direction="horizontal"}
        count.add{type="label", caption={"complex.factory-editor-count"}}
        count.add{type="textfield", tags={func="factory_editor_count"}, text=tostring(factory.count), numeric=true}

        local clock = top.add{type="flow", direction="horizontal"}
        clock.add{type="label", caption={"complex.factory-editor-clock"}}
        window.factory_editor_clock = clock.add{type="textfield", tags={func="factory_editor_clock"}, text=tostring(factory.modifiers.clock), numeric=true, allow_decimal=true}
    end

    if factory.match then
        local clock = top.add{type="flow", direction="horizontal"}
        clock.add{type="label", caption={"complex.factory-editor-level"}}
        clock.add{type="textfield", tags={func="factory_editor_level"}, text=tostring(factory.match.level), numeric=true}
    end

    window.factory_editor_filters = {}
    if type == "normal" then
        normal_filters(window, top, factory)
    else
        fuel_filters(window, top, factory)
    end
    
    top.add{type="button", tags={func="remove_factory"}, caption={"complex.remove"}}
    
    window.factory_editor = top
end

Events.text_changed.factory_editor_count = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    window.selected_factory.count = number
    update_craft_list(window)
    update_in_out_list(window)
    if window.selected_factory.match then
        window.factory_editor_clock.text = tostring(window.selected_factory.modifiers.clock)
    end
end

Events.text_changed.factory_editor_clock = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    if number > 1 then number = 1 end
    window.selected_factory.modifiers.clock = number
    update_in_out_list(window)
end

---------------------------------------------  Pipe Editor Functions  ---------------------------------------------
local function update_pipe_side(window, side)
    for _, button in pairs(window.pipe_editor_buttons) do
        button.state = false
    end

    window.pipe_editor_buttons[side].state = true
end

local function get_selected_fluid(window)
    return window.pipe_config_index[window.pipe_editor_list.selected_index].name
end

local function get_selected_pipe(window)
    return window.complex.pipes[get_selected_fluid(window)]
end

local function get_selected_connection(window)
    return get_selected_pipe(window).positions[window.pipe_editor_selector.selected_index]
end

local function update_pipe_selected(window)
    local data = get_selected_connection(window)

    update_pipe_side(window, data.side)
    window.pipe_editor_position.text = tostring(data.offset)
end

local function update_pipe_editor(window)
    local data = get_selected_pipe(window)

    window.passthrough_button.state = data.passthrough

    window.pipe_editor_selector.clear_items()
    for i, _ in pairs(data.positions) do
        window.pipe_editor_selector.add_item(tostring(i))
    end
    window.pipe_editor_selector.selected_index = 1

    update_pipe_side(window, get_selected_connection(window).side)
    window.pipe_editor_position.text = tostring(get_selected_connection(window).offset)
end

local function pipe_editor(window)
    if window.pipe_editor ~= nil then
        window.pipe_editor.destroy()
        window.pipe_editor = nil
    end

    local fluids = window.complex:get_fluids()
    --game.print("fluids: " .. serpent.block(fluids))
    if table_size(fluids.input) == 0 and table_size(fluids.output) == 0 then return end
    window.pipe_config_index = {}

    local top = window.mid_box.add{type="flow", direction="vertical"}
    top.style.width = 300
    top.add{type="label", caption={"complex.pipe-editor"}}

    local list = top.add{type="list-box", tags={func="pipe_editor_list_update"}, style="stretch_box"}
    window.pipe_editor_list = list

    for name, _ in pairs(fluids.input) do
        list.add_item("[fluid=" .. name .. "]")
        table.insert(window.pipe_config_index, {name=name, type="input"})
    end
    for name, _ in pairs(fluids.output) do
        list.add_item("[fluid=" .. name .. "]")
        table.insert(window.pipe_config_index, {name=name, type="output"})
    end
    local count = 0
    for i = 1, fluids.max_fuels do
        name = "Fuel Input #" .. i
        list.add_item(name)
        table.insert(window.pipe_config_index, {name=name, type="input"})
    end
    list.selected_index = 1

    --make sure all values have at least a default value
    for _, fluid in pairs(window.pipe_config_index) do
        window.complex:init_pipe_config(fluid.name, fluid.type)
    end

    top.add{type="label", caption={"complex.pipe-editor-pipe-connections"}}
    window.pipe_editor_selector = top.add{type="drop-down", tags={func="pipe_editor_selector_update"}}

    local buttons = top.add{type="flow", direction="horizontal"}
    buttons.add{type="button", caption={"complex.add"}, tags={func="pipe_editor_add_connection"}}
    buttons.add{type="button", caption={"complex.remove"}, tags={func="pipe_editor_remove_connection"}}

    window.pipe_editor_buttons = {}

    window.passthrough_button = Gui_Lib.add_labeled_radiobutton(top, "complex.passthrough", {func="pipe_editor_passthrough_update"})

    top.add{type="label", caption={"complex.pipe-editor-side"}}
    window.pipe_editor_buttons.top = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-top", {func="pipe_editor_side_update", side="top"})
    window.pipe_editor_buttons.left = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-left", {func="pipe_editor_side_update", side="left"})
    window.pipe_editor_buttons.right = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-right", {func="pipe_editor_side_update", side="right"})
    window.pipe_editor_buttons.bottom = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-bottom", {func="pipe_editor_side_update", side="bottom"})

    top.add{type="label", caption={"complex.pipe-editor-position"}}
    window.pipe_editor_position = top.add{type="textfield", style="stretchable_textfield", text="fix me!", tags={func="pipe_editor_position_update"}, numeric=true}

    update_pipe_editor(window)
end

Events.selection_state_changed.pipe_editor_list_update = function(event)
    update_pipe_editor(window(event))
end

Events.selection_state_changed.pipe_editor_selector_update = function(event)
    update_pipe_selected(window(event))
end

Events.gui_click.pipe_editor_add_connection = function(event)
    local window = window(event)
    local selector = window.pipe_editor_selector
    local new_index = #selector.items + 1

    window.complex:add_connection(get_selected_fluid(window), selector.selected_index)
    selector.add_item(tostring(new_index))
    selector.selected_index = new_index
    update_pipe_selected(window)
end

Events.gui_click.pipe_editor_remove_connection = function(event)
    local window = window(event)
    local selector = window.pipe_editor_selector

    if #selector.items > 1 then
        window.complex:remove_connection(get_selected_fluid(window), selector.selected_index)
        local index = selector.selected_index
        selector.remove_item(#selector.items)

        local len = #selector.items
        if index > len then
            index = len
        end
        selector.selected_index = index

        update_pipe_selected(window)
    end
end

Events.checked_state_changed.pipe_editor_passthrough_update = function(event)
    local window = window(event)
    get_selected_pipe(window).passthrough = event.element.state
end

Events.checked_state_changed.pipe_editor_side_update = function(event)
    local window = window(event)
    local side = event.element.tags.side

    update_pipe_side(window, side)
    get_selected_connection(window).side = side
end

Events.text_changed.pipe_editor_position_update = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end

    local pipe = get_selected_connection(window)
    pipe.offset = number
end

---------------------------------------------  Alt Recipe Functions  ---------------------------------------------
local function init_recipe_list(window)
    for _, recipe in pairs(window.complex.sub_recipes) do
        window.recipe_list.add_item(recipe.name)
    end

    window.recipe_list.selected_index = 1
    update_in_out_list(window)
end

local function init_fuel_factory_list(window)
    local data = fancy_names(window.complex:fuel_factories())
    window.fuel_factory_list_indexes = data.indexes

    for _, name in pairs(data.names) do
        window.fuel_factory_list.add_item(name)
    end

    window.fuel_factory_list.selected_index = 1
end

local function selected_recipe(window)
    local temp = window.complex.sub_recipes
    local index = window.recipe_list
    if temp ~= nil and index ~= nil and index.selected_index ~= nil then
        local temp = temp[index.selected_index]
        if temp ~= nil then return temp end
    end

    return window.complex
end

local function selected_factory(window)
    return window.complex.factories[window.fuel_factory_list_indexes[window.fuel_factory_list.selected_index]]
end

local function update_fuel_factory_component_list(window)
    local parent = selected_factory(window)

    window.fuel_factory_component_list.clear_items()
    for i, component in pairs(parent:fuel_components(window.recipe_list.selected_index)) do
        window.fuel_factory_component_list.add_item(string.format("level: %s (%s)", component.match.level, component:name()))
    end

end

local function update_fuel_selector(window)
    local power = selected_factory(window).power
    local filter = {}

    if power.type == "item" then
        for name, _ in pairs(power.fuel_categories) do
            table.insert(filter, {filter="fuel-category", ["fuel-category"]=name})
        end
    else
        if power.burner then
            table.insert(filter, {filter="fuel-value", comparison=">", ["fuel-value"]=0})
        else
            table.insert(filter, {filter="name", name=power.filter})
        end
    end

    window.add_fuel_box.clear()
    window.selected_fuel = window.add_fuel_box.add{
        type="choose-elem-button",
        elem_type=power.type,
        elem_filters=filter
    }
    window.add_fuel_box.add{type="button", tags={func="add_fuel_provider"}, caption={"complex.add"}}
end

Events.elem_changed.match_update = function(event)
    local window = window(event)
    local element = event.element
    local in_out = element.tags.type
    local elem_value = element.elem_value

    for _, elem in pairs(window.factory_editor_filters) do
        elem.elem_value = nil
    end
    element.elem_value = elem_value

    if element.elem_value then
        local level = 1
        if window.selected_factory.match ~= nil then
            level = window.selected_factory.match.level
        end

        window.selected_factory:set_match(in_out, level, element.elem_value, element.elem_type)
    else
        window.selected_factory.match = nil
    end
    
    update_in_out_list(window)
    window.factory_editor_clock.text = tostring(window.selected_factory.modifiers.clock)
    factory_editor(window)
    update_factory_list(window)
    if window.sub_factory_editor then
        update_fuel_factory_component_list(window)
    end
end

Events.text_changed.factory_editor_level = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    if number == 0 then number = 1 end
    
    if window.selected_factory:set_level(number) then return end

    update_factory_list(window)
    update_in_out_list(window)
    if window.selected_factory.match then
        window.factory_editor_clock.text = tostring(window.selected_factory.modifiers.clock)
    end
    if window.sub_factory_editor then
        update_fuel_factory_component_list(window)
    end
end

Events.gui_click.add_fuel_provider = function(event)
    local window = window(event)

    local fuel = window.selected_fuel.elem_value
    if fuel == nil then return end

    selected_factory(window):add_fuel(window.recipe_list.selected_index, fuel)

    local index = window.fuel_factory_component_list.selected_index
    update_fuel_factory_component_list(window)
    window.fuel_factory_component_list.selected_index = index

    update_in_out_list(window)
end

local function sub_factory_editor(window)
    if window.sub_factory_editor ~= nil then
        window.sub_factory_editor.destroy()
        window.sub_factory_editor = nil
        window.recipe_list = nil
    end

    if window.complex:multiple_recipes() == false then return end

    local sub_factory_editor = window.bottom_box.add{type="flow", direction="vertical"}
    window.sub_factory_editor = sub_factory_editor

    local recipe_box = sub_factory_editor.add{type="flow", direction="horizontal"}
    local bottom_box = sub_factory_editor.add{type="flow", direction="horizontal"}
    window.true_bottom_box = bottom_box

    Gui_Lib.add_name_box(
        recipe_box,
        "complex.complex-recipe-name",
        window.complex.sub_recipes[1].name,
        "update_recipe_name"
    )
    Gui_Lib.add_name_box(
        recipe_box,
        "complex.complex-speed",
        tostring(window.complex.time),
        "update_complex_speed"
    )

    local list_box = bottom_box.add{type="flow", direction="vertical"}
    local recipe_list = Gui_Lib.add_labeled_list(list_box, "complex.recipe-list", "recipe_list_select")
    window.recipe_list = recipe_list
    init_recipe_list(window)
    local button_box = list_box.add{type="flow", direction="horizontal"}
    button_box.add{type="button", tags={func="add_recipe"}, caption={"complex.add"}}
    button_box.add{type="button", tags={func="remove_recipe"}, caption={"complex.remove"}}
    
    local fuel_factory_list = Gui_Lib.add_labeled_list(bottom_box, "complex.need-fuel-list", "need_fuel_list_select")
    window.fuel_factory_list = fuel_factory_list
    init_fuel_factory_list(window)

    local provider_box = bottom_box.add{type="flow", direction="vertical"}
    local fuel_factory_component_list = Gui_Lib.add_labeled_list(provider_box, "complex.fuel-provider-list", "fuel_provider_list_select")
    window.fuel_factory_component_list = fuel_factory_component_list
    update_fuel_factory_component_list(window)

    local add_fuel_box = provider_box.add{type="flow", direction="horizontal"}
    window.add_fuel_box = add_fuel_box
    update_fuel_selector(window)
end

Events.text_changed.update_recipe_name = function(event)
    local window = window(event)

    selected_recipe(window).name = event.element.text
end

Events.selection_state_changed.recipe_list_select = function(event)
    local window = window(event)
    update_fuel_factory_component_list(window)
    update_in_out_list(window)
end

Events.gui_click.add_recipe = function(event)
    local window = window(event)
    window.complex:new_recipe()

    local index = window.recipe_list.selected_index + 1
    window.recipe_list.add_item(window.complex.sub_recipes[index].name)
    window.recipe_list.selected_index = index
end

Events.gui_click.remove_recipe = function(event)
    local window = window(event)
    if #window.recipe_list == 1 then return end

    local index = window.recipe_list.selected_index
    window.complex:remove_recipe(index)
    window.recipe_list.remove_item(index)

    if index ~= 1 then index = index - 1 end
    window.recipe_list.selected_index = index
    update_fuel_factory_component_list(window)
end

Events.selection_state_changed.need_fuel_list_select = function(event)
    local window = window(event)
    update_fuel_factory_component_list(window)
end

Events.selection_state_changed.fuel_provider_list_select = function(event)
    local window = window(event)

    if window.factory_list ~= nil then
        window.factory_list.selected_index = 0
    end

    window.selected_factory_type = "fuel"
    window.selected_factory = selected_factory(window):fuel_components(window.recipe_list.selected_index)[window.fuel_factory_component_list.selected_index]
    factory_editor(window)
end

---------------------------------------------  Main window Functions  ---------------------------------------------
local function open_complex(player_index)
    if global.players[player_index].complex_window.window ~= nil then return end
    global.players[player_index].complex_window = { complex = global.players[player_index].complex_window.complex }
    local window = global.players[player_index].complex_window

    local window_name = "complex_window"
    local top_flow = Gui_Lib.create_window(player_index, window_name)
    window.top_flow = top_flow

    local name_bar = top_flow.add{type="flow", direction="horizontal"}
    Gui_Lib.add_name_box(
        name_bar,
        "complex.complex-name",
        window.complex.name,
        "update_complex_name"
    )

    Gui_Lib.add_name_box(
        name_bar,
        "complex.complex-floors",
        tostring(window.complex.floors),
        "update_complex_floors"
    )

    name_bar.add{type="label", caption={"complex.graphics"}}
    name_bar.add{
        type="choose-elem-button",
        tags={func="graphics_update"},
        elem_type="entity",
        entity=window.complex.graphics,
        elem_filters={{filter="type", type={"assembling-machine", "furnace", "reactor"}}}
    }

    local size = window.complex:size()
    window.size = name_bar.add{type="label", caption={"complex.size", size.x, size.y}}

    if window.complex:multiple_recipes() == false then
        Gui_Lib.add_name_box(
            top_flow,
            "complex.complex-speed",
            tostring(window.complex.time),
            "update_complex_speed"
        )
    end

    local mid_box = top_flow.add{type="flow", direction="horizontal"}
    window.mid_box = mid_box

    local main_box = mid_box.add{type="flow", direction="vertical"}
    main_box.style.natural_width = 1200
    local top_box = main_box.add{type="flow", direction="horizontal"}
    window.top_box = top_box

    window.factory_list = Gui_Lib.add_labeled_list(top_box, "complex.factory-list", "factory_list_select")
    update_factory_list(window)

    window.craft_list = Gui_Lib.add_labeled_list(top_box, "complex.craft-list", "no_select")
    update_craft_list(window)

    window.input_list = Gui_Lib.add_labeled_list(top_box, "complex.input-list", "no_select")
    window.output_list = Gui_Lib.add_labeled_list(top_box, "complex.output-list", "no_select")
    update_in_out_list(window)

    pipe_editor(window)

    local bottom_box = main_box.add{type="flow", direction="vertical"}
    window.bottom_box = bottom_box

    sub_factory_editor(window)

    -- local factory_list = top_box.add{type="list-box", name="complex_factory_list", style="stretch_box"}

    local bottom_bar = top_flow.add{type="flow", direction="horizontal"}
    bottom_bar.add{type="empty-widget", style="top_bar_fill"}
    bottom_bar.add{type="button", tags={func="complex_test"}, caption={"complex.test"}}
    bottom_bar.add{type="button", tags={func="complex_write"}, caption={"complex.write"}}
    bottom_bar.add{type="button", tags={func="complex_finish"}, caption={"complex.finish"}}
end

Events.text_changed.update_complex_floors = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)

    if number == nil or number <= 0 then number = 1 end

    window.complex.floors = number
    update_size(window)
    update_craft_list(window)
end

Events.text_changed.update_complex_speed = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then
        local temp1, temp2 = string.match(event.element.text, "(%d*%.?%d+)/(%d*%.?%d+)")
        if temp1 ~= nil and temp2 ~= nil then
            number = tonumber(temp1) / tonumber(temp2)
        end
    end

    if number == nil or number < 1/60 or number == math.huge then number = 1 end

    selected_recipe(window).time = number
    update_in_out_list(window)
end

Events.selection_state_changed.no_select = function(event)
    event.element.selected_index = 0
end

Events.text_changed.update_complex_name = function(event)
    window(event).complex.name = event.element.text
end

Events.elem_changed.graphics_update = function(event)
    window(event).complex.graphics = event.element.elem_value
end

Events.selection_state_changed.factory_list_select = function(event)
    -- game.print("complex_factory_list")
    local window = window(event)

    if window.fuel_factory_component_list ~= nil then
        window.fuel_factory_component_list.selected_index = 0
    end

    window.selected_factory_type = "normal"
    window.selected_factory = window.complex.factories[window.factory_indexes[window.factory_list.selected_index]]
    factory_editor(window)
end

Events.gui_click.complex_write = function(event)
    local window = window(event)
    local err, error = window.complex:check_error()

    if err then
        Gui_Lib.error_window(event.player_index, error)
    else
        File_Writer.complex(
            event.player_index,
            window.complex
        )
    
        Gui_Lib.close(event.player_index, "complex_window")
    end
end

Events.gui_click.complex_test = function(event)
    local window = window(event)
    local err, error = window.complex:check_error()

    if err then
        Gui_Lib.error_window(event.player_index, error)
    end
end

Events.gui_click.complex_finish = function(event)
    local player_global = player_global(event)

    -- game.print("1:" .. serpent.block(player_global.complex_window.complex, {maxlevel=1}))
    table.insert(
        player_global.mod_window.mod.complexes,
        player_global.complex_window.complex
    )
    -- game.print("2:" .. serpent.block(player_global.mod_window.mod.complexes[#player_global.mod_window.mod.complexes], {maxlevel=1}))

    Gui_Lib.close(event.player_index, "complex_window")
end

Events.gui_click.remove_factory = function(event)
    local window = window(event)

    if window.selected_factory_type == "normal" then
        window.complex:remove_factory(window.factory_indexes[window.factory_list.selected_index])

        window.factory_editor.destroy()

        sub_factory_editor(window)
        update_factory_list(window)
        update_craft_list(window)
        update_in_out_list(window)
    else
        local index = window.fuel_factory_component_list.selected_index

        selected_factory(window):remove_fuel(window.recipe_list.selected_index, index)
        update_fuel_factory_component_list(window)
        window.fuel_factory_component_list.selected_index = index - 1
    end
end

---------------------------------------------  Public Functions  ---------------------------------------------
Complex_Ui = {
    add_planner_button = add_planner_button,
    open_complex = open_complex,
    close_complex = close_complex,
}