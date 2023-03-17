require("gui.gui_lib")
local mod_gui = require("mod-gui")

local function add_planner_button(player)
    local button_flow = mod_gui.get_button_flow(player)
    button_flow.add{type="sprite-button", tags={func="open_mod_planner"}, sprite="entity/assembling-machine-3", style=mod_gui.button_style}
end

local function open_mod(player_index)
    local player_global = global.players[player_index]
    if player_global.mod_window.window ~= nil then return end
    local window_name = "mod_window"

    local top_flow = Gui_Lib.create_window(player, player_global, window_name)

    Gui_Lib.add_name_box(
        top_flow,
        "complex.mod-name",
        player_global.mod.name,
        "update_mod_name"
    )

    local main_box = top_flow.add{type="flow", name="mod_main_box", direction="horizontal"}

    player_global.mod_window.complex_list = Gui_Lib.add_labeled_list(main_box, "complex.complex-list", "complex_complex_list")

    main_box.add{type="flow", name="mod_info_box", direction="vertical"}

    local bottom_bar = top_flow.add{type="flow", name="complex_controls_flow", direction="horizontal"}
    bottom_bar.add{type="empty-widget", style="top_bar_fill"}
    bottom_bar.add{type="button", tags={func="mod_finish"}, caption={"complex.write"}}
end

Events.text_changed.update_mod_name = function(event)
    global.players[event.player_index].mod.name = event.element.text
end

Events.gui_click.open_mod_planner = function(event)
    open_mod(event.player_index)
end

Events.gui_click.mod_finish = function(event)
    Gui_Lib.close(event.player_index, "mod_window")
end

Mod_Ui = {
    open_mod = open_mod,
    add_planner_button = add_planner_button,
}