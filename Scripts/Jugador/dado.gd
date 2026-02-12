extends MeshInstance3D
class_name Dado


# ############################################################
# Variables
# ############################################################

@export var dice_speed: float = 3.5
@export var numero_caras: Array[Label3D] = []
@export var text_change_interval: float = 0.05
# Ajustes para el eje oscilante (estilo Mario Party)
@export var base_axis: Vector3 = Vector3(1, 0, 0)
@export var axis_amplitude: float = 1
@export var axis_frequency: float = 0.8
@export var particle: GPUParticles3D
var moving: bool = true
var _text_timer: float = 0.0
var _dice_time: float = 0.0
var _last_axis: Vector3 = Vector3.ZERO


# ############################################################
# Logica
# ############################################################

func _process(delta):
	_dice_time += delta
	# Calcular un eje oscilante a partir del eje base
	var offset_dir := base_axis.cross(Vector3.UP)
	if offset_dir.length() < 0.1:
		offset_dir = base_axis.cross(Vector3.FORWARD)
	offset_dir = offset_dir.normalized()
	var oscillation := offset_dir * sin(_dice_time * axis_frequency * TAU) * axis_amplitude
	var current_axis := (base_axis + oscillation).normalized()
	_last_axis = current_axis
	# Rotación por un ángulo proporcional a dice_speed
	rotate(current_axis, deg_to_rad(180) * dice_speed * delta)


	_text_timer += delta
	if _text_timer >= text_change_interval:
		_text_timer = 0.0
		for cara in numero_caras:
			var nuevo_numero := randi() % 6 + 1
			cara.text = str(nuevo_numero)

func dice_visibility(visible_state: bool = true, base_y: float = 0.0):
	self.visible = visible_state
	if not visible_state:
		reset_dice(base_y)
	else:
		# Scala de 0 a 1
		var tween := get_tree().create_tween()
		self.scale = Vector3.ZERO
		tween.tween_property(self , "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
func stop_dice(number: int):
	await get_tree().create_timer(0.4).timeout
	particle.emitting = true
	var base_y := position.y
	var tween := get_tree().create_tween()
	tween.tween_property(self , "position:y", base_y + 1, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	dice_visibility(false, base_y)
	# Detener la rotacion y mostrar el numero final
	self.rotation = Vector3.ZERO
	for cara in numero_caras:
		cara.text = str(number)

func reset_dice(base_y: float = 0.0):
	_text_timer = 0.0
	_dice_time = 0.0
	# Elegir un eje base aleatorio y añadir un pequeño sesgo para variar
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN, Vector3.BACK]
	base_axis = axes[randi() % axes.size()] + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.2
	base_axis = base_axis.normalized()
	_last_axis = base_axis
	position.y = base_y