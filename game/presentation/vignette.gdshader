shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 point = (UV - vec2(0.5)) * vec2(1.0, 0.83);
	float edge = smoothstep(0.23, 0.64, length(point));
	COLOR = vec4(0.016, 0.009, 0.04, edge * 0.38);
}
