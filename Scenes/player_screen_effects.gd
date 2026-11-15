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
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centre = uv - vec2(0.5);
	float radius = length(centre) * 2.0;
	float wobble = sin(time * 9.0 + radius * 16.0) * 0.0016;
	uv += normalize(centre + vec2(0.0001)) * wobble * distortion_strength;
	vec3 colour = texture(screen_texture, uv).rgb;
	float edge = smoothstep(0.45, 1.15, radius);
	float low = 1.0 - health_ratio;
	float vignette = edge * (0.22 * low + 0.55 * dead_amount);
	colour = mix(colour, vec3(0.55, 0.03, 0.03), clamp(vignette, 0.0, 1.0));
	float desaturate = clamp(0.22 * low + 0.75 * dead_amount, 0.0, 1.0);
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	colour = mix(colour, vec3(grey), desaturate);
	colour *= 1.0 - 0.22 * dead_amount - 0.07 * pulse * low;
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
	if bool(SettingsManager.get_value("reduced_motion")) or bool(SettingsManager.get_value("reduced_flashing")):
		material.set_shader_parameter("distortion_strength", 0.0)
		material.set_shader_parameter("pulse", 0.0)
		return
	var low := 1.0 - health_ratio
	var beat := 0.0
	if health_ratio < 0.35:
		var cycle := fmod(Time.get_ticks_msec() * 0.001, maxf(0.35, health_ratio * 1.7))
		beat = 1.0 - absf(cycle / maxf(0.35, health_ratio * 1.7) * 2.0 - 1.0)
		beat = pow(beat, 3.0)
	material.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)
	material.set_shader_parameter("pulse", beat)
	material.set_shader_parameter("distortion_strength", clampf(low * 0.7 + float(dead) * 0.3, 0.0, 1.0))
