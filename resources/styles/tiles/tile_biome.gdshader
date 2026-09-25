shader_type spatial;

// Textura de casilla. Todo en espacio mundo: no depende de las UV del .glb y
// las casillas vecinas del mismo bioma casan sin costuras.
// `biome` sigue el orden de Tile.biome_type.
// Con `use_texture` el detalle sale de una imagen (media gris 0.5, se tiñe con
// `tint`); sin ella, de un patrón procedural por bioma.

uniform vec4 tint : source_color = vec4(1.0);
uniform int biome = 0;
// 1 = textura completa (modo Biomas); en los demás modos se atenúa para que
// el color del modo mande.
uniform float detail : hint_range(0.0, 1.0) = 1.0;
uniform float hex_radius = 1.0;
// Altura local (sobre el centro de la casilla) a partir de la cual nieva en la montaña.
uniform float snow_line = 0.5;
uniform float bump_strength = 0.6;
uniform bool use_texture = false;
// Sin source_color: es un multiplicador (media 0.5), no un color sRGB.
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
// Repeticiones de la imagen por unidad de mundo (radio de casilla = 1).
uniform float tex_scale = 0.2;

varying vec3 world_pos;
varying vec3 local_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

// Distancia al punto de rejilla aleatorio más cercano (ruido celular): copas de árbol.
float cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
			d = min(d, length(g + o - f));
		}
	}
	return d;
}

// 0 en el centro del hexágono (lados planos arriba/abajo), 1 en el borde.
float hex_dist(vec2 p) {
	p = abs(p) / hex_radius;
	return max(p.y, p.x * 0.866025 + p.y * 0.5) / 0.866025;
}

// Devuelve el factor de brillo (≈1) que modula `tint`, y la rugosidad en .y.
vec2 biome_pattern(vec2 p, float y) {
	switch (biome) {
		case 0: { // Pradera: manchas suaves + motas de hierba
			float n = fbm(p * 3.0);
			float tufts = smoothstep(0.5, 0.75, fbm(p * 12.0));
			return vec2(0.6 + 0.6 * n + 0.2 * tufts, 0.9);
		}
		case 1: { // Bosque: copas redondeadas, huecos oscuros entre ellas
			float crown = 1.0 - smoothstep(0.0, 0.55, cells(p * 5.0));
			float clump = fbm(p * 1.5);
			return vec2(0.5 + 0.8 * crown * (0.6 + clump) + 0.1 * noise(p * 20.0), 0.95);
		}
		case 2: { // Desierto: dunas onduladas
			float warp = fbm(p * 1.2) * 5.0;
			float dune = sin(p.x * 7.0 + p.y * 3.0 + warp) * 0.5 + 0.5;
			return vec2(0.8 + 0.3 * dune * dune + 0.06 * noise(p * 30.0), 0.85);
		}
		case 3: { // Pantano: charcos oscuros y brillantes sobre fondo turbio
			float n = fbm(p * 2.6);
			float pool = smoothstep(0.5, 0.56, n);
			float reeds = step(0.78, noise(p * 26.0)) * (1.0 - pool);
			float moss = 1.0 + 2.5 * fbm(p * 7.0);
			return vec2(mix(moss, 0.6, pool) - 0.4 * reeds, mix(0.9, 0.15, pool));
		}
		case 4: { // Tundra: placas de nieve sobre tierra helada
			float n = fbm(p * 1.8);
			float snow = smoothstep(0.5, 0.58, n);
			return vec2(0.85 + 0.12 * fbm(p * 8.0) + 0.35 * snow, 0.8);
		}
		case 5: { // Océano: oleaje animado con crestas claras
			float t = TIME * 0.15;
			float w = fbm(p * 2.2 + vec2(t, t * 0.6)) + fbm(p * 4.0 - vec2(t * 0.8, 0.0));
			float crest = smoothstep(1.05, 1.2, w);
			return vec2(0.85 + 0.15 * w * 0.5 + 0.2 * crest, 0.35);
		}
		default: { // Montaña: vetas de roca y nieve en las cumbres
			float strata = sin(y * 20.0 + fbm(p * 2.0) * 6.0) * 0.5 + 0.5;
			float rock = 0.7 + 0.25 * strata + 0.25 * fbm(p * 9.0);
			float snow = smoothstep(snow_line, snow_line + 0.08, y + 0.1 * fbm(p * 5.0));
			return vec2(mix(rock, 2.3, snow), 0.95);
		}
	}
	return vec2(1.0, 0.9);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local_pos = world_pos - NODE_POSITION_WORLD;
}

// Proyección triplanar: laderas y laterales no se estiran.
vec3 triplanar(sampler2D tex, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= w.x + w.y + w.z;
	return texture(tex, p.zy).rgb * w.x + texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z;
}

void fragment() {
	vec2 p = world_pos.xz;
	float h = hex_dist(local_pos.xz);
	vec3 n_world = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// Bisel: oscurece el último tramo hacia el borde para marcar la casilla.
	float bevel = 1.0 - 0.25 * smoothstep(0.78, 1.0, h);

	if (use_texture) {
		vec3 tex = triplanar(detail_tex, world_pos * tex_scale, n_world) * 2.0;
		ALBEDO = tint.rgb * mix(vec3(1.0), tex, detail) * bevel;
		ROUGHNESS = 0.9;
		if (n_world.y > 0.9 && detail > 0.0) {
			// Normal GL: verde = "arriba" de la imagen = -V = -Z en mundo.
			vec3 nt = texture(normal_tex, p * tex_scale).rgb * 2.0 - 1.0;
			vec3 bumped = normalize(mix(vec3(0.0, 1.0, 0.0), vec3(nt.x, nt.z, -nt.y), detail));
			NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
		}
	} else {
		vec2 pat = biome_pattern(p, local_pos.y);
		float shade = mix(1.0, pat.x, detail) * bevel;
		ALBEDO = tint.rgb * shade;
		ROUGHNESS = mix(0.9, pat.y, detail);

		// Relieve: el propio patrón hace de mapa de alturas. Solo en caras que
		// miran hacia arriba; en laterales y laderas el gradiente en XZ no vale.
		if (n_world.y > 0.9 && detail > 0.0) {
			float e = 0.03;
			float dx = biome_pattern(p + vec2(e, 0.0), local_pos.y).x - pat.x;
			float dz = biome_pattern(p + vec2(0.0, e), local_pos.y).x - pat.x;
			float k = bump_strength * detail / e * 0.05;
			vec3 bumped = normalize(vec3(-dx * k, 1.0, -dz * k));
			NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);
		}
	}
}
