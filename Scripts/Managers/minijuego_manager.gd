extends Node


# Variables
# ---------------------------------------------------------------------------------------
var minijuegos: Array[String] = [
	"res://Scenes/Minijuegos/Palo/palo.tscn",
	"res://Scenes/Minijuegos/Globo/globo.tscn",
]


# Funciones
# ---------------------------------------------------------------------------------------
func elegir_aleatorio() -> String:
	if minijuegos.size() == 0:
		return ""
	if minijuegos.size() == 1:
		return minijuegos[0]

	var opciones = minijuegos.duplicate()
	if GameData.ultimo_minijuego != "":
		opciones = opciones.filter(func(path): return path != GameData.ultimo_minijuego)
	if opciones.size() == 0:
		return minijuegos[randi() % minijuegos.size()]

	return opciones[randi() % opciones.size()]
