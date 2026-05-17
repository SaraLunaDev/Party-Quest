@tool
extends MeshInstance3D
class_name Casilla

# Variables
# ---------------------------------------------------------------------------------------
enum tipo_casilla {NORMAL, ROJA, MINIJUEGO, BATERIA}
enum tipo_movimiento {CAMINAR, SALTAR}

@export var casillas_destino: Array[Casilla] = []

@export var boton: MeshInstance3D
var is_boton_pressed: bool = false
var tiene_jugador_almacenado: bool = false
@export var press_offset: float = 0.4
@export var trampilla_offset: float = 1.2
@onready var boton_initial_y: float = 0.0
@export var index: int = -1
@export var camino: Path3D
@export var punto_camino: int
@export var direccion: Vector3 = Vector3.ZERO
@export var tipo: tipo_casilla = tipo_casilla.NORMAL:
	set(value):
		tipo = value
		actualizar_apariencia()

@export var movimiento: tipo_movimiento = tipo_movimiento.CAMINAR

# Funciones Basicas
# ---------------------------------------------------------------------------------------
func _ready() -> void:
	if boton:
		boton_initial_y = boton.position.y
		boton.position.y = boton_initial_y
		is_boton_pressed = false
	
	if has_node("PlayerEnterDetector"):
		var area: Area3D = $PlayerEnterDetector
		for b in area.get_overlapping_bodies():
			if b is Jugador:
				press_button()
				break

# Gestion de la Casilla
# ---------------------------------------------------------------------------------------
func actualizar_apariencia():
	if tipo == Casilla.tipo_casilla.BATERIA:
		press_button(0.2)
		await get_tree().create_timer(0.3).timeout
	
	var nombre_tipo: String = tipo_casilla.keys()[tipo].to_lower()
	var ruta = "res://Materials/Tablero/Casillas/%s.tres" % nombre_tipo
	var mat: Material = load(ruta)
	if boton:
		boton.set_surface_override_material(0, mat)
	
	if tipo == Casilla.tipo_casilla.BATERIA:
		release_button()
		await get_tree().create_timer(0.2).timeout


# Setters y Getters
# ---------------------------------------------------------------------------------------
#region
func set_index(value: int):
	index = value

func set_tipo(value: tipo_casilla):
	tipo = value
	actualizar_apariencia()

func get_tipo() -> tipo_casilla:
	return tipo

func get_nombre() -> String:
	return tipo_casilla.keys()[tipo].to_lower()

func set_movimiento(value: tipo_movimiento) -> void:
	movimiento = value

func get_movimiento() -> tipo_movimiento:
	return movimiento

func get_nombre_movimiento() -> String:
	return tipo_movimiento.keys()[movimiento].to_lower()

func set_casillas_destino(destinos: Array[Casilla]) -> void:
	casillas_destino = destinos

func get_casillas_destino() -> Array[Casilla]:
	return casillas_destino

func set_camino(value: Path3D) -> void:
	camino = value

func get_camino() -> Path3D:
	return camino

func set_punto_camino(value: int) -> void:
	punto_camino = value

func get_punto_camino() -> int:
	return punto_camino

func set_direccion(value: Vector3) -> void:
	direccion = value

func get_direccion() -> Vector3:
	return direccion
#endregion


# Funciones de Colision
# ---------------------------------------------------------------------------------------
#region
func _on_player_enter_detector_body_entered(body: Node3D) -> void:
	var jugador = body as Jugador
	if jugador:
		jugador.set_player_mesh_height_offset(0.12)
		
		press_button()

func _on_player_out_detector_body_entered(body: Node3D) -> void:
	var jugador = body as Jugador
	if jugador:
		jugador.return_player_mesh_height_offset()

func _on_player_enter_detector_body_exited(body: Node3D) -> void:
	var jugador = body as Jugador
	if jugador:
		release_button()

func abrir_trampilla() -> void:
	if boton:
		SoundManager.play_sfx(SoundManager.SFX_TRAMPILLA_ABRIR)
		var t = create_tween()
		t.tween_property(boton, "position:y", boton_initial_y - trampilla_offset, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished

func cerrar_trampilla(con_jugador: bool = false) -> void:
	if boton:
		SoundManager.play_sfx(SoundManager.SFX_TRAMPILLA_CERRAR)
		var target_y = boton_initial_y - press_offset if con_jugador else boton_initial_y
		var t = create_tween()
		t.tween_property(boton, "position:y", target_y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished
		if con_jugador:
			is_boton_pressed = true
		else:
			is_boton_pressed = false

func press_button(time: float = 0.4) -> void:
	if boton and not is_boton_pressed:
		is_boton_pressed = true
		SoundManager.play_sfx(SoundManager.SFX_CASILLA_PRESIONAR)
		var t = create_tween()
		t.tween_property(boton, "position:y", boton_initial_y - press_offset, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func release_button(time: float = 0.2) -> void:
	if boton and is_boton_pressed:
		if tiene_jugador_almacenado:
			return
		if has_node("PlayerEnterDetector"):
			var area: Area3D = $PlayerEnterDetector
			for b in area.get_overlapping_bodies():
				if b is Jugador:
					return
		
		is_boton_pressed = false
		SoundManager.play_sfx(SoundManager.SFX_CASILLA_SOLTAR)
		var t = create_tween()
		t.tween_property(boton, "position:y", boton_initial_y, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
#endregion