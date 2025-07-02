extends Node
class_name GameManager

# ============================================================================
# SEÑALES Y CONFIGURACION INICIAL
# ============================================================================

# Señales del juego
signal turno_cambiado(jugador_actual)
signal jugador_movido(jugador, casilla_index)
signal partida_iniciada()
signal partida_finalizada(ganador)

# Referencias principales
@export var tablero: Path3D
@export var jugador_escena: PackedScene
@export var camara_manager: CameraManager
@export var nodo_inicio: Node3D

# Arrays y estado del juego
var jugadores: Array = []
var tipos_originales_casillas: Array = []

# Variables de control de turno
var jugador_actual_index: int = 0
var rondas_completadas: int = 0
var partida_activa: bool = false
var esperando_dado: bool = false
var posicion_corona: int = -1

# Configuracion de victoria
enum TipoVictoria {RONDAS, CORONAS}
@export var tipo_victoria: TipoVictoria = TipoVictoria.RONDAS
@export var limite_rondas: int = 10
@export var limite_coronas: int = 3

# ============================================================================
# INICIALIZACION Y CONFIGURACION
# ============================================================================

func _ready() -> void:
	if tablero == null:
		push_error("No hay tablero asignado")
		return
	if camara_manager == null:
		push_error("No hay CameraManager asignado")
		return
	print("GameManager iniciado correctamente")

func configurar_jugadores(datos_jugadores: Array):
	jugadores.clear()
	for dato in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		jugador.configurar(dato.nombre, dato.color)
		jugadores.append(jugador)
		instanciar_jugador_inicial(jugador)
	print("Jugadores configurados: ", jugadores.size())

func instanciar_jugador_inicial(jugador: Node3D):
	if nodo_inicio == null:
		push_error("No hay nodo de inicio establecido")
		return
	nodo_inicio.add_child(jugador)
	jugador.position = Vector3.ZERO
	jugador.pf = null
	jugador.posicion_tablero = -1

# ============================================================================
# GESTION DE PARTIDA
# ============================================================================

func iniciar_partida():
	if jugadores.size() < 2:
		push_error("Se necesitan al menos 2 jugadores")
		return
	
	print("Iniciando partida con ", jugadores.size(), " jugadores")
	guardar_tipos_originales()
	
	# Posicionar corona inicial
	posicion_corona = -1
	await posicionar_corona_inicial()
	
	# Determinar orden y comenzar
	await determinar_orden_inicial()
	partida_activa = true
	jugador_actual_index = 0
	emit_signal("partida_iniciada")
	iniciar_turno()

func finalizar_partida():
	partida_activa = false
	var ganador = determinar_ganador()
	mostrar_resultados_finales(ganador)
	emit_signal("partida_finalizada", ganador)

func siguiente_turno():
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	
	if jugador_actual_index == 0:
		rondas_completadas += 1
		print("Ronda ", rondas_completadas, " completada")
		verificar_condiciones_victoria()
		return
	
	if verificar_condiciones_victoria():
		return
	
	iniciar_turno()

func verificar_condiciones_victoria() -> bool:
	# Victoria por rondas
	if tipo_victoria == TipoVictoria.RONDAS and rondas_completadas >= limite_rondas:
		finalizar_partida()
		return true
	
	# Victoria por coronas
	if tipo_victoria == TipoVictoria.CORONAS:
		for jugador in jugadores:
			if jugador.coronas >= limite_coronas:
				finalizar_partida()
				return true
	
	if jugador_actual_index == 0 and rondas_completadas > 0:
		iniciar_turno()
	
	return false

# ============================================================================
# GESTION DE TURNOS
# ============================================================================

func iniciar_turno():
	if not partida_activa:
		return
	
	var jugador_actual = jugadores[jugador_actual_index]
	
	# Primer turno - mover al tablero
	if jugador_actual.posicion_tablero == -1:
		print("Primer turno de ", jugador_actual.nombre)
		await mover_jugador_al_tablero(jugador_actual)
		await get_tree().create_timer(1.0).timeout
		emit_signal("turno_cambiado", jugador_actual)
		esperando_dado = true
		return
	
	# Turno normal
	print("Turno de ", jugador_actual.nombre, " - Casilla ", jugador_actual.posicion_tablero)
	esperando_dado = true
	emit_signal("turno_cambiado", jugador_actual)

func procesar_tirada_dado():
	if not esperando_dado or not partida_activa:
		return
	
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
	var resultado = tirar_dado()
	
	print(jugador_actual.nombre, " tiro: ", resultado)
	await mover_jugador_en_tablero(jugador_actual, resultado)
	
	await get_tree().create_timer(2.0).timeout
	siguiente_turno()

func tirar_dado() -> int:
	return randi_range(1, 6)

func determinar_orden_inicial():
	var resultados = []
	for jugador in jugadores:
		var dado = tirar_dado()
		resultados.append({"jugador": jugador, "dado": dado})
		print(jugador.nombre, " tiro: ", dado)
	
	resultados.sort_custom(func(a, b): return a.dado > b.dado)
	
	var jugadores_ordenados = []
	print("Orden determinado:")
	for i in resultados.size():
		jugadores_ordenados.append(resultados[i].jugador)
		print(i + 1, ". ", resultados[i].jugador.nombre)
	
	jugadores = jugadores_ordenados

# ============================================================================
# MOVIMIENTO DE JUGADORES
# ============================================================================

func mover_jugador_al_tablero(jugador: Node3D):
	print("Moviendo ", jugador.nombre, " al tablero")
	await mover_a_casilla_inicio(jugador)
	crear_pathfollow_para_jugador(jugador)

func mover_a_casilla_inicio(jugador: Node3D):
	var posicion_destino = obtener_posicion_casilla_0()
	var tween = create_tween()
	tween.tween_property(jugador, "global_position", posicion_destino, 1.0)
	await tween.finished

func crear_pathfollow_para_jugador(jugador: Node3D):
	var pf = PathFollow3D.new()
	pf.name = "PF_" + jugador.nombre
	pf.rotation_mode = PathFollow3D.ROTATION_Y
	
	# Buscar progress_ratio de casilla 0
	var progress_casilla_0 = obtener_progress_ratio_casilla(0)
	
	tablero.add_child(pf)
	pf.progress_ratio = progress_casilla_0
	
	# Transferir jugador al PathFollow
	nodo_inicio.remove_child(jugador)
	pf.add_child(jugador)
	jugador.position = Vector3.ZERO
	
	# Configurar referencias
	jugador.pf = pf
	jugador.posicion_tablero = 0

func mover_jugador_en_tablero(jugador: Node3D, espacios: int):
	print("Moviendo ", jugador.nombre, " ", espacios, " espacios")
	var tween = create_tween()
	
	for i in espacios:
		var posicion_anterior = jugador.posicion_tablero
		var nueva_posicion = (jugador.posicion_tablero + 1) % tablero.num_casillas
		var progress_destino = obtener_progress_ratio_casilla(nueva_posicion)
		
		jugador.posicion_tablero = nueva_posicion
		
		# Detectar vuelta completa
		if posicion_anterior == (tablero.num_casillas - 1) and nueva_posicion == 0:
			tween.tween_property(jugador.pf, "progress_ratio", 1.0, 0.5)
			tween.tween_callback(func(): jugador.pf.progress_ratio = 0.0)
			if progress_destino > 0:
				tween.tween_property(jugador.pf, "progress_ratio", progress_destino, 0.5)
		else:
			tween.tween_property(jugador.pf, "progress_ratio", progress_destino, 0.5)
		
		if jugador.posicion_tablero == posicion_corona:
			tween.tween_callback(procesar_corona_durante_tween.bind(jugador, i + 1, espacios))
	
	await tween.finished
	
	emit_signal("jugador_movido", jugador, jugador.posicion_tablero)

func procesar_corona_durante_tween(jugador: Node3D, _paso_actual: int, _pasos_totales: int):
	print(jugador.nombre, " obtuvo una corona!")
	jugador.establecer_corona(1)

	restaurar_casilla_corona()
	await get_tree().create_timer(1.0).timeout
	await reposicionar_corona()

func obtener_pathfollow_por_casilla(casilla: Node3D):
	if casilla == null:
		return null

	var parent = casilla.get_parent()
	if parent is PathFollow3D:
		return parent
	return null

# ============================================================================
# SISTEMA DE CORONA
# ============================================================================

func posicionar_corona_inicial():
	print("Posicionando corona inicial")
	var casillas_disponibles = obtener_casillas_disponibles()
	if casillas_disponibles.is_empty():
		print("No hay casillas disponibles para corona")
		return
	
	var mejor_casilla = encontrar_casilla_mas_alejada_inicio(casillas_disponibles)
	if mejor_casilla:
		establecer_corona_en_casilla(mejor_casilla)
		if camara_manager:
			await camara_manager.zoom_temporal_a_coordenada(mejor_casilla.posicion, 3, 0.95)

func procesar_llegada_corona(jugador: Node3D):
	print(jugador.nombre, " llego a la corona")
	
	jugador.establecer_corona(1)
	restaurar_casilla_corona()
	
	await get_tree().create_timer(1.0).timeout
	await reposicionar_corona()

func reposicionar_corona():
	print("Reposicionando corona")
	var casillas_disponibles = obtener_casillas_disponibles()
	if casillas_disponibles.is_empty():
		return
	
	var mejor_casilla = encontrar_casilla_mas_alejada_jugadores(casillas_disponibles)
	if mejor_casilla:
		establecer_corona_en_casilla(mejor_casilla)
		if camara_manager:
			await camara_manager.zoom_temporal_a_coordenada(mejor_casilla.posicion, 3, 0.95)

func restaurar_casilla_corona():
	var casilla_corona = obtener_casilla_por_indice(posicion_corona)
	if casilla_corona and posicion_corona < tipos_originales_casillas.size():
		var tipo_original = tipos_originales_casillas[posicion_corona]
		casilla_corona.set_tipo(tipo_original)

func establecer_corona_en_casilla(info_casilla):
	info_casilla.casilla.set_tipo(info_casilla.casilla.tipo_casilla.CORONA)
	posicion_corona = info_casilla.index
	print("Corona establecida en casilla ", posicion_corona)

# ============================================================================
# BUSQUEDA Y CALCULOS
# ============================================================================

func obtener_casillas_disponibles() -> Array:
	var disponibles = []
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for casilla in child.get_children():
				if casilla.has_method("set_tipo"):
					if casilla.tipo == casilla.tipo_casilla.ROJA or casilla.tipo == casilla.tipo_casilla.NORMAL:
						disponibles.append({
							"index": casilla.index,
							"casilla": casilla,
							"posicion": child.global_position,
							"pathfollow": child
						})
	return disponibles

func encontrar_casilla_mas_alejada_inicio(casillas: Array):
	var posicion_inicio = obtener_posicion_casilla_0()
	var mejor_casilla = null
	var max_distancia = -1
	
	for info in casillas:
		var distancia = info.posicion.distance_to(posicion_inicio)
		if distancia > max_distancia:
			max_distancia = distancia
			mejor_casilla = info
	
	return mejor_casilla

func encontrar_casilla_mas_alejada_jugadores(casillas: Array):
	var posiciones_jugadores = obtener_posiciones_jugadores()
	if posiciones_jugadores.is_empty():
		return encontrar_casilla_mas_alejada_inicio(casillas)
	
	var mejor_casilla = null
	var max_distancia_minima = -1
	
	for info in casillas:
		var distancia_minima = INF
		for pos_jugador in posiciones_jugadores:
			var distancia = info.posicion.distance_to(pos_jugador)
			if distancia < distancia_minima:
				distancia_minima = distancia
		
		if distancia_minima > max_distancia_minima:
			max_distancia_minima = distancia_minima
			mejor_casilla = info
	
	return mejor_casilla

func obtener_posiciones_jugadores() -> Array:
	var posiciones = []
	for jugador in jugadores:
		if jugador.posicion_tablero >= 0 and jugador.pf:
			posiciones.append(jugador.pf.global_position)
	return posiciones

# ============================================================================
# UTILIDADES Y HELPERS
# ============================================================================

func obtener_posicion_casilla_0() -> Vector3:
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for casilla in child.get_children():
				if casilla.has_method("set_tipo") and casilla.index == 0:
					return child.global_position
	
	# Fallback
	var pf_temp = PathFollow3D.new()
	tablero.add_child(pf_temp)
	pf_temp.progress_ratio = 0.0
	var pos = pf_temp.global_position
	tablero.remove_child(pf_temp)
	pf_temp.queue_free()
	return pos

func obtener_progress_ratio_casilla(indice: int) -> float:
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for casilla in child.get_children():
				if casilla.has_method("set_tipo") and casilla.index == indice:
					return child.progress_ratio
	
	return float(indice) / float(tablero.num_casillas)

func obtener_casilla_por_indice(indice: int):
	if indice < 0 or indice >= tablero.num_casillas:
		return null
	
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for casilla in child.get_children():
				if casilla.has_method("set_tipo") and casilla.index == indice:
					return casilla
	return null

func guardar_tipos_originales():
	tipos_originales_casillas.clear()
	tipos_originales_casillas.resize(tablero.num_casillas)
	
	for i in tablero.num_casillas:
		var casilla = obtener_casilla_por_indice(i)
		if casilla:
			tipos_originales_casillas[i] = casilla.tipo
		else:
			tipos_originales_casillas[i] = 0

# ============================================================================
# PROCESAMIENTO DE CASILLAS
# ============================================================================

func procesar_efectos_casilla(jugador: Node3D):
	var casilla = obtener_casilla_por_indice(jugador.posicion_tablero)
	if casilla == null:
		return
	
	match casilla.tipo:
		casilla.tipo_casilla.NORMAL:
			print(jugador.nombre, " gana 3 monedas")
			jugador.establecer_monedas(3)
		casilla.tipo_casilla.ROJA:
			print(jugador.nombre, " pierde 3 monedas")
			jugador.establecer_monedas(-3)
		casilla.tipo_casilla.MINIJUEGO:
			print(jugador.nombre, " activa minijuego")
		casilla.tipo_casilla.CORONA:
			print(jugador.nombre, " llego a corona")

# ============================================================================
# RESULTADOS Y ESTADISTICAS
# ============================================================================

func determinar_ganador():
	var mejor = jugadores[0]
	
	match tipo_victoria:
		TipoVictoria.CORONAS:
			for jugador in jugadores:
				if jugador.coronas >= limite_coronas:
					return jugador
		TipoVictoria.RONDAS:
			for jugador in jugadores:
				if jugador.coronas > mejor.coronas:
					mejor = jugador
				elif jugador.coronas == mejor.coronas and jugador.monedas > mejor.monedas:
					mejor = jugador
	
	return mejor

func mostrar_resultados_finales(ganador):
	print("GANADOR: ", ganador.nombre)
	print("Coronas: ", ganador.coronas, " Monedas: ", ganador.monedas)
	
	var ordenados = jugadores.duplicate()
	ordenados.sort_custom(func(a, b):
		if a.coronas != b.coronas:
			return a.coronas > b.coronas
		return a.monedas > b.monedas
	)
	
	print("Clasificacion final:")
	for i in ordenados.size():
		var j = ordenados[i]
		print(i + 1, ". ", j.nombre, " - ", j.coronas, " coronas, ", j.monedas, " monedas")

# ============================================================================
# INPUT Y DEBUG
# ============================================================================

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				if esperando_dado:
					procesar_tirada_dado()
			KEY_S:
				if jugadores.size() == 0:
					var datos = [
						{"nombre": "Mario", "color": Color.RED},
						{"nombre": "Luigi", "color": Color.GREEN},
						{"nombre": "Peach", "color": Color.PINK},
						{"nombre": "Wario", "color": Color.YELLOW}
					]
					configurar_jugadores(datos)
					await get_tree().create_timer(1.0).timeout
					iniciar_partida()
