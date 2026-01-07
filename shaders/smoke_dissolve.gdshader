shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float pixel_size = 2.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(TEXTURE, 0));
	float px = max(pixel_size, 1.0);
	vec2 grid = floor(UV * tex_size / px);
	float rnd = hash21(grid);
	float mask = step(rnd, reveal);
	vec2 sample_uv = (grid * px + px * 0.5) / tex_size;
	vec4 col = texture(TEXTURE, sample_uv);
	COLOR = vec4(col.rgb, col.a * mask);
}
