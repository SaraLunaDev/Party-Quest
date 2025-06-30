extends Node3D

# Variables
var nombre: String
var color: Color
var monedas: int = 10
var coronas: int = 0
var posicion_tablero: int = 0
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
var pf: PathFollow3D

# Iniciar Jugador con nombre y color
func _init(p_nombre: String = "", p_color: Color = Color.WHITE) -> void:
	nombre = p_nombre
	color = p_color

# Configurar Jugador después de la instanciación
func configurar(p_nombre: String, p_color: Color) -> void:
	nombre = p_nombre
	color = p_color
	# Actualizar color si ya está listo
	if mesh_instance_3d:
		actualizar_color()

# Actualizar su informacion cuando este Instanciado
func _ready() -> void:
	actualizar_color()

# Cambiar el color de su Mesh
func actualizar_color():
	if mesh_instance_3d:
		var nuevo_material = StandardMaterial3D.new()
		nuevo_material.albedo_color = color
		mesh_instance_3d.set_surface_override_material(0, nuevo_material)

# Establecer Monedas
func establecer_monedas(cantidad: int):
	monedas = max(0, monedas + cantidad)
	print("🫢 ", nombre, " ahora tiene ", monedas, " monedas.")

# Establecer Coronas
func establecer_corona(cantidad: int):
	coronas += cantidad
	print("🫢 ", nombre, " ahora tiene ", coronas, " coronas.")
	# TODO: Debe perder 20 monedas para poder obtener la corona

# Debug para mostrar la Info del Jugador
func obtener_info() -> String:
	var corona_texto = ""
	if coronas > 0:
		corona_texto = " " + str(coronas) + "👑"
	return "❔" + nombre + corona_texto + " - Casilla: " + str(posicion_tablero) + " - Monedas: " + str(monedas)
