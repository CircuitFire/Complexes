require("gui.complex_ui")
require("gui.mod_ui")
require("scripts.complex")

local function print_ent(entities)
    for index, entity in pairs(entities) do
        -- game.print(entity.name .. "\n  entity: " .. serpent.block(entity.get_recipe()))
        --game.print(entity.name .. "\n  size: " .. serpent.block(get_size(entity)))
    end
end

local function on_selected_area(event)
    --serpent.block(event)
    -- game.print("test:")
    -- local list = filter_entities(event.entities)
    -- print_ent(list)
    local player = game.get_player(event.player_index)
    player.clear_cursor()

    global.players[player.index].complex_window.complex = Complex:from_blueprint(event.entities)
    Complex_Ui.open_complex(player.index)
end

script.on_event(
    defines.events.on_player_selected_area,
    function(event)
        if event.item == "complex-planner" then
            on_selected_area(event)
        end
    end
)

local function init_player(player_index)
    if global.players[player_index] == nil then
        Mod_Ui.add_planner_button(game.get_player(player_index))

        global.players[player_index] = {
            mod = {
                name = "",
                complexes = {},
            },
            complex_window = {},
            mod_window = {},
        }
    end
end

local function full_init()
    if global.players == nil then
        global.players = {}
    end

    for _, player in pairs(game.players) do
        init_player(player.index)
    end
end

script.on_init(function()
    full_init()
end)

script.on_configuration_changed(function()
    full_init()
end)

script.on_event(defines.events.on_player_created, function(event)
    init_player(event.player_index)
end)

-- script.on_event(
--     defines.events.on_player_alt_selected_area,
--     function(event)
--         game.print("alt select")
--         if event.item == "complex-planner" then
--             on_selected_area(event)
--         end
--     end
-- )