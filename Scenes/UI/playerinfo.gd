extends MarginContainer
class_name PlayerInfoUI

# Variables
# ---------------------------------------------------------------------------------------
@export var battery_label: Label
@export var chips_label: Label
@export var player_image: TextureRect
@export var position_label: Label


# Setters y Getters
# ---------------------------------------------------------------------------------------
# Numero de baterias que tiene el jugador
func set_battery_label(label: int):
	battery_label.text = str(label)

# Numero de chips que tiene el jugador
func set_chips_label(label: int):
	chips_label.text = str(label)

# La imagen del jugador elegido (1.png, 2.png, 3.png o 4.png)
func set_player_image(texture: Texture2D):
	player_image.texture = texture

# Posicion en ranking calculando baterias y casillas
func set_position_label(label: int):
	position_label.text = str(label)
