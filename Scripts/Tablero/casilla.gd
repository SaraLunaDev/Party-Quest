@tool
extends MeshInstance3D

# Tipos de Casilla
enum tipo_casilla {
	NORMAL,
	ROJA,
	MINIJUEGO,
	ESTRELLA
}

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
