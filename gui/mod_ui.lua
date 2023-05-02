require("scripts.file_writer")
require("gui.complex_ui")
require("gui.gui_lib")
require("scripts.complex")
local mod_gui = require("mod-gui")

local function window(event)
    return global.players[event.player_index].mod_window
end

local function add_planner_button(player)
    local button_flow = mod_gui.get_button_flow(player)
    button_flow.add{type="sprite-button", tags={func="open_mod_planner"}, sprite="entity/assembling-machine-3", style=mod_gui.button_style}
end

local function update_complex_list(window)
    window.complex_list.clear_items()

    for _, complex in pairs(window.mod.complexes) do
        window.complex_list.add_item(complex.name)
    end
end

local function selected_complex(window)
    return window.mod.complexes[window.complex_list.selected_index]
end

local function complex_editor(window)
    if window.editor_box ~= nil then window.editor_box.destroy() end
    if selected_complex(window) == nil then return end

    local editor_box = window.main_box.add{type="flow", direction="vertical"}
    window.editor_box = editor_box

    editor_box.add{type="label", caption={"complex.complex-editor"}}

    Gui_Lib.add_name_box(
        editor_box,
        "complex.complex-name",
        selected_complex(window).name,
        "update_mod_complex_name"
    )

    local button_box = editor_box.add{type="flow", direction="horizontal"}
    button_box.add{type="button", tags={func="remove_complex"}, caption={"complex.remove"}}
    button_box.add{type="button", tags={func="edit_complex"}, caption={"complex.edit"}}
end

Events.text_changed.update_mod_complex_name = function(event)
    local window = window(event)
    selected_complex(window).name = event.element.text
    window.complex_list.set_item(window.complex_list.selected_index, event.element.text)
end

Events.gui_click.remove_complex = function(event)
    local window = window(event)
    table.remove(window.mod.complexes, window.complex_list.selected_index)
    update_complex_list(window)
    complex_editor(window)
end

Events.gui_click.edit_complex = function(event)
    local window = window(event)
    p_index = event.player_index

    local complex = selected_complex(window)
    global.players[p_index].complex_window.complex = complex
    Gui_Lib.close(p_index, "mod_window")

    Complex_Ui.open_complex(p_index)
end

local function open_mod(player_index)
    local player_global = global.players[player_index]
    local window = player_global.mod_window
    if window.window ~= nil then return end
    local window_name = "mod_window"

    local top_flow = Gui_Lib.create_window(player_index, window_name)

    Gui_Lib.add_name_box(
        top_flow,
        "complex.mod-name",
        window.mod.name,
        "update_mod_name"
    )

    local main_box = top_flow.add{type="flow", name="mod_main_box", direction="horizontal"}
    window.main_box = main_box

    window.complex_list = Gui_Lib.add_labeled_list(main_box, "complex.complex-list", "complex_complex_list")
    update_complex_list(window)

    main_box.add{type="flow", name="mod_info_box", direction="vertical"}

    local bottom_bar = top_flow.add{type="flow", name="complex_controls_flow", direction="horizontal"}
    bottom_bar.add{type="button", tags={func="clear_complexes"}, caption={"complex.clear-complexes"}}
    bottom_bar.add{type="empty-widget", style="top_bar_fill"}
    bottom_bar.add{type="button", tags={func="mod_finish"}, caption={"complex.write"}}
end

Events.text_changed.update_mod_name = function(event)
    window(event).mod.name = event.element.text
end

Events.gui_click.open_mod_planner = function(event)
    open_mod(event.player_index)
end

Events.selection_state_changed.complex_complex_list = function(event)
    complex_editor(window(event))
end

Events.gui_click.clear_complexes = function(event)
    window(event).mod.complexes = {}
    Gui_Lib.close(event.player_index, "mod_window")
end

Events.gui_click.mod_finish = function(event)
    local window = window(event)

    if window.mod.name == nil or window.mod.name == "" then
        Gui_Lib.error_window(event.player_index, {"mod-name"})
        return
    end

    for index, complex in pairs(window.mod.complexes) do
        local err, error = complex:check_error()

        if err then
            if error[1] == "complex-name" then
                table.insert(error, index)
            else
                table.insert(error, 2, complex.name)
            end
            error[1] = "mod-" .. error[1]
            
            Gui_Lib.error_window(event.player_index, error)
            return
        end
    end

    File_Writer.mod(event.player_index, window.mod)
    Gui_Lib.close(event.player_index, "mod_window")
end

Mod_Ui = {
    open_mod = open_mod,
    add_planner_button = add_planner_button,
}