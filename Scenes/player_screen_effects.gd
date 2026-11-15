extends CanvasLayer

var health_ratio := 1.0
var dead := false
var vignette: ColorRect
var pulse: ColorRect
var distortion: ColorRect
var material: ShaderMaterial

func _ready() -> void:
	layer = 20
	material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float dead_amount : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 1.0) = 0.0;
uniform float time = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
vec3 blur(sampler2D source, vec2 uv, float amount) {
	vec2 texel = vec2(1.0) / vec2(textureSize(source, 0));
	vec2 direction = vec2(1.0, 0.55) * texel * amount;
	vec3 colour = texture(source, uv).rgb * 0.28;
	colour += texture(source, uv + direction).rgb * 0.18;
	colour += texture(source, uv - direction).rgb * 0.18;
	colour += texture(source, uv + direction.yx).rgb * 0.18;
	colour += texture(source, uv - direction.yx).rgb * 0.18;
	return colour;
}
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centre = uv - vec2(0.5);
	float radius = length(centre) * 2.0;
	float low = 1.0 - health_ratio;
	float damage = clamp(max(low, dead_amount), 0.0, 1.0);
	float edge = smoothstep(0.18, 1.15, radius);
	float angle = atan(centre.y, centre.x);
	float sway = sin(time * 2.3 + radius * 4.0) * 0.0075;
	float roll = sin(time * 1.7) * 0.0055;
	float wobble = sin(time * 8.0 + radius * 17.0 + angle * 2.0) * 0.0038;
	vec2 dizzy = vec2(cos(angle), sin(angle)) * (sway + roll) + vec2(wobble, -wobble * 0.6);
	uv += dizzy * distortion_strength * (0.55 + edge * 0.45);
	float blur_amount = (0.9 * damage * (0.35 + edge * 0.65) + pulse * damage * 0.5) * distortion_strength;
	vec3 colour = blur(screen_texture, uv, blur_amount);
	float chroma = 0.0012 * damage * distortion_strength * (0.3 + edge);
	float red = texture(screen_texture, uv + vec2(chroma, 0.0)).r;
	float blue = texture(screen_texture, uv - vec2(chroma, 0.0)).b;
	colour.r = mix(colour.r, red, 0.55);
	colour.b = mix(colour.b, blue, 0.55);
	float vignette = edge * (0.35 * damage + 0.14 * pulse * damage + 0.55 * dead_amount);
	colour = mix(colour, vec3(0.55, 0.03, 0.03), clamp(vignette, 0.0, 1.0));
	float desaturate = clamp(0.22 * low + 0.75 * dead_amount, 0.0, 1.0);
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(grey), desaturate);
	colour *= 1.0 - 0.22 * dead_amount - 0.05 * pulse * damage;
	COLOR = vec4(colour, 1.0);
}
"""
	material.shader = shader
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	add_child(rect)

func update_health(ratio: float) -> void:
	health_ratio = clampf(ratio, 0.0, 1.0)
	material.set_shader_parameter("health_ratio", health_ratio)

func update_dead(amount: float) -> void:
	dead = amount >= 0.99
	material.set_shader_parameter("dead_amount", clampf(amount, 0.0, 1.0))

func _process(delta: float) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and (bool(settings.get_value("reduced_motion")) or bool(settings.get_value("reduced_flashing"))):
		material.set_shader_parameter("distortion_strength", 0.0)
		material.set_shader_parameter("pulse", 0.0)
		return
	var low := 1.0 - health_ratio
	var beat := 0.0
	if health_ratio < 0.55:
		var period := maxf(0.22, health_ratio * 1.9)
		var cycle := fmod(Time.get_ticks_msec() * 0.001, period)
		beat = 1.0 - absf(cycle / period * 2.0 - 1.0)
		beat = pow(beat, 1.6)
	material.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)
	material.set_shader_parameter("pulse", beat)
	material.set_shader_parameter("distortion_strength", clampf(smoothstep(0.15, 0.75, low) * 1.0 + float(dead) * 0.35, 0.0, 1.0))
