shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 rect_size = vec2(1000.0, 700.0);
uniform float corner_radius = 24.0;
void fragment() {
    vec2 half_size = rect_size * 0.5;
    vec2 local = (UV - vec2(0.5)) * rect_size;
    vec2 q = abs(local) - half_size + vec2(corner_radius);
    float distance_to_edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
    float mask = 1.0 - smoothstep(-1.0, 1.0, distance_to_edge);
    vec2 bend = normalize(local + vec2(0.001)) * exp(-abs(distance_to_edge) / 18.0) * 0.0012;
    vec3 blurred = textureLod(screen_texture, SCREEN_UV + bend, 3.0).rgb;
    float highlight = pow(1.0 - UV.y, 3.0) * 0.055;
    vec3 glass = mix(blurred, vec3(0.035, 0.055, 0.085), 0.76) + highlight;
    float rim = 1.0 - smoothstep(0.5, 2.0, abs(distance_to_edge + 1.5));
    glass += rim * mix(vec3(0.06, 0.09, 0.13), vec3(0.18, 0.26, 0.3), 1.0 - UV.y);
    COLOR = vec4(glass, mask * 0.98);
}
