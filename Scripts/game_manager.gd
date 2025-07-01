extends Node
class_name GameManager

# Señales
signal turno_cambiado(jugador_actual)
signal jugador_movido(jugador, casilla_index)
signal partida_iniciada()
signal partida_finalizada(ganador)

# Referencias al Juego en si
@export var tablero: Path3D
@export var jugador_escena: PackedScene
@export var camera_manager: CameraManager
@export var nodo_inicio: Node3D
var jugadores: Array = []
var jugador_actual_index: int = 0
var rondas_completadas: int = 0

# Estado del Juego
var partida_activa: bool = false
var esperando_dado: bool = false

# Posicion de la Corona y Casillas
var tipos_originnales_casillas: Array = []
var posicion_corona: int = -1

# Variables Fin de Partida
enum TipoVictoria {RONDAS, CORONAS}
@export var tipo_victoria: TipoVictoria = TipoVictoria.RONDAS
@export var limite_rondas: int = 10
@export var limite_coronas: int = 3

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

# Instancia los Jugadores en el la posicion 0 del Tablero
func instanciar_jugador_en_tablero(jugador: Node3D):
	print("🏗️ Instanciando ", jugador.nombre, " en zona de inicio...")
	# Verificar nodo inicio
	if nodo_inicio == null:
		push_error("😠 No hay un nodo de inicio establecido")
		return
	# Añadir jugador al nodo inicio
	nodo_inicio.add_child(jugador)
	jugador.position = Vector3.ZERO
	# Configurar estado inicial
	jugador.pf = null
	jugador.posicion_tablero = -1
	print("👤 ", jugador.nombre, " instanciado en zona de inicio")
	print("📍 Posicion: ", jugador.global_position)

# Encontrar la posicion REAL de la casilla 0 (no progress_ratio 0)
func obtener_posicion_casilla_0() -> Vector3:
	print("🔍 Buscando posicion real de la casilla 0...")
	# Buscar la primera casilla del tablero (index 0)
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for grandchild in child.get_children():
				if grandchild.has_method("set_tipo") and grandchild.index == 0:
					print("✅ Casilla 0 encontrada en: ", child.global_position)
					return child.global_position
	# Si no se encuentra, usar progress_ratio 0.0 como fallback
	var pf_temp = PathFollow3D.new()
	pf_temp.progress_ratio = 0.0
	tablero.add_child(pf_temp)
	var pos = pf_temp.global_position
	tablero.remove_child(pf_temp)
	pf_temp.queue_free()
	print("⚠️ Usando progress_ratio 0.0 como fallback: ", pos)
	return pos

# Mover jugador desde zona inicio hacia la casilla 0 REAL
func mover_jugador_a_casilla_0(jugador: Node3D):
	print("🚀 Moviendo ", jugador.nombre, " desde inicio hacia casilla 0...")
	# Obtener posicion actual y destino
	var posicion_inicial = jugador.global_position
	var posicion_casilla_0 = obtener_posicion_casilla_0()
	print("📍 Desde: ", posicion_inicial)
	print("📍 Hacia: ", posicion_casilla_0)
	# ANIMAR movimiento
	var tween_movimiento = create_tween()
	tween_movimiento.set_ease(Tween.EASE_IN_OUT)
	tween_movimiento.tween_property(jugador, "global_position", posicion_casilla_0, 1.0)
	await tween_movimiento.finished
	print("✅ ", jugador.nombre, " llegó a la casilla 0")

# Asociar PathFollow3D al jugador una vez que esté en la casilla 0
func asociar_pathfollow_al_jugador(jugador: Node3D):
	print("🔗 Asociando PathFollow3D a ", jugador.nombre, "...")
	# 🎯 CREAR PathFollow3D
	var pf = PathFollow3D.new()
	pf.name = "PF3D_" + jugador.nombre
	pf.rotation_mode = PathFollow3D.ROTATION_Y
	# 🔍 BUSCAR casilla 0 con variable de control
	var progress_ratio_casilla_0 = 0.0
	var casilla_encontrada = false # ← NUEVA VARIABLE DE CONTROL
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for grandchild in child.get_children():
				if grandchild.has_method("set_tipo") and grandchild.index == 0:
					progress_ratio_casilla_0 = child.progress_ratio
					casilla_encontrada = true # ← MARCAR COMO ENCONTRADA
					print("✅ Casilla 0 encontrada con progress_ratio: ", progress_ratio_casilla_0)
					print("📍 Posicion de casilla 0: ", child.global_position)
					break
		if casilla_encontrada: # ← USAR VARIABLE DE CONTROL
			break
	# 📍 CONFIGURAR PathFollow3D
	tablero.add_child(pf)
	pf.progress_ratio = progress_ratio_casilla_0
	print("🎯 PathFollow3D configurado con progress_ratio: ", pf.progress_ratio)
	print("📍 Posicion final PathFollow3D: ", pf.global_position)
	# 🔄 MOVER jugador al PathFollow3D
	nodo_inicio.remove_child(jugador)
	jugador.position = Vector3.ZERO
	pf.add_child(jugador)
	# 🔧 CONFIGURAR referencias
	jugador.pf = pf
	jugador.posicion_tablero = 0
	print("✅ PathFollow3D asociado a ", jugador.nombre, " con progress_ratio FINAL: ", jugador.pf.progress_ratio)

# Mover jugador desde zona inicio hacia el Tablero
func mover_jugador_al_tablero(jugador: Node3D):
	print("🏃‍♂️ Llevando a ", jugador.nombre, " al tablero...")
	# Paso 1: Mover a la casilla 0
	await mover_jugador_a_casilla_0(jugador)
	# Paso 2: Asociar PathFollow3D
	asociar_pathfollow_al_jugador(jugador)
	print("🎯 ", jugador.nombre, " está listo para jugar en el tablero")

# Inicia la Partida
func iniciar_partida():
	# Si no hay mas de 2 jugadores no se empieza
	if jugadores.size() < 2:
		push_error("😭 Se necesitan al menos 2 jugadores para iniciar")
		return
	
	print("🌸 Iniciando Partida")
	print("🙍 Jugadores:")
	for i in jugadores.size():
		print("- ", jugadores[i].nombre, " (", jugadores[i].color, ")")
	# Guardar los tipos de casilla originales para poder revertir cambios
	guardar_tipos_originales()
	# Funcion que muestra donde esta la corona
	reposicionar_corona()
	await determinar_orden_inicial()
	partida_activa = true
	jugador_actual_index = 0
	emit_signal("partida_iniciada")
	# Se inicia el primer turno
	print("🏃‍♂️ Partida iniciada! Primer turno: ", jugadores[0].nombre)
	iniciar_turno()

# Guardar los Tipos de casillas originales
func guardar_tipos_originales():
	tipos_originnales_casillas.clear()
	for i in tablero.num_casillas:
		var casilla = obtener_casilla_en_posicion(i)
		if casilla:
			tipos_originnales_casillas.append(casilla.tipo)

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
	if jugador_actual.posicion_tablero == -1:
		print("\n🌟 Primer turno de ", jugador_actual.nombre)
		print("🏃‍♂️ Moviendo al tablero...")
		await mover_jugador_al_tablero(jugador_actual)
		await get_tree().create_timer(1.0).timeout
		print("🎯 ", jugador_actual.nombre, " está en el tablero")
		print("🎲 ¡Ahora tira el dado para tu primer movimiento!")
		emit_signal("turno_cambiado", jugador_actual)
		# Activar la espera del dado (como turno normal)
		esperando_dado = true
		print("🎲 Presiona ESPACIO para tirar el dado")
		return

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
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
	# El jugador actual en el turno tira los dados
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
func mover_jugador(jugador: Node3D, espacios: int):
	print("🏃‍♂️ Moviendo a ", jugador.nombre, " ", espacios, " espacios...")
	print("📍 Progress ratio inicial: ", jugador.pf.progress_ratio)
	var tween_secuencial = create_tween()
	for i in espacios:
		var posicion_anterior = jugador.posicion_tablero
		var nueva_posicion = (jugador.posicion_tablero + 1) % tablero.num_casillas
		var progress_actual = jugador.pf.progress_ratio
		var progress_destino = obtener_progress_ratio_de_casilla(nueva_posicion)
		print("🚀 Paso ", i + 1, ": casilla ", posicion_anterior, " → ", nueva_posicion)
		print("📊 Progress: ", progress_actual, " → ", progress_destino)
		# 🔧 SIMPLIFICAR: Solo vuelta completa en caso específico
		var necesita_vuelta_completa = false
		# ÚNICAMENTE cuando pasa de la última casilla a la primera
		if posicion_anterior == (tablero.num_casillas - 1) and nueva_posicion == 0:
			necesita_vuelta_completa = true
			print("🔄 Vuelta completa: última casilla → primera casilla")
		elif posicion_anterior == 0 and progress_actual > 0.8 and progress_destino < 0.2:
			necesita_vuelta_completa = true
		else:
			print("➡️ Movimiento normal")
		jugador.posicion_tablero = nueva_posicion
		# Aplicar movimiento
		if necesita_vuelta_completa:
			print("🔄 Aplicando secuencia de vuelta completa")
			tween_secuencial.tween_property(jugador.pf, "progress_ratio", 1.0, 0.5)
			tween_secuencial.tween_callback(func():
				print("🔄 Reseteando a progress_ratio 0.0")
				jugador.pf.progress_ratio = 0.0
			)
			if progress_destino > 0:
				tween_secuencial.tween_property(jugador.pf, "progress_ratio", progress_destino, 0.5)
		else:
			print("➡️ Movimiento directo a progress_ratio: ", progress_destino)
			tween_secuencial.tween_property(jugador.pf, "progress_ratio", progress_destino, 0.5)
		# Si el jugador llega a la casilla de la Corona, animar y transferir
		if jugador.posicion_tablero == posicion_corona:
			tween_secuencial.tween_interval(1.0)
			tween_secuencial.tween_callback(func():
				print("👑 ", jugador.nombre, " ha llegado a la casilla de la Corona!")
				transferir_corona(jugador)
			)
			tween_secuencial.tween_interval(1.0)
	await tween_secuencial.finished
	print("🎯 ", jugador.nombre, " llego a la casilla ", jugador.posicion_tablero)
	print("📍 Progress ratio final: ", jugador.pf.progress_ratio)
	emit_signal("jugador_movido", jugador, jugador.posicion_tablero)

# Obtener el progress_ratio REAL de una casilla específica
func obtener_progress_ratio_de_casilla(indice_casilla: int) -> float:
	print("🔍 Buscando progress_ratio real de casilla ", indice_casilla)
	# Buscar la casilla con el indice específico
	for child in tablero.get_children():
		if child is PathFollow3D and child.get_child_count() > 0:
			for grandchild in child.get_children():
				if grandchild.has_method("set_tipo") and grandchild.index == indice_casilla:
					print("✅ Casilla ", indice_casilla, " encontrada con progress_ratio: ", child.progress_ratio)
					return child.progress_ratio
	# Si no se encuentra, usar cálculo matemático como fallback
	var progress_fallback = float(indice_casilla) / float(tablero.num_casillas)
	print("⚠️ Casilla ", indice_casilla, " no encontrada, usando fallback: ", progress_fallback)
	return progress_fallback

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

# Transfiere la Corona al Jugador que ha llegado a la casilla de la Corona
func transferir_corona(jugador_corona: Node3D):
	jugador_corona.establecer_corona(1)
	# Cambiar la casilla actual de la corona a una de tipo Normal
	var casilla_corona_actual = obtener_casilla_en_posicion(posicion_corona)
	if casilla_corona_actual:
		var tipo_original = tipos_originnales_casillas[posicion_corona]
		casilla_corona_actual.set_tipo(tipo_original)
		print("🍃 La casilla ", posicion_corona, " volvió a su tipo original: ", casilla_corona_actual.tipo_casilla.keys()[tipo_original])
	# Reposicionar la Casilla de Corona a una nueva Casilla
	reposicionar_corona()

# Reposiciona la casilla de la Corona
func reposicionar_corona():
	var casillas_disponibles = []
	# Obtener cada casilla Roja o Normal
	for i in tablero.num_casillas:
		var pf = tablero.get_child(i)
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.tipo == casilla.tipo_casilla.ROJA or casilla.tipo == casilla.tipo_casilla.NORMAL:
				# Añadir la Casilla a un Array
				casillas_disponibles.append({"index": casilla.index, "casilla": casilla, "posicion": pf.global_position})
	# Encontrar la casilla mas alejada fisicamente
	if casillas_disponibles.size() > 0:
		var mejor_casilla = null
		var max_distancia = -1
		for casilla_info in casillas_disponibles:
			var distancia = casilla_info.posicion.distance_to(tablero.get_child(posicion_corona).global_position)
			if distancia > max_distancia:
				max_distancia = distancia
				mejor_casilla = casilla_info.casilla
		if mejor_casilla:
			mejor_casilla.set_tipo(mejor_casilla.tipo_casilla.CORONA)
			posicion_corona = mejor_casilla.index
			print("👑 La Corona se ha reposicionado en la casilla: ", posicion_corona)
	else:
		print("😢 No hay casillas disponibles para reposicionar la Corona")
		
# Metodo auxiliar para obbtener el tipo de casilla en una posicion dada
func obtener_casilla_en_posicion(posicion: int):
	if posicion < 0 or posicion >= tablero.num_casillas:
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
		# Finalizar partida si las rondas llegan a las establecidas
		if tipo_victoria == TipoVictoria.RONDAS and rondas_completadas >= limite_rondas:
			finalizar_partida()
			return
	# Finalizar partida si las coronas llegan a las establecidas
	if tipo_victoria == TipoVictoria.CORONAS:
		for jugador in jugadores:
			if jugador.coronas >= limite_coronas:
				finalizar_partida()
				return
	# Inicia el siguiente turno
	iniciar_turno()

func finalizar_partida():
	partida_activa = false
	print("🏁 ¡FIN DE PARTIDA!")
	var ganador = determinar_ganador()
	mostrar_resultados_finales(ganador)
	# Emitir señal de fin de partida
	emit_signal("partida_finalizada", ganador)

# Determina quien es el ganador
func determinar_ganador():
	var mejor_jugador = jugadores[0]
	match tipo_victoria:
		TipoVictoria.CORONAS:
			# En modo coronas, ya sabemos que alguien alcanzo el límite
			for jugador in jugadores:
				if jugador.coronas >= limite_coronas:
					return jugador

		TipoVictoria.RONDAS:
			# En modo rondas, gana quien tenga más coronas
			for jugador in jugadores:
				if jugador.coronas > mejor_jugador.coronas:
					mejor_jugador = jugador
				elif jugador.coronas == mejor_jugador.coronas:
					# En caso de empate, gana quien tenga más monedas
					if jugador.monedas > mejor_jugador.monedas:
						mejor_jugador = jugador

	return mejor_jugador

# Muestra los resultados finales
func mostrar_resultados_finales(ganador):
	print("\n🏆 ¡¡¡ RESULTADOS FINALES !!!")
	print("🥇 GANADOR: ", ganador.nombre)
	print("👑 Coronas: ", ganador.coronas)
	print("💰 Monedas: ", ganador.monedas)
	print("\n📊 Clasificación final:")

	# Ordenar jugadores por coronas y luego por monedas
	var jugadores_ordenados = jugadores.duplicate()
	jugadores_ordenados.sort_custom(func(a, b):
		if a.coronas != b.coronas:
			return a.coronas > b.coronas
		else:
			return a.monedas > b.monedas
	)

	for i in jugadores_ordenados.size():
		var j = jugadores_ordenados[i]
		var posicion = i + 1
		var medal = "🥇" if posicion == 1 else "🥈" if posicion == 2 else "🥉" if posicion == 3 else "🏅"
		print(medal, " ", posicion, ". ", j.nombre, " - ", j.coronas, "👑 ", j.monedas, "💰")

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
