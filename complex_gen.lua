Complex_Gen = {}

local function scale_box(entity, type, scale)
    entity[type][1][1] = entity[type][1][1] * scale
    entity[type][1][2] = entity[type][1][2] * scale
    entity[type][2][1] = entity[type][2][1] * scale
    entity[type][2][2] = entity[type][2][2] * scale
end

local function scale_animation(animation, scale)
    local current_scale = animation.scale
    if current_scale == nil then current_scale = 1 end
    animation.scale = current_scale * scale

    if animation.hr_version ~= nil then
        local current_scale = animation.hr_version.scale
        if current_scale == nil then current_scale = 1 end
        animation.hr_version.scale = current_scale * scale
    end
end

local function scale_layers(anim, scale)
    if anim.layers then
        for _, layer in pairs(anim.layers) do
            scale_animation(layer, scale)
        end
    else
        scale_animation(anim, scale)
    end
end

function Complex_Gen.scale_graphics(entity, size)
    local scale = size.x / math.ceil(entity.selection_box[2][1] - entity.selection_box[1][1])

    if entity["drawing_box"] ~= nil then scale_box(entity, "drawing_box", scale) end

    entity.selection_box[2][1] = size.x / 2
    entity.selection_box[2][2] = size.y / 2
    entity.selection_box[1][1] = -entity.selection_box[2][1]
    entity.selection_box[1][2] = -entity.selection_box[2][2]
    
    entity.collision_box = entity.selection_box
    entity.collision_box[1][1] = entity.collision_box[1][1] + 0.3
    entity.collision_box[1][2] = entity.collision_box[1][2] + 0.3
    entity.collision_box[2][1] = entity.collision_box[2][1] - 0.3
    entity.collision_box[2][2] = entity.collision_box[2][2] - 0.3
    -- scale_box(entity, "collision_box", scale)
    
    local anim = entity.animation
    if not anim then
        entity.animation = entity.picture
        anim = entity.animation
    end
    if anim.layers or anim.size then scale_layers(anim, scale) end
    if anim.east                then scale_layers(anim.east, scale) end
    if anim.north               then scale_layers(anim.north, scale) end
    if anim.south               then scale_layers(anim.south, scale) end
    if anim.west                then scale_layers(anim.west, scale) end

    if entity.water_reflection then
        local current_scale = entity.water_reflection.scale
        if not current_scale then current_scale = 1 end
        entity.water_reflection.scale = current_scale * scale
    end

    if entity.working_visualisations ~= nil then
        local working = entity.working_visualisations
        if working.animation        then scale_animation(working.animation, scale) end
        if working.east_animation   then scale_animation(working.east_animation, scale) end
        if working.north_animation  then scale_animation(working.north_animation, scale) end
        if working.south_animation  then scale_animation(working.south_animation, scale) end
        if working.west_animation   then scale_animation(working.west_animation, scale) end
    end
end

local north = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pictures.up)
north.shift = {0, 1}
north.priority = "high"
north.hr_version.shift = {0, 1}
north.hr_version.priority = "high"

local south = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pictures.down)
south.shift = {0, -1}
south.priority = "high"
south.hr_version.shift = {0, -1}
south.hr_version.priority = "high"

local west = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pictures.left)
west.shift = {1, 0}
west.priority = "high"
west.hr_version.shift = {1, 0}
west.hr_version.priority = "high"

local east = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pictures.right)
east.shift = {-1, 0}
east.priority = "high"
east.hr_version.shift = {-1, 0}
east.hr_version.priority = "high"

Complex_Gen.pipe_pictures = {
    north = north,
    south = south,
    west = west,
    east = east,
}

function Complex_Gen.pipe_connection(input)
    local base_level
    local symbol
    
    if input.type == "input" then
        base_level = -1
        symbol = "input"
    else
        base_level = 1
        symbol = "output"
    end

    if input.passthrough then
        base_level = 0
        symbol = "input-output"
    end

    pipe_connections = {}

    for _, connection in pairs(input.connections) do
        table.insert(pipe_connections, {type=symbol, position=connection})
    end

    return {
        base_area = input.area,
        base_level = base_level,
        pipe_connections = pipe_connections,
        pipe_covers = pipecoverspictures(),
        pipe_picture = Complex_Gen.pipe_pictures,
        render_layer = "lower-object-above-shadow",
        production_type = input.type
    }
end

function Complex_Gen.update_complex_assembler(recipe)

end