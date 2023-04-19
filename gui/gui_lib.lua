
Events = {
    gui_click = {},
    text_changed = {},
    selection_state_changed = {},
    elem_changed = {},
    checked_state_changed = {},
    switch_state_changed = {},
}

local function handel_event(event, type)
    local func = Events[type][event.element.tags.func]
    if func ~= nil then func(event) end
end

script.on_event(defines.events.on_gui_click, function(event)
    handel_event(event, "gui_click")
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    handel_event(event, "text_changed")
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    handel_event(event, "selection_state_changed")
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    handel_event(event, "elem_changed")
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    handel_event(event, "checked_state_changed")
end)

script.on_event(defines.events.on_gui_switch_state_changed, function(event)
    handel_event(event, "switch_state_changed")
end)

Gui_Lib = {}

function Gui_Lib.add_top_bar(parent, window_name)
    local top_bar = parent.add{type="flow", direction="horizontal"}
    top_bar.add{type="label", caption={"complex." .. window_name}, style="frame_title"}
    top_bar.add{type="empty-widget", style="top_bar_fill"}
    top_bar.add{
        type="sprite-button",
        style="frame_action_button",
        sprite="utility/close_white",
        hovered_sprite="utility/close_black",
        clicked_sprite="utility/close_black",
        tags={func="close_button", window=window_name}
    }
end

function Gui_Lib.close(player_index, window_name)
    local window = global.players[player_index][window_name].window

    if window ~= nil then
        window.destroy()
        global.players[player_index][window_name].window = nil
    end
end

Events.gui_click.close_button = function(event)
    Gui_Lib.close(event.player_index, event.element.tags.window)
end

function Gui_Lib.create_window(player_index, name, size)
    local player = game.get_player(player_index)
    local player_global = global.players[player_index]
    if size == nil then size = {1500, 1000} end

    local screen_element = player.gui.screen
    local complex_window = screen_element.add{type="frame", name=name}
    complex_window.auto_center = true
    complex_window.style.size = size

    player_global[name].window = complex_window

    local top_flow = complex_window.add{type="flow", direction="vertical"}
    Gui_Lib.add_top_bar(top_flow, name)

    return top_flow
end

function Gui_Lib.add_name_box(parent, label, text, func)
    local name_flow = parent.add{type="flow", direction="horizontal"}
    name_flow.add{type="label", caption={"", {label}, ": "}}
    local complex_name = name_flow.add{type="textfield", text=text, style="stretchable_textfield", tags={func=func}}
end

function Gui_Lib.add_labeled_list(parent, label, func)
    local flow = parent.add{type="flow", direction="vertical"}
    flow.add{type="label", caption={label}}
    return flow.add{type="list-box", tags={func=func}, style="stretch_box"}
end

function Gui_Lib.add_labeled_radiobutton(parent, label, tags, state)
    local flow = parent.add{type="flow", direction="horizontal"}
    if state == nil then state = false end
    local button = flow.add{type="radiobutton", state=state, tags=tags}
    flow.add{type="label", caption={label}}
    return button
end

function Gui_Lib.error_window(player_index, message)
    local player = game.get_player(player_index)
    local player_global = global.players[player_index]
    size = {900, 300}

    local screen_element = player.gui.screen
    local complex_window = screen_element.add{type="frame", name="error"}
    complex_window.auto_center = true
    complex_window.style.size = size

    player_global["error"] = {
        window = complex_window
    }

    message[1] = "complex-error." .. message[1]

    local top_flow = complex_window.add{type="flow", direction="vertical"}
    top_flow.add{type="label", caption=message, style="frame_title"}
    top_flow.add{type="button", tags={func="close_button", window="error"}, caption={"complex.close"}}
end