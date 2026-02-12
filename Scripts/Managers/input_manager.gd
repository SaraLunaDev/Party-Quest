extends Node
class_name InputManager

signal device_button_pressed(device_id, button_name)
signal device_action(device_id, action_name)

# Mapea teclas/joypad a acciones lógicas
func _map_key(scancode: int) -> String:
	match scancode:
		KEY_SPACE, KEY_ENTER:
			return "ui_accept"
		KEY_S, KEY_ENTER:
			return "start"
		KEY_D, KEY_RIGHT, KEY_UP:
			return "ui_right"
		KEY_A, KEY_LEFT, KEY_DOWN:
			return "ui_left"
		KEY_ESCAPE:
			return "ui_cancel"
		_:
			return ""

func _map_joy(button_index: int) -> String:
	# Estándar: 0 = A / Cross -> aceptar / tirar dado
	# Añadimos L1 (index 4) como 'start' además del botón 9
	match button_index:
		0:
			return "ui_accept"
		1:
			return "ui_cancel"
		6:
			return "start"
		13:
			return "ui_left"
		14:
			return "ui_right"
		_:
			return ""

func _input(event: InputEvent) -> void:
	# Normalizar device id: teclado => "keyboard", mandos => "joypad_<id>"
	var device_key
	if event is InputEventKey:
		device_key = "keyboard"
	elif event.has_method("get_device"):
		device_key = "joypad_%d" % event.get_device()
	else:
		device_key = "unknown"

	# Key events
	if event is InputEventKey and event.pressed:
		var action = _map_key(event.keycode)
		if action != "":
			emit_signal("device_action", device_key, action)
		else:
			# Enviar botón "any" para que el juego lo use como JOIN/SPAWN o detección
			emit_signal("device_button_pressed", device_key, "key_" + str(event.keycode))

	# Joypad button events
	elif event is InputEventJoypadButton and event.pressed:
		var a = _map_joy(event.button_index)
		if a != "":
			emit_signal("device_action", device_key, a)
		else:
			emit_signal("device_button_pressed", device_key, "joy_" + str(event.button_index))

	# Joystick motion / axis (DPAD via axis) - opcional
	elif event is InputEventJoypadMotion:
		# No mapeamos ejes aquí, DPAD normalmente llega como buttons
		pass
