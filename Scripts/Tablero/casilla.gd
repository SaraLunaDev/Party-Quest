@tool
extends MeshInstance3D
class_name Casilla


# ############################################################
# Variables
# ############################################################

# Tipos de Casilla
enum tipo_casilla {NORMAL, ROJA, MINIJUEGO, BATERIA}

# Casillas destino
@export var casillas_destino: Array[Casilla] = []

@export var boton: MeshInstance3D
var is_boton_pressed: bool = false
@export var press_offset: float = 0.4
@onready var boton_initial_y: float = 0.0

func _ready() -> void:
	# Guardar posición inicial del botón y asegurar estado no presionado al inicio
	if boton:
		boton_initial_y = boton.position.y
		boton.position.y = boton_initial_y
		is_boton_pressed = false
	# Si ya hay un jugador encima al iniciar, presionar el botón
	if has_node("PlayerEnterDetector"):
		var area: Area3D = $PlayerEnterDetector
		for b in area.get_overlapping_bodies():
			if b is Jugador:
				press_button()
				break

# Variables de la Casilla
@export var index: int = -1
@export var camino: Path3D
@export var punto_camino: float
@export var direccion: Vector3 = Vector3.ZERO
@export var tipo: tipo_casilla = tipo_casilla.NORMAL:
	set(value):
		tipo = value
		actualizar_apariencia()


# ############################################################
# Apariencia Casilla
# ############################################################	

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

# ############################################################
# Setters y Getters
# ############################################################

func set_index(value: int):
	index = value

func set_tipo(value: tipo_casilla):
	tipo = value
	actualizar_apariencia()

func get_tipo() -> tipo_casilla:
	return tipo

func get_nombre() -> String:
	return tipo_casilla.keys()[tipo].to_lower()

func set_casillas_destino(destinos: Array[Casilla]) -> void:
	casillas_destino = destinos

func get_casillas_destino() -> Array[Casilla]:
	return casillas_destino

func set_camino(value: Path3D) -> void:
	camino = value

func get_camino() -> Path3D:
	return camino

func set_punto_camino(value: float) -> void:
	punto_camino = value

func get_punto_camino() -> float:
	return punto_camino

func set_direccion(value: Vector3) -> void:
	direccion = value

func get_direccion() -> Vector3:
	return direccion


func _on_player_enter_detector_body_entered(body: Node3D) -> void:
	# Cambiar la altura de body a un +1 de la altura que ya tiene, para evitar que se quede "pegado" a la casilla
	var jugador = body as Jugador
	if jugador:
		jugador.set_player_mesh_height_offset(.12)
		# Presionar el botón cuando un jugador entra
		press_button()

func _on_player_out_detector_body_entered(body: Node3D) -> void:
	# Cambiar la altura de body a un -1 de la altura que ya tiene, para evitar que se quede "pegado" a la casilla
	var jugador = body as Jugador
	if jugador:
		jugador.return_player_mesh_height_offset()


func _on_player_enter_detector_body_exited(body: Node3D) -> void:
	var jugador = body as Jugador
	if jugador:
		# Soltar el botón cuando el jugador sale
		release_button()


func press_button(time: float = 0.4) -> void:
	if boton and not is_boton_pressed:
		is_boton_pressed = true
		var t = create_tween()
		t.tween_property(boton, "position:y", boton_initial_y - press_offset, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func release_button(time: float = 0.2) -> void:
	if boton and is_boton_pressed:
		# Verificar si hay algún jugador encima de la casilla
		if has_node("PlayerEnterDetector"):
			var area: Area3D = $PlayerEnterDetector
			for b in area.get_overlapping_bodies():
				if b is Jugador:
					return
		
		is_boton_pressed = false
		var t = create_tween()
		t.tween_property(boton, "position:y", boton_initial_y, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
