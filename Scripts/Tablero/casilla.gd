@tool
extends MeshInstance3D

# Tipos de Casilla
enum tipo_casilla {NORMAL,ROJA,MINIJUEGO,CORONA}

# Numero que Representa la casilla en el Tablero
@export var index: int = -1
@export var light: OmniLight3D

# Selector de Tipo
@export var tipo: tipo_casilla = tipo_casilla.NORMAL:
	set(value):
		tipo = value
		actualizar_apariencia()

# Actualiza el Material de la Casilla en base a su Tipo
func actualizar_apariencia():
	# Pillo el nombre en base al enum
	var nombre_tipo: String = tipo_casilla.keys()[tipo].to_lower()
	# Obtengo el material usando el nombre de antes
	var ruta = "res://Materials/Tablero/Casillas/%s.tres" % nombre_tipo
	# Lo creo en base a la ruta de antes
	var mat: Material = load(ruta)
	# Lo aplico en la parte Override Material
	set_surface_override_material(0, mat)

# Establece el idex de la Casilla en el Tablero
func set_index(value: int):
	index = value

# Establece el tipo de la Casilla en el Tablero
func set_tipo(value: tipo_casilla):
	tipo = value
<<<<<<< HEAD

func set_casillas_destino(destinos: Array[Casilla]) -> void:
	casillas_destino = destinos

func get_casillas_destino() -> Array[Casilla]:
	return casillas_destino

func enable_emission():
	if light:
		var mat: Material = get_surface_override_material(0)
		if mat is StandardMaterial3D:
			light.light_color = mat.albedo_color
			light.light_energy = 1.0
			light.visible = true

func disable_emission():
	if light:
		light.visible = false
=======
>>>>>>> parent of 3e2fa94 (Commit antes de Cambiar el GameManager)
