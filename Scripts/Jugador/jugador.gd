extends CharacterBody3D
class_name Jugador


# Senales
# ---------------------------------------------------------------------------------------
signal stats_updated(jugador: Node3D)


# Variables
# ---------------------------------------------------------------------------------------

var nombre: String
var color: Color
var microchips: int = 20
var baterias: int = 0
var posicion_casilla: int = 0
var pf: PathFollow3D

var device_id = null
var speed: float = 4.0
var on_air: bool = false
@export var jump_duration: float = 0.5

var is_running: bool = false
var is_jumping: bool = false
var is_idling: bool = true
var is_walking: bool = false
var is_waving: bool = false
var is_hited: bool = false
var is_cheering: bool = false
var is_looking_at_camera: bool = false

var is_in_casilla: bool = false

@export var animation_tree: AnimationTree
@export var rotation_speed: float = 8.0
var last_pos := Vector3.ZERO

@export var area_3d: Area3D
var is_moved_out: bool = false
var moved_out_position: Vector3 = Vector3.ZERO
var moved_out_rotation: Vector3 = Vector3.ZERO

@export var number_label_3d: Label3D

@export var particle_get_diamante: GPUParticles3D
@export var particle_lose_diamante: GPUParticles3D

@export var player_mesh: Node3D


# Funciones Basicas
# ---------------------------------------------------------------------------------------

# Reset del transform
func _ready():
	last_pos = global_transform.origin
	return_player_mesh_height_offset()

# Controla la rotacion del jugador para que mire en la direccion a la que se esta moviendo
func _physics_process(delta):
	var current_pos = global_transform.origin
	var movement_dir = (current_pos - last_pos).normalized()

	if is_looking_at_camera:
		var cam = get_viewport().get_camera_3d()
		if cam:
			var target_pos = cam.global_transform.origin
			target_pos.y = global_transform.origin.y
			var direction = (target_pos - global_transform.origin).normalized()
			var target_rotation = Vector3(0, atan2(direction.x, direction.z), 0)
			var current_rotation = rotation
			current_rotation.y = lerp_angle(current_rotation.y, target_rotation.y, rotation_speed * delta)
			rotation = current_rotation
	else:
		if movement_dir.length() > 0.01:
			var target_rotation = Vector3(0, atan2(movement_dir.x, movement_dir.z), 0)
			var current_rotation = rotation
			current_rotation.y = lerp_angle(current_rotation.y, target_rotation.y, rotation_speed * delta)
			rotation = current_rotation
	
	last_pos = current_pos

# Inicializacion del Jugador con nombre y color
func _init(p_nombre: String = "", p_color: Color = Color.WHITE) -> void:
	nombre = p_nombre
	color = p_color

# Configura el Jugador
func configurar(p_nombre: String, p_color: Color) -> void:
	nombre = p_nombre
	color = p_color


# Estado del Jugador
# ---------------------------------------------------------------------------------------
#region
# Controla la visibilidad del numero asociado al jugador
func set_number_visibility_state(visible_state: bool) -> void:
	if not number_label_3d:
		return

	if visible_state:
		number_label_3d.visible = true
		number_label_3d.scale = Vector3.ZERO
		var t = create_tween()
		t.tween_property(number_label_3d, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		var t = create_tween()
		t.tween_property(number_label_3d, "scale", Vector3.ZERO, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		number_label_3d.visible = false

# Actualiza el numero de microchips con efecto visual
func establecer_microchips(cantidad: int, animar: bool = true) -> void:
	microchips = max(0, microchips + cantidad)
	await get_tree().create_timer(1).timeout
	if !animar:
		emit_signal("stats_updated", self )
		return
	if cantidad > 0:
		if particle_get_diamante:
			particle_get_diamante.amount = cantidad
			particle_get_diamante.emitting = true
			set_cheering_state(true)
	elif cantidad < 0:
		if particle_lose_diamante:
			await get_tree().create_timer(.8).timeout
			set_hited_state(true)
			await get_tree().create_timer(.15).timeout
			particle_lose_diamante.amount = abs(cantidad)
			particle_lose_diamante.emitting = true
	
	emit_signal("stats_updated", self )

# Actualiza el numero de baterias con efecto visual
func establecer_baterias(cantidad: int, animar: bool = true) -> void:
	baterias = max(0, baterias + cantidad)
	await get_tree().create_timer(1).timeout
	if !animar:
		emit_signal("stats_updated", self )
		return
	if cantidad > 0:
		if particle_get_diamante:
			particle_get_diamante.amount = cantidad
			particle_get_diamante.emitting = true
			set_cheering_state(true)
	elif cantidad < 0:
		if particle_lose_diamante:
			await get_tree().create_timer(.8).timeout
			set_hited_state(true)
			await get_tree().create_timer(.15).timeout
			particle_lose_diamante.amount = abs(cantidad)
			particle_lose_diamante.emitting = true
	
	emit_signal("stats_updated", self )

# Devuelve el numero de microchips actuales
func get_microchips() -> int:
	return microchips

# Devuelve el numero de baterias actuales
func get_baterias() -> int:
	return baterias
#endregion


# Getters y Setters
# ---------------------------------------------------------------------------------------
#region Getters y Setters
# Controla la velocidad del jugador
func set_speed(value: float) -> void:
	speed = value

# Devuelve la velocidad actual del jugador
func get_speed() -> float:
	return speed

# Control sobre si esta o no en una casilla
func set_moved_out(moved: bool) -> void:
	is_moved_out = moved

# Devuelve si el jugador esta o no en una casilla
func get_moved_out() -> bool:
	return is_moved_out

# Controla si el jugador esta mirando o no a la camara
func set_looking_at_camera(state: bool) -> void:
	is_looking_at_camera = state

# Devuelve si el jugador esta mirando o no a la camara
func get_looking_at_camera() -> bool:
	return is_looking_at_camera

# Controla si el jugador esta o no en el aire
func set_on_air(state: bool) -> void:
	on_air = state

# Devuelve si el jugador esta o no en el aire
func get_on_air() -> bool:
	return on_air

# Controla la duracion del salto del jugador
func get_jump_duration() -> float:
	return jump_duration
#endregion


# Animaciones
# ---------------------------------------------------------------------------------------
#region Animaciones
# Correr
func set_running_state(state_name: bool) -> void:
	if !state_name:
		set_idle_state(true)
	else:
		set_idle_state(false)
	animation_tree.set("parameters/conditions/running", state_name)
	is_running = state_name

# Caminar
func set_walking_state(state_name: bool) -> void:
	if !state_name:
		set_idle_state(true)
	else:
		set_idle_state(false)
	animation_tree.set("parameters/conditions/walking", state_name)
	is_walking = state_name
	
# Saltar
func set_jumping_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/jumping", state_name)
	is_jumping = state_name
	await get_tree().create_timer(.5).timeout
	if state_name:
		set_jumping_state(false)

# Idle
func set_idle_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/idling", state_name)
	is_idling = state_name

# Saludar
func set_waving_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/waving", state_name)
	is_waving = state_name
	if is_waving:
		await get_tree().create_timer(.1).timeout
		set_waving_state(false)

# Celebrar
func set_cheering_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/cheering", state_name)
	is_cheering = state_name
	if is_cheering:
		await get_tree().create_timer(.1).timeout
		set_cheering_state(false)

# Golpeado
func set_hited_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/hited", state_name)
	is_hited = state_name
	if is_hited:
		await get_tree().create_timer(.1).timeout
		set_hited_state(false)

# Controla la altura del mesh del jugador para simular que esta subiendo de una casilla
func set_player_mesh_height_offset(offset: float) -> void:
	if not player_mesh:
		return
	
	if on_air:
		return
	
	# Aplicar el offset con animacion suave
	var t = create_tween()
	t.tween_property(player_mesh, "position:y", player_mesh.position.y + offset, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Devuelve la altura original del mesh del jugador para simular que esta bajando de una casilla
func return_player_mesh_height_offset() -> void:
	if not player_mesh:
		return
	
	if on_air:
		return
	
	# Devolver a la altura original con animacion suave
	var t = create_tween()
	t.tween_property(player_mesh, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Devuelve el offset actual del mesh del jugador en el eje Y
func get_player_mesh_offset() -> float:
	if not player_mesh:
		return 0.0
	return player_mesh.position.y
#endregion