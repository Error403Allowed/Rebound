shader_type canvas_item;
render_mode unshaded;
uniform float motion = 1.0;
void fragment() {
    vec2 p = UV;
    float time = TIME * 0.12 * motion;
    vec2 a = vec2(0.2 + 0.08 * sin(time), 0.32);
    vec2 b = vec2(0.8, 0.7 + 0.08 * cos(time));
    vec3 color = vec3(0.012, 0.023, 0.045);
    color += vec3(0.02, 0.21, 0.16) * exp(-7.0 * distance(p, a));
    color += vec3(0.13, 0.05, 0.25) * exp(-6.0 * distance(p, b));
    color += vec3(0.025, 0.08, 0.15) * exp(-5.0 * distance(p, vec2(0.7, 0.15)));
    COLOR = vec4(color, 1.0);
}
