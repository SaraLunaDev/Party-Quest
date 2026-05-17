extends Node


# Variables
# ---------------------------------------------------------------------------------------
var jugadores_data: Array = []
var jugador_actual_index: int = 0
var rondas_completadas: int = 0
var limite_rondas: int = 5

var tiene_estado_guardado: bool = false
var omitir_incremento_ronda: bool = false
var escena_tablero: String = "res://Scenes/Main/Juego.tscn"
var resultados_minijuego: Array = []
var ultimo_minijuego: String = ""
var tablero_casillas: Array = []


# Funciones
# ---------------------------------------------------------------------------------------
func guardar_estado(jugadores: Array, tablero: Node, idx_actual: int, rondas: int, max_rondas: int) -> void:
	jugadores_data.clear()
	for j in jugadores:
		jugadores_data.append({
			"nombre": j.nombre,
			"color": j.color,
			"device_id": j.device_id,
			"microchips": j.get_microchips(),
			"baterias": j.get_baterias(),
			"posicion_casilla": j.posicion_casilla
		})

	tablero_casillas.clear()
	if tablero != null and tablero.has_method("obtener_casillas_del_tablero"):
		for casilla in tablero.obtener_casillas_del_tablero():
			tablero_casillas.append({
				"index": casilla.index,
				"tipo": casilla.get_tipo()
			})

	jugador_actual_index = idx_actual
	rondas_completadas = rondas
	limite_rondas = max_rondas
	tiene_estado_guardado = true

func limpiar_resultados() -> void:
	resultados_minijuego.clear()
