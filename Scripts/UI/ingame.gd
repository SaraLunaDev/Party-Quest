extends Control
class_name IngameUI


# Señales
# ---------------------------------------------------------------------------------------
signal dice_button_pressed
signal map_button_pressed
signal button_selection_changed(selection: ButtonSelection)
signal texto_completado


# Variables
# ---------------------------------------------------------------------------------------
@export var dice_button: Button
@export var map_button: Button
@export var buttons_container: MarginContainer
@export var button_icon: Texture2D
@export var player_info_position: VBoxContainer
@export var player_info_scene: PackedScene

@onready var rondas_container: MarginContainer = $CanvasLayer/Rondas
@onready var numero_ronda_label: Label = $CanvasLayer/Rondas/HBoxContainer/NumeroRonda
@onready var minijuego_container: MarginContainer = $CanvasLayer/MiniJuego
@onready var animation_player: AnimationPlayer = $CanvasLayer/AnimationPlayer
@onready var text_box: MarginContainer = $CanvasLayer/TextBox
@onready var text_label: Label = $CanvasLayer/TextBox/Text

enum ButtonSelection {
	DICE,
	MAP
}

var current_selection: ButtonSelection = ButtonSelection.DICE
var buttons_active: bool = false
var map_view_open: bool = false
var game_manager: Node = null
var dice_button_original_size: Vector2
var map_button_original_size: Vector2

var player_info_instances: Array[PlayerInfoUI] = []
var players_data: Array = []

var _texto_tween: Tween = null
var escribiendo_texto: bool = false
var _last_visible_chars: int = 0


# Funciones Basicas
# ---------------------------------------------------------------------------------------
func _ready():
	rondas_container.visible = false
	minijuego_container.visible = false
	text_box.visible = false
	if dice_button:
		dice_button.pressed.connect(_on_dice_button_pressed)
		dice_button_original_size = dice_button.custom_minimum_size
		dice_button.mouse_entered.connect(_on_button_mouse_entered.bind(dice_button))
		dice_button.mouse_exited.connect(_on_button_mouse_exited.bind(dice_button))
	if map_button:
		map_button.pressed.connect(_on_map_button_pressed)
		map_button_original_size = map_button.custom_minimum_size
		map_button.mouse_entered.connect(_on_button_mouse_entered.bind(map_button))
		map_button.mouse_exited.connect(_on_button_mouse_exited.bind(map_button))
	
	_update_button_visual_state()


# Funciones de Interaccion
# ---------------------------------------------------------------------------------------
#region
# Muestra el cuadro de texto con animacion de maquina de escribir
func mostrar_texto_tutorial(texto: String) -> void:
	text_box.visible = true
	text_label.visible_characters = 0
	text_label.text = texto
	var duracion = texto.length() / 30.0
	escribiendo_texto = true
	_last_visible_chars = 0
	if _texto_tween:
		_texto_tween.kill()
	_texto_tween = create_tween()
	_texto_tween.tween_method(_set_visible_chars, 0.0, float(texto.length()), duracion)
	_texto_tween.finished.connect(_completar_texto, CONNECT_ONE_SHOT)
	await texto_completado

func _set_visible_chars(value: float) -> void:
	var int_val = int(value)
	if int_val > _last_visible_chars:
		_last_visible_chars = int_val
		if int_val % 2 == 0:
			var pitch = randf_range(0.95, 1.05)
			SoundManager.play_sfx(SoundManager.SFX_UI_CHARACTER, -1.0, pitch)
	text_label.visible_characters = int_val

# Finaliza la animacion del texto y emite la señal de completado
func _completar_texto() -> void:
	escribiendo_texto = false
	_texto_tween = null
	texto_completado.emit()

# Salta la animacion de escritura mostrando el texto completo inmediatamente
func saltar_texto_tutorial() -> void:
	if not escribiendo_texto or _texto_tween == null:
		return
	if _texto_tween.finished.is_connected(_completar_texto):
		_texto_tween.finished.disconnect(_completar_texto)
	_texto_tween.kill()
	_texto_tween = null
	text_label.visible_characters = text_label.text.length()
	_completar_texto()

# Oculta el cuadro de texto del tutorial
func ocultar_texto_tutorial() -> void:
	text_box.visible = false
	text_label.text = ""

func mostrar_ronda(ronda_actual: int, ronda_max: int) -> void:
	numero_ronda_label.text = str(ronda_actual) + "/" + str(ronda_max)
	rondas_container.visible = true
	animation_player.play("rounds")
	await animation_player.animation_finished
	rondas_container.visible = false

func mostrar_minijuego() -> void:
	minijuego_container.visible = true
	animation_player.play("minijuego")
	await animation_player.animation_finished
	minijuego_container.visible = false

func set_game_manager(manager: Node):
	game_manager = manager
	if game_manager.has_signal("turno_iniciado"):
		game_manager.connect("turno_iniciado", _on_turno_iniciado)
	
	if game_manager.has_method("get_jugadores"):
		var jugadores = game_manager.get_jugadores()
		for jugador in jugadores:
			add_player_to_ui(jugador)

func mostrar() -> void:
	$CanvasLayer.visible = true
	if buttons_container:
		buttons_container.visible = false

func activate_buttons():
	buttons_active = true
	current_selection = ButtonSelection.DICE
	if buttons_container:
		buttons_container.visible = true
	_update_button_visual_state()
	emit_signal("button_selection_changed", current_selection)

func deactivate_buttons():
	buttons_active = false
	if buttons_container:
		buttons_container.visible = false
	_update_button_visual_state()

func navigate_selection(direction: int):
	if not buttons_active or map_view_open:
		return
	
	match direction:
		1:
			current_selection = ButtonSelection.DICE
		-1:
			current_selection = ButtonSelection.MAP
	
	SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
	_update_button_visual_state()
	emit_signal("button_selection_changed", current_selection)

func trigger_selected_button():
	if not buttons_active:
		return false
	
	match current_selection:
		ButtonSelection.DICE:
			_on_dice_button_pressed()
			return true
		ButtonSelection.MAP:
			_on_map_button_pressed()
			return true
	
	return false
#endregion


# Gestion de Jugadores
# ---------------------------------------------------------------------------------------
#region

# Muestra una tarjeta de jugador en cuanto se une al lobby, sin necesitar el nodo instanciado
func add_slot_to_ui(slot_name: String) -> void:
	if not player_info_scene or not player_info_position:
		return
	
	$CanvasLayer.visible = true
	if buttons_container:
		buttons_container.visible = false
	
	var player_info = player_info_scene.instantiate() as PlayerInfoUI
	if not player_info:
		return
	
	player_info_position.add_child(player_info)
	player_info_instances.append(player_info)
	
	var player_data = {
		"jugador": null,
		"player_info": player_info,
		"slot_name": slot_name
	}
	players_data.append(player_data)
	
	player_info.set_battery_label(0)
	player_info.set_chips_label(0)
	player_info.set_position_label(players_data.size())
	
	var regex = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(slot_name)
	var player_number = "1"
	if result:
		player_number = result.get_string()
	
	var player_texture = load("res://Assets/UI/Characters/" + player_number + ".png")
	if player_texture:
		player_info.set_player_image(player_texture)

# Anade un jugador al UI creando su PlayerInfo y configurando las conexiones
func add_player_to_ui(jugador: Node3D):
	# Si ya existe un slot para este jugador, enlazar el nodo sin duplicar la tarjeta
	for data in players_data:
		if data.get("slot_name", "") == jugador.nombre:
			data["jugador"] = jugador
			if jugador.has_signal("stats_updated"):
				jugador.connect("stats_updated", _on_player_stats_updated)
			update_player_info(jugador)
			update_ranking_order()
			return
	
	if not player_info_scene or not player_info_position:
		print("Error: player_info_scene o player_info_position no estan configurados")
		return
	
	var player_info = player_info_scene.instantiate() as PlayerInfoUI
	if not player_info:
		print("Error: No se pudo instanciar PlayerInfoUI")
		return
	
	player_info_position.add_child(player_info)
	player_info_instances.append(player_info)
	
	var player_data = {
		"jugador": jugador,
		"player_info": player_info,
		"slot_name": jugador.nombre
	}
	players_data.append(player_data)
	
	if jugador.has_signal("stats_updated"):
		jugador.connect("stats_updated", _on_player_stats_updated)
	
	update_player_info(jugador)
	update_ranking_order()

func remove_player_from_ui(jugador: Node3D):
	for i in range(players_data.size()):
		if players_data[i].jugador == jugador:
			var player_info = players_data[i].player_info
			player_info.queue_free()
			player_info_instances.erase(player_info)
			players_data.remove_at(i)
			update_ranking_order()
			break

func update_player_info(jugador: Node3D):
	var player_data = null
	for data in players_data:
		if data.jugador == jugador:
			player_data = data
			break
	
	if not player_data:
		return
	
	var player_info = player_data.player_info as PlayerInfoUI
	if not player_info:
		return
	
	player_info.set_battery_label(jugador.baterias)
	player_info.set_chips_label(jugador.microchips)
	
	# Extraer numero del nombre del jugador (formato "Player 1", "Player 2", etc.)
	var player_number = "1" # valor por defecto
	var regex = RegEx.new()
	regex.compile("\\d+") # busca uno o mas digitos
	var result = regex.search(str(jugador.nombre))
	if result:
		player_number = result.get_string()
	
	var player_texture = load("res://Assets/UI/Characters/" + player_number + ".png")
	if player_texture:
		player_info.set_player_image(player_texture)
	
	# Aplicar textura al modelo 3D del jugador
	apply_player_material(jugador, player_number)

func set_player_cards_visible(show_cards: bool) -> void:
	if player_info_position:
		player_info_position.visible = show_cards

func update_all_players_info():
	for data in players_data:
		if data.jugador:
			update_player_info(data.jugador)
	update_ranking_order()

func _compare_player_scores(a, b) -> bool:
	if not a or not b:
		return false

	var jugador_a = a.jugador
	var jugador_b = b.jugador
	if not jugador_a and not jugador_b:
		return false
	if not jugador_a:
		return false
	if not jugador_b:
		return true

	if jugador_a.baterias != jugador_b.baterias:
		return jugador_a.baterias > jugador_b.baterias
	if jugador_a.microchips != jugador_b.microchips:
		return jugador_a.microchips > jugador_b.microchips
	if jugador_a.posicion_casilla != jugador_b.posicion_casilla:
		return jugador_a.posicion_casilla > jugador_b.posicion_casilla

	return false

func calculate_player_score(jugador: Node3D) -> int:
	if not jugador:
		return 0
	return jugador.baterias * 100000 + jugador.microchips * 100 + jugador.posicion_casilla

func get_sorted_players() -> Array:
	var sorted_players = players_data.duplicate()
	sorted_players.sort_custom(Callable(self , "_compare_player_scores"))

	var result: Array = []
	for data in sorted_players:
		if data.jugador:
			result.append(data.jugador)
	return result

func update_ranking_order():
	if players_data.size() <= 1:
		return

	var sorted_players = players_data.duplicate()
	sorted_players.sort_custom(Callable(self , "_compare_player_scores"))
	
	for i in range(sorted_players.size()):
		var player_data = sorted_players[i]
		var player_info = player_data.player_info as PlayerInfoUI
		player_info.set_position_label(i + 1)
		player_info_position.move_child(player_info, i)

func get_player_info_by_jugador(jugador: Node3D) -> PlayerInfoUI:
	for data in players_data:
		if data.jugador == jugador:
			return data.player_info
	return null

func clear_all_players():
	for data in players_data:
		data.player_info.queue_free()
	
	player_info_instances.clear()
	players_data.clear()

func apply_player_material(jugador: Node3D, player_number: String):
	if not jugador.player_mesh:
		return
	
	# Cargar la textura del jugador
	var texture_path = "res://Assets/Jugador/Mannequin Character/Textures/" + player_number + ".png"
	var player_texture = load(texture_path)
	if not player_texture:
		print("Error: No se pudo cargar la textura: ", texture_path)
		return
	
	# Crear material con la textura
	var player_material = StandardMaterial3D.new()
	player_material.albedo_texture = player_texture
	player_material.metallic = 0.0
	player_material.roughness = 0.8
	
	# Buscar todos los MeshInstance3D dentro del player_mesh y aplicar el material
	var mesh_instances = find_mesh_instances(jugador.player_mesh)
	for mesh_instance in mesh_instances:
		mesh_instance.material_override = player_material

func find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node)
	
	for child in node.get_children():
		mesh_instances.append_array(find_mesh_instances(child))
	
	return mesh_instances
#endregion


# Estilos de Botones
# ---------------------------------------------------------------------------------------
#region
func _update_button_visual_state():
	if not dice_button or not map_button:
		return
	
	if not buttons_active:
		_reset_button_styles()
		return
	
	match current_selection:
		ButtonSelection.DICE:
			_highlight_button(dice_button)
			_unhighlight_button(map_button)
		ButtonSelection.MAP:
			_highlight_button(map_button)
			_unhighlight_button(dice_button)

func _highlight_button(button: Button):
	button.modulate = Color(1.0, 1.0, 1.0)
	if button_icon:
		button.icon = button_icon
	
	var original_size: Vector2
	if button == dice_button:
		original_size = dice_button_original_size
	else:
		original_size = map_button_original_size
	
	button.custom_minimum_size = Vector2(original_size.x + 80, original_size.y)
	
func _unhighlight_button(button: Button):
	button.modulate = Color(0.6, 0.6, 0.6)
	button.icon = null
	
	var original_size: Vector2
	if button == dice_button:
		original_size = dice_button_original_size
	else:
		original_size = map_button_original_size
	
	button.custom_minimum_size = original_size

func _reset_button_styles():
	if dice_button:
		dice_button.modulate = Color(1.0, 1.0, 1.0)
		dice_button.scale = Vector2(1.0, 1.0)
		dice_button.icon = null
		dice_button.custom_minimum_size = dice_button_original_size
	if map_button:
		map_button.modulate = Color(1.0, 1.0, 1.0)
		map_button.scale = Vector2(1.0, 1.0)
		map_button.icon = null
		map_button.custom_minimum_size = map_button_original_size

func _on_button_mouse_entered(button: Button) -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
	var other = map_button if button == dice_button else dice_button
	_highlight_button(button)
	_unhighlight_button(other)

func _on_button_mouse_exited(_button: Button) -> void:
	_update_button_visual_state()
#endregion


# Gestion de Señales
# ---------------------------------------------------------------------------------------
#region
func _on_dice_button_pressed():
	SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
	emit_signal("dice_button_pressed")

func _on_map_button_pressed():
	SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
	emit_signal("map_button_pressed")

func is_map_view_open() -> bool:
	return map_view_open

func set_map_view_open(open: bool) -> void:
	map_view_open = open
	if dice_button:
		dice_button.visible = not open
	if map_button:
		map_button.text = tr("KEY_CLOSE") if open else tr("KEY_MAPA")
	if buttons_container:
		buttons_container.visible = true
	if open:
		buttons_active = true
		current_selection = ButtonSelection.MAP
	elif buttons_active:
		current_selection = ButtonSelection.DICE
	_update_button_visual_state()
	emit_signal("button_selection_changed", current_selection)

func _on_turno_iniciado(_jugador):
	activate_buttons()
	update_all_players_info()
func _on_player_stats_updated(jugador: Node3D):
	update_player_info(jugador)
	update_ranking_order()
#endregion
