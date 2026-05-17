extends Node
class_name InputManager


# Señales
# ---------------------------------------------------------------------------------------
signal device_button_pressed(device_id, button_name)
signal device_action(device_id, action_name)


# Funciones Basicas
# ---------------------------------------------------------------------------------------
#region
# Mapea las teclas del teclado a acciones del juego
func _map_key(scancode: int) -> String:
	match scancode:
		KEY_SPACE, KEY_ENTER:
			return "ui_accept"
		KEY_S, KEY_ENTER:
			return "start"
		KEY_D, KEY_RIGHT:
			return "ui_right"
		KEY_A, KEY_LEFT:
			return "ui_left"
		KEY_UP:
			return "ui_up"
		KEY_DOWN:
			return "ui_down"
		KEY_ESCAPE:
			return "ui_cancel"
		_:
			return ""

# Mapea los botones del mando a acciones del juego
func _map_joy(button_index: int) -> String:
	match button_index:
		0:
			return "ui_accept"
		1:
			return "ui_cancel"
		6:
			return "start"
		11:
			return "ui_up"
		12:
			return "ui_down"
		13:
			return "ui_left"
		14:
			return "ui_right"
		_:
			return ""

# Maneja la entrada del usuario y emite señales correspondientes
func _input(event: InputEvent) -> void:
	var device_key
	if event is InputEventKey:
		device_key = "keyboard"
	elif event.has_method("get_device"):
		device_key = "joypad_%d" % event.get_device()
	else:
		device_key = "unknown"

	
	if event is InputEventKey and event.pressed:
		var action = _map_key(event.keycode)
		if action != "":
			emit_signal("device_action", device_key, action)
		else:
			emit_signal("device_button_pressed", device_key, "key_" + str(event.keycode))

	
	elif event is InputEventJoypadButton and event.pressed:
		var a = _map_joy(event.button_index)
		if a != "":
			emit_signal("device_action", device_key, a)
		else:
			emit_signal("device_button_pressed", device_key, "joy_" + str(event.button_index))

	
	elif event is InputEventJoypadMotion:
		pass
#endregion