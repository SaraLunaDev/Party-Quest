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

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# CONFIGURACION INICIAL
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func _ready() -> void:
	if tablero == null:
		print("❌ Error: El nodo 'tablero' no esta asignado.")

	print("Game Manager Listo")

func instanciar_jugadores(datos_jugadores: Array):
	if jugador_escena == null:
		print("❌ Error: La escena del jugador no esta asignada.")
		return

	jugadores.clear()

	for datos in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		jugador.configurar(datos.nombre, datos.color)
		jugadores.append(jugador)

	for jugador in jugadores:
		tablero.add_child(jugador)
		jugador.position = Vector3.ZERO
		jugador.rotation_degrees = Vector3.ZERO
		jugador.pf = null
		jugador.posicion_tablero = 0

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# GESTION DE PARTIDA
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func comenzar_partida():
	if jugadores.size() < 2:
		print("❌ Error: No hay suficientes jugadores para comenzar la partida.")

	# TODO: Instanciar Corona
	# TODO: Determinar Orden de Jugadores
	partida_activa = true
	emit_signal("partida_iniciada")
	
	print("🎉 Partida iniciada con ", jugadores.size(), " jugadores.")
	iniciar_turno()

func finalizar_partida():
	partida_activa = false
	# TODO: Elegir Ganador
	emit_signal("partida_finalizada")

	print("\n🏁 Partida finalizada.")
	
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# GESTIONN DE TURNOS
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func iniciar_turno():
	if !partida_activa:
		return

	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	if jugador_actual_index == 0:
		rondas_completadas += 1
		if rondas_completadas != 0:
			print("\n🔄 Ronda ", rondas_completadas, " completada.")
		if rondas_completadas >= limite_rondas:
			finalizar_partida()
			return
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = true
	emit_signal("turno_iniciado", jugador_actual)
	
	print("\n🎮 Turno de ", jugador_actual.nombre)

func tirar_dado():
	if !esperando_dado or !partida_activa:
		return

	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
	var resultado_dado = randi() % tirada_maxima + 1
	mover_jugador(jugador_actual, resultado_dado)
	
	print("🎲 ", jugador_actual.nombre, " ha tirado: ", resultado_dado)
	iniciar_turno()
	
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Movimiento de Jugador
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func mover_jugador(jugador: Node3D, pasos: int):
	pass

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
				if esperando_dado:
					tirar_dado()
