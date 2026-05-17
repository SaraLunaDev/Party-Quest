extends Node
class_name MainGameManager


# Señales
# ---------------------------------------------------------------------------------------
signal partida_iniciada()
signal partida_finalizada()
signal turno_iniciado(jugador_actual)
signal tutorial_avanzado


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
@export var main_menu: MainMenuUI
@export var conectar_tutorial: ConectarTutorialUI

var flechas_instanciadas: Array = []
var flechas_mapa: Array = []
var jugadores_almacenados_para_mapa: Array = []

var jugadores: Array = []
var jugador_actual_index: int = 0
var rondas_completadas: int = 0
var minijuegos_jugados_en_ronda: int = 0
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

var en_tutorial: bool = false

var en_fase_orden: bool = false
var resultados_orden: Array = []

var player_slots: Array = []
var input_manager: Node = null
var lobby_open: bool = false
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

	if GameData.tiene_estado_guardado:
		await _restaurar_desde_minijuego()
		return

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

	await camera_manager.set_state(CameraManager.STATE_GROUP, spawn_point.global_transform.origin)
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
	if conectar_tutorial:
		conectar_tutorial.ocultar()
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

	if camera_manager != null and spawn_point != null:
		await camera_manager.set_state(CameraManager.STATE_GROUP, spawn_point.global_transform.origin)
	SoundManager.play_music(SoundManager.MUSIC_TABLERO)

	if jugadores.size() >= 2:
		for j in jugadores:
			if not j.device_id:
				print("❌ Error: No todos los jugadores tienen un dispositivo asignado.")
				return

	print("\n🎉 Partida iniciada con ", jugadores.size(), " jugadores.")
	partida_activa = true
	emit_signal("partida_iniciada")
	await mostrar_tutoriales()
	await determinar_orden()
	iniciar_turno()

# Finaliza la partida, determina el ganador por baterias + microchips, enfoca camara y reinicia escena
func finalizar_partida():
	partida_activa = false
	emit_signal("partida_finalizada")
	print("🏁 Partida finalizada.")

	var ganador: Node3D = null

	print("\n🏆 Resultados finales:")
	for jugador in jugadores:
		print("   ", jugador.nombre, ": ", jugador.get_baterias(), " baterias, ", jugador.get_microchips(), " microchips")
		if ganador == null:
			ganador = jugador
		else:
			var b = jugador.get_baterias()
			var b_mejor = ganador.get_baterias()
			if b > b_mejor or (b == b_mejor and jugador.get_microchips() > ganador.get_microchips()):
				ganador = jugador

	if ganador == null:
		get_tree().reload_current_scene()
		return

	print("\n🥇 GANADOR: ", ganador.nombre, " con ", ganador.get_baterias(), " baterias y ", ganador.get_microchips(), " microchips")

	if camera_manager != null and spawn_point != null:
		await camera_manager.set_state(CameraManager.STATE_GROUP, spawn_point.global_transform.origin)
		await get_tree().create_timer(0.25).timeout

	if ingame_ui:
		ingame_ui.set_player_cards_visible(false)

	await _respawn_players_for_podium()
	await get_tree().create_timer(4.0).timeout
	var ranking = _ordenar_jugadores_por_resultado()
	await _mostrar_podio_final(ranking)
	await get_tree().create_timer(5.0).timeout

	get_tree().reload_current_scene()

func _ordenar_jugadores_por_resultado() -> Array:
	var orden = jugadores.duplicate()
	orden.sort_custom(Callable(self , "_comparar_jugadores_por_resultado"))
	return orden

func _comparar_jugadores_por_resultado(a, b) -> bool:
	if a.get_baterias() != b.get_baterias():
		return a.get_baterias() > b.get_baterias()
	if a.get_microchips() != b.get_microchips():
		return a.get_microchips() > b.get_microchips()
	return a.posicion_casilla > b.posicion_casilla

func _respawn_players_for_podium() -> void:
	if spawn_point == null:
		return

	var center = (jugadores.size() - 1) * 0.5
	var right = spawn_point.global_transform.basis.x.normalized()
	for i in range(jugadores.size()):
		var jugador = jugadores[i]
		var offset = (i - center) * spawn_space
		jugador.global_position = spawn_point.global_position + right * offset
		jugador.rotation_degrees = spawn_point.rotation_degrees
		jugador.posicion_casilla = 0
		jugador.almacenado_en_casilla = false
		if jugador.has_method("restore_from_storage"):
			jugador.restore_from_storage()
		jugador.set_looking_at_camera(true)
		jugador.set_idle_state(true)
		jugador.set_spawning_state(true)
		await get_tree().create_timer(0.12).timeout
		jugador.set_spawning_state(false)

	await get_tree().create_timer(0.2).timeout

func _mostrar_podio_final(ranking: Array) -> void:
	for jugador in jugadores:
		if jugador.has_method("show_podium"):
			jugador.show_podium(true, false)

	var previous_raise: float = 0.0
	for i in range(ranking.size()):
		var jugador = ranking[ranking.size() - 1 - i]
		var raise_amount = 0.6 + i * 0.4
		var tween = jugador.create_tween()
		tween.tween_property(jugador, "global_position:y", jugador.global_position.y + raise_amount, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tween.finished

		var camera_raise = raise_amount - previous_raise
		if camera_manager != null and camera_manager.camera != null and camera_raise != 0.0:
			camera_manager.shift_group_camera_y(camera_raise)
		previous_raise = raise_amount

		await get_tree().create_timer(2.0).timeout

	for index in range(ranking.size()):
		var jugador = ranking[index]
		if jugador.number_label_3d:
			jugador.number_label_3d.text = str(index + 1)
		jugador.set_looking_at_camera(true)
		await jugador.set_number_visibility_state(true)
		match index:
			0:
				if jugador.has_method("play_final_animation"):
					jugador.play_final_animation("cheer")
			1:
				if jugador.has_method("play_final_animation"):
					jugador.play_final_animation("wave")
			2:
				if jugador.has_method("play_final_animation"):
					jugador.play_final_animation("idle")
			3:
				if jugador.has_method("play_final_animation"):
					jugador.play_final_animation("hit")
			_:
				if jugador.has_method("play_final_animation"):
					jugador.play_final_animation("idle")

func _restaurar_desde_minijuego() -> void:
	# Ocultar UI de lobby y menu principal si siguen visibles
	if main_menu:
		main_menu.ocultar()
	if conectar_tutorial:
		conectar_tutorial.ocultar()
	if ingame_ui:
		ingame_ui.mostrar()

	# Restaurar tipos de casilla dinámicos guardados antes de entrar al minijuego
	if GameData.tablero_casillas.size() > 0:
		for casilla_info in GameData.tablero_casillas:
			var casilla = buscar_casilla(casilla_info.index)
			if casilla != null:
				casilla.set_tipo(casilla_info.tipo)

	# Instanciar jugadores almacenados en sus casillas desde el primer momento
	jugadores.clear()
	for d in GameData.jugadores_data:
		var j = jugador_escena.instantiate()
		j.configurar(d.nombre, d.color)
		j.device_id = d.device_id
		j.microchips = d.microchips
		j.baterias = d.baterias
		j.posicion_casilla = d.posicion_casilla
		j.pf = null
		# Marcar como almacenado antes de add_child para que _ready() no deshaga el estado
		j.almacenado_en_casilla = true
		if j.player_mesh:
			j.player_mesh.position.y = -4.0
		tablero.add_child(j)
		# Posicionar en casilla tras add_child (global_position requiere estar en el arbol)
		var casilla = buscar_casilla(j.posicion_casilla)
		if casilla:
			j.global_position = casilla.global_position
			j.posicion_almacenada = casilla.global_position
			j.mesh_y_almacenada = 0.12
			casilla.tiene_jugador_almacenado = true
		jugadores.append(j)

	for resultado in GameData.resultados_minijuego:
		for jugador in jugadores:
			if jugador.nombre == resultado.nombre:
				if resultado.has("microchips_ganados"):
					jugador.establecer_microchips(resultado.microchips_ganados, false)
				if resultado.has("baterias_ganadas"):
					jugador.establecer_baterias(resultado.baterias_ganadas, false)
				break
	GameData.resultados_minijuego.clear()

	for j in jugadores:
		if ingame_ui:
			ingame_ui.add_player_to_ui(j)
			ingame_ui.update_player_info(j)

	rondas_completadas = GameData.rondas_completadas
	limite_rondas = GameData.limite_rondas
	jugador_actual_index = GameData.jugador_actual_index
	minijuegos_jugados_en_ronda = 1
	GameData.tiene_estado_guardado = false
	GameData.tablero_casillas.clear()

	partida_activa = true
	SoundManager.play_music(SoundManager.MUSIC_TABLERO)
	emit_signal("partida_iniciada")
	print("🔄 Restaurado desde minijuego. Ronda ", rondas_completadas, ", turno de ", jugadores[jugador_actual_index].nombre)
	if GameData.omitir_incremento_ronda:
		GameData.omitir_incremento_ronda = false
		if ingame_ui:
			SoundManager.play_sfx(SoundManager.SFX_ANUNCIO_RONDA)
			await ingame_ui.mostrar_ronda(rondas_completadas, limite_rondas)
		iniciar_turno(true)
	else:
		iniciar_turno()

# Determina el orden de los jugadores al inicio de la partida: todos los dados aparecen a la vez y cada jugador tira cuando quiera
func determinar_orden():
	print("\n🤔 Determinando el orden")
	resultados_orden.clear()

	if camera_manager != null and spawn_point != null:
		await camera_manager.set_state(CameraManager.STATE_GROUP, spawn_point.global_transform.origin)

	await rotate_all_players_towards_camera(0.8)

	if ingame_ui:
		var texto = TranslationServer.translate("KEY_ORDER_DICE")
		en_tutorial = true
		await ingame_ui.mostrar_texto_tutorial(texto)
		await tutorial_avanzado
		en_tutorial = false
		ingame_ui.ocultar_texto_tutorial()

	for jugador in jugadores:
		var dado = jugador.get_node_or_null("Dado")
		if dado != null:
			dado.dice_visibility(true)

	await get_tree().create_timer(1.0).timeout
	en_fase_orden = true
	print("   Todos los jugadores: pulsa aceptar para tirar el dado")

	while resultados_orden.size() < jugadores.size():
		await get_tree().process_frame

	await get_tree().create_timer(2.5).timeout
	en_fase_orden = false

	for jugador in jugadores:
		jugador.set_number_visibility_state(false)
	await get_tree().create_timer(.4).timeout

	resultados_orden.sort_custom(func(a, b): return a.resultado > b.resultado)
	var jugadores_ordenados = []

	print("\n😯 Orden de Jugadores:")
	for i in resultados_orden.size():
		jugadores_ordenados.append(resultados_orden[i].jugador)
		print("   ", i + 1, ".- ", resultados_orden[i].jugador.nombre, " (", resultados_orden[i].resultado, ")")
	jugadores = jugadores_ordenados
	resultados_orden.clear()
	print()

# Ejecuta la tirada del dado de un jugador concreto durante la fase de determinacion de orden
func _tirar_dado_orden_jugador(jugador: Node3D):
	for r in resultados_orden:
		if r.jugador == jugador:
			return

	var resultado = randi() % tirada_maxima + 1
	jugador.set_jumping_state(true)
	var dado = jugador.get_node_or_null("Dado")
	if dado != null:
		dado.stop_dice(resultado)
		jugador.get_node_or_null("Number").text = str(resultado)
		await jugador.set_number_visibility_state(true)

	resultados_orden.append({"jugador": jugador, "resultado": resultado})
	print("   ", "🎲 ", jugador.nombre, " ha tirado: ", resultado)
#endregion


# Gestion de Turnos
# ---------------------------------------------------------------------------------------
#region

# Inicia el turno del jugador actual, ajustando su posicion si es necesario, haciendo que salude a la camara y mostrando el dado para que lo tire
func iniciar_turno(skip_round_check: bool = false):
	if jugador_actual_index == 0 and rondas_completadas == 0:
		SoundManager.play_music(SoundManager.MUSIC_TABLERO)
	await get_tree().create_timer(1.4).timeout

	if !partida_activa:
		return

	if jugador_actual_index == 0 and not skip_round_check:
		rondas_completadas += 1
		if rondas_completadas > limite_rondas:
			finalizar_partida()
			return
		if rondas_completadas % 2 == 0 and minijuegos_jugados_en_ronda == 0:
			minijuegos_jugados_en_ronda += 1
			print("\n🎮 Minijuego de ronda ", rondas_completadas)
			partida_activa = false
			GameData.omitir_incremento_ronda = true
			if camera_manager != null:
				await camera_manager.set_state(CameraManager.STATE_OVERVIEW, Vector3.ZERO, Vector3.ZERO)
			if ingame_ui:
				SoundManager.play_sfx(SoundManager.SFX_ANUNCIO_MINIJUEGO)
				await ingame_ui.mostrar_minijuego()
			GameData.guardar_estado(jugadores, tablero, 0, rondas_completadas, limite_rondas)
			var siguiente_minijuego = MinijuegoManager.elegir_aleatorio()
			GameData.ultimo_minijuego = siguiente_minijuego
			get_tree().change_scene_to_file(siguiente_minijuego)
			return
		else:
			minijuegos_jugados_en_ronda = 0
			print("\n🔄 Comenzando ronda ", rondas_completadas)
			print("----------------------")
			if ingame_ui:
				SoundManager.play_sfx(SoundManager.SFX_ANUNCIO_RONDA)
				await ingame_ui.mostrar_ronda(rondas_completadas, limite_rondas)

	var jugador_actual = jugadores[jugador_actual_index]

	if camera_manager != null:
		camera_manager.set_target_player(jugador_actual)
		await camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)

	var casilla_inicio = buscar_casilla(jugador_actual.posicion_casilla)
	if jugador_actual.almacenado_en_casilla:
		if casilla_inicio:
			await casilla_inicio.abrir_trampilla()
		if casilla_inicio and casilla_inicio.boton:
			get_tree().create_timer(0.5).timeout.connect(func(): casilla_inicio.cerrar_trampilla(true), CONNECT_ONE_SHOT)
		await jugador_actual.sacar_de_casilla()
		if casilla_inicio:
			casilla_inicio.tiene_jugador_almacenado = false
	elif casilla_inicio != null and rondas_completadas > 1:
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

	if not partida_activa:
		return

	var casilla_aterrizaje = buscar_casilla(jugador_actual.posicion_casilla)
	await get_tree().create_timer(1.0).timeout
	if casilla_aterrizaje:
		casilla_aterrizaje.tiene_jugador_almacenado = true
		if casilla_aterrizaje.boton:
			casilla_aterrizaje.abrir_trampilla()
	await jugador_actual.almacenar_en_casilla()
	if casilla_aterrizaje and casilla_aterrizaje.boton:
		await casilla_aterrizaje.cerrar_trampilla()
	print("   📦 ", jugador_actual.nombre, " almacenado en casilla ", jugador_actual.posicion_casilla)
	
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
	var _mover_sfx: AudioStreamPlayer = null


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
			SoundManager.stop_sfx_player(_mover_sfx)
			destino = await manejar_bifurcacion(jugador, destinos)
			_mover_sfx = SoundManager.play_sfx_looping(SoundManager.SFX_JUGADOR_MOVER, -1.0, 1.0, 0.05, 0.05)
			jugador.set_running_state(true)
		else:
			destino = destinos[0]
		
		print("      ", "➡️ ", jugador.nombre, " se mueve a la casilla ", destino.index)
		
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
			SoundManager.stop_sfx_player(_mover_sfx)
			_mover_sfx = null
			await realizar_movimiento_salto(jugador, destino, jugador.get_jump_duration())
		else:
			if _mover_sfx == null:
				_mover_sfx = SoundManager.play_sfx_looping(SoundManager.SFX_JUGADOR_MOVER, -1.0, 1.0, 0.15, 0.15)
			await realizar_movimiento_normal(jugador, destino, duration)
			SoundManager.play_sfx(SoundManager.SFX_PASO_CASILLA)
		
		if destino.get_tipo() == Casilla.tipo_casilla.BATERIA:
			await jugador.set_number_visibility_state(false)
			jugador.set_running_state(false)
			SoundManager.stop_sfx_player(_mover_sfx)
			await manejar_compra_bateria(jugador)
			await jugador.set_number_visibility_state(true)
			if camera_manager != null:
				camera_manager.set_target_player(jugador)
				await camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)
			_mover_sfx = SoundManager.play_sfx_looping(SoundManager.SFX_JUGADOR_MOVER, -1.0, 1.0, 0.15, 0.15)
			jugador.set_running_state(true)
			continue

	await jugador.set_number_visibility_state(false)
	print("\n   ", "✅ ", jugador.nombre, " ha llegado a la casilla ", jugador.posicion_casilla, " (", buscar_casilla(jugador.posicion_casilla).get_nombre(), ")")
	SoundManager.stop_sfx_player(_mover_sfx)
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
			print("   🎳 Lanzando minijuego...")
			partida_activa = false
			await camera_manager.set_state(CameraManager.STATE_LOOK_AT, jugador.global_transform.origin, Vector3.ZERO)
			await rotate_player_towards_camera(jugador)
			if ingame_ui:
				SoundManager.play_sfx(SoundManager.SFX_ANUNCIO_MINIJUEGO)
				await ingame_ui.mostrar_minijuego()
			var proximo_indice = (jugador_actual_index + 1) % jugadores.size()
			GameData.guardar_estado(jugadores, tablero, proximo_indice, rondas_completadas, limite_rondas)
			var siguiente_minijuego = MinijuegoManager.elegir_aleatorio()
			GameData.ultimo_minijuego = siguiente_minijuego
			get_tree().change_scene_to_file(siguiente_minijuego)
			return

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
	SoundManager.play_sfx(SoundManager.SFX_SALTO_IMPULSO)
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
	jugador.set_jumping_state(false)
	jugador.set_running_state(false)
	jugador.set_walking_state(false)
	jugador.set_idle_state(true)
	SoundManager.play_sfx(SoundManager.SFX_SALTO_ATERRIZAJE)
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
			var dir_incoming = (otro_jugador.global_position - jugador_excluido.global_position)
			dir_incoming.y = 0
			var misma_posicion = dir_incoming.length() < 0.1
			if misma_posicion:
				var tween_away = otro_jugador.create_tween()
				tween_away.tween_property(otro_jugador, "position", jugador_excluido.global_position, 0.75)
				otro_jugador.set_moved_out(true)
				await tween_away.finished
				otro_jugador.set_moved_out(false)
			else:
				dir_incoming = dir_incoming.normalized()
				var dir_away = Vector3(-dir_incoming.z, 0, dir_incoming.x)
				var offset_away = dir_away * 2
				if not triangular:
					var tween_away = otro_jugador.create_tween()
					tween_away.tween_property(otro_jugador, "position", otro_jugador.global_position + offset_away, 0.75)
					otro_jugador.set_moved_out(true)
					await tween_away.finished
					otro_jugador.set_moved_out(false)
				else:
					var start_pos = otro_jugador.global_position
					var final_dest = otro_jugador.global_position + dir_away * 2
					
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
	SoundManager.play_sfx(SoundManager.SFX_BIFURCACION_FLECHA)
	actualizar_indicadores_visuales()

# Permite al jugador preseleccionar una opcion de destino en la bifurcacion usando las flechas, actualizando los indicadores visuales para mostrar la opcion actualmente seleccionada
func preseleccionar_destino(incremento: int):
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	indice_destino_seleccionado = (indice_destino_seleccionado + incremento) % casillas_destino_disponibles.size()
	if indice_destino_seleccionado < 0:
		indice_destino_seleccionado = casillas_destino_disponibles.size() - 1
	
	var casilla_seleccionada = casillas_destino_disponibles[indice_destino_seleccionado]
	
	actualizar_indicadores_visuales()
	SoundManager.play_sfx(SoundManager.SFX_BIFURCACION_NAVEGAR)
	return casilla_seleccionada

# Confirma la seleccion del destino en la bifurcacion, devolviendo la casilla destino elegida y finalizando el proceso de seleccion
func seleccionar_destino():
	if not en_bifurcacion or casillas_destino_disponibles.is_empty():
		return null
	
	var casilla_elegida = casillas_destino_disponibles[indice_destino_seleccionado]
	print("         ", "✅ ", jugador_en_bifurcacion.nombre, " eligio casilla ", casilla_elegida.index)
	SoundManager.play_sfx(SoundManager.SFX_BIFURCACION_CONFIRMAR)
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

func mostrar_flechas_bifurcaciones() -> void:
	ocultar_flechas_bifurcaciones()
	if tablero == null or not tablero.has_method("obtener_casillas_del_tablero"):
		return

	var todas_casillas = tablero.obtener_casillas_del_tablero()
	for casilla in todas_casillas:
		var destinos = casilla.get_casillas_destino()
		if destinos.size() <= 1:
			continue
		for destino in destinos:
			var f = flecha_escena.instantiate()
			tablero.add_child(f)
			var dir = destino.global_position - casilla.global_position
			dir.y = 0
			var distancia = 1.5
			var altura = 1.2
			f.global_transform.origin = casilla.global_transform.origin + dir.normalized() * distancia + Vector3(0, altura, 0)
			var yaw = atan2(dir.x, dir.z)
			yaw += PI
			var x_offset_deg: float = -90.0
			f.rotation = Vector3(deg_to_rad(x_offset_deg), yaw, 0)
			set_flecha_selected(f, 1.0)
			flechas_mapa.append(f)

func ocultar_flechas_bifurcaciones() -> void:
	for f in flechas_mapa:
		if f and f.is_inside_tree():
			f.queue_free()
	flechas_mapa.clear()

func _mostrar_vista_mapa() -> void:
	if ingame_ui:
		ingame_ui.set_map_view_open(true)
	if camera_manager != null:
		await camera_manager.set_state(CameraManager.STATE_MAPVIEW)
	mostrar_flechas_bifurcaciones()
	await _guardar_y_sacar_jugadores_de_casillas()

func _ocultar_vista_mapa() -> void:
	if ingame_ui:
		ingame_ui.set_map_view_open(false)
	ocultar_flechas_bifurcaciones()
	await _restaurar_jugadores_en_casillas()

func _guardar_y_sacar_jugadores_de_casillas() -> void:
	jugadores_almacenados_para_mapa.clear()
	var jugadores_esperados: Array = []
	for jugador in jugadores:
		if jugador.almacenado_en_casilla:
			jugadores_almacenados_para_mapa.append(jugador)
			var casilla = buscar_casilla(jugador.posicion_casilla)
			if casilla:
				casilla.tiene_jugador_almacenado = false
			jugadores_esperados.append(jugador)
			jugador.sacar_de_casilla()

	for jugador in jugadores_esperados:
		await jugador.sacado_de_casilla_complete

func _restaurar_jugadores_en_casillas() -> void:
	var jugadores_esperados: Array = []
	for jugador in jugadores_almacenados_para_mapa:
		var casilla = buscar_casilla(jugador.posicion_casilla)
		if casilla:
			casilla.tiene_jugador_almacenado = true
		jugadores_esperados.append(jugador)
		jugador.almacenar_en_casilla()

	for jugador in jugadores_esperados:
		await jugador.almacenado_en_casilla_complete
	jugadores_almacenados_para_mapa.clear()

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


# Gestion de Tutoriales
# ---------------------------------------------------------------------------------------
#region

# Muestra la secuencia de tutoriales al inicio de la partida
func mostrar_tutoriales() -> void:
	if ingame_ui == null:
		return

	var tutos = [
		{"clave": "KEY_GAME_TUTO_1", "tipo": - 1},
		{"clave": "KEY_GAME_TUTO_2", "tipo": - 1, "dado": true},
		{"clave": "KEY_GAME_TUTO_3", "tipo": Casilla.tipo_casilla.NORMAL, "indice": 1},
		{"clave": "KEY_GAME_TUTO_4", "tipo": Casilla.tipo_casilla.ROJA},
		{"clave": "KEY_GAME_TUTO_5", "tipo": Casilla.tipo_casilla.MINIJUEGO},
		{"clave": "KEY_GAME_TUTO_6", "tipo": Casilla.tipo_casilla.BATERIA, "crear_bateria": true},
		{"clave": "KEY_GAME_TUTO_7", "tipo": Casilla.tipo_casilla.BATERIA},
		{"clave": "KEY_GAME_TUTO_8", "tipo": - 1},
		{"clave": "KEY_GAME_TUTO_9", "tipo": - 1},
	]

	var dado_tuto: Dado = null
	var dado_base_y: float = 0.0

	for i in tutos.size():
		var tuto = tutos[i]

		if tuto.get("crear_bateria", false):
			await convertir_casilla_lejana_a_bateria()
		elif tuto.get("dado", false):
			var jugador_ref = jugadores[0]
			dado_tuto = jugador_ref.get_node_or_null("Dado")
			if dado_tuto != null:
				dado_base_y = dado_tuto.position.y
				dado_tuto.dice_visibility(true)
				await camera_manager.set_state(CameraManager.STATE_LOOK_AT, jugador_ref.global_transform.origin, Vector3.ZERO)
		elif tuto.tipo >= 0:
			var casilla = _buscar_casilla_lejana_tipo(tuto.tipo as Casilla.tipo_casilla, tuto.get("indice", 0))
			if casilla != null and camera_manager != null:
				await camera_manager.set_state(CameraManager.STATE_LOOK_AT, casilla.global_transform.origin, Vector3.ZERO)

		var texto = TranslationServer.translate(tuto.clave)
		en_tutorial = true
		await ingame_ui.mostrar_texto_tutorial(texto)

		await tutorial_avanzado
		en_tutorial = false

		if tuto.get("dado", false) and dado_tuto != null:
			var jugador_ref = jugadores[0]
			var resultado = randi() % tirada_maxima + 1
			jugador_ref.set_jumping_state(true)
			jugador_ref.get_node_or_null("Number").text = str(resultado)
			await dado_tuto.stop_dice(resultado)
			await jugador_ref.set_number_visibility_state(true)
			await get_tree().create_timer(1.5).timeout
			await jugador_ref.set_number_visibility_state(false)
			dado_tuto.position.y = dado_base_y
			dado_tuto = null
			var siguiente = tutos[i + 1] if i + 1 < tutos.size() else null
			if siguiente != null and siguiente.tipo < 0 and not siguiente.get("dado", false) and not siguiente.get("crear_bateria", false):
				if spawn_point != null and camera_manager != null:
					await camera_manager.set_state(CameraManager.STATE_LOOK_AT, spawn_point.global_transform.origin, Vector3.ZERO)

	ingame_ui.ocultar_texto_tutorial()

# Devuelve la casilla del tipo indicado mas lejana de los jugadores (indice 0 = la mas lejana, 1 = segunda mas lejana)
func _buscar_casilla_lejana_tipo(tipo: Casilla.tipo_casilla, indice: int = 0) -> Casilla:
	if tablero == null or not tablero.has_method("obtener_casillas_del_tablero"):
		return null
	var todas_casillas = tablero.obtener_casillas_del_tablero()
	var casillas_tipo = todas_casillas.filter(func(c): return c.get_tipo() == tipo)
	if casillas_tipo.size() == 0:
		return null

	var con_distancia: Array = []
	for casilla in casillas_tipo:
		var distancia_minima = INF
		for jugador in jugadores:
			var d = casilla.global_position.distance_to(jugador.global_position)
			if d < distancia_minima:
				distancia_minima = d
		con_distancia.append({"casilla": casilla, "distancia": distancia_minima})

	con_distancia.sort_custom(func(a, b): return a.distancia > b.distancia)

	if indice >= con_distancia.size():
		indice = con_distancia.size() - 1
	return con_distancia[indice].casilla
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
		SoundManager.play_sfx(SoundManager.SFX_CASILLA_BATERIA_APARECE)
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
		
		if ingame_ui:
			var texto_compra = TranslationServer.translate("KEY_BATTERY_BUY") % [costo_bateria]
			await ingame_ui.mostrar_texto_tutorial(texto_compra)
		
		while en_compra_bateria:
			await get_tree().process_frame
		
		if ingame_ui:
			ingame_ui.ocultar_texto_tutorial()
	else:
		print("   ❌ No tienes suficientes microchips (tienes ", jugador.get_microchips(), ", necesitas ", costo_bateria, ")")
		
		if ingame_ui:
			var texto_sin_chips = TranslationServer.translate("KEY_BATTERY_NO_CHIPS")
			en_tutorial = true
			await ingame_ui.mostrar_texto_tutorial(texto_sin_chips)
			await tutorial_avanzado
			en_tutorial = false
			ingame_ui.ocultar_texto_tutorial()
		else:
			await get_tree().create_timer(2).timeout
		
		en_compra_bateria = false
		jugador_en_compra = null

# Confirma la compra de bateria, descontando los microchips correspondientes si el jugador decide comprar y actualizando su cantidad de baterias, o simplemente rechazando la compra si el jugador decide no comprar
func confirmar_compra_bateria(comprar: bool) -> void:
	if not en_compra_bateria or jugador_en_compra == null:
		return
	
	if ingame_ui:
		ingame_ui.ocultar_texto_tutorial()
	
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

	var target_deg = Vector3(current_deg.x, desired_y, current_deg.z)
	jugador_actual.set_looking_at_camera(true)
	jugador_actual.set_walking_state(true)

	var tween = jugador_actual.create_tween()
	tween.tween_property(jugador_actual, "rotation_degrees", target_deg, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	jugador_actual.set_looking_at_camera(false)
	jugador_actual.set_walking_state(false)

# Hace que todos los jugadores roten suavemente para mirar hacia la camara al mismo tiempo
func rotate_all_players_towards_camera(duration: float = 0.6) -> void:
	for jugador in jugadores:
		jugador.set_looking_at_camera(true)
		jugador.set_walking_state(true)

	await get_tree().create_timer(duration).timeout

	for jugador in jugadores:
		jugador.set_looking_at_camera(false)
		jugador.set_walking_state(false)

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

	if en_tutorial and action_name == "ui_accept":
		if ingame_ui and ingame_ui.escribiendo_texto:
			ingame_ui.saltar_texto_tutorial()
		else:
			emit_signal("tutorial_avanzado")
		return

	if en_fase_orden and action_name == "ui_accept":
		for jugador in jugadores:
			if jugador.device_id == device_id:
				await _tirar_dado_orden_jugador(jugador)
				break
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
				"ui_right":
					if en_bifurcacion:
						preseleccionar_destino(1)
				"ui_up":
					if ingame_ui and not en_bifurcacion:
						ingame_ui.navigate_selection(1)
				"ui_down":
					if ingame_ui and not en_bifurcacion:
						ingame_ui.navigate_selection(-1)
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
	SoundManager.play_sfx(SoundManager.SFX_JUGADOR_UNIRSE)
	SoundManager.play_music(SoundManager.MUSIC_MAIN_MENU)
	if ingame_ui:
		ingame_ui.add_slot_to_ui(slot_name)
	if conectar_tutorial:
		if player_slots.size() >= 2:
			conectar_tutorial.mostrar_hint_inicio(player_slots[0].device_id == "keyboard")
		else:
			conectar_tutorial.ocultar_hint_inicio()
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
	if camera_manager != null and spawn_point != null:
		await camera_manager.set_state(CameraManager.STATE_GROUP, spawn_point.global_transform.origin)
	SoundManager.play_music(SoundManager.MUSIC_TABLERO)
	partida_activa = true
	emit_signal("partida_iniciada")
	await mostrar_tutoriales()
	await determinar_orden()
	iniciar_turno()

# Funciones de callback para los botones de UI
func _on_ui_dice_button_pressed():
	if esperando_dado and partida_activa:
		tirar_dado()

func _on_ui_map_button_pressed():
	if not partida_activa or ingame_ui == null:
		return

	if ingame_ui.is_map_view_open():
		if camera_manager != null and jugadores.size() > 0 and jugador_actual_index >= 0 and jugador_actual_index < jugadores.size():
			camera_manager.set_target_player(jugadores[jugador_actual_index])
			camera_manager.set_state(CameraManager.STATE_FOLLOW, Vector3.ZERO, Vector3.ZERO)

		_ocultar_vista_mapa()
		return

	if not esperando_dado:
		return

	await _mostrar_vista_mapa()
	return

# Funciones de callback para los botones de UI
