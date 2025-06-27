extends Node

# Señales
signal turno_cambiado(jugador_actual)
signal jugador_movido(jugador, casilla_index)
signal partida_iniciada()

# Referencias al Juego en si
@export var tablero: Path3D
@export var jugador_escena: PackedScene
var jugadores: Array = []
var jugador_actual_index: int = 0
var turnos_completados: int = 0

# Estado del Juego
var partida_activa: bool = false
var esperando_dado: bool = false

# Corona
var posicion_corona: int = -1

# Ejecutar cosas al inicio
func _ready() -> void:
	if tablero == null:
		push_error("😠 No estableciste un tablero")
		return
	
	print("😀 GameManager iniciado Correctamente!")

func configurar_jugadores(datos_jugadores: Array):
	jugadores.clear()
	
	for dato in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		
		jugador.configurar(dato.nombre, dato.color)
		
		jugadores.append(jugador)
		instanciar_jugador_en_tablero(jugador)
	
	print("Jugadores configurados: ", jugadores.size())

func instanciar_jugador_en_tablero(jugador: Node3D):
	var primera_casilla = tablero.get_child(0)
	primera_casilla.add_child(jugador)
	jugador.position.y = 1.0
	
	jugador.actualizar_color()

func iniciar_partida():
	if jugadores.size() < 2:
		push_error("😭 Se necesitan al menos 2 jugadores para iniciar")
		return
	
	print("🌸 Iniciando Partida")
	print("🙍 Jugadores:")
	for i in jugadores.size():
		print("- ", jugadores[i].nombre, " (", jugadores[i].color, ")")
	
	determinar_posicion_corona()
	
	await determinar_orden_inicial()
	
	partida_activa = true
	jugador_actual_index = 0
	emit_signal("partida_iniciada")
	
	print("🏃‍♂️ Partida iniciada! Primer turno: ", jugadores[0].nombre)
	iniciar_turno()

func determinar_posicion_corona():
	for i in tablero.get_child_count():
		var pf = tablero.get_child(i)
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.tipo == casilla.tipo_casilla.CORONA:
				posicion_corona = casilla.index
				print("👑 La Corona esta en la casilla: ", posicion_corona)
				break

func determinar_orden_inicial():
	print("🤔 Determinando Turnos")
	var resultados_dados = []
	
	for jugador in jugadores:
		var resultado = tirar_dado()
		resultados_dados.append({"jugador": jugador, "dado": resultado})
		print(jugador.nombre, " tiró: ", resultado)
		await get_tree().create_timer(1.0).timeout
	
	resultados_dados.sort_custom(func(a, b): return a.dado > b.dado)
	
	var jugadores_ordenados = []
	print("\n🫢 Orden de Juego determinado:")
	for i in resultados_dados.size():
		jugadores_ordenados.append(resultados_dados[i].jugador)
		print(str(i + 1) + ". ", resultados_dados[i].jugador.nombre, " (", resultados_dados[i].dado, ")")
	
	jugadores = jugadores_ordenados

func tirar_dado() -> int:
	return randi_range(1, 6)

func iniciar_turno():
	if not partida_activa:
		return
	
	var jugador_actual = jugadores[jugador_actual_index]
	print("\n🎯 Turno de ", jugador_actual.nombre)
	print("🔖 Posicion actual: Casilla ", jugador_actual.posicion_tablero)
	print("💰 Monedas: ", jugador_actual.monedas)
	print("👑 Coronas: ", jugador_actual.coronas)
	
	esperando_dado = true
	emit_signal("turno_cambiado", jugador_actual)
	
	print("🎲 Presiona ESPACIO para tirar el dado")

func procesar_tirada_dado():
	if not esperando_dado or not partida_activa:
		return
	
	esperando_dado = false
	var jugador_actual = jugadores[jugador_actual_index]
	var resultado_dado = tirar_dado()
	
	print("🎲 ", jugador_actual.nombre, " tiro: ", resultado_dado)
	
	await mover_jugador(jugador_actual, resultado_dado)
	
	procesar_casilla(jugador_actual)
	
	await get_tree().create_timer(2.0).timeout
	siguiente_turno()

func mover_jugador(jugador: Node3D, espacios: int):
	print("🏃‍♂️ Moviendo a ", jugador.nombre, " ", espacios, " espacios...")
	
	for i in espacios:
		jugador.posicion_tablero = (jugador.posicion_tablero + 1) % tablero.get_child_count()
		
		var nueva_casilla = tablero.get_child(jugador.posicion_tablero)
		if nueva_casilla is PathFollow3D:
			if jugador.get_parent():
				jugador.get_parent().remove_child(jugador)
			
			nueva_casilla.add_child(jugador)
			jugador.position.y = 1.0
		
		await get_tree().create_timer(0.5).timeout
	
	print("🎯 ", jugador.nombre, " llego a la casilla ", jugador.posicion_tablero)
	emit_signal("jugador_movido", jugador, jugador.posicion_tablero)

func procesar_casilla(jugador: Node3D):
	var casilla_actual = obtener_casilla_en_posicion(jugador.posicion_tablero)
	if casilla_actual == null:
		return
	
	print("🔍 Procesando caslla tipo: ", casilla_actual.tipo_casilla.keys()[casilla_actual.tipo])
	
	match casilla_actual.tipo:
		casilla_actual.tipo_casilla.NORMAL:
			print("💙 ", jugador.nombre, " cayó en casilla normal (+3 monedas)")
			jugador.establecer_monedas(3)
		casilla_actual.tipo_casilla.ROJA:
			print("❤️ ", jugador.nombre, " cayó en casilla roja (-3 monedas)")
			jugador.establecer_monedas(-3)
		casilla_actual.tipo_casilla.MINIJUEGO:
			print("🎮 ", jugador.nombre, " cayó en casilla de minijuego!")
			# TODO: Implementar minijuegos
		casilla_actual.tipo_casilla.CORONA:
			print("👑 ", jugador.nombre, " llegó a la casilla de la CORONA!")
			transferir_corona(jugador)

func transferir_corona(jugador_corona: Node3D):
	jugador_corona.establecer_corona(1)
	
	var casilla_corona_actual = obtener_casilla_en_posicion(posicion_corona)
	if casilla_corona_actual:
		casilla_corona_actual.set_tipo(casilla_corona_actual.tipo_casilla.NORMAL)
		print("🍃 La casilla ", posicion_corona, "ahora es NORMAL")
	
	reposicionar_corona()

func reposicionar_corona():
	var casillas_disponibles = []
	
	for i in tablero.get_child_count():
		var pf = tablero.get_child(0)
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.tipo == casilla.tipo_casilla.ROJA or casilla.tipo == casilla.tipo_casilla.NORMAL:
				casillas_disponibles.append({"index": casilla.index, "casilla": casilla})
	
	if casillas_disponibles.size() > 0:
		var casilla_elegida = casillas_disponibles[randi() % casillas_disponibles.size()]
		
		casilla_elegida.casilla.set_tipo(casilla_elegida.casilla.tipo_casilla.CORONA)
		posicion_corona = casilla_elegida.index
		
		print("👑 La corona se reposiciono a la casilla ", posicion_corona)
	else:
		print("😭 No hay casillas disponibles para reposicionar la corona")

func obtener_casilla_en_posicion(posicion: int):
	if posicion < 0 or posicion >= tablero.get_child_count():
		return null
	
	var pf = tablero.get_child(posicion)
	if pf is PathFollow3D and pf.get_child_count() > 0:
		for child in pf.get_children():
			if child.has_method("set_tipo"):
				return child
	 
	return null

func siguiente_turno():
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	
	if jugador_actual_index == 0:
		turnos_completados += 1
		print("🍃 Fin de ronda ", turnos_completados)
		motrar_estado_jugadores()
	
	iniciar_turno()

func motrar_estado_jugadores():
	print("\n📊 Estado actual de los jugadores:")
	for i in jugadores.size():
		var j = jugadores[i]
		print(str(i + 1), ". ", j.obtener_info())

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE and esperando_dado:
			procesar_tirada_dado()
		elif event.keycode == KEY_S and jugadores.size() == 0:
			var datos_test = [
				{"nombre": "Mario", "color": Color.RED},
				{"nombre": "Luigi", "color": Color.GREEN},
				{"nombre": "Peach", "color": Color.PINK},
				{"nombre": "Wario", "color": Color.YELLOW},
				{"nombre": "Waluigi", "color": Color.PURPLE}
			]
			configurar_jugadores(datos_test)
			await get_tree().create_timer(1.0).timeout
			iniciar_partida()
