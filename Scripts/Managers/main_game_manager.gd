extends Node
class_name MainGameManager

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Variables
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

# Señales
signal partida_iniciada()
signal partida_finalizada()
signal turno_iniciado(jugador_actual)

# Variables Exportadas
@export var tablero: Node3D
@export var jugador_escena: PackedScene
@export var limite_rondas: int = 5

# Variables Privadas
var jugadores: Array = []
var jugador_actual_index: int = 0
var rondas_completadas: int = 0
var partida_activa: bool = false
var esperando_dado: bool = false
var tirada_maxima: int = 6
var en_bifurcacion: bool = false

# Variables para bifurcaciones
var casillas_destino_disponibles: Array[Casilla] = []
var indice_destino_seleccionado: int = 0
var jugador_en_bifurcacion: Node3D = null

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Configuracion Inicial
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func _ready() -> void:
	if tablero == null:
		print("❌ Error: El nodo 'tablero' no esta asignado.")

	print("💚 Game Manager Listo")

func instanciar_jugadores(datos_jugadores: Array):
	if jugador_escena == null:
		print("❌ Error: La escena del jugador no esta asignada.")
		return

	jugadores.clear()

	for datos in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		jugador.configurar(datos.nombre, datos.color)
		jugadores.append(jugador)

	var casilla_actual = buscar_casilla(0)

	for jugador in jugadores:
		tablero.add_child(jugador)
		jugador.position = casilla_actual.global_position
		jugador.rotation_degrees = Vector3.ZERO
		jugador.pf = null
		jugador.posicion_casilla = 0

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Gestion de Partida
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func comenzar_partida():
	if jugadores.size() < 2:
		print("❌ Error: No hay suficientes jugadores para comenzar la partida.")

	print("\n🎉 Partida iniciada con ", jugadores.size(), " jugadores.")
	# TODO: Instanciar Corona
	await determinar_orden()
	partida_activa = true
	emit_signal("partida_iniciada")
	iniciar_turno()

func finalizar_partida():
	partida_activa = false
	# TODO: Elegir Ganador
	emit_signal("partida_finalizada")

	print("\n🏁 Partida finalizada.")
	
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Gestion de Turnos
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func determinar_orden():
	print("\n🤔 Determinando el orden")
	var resultados = []
	for jugador in jugadores:
		var resultado_dado = randi() % tirada_maxima + 1
		resultados.append({"jugador": jugador, "resultado": resultado_dado})
		print("   ", "🎲 ", jugador.nombre, " ha tirado: ", resultado_dado)
	resultados.sort_custom(func(a, b): return a.resultado > b.resultado)
	var jugadores_ordenados = []
	
	print("\n😯 Orden de Jugadores:")
	for i in resultados.size():
		jugadores_ordenados.append(resultados[i].jugador)
		print("   ", i + 1, ".- ", resultados[i].jugador.nombre)
	jugadores = jugadores_ordenados
	print()

func iniciar_turno():
	if !partida_activa:
		return
	if jugador_actual_index == 0:
		rondas_completadas += 1
		if rondas_completadas > limite_rondas:
			finalizar_partida()
			return
		else:
			print("🔄 Comenzando ronda ", rondas_completadas)
			print("----------------------")
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = true
	emit_signal("turno_iniciado", jugador_actual)
	
	print("🎮 Turno de ", jugador_actual.nombre)

func tirar_dado():
	if !esperando_dado or !partida_activa:
		return

	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
	var resultado_dado = randi() % tirada_maxima + 1
	print("   ", "🎲 ", jugador_actual.nombre, " ha tirado: ", resultado_dado)
	
	await mover_jugador(jugador_actual, resultado_dado)
	
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	iniciar_turno()

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Movimiento de Jugador
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func mover_jugador(jugador: Node3D, espacios: int):
	print("   ", "🚶‍♂️ ", jugador.nombre, " se mueve ", espacios, " espacios.")

	for i in espacios:
		var posicion = jugador.posicion_casilla
		# Obtener casilla actual
		var casilla_actual = buscar_casilla(posicion)
		if casilla_actual == null:
			print("   ", "❌ No se encontro la casilla ", posicion)
			return
			
		# Ver destinos de la casilla actual
		var destinos = casilla_actual.get_casillas_destino()
		if destinos.size() == 0:
			print("   ", "❌ No hay destinos disponibles en la casilla ", posicion)
			return
		
		var destino: Casilla
		
		# Si hay mas de un destino, manejar bifurcacion
		if destinos.size() > 1:
			print("   ", "🔀 Bifurcacion detectada en casilla ", posicion)
			destino = manejar_bifurcacion(jugador, destinos)
		else:
			# Solo un destino, continuar normalmente
			destino = destinos[0]
		
		print("      ", "➡️ ", jugador.nombre, " se mueve a la casilla ", destino.index)
		
		# Mover al jugador a la nueva casilla
		jugador.posicion_casilla = destino.index
		jugador.position = destino.global_position

		await get_tree().create_timer(0.5).timeout
	
	print("   ", "✅ ", jugador.nombre, " ha llegado a la casilla ", jugador.posicion_casilla, "\n")

func manejar_bifurcacion(_jugador: Node3D, destinos: Array[Casilla]) -> Casilla:
	# Seleccion aleatoria para NPCs
	# TODO: Implementar tipo de jugador para diferenciar entre persona y NPC
	var destino = destinos[randi() % destinos.size()]
	print("      ", "🎲 Seleccion aleatoria: casilla ", destino.index)
	return destino
	
	# TODO: Implementar seleccion manual para el Jugador tipo persona

func buscar_casilla(indice: int) -> Casilla:
	var todas_casillas = get_tree().get_nodes_in_group("casilla")
	for casilla in todas_casillas:
		if casilla.index == indice:
			return casilla
	return null

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Bifurcaciones
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func iniciar_seleccion_bifurcacion(jugador: Node3D, destinos: Array[Casilla]):
	en_bifurcacion = true
	jugador_en_bifurcacion = jugador
	casillas_destino_disponibles = destinos
	indice_destino_seleccionado = 0
	
	print("🔀 ", jugador.nombre, " esta en una bifurcacion con ", destinos.size(), " opciones:")
	for i in destinos.size():
		var prefijo = "👉 " if i == indice_destino_seleccionado else "   "
		print("   ", prefijo, i + 1, ". Casilla ", destinos[i].index)
	
	# Encender luz de la opcion seleccionada
	actualizar_indicadores_visuales()

func preseleccionar_destino(incremento: int) -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	# Actualizar indice
	indice_destino_seleccionado = (indice_destino_seleccionado + incremento) % casillas_destino_disponibles.size()
	if indice_destino_seleccionado < 0:
		indice_destino_seleccionado = casillas_destino_disponibles.size() - 1
	
	var casilla_seleccionada = casillas_destino_disponibles[indice_destino_seleccionado]
	print("🎯 ", jugador_en_bifurcacion.nombre, " preselecciono casilla ", casilla_seleccionada.index)
	
	# Actualizar indicadores visuales
	actualizar_indicadores_visuales()
	
	return casilla_seleccionada

func seleccionar_destino() -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	var casilla_elegida = casillas_destino_disponibles[indice_destino_seleccionado]
	print("✅ ", jugador_en_bifurcacion.nombre, " eligio casilla ", casilla_elegida.index)
	
	# Limpiar estado de bifurcacion
	finalizar_seleccion_bifurcacion()
	
	return casilla_elegida

func actualizar_indicadores_visuales():
	if not en_bifurcacion:
		return
	
	# Apagar todas las luces primero
	for casilla in casillas_destino_disponibles:
		casilla.apagar_luz()
	
	# Encender la luz de la opcion seleccionada
	if indice_destino_seleccionado < casillas_destino_disponibles.size():
		casillas_destino_disponibles[indice_destino_seleccionado].encender_luz()

func finalizar_seleccion_bifurcacion():
	# Apagar todas las luces
	for casilla in casillas_destino_disponibles:
		casilla.apagar_luz()
	
	en_bifurcacion = false
	jugador_en_bifurcacion = null
	casillas_destino_disponibles.clear()
	indice_destino_seleccionado = 0

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# INPUT Y DEVUGS
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_S:
				if jugadores.size() == 0:
					var datos_jugadores = [
						{"nombre": "Mario", "color": Color.RED},
						{"nombre": "Luigi", "color": Color.GREEN}
					]
					instanciar_jugadores(datos_jugadores)
					comenzar_partida()
			KEY_SPACE:
				if en_bifurcacion:
					# Si estamos en bifurcacion, confirmar seleccion
					var destino = seleccionar_destino()
					if destino != null:
						print("🎯 Destino confirmado: casilla ", destino.index)
				else:
					# Si no estamos en bifurcacion, tirar dado
					tirar_dado()
			KEY_D:
				# Navegar hacia la derecha en bifurcaciones
				if en_bifurcacion:
					preseleccionar_destino(1)
			KEY_A:
				# Navegar hacia la izquierda en bifurcaciones
				if en_bifurcacion:
					preseleccionar_destino(-1)
