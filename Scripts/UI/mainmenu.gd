extends Control
class_name MainMenuUI


# Variables
# ---------------------------------------------------------------------------------------
@export var opciones_container: MarginContainer
@export var opciones_button: Button
@export var comenzar_button: Button
@export var salir_button: Button
@export var idioma_button: Button
@export var volume_slider: HSlider
@export var sfx_slider: HSlider
@export var button_icon: Texture2D
@export var game_manager: MainGameManager
@export var conectar_tutorial: ConectarTutorialUI

var last_focused: Control = null
var input_manager: Node = null
var active_controls: Array[Control] = []


# Funciones Basicas
# ---------------------------------------------------------------------------------------
#region
func _ready() -> void:
	if GameData.tiene_estado_guardado:
		_hide_mainmenu()
		return
	if opciones_container:
		opciones_container.visible = false
	_update_opciones_button_text()
	_update_idioma_button_text()
	SoundManager.play_music(SoundManager.MUSIC_MAIN_MENU)

	for button in [comenzar_button, opciones_button, salir_button, idioma_button]:
		if button:
			button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
			button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
			button.focus_mode = Control.FOCUS_NONE
	if volume_slider:
		volume_slider.value = SoundManager.music_volume
		volume_slider.mouse_entered.connect(_on_slider_mouse_entered)
		volume_slider.mouse_exited.connect(_on_slider_mouse_exited)
		volume_slider.value_changed.connect(SoundManager.set_music_volume)
	if sfx_slider:
		sfx_slider.value = SoundManager.sfx_volume
		sfx_slider.mouse_entered.connect(_on_sfx_slider_mouse_entered)
		sfx_slider.mouse_exited.connect(_on_sfx_slider_mouse_exited)
		sfx_slider.value_changed.connect(SoundManager.set_sfx_volume)

	_rebuild_active_controls()

	input_manager = preload("res://Scripts/Managers/input_manager.gd").new()
	add_child(input_manager)
	input_manager.connect("device_action", Callable(self , "_on_device_action"))

func _update_opciones_button_text() -> void:
	if not opciones_button:
		return

	if opciones_container and opciones_container.visible:
		opciones_button.text = "KEY_CLOSE"
	else:
		opciones_button.text = "KEY_OPTIONS"
#endregion


# Funciones de Interaccion
# ---------------------------------------------------------------------------------------
#region
func _hide_mainmenu() -> void:
	$CanvasLayer.visible = false

func ocultar() -> void:
	$CanvasLayer.visible = false

func _on_comenzar_pressed() -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
	_hide_mainmenu()
	if conectar_tutorial:
		conectar_tutorial.mostrar()
	if game_manager:
		game_manager.lobby_open = true

func _on_opciones_pressed() -> void:
	if opciones_container:
		opciones_container.visible = not opciones_container.visible
		if opciones_container.visible:
			SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
		else:
			SoundManager.play_sfx(SoundManager.SFX_UI_BACK)
		_update_opciones_button_text()
		_rebuild_active_controls()

func _on_salir_pressed() -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
	get_tree().quit()


func _on_idioma_pressed() -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_CONFIRM)
	var current_locale = TranslationServer.get_locale()
	if current_locale == "es":
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale("es")
	_update_idioma_button_text()

func _update_idioma_button_text() -> void:
	if not idioma_button:
		return
	if TranslationServer.get_locale() == "es":
		idioma_button.text = tr("KEY_ESP")
	else:
		idioma_button.text = tr("KEY_ENG")
#endregion


# Estilos de Botones
# ---------------------------------------------------------------------------------------
#region
func _rebuild_active_controls() -> void:
	active_controls.clear()
	for c in [comenzar_button, opciones_button] as Array[Control]:
		if c:
			active_controls.append(c)
	if opciones_container and opciones_container.visible:
		for c in [idioma_button, volume_slider, sfx_slider] as Array[Control]:
			if c:
				active_controls.append(c)
	if salir_button:
		active_controls.append(salir_button)
	if last_focused == null or not active_controls.has(last_focused):
		last_focused = active_controls[0] if not active_controls.is_empty() else null
	if last_focused:
		_highlight_control(last_focused)

func _on_button_focus_entered(_button: Button) -> void:
	pass

func _on_button_focus_exited(_button: Button) -> void:
	pass

func _on_button_mouse_entered(button: Button) -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
	last_focused = button
	_highlight_control(button)

func _on_button_mouse_exited(_button: Button) -> void:
	_highlight_control(last_focused)

func _on_slider_mouse_entered() -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
	last_focused = volume_slider
	_highlight_control(volume_slider)

func _on_slider_mouse_exited() -> void:
	_highlight_control(last_focused)

func _on_sfx_slider_mouse_entered() -> void:
	SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
	last_focused = sfx_slider
	_highlight_control(sfx_slider)

func _on_sfx_slider_mouse_exited() -> void:
	_highlight_control(last_focused)

func _highlight_control(control: Control) -> void:
	for c in ([comenzar_button, opciones_button, salir_button, idioma_button, volume_slider, sfx_slider] as Array[Control]):
		if not c:
			continue
		if c == control:
			c.modulate = Color(1.0, 1.0, 1.0)
			if c is Button and button_icon:
				(c as Button).icon = button_icon
		else:
			c.modulate = Color(0.6, 0.6, 0.6)
			if c is Button:
				(c as Button).icon = null
#endregion


# Gestion de Señales
# ---------------------------------------------------------------------------------------
#region
func _on_device_action(_device_id, action_name: String) -> void:
	if not $CanvasLayer.visible:
		return
	if active_controls.is_empty():
		return
	var idx = active_controls.find(last_focused)
	if last_focused == volume_slider or last_focused == sfx_slider:
		var slider = last_focused as HSlider
		match action_name:
			"ui_right":
				slider.value = clamp(slider.value + slider.step, slider.min_value, slider.max_value)
				SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
			"ui_left":
				slider.value = clamp(slider.value - slider.step, slider.min_value, slider.max_value)
				SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
			"ui_up":
				idx = (idx - 1 + active_controls.size()) % active_controls.size()
				last_focused = active_controls[idx]
				SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
				_highlight_control(last_focused)
			"ui_down", "ui_accept":
				idx = (idx + 1) % active_controls.size()
				last_focused = active_controls[idx]
				SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
				_highlight_control(last_focused)
		return
	match action_name:
		"ui_up":
			idx = (idx - 1 + active_controls.size()) % active_controls.size()
			last_focused = active_controls[idx]
			SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
			_highlight_control(last_focused)
		"ui_down":
			idx = (idx + 1) % active_controls.size()
			last_focused = active_controls[idx]
			SoundManager.play_sfx(SoundManager.SFX_UI_HOVER)
			_highlight_control(last_focused)
		"ui_accept":
			if last_focused is Button:
				(last_focused as Button).pressed.emit()
#endregion
