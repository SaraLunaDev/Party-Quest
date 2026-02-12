extends CharacterBody3D
class_name Jugador


# ############################################################
# Variables
# ############################################################

var nombre: String
var color: Color
var microchips: int = 40
var baterias: int = 0
var posicion_casilla: int = 0
var pf: PathFollow3D
# Device id asignado por InputManager ("keyboard" o "joypad_N")
var device_id = null
var speed: float = 4.0

var is_running: bool = false
var is_jumping: bool = false
var is_idling: bool = true
var is_walking: bool = false
var is_waving: bool = false
var is_hited: bool = false
var is_cheering: bool = false

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


# ############################################################
# Funciones
# ############################################################

# Iniciar posicion inicial
func _ready():
	last_pos = global_transform.origin

# Actualizar rotacion cada frame en base a la direccion de movimiento
func _physics_process(delta):
	var current_pos = global_transform.origin
	var movement_dir = (current_pos - last_pos).normalized()
	
	if movement_dir.length() > 0.01:
		var target_rotation = Vector3(0, atan2(movement_dir.x, movement_dir.z), 0)
		var current_rotation = rotation
		current_rotation.y = lerp_angle(current_rotation.y, target_rotation.y, rotation_speed * delta)
		rotation = current_rotation
	
	last_pos = current_pos

# Iniciar Jugador con nombre y color
func _init(p_nombre: String = "", p_color: Color = Color.WHITE) -> void:
	nombre = p_nombre
	color = p_color

# Configurar Jugador despues de la instanciacion
func configurar(p_nombre: String, p_color: Color) -> void:
	nombre = p_nombre
	color = p_color

# Establecer microchips
func establecer_microchips(cantidad: int, animar: bool = true) -> void:
	microchips = max(0, microchips + cantidad)
	await get_tree().create_timer(1).timeout
	if !animar:
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

# Obtener microchips del jugador
func get_microchips() -> int:
	return microchips

# Establecer baterias
func establecer_baterias(cantidad: int, animar: bool = true) -> void:
	baterias += cantidad
	if !animar:
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

# Obtener baterias del jugador
func get_baterias() -> int:
	return baterias

# Debug para mostrar la Info del Jugador
func obtener_info() -> String:
	var bateria_texto = ""
	if baterias > 0:
		bateria_texto = " " + str(baterias)
	return nombre + bateria_texto + " - Casilla: " + str(posicion_casilla) + " - microchips: " + str(microchips)

# Obtener velocidad del jugador
func get_speed() -> float:
	return speed

# Decidir si esta en casilla o no 
func set_is_in_casilla(value: bool) -> void:
	is_in_casilla = value

# Saber si esta en una casilla
func get_is_in_casilla() -> bool:
	return is_in_casilla

func set_player_mesh_height_offset(offset: float) -> void:
	if player_mesh:
		var t = create_tween()
		t.tween_property(player_mesh, "position:y", offset, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func return_player_mesh_height_offset() -> void:
	if player_mesh:
		var t = create_tween()
		t.tween_property(player_mesh, "position:y", global_transform.origin.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Visibilidad del numero sobre el jugador
func set_number_visibility_state(visible_state: bool) -> void:
	# Si visible_state es true, escalar de 0 a 1
	if not number_label_3d:
		return

	# Mostrar: hacer visible y animar de 0 a 1
	if visible_state:
		number_label_3d.visible = true
		number_label_3d.scale = Vector3.ZERO
		var t = create_tween()
		t.tween_property(number_label_3d, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		# Ocultar: animar de 1 a 0 y esconder al terminar
		var t = create_tween()
		t.tween_property(number_label_3d, "scale", Vector3.ZERO, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		number_label_3d.visible = false

# Obtener si esta fuera de la casilla
func set_moved_out(moved: bool) -> void:
	is_moved_out = moved
func get_moved_out() -> bool:
	return is_moved_out

# ############################################################
# Animaciones
# ############################################################

func set_running_state(state_name: bool) -> void:
	if !state_name:
		set_idle_state(true)
	else:
		set_idle_state(false)
	animation_tree.set("parameters/conditions/running", state_name)
	is_running = state_name

func set_walking_state(state_name: bool) -> void:
	if !state_name:
		set_idle_state(true)
	else:
		set_idle_state(false)
	animation_tree.set("parameters/conditions/walking", state_name)
	is_walking = state_name
	
func set_jumping_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/jumping", state_name)
	is_jumping = state_name
	await get_tree().create_timer(.5).timeout
	if state_name:
		set_jumping_state(false)

func set_idle_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/idling", state_name)
	is_idling = state_name

func set_waving_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/waving", state_name)
	is_waving = state_name
	if is_waving:
		await get_tree().create_timer(.1).timeout
		set_waving_state(false)

func set_cheering_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/cheering", state_name)
	is_cheering = state_name
	if is_cheering:
		await get_tree().create_timer(.1).timeout
		set_cheering_state(false)

func set_hited_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/hited", state_name)
	is_hited = state_name
	if is_hited:
		await get_tree().create_timer(.1).timeout
		set_hited_state(false)
