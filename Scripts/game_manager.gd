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
var rondas_completadas: int = 0

# Estado del Juego
var partida_activa: bool = false
var esperando_dado: bool = false

# Posicion de la Corona
var posicion_corona: int = -1

# Ejecutar cosas al inicio
func _ready() -> void:
	if tablero == null:
		push_error("😠 No estableciste un tablero")
		return
	print("😀 GameManager iniciado Correctamente!")

# Configura los Jugadores que van a Jugar
func configurar_jugadores(datos_jugadores: Array):
	jugadores.clear()
	# Bucle que obtiene los datos de cada Jugador
	for dato in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		# Se configuran nombre y color
		jugador.configurar(dato.nombre, dato.color)
		# Añadir cada jugador al Array de Jugadores
		jugadores.append(jugador)
		# Instanciar el jugador en el trablero
		instanciar_jugador_en_tablero(jugador)
	
	print("Jugadores configurados: ", jugadores.size())

# Instancia los Jugadores en el la casilla 0 del Tablero
func instanciar_jugador_en_tablero(jugador: Node3D):
	# Bucle para todos los hijos del Tablero
	for i in tablero.get_child_count():
		# Obtener el Hijo
		var pf = tablero.get_child(i)
		var casilla = pf.get_child(0)
		# Comprobar que sea una Casilla
		if pf is PathFollow3D and casilla.has_method("set_tipo"):
			# TODO: El jugador no se añadira a la primera casilla
			#		hasta que no empiece su turno. En su lugar, 
			#		el turno de elegir el orden de jugadores se
			#		hara en un lugar cercano a la primera casilla
			#		y cuando el orden se establezca, tras usar
			#		el primer dado del primer turno, entonces
			#		se movera al jugador hacia esa casilla 0
			#		y empezara su movimiento sobre el tablero.
			#		Con el resto de primeros turnos igual, cada
			#		jugador hara lo mismo cuando llegue su primer
			#		turno.
			# Se añade el jugador a esa casilla
			casilla.add_child(jugador)
			jugador.actualizar_color()

# Inicia la Partida
func iniciar_partida():
	# Si no hay mas de 2 jugadores no se empieza
	if jugadores.size() < 2:
		push_error("😭 Se necesitan al menos 2 jugadores para iniciar")
		return
	print("🌸 Iniciando Partida")
	print("🙍 Jugadores:")
	# Mostrar los jugadores.
	# TODO CAMARA: La Camara muestra a los Jugadores
	for i in jugadores.size():
		print("- ", jugadores[i].nombre, " (", jugadores[i].color, ")")
	# Funcion que muestra donde esta la corona
	# TODO CAMARA: La Camara muestra la corona
	determinar_posicion_corona()
	# Determina el orden en el Tablero
	# TODO CAMARA: La Camara muestra a los Jugadores
	await determinar_orden_inicial()
	# TODO CAMARA: La Camara muestra al primer Jugador
	partida_activa = true
	jugador_actual_index = 0
	emit_signal("partida_iniciada")
	# Se inicia el primer turno
	print("🏃‍♂️ Partida iniciada! Primer turno: ", jugadores[0].nombre)
	iniciar_turno()

# Obtener la posicion de la Corona
func determinar_posicion_corona():
	for i in tablero.get_child_count():
		var pf = tablero.get_child(i)
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.tipo == casilla.tipo_casilla.CORONA:
				posicion_corona = casilla.index
				print("👑 La Corona esta en la casilla: ", posicion_corona)
				break

# Determinar el orden inicial de Jugadores
func determinar_orden_inicial():
	print("🤔 Determinando Turnos")
	# Se crea un Array para almacenar los dados obtenidos
	var resultados_dados = []
	# Simulacion de que dado obtiene cada jugador.
	# TODO: Cuando la funcion de multiplayer local este implementada,
	#		cada jugador lanzara su dado. Cuando todos los jugadores
	#		hayan lanzado su dado se seguira con el codigo. Por ahora
	#		se simulara la tirada.
	for jugador in jugadores:
		var resultado = tirar_dado()
		resultados_dados.append({"jugador": jugador, "dado": resultado})
		print(jugador.nombre, " tiró: ", resultado)
		await get_tree().create_timer(1.0).timeout
	# Se ordenan el Array de los resultados de mayor a menor
	resultados_dados.sort_custom(func(a, b): return a.dado > b.dado)
	# Se llena el Array de Jugadores con el orden establecido
	var jugadores_ordenados = []
	print("\n🫢 Orden de Juego determinado:")
	for i in resultados_dados.size():
		jugadores_ordenados.append(resultados_dados[i].jugador)
		print(str(i + 1) + ". ", resultados_dados[i].jugador.nombre, " (", resultados_dados[i].dado, ")")
	# Eje God
	jugadores = jugadores_ordenados

# Tira dados
func tirar_dado() -> int:
	return randi_range(1, 6)

# Iniciar Turno
func iniciar_turno():
	if not partida_activa:
		return
	# Se obtiene el jugador actual
	var jugador_actual = jugadores[jugador_actual_index]
	print("\n🎯 Turno de ", jugador_actual.nombre)
	print("🔖 Posicion actual: Casilla ", jugador_actual.posicion_tablero)
	print("💰 Monedas: ", jugador_actual.monedas)
	print("👑 Coronas: ", jugador_actual.coronas)
	# Señal de que ha cambiado el turno
	esperando_dado = true
	emit_signal("turno_cambiado", jugador_actual)
	# Se espera a que el jugador pulse espacio
	# TODO: Esto esta simulado para que yo siempre gestione
	#		a todos los jugadores, pero en el futuro debera
	#		haber un multiplayer local en el que la accion
	#		de lanzar el dado se gestione con el control
	#		del jugador en cuestion (se jugara con mando, cada
	#		jugador un mando y asi se diferenciaran, por lo que
	#		cada jugador debera tener un mando asignado a el)
	print("🎲 Presiona ESPACIO para tirar el dado")

# Procesar la tirada del Dado
func procesar_tirada_dado():
	# No se procesa si ya se esta tirando o no hay partida activa
	if not esperando_dado or not partida_activa:
		return
	esperando_dado = false
	# El jugador actual en el turno tira los dados
	var jugador_actual = jugadores[jugador_actual_index]
	var resultado_dado = tirar_dado()
	print("🎲 ", jugador_actual.nombre, " tiro: ", resultado_dado)
	# Mover al jugador hacia la posicion que obtuvo por los Dados
	await mover_jugador(jugador_actual, resultado_dado)
	# Obtener el efecto de la casilla
	# TODO: Animacion de dar o quitar monedas
	# TODO: Gestion de parar el tablero, mostrar el Minijuego, jugarlo, y volver al tablero
	procesar_casilla(jugador_actual)
	# Siguiente turno
	await get_tree().create_timer(2.0).timeout
	siguiente_turno()

# Mover Jugador por el Tablero
# TODO: Reemplazar logica de movimiento
func mover_jugador(jugador: Node3D, espacios: int):
	print("🏃‍♂️ Moviendo a ", jugador.nombre, " ", espacios, " espacios...")
	# TODO: El jugador debe estar bajo un PathFollow3d y moverse por el path3d del trablero haciendo uso de el
	#		por ahora se teletransporta entre casillas pero esto ha de cambiar por completo.
	for i in espacios:
		jugador.posicion_tablero = (jugador.posicion_tablero + 1) % tablero.get_child_count()
		var nueva_casilla = tablero.get_child(jugador.posicion_tablero)
		if nueva_casilla is PathFollow3D:
			if jugador.get_parent():
				jugador.get_parent().remove_child(jugador)
			nueva_casilla.add_child(jugador)
		await get_tree().create_timer(0.5).timeout
	print("🎯 ", jugador.nombre, " llego a la casilla ", jugador.posicion_tablero)
	emit_signal("jugador_movido", jugador, jugador.posicion_tablero)

# Obtener el tipo de Casilla en la que el Jugador ha caido
func procesar_casilla(jugador: Node3D):
	var casilla_actual = obtener_casilla_en_posicion(jugador.posicion_tablero)
	if casilla_actual == null:
		return
	print("🔍 Procesando caslla tipo: ", casilla_actual.tipo_casilla.keys()[casilla_actual.tipo])
	# Swich que gestiona que hacer en cada tipo de casilla
	match casilla_actual.tipo:
		casilla_actual.tipo_casilla.NORMAL:
			print("💙 ", jugador.nombre, " cayo en casilla normal (+3 monedas)")
			jugador.establecer_monedas(3)
		casilla_actual.tipo_casilla.ROJA:
			print("❤️ ", jugador.nombre, " cayo en casilla roja (-3 monedas)")
			jugador.establecer_monedas(-3)
		casilla_actual.tipo_casilla.MINIJUEGO:
			print("🎮 ", jugador.nombre, " cayo en casilla de minijuego!")
			# TODO: Implementar minijuegos
		casilla_actual.tipo_casilla.CORONA:
			print("👑 ", jugador.nombre, " llego a la casilla de la CORONA!")
			transferir_corona(jugador)

# TODO: La Corona no solo se podra obtener si el jugador cae en la casilla, si
#		mientras el jugador se esta moviendo pasa por la casilla de estrella,
#		debera pausar su movimiento, obtener la estrella, y seguir con el resto
#		de movimiento que le quedase.
# TODO: La casilla no siempre sera normal tras haber sido Corona, debera ser
#		lo que en un inicio fue antes de que se posicionara la corona. Para
#		esto hay que almacenar el tablero original sin corona, y cuando esta
#		cambie de posicion, la casilla volvera a ser lo que fue.
# Añadir la Corona al Jugador
func transferir_corona(jugador_corona: Node3D):
	jugador_corona.establecer_corona(1)
	# Cambiar la casilla actual de la corona a una de tipo Normal
	var casilla_corona_actual = obtener_casilla_en_posicion(posicion_corona)
	if casilla_corona_actual:
		casilla_corona_actual.set_tipo(casilla_corona_actual.tipo_casilla.NORMAL)
		print("🍃 La casilla ", posicion_corona, "ahora es NORMAL")
	# Reposicionar la Casilla de Corona a una nueva Casilla
	reposicionar_corona()

# Reposiciona la casilla de la Corona
func reposicionar_corona():
	var casillas_disponibles = []
	# Obtener cada casilla Roja o Normal
	for i in tablero.get_child_count():
		var pf = tablero.get_child(0)
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.tipo == casilla.tipo_casilla.ROJA or casilla.tipo == casilla.tipo_casilla.NORMAL:
				# Añadir la Casilla a un Array
				casillas_disponibles.append({"index": casilla.index, "casilla": casilla})
	# Se elige una casilla aleatoriamente
	if casillas_disponibles.size() > 0:
		var casilla_elegida = casillas_disponibles[randi() % casillas_disponibles.size()]
		# Se establece la nueva posicion de la Corona
		casilla_elegida.casilla.set_tipo(casilla_elegida.casilla.tipo_casilla.CORONA)
		posicion_corona = casilla_elegida.index
		print("👑 La corona se reposiciono a la casilla ", posicion_corona)
	else:
		print("😭 No hay casillas disponibles para reposicionar la corona")

# Metodo auxiliar para obbtener el tipo de casilla en una posicion dada
func obtener_casilla_en_posicion(posicion: int):
	if posicion < 0 or posicion >= tablero.get_child_count():
		return null
	var pf = tablero.get_child(posicion)
	if pf is PathFollow3D and pf.get_child_count() > 0:
		for child in pf.get_children():
			if child.has_method("set_tipo"):
				return child
	return null

# Gestiona el siguiente turno
func siguiente_turno():
	# Obtiene en siguiente jugador
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	# Si es final de ronda
	if jugador_actual_index == 0:
		rondas_completadas += 1
		print("🍃 Fin de ronda ", rondas_completadas)
		motrar_estado_jugadores()
	# Inicia el siguiente turno
	iniciar_turno()

# Mostrar estado de Jugadores
# TODO: Por ahora es solo un log, pero despues de cada ronda habra un UI
#		element que mostrara las estats de cada jugador de forma visual
func motrar_estado_jugadores():
	print("\n📊 Estado actual de los jugadores:")
	for i in jugadores.size():
		var j = jugadores[i]
		print(str(i + 1), ". ", j.obtener_info())

# Funcion para debugear y probar la partida
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
