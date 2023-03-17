require("scripts.file_writer")
require("gui.gui_lib")

local function player(event)
    return game.get_player(event.player_index)
end

local function player_global(event)
    return global.players[event.player_index]
end

local function window(event)
    return global.players[event.player_index].complex_window
end

local function update_factory_list(window)
    local factory_list = window.factory_list

    factory_list.clear_items()
    -- game.print("update" .. serpent.block(player_global.complex.recipes))
    local data = window.complex:fancy_names()
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
end

local function update_in_out_list(window)
    input_list = window.input_list
    output_list = window.output_list

    local in_out_list = window.complex:get_recipe()

    input_list.clear_items()
    for name, data in pairs(in_out_list.input) do
        input_list.add_item("[" .. data.type .. "=" .. name .. "]: " .. data.amount)
    end

    output_list.clear_items()
    for name, data in pairs(in_out_list.output) do
        output_list.add_item("[" .. data.type .. "=" .. name .. "]: " .. data.amount)
    end
end

local function get_current_factory(window)
    local indexes = window.factory_indexes
    if indexes == nil then return nil end

    local selected = window.factory_list
    if selected == nil or selected.selected_index == 0 then return nil end

    window.selected_factory = window.complex.factories[indexes[selected.selected_index]]

    return window.selected_factory
end

local function factory_editor(window)
    if window.factory_editor ~= nil then
        window.factory_editor.destroy()
    end

    local factory = get_current_factory(window)
    if factory == nil then return end

    -- game.print("test: " .. serpent.block(factory))

    local top = window.top_box.add{type="flow", direction="vertical"}

    top.add{type="label", caption={"complex.factory-editor"}}

    local count = top.add{type="flow", direction="horizontal"}
    count.add{type="label", caption={"complex.factory-editor-count"}}
    count.add{type="textfield", tags={func="factory_editor_count"}, text=tostring(factory.count), numeric=true}

    local clock = top.add{type="flow", direction="horizontal"}
    clock.add{type="label", caption={"complex.factory-editor-clock"}}
    window.factory_editor_clock = clock.add{type="textfield", tags={func="factory_editor_clock"}, text=tostring(factory.modifiers.clock), numeric=true, allow_decimal=true}

    local current_filter = {
        input = {},
        output = {},
    }

    if factory.match then
        local clock = top.add{type="flow", direction="horizontal"}
        clock.add{type="label", caption={"complex.factory-editor-level"}}
        clock.add{type="textfield", tags={func="factory_editor_level"}, text=tostring(factory.match.level), numeric=true}

        current_filter[factory.match.type][factory.match.item_type] = factory.match.item_name
    end

    local possible_filters = {
        input = {item={}, fluid={}},
        output = {item={}, fluid={}},
    }

    for name, data in pairs(factory.recipe.input) do
        table.insert(possible_filters.input[data.type], name)
    end
    for name, data in pairs(factory.recipe.output) do
        table.insert(possible_filters.output[data.type], name)
    end

    local input = top.add{type="flow", direction="horizontal"}
    input.add{type="label", caption={"complex.factory-editor-match-input"}}
    input.add{type="label", caption={"complex.factory-editor-match-item"}}
    window.factory_editor_input_item = input.add{
        type="choose-elem-button",
        tags={func="match_update", type="input_item"},
        elem_type="item",
        item=current_filter.input.item,
        elem_filters={{filter="name", name=possible_filters.input.item}}
    }
    input.add{type="label", caption={"complex.factory-editor-match-fluid"}}
    window.factory_editor_input_fluid = input.add{
        type="choose-elem-button",
        tags={func="match_update", type="input_fluid"},
        elem_type="fluid",
        fluid=current_filter.input.fluid,
        elem_filters={{filter="name", name=possible_filters.input.fluid}}
    }

    local output = top.add{type="flow", direction="horizontal"}
    output.add{type="label", caption={"complex.factory-editor-match-output"}}
    output.add{type="label", caption={"complex.factory-editor-match-item"}}
    window.factory_editor_output_item = output.add{
        type="choose-elem-button",
        tags={func="match_update", type="output_item"},
        elem_type="item",
        item=current_filter.output.item,
        elem_filters={{filter="name", name=possible_filters.output.item}}
    }
    output.add{type="label", caption={"complex.factory-editor-match-fluid"}}
    window.factory_editor_output_fluid = output.add{
        type="choose-elem-button",
        tags={func="match_update", type="output_fluid"},
        elem_type="fluid",
        fluid=current_filter.output.fluid,
        elem_filters={{filter="name", name=possible_filters.output.fluid}}
    }

    top.add{type="button", tags={func="remove_factory"}, caption={"complex.remove_factory"}}
    
    window.factory_editor = top
end

Events.gui_click.remove_factory = function(event)
    local window = window(event)
    window.complex.factories[window.factory_indexes[window.factory_list.selected_index]] = nil

    window.factory_editor.destroy()
    update_factory_list(window)
    update_craft_list(window)
    update_in_out_list(window)
end

Events.text_changed.factory_editor_count = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    window.selected_factory.count = number
    update_craft_list(window)
    update_in_out_list(window)
end

Events.text_changed.factory_editor_clock = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    if number > 1 then number = 1 end
    window.selected_factory.modifiers.clock = number
    update_in_out_list(window)
end

Events.text_changed.factory_editor_level = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    if number == 0 then number = 1 end
    window.selected_factory.match.level = number
    update_in_out_list(window)
end

Events.elem_changed.match_update = function(event)
    local window = window(event)
    local element = event.element
    local type = element.tags.type

    local info = {
        input_item   = {clear = true, type = "input"},
        input_fluid  = {clear = true, type = "input"},
        output_item  = {clear = true, type = "output"},
        output_fluid = {clear = true, type = "output"},
    }

    info[type].clear = false

    for name, data in pairs(info) do
        local elem = window["factory_editor_" .. name]

        if data.clear then
            elem.elem_value = nil
        end
    end

    if element.elem_value then
        local level = 1
        if window.selected_factory.match ~= nil then
            level = window.selected_factory.match.level
        end

        window.selected_factory.match = {
            type = info[type].type,
            item_name = element.elem_value,
            item_type = element.elem_type,
            level = level,
        }
    else
        window.selected_factory.match = nil
    end
    
    update_in_out_list(window)
    window.factory_editor_clock.text = tostring(window.selected_factory.modifiers.clock)
    factory_editor(window)
end

local function pipe_editor(window)
    if window.pipe_editor ~= nil then
        window.pipe_editor.destroy()
        window.pipe_editor = nil
    end

    local fluids = window.complex:get_fluids()
    if #fluids.input == 0 and #fluids.output == 0 then return end
    window.pipe_config_index = {}

    local top = window.top_box.add{type="flow", direction="vertical"}
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

    top.add{type="label", caption={"complex.pipe-editor-pipe-connections"}}
    top.add{type="drop-down", tags={func="pipe_editor_connection_list_update"}}

    local buttons = top.add{type="flow", direction="horizontal"}
    buttons.add{type="button", caption={"complex.pipe-editor-add"}, tags={func="pipe_editor_add_connection"}}
    buttons.add{type="button", caption={"complex.pipe-editor-remove"}, tags={func="pipe_editor_remove_connection"}}

    window.pipe_editor_buttons = {}

    top.add{type="label", caption={"complex.pipe-editor-side"}}
    window.pipe_editor_buttons.top = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-top", {func="pipe_editor_side_update", side="top"})
    window.pipe_editor_buttons.left = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-left", {func="pipe_editor_side_update", side="left"})
    window.pipe_editor_buttons.right = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-right", {func="pipe_editor_side_update", side="right"})
    window.pipe_editor_buttons.bottom = Gui_Lib.add_labeled_radiobutton(top, "complex.pipe-editor-bottom", {func="pipe_editor_side_update", side="bottom"})

    top.add{type="label", caption={"complex.pipe-editor-position"}}
    top.add{type="textfield", style="stretchable_textfield", text="0", {func="pipe_editor_position_update"}, numeric=true}
end

local function sub_factory_editor(window)
    if window.complex:multiple_recipes() == false then
        if window.sub_factory_editor ~= nil then
            window.sub_factory_editor.destroy()
            window.sub_factory_editor = nil
        end
        return
    end

    if window.sub_factory_editor ~= nil then
        local sub_factory_editor = window.bottom_box.add{type="flow", direction="vertical"}
        window.sub_factory_editor = sub_factory_editor

        local recipe_box = sub_factory_editor.add{type="flow", direction="horizontal"}
        local bottom_box = sub_factory_editor.add{type="flow", direction="horizontal"}

        Gui_Lib.add_name_box(
            recipe_box,
            "complex.complex-recipe-name",
            "fix me!",
            "update_recipe_name"
        )
        Gui_Lib.add_name_box(
            recipe_box,
            "complex.complex-speed",
            tostring(window.complex.time),
            "update_complex_speed"
        )
    end

    


end



local function open_complex(player_index)
    local window = global.players[player_index].complex_window
    if window.window ~= nil then return end

    local window_name = "complex_window"
    local top_flow = Gui_Lib.create_window(player_index, window_name)
    window.top_flow = top_flow

    Gui_Lib.add_name_box(
        top_flow,
        "complex.complex-name",
        window.complex.name,
        "update_complex_name"
    )

    if window.complex:multiple_recipes() == false then
        Gui_Lib.add_name_box(
            top_flow,
            "complex.complex-speed",
            tostring(window.complex.time),
            "update_complex_speed"
        )
    end

    local top_box = top_flow.add{type="flow", direction="horizontal"}
    window.top_box = top_box

    window.factory_list = Gui_Lib.add_labeled_list(top_box, "complex.factory-list", "factory_list_select")
    update_factory_list(window)

    window.craft_list = Gui_Lib.add_labeled_list(top_box, "complex.craft-list", "no_select")
    update_craft_list(window)

    window.input_list = Gui_Lib.add_labeled_list(top_box, "complex.input-list", "no_select")
    window.output_list = Gui_Lib.add_labeled_list(top_box, "complex.output-list", "no_select")
    update_in_out_list(window)

    pipe_editor(window)

    local bottom_box = top_flow.add{type="flow", direction="vertical"}
    window.bottom_box = bottom_box

    sub_factory_editor(window)

    -- local factory_list = top_box.add{type="list-box", name="complex_factory_list", style="stretch_box"}

    local bottom_bar = top_flow.add{type="flow", direction="horizontal"}
    bottom_bar.add{type="empty-widget", style="top_bar_fill"}
    bottom_bar.add{type="button", tags={func="complex_write"}, caption={"complex.write"}}
    bottom_bar.add{type="button", tags={func="complex_finish"}, caption={"complex.finish"}}
end

Events.text_changed.update_complex_speed = function(event)
    local window = window(event)
    local number = tonumber(event.element.text)
    if number == nil then return end
    if number <= 0 then number = 1 end

    if window.complex:multiple_recipes() then

    else
        window.complex.time = number
    end
    
    update_in_out_list(window)
end

Events.selection_state_changed.no_select = function(event)
    event.element.selected_index = 0
end

Events.text_changed.update_complex_name = function(event)
    window(event).complex.name = event.element.text
end

Events.selection_state_changed.factory_list_select = function(event)
    -- game.print("complex_factory_list")
    factory_editor(window(event))
end

Events.gui_click.complex_write = function(event)
    File_Writer.mod(player(event), {name = "test", complexes = {global.players[event.player_index].complex_window.complex}})
    Gui_Lib.close(event.player_index, "complex_window")
end

Events.gui_click.complex_finish = function(event)
    local player_global = player_global(event)

    table.insert(
        player_global.mod.complexes,
        player_global.complex
    )

    Gui_Lib.close(event.player_index, "complex_window")
end


Complex_Ui = {
    add_planner_button = add_planner_button,
    open_complex = open_complex,
    close_complex = close_complex,
}