
local name = "complex-assembler"

data:extend({
    Generate.entity({
        basic = {
            crafting_categories = {"complexAssembler"},
        },
        name = name,
        size = { 6, 6 },
    }),
    Generate.item({
        name = name,
    }),
    Generate.recipe({
        basic = {
            category = "crafting-with-fluid",
        },
        complex = {
            name = name,
            time = 10,
        },
    }),
    Generate.recipe_category({
        name = "complexAssembler",
    })
})