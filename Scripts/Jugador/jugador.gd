extends CharacterBody3D
class_name Jugador


# Senales
# ---------------------------------------------------------------------------------------
signal stats_updated(jugador: Node3D)
signal almacenado_en_casilla_complete
signal sacado_de_casilla_complete


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
@export var interact_duration: float = 0.6

var is_running: bool = false
var is_jumping: bool = false
var is_interacting: bool = false
var _interact_token: int = 0
var is_idling: bool = true
var is_walking: bool = false
var is_waving: bool = false
var is_hited: bool = false
var is_cheering: bool = false
var is_looking_at_camera: bool = false

var is_in_casilla: bool = false

var almacenado_en_casilla: bool = false
var posicion_almacenada: Vector3 = Vector3.ZERO
var mesh_y_almacenada: float = 0.0

@export var animation_tree: AnimationTree
@export var rotation_speed: float = 8.0
var last_pos := Vector3.ZERO

@export var area_3d: Area3D
var is_moved_out: bool = false
var moved_out_position: Vector3 = Vector3.ZERO
var moved_out_rotation: Vector3 = Vector3.ZERO

@export var number_label_3d: Label3D
@export var label_chips_resultado: Label3D
@export var wood_resultado: MeshInstance3D

@export var particle_get_diamante: GPUParticles3D
@export var particle_get_bateria: GPUParticles3D
@export var particle_lose_diamante: GPUParticles3D

@export var particle_explosion_debris: GPUParticles3D
@export var particle_explosion_fire: GPUParticles3D
@export var particle_explosion_smoke: GPUParticles3D

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
	_aplicar_textura()

func _aplicar_textura() -> void:
	if not player_mesh:
		return
	var regex = RegEx.new()
	regex.compile("\\d+")
	var match_result = regex.search(nombre)
	if not match_result:
		return
	var player_number = match_result.get_string()
	var texture_path = "res://Assets/Jugador/Mannequin Character/Textures/" + player_number + ".png"
	var player_texture = load(texture_path)
	if not player_texture:
		return
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = player_texture
	mat.metallic = 0.0
	mat.roughness = 0.8
	for mesh_inst in _find_mesh_instances(player_mesh):
		mesh_inst.material_override = mat

func _find_mesh_instances(node: Node) -> Array:
	var result = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


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

# Controla la visibilidad del label de chips del resultado
func set_chips_visibility_state(visible_state: bool) -> void:
	if not label_chips_resultado:
		return

	if visible_state:
		label_chips_resultado.visible = true
		label_chips_resultado.scale = Vector3.ZERO
		var t = create_tween()
		t.tween_property(label_chips_resultado, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		var t = create_tween()
		t.tween_property(label_chips_resultado, "scale", Vector3.ZERO, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		label_chips_resultado.visible = false

# Actualiza el numero de microchips con efecto visual
func establecer_microchips(cantidad: int, animar: bool = true) -> void:
	microchips = max(0, microchips + cantidad)
	emit_signal("stats_updated", self )
	await get_tree().create_timer(1).timeout
	if !animar:
		emit_signal("stats_updated", self )
		return
	if cantidad > 0:
		prepare_for_celebration()
		await get_tree().process_frame
		SoundManager.play_sfx(SoundManager.SFX_JUGADOR_CHIPS)
		if particle_get_diamante:
			particle_get_diamante.amount = cantidad
			particle_get_diamante.emitting = true
		await set_cheering_state(true)
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
	emit_signal("stats_updated", self )
	await get_tree().create_timer(1).timeout
	if !animar:
		emit_signal("stats_updated", self )
		return
	if cantidad > 0:
		prepare_for_celebration()
		await get_tree().process_frame
		if particle_get_bateria:
			particle_get_bateria.amount = cantidad
			particle_get_bateria.emitting = true
		await set_cheering_state(true)
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

func set_jumping_insta_state() -> void:
	var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	playback.start("Rig_Medium_MovementBasic_Jump_Full_Short 2", true)

func set_interact_state(state_name: bool) -> void:
	if state_name:
		_interact_token += 1
		var token = _interact_token
		is_interacting = true
		animation_tree.set("parameters/conditions/interact", true)
		var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
		playback.start("Rig_Medium_General_Interact", true)
		await get_tree().create_timer(interact_duration).timeout
		if token == _interact_token:
			animation_tree.set("parameters/conditions/interact", false)
			is_interacting = false
	else:
		_interact_token += 1
		animation_tree.set("parameters/conditions/interact", false)
		is_interacting = false

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

func prepare_for_celebration() -> void:
	set_running_state(false)
	set_walking_state(false)
	set_jumping_state(false)
	set_idle_state(true)

# Celebrar
func set_cheering_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/cheering", state_name)
	is_cheering = state_name
	if is_cheering:
		await get_tree().create_timer(.35).timeout
		set_cheering_state(false)

# Golpeado
func set_hited_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/hited", state_name)
	is_hited = state_name
	if is_hited:
		SoundManager.play_sfx(SoundManager.SFX_JUGADOR_DAÑO)
		await get_tree().create_timer(.1).timeout
		set_hited_state(false)

func iniciar_explosion() -> void:
	if particle_explosion_debris:
		particle_explosion_debris.restart()
	if particle_explosion_fire:
		particle_explosion_fire.restart()
	if particle_explosion_smoke:
		particle_explosion_smoke.restart()
	if player_mesh:
		var t = player_mesh.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(player_mesh, "scale", Vector3.ZERO, 0.2)

# Controla la altura del mesh del jugador para simular que esta subiendo de una casilla
func set_player_mesh_height_offset(offset: float) -> void:
	if not player_mesh:
		return
	
	if on_air or almacenado_en_casilla:
		return
	
	# Aplicar el offset con animacion suave
	var t = create_tween()
	t.tween_property(player_mesh, "position:y", player_mesh.position.y + offset, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Devuelve la altura original del mesh del jugador para simular que esta bajando de una casilla
func return_player_mesh_height_offset() -> void:
	if not player_mesh:
		return
	
	if on_air or almacenado_en_casilla:
		return
	
	# Devolver a la altura original con animacion suave
	var t = create_tween()
	t.tween_property(player_mesh, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# Devuelve el offset actual del mesh del jugador en el eje Y
func get_player_mesh_offset() -> float:
	if not player_mesh:
		return 0.0
	return player_mesh.position.y

# Sentarse / inicio del almacenamiento en casilla
func set_sitting_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/sitting", state_name)

# Spawnear / salir del almacenamiento en casilla
func set_spawning_state(state_name: bool) -> void:
	animation_tree.set("parameters/conditions/spawning", state_name)

func show_podium(show: bool, animate: bool = true) -> void:
	var podio = get_node_or_null("Podio")
	if podio == null:
		return
	if not animate:
		podio.visible = show
		return

	if show:
		podio.visible = true
		podio.scale = Vector3.ZERO
		var t = create_tween()
		t.tween_property(podio, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		var t = create_tween()
		t.tween_property(podio, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		podio.visible = false

func play_final_animation(state: String) -> void:
	if animation_tree == null:
		return
	animation_tree.set("parameters/conditions/cheering", false)
	animation_tree.set("parameters/conditions/waving", false)
	animation_tree.set("parameters/conditions/idling", false)
	animation_tree.set("parameters/conditions/hited", false)
	animation_tree.set("parameters/conditions/running", false)
	animation_tree.set("parameters/conditions/walking", false)
	animation_tree.set("parameters/conditions/jumping", false)
	animation_tree.set("parameters/conditions/interact", false)
	animation_tree.set("parameters/conditions/sitting", false)
	animation_tree.set("parameters/conditions/spawning", false)
	match state:
		"cheer":
			animation_tree.set("parameters/conditions/cheering", true)
		"wave":
			animation_tree.set("parameters/conditions/waving", true)
		"idle":
			animation_tree.set("parameters/conditions/idling", true)
		"hit":
			animation_tree.set("parameters/conditions/hited", true)

func restore_from_storage() -> void:
	almacenado_en_casilla = false
	if player_mesh:
		player_mesh.visible = true
		player_mesh.scale = Vector3.ONE
		player_mesh.position.y = 0.0

# Almacena al jugador dentro de la casilla bajando su mesh hasta ocultarlo
func almacenar_en_casilla() -> void:
	posicion_almacenada = global_position
	if player_mesh:
		mesh_y_almacenada = player_mesh.position.y
	set_idle_state(true)
	set_sitting_state(true)
	await get_tree().create_timer(0.1).timeout
	set_sitting_state(false)
	if player_mesh:
		var t = create_tween()
		t.tween_property(player_mesh, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
	almacenado_en_casilla = true
	emit_signal("almacenado_en_casilla_complete")

# Saca al jugador de la casilla teletransportandolo a su posicion y subiendo su mesh
func sacar_de_casilla() -> void:
	global_position = posicion_almacenada
	set_spawning_state(true)
	await get_tree().create_timer(0.1).timeout
	set_spawning_state(false)
	if player_mesh:
		player_mesh.position.y = -4.0
		var t = create_tween()
		t.tween_property(player_mesh, "position:y", mesh_y_almacenada, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished
	almacenado_en_casilla = false
	emit_signal("sacado_de_casilla_complete")
#endregion
