@tool
extends Node3D


# ############################################################
# Variables
# ############################################################	

@export var caminos: Array[Path3D]
@export var casilla_escena: PackedScene

# Si es true, las casillas instanciadas rotarán siguiendo la trayectoria
@export var rotar_seguir_trayectoria: bool = false

@export var numero_casillas: int
var asociaciones_puntos: Dictionary = {}
var posiciones_anteriores: Dictionary = {}

@export_category("Casillas")
@export var instanciar_casillas: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_instanciar_casillas()
		instanciar_casillas = false

@export var cantidad_casillas_roja_juntas: int = 2:
	set(value):
		cantidad_casillas_roja_juntas = max(1, value)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(_obtener_casillas_del_tablero())

@export var cantidad_casillas_entre_rojas: int = 2:
	set(value):
		cantidad_casillas_entre_rojas = max(0, value)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(_obtener_casillas_del_tablero())
@export var porcentaje_casillas_minijuego: float = 0.1:
	set(value):
		porcentaje_casillas_minijuego = clamp(value, 0.0, 1.0)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(_obtener_casillas_del_tablero())

@export var casillas_inicio_prohibidas_minijuego: int = 6:
	set(value):
		casillas_inicio_prohibidas_minijuego = max(0, value)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(_obtener_casillas_del_tablero())

@export_category("Puntos de Union")
@export var fijar_puntos_de_union: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_asignar_puntos_de_union()
		fijar_puntos_de_union = false

func _ready():
	if Engine.is_editor_hint():
		for camino in caminos:
			if not camino.is_connected("curve_changed", Callable(self , "_actualizar_posicion_casillas")):
				camino.connect("curve_changed", Callable(self , "_actualizar_posicion_casillas"))
			if not camino.is_connected("curve_changed", Callable(self , "_sincronizar_puntos_de_union")):
				camino.connect("curve_changed", Callable(self , "_sincronizar_puntos_de_union"))
		_asignar_puntos_de_union()


# ############################################################
# Gestion de Casillas
# ############################################################

func _limpiar_casillas() -> void:
	if not Engine.is_editor_hint():
		return
	for camino in caminos:
		for child in camino.get_children():
			if child.name.begins_with("Casilla_"):
				camino.remove_child(child)
				child.queue_free()

func _instanciar_casillas() -> Array[Vector3]:
	if not Engine.is_editor_hint():
		return []
	_limpiar_casillas()
	numero_casillas = 0
	var puntos: Array[Vector3] = []
	var todas_las_casillas: Array[Casilla] = []
	
	# Crear todas las casillas
	for camino in caminos:
		var curva = camino.get_curve()
		var point_count = curva.get_point_count()
		var is_abierto = not curva.is_closed()
		var start_idx = 1 if is_abierto and point_count > 2 else 0
		var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count
		
		for i in range(start_idx, end_idx):
			var punto = curva.get_point_position(i)
			puntos.append(punto)
			
			# Crear casilla directamente como hijo del Path3D
			var casilla = casilla_escena.instantiate()
			casilla.name = "Casilla_" + str(numero_casillas)
			camino.add_child(casilla)
			casilla.owner = get_tree().edited_scene_root
			casilla.set_index(numero_casillas)
			casilla.set_punto_camino(i)
			casilla.set_camino(camino)
			
			# Posicionar la casilla en el punto de la curva
			casilla.global_position = camino.global_position + punto

			# Aplicar rotacion siguiendo la trayectoria si está habilitado
			if rotar_seguir_trayectoria:
				var prev_idx = i - 1 if i - 1 >= 0 else (point_count - 1 if curva.is_closed() else i)
				var next_idx = i + 1 if i + 1 < point_count else (0 if curva.is_closed() else i)
				var prev_p = curva.get_point_position(prev_idx)
				var next_p = curva.get_point_position(next_idx)
				var direccion = (next_p - prev_p)
				if direccion.length() > 0.0001:
					direccion = direccion.normalized()
					casilla.look_at(casilla.global_position + direccion, Vector3.UP)
			
			todas_las_casillas.append(casilla)
			numero_casillas += 1
	
	# Establecer tipo de casillas
	_establecer_tipo_casillas(todas_las_casillas)
	
	# Configurar conexiones entre casillas
	_configurar_conexiones_casillas(todas_las_casillas)
	return puntos

func _obtener_casillas_del_tablero() -> Array[Casilla]:
	var casillas: Array[Casilla] = []
	for camino in caminos:
		for child in camino.get_children():
			if child is Casilla:
				casillas.append(child as Casilla)
	return casillas

func obtener_casillas_del_tablero() -> Array[Casilla]:
	return _obtener_casillas_del_tablero()

func _establecer_tipo_casillas(casillas: Array[Casilla]) -> void:
	if not Engine.is_editor_hint():
		return
	if casillas.size() == 0:
		return

	var total = casillas.size()
	var num_minijuegos = int(round(total * porcentaje_casillas_minijuego))

	# Poner todas las casillas en NORMAL
	for casilla in casillas:
		casilla.set_tipo(casilla.tipo_casilla.NORMAL)

	# Asignar casillas ROJAS
	var i = 0
	while i < total:
		# Asignar grupo ROJO
		for j in range(cantidad_casillas_roja_juntas):
			var idx = i + j
			if idx >= total:
				break
			casillas[idx].set_tipo(casillas[idx].tipo_casilla.ROJA)

		# Avanzar y aplicar separacion
		i += cantidad_casillas_roja_juntas
		i += cantidad_casillas_entre_rojas

	# Contar rojas asignadas
	var rojas_asignadas = 0
	for casilla in casillas:
		if casilla.tipo == casilla.tipo_casilla.ROJA:
			rojas_asignadas += 1

	# Evitar solapamiento con minijuegos
	if rojas_asignadas + num_minijuegos > total:
		num_minijuegos = max(0, total - rojas_asignadas)

	# Asignar casillas de minijuego entre las restantes
	var disponibles: Array = []
	for idx in range(total):
		# Evitar las primeras casillas (configurable)
		if casillas[idx].tipo == casillas[idx].tipo_casilla.NORMAL and idx >= casillas_inicio_prohibidas_minijuego:
			disponibles.append(idx)

	# Asegurar que no intentemos asignar más minijuegos de los disponibles
	num_minijuegos = min(num_minijuegos, disponibles.size())

	if num_minijuegos > 0 and disponibles.size() > 0:
		var n = disponibles.size()
		if num_minijuegos >= n:
			for pos in disponibles:
				casillas[pos].set_tipo(casillas[pos].tipo_casilla.MINIJUEGO)
		else:
			var step = float(n) / float(num_minijuegos)
			var chosen_positions: Array = []
			for k in range(num_minijuegos):
				var pos = int(floor((k + 0.5) * step))
				if pos >= n:
					pos = n - 1
				var final_pos = pos
				var offset = 0
				while final_pos in chosen_positions:
					offset += 1
					if pos + offset < n and not (pos + offset in chosen_positions):
						final_pos = pos + offset
						break
					if pos - offset >= 0 and not (pos - offset in chosen_positions):
						final_pos = pos - offset
						break
				chosen_positions.append(final_pos)

			for p in chosen_positions:
				var idx_casilla = disponibles[p]
				casillas[idx_casilla].set_tipo(casillas[idx_casilla].tipo_casilla.MINIJUEGO)

func _configurar_conexiones_casillas(casillas: Array[Casilla]) -> void:
	# Primero: Crear mapas de casillas por camino para mejor organizacion
	var casillas_por_camino: Dictionary = {}
	for casilla in casillas:
		var camino = casilla.get_camino()
		if camino != null:
			if not casillas_por_camino.has(camino):
				casillas_por_camino[camino] = []
			casillas_por_camino[camino].append(casilla)
	
	# Segundo: Configurar conexiones para cada casilla
	for casilla_actual in casillas:
		var casillas_destino: Array[Casilla] = []
		
		# Caso 1: Ultima casilla de camino abierto
		if _es_ultima_casilla_camino_abierto(casilla_actual):
			var destino_final = _encontrar_casilla_destino_final(casilla_actual, casillas)
			if destino_final != null:
				casillas_destino.append(destino_final)
		
		# Caso 2: Casilla normal (incluye casillas de camino cerrado)
		else:
			# Conexion principal: siguiente casilla en el mismo camino
			var siguiente_casilla = _encontrar_siguiente_casilla_en_camino(casilla_actual, casillas_por_camino)
			if siguiente_casilla != null:
				casillas_destino.append(siguiente_casilla)
			
			# Conexiones adicionales: bifurcaciones que salen desde esta casilla
			var conexiones_bifurcacion = _encontrar_conexiones_bifurcacion(casilla_actual, casillas)
			for conexion in conexiones_bifurcacion:
				casillas_destino.append(conexion)
		
		# Asignar todas las conexiones a la casilla
		casilla_actual.set_casillas_destino(casillas_destino)


# ############################################################
# Detectar casillas especiales
# ############################################################

func _es_casilla_de_camino_abierto(casilla: Casilla) -> bool:
	var padre = casilla.get_parent()
	return padre is Path3D and not padre.get_curve().is_closed()

func _es_ultima_casilla_camino_abierto(casilla: Casilla) -> bool:
	if not _es_casilla_de_camino_abierto(casilla):
		return false
	
	var camino_padre = casilla.get_parent() as Path3D
	var curva = camino_padre.get_curve()
	var punto_penultimo = curva.get_point_position(curva.get_point_count() - 2)
	var punto_penultimo_global = camino_padre.global_position + punto_penultimo
	
	return casilla.global_position.distance_to(punto_penultimo_global) <= 0.1


# ############################################################
# Buscar conexiones
# ############################################################

func _encontrar_casilla_punto_final(casilla_ultima_abierto: Casilla, todas_casillas: Array[Casilla]) -> Casilla:
	return _encontrar_casilla_destino_final(casilla_ultima_abierto, todas_casillas)

func _encontrar_casilla_destino_final(casilla_ultima_abierto: Casilla, todas_casillas: Array[Casilla]) -> Casilla:
	var camino_padre = casilla_ultima_abierto.get_parent() as Path3D
	var curva = camino_padre.get_curve()
	var punto_final = curva.get_point_position(curva.get_point_count() - 1)
	var punto_final_global = camino_padre.global_position + punto_final
	
	# Buscar cualquier casilla que este en la posicion del punto final
	var casillas_candidatas: Array[Casilla] = []
	
	for casilla in todas_casillas:
		# Saltar la casilla actual (no puede conectar consigo misma)
		if casilla == casilla_ultima_abierto:
			continue
		
		# Verificar si esta en la posicion del punto final
		if punto_final_global.distance_to(casilla.global_position) <= 0.1:
			casillas_candidatas.append(casilla)
	
	# Si encontramos casillas candidatas, elegir la mejor
	if casillas_candidatas.size() > 0:
		# Priorizar por tipo de camino: cerrado > abierto
		var casillas_cerradas = casillas_candidatas.filter(func(c): return c.get_camino() != null and c.get_camino().curve.is_closed())
		var casillas_abiertas = casillas_candidatas.filter(func(c): return c.get_camino() != null and not c.get_camino().curve.is_closed())
		
		# Si hay casillas de caminos cerrados, elegir la primera
		if casillas_cerradas.size() > 0:
			return casillas_cerradas[0]
		
		# Si no hay casillas de caminos cerrados, elegir la primera de caminos abiertos
		if casillas_abiertas.size() > 0:
			return casillas_abiertas[0]
	
	return null

func _encontrar_siguiente_casilla_en_camino(casilla_actual: Casilla, casillas_por_camino: Dictionary) -> Casilla:
	var camino_actual = casilla_actual.get_camino()
	if camino_actual == null or not casillas_por_camino.has(camino_actual):
		return null
	
	var casillas_del_camino = casillas_por_camino[camino_actual]
	var curva = camino_actual.get_curve()
	var punto_actual = casilla_actual.get_punto_camino()
	
	# Para caminos cerrados: buscar la siguiente casilla por punto de camino
	if curva.is_closed():
		var siguiente_punto = punto_actual + 1
		if siguiente_punto >= curva.get_point_count():
			siguiente_punto = 0 # Volver al principio en caminos cerrados
		
		for casilla in casillas_del_camino:
			if casilla.get_punto_camino() == siguiente_punto:
				return casilla
	
	# Para caminos abiertos: buscar siguiente punto (si existe)
	else:
		var siguiente_punto = punto_actual + 1
		for casilla in casillas_del_camino:
			if casilla.get_punto_camino() == siguiente_punto:
				return casilla
	
	return null

func _encontrar_conexiones_bifurcacion(casilla_objetivo: Casilla, todas_casillas: Array[Casilla]) -> Array[Casilla]:
	var conexiones: Array[Casilla] = []
	var posicion_objetivo = casilla_objetivo.global_position
	
	# Buscar caminos abiertos que comienzan en la posicion de esta casilla
	var abiertos = caminos.filter(func(c): return not c.curve.is_closed())
	for camino_abierto in abiertos:
		var punto_inicial = camino_abierto.get_curve().get_point_position(0)
		var punto_inicial_global = camino_abierto.global_position + punto_inicial
		
		if posicion_objetivo.distance_to(punto_inicial_global) <= 0.1:
			var primera_casilla = _encontrar_primera_casilla_camino_abierto(camino_abierto, todas_casillas)
			if primera_casilla != null and primera_casilla != casilla_objetivo:
				conexiones.append(primera_casilla)
	
	return conexiones

func _encontrar_primera_casilla_camino_abierto(camino_abierto: Path3D, todas_casillas: Array[Casilla]) -> Casilla:
	var curva = camino_abierto.get_curve()
	if curva.get_point_count() <= 2:
		return null
	
	var punto_primera_casilla = curva.get_point_position(1)
	var punto_primera_casilla_global = camino_abierto.global_position + punto_primera_casilla
	for casilla in todas_casillas:
		if punto_primera_casilla_global.distance_to(casilla.global_position) <= 0.1:
			return casilla
	
	return null


# ############################################################
# Sincronizar puntos de union
# ############################################################

var ignorar_sincronizacion := false

func _asignar_puntos_de_union() -> void:
	if not Engine.is_editor_hint():
		return
	asociaciones_puntos.clear()
	posiciones_anteriores.clear()
	
	var abiertos = caminos.filter(func(c): return not c.curve.is_closed())
	var todos_caminos = caminos.duplicate() # Usar todos los caminos, no solo cerrados
	
	if todos_caminos.is_empty():
		return
	
	for camino_abierto in abiertos:
		var curva_abierta = camino_abierto.get_curve()
		if curva_abierta.get_point_count() < 2:
			continue
		
		asociaciones_puntos[camino_abierto.name] = {}
		
		# Asociar punto inicial - buscar en todos los caminos excepto el actual
		var punto_inicial = curva_abierta.get_point_position(0)
		var caminos_para_inicial = todos_caminos.filter(func(c): return c != camino_abierto)
		var asociacion_inicial = _encontrar_punto_mas_cercano(punto_inicial, caminos_para_inicial)
		if asociacion_inicial != null:
			asociaciones_puntos[camino_abierto.name]["inicial"] = asociacion_inicial
			curva_abierta.set_point_position(0, asociacion_inicial.posicion)
		
		# Asociar punto final - buscar en todos los caminos excepto el actual
		var ultimo_idx = curva_abierta.get_point_count() - 1
		var punto_final = curva_abierta.get_point_position(ultimo_idx)
		var caminos_para_final = todos_caminos.filter(func(c): return c != camino_abierto)
		var asociacion_final = _encontrar_punto_mas_cercano(punto_final, caminos_para_final)
		if asociacion_final != null:
			asociaciones_puntos[camino_abierto.name]["final"] = asociacion_final
			curva_abierta.set_point_position(ultimo_idx, asociacion_final.posicion)
	
	_guardar_posiciones_actuales()

func _encontrar_punto_mas_cercano(punto_objetivo: Vector3, caminos_candidatos: Array):
	var mejor_resultado = null
	var distancia_minima = 999999.0
	
	for camino_candidato in caminos_candidatos:
		if camino_candidato == null:
			continue
		
		var curva_candidata = camino_candidato.get_curve()
		if curva_candidata == null:
			continue
		
		for i in range(curva_candidata.get_point_count()):
			var punto_candidato = curva_candidata.get_point_position(i)
			var distancia = punto_objetivo.distance_to(punto_candidato)
			
			if distancia < distancia_minima:
				distancia_minima = distancia
				mejor_resultado = {
					"camino": camino_candidato,
					"indice": i,
					"posicion": punto_candidato,
					"distancia": distancia
				}
	
	# Solo aceptar si la distancia es razonable
	if mejor_resultado != null and distancia_minima > 10.0:
		return null
	
	return mejor_resultado

func _guardar_posiciones_actuales() -> void:
	posiciones_anteriores.clear()
	
	for camino in caminos:
		var posiciones_camino = []
		var curva = camino.get_curve()
		
		for i in range(curva.get_point_count()):
			posiciones_camino.append(curva.get_point_position(i))
		
		posiciones_anteriores[camino.name] = posiciones_camino

func _actualizar_posicion_casillas() -> void:
	if not Engine.is_editor_hint():
		return
	# Actualizar posiciones de todas las casillas basado en sus caminos
	for camino in caminos:
		var curva = camino.get_curve()
		var point_count = curva.get_point_count()
		var is_abierto = not curva.is_closed()
		var start_idx = 1 if is_abierto and point_count > 2 else 0
		var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count
		
		for i in range(start_idx, end_idx):
			var punto = curva.get_point_position(i)
			# Buscar la casilla correspondiente a este punto
			for child in camino.get_children():
				if child is Casilla and child.get_punto_camino() == i:
					# Actualizar posicion de la casilla
					child.global_position = camino.global_position + punto
					
					# Actualizar rotacion si no es un salto
					var punto_in = curva.get_point_in(i)
					var punto_out = curva.get_point_out(i)
					var es_salto = punto_in.y > 0.5 or punto_out.y > 0.5
					
					var punto_anterior_es_salto = false
					if i > 0:
						var punto_anterior_in = curva.get_point_in(i - 1)
						var punto_anterior_out = curva.get_point_out(i - 1)
						punto_anterior_es_salto = punto_anterior_in.y > 0.5 or punto_anterior_out.y > 0.5
					
					if not (es_salto or punto_anterior_es_salto):
						var direccion = punto_out.normalized()
						if direccion.length() > 0.01:
							child.look_at(child.global_position + direccion, Vector3.UP)
					break

func _sincronizar_puntos_de_union() -> void:
	if not Engine.is_editor_hint():
		return
	if ignorar_sincronizacion:
		return
	ignorar_sincronizacion = true

	if asociaciones_puntos.is_empty():
		_asignar_puntos_de_union()
		ignorar_sincronizacion = false
		return

	var puntos_cambiados = _detectar_puntos_cambiados()
	if puntos_cambiados.is_empty():
		ignorar_sincronizacion = false
		return

	for cambio in puntos_cambiados:
		_sincronizar_extremos_asociados(cambio)

	_guardar_posiciones_actuales()
	ignorar_sincronizacion = false

func _detectar_puntos_cambiados() -> Array:
	var cambios = []
	
	for camino in caminos:
		var nombre_camino = camino.name
		if not posiciones_anteriores.has(nombre_camino):
			continue
		
		var curva = camino.get_curve()
		var posiciones_previas = posiciones_anteriores[nombre_camino]
		
		for i in range(curva.get_point_count()):
			if i >= posiciones_previas.size():
				continue
			
			var posicion_actual = curva.get_point_position(i)
			var posicion_previa = posiciones_previas[i]
			
			if posicion_actual.distance_to(posicion_previa) > 0.001:
				cambios.append({
					"camino": camino,
					"indice": i,
					"posicion_nueva": posicion_actual,
					"posicion_previa": posicion_previa
				})
	
	return cambios

func _sincronizar_extremos_asociados(cambio: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	var camino_cambiado = cambio.camino
	var indice_cambiado = cambio.indice
	var nueva_posicion = cambio.posicion_nueva
	
	# Caso 1: Un camino base cambio, actualizar caminos abiertos asociados
	for nombre_camino_abierto in asociaciones_puntos.keys():
		var asociaciones = asociaciones_puntos[nombre_camino_abierto]
		var camino_abierto = _encontrar_camino_por_nombre(nombre_camino_abierto)
		
		if camino_abierto == null:
			continue
		
		# Sincronizar punto inicial
		if asociaciones.has("inicial"):
			var asoc_inicial = asociaciones.inicial
			if asoc_inicial.camino == camino_cambiado and asoc_inicial.indice == indice_cambiado:
				camino_abierto.curve.set_point_position(0, nueva_posicion)
				asociaciones.inicial.posicion = nueva_posicion
		
		# Sincronizar punto final
		if asociaciones.has("final"):
			var asoc_final = asociaciones.final
			if asoc_final.camino == camino_cambiado and asoc_final.indice == indice_cambiado:
				var ultimo_idx = camino_abierto.curve.get_point_count() - 1
				camino_abierto.curve.set_point_position(ultimo_idx, nueva_posicion)
				asociaciones.final.posicion = nueva_posicion
	
	# Caso 2: Un camino abierto cambio, actualizar otros caminos enlazados
	if not camino_cambiado.curve.is_closed():
		var nombre_camino_cambiado = camino_cambiado.name
		if asociaciones_puntos.has(nombre_camino_cambiado):
			var asociaciones_actuales = asociaciones_puntos[nombre_camino_cambiado]
			var curva_cambiada = camino_cambiado.get_curve()
			
			# Si cambio el punto inicial (indice 0)
			if indice_cambiado == 0 and asociaciones_actuales.has("inicial"):
				var asoc = asociaciones_actuales.inicial
				asoc.camino.curve.set_point_position(asoc.indice, nueva_posicion)
				asoc.posicion = nueva_posicion
			
			# Si cambio el punto final (ultimo indice)
			elif indice_cambiado == curva_cambiada.get_point_count() - 1 and asociaciones_actuales.has("final"):
				var asoc = asociaciones_actuales.final
				asoc.camino.curve.set_point_position(asoc.indice, nueva_posicion)
				asoc.posicion = nueva_posicion

func _encontrar_camino_por_nombre(nombre: String) -> Path3D:
	for camino in caminos:
		if camino.name == nombre:
			return camino
	return null
