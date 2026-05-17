extends Control
class_name ConectarTutorialUI

var _texto_base: String = ""

func mostrar() -> void:
	$CanvasLayer.visible = true
	_texto_base = TranslationServer.translate("KEY_JOIN")
	$CanvasLayer/MarginContainer/Label.text = _texto_base

func ocultar() -> void:
	$CanvasLayer.visible = false

func mostrar_hint_inicio(is_keyboard: bool) -> void:
	var clave = "KEY_JOIN_START_KEYBOARD" if is_keyboard else "KEY_JOIN_START_GAMEPAD"
	$CanvasLayer/MarginContainer/Label.text = _texto_base + "\n\n" + TranslationServer.translate(clave)

func ocultar_hint_inicio() -> void:
	$CanvasLayer/MarginContainer/Label.text = _texto_base
