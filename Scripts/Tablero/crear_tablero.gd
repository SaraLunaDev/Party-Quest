@tool
extends Path3D

# Numero de Casillas en el Path3D
@export var num_casillas: int = 30
@export var max_rojas_seguidas: int = 3
# Escena de la Casilla a Instanciar en el Path3D
@export var casilla_escena: PackedScene
# Array de indices
@export var indices_casillas: Array
var rng = RandomNumberGenerator.new()
# Rango de Casillas Multijugador
@export_range(0, 100, 1, "suffix:%") var porcentaje_minijuegos: int = 10

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
		push_error("😠 No hay una escena Casilla establecida")
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
		# Aplica su Index de Posicion
		casilla.set_index(i)
		# Añadimos la Casilla como hija del PathFollow3D
		pathFollow.add_child(casilla)
		
		# Añadimos el PathFollow3D como hijo del Path3D
		add_child(pathFollow)
		
		# Establecer un owner para ver y mantener los nodos en el editor
		pathFollow.owner = get_tree().edited_scene_root
		casilla.owner = get_tree().edited_scene_root
		
		# Añade una posicion equidistante entre el numero de Casillas
		pathFollow.progress_ratio = float(i) / float(num_casillas)
	
	# Aplicar Tipo a cada Casilla
	_cambiar_tipo_casillas()
	

# Cambia el tipo de las Casillas existentes
func _cambiar_tipo_casillas():
	var rojas_colocadas = 0
	var rojas_seguidas = 0
	var total_rojas = int(num_casillas / 2)
	
	# Bucle que no para hasta tener el mismo numero de casillas Rojas que Normales
	while rojas_colocadas != total_rojas:
		rojas_seguidas = 0
		rojas_colocadas = 0
		
		# Bucle para leer todas las Casillas
		for pf in get_children():
			if pf is PathFollow3D:
				var casilla = pf.get_child(0)
				
				# Limitar el numero de Rojas
				if rojas_colocadas >= total_rojas:
					casilla.set_tipo(casilla.tipo_casilla.NORMAL)
					rojas_seguidas = 0
					continue
				
				# Limitar el numero de Rojas seguidas
				if rojas_seguidas >= max_rojas_seguidas:
					casilla.set_tipo(casilla.tipo_casilla.NORMAL)
					rojas_seguidas = 0
					continue
				
				var es_roja = randf() < 0.5
				if es_roja:
					casilla.set_tipo(casilla.tipo_casilla.ROJA)
					rojas_colocadas += 1
					rojas_seguidas += 1
				else:
					casilla.set_tipo(casilla.tipo_casilla.NORMAL)
					rojas_seguidas = 0
	
	# Randomizar la posicion de la Corona
	var casilla_corona = (rng.randi_range(0, num_casillas - 1))
	# Bucle para buscar la Casilla en cuestion y cambiar su tipo
	for pf in get_children():
		if pf is PathFollow3D:
			var casilla = pf.get_child(0)
			if casilla.index == casilla_corona:
				casilla.set_tipo(casilla.tipo_casilla.CORONA)
	
	# Aplicar un 10% de Casillas Minijuego
	var total_minijuegos = max(1, int(num_casillas * porcentaje_minijuegos / 100))
	var casillas_minijuego = []
	
	# Bucle para Sustituir Casillas Azules y Rojas por Minijuegos
	var espaciado = float(num_casillas) / float(total_minijuegos + 1)
	for i in range(total_minijuegos):
		var pos_ideal = int((i + 1) * espaciado)
		
		for offset in range(0, 5):
			var idx = pos_ideal + (offset if i%2==0 else -offset)
			idx = clampi(idx, 0, num_casillas - 1)
			
			var pf = get_child(idx)
			var casilla = pf.get_child(0)
			
			if casilla.tipo != casilla.tipo_casilla.CORONA:
				var valida = true
				for j in range(max(0, idx - 1), min(num_casillas - 1, idx + 1) + 1):
					var c_ady = get_child(j).get_child(0)
					if c_ady.tipo == c_ady.tipo_casilla.MINIJUEGO:
						valida = false
						break
				if valida:
					casilla.set_tipo(casilla.tipo_casilla.MINIJUEGO)
					casillas_minijuego.append(idx)
					break
