@tool
extends MeshInstance3D
class_name Casilla

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Variables
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦	

# Tipos de Casilla
enum tipo_casilla {NORMAL, ROJA, MINIJUEGO, CORONA}

# Casillas destino
@export var casillas_destino: Array[Casilla] = []

# Variables de la Casilla
@export var index: int = -1
@export var camino: Path3D
@export var punto_camino: float
@onready var luz: OmniLight3D = $OmniLight3D
@export var tipo: tipo_casilla = tipo_casilla.NORMAL:
	set(value):
		tipo = value
		actualizar_apariencia()

# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Apariencia Casilla
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦		

func actualizar_apariencia():
	var nombre_tipo: String = tipo_casilla.keys()[tipo].to_lower()
	var ruta = "res://Materials/Tablero/Casillas/%s.tres" % nombre_tipo
	var mat: Material = load(ruta)
	set_surface_override_material(0, mat)

func encender_luz():
	if luz:
		luz.visible = true
		var material: Material = get_surface_override_material(0)
		luz.light_color = material.albedo_color

func apagar_luz():
	if luz:
		luz.visible = false
		
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦
# Setters y Getters
# ✦•················•⋅ ∙ ∘ ☽ ☆ ☾ ∘ ⋅ ⋅•················•✦

func set_index(value: int):
	index = value

func set_tipo(value: tipo_casilla):
	tipo = value

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
