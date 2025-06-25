@tool
extends Path3D

# Numero de Casillas en el Path3D
@export var num_casillas: int = 30
# Escena de la Casilla a Instanciar en el Path3D
@export var casilla_escena: PackedScene

@export_tool_button("Crear Casillas")
var c: Callable = func():
	_crear_casillas()

# Limpia las Casillas del Path3D
func _limpiar_casillas():
	for child in get_children():
		if child is PathFollow3D:
			remove_child(child)
			child.queue_free()

# Crea las Casillas en el Path3D
func _crear_casillas():
	# Comprueba que haya una escena Casilla valida
	if casilla_escena == null:
		push_error("No hay una escena Casilla establecida")
		return
	
	# Limpia las Casillas del Path3D
	_limpiar_casillas()
	
	# Bucle que recorre todas las casillas de num_casillas
	for i in num_casillas:
		# Crea un PathFollow3D
		var pathFollow = PathFollow3D.new()
		pathFollow.name = "PF3D_Casilla_" + str(i)
		
		# Instancia la Casilla
		var casilla = casilla_escena.instantiate()
		# Añadimos la Casilla como hija del PathFollow3D
		pathFollow.add_child(casilla)
		
		# Añadimos el PathFollow3D como hijo del Path3D
		add_child(pathFollow)
		
		# Establecer un owner para ver y mantener los nodos en el editor
		pathFollow.owner = get_tree().edited_scene_root
		casilla.owner = get_tree().edited_scene_root
		
		# Añade una posicion equidistante entre el numero de Casillas
		pathFollow.progress_ratio = float(i) / float(num_casillas - 1)
