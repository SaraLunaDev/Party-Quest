extends Node
class_name CameraManager

# Variables
@export var camara: Camera3D
@export var game_manager: GameManager

# Control de seguimiento
@export var jugador_actual_seguido: Node3D = null
var pathfollow_camara: PathFollow3D = null

# Offset para la camara
@export var offset_posicion: Vector3 = Vector3(10, 12, 20)
@export var offset_rotacion: Vector3 = Vector3(-30, 30, 0)

# Sincronizacion de posicion
var sincronizando_posicion: bool = false

func _ready() -> void:
	if game_manager:
		game_manager.connect("turno_cambiado", _on_turno_cambiado)
		game_manager.connect("partida_iniciada", _on_partida_iniciada)
		game_manager.connect("partida_finalizada", _on_partida_finalizada)

func _process(_delta: float) -> void:
	if not sincronizando_posicion or not jugador_actual_seguido or not pathfollow_camara:
		return
	
	# Sincronizar progress_ratio de la camara con el jugador actual
	if jugador_actual_seguido.pf:
		pathfollow_camara.progress_ratio = jugador_actual_seguido.pf.progress_ratio

# Hacer que la camara siga a un jugador especifico
func seguir_jugador(jugador: Node3D) -> void:
	if not jugador:
		print("😤 Jugador sin PathFollow3D valido")
		return
	
	print("📷 Camara: Siguiendo a ", jugador.nombre)
	if jugador_actual_seguido and jugador_actual_seguido.pf:
		# Desconectar la camara del PathFollow3D del jugador actual
		desconectar_camara_jugador()
	# Conectar la camara al PathFollow3D del jugador
	conectar_camara_jugador(jugador)
	# Establecer jugador actual seguido
	jugador_actual_seguido = jugador

# Conectar la camara al PathFollow3D del jugador
func conectar_camara_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("🔌 Camara: Conectando a ", jugador.nombre)
	# Limpiar PathFollow3D anterior si existe
	if pathfollow_camara:
		pathfollow_camara.queue_free()
		pathfollow_camara = null
	# Crear un nuevo PathFollow3D para la camara
	pathfollow_camara = PathFollow3D.new()
	pathfollow_camara.name = "PF3D_Camara_" + jugador.nombre
	# Configurar para que no rote
	pathfollow_camara.rotation_mode = PathFollow3D.ROTATION_NONE
	# Obtener el tablero desde el jugador
	var tablero = jugador.pf.get_parent()
	tablero.add_child(pathfollow_camara)
	# Sincronizar posicion con la del jugador
	pathfollow_camara.progress_ratio = jugador.pf.progress_ratio
	# Eliminar camara de su padre actual
	if camara.get_parent():
		camara.get_parent().remove_child(camara)
	# Añadir camara al PathFollow3D del jugador
	pathfollow_camara.add_child(camara)
	# Ajustar posicion y rotacion de la camara
	camara.position = offset_posicion
	camara.rotation_degrees = offset_rotacion
	# Iniciar sincronizazcion continua
	sincronizando_posicion = true
	
# Deconectar la camara del PathFollow3D del jugador actual
func desconectar_camara_jugador() -> void:
	if not camara or not camara.get_parent():
		return
	
	print("🔌 Camara: Desconectando de ", jugador_actual_seguido.nombre)
	# Guardar posicion global antes de desconectar
	var posicion_global = camara.global_position
	var rotacion_global = camara.global_rotation
	# Eliminar la camara de su padre actual
	if camara.get_parent():
		camara.get_parent().remove_child(camara)
	# Limpiar PathFollow3D de la camara
	pathfollow_camara.queue_free()
	pathfollow_camara = null
	# Temporalmente añadir la camara a la escena actual para evitar errores
	get_tree().current_scene.add_child(camara)
	# Restaurar la posicion y rotacion global
	camara.global_position = posicion_global
	camara.global_rotation = rotacion_global

# Cambio instananeo de jugador
func cambiar_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("⚡ Teleport instantaneo al jugador ", jugador.nombre)
	# Cambiar inmediatamente al nuevo jugador
	seguir_jugador(jugador)
	print("✅ Teleport completado - Camara ahora sigue a ", jugador.nombre)

func _exit_tree() -> void:
	# Limpiar PathFollow3D de la camara
	if pathfollow_camara:
		pathfollow_camara.queue_free()
		pathfollow_camara = null
	sincronizando_posicion = false

# Responder al cambio de turno
func _on_turno_cambiado(jugador_actual: Node3D):
	print("📷Camara: Nuevoturno - ", jugador_actual.nombre)
	cambiar_jugador(jugador_actual)

# Responder al inicio de partida
func _on_partida_iniciada():
	print("📷Camara: Partidainiciada")

# Responder al final de partida
func _on_partida_finalizada(ganador: Node3D):
	print("📷Camara: Mostrandoa", ganador, ", ganadordelapartida")
	if ganador != jugador_actual_seguido:
		cambiar_jugador(ganador)
