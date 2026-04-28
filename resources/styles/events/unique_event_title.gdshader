shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.78, 0.42, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 gradient = mix(color_top, color_bottom, UV.y);
	COLOR = vec4(gradient.rgb, tex.a);
}
