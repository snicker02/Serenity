shader_type canvas_item;

// The shader asks: "Is there a wall here?"
uniform sampler2D mask_texture;

void fragment() {
    // 1. Get the color of the line we are drawing
    vec4 current_color = texture(TEXTURE, UV);

    // 2. Look at the mask texture at this screen position
    vec4 mask_color = texture(mask_texture, SCREEN_UV);

    // 3. If the mask is White (Wall), make our line Invisible
    if (mask_color.r > 0.5) {
        current_color.a = 0.0;
    }

    COLOR = current_color;
}