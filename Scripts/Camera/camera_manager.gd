extends Node
class_name CameraManager

# Variables
@export var camera: Camera3D
@export var tablero: Path3D
@export var game_manager: GameManager

# Seguimiento continuo del jugador
var seguimiento_continuo: bool = false
var tween_seguimiento: Tween = null

# Control de actualizacion de posicion
@export var frecuencia_actualizacion: float = 0.05
var timer_actualizacion: float = 0.0

# Estados de la camara
enum EstadoCamara {
	VISTA_GENERAL,
	VISTA_JUGADOR,
	VISTA_ESPECIAL,
	RESULTADO_FINAL
}

var estado_actual: EstadoCamara = EstadoCamara.VISTA_GENERAL
var jugador_objetivo: Node3D = null
var posicion_objetivo: Vector3
var rotacion_objetivo: Vector3

# Cofiguracion de seguimiento
@export var distancia_seguimiento: float = 8.0
@export var altura_seguimiento: float = 5.0
@export var velocidad_transicion: float = 2.0
@export var velocidad_rotacion: float = 3.0

# Configuracion de vista general
@export var posicion_vista_general: Vector3 = Vector3(0, 20, 30)
@export var rotacion_vista_general: Vector3 = Vector3(-40, 0, 0)

func _ready() -> void:
	# Configurar la camara inicial
	establecer_vista_general()

	if game_manager:
		game_manager.connect("turno_cambiado", _on_turno_cambiado)
		game_manager.connect("jugador_movido", _on_jugador_movido)
		game_manager.connect("partida_iniciada", _on_partida_iniciada)
		game_manager.connect("partida_finalizada", _on_partida_finalizada)

# Agregar la funcion _process para seguimiento en tiempo real
func _process(delta: float) -> void:
	if not seguimiento_continuo or not jugador_objetivo or not jugador_objetivo.pf:
		return
	
	# Control de frecuencia de actualizacion
	timer_actualizacion += delta
	if timer_actualizacion >= frecuencia_actualizacion:
		timer_actualizacion = 0.0
		actualizar_seguimiento_continuo()

# Actualizar posicion de camara basada en la posicion actual del jugador
func actualizar_seguimiento_continuo() -> void:
	if not jugador_objetivo or not jugador_objetivo.pf:
		return
	
	# Calcular nueva posicion basada en donde esta el jugador AHORA MISMO
	var posicion_actual_jugador = jugador_objetivo.pf.global_position
	var direccion_camara = Vector3.BACK * distancia_seguimiento
	direccion_camara.y = altura_seguimiento
	var nueva_posicion_objetivo = posicion_actual_jugador + direccion_camara
	
	# Solo actualizar si la posicion cambio significativamente
	if posicion_objetivo.distance_to(nueva_posicion_objetivo) > 0.1:
		posicion_objetivo = nueva_posicion_objetivo
		rotacion_objetivo = Vector3(-30, 0, 0)
		
		# Transicion suave y rapida para seguimiento continuo
		transicionar_camara_suave()

# Transicion mas suave y rapida para seguimiento continuo
func transicionar_camara_suave() -> void:
	if not camera:
		return
	
	# Cancelar tween anterior si existe
	if tween_seguimiento:
		tween_seguimiento.kill()
	
	# Crear nuevo tween mas rapido para seguimiento continuo
	tween_seguimiento = create_tween()
	tween_seguimiento.set_parallel(true)
	
	# Transiciones mas rapidas para seguimiento fluido
	var duracion_seguimiento = 0.1 # Mas rapido que transicion normal
	tween_seguimiento.tween_property(camera, "global_position", posicion_objetivo, duracion_seguimiento)
	tween_seguimiento.tween_property(camera, "rotation_degrees", rotacion_objetivo, duracion_seguimiento)

# Teleport instantaneo de la camara a una posicion
func teleport_camara(nueva_posicion: Vector3, nueva_rotacion: Vector3) -> void:
	print("📷 Camara: Teleport instantaneo a nueva posicion")
	
	# Detener cualquier tween activo
	if tween_seguimiento:
		tween_seguimiento.kill()
		tween_seguimiento = null
	
	# Establecer posicion y rotacion INSTANTANEAMENTE
	posicion_objetivo = nueva_posicion
	rotacion_objetivo = nueva_rotacion
	
	# Aplicar directamente sin animacion
	if camera:
		camera.global_position = posicion_objetivo
		camera.rotation_degrees = rotacion_objetivo

# Teleport instantaneo hacia un jugador especifico
func teleport_a_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("📷 Camara: Teleport instantaneo al jugador ", jugador.nombre)
	estado_actual = EstadoCamara.VISTA_JUGADOR
	jugador_objetivo = jugador
	
	# Calcular posicion del jugador
	var posicion_jugador = jugador.pf.global_position
	var direccion_camara = Vector3.BACK * distancia_seguimiento
	direccion_camara.y = altura_seguimiento
	var posicion_camara = posicion_jugador + direccion_camara
	var rotacion_camara = Vector3(-30, 0, 0)
	
	# Teleport instantaneo
	teleport_camara(posicion_camara, rotacion_camara)
	
	# Iniciar seguimiento continuo despues del teleport
	seguimiento_continuo = true

func establecer_vista_general() -> void:
	print("📷 Camara: Vista general del tablero")
	detener_seguimiento_continuo()
	estado_actual = EstadoCamara.VISTA_GENERAL
	posicion_objetivo = posicion_vista_general
	rotacion_objetivo = rotacion_vista_general
	transicionar_camara()

# Modificar seguir_jugador para usar seguimiento continuo
func seguir_jugador(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	print("📷 Camara: Siguiendo al jugador ", jugador.nombre)
	estado_actual = EstadoCamara.VISTA_JUGADOR
	
	# Iniciar seguimiento continuo en lugar de posicion fija
	iniciar_seguimiento_continuo(jugador)

# Iniciar seguimiento continuo del jugador
func iniciar_seguimiento_continuo(jugador: Node3D) -> void:
	if not jugador or not jugador.pf:
		return
	
	print("📷 Camara: Iniciando seguimiento continuo de ", jugador.nombre)
	jugador_objetivo = jugador
	seguimiento_continuo = true

	# Calcular posicion inicial
	calcular_posicion_seguimiento()
	transicionar_camara()

# Detener seguimiento continuo
func detener_seguimiento_continuo() -> void:
	print("📷 Camara: Deteniendo seguimiento continuo")
	seguimiento_continuo = false
	if tween_seguimiento:
		tween_seguimiento.kill()
		tween_seguimiento = null

func calcular_posicion_seguimiento() -> void:
	if not jugador_objetivo or not jugador_objetivo.pf:
		return
	
	var posicion_jugador = jugador_objetivo.pf.global_position
	var direccion_camara = Vector3.BACK * distancia_seguimiento
	direccion_camara.y = altura_seguimiento
	posicion_objetivo = posicion_jugador + direccion_camara
	rotacion_objetivo = Vector3(-30, 0, 0)

func enfocar_evento(posicion: Vector3, duracion: float = 3.0) -> void:
	print("📷 Camara: Enfocando evento especial en ", posicion)
	var estado_anterior = estado_actual
	estado_actual = EstadoCamara.VISTA_ESPECIAL
	
	var direccion_camara = Vector3.BACK * distancia_seguimiento
	direccion_camara.y = altura_seguimiento * 1.5
	posicion_objetivo = posicion + direccion_camara
	
	transicionar_camara()
	
	await get_tree().create_timer(duracion).timeout
	estado_actual = estado_anterior
	if jugador_objetivo:
		seguir_jugador(jugador_objetivo)
	else:
		establecer_vista_general()

func transicionar_camara() -> void:
	if not camera:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(camera, "global_position", posicion_objetivo, 1.0 / velocidad_transicion)
	tween.tween_property(camera, "rotation_degrees", rotacion_objetivo, 1.0 / velocidad_rotacion)

# Responder al cambio de turno
func _on_turno_cambiado(jugador_actual: Node3D):
	print("📷 Camara: Nuevo turno - ", jugador_actual.nombre)
	detener_seguimiento_continuo()
	teleport_a_jugador(jugador_actual)

# Responder al movimiento del jugador
func _on_jugador_movido(jugador: Node3D, casilla_index: int):
	print("📷 Camara: Jugador ", jugador.nombre, " se movio a la casilla ", casilla_index)

# Responder al inicio de partida
func _on_partida_iniciada():
	print("📷 Camara: Partida iniciada")
	await get_tree().create_timer(2.0).timeout
	# La camara ya seguira al primer jugador cuando cambie el turno

# Responder al final de partida
func _on_partida_finalizada(ganador: Node3D):
	print("📷 Camara: Mostrando ganador")
	# Enfocar dramaticamente al ganador
	if ganador and ganador.pf:
		enfocar_evento(ganador.pf.global_position, 5.0)
