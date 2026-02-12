extends Node
class_name MainGameManager


# ############################################################
# Variables
# ############################################################

# Señales
signal partida_iniciada()
signal partida_finalizada()
signal turno_iniciado(jugador_actual)

# Variables Exportadas
@export var tablero: Node3D
@export var jugador_escena: PackedScene
@export var limite_rondas: int = 5
@export var camera: Camera3D
@export var flecha_escena: PackedScene
@export var spawn_point: Node3D
@export var spawn_space: float = 2.0
@export var camera_manager: CameraManager

var flechas_instanciadas: Array = []

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
# Ultimo destino confirmado por el jugador
var ultimo_destino_confirmado: Casilla = null

# Variables para compra de bateria
var en_compra_bateria: bool = false
var jugador_en_compra: Node3D = null
var costo_bateria: int = 20

# --- Input / Players por dispositivo
var player_slots: Array = [] # {name, color, device_id, spawned, instance}
var input_manager: Node = null
var lobby_open: bool = true
var waiting_for_spawns: bool = false
var first_spawner_device = null
var waiting_first_confirmation: bool = false


# ##############################################################
# Configuracion Inicial
# ##############################################################

func _ready() -> void:
	if tablero == null:
		print("❌ Error: El nodo 'tablero' no esta asignado.")

	# Crear InputManager dinámicamente (no requiere autoload)
	input_manager = preload("res://Scripts/Managers/input_manager.gd").new()
	add_child(input_manager)
	input_manager.connect("device_button_pressed", Callable(self , "_on_device_button_pressed"))
	input_manager.connect("device_action", Callable(self , "_on_device_action"))

	print("💚 Game Manager Listo\n")

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


# ############################################################
# Gestion de Partida
# ############################################################

func comenzar_partida():
	# Requerir al menos 2 dispositivos unidos o jugadores con device asignado
	if player_slots.size() < 2 and jugadores.size() < 2:
		print("❌ Error: Necesitas al menos 2 jugadores")
		return

	# Si hay player_slots, instanciamos desde ellos (comportamiento 1:1 antiguo)
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

	# Si jugadores ya estaban instanciados, asegurar que todos tengan device_id asignado
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

func finalizar_partida():
	partida_activa = false
	# TODO: Elegir Ganador
	emit_signal("partida_finalizada")

	print("🏁 Partida finalizada.")


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


# ############################################################
# Gestion de Turnos
# ############################################################

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
		# Esperar a que terminen los desplazamientos antes de comenzar la gestión del turno
		desplazar_fuera_casilla(casilla_inicio, jugador_actual, true)
		# Evitar reajustar en el primer turno del jugador (ronda 1 y casilla inicial 0)
		if not (rondas_completadas == 1 and jugador_actual.posicion_casilla == 0):
			# Asegurar que el jugador actual esté posicionado en la casilla de inicio antes de iniciar el turno
			await ajustar_jugador_a_casilla(jugador_actual, casilla_inicio)
			jugador_actual.set_running_state(false)

	await rotate_player_towards_camera(jugador_actual)
	await get_tree().create_timer(.2).timeout
	jugador_actual.set_waving_state(true)
	await get_tree().create_timer(2.4).timeout

	# Ahora que se ha solucionado la superposición, habilitar la tirada de dado y mostrar el dado
	esperando_dado = true
	var dado = jugador_actual.get_node_or_null("Dado")
	if dado != null:
		dado.dice_visibility(true)

	emit_signal("turno_iniciado", jugador_actual)
	
	print("\n🎮 Turno de ", jugador_actual.nombre, " (", jugador_actual.device_id, ")")

func tirar_dado():
	if !esperando_dado or !partida_activa:
		return
	var jugador_actual = jugadores[jugador_actual_index]
	esperando_dado = false
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


# ############################################################
# Movimiento de Jugador
# ############################################################

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
	# Evitar duraciones demasiado cortas
	if dur < 0.05:
		dur = 0.05
	# Desplazar con tween usando la duración calculada
	var tween_start = jugador.create_tween()
	tween_start.tween_property(jugador, "position", casilla.global_position, dur)
	await tween_start.finished

func mover_jugador(jugador: Node3D, espacios: int) -> void:
	print("   ", "🚶‍♂️ ", jugador.nombre, " se mueve ", espacios, " espacios.")
	jugador.set_running_state(true)

	# Hacer un ajuste inicial a la posicion de inicio si es necesario
	var casilla_inicio = buscar_casilla(jugador.posicion_casilla)
	if casilla_inicio != null:
		await ajustar_jugador_a_casilla(jugador, casilla_inicio)

	# Mover paso a paso usando Tween, de casilla en casilla
	for i in range(espacios):
		var posicion = jugador.posicion_casilla
		# Obtener casilla actual
		var casilla_actual = buscar_casilla(posicion)
		if casilla_actual == null:
			print("   ", "❌ No se encontro la casilla ", posicion)
			return
		
		
		# Ver destinos de la casilla actual
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
				# Re-obtener destinos
				destinos = casilla_actual.get_casillas_destino()
				print("   ", "🔁 Reconfiguracion: destinos=", destinos.size())
			# Si sigue vacio, detener movimiento
			if destinos.size() == 0:
				print("   ", "❌ Casilla ", posicion, " sigue sin destinos.")
				return
		
		var destino: Casilla
		
		# Si hay mas de un destino, manejar bifurcacion
		if destinos.size() > 1:
			jugador.set_running_state(false)
			destino = await manejar_bifurcacion(jugador, destinos)
			jugador.set_running_state(true)
		else:
			# Solo un destino, continuar normalmente
			destino = destinos[0]
		
		print("      ", "➡️ ", jugador.nombre, " se mueve a la casilla ", destino.index)

		# Comprobar si en destino.index hay un jugador y sacarlo por consola
		desplazar_fuera_casilla(destino, jugador)

		
		jugador.get_node_or_null("Number").text = str(espacios - (i + 1))
		
		jugador.posicion_casilla = destino.index
		# Calcular direccion horizontal hacia la siguiente casilla
		var dir = destino.global_position - jugador.global_position
		dir.y = 0
		var distancia = dir.length()
		var velocidad = jugador.get_speed()
		var duration: float = 0.8
		if velocidad > 0:
			duration = distancia / velocidad
		# Evitar duraciones nulas o muy cortas
		if duration < 0.05:
			duration = 0.05
		# Crear un tween y animar posicion con la duración calculada
		var tween = jugador.create_tween()
		# Tween de posicion
		tween.tween_property(jugador, "position", destino.global_position, duration)
		# Esperar a que terminen los tweens antes de continuar al siguiente paso
		await tween.finished
		
		# Verificar si la casilla de destino es BATERIA, si es asi, ejecutar efecto y continuar movimiento
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

	# Obtener tipo de casilla y aplicar efecto en base a ella
	var casilla_final = buscar_casilla(jugador.posicion_casilla)
	if casilla_final != null:
		await ejecutar_efecto_casilla(jugador, casilla_final)
	
	print("\n   ", "🔁 Fin de movimiento de ", jugador.nombre)


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
			print("   ", "🎳 Simulando minijuego.")
			# Obtener todos los jugadores activos del tablero (excluir los movidos fuera)
			var jugadores_en_tablero: Array = []
			for p in jugadores:
				if not p.is_moved_out:
					jugadores_en_tablero.append(p)
			# Simular resultado del minijuego con una tirada de dado para cada participante
			var resultado_minijuego: Array = []
			for p in jugadores_en_tablero:
				var resultado = randi() % tirada_maxima + 1
				resultado_minijuego.append({"jugador": p, "resultado": resultado})
				print("         ", "🎲 ", p.nombre, " ha tirado: ", resultado)
			# Ordenar por resultado descendente
			resultado_minijuego.sort_custom(func(a, b): return a.resultado > b.resultado)
			await get_tree().create_timer(2).timeout
			print("         ", "🏆 Resultado del minijuego:")
			# Repartir premios: 1er=4, 2do=2, 3ro=1
			for i in resultado_minijuego.size():
				var premio = 0
				if i == 0:
					premio = 4
				elif i == 1:
					premio = 2
				elif i == 2:
					premio = 1
				
				resultado_minijuego[i].jugador.establecer_microchips(premio)
				# Apuntar camara al jugador que toca premiar si ha ganado algo
				if premio > 0 and camera_manager != null:
					await camera_manager.set_state(CameraManager.STATE_LOOK_AT, resultado_minijuego[i].jugador.global_transform.origin, Vector3.ZERO, true)
					await rotate_player_towards_camera(resultado_minijuego[i].jugador)
					await get_tree().create_timer(2).timeout
					print("            ", i + 1, ".- ", resultado_minijuego[i].jugador.nombre, " con ", resultado_minijuego[i].resultado, " -> premio: ", premio, " microchips. Total: ", resultado_minijuego[i].jugador.get_microchips(), " microchips.")

func manejar_bifurcacion(jugador: Node3D, destinos: Array[Casilla]) -> Casilla:
	# Cambiar camara a LOOK_AT_FROM_SKY
	await jugador.set_number_visibility_state(false)
	await camera_manager.set_state(CameraManager.STATE_LOOK_AT_FROM_SKY, jugador.global_transform.origin, Vector3.ZERO)
	# Iniciar seleccion manual por el jugador y esperar confirmacion
	iniciar_seleccion_bifurcacion(jugador, destinos)
	# Esperar hasta que el jugador confirme una opcion
	while en_bifurcacion:
		await get_tree().process_frame
	# Recuperar la opcion confirmada
	var destino_confirmado = ultimo_destino_confirmado
	ultimo_destino_confirmado = null
	if destino_confirmado == null:
		# Fallback por si acaso: elegir aleatoriamente
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

# Mover a jugadores fuera de una casilla para evitar superposición
func desplazar_fuera_casilla(casilla: Casilla, jugador_excluido: Node3D, triangular: bool = false) -> void:
	for otro_jugador in jugadores:
		if otro_jugador != jugador_excluido and otro_jugador.posicion_casilla == casilla.index:
			otro_jugador.set_running_state(true)
			print("      ", "👥 ", otro_jugador.nombre, " esta en la casilla ", casilla.index, ", se mueve")
			var dir_away = casilla.global_transform.basis.x.normalized()
			var offset_away = dir_away * 2
			if not triangular:
				var tween_away = otro_jugador.create_tween()
				tween_away.tween_property(otro_jugador, "position", otro_jugador.global_position + offset_away, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				otro_jugador.set_moved_out(true)
				await tween_away.finished
				otro_jugador.set_moved_out(false)
			else:
				# Movimiento triangular: primero desviación 45º, luego posicionarse donde normalmente queda respecto a la casilla
				var angle = deg_to_rad(45)
				var c = cos(angle)
				var s = sin(angle)
				# Rotamos dir_away alrededor del eje Y
				var dir_dev = Vector3(dir_away.x * c - dir_away.z * s, 0, dir_away.x * s + dir_away.z * c).normalized()
				var offset_dev = dir_dev * 2
				var first_dest = otro_jugador.global_position + offset_dev
				var final_dest = casilla.global_transform.origin + dir_away * 2
				# Primera animación: desviación
				var tween1 = otro_jugador.create_tween()
				tween1.tween_property(otro_jugador, "position", first_dest, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				otro_jugador.set_moved_out(true)
				await tween1.finished
				# Segunda animación: posicionarse en la posición normal respecto a la casilla
				var tween2 = otro_jugador.create_tween()
				tween2.tween_property(otro_jugador, "position", final_dest, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				await tween2.finished
				otro_jugador.set_moved_out(false)
			# Hacer que el jugador rote mirando a la casilla después de ser desplazado
			await rotate_player_towards_point(otro_jugador, casilla.global_transform.origin)
			otro_jugador.set_running_state(false)


# ############################################################
# Bifurcaciones
# ############################################################

func iniciar_seleccion_bifurcacion(jugador: Node3D, destinos: Array[Casilla]):
	en_bifurcacion = true
	jugador_en_bifurcacion = jugador
	casillas_destino_disponibles = destinos
	indice_destino_seleccionado = 0
	
	print("         ", "🔀 ", jugador.nombre, " en bifurcacion (", destinos.size(), " opciones). Usa ← → y aceptar para confirmar.")
	
	# Instanciar flechas que señalan a los destinos y actualizar visuales
	crear_flechas_seleccion(jugador, destinos)
	actualizar_indicadores_visuales()

func preseleccionar_destino(incremento: int) -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	# Actualizar indice
	indice_destino_seleccionado = (indice_destino_seleccionado + incremento) % casillas_destino_disponibles.size()
	if indice_destino_seleccionado < 0:
		indice_destino_seleccionado = casillas_destino_disponibles.size() - 1
	
	var casilla_seleccionada = casillas_destino_disponibles[indice_destino_seleccionado]
	
	# Actualizar indicadores visuales
	actualizar_indicadores_visuales()
	
	return casilla_seleccionada

func seleccionar_destino() -> Casilla:
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	var casilla_elegida = casillas_destino_disponibles[indice_destino_seleccionado]
	print("         ", "✅ ", jugador_en_bifurcacion.nombre, " eligio casilla ", casilla_elegida.index)
	
	# Guardar eleccion y limpiar estado de bifurcacion
	ultimo_destino_confirmado = casilla_elegida
	finalizar_seleccion_bifurcacion()
	
	return casilla_elegida

func actualizar_indicadores_visuales():
	if not en_bifurcacion:
		return
	
	# Actualizar opacidad de flechas (si existen)
	update_flechas_alpha()

func finalizar_seleccion_bifurcacion():
	# Destruir flechas instanciadas
	for f in flechas_instanciadas:
		if f and f.is_inside_tree():
			f.queue_free()
	flechas_instanciadas.clear()
	
	en_bifurcacion = false
	jugador_en_bifurcacion = null
	casillas_destino_disponibles.clear()
	indice_destino_seleccionado = 0


# Mostrar flechas en la seleccion de bifurcacion
func crear_flechas_seleccion(jugador: Node3D, destinos: Array[Casilla]) -> void:
	# Limpiar flechas existentes
	for f in flechas_instanciadas:
		if f and f.is_inside_tree():
			f.queue_free()
	flechas_instanciadas.clear()
	
	# Instanciar una flecha por cada destino
	for destino in destinos:
		var f = flecha_escena.instantiate()
		tablero.add_child(f)
		# Calcular direccion horizontal hacia el destino
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
		# Ajustar seleccionada por defecto
		set_flecha_selected(f, 0.25)
		flechas_instanciadas.append(f)
	# Marcar la seleccion inicial
	if flechas_instanciadas.size() > 0 and indice_destino_seleccionado < flechas_instanciadas.size():
		set_flecha_selected(flechas_instanciadas[indice_destino_seleccionado], 1.0)

func set_flecha_selected(f: MeshInstance3D, alpha: float) -> void:
	if f == null:
		return
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 145.0 / 255.0, 0.0, alpha)
	f.material_override = mat
	var ap = f.get_node_or_null("AnimationPlayer")
	if ap != null:
		# Reproducir animacion segun si es seleccionada o no
		if alpha >= 1.0:
			ap.play("selected")
		else:
			ap.play("RESET")

func update_flechas_alpha() -> void:
	for i in range(flechas_instanciadas.size()):
		var f = flechas_instanciadas[i]
		if i == indice_destino_seleccionado:
			set_flecha_selected(f, 1.0)
		else:
			set_flecha_selected(f, 0.25)


# ############################################################
# Compra de Bateria
# ############################################################

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
			await get_tree().create_timer(2).timeout
		else:
			print("      ❌ No tienes suficientes microchips para comprar.")
			await get_tree().create_timer(1).timeout
	else:
		print("      ❌ ", jugador.nombre, " rechazó comprar una BATERIA.")
		print("      💾 Microchips: ", jugador.get_microchips())
		await get_tree().create_timer(1).timeout
	
	en_compra_bateria = false


# ############################################################
# CAMARA
# ############################################################

func rotate_player_towards_camera(jugador_actual: Node3D) -> void:
	# Rotar jugador hacia la camara suavemente usando Tween
	if camera == null or jugador_actual == null:
		return
	# Usar la posición de la cámara pero con la misma altura Y que el jugador
	var cam_pos = camera.global_transform.origin
	var player_pos = jugador_actual.global_transform.origin
	cam_pos.y = player_pos.y
	var to_cam = cam_pos - player_pos
	# Si están demasiado cerca, no hacemos nada
	if to_cam.length() < 0.01:
		return
	jugador_actual.set_running_state(false)
	await get_tree().create_timer(.2).timeout
	jugador_actual.set_walking_state(true)
	# Calcular yaw directamente con atan2 para mayor robustez
	var yaw_rad = atan2(to_cam.x, to_cam.z)
	var yaw_deg = rad_to_deg(yaw_rad)
	var current_deg = jugador_actual.rotation_degrees
	# Normalizar yaw para escoger la ruta más corta (evitar giros > 180°)
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

# Rotación genérica hacia un punto (misma lógica que la rotación hacia la cámara)
func rotate_player_towards_point(jugador_actual: Node3D, target_point: Vector3) -> void:
	# Rotar jugador hacia un punto (preserva la altura Y del jugador) usando Tween
	if jugador_actual == null:
		return
	var player_pos = jugador_actual.global_transform.origin
	var tgt = target_point
	tgt.y = player_pos.y
	var to_tgt = tgt - player_pos
	# Si están demasiado cerca, no hacemos nada
	if to_tgt.length() < 0.01:
		return
	jugador_actual.set_running_state(false)
	await get_tree().create_timer(.2).timeout
	jugador_actual.set_walking_state(true)
	# Calcular yaw directamente con atan2 para mayor robustez
	var yaw_rad = atan2(to_tgt.x, to_tgt.z)
	var yaw_deg = rad_to_deg(yaw_rad)
	var current_deg = jugador_actual.rotation_degrees
	# Normalizar yaw para escoger la ruta más corta (evitar giros > 180°)
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


# ############################################################
# INPUT POR DISPOSITIVO (usando InputManager)
# ############################################################

func _on_device_button_pressed(device_id, _button_name: String) -> void:
	# Lobby: cualquier pulsación en un dispositivo no asignado crea un "slot" de jugador
	if lobby_open:
		if not _device_already_assigned(device_id):
			_add_player_slot(device_id)
			return

	# Si estamos en fase de spawn/espera: una pulsación del dispositivo asignado realiza spawn
	if waiting_for_spawns:
		var slot = _get_slot_by_device(device_id)
		if slot != null and not slot.spawned:
			spawn_player_for_device(device_id)
			# Si es el primer jugador en spawnear, requerimos una confirmacion adicional para iniciar partida
			if first_spawner_device == -1:
				first_spawner_device = device_id
				waiting_first_confirmation = true
			return

	# Si estamos esperando la confirmación del primer jugador, ignorar otras devices
	if waiting_first_confirmation and device_id == first_spawner_device:
		# tratar como confirmación extra (se intercepta en device_action/ui_accept también)
		pass


func _on_device_action(device_id, action_name: String) -> void:
	# Si estamos en el lobby, tratar cualquier acción también como "join" (añadir slot)
	if lobby_open:
		var already_assigned = _device_already_assigned(device_id)
		if not already_assigned:
			_add_player_slot(device_id)
			# Si el dispositivo NO estaba unido y la acción es cualquier cosa, solo unimos — no ejecutamos otras acciones
			# Si el dispositivo se acaba de unir con cualquier acción, sólo añadimos el slot —
			# no mostramos mensajes adicionales (el _add_player_slot ya reporta la unión).
			if action_name == "start":
				return
		# Si la acción fue 'start' y el dispositivo YA estaba asignado, solo Player 1 puede iniciarla
		if action_name == "start":
			# Requerir al menos 2 player_slots existentes
			if player_slots.size() < 2:
				print("❗ Necesitas al menos 2 jugadores para comenzar la partida. Actualmente: ", player_slots.size())
				return
			# Comprobar que solo el primer slot (Player 1) puede iniciar
			if player_slots.size() > 0 and device_id != player_slots[0].device_id:
				print("❗ Solo ", player_slots[0].name, " puede iniciar la partida.")
				return
			# Es Player 1 y hay 2+ players: iniciar la partida
			lobby_open = false
			await comenzar_partida()
			return

	# Confirmación del primer spawner: el mismo dispositivo debe volver a pulsar su botón (ui_accept)
	if waiting_first_confirmation and device_id == first_spawner_device and action_name == "ui_accept":
		waiting_first_confirmation = false
		waiting_for_spawns = false
		print("✅ Primer jugador confirmado. Iniciando partida.")
		# Finalizar inicio -> determinamos orden y arrancamos
		await _finalize_start()
		return

	# Durante la partida: acciones mapeadas por dispositivo
	if partida_activa:
		# Localizar jugador actual y comprobar device
		var jugador_actual = jugadores[jugador_actual_index]
		if jugador_actual != null and jugador_actual.device_id == device_id:
			match action_name:
				"ui_accept":
					# Si estamos en proceso de compra, aceptar confirma la compra
					if en_compra_bateria:
						await confirmar_compra_bateria(true)
						return
					# En bifurcación, confirmar selección si es el jugador_en_bifurcacion
					if en_bifurcacion and jugador_en_bifurcacion == jugador_actual:
						var destino = seleccionar_destino()
						if destino != null:
							return
					# Si no se confirmó una bifurcación, tirar dado
					tirar_dado()
				"ui_left":
					if en_bifurcacion:
						preseleccionar_destino(-1)
				"ui_right":
					if en_bifurcacion:
						preseleccionar_destino(1)
				"ui_cancel":
					if en_compra_bateria:
						await confirmar_compra_bateria(false)
				_:
					pass

	# Si no hay partida activa pero estamos en fase de espera de spawns, mapear confirmaciones rápidas
	if waiting_for_spawns:
		# Si el mismo dispositivo que spawnió presiona "ui_accept" lo tratamos como spawn/confirm
		var slot = _get_slot_by_device(device_id)
		if slot != null and not slot.spawned and action_name == "ui_accept":
			spawn_player_for_device(device_id)
			if first_spawner_device == -1:
				first_spawner_device = device_id
				waiting_first_confirmation = true

# -------------------------
# Helpers: slots / spawn
# -------------------------
func _device_already_assigned(device_id) -> bool:
	for s in player_slots:
		if s.device_id == device_id:
			return true
	return false

func _get_slot_by_device(device_id):
	for s in player_slots:
		if s.device_id == device_id:
			return s
	return null

func _add_player_slot(device_id) -> void:
	var default_colors = [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW]
	var idx = player_slots.size()
	var color = default_colors[idx % default_colors.size()]
	var slot_name = "Player " + str(idx + 1)
	var slot = {"name": slot_name, "color": color, "device_id": device_id, "spawned": false, "instance": null}
	player_slots.append(slot)
	print("🔔 Dispositivo ", device_id, " se ha unido como ", slot_name)

func spawn_player_for_device(device_id) -> void:
	var slot = _get_slot_by_device(device_id)
	if slot == null:
		print("❌ Intentando spawnear dispositivo no registrado: ", device_id)
		return
	if slot.spawned:
		print("❗ Dispositivo ya tiene jugador spawneado: ", device_id)
		return
	# Instanciar jugador y asignar device
	if jugador_escena == null:
		print("❌ Error: La escena del jugador no esta asignada.")
		return
	var jugador = jugador_escena.instantiate()
	jugador.configurar(slot.name, slot.color)
	jugador.device_id = device_id
	jugadores.append(jugador)
	tablero.add_child(jugador)
	# Inicializar estado equivalente a instanciar_jugadores
	jugador.pf = null
	jugador.posicion_casilla = 0
	await get_tree().create_timer(.05).timeout
	# Posicionar según spawn_point y offset (mantener lógica previa)
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

# Finalizar el inicio de la partida tras confirmación del primer jugador
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
