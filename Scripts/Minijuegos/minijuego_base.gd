extends Node
class_name MinijuegoBase


# Senales
# ---------------------------------------------------------------------------------------
signal tutorial_avanzado


# Variables
# ---------------------------------------------------------------------------------------
@export var jugador_escena: PackedScene
@export var tiempo_maximo: float = 60.0
@export var premios: Array[int] = [4, 2, 1, 0]

# Nodos UI: asignar en la escena hija
@export var panel_tutorial: Control
@export var label_tutorial: Label
@export var label_timer: Label
@export var panel_resultados: Control
@export var label_resultados: Label

@export_group("Resultados 3D")
@export var altura_camara_resultados: float = 0.5
@export var distancia_jugadores_camara: float = 5.0
@export var separacion_jugadores: float = 2.5
@export var offset_x_jugadores: float = 0.0
@export var offset_z_jugadores: float = 0.0
@export var duracion_resultados: float = 5.0

var jugadores_instanciados: Array = []
var activo: bool = false
var tiempo_transcurrido: float = 0.0
var en_tutorial: bool = false
var input_manager: Node = null


# Funciones Basicas
# ---------------------------------------------------------------------------------------
func _ready() -> void:
	input_manager = preload("res://Scripts/Managers/input_manager.gd").new()
	add_child(input_manager)
	input_manager.connect("device_action", Callable(self , "_on_device_action"))
	if label_timer:
		label_timer.visible = false
	_instanciar_jugadores()
	SoundManager.play_music(SoundManager.MUSIC_TUTORIAL_MINIJUEGO)
	await _mostrar_tutorial()
	if label_timer:
		label_timer.visible = true
	_iniciar_minijuego()

func _process(delta: float) -> void:
	if not activo:
		return
	tiempo_transcurrido += delta
	var restante = tiempo_maximo - tiempo_transcurrido
	if label_timer:
		label_timer.text = "%.0f" % max(0.0, restante)
	if tiempo_transcurrido >= tiempo_maximo:
		_terminar_minijuego()


# Override en subclases
# ---------------------------------------------------------------------------------------
func _instanciar_jugadores() -> void:
	pass

func _mostrar_tutorial() -> void:
	await get_tree().process_frame

func _iniciar_minijuego() -> void:
	activo = true

func _calcular_resultados() -> Array:
	return []


# Flujo del minijuego
# ---------------------------------------------------------------------------------------
func _terminar_minijuego() -> void:
	if not activo:
		return
	activo = false
	await get_tree().create_timer(2.0).timeout
	if label_timer:
		label_timer.visible = false
	var resultados = _calcular_resultados()
	await _mostrar_resultados(resultados)
	_volver_al_tablero(resultados)

func _mostrar_resultados(resultados: Array) -> void:
	if panel_resultados:
		panel_resultados.visible = false

	var luz_resultados = DirectionalLight3D.new()
	luz_resultados.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	luz_resultados.light_energy = 0.6
	add_child(luz_resultados)

	var cam = get_viewport().get_camera_3d()
	var cam_transform_original: Transform3D
	if cam:
		cam_transform_original = cam.global_transform
		cam.global_position = Vector3(cam.global_position.x, altura_camara_resultados, cam.global_position.z)
		cam.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		cam.fov = 70.0

	var num = resultados.size()
	for i in range(num):
		var jugador = _get_jugador_node(resultados[i].nombre)
		if not jugador:
			continue

		# Asegurar que el jugador sea visible para la pantalla de resultados
		jugador.visible = true
		if jugador.player_mesh:
			jugador.player_mesh.scale = Vector3.ONE

		# Congelar proceso de fisica para que no sobreescriba la rotacion
		jugador.set_physics_process(false)

		# Posicionar en linea horizontal frente a la camara, centrado, en orden de puesto
		var offset_x = (i - (num - 1) / 2.0) * separacion_jugadores
		if cam:
			jugador.global_position = Vector3(
				cam.global_position.x + offset_x + offset_x_jugadores,
				cam.global_position.y + distancia_jugadores_camara,
				cam.global_position.z + offset_z_jugadores
			)

		# Rotar para que queden horizontales al suelo (tumbados cara abajo) vistos desde la camara al cielo
		jugador.rotation_degrees = Vector3(90.0, 0.0, 0.0)

		# Mostrar puesto en el label del numero del jugador
		# Desactivar el proceso de seguimiento de camara del numero durante los resultados
		if jugador.number_label_3d:
			jugador.number_label_3d.text = str(i + 1)
			jugador.number_label_3d.set_process(false)
			if cam:
				var target_numero = Vector3(jugador.number_label_3d.global_position.x, cam.global_position.y, jugador.number_label_3d.global_position.z)
				jugador.number_label_3d.look_at(target_numero, Vector3.BACK)
				jugador.number_label_3d.rotate_y(PI)
		jugador.set_number_visibility_state(true)

		# Mostrar chips ganados y suelo
		var premio = premios[i] if i < premios.size() else 0
		if jugador.label_chips_resultado:
			jugador.label_chips_resultado.text = "+" + str(premio) + " CHIPS" if premio > 0 else str(premio) + " CHIPS"
			jugador.label_chips_resultado.set_process(false)
			if cam:
				var target_chips = Vector3(jugador.label_chips_resultado.global_position.x, cam.global_position.y, jugador.label_chips_resultado.global_position.z)
				jugador.label_chips_resultado.look_at(target_chips, Vector3.BACK)
				jugador.label_chips_resultado.rotate_y(PI)
			jugador.set_chips_visibility_state(true)
		if jugador.wood_resultado:
			jugador.wood_resultado.visible = true

	await get_tree().create_timer(2.0).timeout

	for i in range(num):
		var jugador = _get_jugador_node(resultados[i].nombre)
		if not jugador:
			continue
		match i:
			0: jugador.set_cheering_state(true)
			1: jugador.set_waving_state(true)
			2: jugador.set_idle_state(true)
			3: jugador.set_hited_state(true)

	await get_tree().create_timer(duracion_resultados).timeout

	for data in resultados:
		var jugador = _get_jugador_node(data.nombre)
		if jugador:
			jugador.set_physics_process(true)
			jugador.set_number_visibility_state(false)
			if jugador.number_label_3d:
				jugador.number_label_3d.set_process(true)
			if jugador.label_chips_resultado:
				jugador.set_chips_visibility_state(false)
				jugador.label_chips_resultado.set_process(true)
			if jugador.wood_resultado:
				jugador.wood_resultado.visible = false

	luz_resultados.queue_free()

	if cam:
		cam.global_transform = cam_transform_original

func _volver_al_tablero(resultados: Array) -> void:
	GameData.resultados_minijuego.clear()
	for i in range(resultados.size()):
		var premio = premios[i] if i < premios.size() else 0
		GameData.resultados_minijuego.append({
			"nombre": resultados[i].nombre,
			"microchips_ganados": premio
		})
	get_tree().change_scene_to_file(GameData.escena_tablero)

# Muestra texto de tutorial y espera confirmacion de cualquier jugador
func _mostrar_tutorial_texto(texto: String) -> void:
	if panel_tutorial and label_tutorial:
		label_tutorial.text = texto
		panel_tutorial.visible = true
	en_tutorial = true
	await tutorial_avanzado
	en_tutorial = false
	if panel_tutorial:
		panel_tutorial.visible = false


# Utilidades
# ---------------------------------------------------------------------------------------
func _get_jugador_node(nombre: String) -> Node3D:
	for j in jugadores_instanciados:
		if j.nombre == nombre:
			return j
	return null

func _get_jugador_por_device(device_id) -> Node3D:
	for j in jugadores_instanciados:
		if j.device_id == device_id:
			return j
	return null

func _on_device_action(_device_id, action: String) -> void:
	if en_tutorial and action == "ui_accept":
		emit_signal("tutorial_avanzado")
