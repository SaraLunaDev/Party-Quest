class_name MovementManager
extends Node

# Referencia al jugador que se esta moviendo
var jugador_actual: Node3D
var casillas_destino: Array[Casilla] = []
var casilla_actual_index: int = 0

# Configuracion de movimiento
@export var velocidad_movimiento: float = 5.0
@export var altura_salto: float = 2.0
@export var duracion_pausa: float = 0.3

# Estados de movimiento
var esta_moviendo: bool = false
var tween: Tween

signal movimiento_completado
signal casilla_alcanzada(casilla: Casilla)

func _ready():
	# Crear el tween para animaciones
	tween = create_tween()
	tween.set_parallel(true)

# ====================================================================
# FUNCIONES PRINCIPALES DE MOVIMIENTO
# ====================================================================

func mover_jugador_a_casilla(jugador: Node3D, casilla_destino: Casilla) -> void:
	if esta_moviendo:
		print("MovementManager: Ya hay un movimiento en progreso")
		return
	
	jugador_actual = jugador
	casillas_destino = [casilla_destino]
	casilla_actual_index = 0
	esta_moviendo = true
	
	_mover_a_siguiente_casilla()

func mover_jugador_por_pasos(jugador: Node3D, pasos: int) -> void:
	if esta_moviendo:
		print("MovementManager: Ya hay un movimiento en progreso")
		return
	
	# Obtener casilla actual del jugador
	var casilla_inicial = _encontrar_casilla_mas_cercana(jugador.global_position)
	if casilla_inicial == null:
		print("MovementManager: No se encontro casilla inicial")
		return
	
	# Calcular ruta de casillas
	casillas_destino = _calcular_ruta_pasos(casilla_inicial, pasos)
	if casillas_destino.is_empty():
		print("MovementManager: No se pudo calcular ruta")
		return
	
	jugador_actual = jugador
	casilla_actual_index = 0
	esta_moviendo = true
	
	_mover_a_siguiente_casilla()

# ====================================================================
# FUNCIONES INTERNAS DE MOVIMIENTO
# ====================================================================

func _mover_a_siguiente_casilla() -> void:
	if casilla_actual_index >= casillas_destino.size():
		_finalizar_movimiento()
		return
	
	var casilla_destino = casillas_destino[casilla_actual_index]
	var posicion_destino = casilla_destino.global_position
	
	# Detectar si es un salto (diferencia de altura significativa)
	var diferencia_altura = abs(posicion_destino.y - jugador_actual.global_position.y)
	var es_salto = diferencia_altura > 1.0
	
	if es_salto:
		_ejecutar_salto(posicion_destino)
	else:
		_ejecutar_movimiento_normal(posicion_destino)

func _ejecutar_movimiento_normal(destino: Vector3) -> void:
	var distancia = jugador_actual.global_position.distance_to(destino)
	var duracion = distancia / velocidad_movimiento
	
	# Animar movimiento
	tween = create_tween()
	tween.tween_property(jugador_actual, "global_position", destino, duracion)
	tween.tween_callback(_on_casilla_alcanzada)

func _ejecutar_salto(destino: Vector3) -> void:
	var distancia = jugador_actual.global_position.distance_to(destino)
	var duracion = distancia / velocidad_movimiento
	
	# Calcular punto medio del salto
	var punto_medio = (jugador_actual.global_position + destino) / 2
	punto_medio.y = max(jugador_actual.global_position.y, destino.y) + altura_salto
	
	# Animar salto en dos partes
	tween = create_tween()
	tween.set_parallel(true)
	
	# Primera parte: subir al punto medio
	tween.tween_property(jugador_actual, "global_position", punto_medio, duracion / 2)
	
	# Segunda parte: bajar al destino
	tween.tween_property(jugador_actual, "global_position", destino, duracion / 2)
	tween.tween_delay(duracion / 2)
	
	tween.tween_callback(_on_casilla_alcanzada)

func _on_casilla_alcanzada() -> void:
	var casilla_actual = casillas_destino[casilla_actual_index]
	casilla_alcanzada.emit(casilla_actual)
	
	# Pausa antes del siguiente movimiento
	await get_tree().create_timer(duracion_pausa).timeout
	
	casilla_actual_index += 1
	_mover_a_siguiente_casilla()

func _finalizar_movimiento() -> void:
	esta_moviendo = false
	jugador_actual = null
	casillas_destino.clear()
	casilla_actual_index = 0
	movimiento_completado.emit()

# ====================================================================
# FUNCIONES DE UTILIDAD
# ====================================================================

func _encontrar_casilla_mas_cercana(posicion: Vector3) -> Casilla:
	var distancia_minima = 999999.0
	var casilla_mas_cercana: Casilla = null
	
	# Buscar en todos los caminos del tablero
	var tablero = get_tree().get_first_node_in_group("tablero")
	if tablero == null:
		return null
	
	for camino in tablero.caminos:
		for child in camino.get_children():
			if child.name.begins_with("Casilla_"):
				var distancia = posicion.distance_to(child.global_position)
				if distancia < distancia_minima:
					distancia_minima = distancia
					casilla_mas_cercana = child
	
	return casilla_mas_cercana

func _calcular_ruta_pasos(casilla_inicial: Casilla, pasos: int) -> Array[Casilla]:
	var ruta: Array[Casilla] = []
	var casilla_actual = casilla_inicial
	
	for i in range(pasos):
		var siguientes_casillas = casilla_actual.get_casillas_destino()
		if siguientes_casillas.is_empty():
			break
		
		# Por ahora, tomar la primera opcion disponible
		casilla_actual = siguientes_casillas[0]
		ruta.append(casilla_actual)
	
	return ruta

# ====================================================================
# FUNCIONES PUBLICAS DE ESTADO
# ====================================================================

func detener_movimiento() -> void:
	if tween:
		tween.kill()
	_finalizar_movimiento()

func esta_en_movimiento() -> bool:
	return esta_moviendo
