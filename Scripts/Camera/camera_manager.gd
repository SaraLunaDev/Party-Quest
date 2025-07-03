extends Node
class_name CameraManager

# ============================================================================
# CONFIGURACION Y VARIABLES PRINCIPALES
# ============================================================================

# Referencias principales
@export var camara: Camera3D
@export var game_manager: GameManager

# Control de seguimiento
@export var jugador_actual_seguido: Node3D = null
var pathfollow_camara: PathFollow3D = null

# Configuracion de offset
@export var offset_posicion: Vector3 = Vector3(10, 12, 20)
@export var offset_rotacion: Vector3 = Vector3(-30, 30, 0)

# Estados de la camara
enum EstadoCamara {
	SIGUIENDO_JUGADOR,
	VISTA_GENERAL,
	TRANSICION,
	ZOOM_TEMPORAL
}

var estado_actual: EstadoCamara = EstadoCamara.VISTA_GENERAL

# Control de sincronizacion
var sincronizando_posicion: bool = false

# Variables para zoom temporal
var posicion_antes_zoom: Vector3
var rotacion_antes_zoom: Vector3
var posicion_global_antes_zoom: Vector3
var rotacion_global_antes_zoom: Vector3
var padre_antes_zoom: Node
var coordenada_zoom_objetivo: Vector3
var duracion_zoom: float
var zoom_activo: bool = false

# ============================================================================
# INICIALIZACION Y CONFIGURACION
# ============================================================================

func _ready() -> void:
	if game_manager:
		conectar_senales_game_manager()
	else:
		print("No hay GameManager asignado al CameraManager")

func conectar_senales_game_manager():
	game_manager.connect("turno_cambiado", _on_turno_cambiado)
	game_manager.connect("partida_iniciada", _on_partida_iniciada)
	game_manager.connect("partida_finalizada", _on_partida_finalizada)

func _exit_tree() -> void:
	limpiar_pathfollow_camara()
	sincronizando_posicion = false

# ============================================================================
# SISTEMA DE SEGUIMIENTO DE JUGADORES
# ============================================================================

func _process(_delta: float) -> void:
	if not sincronizando_posicion or not jugador_actual_seguido or not pathfollow_camara:
		return
	
	# Sincronizar progress_ratio de la camara con el jugador actual
	if jugador_actual_seguido.pf:
		pathfollow_camara.progress_ratio = jugador_actual_seguido.pf.progress_ratio

func seguir_jugador(jugador: Node3D) -> void:
	if not jugador:
		print("Jugador sin PathFollow3D valido")
		return
	
	print("Camara siguiendo a ", jugador.nombre)
	if jugador_actual_seguido and jugador_actual_seguido.pf:
		desconectar_camara_jugador()
	
	conectar_camara_jugador(jugador)
	jugador_actual_seguido = jugador
	estado_actual = EstadoCamara.SIGUIENDO_JUGADOR

func cambiar_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("Cambio instantaneo al jugador ", jugador.nombre)
	seguir_jugador(jugador)

# ============================================================================
# GESTION DE PATHFOLLOW PARA CAMARA
# ============================================================================

func conectar_camara_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("Conectando camara a ", jugador.nombre)
	limpiar_pathfollow_camara()
	crear_pathfollow_camara(jugador)
	configurar_camara_en_pathfollow()
	sincronizando_posicion = true

func crear_pathfollow_camara(jugador: Node3D):
	pathfollow_camara = PathFollow3D.new()
	pathfollow_camara.name = "PF3D_Camara_" + jugador.nombre
	pathfollow_camara.rotation_mode = PathFollow3D.ROTATION_NONE
	
	var tablero = jugador.pf.get_parent()
	tablero.add_child(pathfollow_camara)
	pathfollow_camara.progress_ratio = jugador.pf.progress_ratio

func configurar_camara_en_pathfollow():
	if camara.get_parent():
		camara.get_parent().remove_child(camara)
	
	pathfollow_camara.add_child(camara)
	camara.position = offset_posicion
	camara.rotation_degrees = offset_rotacion

func desconectar_camara_jugador() -> void:
	if not camara or not camara.get_parent():
		return
	
	print("Desconectando camara de ", jugador_actual_seguido.nombre)
	
	# Preservar posicion global
	var posicion_global = camara.global_position
	var rotacion_global = camara.global_rotation
	
	# Remover camara del pathfollow
	if camara.get_parent():
		camara.get_parent().remove_child(camara)
	
	limpiar_pathfollow_camara()
	
	# Añadir temporalmente a escena principal
	get_tree().current_scene.add_child(camara)
	camara.global_position = posicion_global
	camara.global_rotation = rotacion_global

func limpiar_pathfollow_camara():
	if pathfollow_camara:
		pathfollow_camara.queue_free()
		pathfollow_camara = null

# ============================================================================
# SISTEMA DE ZOOM TEMPORAL
# ============================================================================

func zoom_temporal_a_coordenada(coordenada: Vector3, duracion: float, factor_zoom: float):
	if estado_actual == EstadoCamara.ZOOM_TEMPORAL:
		print("Ya hay un zoom temporal activo")
		return
	
	print("Iniciando zoom temporal")
	await ejecutar_zoom_temporal(coordenada, duracion, factor_zoom)

func ejecutar_zoom_temporal(coordenada_global: Vector3, duracion: float, factor_zoom: float):
	print("Zoom a coordenada: ", coordenada_global)
	
	guardar_estado_actual()
	configurar_zoom_temporal(coordenada_global, duracion)
	extraer_camara_de_pathfollow()
	
	await animar_zoom_hacia_coordenada(coordenada_global, factor_zoom)
	await restaurar_estado_anterior()

func guardar_estado_actual():
	var parent_actual = camara.get_parent()
	if parent_actual != null and parent_actual is PathFollow3D:
		padre_antes_zoom = camara.get_parent()
		posicion_antes_zoom = camara.position
		rotacion_antes_zoom = camara.rotation
		posicion_global_antes_zoom = camara.global_position
		rotacion_global_antes_zoom = camara.global_rotation
	else:
		posicion_antes_zoom = camara.global_position
		rotacion_antes_zoom = camara.global_rotation
		posicion_global_antes_zoom = camara.global_position
		rotacion_global_antes_zoom = camara.global_rotation
		padre_antes_zoom = camara.get_parent()

func configurar_zoom_temporal(coordenada: Vector3, duracion: float):
	coordenada_zoom_objetivo = coordenada
	duracion_zoom = duracion
	zoom_activo = true
	estado_actual = EstadoCamara.ZOOM_TEMPORAL

func extraer_camara_de_pathfollow():
	var parent_actual = camara.get_parent()
	if parent_actual != null and parent_actual is PathFollow3D:
		var posicion_global_actual = camara.global_position
		var rotacion_global_actual = camara.global_rotation
		
		camara.get_parent().remove_child(camara)
		get_tree().current_scene.add_child(camara)
		
		camara.global_position = posicion_global_actual
		camara.global_rotation = rotacion_global_actual

# ============================================================================
# ANIMACIONES DE ZOOM
# ============================================================================

func animar_zoom_hacia_coordenada(coordenada: Vector3, factor_zoom: float):
	print("Animando zoom hacia coordenada")
	
	var posicion_objetivo = calcular_posicion_objetivo(coordenada)
	var rotacion_objetivo = calcular_rotacion_objetivo(coordenada, posicion_objetivo)
	
	var tween_movimiento = crear_tween_zoom()
	ejecutar_animacion_posicion_rotacion(tween_movimiento, posicion_objetivo, rotacion_objetivo)
	await tween_movimiento.finished
	var tween_fov = crear_tween_zoom()
	aplicar_zoom_fov(tween_fov, factor_zoom)
	await tween_fov.finished
	print("Animacion de zoom completada")

func calcular_posicion_objetivo(coordenada: Vector3) -> Vector3:
	var posicion_objetivo = coordenada + offset_posicion
	return posicion_objetivo

func calcular_rotacion_objetivo(coordenada: Vector3, posicion_objetivo: Vector3) -> Vector3:
	var look_transform = Transform3D().looking_at(coordenada - posicion_objetivo, Vector3.UP)
	return look_transform.basis.get_euler()

func crear_tween_zoom() -> Tween:
	var tween = create_tween()
	tween.set_parallel(true)
	return tween

func ejecutar_animacion_posicion_rotacion(tween: Tween, posicion: Vector3, rotacion: Vector3):
	tween.tween_property(camara, "global_position", posicion, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(camara, "global_rotation", rotacion, 0.5).set_ease(Tween.EASE_OUT)

func aplicar_zoom_fov(tween: Tween, factor_zoom: float):
	if camara.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var fov_original = camara.fov
		var fov_zoom = fov_original * factor_zoom
		tween.tween_property(camara, "fov", fov_zoom, duracion_zoom).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)

# ============================================================================
# RESTAURACION DESPUES DEL ZOOM
# ============================================================================

func restaurar_estado_anterior():
	print("Regresando de zoom temporal")
	
	if not zoom_activo:
		return
	
	zoom_activo = false
	
	if padre_antes_zoom != null and padre_antes_zoom is PathFollow3D:
		await restaurar_a_pathfollow()
	else:
		await restaurar_posicion_fija()
	
	actualizar_estado_final()

func restaurar_a_pathfollow():
	await animar_regreso(posicion_global_antes_zoom, rotacion_global_antes_zoom)
	reconectar_a_pathfollow()

func calcular_posicion_pathfollow() -> Vector3:
	var posicion_objetivo = padre_antes_zoom.global_position
	return posicion_objetivo + padre_antes_zoom.global_transform.basis * posicion_antes_zoom

func reconectar_a_pathfollow():
	if camara.get_parent():
		camara.get_parent().remove_child(camara)
	padre_antes_zoom.add_child(camara)
	camara.position = posicion_antes_zoom
	camara.rotation = rotacion_antes_zoom

func restaurar_posicion_fija():
	await animar_regreso(posicion_antes_zoom, rotacion_antes_zoom)

func animar_regreso(posicion: Vector3, rotacion: Vector3):
	#var tween = create_tween()
	#tween.set_parallel(true)
	#tween.tween_property(camara, "global_position", posicion, 1.0)
	#tween.tween_property(camara, "global_rotation", rotacion, 1.0)
	#await tween.finished
	camara.global_position = posicion
	camara.global_rotation = rotacion
	await get_tree().process_frame

func actualizar_estado_final():
	if jugador_actual_seguido != null:
		estado_actual = EstadoCamara.SIGUIENDO_JUGADOR
		print("Camara regreso a seguir jugador: ", jugador_actual_seguido.nombre)
	else:
		estado_actual = EstadoCamara.VISTA_GENERAL
		print("Camara regreso a vista general")

# ============================================================================
# RESPUESTA A EVENTOS DEL JUEGO
# ============================================================================

func _on_turno_cambiado(jugador_actual: Node3D):
	print("Camara: Nuevo turno - ", jugador_actual.nombre)
	cambiar_jugador(jugador_actual)

func _on_partida_iniciada():
	print("Camara: Partida iniciada")

func _on_partida_finalizada(ganador: Node3D):
	print("Camara: Mostrando ganador - ", ganador.nombre)
	if ganador != jugador_actual_seguido:
		cambiar_jugador(ganador)
