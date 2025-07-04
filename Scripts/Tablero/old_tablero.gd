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
# Rango de Casillas Rojas
@export_range(0, 100, 1, "suffix:%") var porcentaje_rojas: int = 50
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

		# Añadir modo de rotacion
		pathFollow.rotation_mode = PathFollow3D.ROTATION_XY
		
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
	var total_rojas = int(num_casillas * porcentaje_rojas / 100.0)
	var indices = range(num_casillas)
	indices.shuffle()
	
	# Primero todas las rojas
	for i in range(total_rojas):
		if i >= indices.size():
			break
		var idx = indices[i]
		var pf = get_child(idx)
		var casilla = pf.get_child(0)
		casilla.set_tipo(casilla.tipo_casilla.ROJA)
	
	# Luego ajustar las seguidas
	for i in range(num_casillas):
		var pf = get_child(i)
		var casilla = pf.get_child(0)
		if casilla.tipo == casilla.tipo_casilla.ROJA:
			# Si hay demasiadas seguidas
			var seguidas = 1
			for j in range(i - 1, max(-1, i - max_rojas_seguidas - 1), -1):
				if get_child(j).get_child(0).tipo == casilla.tipo_casilla.ROJA:
					seguidas += 1
				else:
					break
			if seguidas > max_rojas_seguidas:
				# Cambiar excedentes a normales
				for k in range(i - seguidas + max_rojas_seguidas, i):
					get_child(k).get_child(0).set_tipo(casilla.tipo_casilla.NORMAL)

	# El resto son normales por si acaso
	for i in range(num_casillas):
		var casilla = get_child(i).get_child(0)
		if casilla.tipo != casilla.tipo_casilla.ROJA && casilla.tipo != casilla.tipo_casilla.MINIJUEGO:
			casilla.set_tipo(casilla.tipo_casilla.NORMAL)
	
	# Aplicar el porcentaje de Minijuegos
	var total_minijuegos = max(1, int(float(num_casillas) * float(porcentaje_minijuegos) / 100.0))
	var seccion_size = float(num_casillas) / float(total_minijuegos)
	var posiciones_minijuegos = []

	# Posiciones equiespaciadas con offset aleatorio
	for i in range(total_minijuegos):
		var pos_base = (i * seccion_size) + (seccion_size * 0.5)
		var offset = rng.randf_range(-seccion_size * 0.4, seccion_size * 0.4)
		var pos_final = int(clamp(pos_base + offset, 0, num_casillas - 1))
		posiciones_minijuegos.append(pos_final)

	# Ordenar y asegurar espaciado minimo
	posiciones_minijuegos.sort()
	for i in range(posiciones_minijuegos.size() - 1, 0, -1):
		var espaciado_minimo = num_casillas / (total_minijuegos * 2)
		if posiciones_minijuegos[i] - posiciones_minijuegos[i - 1] < espaciado_minimo:
			posiciones_minijuegos[i] = min(posiciones_minijuegos[i - 1] + espaciado_minimo, num_casillas - 1)

	# Aplicar los minijuegos verificando adyacentes
	for pos in posiciones_minijuegos:
		var intentos = 0
		var idx = pos
		var colocada = false
		while intentos < 5 and not colocada:
			var pf = get_child(idx)
			var casilla = pf.get_child(0)
			if casilla.tipo != casilla.tipo_casilla.CORONA:
				var valida = true
				# Verificar adyacentes
				for j in range(max(0, idx - 1), min(num_casillas - 1, idx + 1) + 1):
					var c_ady = get_child(j).get_child(0)
					if c_ady.tipo == c_ady.tipo_casilla.MINIJUEGO:
						valida = false
						break
				if valida:
					casilla.set_tipo(casilla.tipo_casilla.MINIJUEGO)
					colocada = true
				else:
					# Buscar alternativa cercana
					idx = (idx + rng.randi_range(1, 3)) % num_casillas
					intentos += 1
			else:
				idx = (idx + 1) % num_casillas
				intentos += 1
