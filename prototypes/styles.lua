local styles = data.raw["gui-style"].default

styles.top_bar_fill = {
    type = "empty_widget_style",
    parent = "draggable_space",
    horizontally_stretchable = "on",
    height = 24,
}

styles.stretch_box = {
    type = "list_box_style",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
}