shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert;

uniform vec3 color_base : source_color = vec3(0.10, 0.30, 0.06);
uniform vec3 color_tip  : source_color = vec3(0.50, 0.78, 0.22);
uniform float blade_height = 0.6;
uniform float wind_strength = 0.25;
uniform float wind_speed = 1.5;
uniform float wind_scale = 0.3;

varying float v_height;

void vertex() {
    v_height = clamp(VERTEX.y / blade_height, 0.0, 1.0);

    // Each blade's world position (so neighbours sway out of sync)
    vec3 origin = MODEL_MATRIX[3].xyz;
    float wave = sin(TIME * wind_speed + (origin.x + origin.z) * wind_scale);
    wave += 0.5 * sin(TIME * wind_speed * 2.3 + origin.x * 0.7);

    // Tip moves most, base stays planted
    VERTEX.x += wave * wind_strength * v_height * v_height;

    // Make lighting match the ground, so the grass blends in
    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    ALBEDO = mix(color_base, color_tip, v_height);
    ROUGHNESS = 1.0;
}