shader_type canvas_item;

uniform vec4 color_top : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.78, 0.42, 0.0, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// COLOR refleja font_color (blanco = alta luminancia) para el pase del texto
	// y outline_color (marrón oscuro = baja luminancia) para el pase del outline.
	// Usamos luminancia para distinguirlos y aplicar el gradiente solo al texto.
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	if (lum > 0.5) {
		// Pase de texto → aplicar gradiente dorado
		vec4 gradient = mix(color_top, color_bottom, UV.y);
		COLOR = vec4(gradient.rgb, tex.a);
	} else {
		// Pase de outline → mantener el color oscuro original
		COLOR = vec4(COLOR.rgb, tex.a);
	}
}
