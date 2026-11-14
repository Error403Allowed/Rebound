shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert;

uniform vec3 color_base : source_color = vec3(0.10, 0.30, 0.06);
uniform vec3 color_tip  : source_color = vec3(0.50, 0.78, 0.22);
uniform float blade_height = 0.6;
uniform float wind_strength = 0.25;
uniform float wind_speed = 1.5;
uniform float wind_scale = 0.3;

// each tuft picks a random distance inside these bands
uniform float grow_start = -10.0;
uniform float grow_end = -5.0;
uniform float fade_start = 14.0;
uniform float fade_end = 22.0;

varying float v_height;

void vertex() {
    v_height = clamp(VERTEX.y / blade_height, 0.0, 1.0);

    vec3 origin = MODEL_MATRIX[3].xyz;
    float wave = sin(TIME * wind_speed + (origin.x + origin.z) * wind_scale);
    wave += 0.5 * sin(TIME * wind_speed * 2.3 + origin.x * 0.7);
    VERTEX.x += wave * wind_strength * v_height * v_height;

    // random value per tuft, from its position
    float r = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);

    float d = distance(origin, CAMERA_POSITION_WORLD);
    float grow_at = mix(grow_start, grow_end, r);
    float fade_at = mix(fade_start, fade_end, r);

    // short 1.5m shrink so each tuft pops smoothly, at a different distance from its neighbours
    float s = smoothstep(grow_at, grow_at + 1.5, d) * (1.0 - smoothstep(fade_at - 1.5, fade_at, d));
    VERTEX *= s;

    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    ALBEDO = mix(color_base, color_tip, v_height);
    ROUGHNESS = 1.0;
}