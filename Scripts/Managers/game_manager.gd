extends Node
class_name MainGameManager


# Señales
# ---------------------------------------------------------------------------------------
signal partida_iniciada()
signal partida_finalizada()
signal turno_iniciado(jugador_actual)


# Variables
# ---------------------------------------------------------------------------------------
@export var tablero: Node3D
@export var jugador_escena: PackedScene
@export var limite_rondas: int = 5
@export var camera: Camera3D
@export var flecha_escena: PackedScene
@export var spawn_point: Node3D
@export var spawn_space: float = 2.0
@export var camera_manager: CameraManager
@export var ingame_ui: IngameUI

var flechas_instanciadas: Array = []

var jugadores: Array = []
var jugador_actual_index: int = 0
var rondas_completadas: int = 0
var partida_activa: bool = false
var esperando_dado: bool = false
var tirada_maxima: int = 6
var en_bifurcacion: bool = false

var casillas_destino_disponibles: Array[Casilla] = []
var indice_destino_seleccionado: int = 0
var jugador_en_bifurcacion: Node3D = null

var ultimo_destino_confirmado: Casilla = null

var en_compra_bateria: bool = false
var jugador_en_compra: Node3D = null
var costo_bateria: int = 20

var player_slots: Array = []
var input_manager: Node = null
var lobby_open: bool = true
var waiting_for_spawns: bool = false
var first_spawner_device = null
var waiting_first_confirmation: bool = false


# Funciones Basicas
# ---------------------------------------------------------------------------------------
func _ready() -> void:
	if tablero == null:
		print("❌ Error: El nodo 'tablero' no esta asignado.")

	
	input_manager = preload("res://Scripts/Managers/input_manager.gd").new()
	add_child(input_manager)
	input_manager.connect("device_button_pressed", Callable(self , "_on_device_button_pressed"))
	input_manager.connect("device_action", Callable(self , "_on_device_action"))

	# Conectar con la UI del juego
	if ingame_ui:
		ingame_ui.set_game_manager(self )
		ingame_ui.connect("dice_button_pressed", Callable(self , "_on_ui_dice_button_pressed"))
		ingame_ui.connect("map_button_pressed", Callable(self , "_on_ui_map_button_pressed"))

	print("💚 Game Manager Listo\n")


# Gestion de Jugadores
# ---------------------------------------------------------------------------------------
#region

func get_jugadores() -> Array:
	return jugadores

# Instancia los jugadores segun los datos recibidos, los posiciona en el punto de spawn y los prepara para el inicio de la partida
func instanciar_jugadores(datos_jugadores: Array):
	if jugador_escena == null:
		print("❌ Error: La escena del jugador no esta asignada.")
		return

	jugadores.clear()

	await camera_manager.set_state(CameraManager.STATE_LOOK_AT, spawn_point.global_transform.origin, spawn_point.global_transform.basis.get_euler())
	await get_tree().create_timer(.2).timeout

	for datos in datos_jugadores:
		var jugador = jugador_escena.instantiate()
		jugador.configurar(datos.nombre, datos.color)
		jugadores.append(jugador)

	for i in range(jugadores.size()):
		var jugador = jugadores[i]
		tablero.add_child(jugador)
		
		if ingame_ui:
			ingame_ui.add_player_to_ui(jugador)
		
		if spawn_point == null:
			jugador.global_position = Vector3.ZERO
			jugador.rotation_degrees = Vector3.ZERO
			if camera != null:
				var cam_pos = camera.global_transform.origin
				cam_pos.y = jugador.global_transform.origin.y
				var to_cam = cam_pos - jugador.global_transform.origin
				if to_cam.length() >= 0.01:
					var yaw_rad = atan2(to_cam.x, to_cam.z)
					jugador.rotation_degrees.y = rad_to_deg(yaw_rad)
		else:
			var right = spawn_point.global_transform.basis.x.normalized()
			var center = (jugadores.size() - 1) * 0.5
			var offset = (i - center) * spawn_space
			jugador.global_position = spawn_point.global_position + right * offset
			jugador.rotation_degrees = spawn_point.rotation_degrees
			if camera != null:
				var cam_pos = camera.global_transform.origin
				cam_pos.y = jugador.global_transform.origin.y
				var to_cam = cam_pos - jugador.global_transform.origin
				if to_cam.length() >= 0.01:
					var yaw_rad = atan2(to_cam.x, to_cam.z)
					jugador.rotation_degrees.y = rad_to_deg(yaw_rad)
		jugador.pf = null
		jugador.posicion_casilla = 0
		await get_tree().create_timer(.2).timeout
	
	await get_tree().create_timer(2).timeout
#endregion


# Gestion de Partida
# ---------------------------------------------------------------------------------------
#region

# Inicia la partida, verificando que haya suficientes jugadores, asignando dispositivos y determinando el orden de turno
func comenzar_partida():
	if player_slots.size() < 2 and jugadores.size() < 2:
		print("❌ Error: Necesitas al menos 2 jugadores")
		return

	if jugadores.size() == 0 and player_slots.size() >= 2:
		print("\n🔁 Instanciando jugadores...")
		var datos_jugadores: Array = []
		for s in player_slots:
			datos_jugadores.append({"nombre": s.name, "color": s.color})
		await instanciar_jugadores(datos_jugadores)
		for i in range(min(player_slots.size(), jugadores.size())):
			player_slots[i].spawned = true
			player_slots[i].instance = jugadores[i]
			jugadores[i].device_id = player_slots[i].device_id

	if jugadores.size() >= 2:
		for j in jugadores:
			if not j.device_id:
				print("❌ Error: No todos los jugadores tienen un dispositivo asignado.")
				return

	print("\n🎉 Partida iniciada con ", jugadores.size(), " jugadores.")
	await determinar_orden()
	partida_activa = true
	emit_signal("partida_iniciada")
	await convertir_casilla_lejana_a_bateria()
	iniciar_turno()

# Finaliza la partida, desactivando el estado de partida activa y emitiendo la señal de partida finalizada
func finalizar_partida():
	partida_activa = false
	
	emit_signal("partida_finalizada")

	print("🏁 Partida finalizada.")

# Determina el orden de los jugadores al inicio de la partida haciendo que cada uno tire un dado y ordenandolos segun el resultado
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
#endregion


# Gestion de Turnos
# ---------------------------------------------------------------------------------------
#region

# Inicia el turno del jugador actual, ajustando su posicion si es necesario, haciendo que salude a la camara y mostrando el dado para que lo tire
func iniciar_turno():
	await get_tree().create_timer(1.4).timeout

	if !partida_activa:
		return

	if jugador_actual_index == 0:
		rondas_completadas += 1
		if rondas_completadas > limite_rondas:
			finalizar_partida()
			return
		else:
			print("\n🔄 Comenzando ronda ", rondas_completadas)
			print("----------------------")
			await get_tree().create_timer(1.0).timeout

	var jugador_actual = jugadores[jugador_actual_index]

	if camera_manager != null:
		camera_manager.set_target_player(jugador_actual)
		await camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)

	var casilla_inicio = buscar_casilla(jugador_actual.posicion_casilla)
	if casilla_inicio != null and not (casilla_inicio.index == 0 and jugador_actual_index == 0 and rondas_completadas == 1):
		desplazar_fuera_casilla(casilla_inicio, jugador_actual, true)
		
		if not (rondas_completadas == 1 and jugador_actual.posicion_casilla == 0):
			await ajustar_jugador_a_casilla(jugador_actual, casilla_inicio)
			jugador_actual.set_running_state(false)

	await rotate_player_towards_camera(jugador_actual)
	await get_tree().create_timer(.6).timeout
	jugador_actual.set_waving_state(true)
	await get_tree().create_timer(2.4).timeout

	
	esperando_dado = true
	var dado = jugador_actual.get_node_or_null("Dado")
	if dado != null:
		dado.dice_visibility(true)

	emit_signal("turno_iniciado", jugador_actual)
	
	print("\n🎮 Turno de ", jugador_actual.nombre, " (", jugador_actual.device_id, ")")

# Obtiene un numero aleatorio para la tirada del dado, hace que el jugador salte, muestra el resultado de la tirada y luego mueve al jugador segun el resultado
func tirar_dado():
	if !esperando_dado or !partida_activa:
		return
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
	
	# Desactivar botones de UI
	if ingame_ui:
		ingame_ui.deactivate_buttons()
	
	var resultado_dado = randi() % tirada_maxima + 1
	jugador_actual.set_jumping_state(true)

	var dado = jugador_actual.get_node_or_null("Dado")
	if dado != null:
		dado.stop_dice(resultado_dado)
		jugador_actual.get_node_or_null("Number").text = str(resultado_dado)
		await jugador_actual.set_number_visibility_state(true)

	print("   ", "🎲 ", jugador_actual.nombre, " ha tirado: ", resultado_dado)

	await get_tree().create_timer(2).timeout
	
	await mover_jugador(jugador_actual, resultado_dado)
	
	jugador_actual_index = (jugador_actual_index + 1) % jugadores.size()
	iniciar_turno()
#endregion


# Gestion del Movimiento por el Tablero
# ---------------------------------------------------------------------------------------
#region

# Reajusta la posicion del jugador para que quede perfectamente centrado en la casilla, con una animacion de movimiento suave
func ajustar_jugador_a_casilla(jugador: Node3D, casilla: Casilla) -> void:
	if jugador == null or casilla == null:
		return
	var distancia = jugador.global_position.distance_to(casilla.global_position)
	if distancia <= 0.01:
		return
	
	jugador.set_running_state(true)
	print("      ", "🔁 Ajustando posicion de ", jugador.nombre, " a la casilla ", casilla.index)
	var dir = casilla.global_position - jugador.global_position
	dir.y = 0
	var distancia_start = dir.length()
	var velocidad = jugador.get_speed()
	var dur: float = 1.0
	if velocidad > 0:
		dur = distancia_start / velocidad
	
	if dur < 0.05:
		dur = 0.05
	
	var tween_start = jugador.create_tween()
	tween_start.tween_property(jugador, "position", casilla.global_position, dur)
	await tween_start.finished

# Mueve al jugador por las casillas hasta el destino, controlando animaciones, efectos de casillas, bifurcaciones y compras de bateria en el camino
func mover_jugador(jugador: Node3D, espacios: int) -> void:
	print("   ", "🚶‍♂️ ", jugador.nombre, " se mueve ", espacios, " espacios.")
	jugador.set_running_state(true)


	var casilla_inicio = buscar_casilla(jugador.posicion_casilla)
	if casilla_inicio != null:
		await ajustar_jugador_a_casilla(jugador, casilla_inicio)
	
	for i in range(espacios):
		var posicion = jugador.posicion_casilla
		
		var casilla_actual = buscar_casilla(posicion)
		if casilla_actual == null:
			print("   ", "❌ No se encontro la casilla ", posicion)
			return
		
		var destinos = casilla_actual.get_casillas_destino()
		if destinos.size() == 0:
			print("   ", "❗ Casilla ", posicion, " sin destinos. Reconfigurando tablero...")
			var todas_casillas_nodes = get_tree().get_nodes_in_group("casilla")
			var casillas_typed: Array[Casilla] = []
			for n in todas_casillas_nodes:
				if n is Casilla:
					casillas_typed.append(n)
			if tablero and tablero.has_method("_configurar_conexiones_casillas"):
				tablero._configurar_conexiones_casillas(casillas_typed)
				
				destinos = casilla_actual.get_casillas_destino()
				print("   ", "🔁 Reconfiguracion: destinos=", destinos.size())
			
			if destinos.size() == 0:
				print("   ", "❌ Casilla ", posicion, " sigue sin destinos.")
				return
		
		var destino: Casilla
		
		if destinos.size() > 1:
			jugador.set_running_state(false)
			destino = await manejar_bifurcacion(jugador, destinos)
			jugador.set_running_state(true)
		else:
			destino = destinos[0]
		
		print("      ", "➡️ ", jugador.nombre, " se mueve a la casilla ", destino.index)
		
		desplazar_fuera_casilla(destino, jugador)

		jugador.get_node_or_null("Number").text = str(espacios - (i + 1))
		
		jugador.posicion_casilla = destino.index
		
		if ingame_ui:
			ingame_ui.update_player_info(jugador)
		
		var dir = destino.global_position - jugador.global_position
		dir.y = 0
		var distancia = dir.length()
		var velocidad = jugador.get_speed()
		var duration: float = 0.8
		if velocidad > 0:
			duration = distancia / velocidad
		
		if duration < 0.05:
			duration = 0.05
		
		# Verificar si el movimiento requiere salto
		if destino.get_movimiento() == Casilla.tipo_movimiento.SALTAR:
			await realizar_movimiento_salto(jugador, destino, jugador.get_jump_duration())
		else:
			await realizar_movimiento_normal(jugador, destino, duration)
		
		if destino.get_tipo() == Casilla.tipo_casilla.BATERIA:
			await jugador.set_number_visibility_state(false)
			jugador.set_running_state(false)
			await manejar_compra_bateria(jugador)
			await jugador.set_number_visibility_state(true)
			if camera_manager != null:
				camera_manager.set_target_player(jugador)
				await camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)
			jugador.set_running_state(true)
			continue

	await jugador.set_number_visibility_state(false)
	print("\n   ", "✅ ", jugador.nombre, " ha llegado a la casilla ", jugador.posicion_casilla, " (", buscar_casilla(jugador.posicion_casilla).get_nombre(), ")")
	jugador.set_running_state(false)

	var casilla_final = buscar_casilla(jugador.posicion_casilla)
	if casilla_final != null:
		await ejecutar_efecto_casilla(jugador, casilla_final)
	
	print("\n   ", "🔁 Fin de movimiento de ", jugador.nombre)

# Aplica el efecto de la casilla en la que ha caido el jugador, como dar o quitar microchips o jugar un minijuego
func ejecutar_efecto_casilla(jugador: Node3D, casilla: Casilla) -> void:
	match casilla.get_tipo():
		0:
			jugador.establecer_microchips(4)
			await camera_manager.set_state(CameraManager.STATE_LOOK_AT, jugador.global_transform.origin, Vector3.ZERO)
			await rotate_player_towards_camera(jugador)
			await get_tree().create_timer(1.6).timeout
			print("   ", "💾 Dando 4 microchips a ", jugador.nombre, ". Microchips actuales: ", jugador.get_microchips())
		1:
			jugador.establecer_microchips(-4)
			await camera_manager.set_state(CameraManager.STATE_LOOK_AT, jugador.global_transform.origin, Vector3.ZERO)
			await rotate_player_towards_camera(jugador)
			await get_tree().create_timer(1.6).timeout
			print("   ", "😢 Quitando 2 microchips a ", jugador.nombre, ". Microchips actuales: ", jugador.get_microchips())
		2:
			# TODO: Gestion de Minijuegos
			print("   ", "🎳 Simulando minijuego.")
			
			var jugadores_en_tablero: Array = []
			for p in jugadores:
				if not p.is_moved_out:
					jugadores_en_tablero.append(p)
			
			var resultado_minijuego: Array = []
			for p in jugadores_en_tablero:
				var resultado = randi() % tirada_maxima + 1
				resultado_minijuego.append({"jugador": p, "resultado": resultado})
				print("         ", "🎲 ", p.nombre, " ha tirado: ", resultado)
			
			resultado_minijuego.sort_custom(func(a, b): return a.resultado > b.resultado)
			await get_tree().create_timer(2).timeout
			print("         ", "🏆 Resultado del minijuego:")
			
			for i in resultado_minijuego.size():
				var premio = 0
				if i == 0:
					premio = 4
				elif i == 1:
					premio = 2
				elif i == 2:
					premio = 1
				
				resultado_minijuego[i].jugador.establecer_microchips(premio)
				
				if premio > 0 and camera_manager != null:
					await camera_manager.set_state(CameraManager.STATE_LOOK_AT, resultado_minijuego[i].jugador.global_transform.origin, Vector3.ZERO, true)
					await rotate_player_towards_camera(resultado_minijuego[i].jugador)
					await get_tree().create_timer(2).timeout
					print("            ", i + 1, ".- ", resultado_minijuego[i].jugador.nombre, " con ", resultado_minijuego[i].resultado, " -> premio: ", premio, " microchips. Total: ", resultado_minijuego[i].jugador.get_microchips(), " microchips.")

# Realiza movimiento normal caminando hacia la casilla destino
func realizar_movimiento_normal(jugador: Node3D, destino: Casilla, duration: float) -> void:
	jugador.set_running_state(true)
	var tween = jugador.create_tween()
	tween.tween_property(jugador, "position", destino.global_position, duration)
	await tween.finished

# Realiza movimiento con salto hacia la casilla destino
func realizar_movimiento_salto(jugador: Node3D, destino: Casilla, duration: float) -> void:
	jugador.set_running_state(false)
	await rotate_player_towards_point(jugador, destino.global_transform.origin)
	await get_tree().create_timer(.4).timeout
	
	# Guardar el offset inicial para calcular la trayectoria correcta
	var offset_mesh_inicial = 0.0
	if jugador.player_mesh:
		offset_mesh_inicial = jugador.get_player_mesh_offset()
	
	var posicion_inicial = jugador.global_position
	# Compensar la posicion inicial por el offset que tenia el mesh
	posicion_inicial.y += offset_mesh_inicial
	var posicion_destino = destino.global_position
	
	# Altura del salto
	var altura_salto = 1.0
	var tiempo_actual = 0.0
	var tiempo_total = duration
	
	jugador.set_on_air(true)
	jugador.set_jumping_state(true)
	await get_tree().create_timer(.3).timeout
	
	while tiempo_actual < tiempo_total:
		var progress = tiempo_actual / tiempo_total
		
		# Interpolacion horizontal directa
		var pos_horizontal = posicion_inicial.lerp(posicion_destino, progress)
		
		# Interpolacion vertical que considera diferencia de altura entre origen y destino
		var altura_base = lerp(posicion_inicial.y, posicion_destino.y, progress)
		var altura_arco = altura_salto * sin(progress * PI)
		var altura_y = altura_base + altura_arco
		
		jugador.global_position = Vector3(pos_horizontal.x, altura_y, pos_horizontal.z)
		
		tiempo_actual += get_process_delta_time()
		await get_tree().process_frame

	# Asegurar posicion final exacta
	jugador.global_position = posicion_destino
	jugador.set_on_air(false)
	await get_tree().create_timer(.4).timeout
#endregion


# Gestion de Bifurcaciones
# ---------------------------------------------------------------------------------------
#region

# Maneja la logica de una bifurcacion, mostrando las opciones disponibles, permitiendo al jugador seleccionar una y devolviendo la casilla destino elegida
func manejar_bifurcacion(jugador: Node3D, destinos: Array[Casilla]) -> Casilla:
	await jugador.set_number_visibility_state(false)
	await camera_manager.set_state(CameraManager.STATE_LOOK_AT_FROM_SKY, jugador.global_transform.origin, Vector3.ZERO)
	
	iniciar_seleccion_bifurcacion(jugador, destinos)
	
	while en_bifurcacion:
		await get_tree().process_frame
	
	var destino_confirmado = ultimo_destino_confirmado
	ultimo_destino_confirmado = null
	if destino_confirmado == null:
		destino_confirmado = destinos[randi() % destinos.size()]

	await camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)
	await jugador.set_number_visibility_state(true)
	await get_tree().create_timer(.2).timeout
	return destino_confirmado

func buscar_casilla(indice: int) -> Casilla:
	var todas_casillas = get_tree().get_nodes_in_group("casilla")
	for casilla in todas_casillas:
		if casilla.index == indice:
			return casilla
	return null

# Desplaza al jugador especificado fuera de la casilla con una animacion de desplazamiento
func desplazar_jugador_fuera_casilla(jugador: Node3D, casilla: Casilla, triangular: bool = false) -> void:
	if jugador == null or casilla == null:
		return
		
	jugador.set_running_state(true)
	print("      ", "👥 ", jugador.nombre, " se desplaza fuera de la casilla ", casilla.index)
	
	var dir_away = casilla.global_transform.basis.x.normalized()
	var offset_away = dir_away * 2
	
	if not triangular:
		var tween_away = jugador.create_tween()
		tween_away.tween_property(jugador, "position", jugador.global_position + offset_away, 0.75)
		jugador.set_moved_out(true)
		await tween_away.finished
		jugador.set_moved_out(false)
	else:
		var start_pos = jugador.global_position
		var final_dest = casilla.global_transform.origin + dir_away * 2
		
		var mid_distance = start_pos.distance_to(final_dest) * 0.8
		var perpendicular = Vector3(-dir_away.z, 0, dir_away.x).normalized()
		var mid_point = start_pos.lerp(final_dest, 0.5) + perpendicular * mid_distance * 1.8
		
		var tween_circle = jugador.create_tween()
		jugador.set_moved_out(true)
		
		var arc_func = func(t: float): jugador.position = _quadratic_bezier(start_pos, mid_point, final_dest, t)
		tween_circle.tween_method(arc_func, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE)
		await tween_circle.finished
		jugador.set_moved_out(false)
	
	await rotate_player_towards_point(jugador, casilla.global_transform.origin)
	jugador.set_running_state(false)

# Desplaza a los jugadores que esten en la casilla de destino para que no queden amontonados, con una animacion de desplazamiento suave
func desplazar_fuera_casilla(casilla: Casilla, jugador_excluido: Node3D, triangular: bool = false) -> void:
	for otro_jugador in jugadores:
		if otro_jugador != jugador_excluido and otro_jugador.posicion_casilla == casilla.index:
			otro_jugador.set_running_state(true)
			print("      ", "👥 ", otro_jugador.nombre, " esta en la casilla ", casilla.index, ", se mueve")
			var dir_away = casilla.global_transform.basis.x.normalized()
			var offset_away = dir_away * 2
			if not triangular:
				var tween_away = otro_jugador.create_tween()
				tween_away.tween_property(otro_jugador, "position", otro_jugador.global_position + offset_away, 0.75)
				otro_jugador.set_moved_out(true)
				await tween_away.finished
				otro_jugador.set_moved_out(false)
			else:
				var start_pos = otro_jugador.global_position
				var final_dest = casilla.global_transform.origin + dir_away * 2
				
				var mid_distance = start_pos.distance_to(final_dest) * 0.8
				var perpendicular = Vector3(-dir_away.z, 0, dir_away.x).normalized()
				var mid_point = start_pos.lerp(final_dest, 0.5) + perpendicular * mid_distance * 1.8
				
				var tween_circle = otro_jugador.create_tween()
				otro_jugador.set_moved_out(true)
				
				var arc_func = func(t: float): otro_jugador.position = _quadratic_bezier(start_pos, mid_point, final_dest, t)
				tween_circle.tween_method(arc_func, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE)
				await tween_circle.finished
				otro_jugador.set_moved_out(false)
			
			await rotate_player_towards_point(otro_jugador, casilla.global_transform.origin)
			otro_jugador.set_running_state(false)

# Calcula un punto en una curva de Bezier cuadratica
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

# Inicia el proceso de seleccion de destino en una bifurcacion, mostrando las opciones disponibles y preparando la logica para que el jugador pueda seleccionar una usando las flechas y confirmando con el boton de aceptar
func iniciar_seleccion_bifurcacion(jugador: Node3D, destinos: Array[Casilla]):
	en_bifurcacion = true
	jugador_en_bifurcacion = jugador
	casillas_destino_disponibles = destinos
	indice_destino_seleccionado = 0
	
	print("         ", "🔀 ", jugador.nombre, " en bifurcacion (", destinos.size(), " opciones). Usa ← → y aceptar para confirmar.")
	
	crear_flechas_seleccion(jugador, destinos)
	actualizar_indicadores_visuales()

# Permite al jugador preseleccionar una opcion de destino en la bifurcacion usando las flechas, actualizando los indicadores visuales para mostrar la opcion actualmente seleccionada
func preseleccionar_destino(incremento: int) -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	indice_destino_seleccionado = (indice_destino_seleccionado + incremento) % casillas_destino_disponibles.size()
	if indice_destino_seleccionado < 0:
		indice_destino_seleccionado = casillas_destino_disponibles.size() - 1
	
	var casilla_seleccionada = casillas_destino_disponibles[indice_destino_seleccionado]
	
	actualizar_indicadores_visuales()
	
	return casilla_seleccionada

# Confirma la seleccion del destino en la bifurcacion, devolviendo la casilla destino elegida y finalizando el proceso de seleccion
func seleccionar_destino() -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	var casilla_elegida = casillas_destino_disponibles[indice_destino_seleccionado]
	print("         ", "✅ ", jugador_en_bifurcacion.nombre, " eligio casilla ", casilla_elegida.index)
	
	ultimo_destino_confirmado = casilla_elegida
	finalizar_seleccion_bifurcacion()
	
	return casilla_elegida

# Actualiza los indicadores visuales de las opciones de destino en la bifurcacion para resaltar la opcion actualmente preseleccionada, atenuando las demas opciones
func actualizar_indicadores_visuales():
	if not en_bifurcacion:
		return
	
	update_flechas_alpha()

# Finaliza el proceso de seleccion de destino en la bifurcacion, limpiando las flechas y reseteando las variables relacionadas para volver al estado normal de juego
func finalizar_seleccion_bifurcacion():
	for f in flechas_instanciadas:
		if f and f.is_inside_tree():
			f.queue_free()
	flechas_instanciadas.clear()
	
	en_bifurcacion = false
	jugador_en_bifurcacion = null
	casillas_destino_disponibles.clear()
	indice_destino_seleccionado = 0

# Crea las flechas de seleccion para las opciones de destino en la bifurcacion, posicionandolas frente al jugador y orientandolas hacia las casillas destino correspondientes, ademas de aplicar un efecto visual para resaltar la opcion actualmente preseleccionada
func crear_flechas_seleccion(jugador: Node3D, destinos: Array[Casilla]) -> void:
	for f in flechas_instanciadas:
		if f and f.is_inside_tree():
			f.queue_free()
	flechas_instanciadas.clear()
	
	for destino in destinos:
		var f = flecha_escena.instantiate()
		tablero.add_child(f)
		
		var dir = destino.global_position - jugador.global_position
		dir.y = 0
		var distancia = 2
		var altura = 1
		f.global_transform.origin = jugador.global_transform.origin + dir.normalized() * distancia + Vector3(0, altura, 0)
		var dir_h = destino.global_position - jugador.global_position
		dir_h.y = 0
		var yaw = atan2(dir_h.x, dir_h.z)
		yaw += PI
		var x_offset_deg: float = -90.0
		f.rotation = Vector3(deg_to_rad(x_offset_deg), yaw, 0)
		
		set_flecha_selected(f, 0.25)
		flechas_instanciadas.append(f)
	
	if flechas_instanciadas.size() > 0 and indice_destino_seleccionado < flechas_instanciadas.size():
		set_flecha_selected(flechas_instanciadas[indice_destino_seleccionado], 1.0)

# Aplica un material con transparencia a la flecha para resaltar la opcion actualmente seleccionada en la bifurcacion, y reproduce una animacion de seleccion si corresponde
func set_flecha_selected(f: MeshInstance3D, alpha: float) -> void:
	if f == null:
		return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 145.0 / 255.0, 0.0, alpha)
	f.material_override = mat
	var ap = f.get_node_or_null("AnimationPlayer")
	if ap != null:
		if alpha >= 1.0:
			ap.play("selected")
		else:
			ap.play("RESET")

# Actualiza el alpha de las flechas de seleccion en la bifurcacion para resaltar la opcion actualmente seleccionada y atenuar las demas opciones
func update_flechas_alpha() -> void:
	for i in range(flechas_instanciadas.size()):
		var f = flechas_instanciadas[i]
		if i == indice_destino_seleccionado:
			set_flecha_selected(f, 1.0)
		else:
			set_flecha_selected(f, 0.25)
#endregion


# Gestion de Bateria
# ---------------------------------------------------------------------------------------
#region

# Convierte la casilla mas lejana a los jugadores en una casilla de bateria
func convertir_casilla_lejana_a_bateria():
	if tablero == null or not tablero.has_method("obtener_casillas_del_tablero"):
		print("❌ Error: No se puede acceder a las casillas del tablero.")
		return
	
	var todas_casillas = tablero.obtener_casillas_del_tablero()
	var casillas_normales = todas_casillas.filter(func(c): return c.get_tipo() == Casilla.tipo_casilla.NORMAL)
	if casillas_normales.size() == 0:
		print("❗ No hay casillas NORMAL disponibles.")
		return
	
	var casilla_mas_lejana = null
	var distancia_maxima = -1.0
	
	for casilla in casillas_normales:
		var distancia_minima_a_jugadores = INF
		for jugador in jugadores:
			var distancia = casilla.global_position.distance_to(jugador.global_position)
			if distancia < distancia_minima_a_jugadores:
				distancia_minima_a_jugadores = distancia
		
		if distancia_minima_a_jugadores > distancia_maxima:
			distancia_maxima = distancia_minima_a_jugadores
			casilla_mas_lejana = casilla
	
	if casilla_mas_lejana != null:
		if camera_manager != null:
			await camera_manager.set_state(CameraManager.STATE_LOOK_AT, casilla_mas_lejana.global_transform.origin, Vector3.ZERO)
			await get_tree().create_timer(.6).timeout

		casilla_mas_lejana.set_tipo(Casilla.tipo_casilla.BATERIA)
		print("🔋 Casilla ", casilla_mas_lejana.index, " convertida a BATERIA.")
		
		await get_tree().create_timer(.6).timeout
	else:
		print("❌ No se encontro casilla para convertir a BATERIA.")

# Maneja la logica de compra de bateria al caer en una casilla de bateria, mostrando la opcion de compra si el jugador tiene suficientes microchips y actualizando el estado del jugador segun su decision
func manejar_compra_bateria(jugador: Node3D) -> void:
	en_compra_bateria = true
	jugador_en_compra = jugador
	
	await camera_manager.set_state(CameraManager.STATE_LOOK_AT, jugador.global_transform.origin, Vector3.ZERO)
	await rotate_player_towards_camera(jugador)
	
	print("\n   🔋 ", jugador.nombre, " ha llegado a una casilla BATERIA.")
	
	if jugador.get_microchips() >= costo_bateria:
		print("   💰 Tienes ", jugador.get_microchips(), " microchips (necesitas ", costo_bateria, ")")
		print("   🎯 Aceptar para comprar | Salir para rechazar")
		
		while en_compra_bateria:
			await get_tree().process_frame
	else:
		print("   ❌ No tienes suficientes microchips (tienes ", jugador.get_microchips(), ", necesitas ", costo_bateria, ")")
		await get_tree().create_timer(2).timeout
		en_compra_bateria = false
		jugador_en_compra = null

# Confirma la compra de bateria, descontando los microchips correspondientes si el jugador decide comprar y actualizando su cantidad de baterias, o simplemente rechazando la compra si el jugador decide no comprar
func confirmar_compra_bateria(comprar: bool) -> void:
	if not en_compra_bateria or jugador_en_compra == null:
		return
	
	var jugador = jugador_en_compra
	jugador_en_compra = null
	
	if comprar:
		if jugador.get_microchips() >= costo_bateria:
			jugador.establecer_microchips(-costo_bateria, false)
			jugador.establecer_baterias(1)
			print("      ✅ ", jugador.nombre, " compro una BATERIA por ", costo_bateria, " microchips.")
			print("      💾 Microchips restantes: ", jugador.get_microchips())
			print("      🔋 Baterias totales: ", jugador.get_baterias())
			
			var casilla_actual = buscar_casilla(jugador.posicion_casilla)
			if casilla_actual != null:
				await get_tree().create_timer(4).timeout
				await camera_manager.set_state(CameraManager.STATE_LOOK_AT, casilla_actual.global_transform.origin, Vector3.ZERO, false, 0.6)
				casilla_actual.set_tipo(Casilla.tipo_casilla.NORMAL)
				await get_tree().create_timer(2).timeout
				await convertir_casilla_lejana_a_bateria()
			
			await get_tree().create_timer(2).timeout
		else:
			print("      ❌ No tienes suficientes microchips para comprar.")
			await get_tree().create_timer(1).timeout
	else:
		print("      ❌ ", jugador.nombre, " rechazó comprar una BATERIA.")
		print("      💾 Microchips: ", jugador.get_microchips())
		await get_tree().create_timer(1).timeout
	
	en_compra_bateria = false
#endregion


# Gestion de Camara
# ---------------------------------------------------------------------------------------
#region

# Hace que el jugador rote suavemente para mirar hacia la camara, ajustando su rotacion segun la posicion de la camara y aplicando una animacion de caminata durante el giro
func rotate_player_towards_camera(jugador_actual: Node3D) -> void:
	if camera == null or jugador_actual == null:
		return
	
	var player_pos = jugador_actual.global_transform.origin
	var cam_pos = camera.global_transform.origin
	cam_pos.y = player_pos.y
	var to_cam = cam_pos - player_pos
	
	if to_cam.length() < 0.01:
		return
	
	var yaw_rad = atan2(to_cam.x, to_cam.z)
	var yaw_deg = rad_to_deg(yaw_rad)
	var current_deg = jugador_actual.rotation_degrees
	
	var desired_y = yaw_deg
	while desired_y - current_deg.y > 180.0:
		desired_y -= 360.0
	while desired_y - current_deg.y < -180.0:
		desired_y += 360.0
	
	if abs(desired_y - current_deg.y) < 5.0:
		return
	
	jugador_actual.set_looking_at_camera(true)
	jugador_actual.set_walking_state(true)
	await get_tree().create_timer(.6).timeout
	jugador_actual.set_looking_at_camera(false)
	jugador_actual.set_walking_state(false)

# Hace que el jugador rote suavemente para mirar hacia un punto especifico, ajustando su rotacion segun la posicion del punto y aplicando una animacion de caminata durante el giro
func rotate_player_towards_point(jugador_actual: Node3D, target_point: Vector3) -> void:
	if jugador_actual == null:
		return
	var player_pos = jugador_actual.global_transform.origin
	var tgt = target_point
	tgt.y = player_pos.y
	var to_tgt = tgt - player_pos
	
	if to_tgt.length() < 0.01:
		return
	jugador_actual.set_running_state(false)
	await get_tree().create_timer(.2).timeout
	jugador_actual.set_walking_state(true)
	
	var yaw_rad = atan2(to_tgt.x, to_tgt.z)
	var yaw_deg = rad_to_deg(yaw_rad)
	var current_deg = jugador_actual.rotation_degrees
	
	var desired_y = yaw_deg
	while desired_y - current_deg.y > 180.0:
		desired_y -= 360.0
	while desired_y - current_deg.y < -180.0:
		desired_y += 360.0
	var target_deg = Vector3(current_deg.x, desired_y, current_deg.z)
	var tween = jugador_actual.create_tween()
	tween.tween_property(jugador_actual, "rotation_degrees", target_deg, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	jugador_actual.set_walking_state(false)
#endregion


# Gestion de Inputs por Dispositivo
# ---------------------------------------------------------------------------------------
#region

# Gestiona la logica de los inputs recibidos por dispositivo, asignando nuevos jugadores en el lobby, permitiendo a los jugadores spawnear al inicio de la partida, manejando la confirmacion del primer jugador spawneado para iniciar la partida, y gestionando las acciones durante la partida como tirar el dado o seleccionar opciones en bifurcaciones o compras de bateria
func _on_device_button_pressed(device_id, _button_name: String) -> void:
	if lobby_open:
		if not _device_already_assigned(device_id):
			_add_player_slot(device_id)
			return

	if waiting_for_spawns:
		var slot = _get_slot_by_device(device_id)
		if slot != null and not slot.spawned:
			spawn_player_for_device(device_id)
			
			if first_spawner_device == -1:
				first_spawner_device = device_id
				waiting_first_confirmation = true
			return

	if waiting_first_confirmation and device_id == first_spawner_device:
		pass

# Durante la partida, se gestionan las acciones de los jugadores segun el boton presionado, permitiendo tirar el dado, preseleccionar opciones en bifurcaciones o confirmar compras de bateria segun el contexto actual del juego
func _on_device_action(device_id, action_name: String) -> void:
	if lobby_open:
		var already_assigned = _device_already_assigned(device_id)
		if not already_assigned:
			_add_player_slot(device_id)
			
			
			if action_name == "start":
				return
		
		if action_name == "start":
			if player_slots.size() < 2:
				print("❗ Necesitas al menos 2 jugadores para comenzar la partida. Actualmente: ", player_slots.size())
				return
			
			if player_slots.size() > 0 and device_id != player_slots[0].device_id:
				print("❗ Solo ", player_slots[0].name, " puede iniciar la partida.")
				return
			
			lobby_open = false
			await comenzar_partida()
			return

	if waiting_first_confirmation and device_id == first_spawner_device and action_name == "ui_accept":
		waiting_first_confirmation = false
		waiting_for_spawns = false
		print("✅ Primer jugador confirmado. Iniciando partida.")
		
		await _finalize_start()
		return

	if partida_activa:
		var jugador_actual = jugadores[jugador_actual_index]
		if jugador_actual != null and jugador_actual.device_id == device_id:
			match action_name:
				"ui_accept":
					if en_compra_bateria:
						await confirmar_compra_bateria(true)
						return
					
					if en_bifurcacion and jugador_en_bifurcacion == jugador_actual:
						var destino = seleccionar_destino()
						if destino != null:
							return
					
					# Solo tirar dado si el boton de dado esta seleccionado
					if ingame_ui and esperando_dado:
						var is_dice_selected = ingame_ui.trigger_selected_button()
						# trigger_selected_button retorna true si se activo el boton de dado
						if not is_dice_selected:
							print("❗ Debes seleccionar el boton de dado para tirar!")
				"ui_left":
					if en_bifurcacion:
						preseleccionar_destino(-1)
					elif ingame_ui:
						ingame_ui.navigate_selection(-1)
				"ui_right":
					if en_bifurcacion:
						preseleccionar_destino(1)
					elif ingame_ui:
						ingame_ui.navigate_selection(1)
				"ui_cancel":
					if en_compra_bateria:
						await confirmar_compra_bateria(false)
				_:
					pass

	if waiting_for_spawns:
		var slot = _get_slot_by_device(device_id)
		if slot != null and not slot.spawned and action_name == "ui_accept":
			spawn_player_for_device(device_id)
			if first_spawner_device == -1:
				first_spawner_device = device_id
				waiting_first_confirmation = true

# Verifica si un dispositivo ya esta asignado a un jugador en el lobby, para evitar asignar multiples jugadores al mismo dispositivo
func _device_already_assigned(device_id) -> bool:
	for s in player_slots:
		if s.device_id == device_id:
			return true
	return false

# Obtiene la informacion del slot de jugador correspondiente a un dispositivo, para gestionar su estado de spawn y asociar el jugador spawneado al dispositivo correcto
func _get_slot_by_device(device_id):
	for s in player_slots:
		if s.device_id == device_id:
			return s
	return null

# Agrega un nuevo slot de jugador al lobby para un dispositivo que se ha unido, asignandole un nombre y color predeterminados segun el orden de llegada, y mostrando un mensaje de bienvenida en la consola
func _add_player_slot(device_id) -> void:
	var default_colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	var idx = player_slots.size()
	var color = default_colors[idx % default_colors.size()]
	var slot_name = "Player " + str(idx + 1)
	var slot = {"name": slot_name, "color": color, "device_id": device_id, "spawned": false, "instance": null}
	player_slots.append(slot)
	print("🔔 Dispositivo ", device_id, " se ha unido como ", slot_name)

# Spawnea al jugador correspondiente a un dispositivo en el tablero, asignandole el nombre y color del slot, posicionandolo en el punto de spawn y actualizando el estado del slot para indicar que el jugador ha sido spawneado
func spawn_player_for_device(device_id) -> void:
	var slot = _get_slot_by_device(device_id)
	if slot == null:
		print("❌ Intentando spawnear dispositivo no registrado: ", device_id)
		return
	if slot.spawned:
		print("❗ Dispositivo ya tiene jugador spawneado: ", device_id)
		return
	
	if jugador_escena == null:
		print("❌ Error: La escena del jugador no esta asignada.")
		return
	var jugador = jugador_escena.instantiate()
	jugador.configurar(slot.name, slot.color)
	jugador.device_id = device_id
	jugadores.append(jugador)
	tablero.add_child(jugador)
	
	jugador.pf = null
	jugador.posicion_casilla = 0
	
	if ingame_ui:
		ingame_ui.add_player_to_ui(jugador)
	
	await get_tree().create_timer(.05).timeout
	
	var i = jugadores.size() - 1
	if spawn_point == null:
		jugador.global_position = Vector3.ZERO
		jugador.rotation_degrees = Vector3.ZERO
	else:
		var right = spawn_point.global_transform.basis.x.normalized()
		var center = (jugadores.size() - 1) * 0.5
		var offset = (i - center) * spawn_space
		jugador.global_position = spawn_point.global_position + right * offset
		jugador.rotation_degrees = spawn_point.rotation_degrees

	slot.spawned = true
	slot.instance = jugador
	print("🎮 Jugador '", slot.name, "' (device ", device_id, ") spawneado.")

# Finaliza la configuracion inicial y comienza la partida
func _finalize_start() -> void:
	if jugadores.size() < 1:
		print("❌ No hay jugadores spawneados para iniciar la partida.")
		return
	print("\n🎉 Partida iniciada con ", jugadores.size(), " jugadores (spawn-confirmed).")
	await determinar_orden()
	partida_activa = true
	emit_signal("partida_iniciada")
	await convertir_casilla_lejana_a_bateria()
	iniciar_turno()

# Funciones de callback para los botones de UI
func _on_ui_dice_button_pressed():
	if esperando_dado and partida_activa:
		tirar_dado()

func _on_ui_map_button_pressed():
	# Implementar funcionalidad del boton mapa aqui
	print("📍 Boton mapa presionado")
#endregion
