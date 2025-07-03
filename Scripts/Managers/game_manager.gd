class_name PartyGameManager
extends Node

# Referencias principales
@onready var movement_manager: Node
@onready var tablero: Node3D

# Estados del juego
enum EstadoJuego {
	MENU,
	SELECCION_JUGADORES,
	INICIANDO_PARTIDA,
	TURNO_JUGADOR,
	MOVIENDO_JUGADOR,
	EVENTO_CASILLA,
	MINIJUEGO,
	FIN_PARTIDA
}

var estado_actual: EstadoJuego = EstadoJuego.MENU

# Configuracion de partida
@export var numero_turnos: int = 10
@export var numero_jugadores: int = 4

# Control de turnos
var jugadores: Array[Node3D] = []
var jugador_actual_index: int = 0
var turno_actual: int = 1

# Senales
signal estado_cambiado(nuevo_estado: EstadoJuego)
signal turno_iniciado(jugador: Node3D, numero_turno: int)
signal partida_terminada(ganador: Node3D)

func _ready():
	# Buscar referencias en la escena
	movement_manager = get_node("MovementManager")
	tablero = get_tree().get_first_node_in_group("tablero")
	
	# Conectar senales del MovementManager
	if movement_manager:
		movement_manager.movimiento_completado.connect(_on_movimiento_completado)
		movement_manager.casilla_alcanzada.connect(_on_casilla_alcanzada)
	
	# Inicializar estado
	_cambiar_estado(EstadoJuego.MENU)

# ====================================================================
# CONTROL DE ESTADOS
# ====================================================================

func _cambiar_estado(nuevo_estado: EstadoJuego) -> void:
	print("GameManager: Cambiando estado de ", EstadoJuego.keys()[estado_actual], " a ", EstadoJuego.keys()[nuevo_estado])
	estado_actual = nuevo_estado
	estado_cambiado.emit(nuevo_estado)
	
	# Ejecutar logica especifica del estado
	match nuevo_estado:
		EstadoJuego.MENU:
			_manejar_menu()
		EstadoJuego.SELECCION_JUGADORES:
			_manejar_seleccion_jugadores()
		EstadoJuego.INICIANDO_PARTIDA:
			_manejar_inicio_partida()
		EstadoJuego.TURNO_JUGADOR:
			_manejar_turno_jugador()
		EstadoJuego.MOVIENDO_JUGADOR:
			_manejar_movimiento_jugador()
		EstadoJuego.EVENTO_CASILLA:
			_manejar_evento_casilla()
		EstadoJuego.MINIJUEGO:
			_manejar_minijuego()
		EstadoJuego.FIN_PARTIDA:
			_manejar_fin_partida()

# ====================================================================
# MANEJO DE ESTADOS ESPECIFICOS
# ====================================================================

func _manejar_menu() -> void:
	print("GameManager: Mostrando menu principal")
	# Aqui se conectaria con la UI del menu

func _manejar_seleccion_jugadores() -> void:
	print("GameManager: Seleccionando jugadores")
	# Aqui se conectaria con la UI de seleccion de jugadores

func _manejar_inicio_partida() -> void:
	print("GameManager: Iniciando partida con ", numero_jugadores, " jugadores")
	_crear_jugadores()
	_posicionar_jugadores_inicio()
	_cambiar_estado(EstadoJuego.TURNO_JUGADOR)

func _manejar_turno_jugador() -> void:
	var jugador_actual = jugadores[jugador_actual_index]
	print("GameManager: Turno ", turno_actual, " - Jugador ", jugador_actual_index + 1)
	turno_iniciado.emit(jugador_actual, turno_actual)
	
	# Simular tirada de dados (por ahora valor aleatorio)
	var pasos = randi_range(1, 6)
	print("GameManager: Jugador saca ", pasos, " en los dados")
	
	# Iniciar movimiento
	_mover_jugador_actual(pasos)

func _manejar_movimiento_jugador() -> void:
	print("GameManager: Jugador moviendose...")
	# El MovementManager maneja el movimiento actual

func _manejar_evento_casilla() -> void:
	var _jugador_actual = jugadores[jugador_actual_index]
	print("GameManager: Procesando evento de casilla para jugador ", jugador_actual_index + 1)
	
	# Simular evento de casilla (por ahora pausa simple)
	await get_tree().create_timer(1.0).timeout
	_siguiente_turno()

func _manejar_minijuego() -> void:
	print("GameManager: Ejecutando minijuego")
	# Aqui se iniciaria un minijuego
	await get_tree().create_timer(2.0).timeout
	_siguiente_turno()

func _manejar_fin_partida() -> void:
	print("GameManager: Partida terminada")
	var ganador = _determinar_ganador()
	partida_terminada.emit(ganador)

# ====================================================================
# FUNCIONES DE JUEGO
# ====================================================================

func iniciar_partida() -> void:
	_cambiar_estado(EstadoJuego.INICIANDO_PARTIDA)

func _crear_jugadores() -> void:
	jugadores.clear()
	
	# Buscar jugadores en la escena o crearlos
	var grupo_jugadores = get_tree().get_nodes_in_group("jugadores")
	
	if grupo_jugadores.size() >= numero_jugadores:
		# Usar jugadores existentes
		for i in range(numero_jugadores):
			jugadores.append(grupo_jugadores[i])
	else:
		print("GameManager: No hay suficientes jugadores en la escena")
		# Aqui se podrian crear jugadores dinamicamente

func _posicionar_jugadores_inicio() -> void:
	if tablero == null:
		print("GameManager: No se encontro tablero")
		return
	
	# Buscar casilla inicial (primera casilla del primer camino)
	var primer_camino = tablero.caminos[0] if tablero.caminos.size() > 0 else null
	if primer_camino == null:
		print("GameManager: No hay caminos en el tablero")
		return
	
	var casilla_inicial: Casilla = null
	for child in primer_camino.get_children():
		if child.name.begins_with("Casilla_"):
			casilla_inicial = child
			break
	
	if casilla_inicial == null:
		print("GameManager: No se encontro casilla inicial")
		return
	
	# Posicionar todos los jugadores en la casilla inicial
	for jugador in jugadores:
		jugador.global_position = casilla_inicial.global_position
		# Pequeno offset para que no se superpongan
		var offset = Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
		jugador.global_position += offset

func _mover_jugador_actual(pasos: int) -> void:
	if movement_manager == null:
		print("GameManager: MovementManager no disponible")
		return
	
	var jugador_actual = jugadores[jugador_actual_index]
	_cambiar_estado(EstadoJuego.MOVIENDO_JUGADOR)
	movement_manager.mover_jugador_por_pasos(jugador_actual, pasos)

func _siguiente_turno() -> void:
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	
	# Si completamos una ronda, aumentar turno
	if jugador_actual_index == 0:
		turno_actual += 1
		
		# Verificar si la partida termino
		if turno_actual > numero_turnos:
			_cambiar_estado(EstadoJuego.FIN_PARTIDA)
			return
	
	_cambiar_estado(EstadoJuego.TURNO_JUGADOR)

func _determinar_ganador() -> Node3D:
	# Por ahora, el primer jugador gana (logica simple)
	return jugadores[0] if jugadores.size() > 0 else null

# ====================================================================
# CALLBACKS DEL MOVEMENTMANAGER
# ====================================================================

func _on_movimiento_completado() -> void:
	print("GameManager: Movimiento completado")
	_cambiar_estado(EstadoJuego.EVENTO_CASILLA)

func _on_casilla_alcanzada(casilla: Casilla) -> void:
	print("GameManager: Jugador alcanzo casilla ", casilla.get_index())
	# Aqui se podrian activar efectos de casilla

# ====================================================================
# FUNCIONES PUBLICAS
# ====================================================================

func obtener_estado_actual() -> EstadoJuego:
	return estado_actual

func obtener_jugador_actual() -> Node3D:
	if jugador_actual_index < jugadores.size():
		return jugadores[jugador_actual_index]
	return null

func obtener_turno_actual() -> int:
	return turno_actual

func es_turno_de_jugador(jugador: Node3D) -> bool:
	return jugador == obtener_jugador_actual()
