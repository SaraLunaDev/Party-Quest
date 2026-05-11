@tool
extends Node3D


# Variables
# ---------------------------------------------------------------------------------------
# IMPORTANTE: El primer camino del array debe ser el camino principal y estar cerrado
# Los demas caminos pueden ser abiertos y se conectaran al principal
@export var caminos: Array[Path3D]
@export var casilla_escena: PackedScene

@export var rotar_seguir_trayectoria: bool = false

var ignorar_sincronizacion := false
var posiciones_cache: Dictionary = {}

@export var numero_casillas: int
var asociaciones_puntos: Dictionary = {}
var posiciones_anteriores: Dictionary = {}

#region Configuracion de Casillas
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
			_establecer_tipo_casillas(obtener_casillas_del_tablero())

@export var cantidad_casillas_entre_rojas: int = 2:
	set(value):
		cantidad_casillas_entre_rojas = max(0, value)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(obtener_casillas_del_tablero())

@export var porcentaje_casillas_minijuego: float = 0.1:
	set(value):
		porcentaje_casillas_minijuego = clamp(value, 0.0, 1.0)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(obtener_casillas_del_tablero())

@export var casillas_inicio_prohibidas_minijuego: int = 6:
	set(value):
		casillas_inicio_prohibidas_minijuego = max(0, value)
		if Engine.is_editor_hint():
			_establecer_tipo_casillas(obtener_casillas_del_tablero())

@export_category("Debug")
@export var verificar_asignaciones: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_verificar_asignaciones_puntos()
		verificar_asignaciones = false

@export var forzar_camino_principal_cerrado: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_validar_camino_principal()
		forzar_camino_principal_cerrado = false

@export_category("Puntos de Union")
@export var fijar_puntos_de_union: bool:
	set(value):
		if Engine.is_editor_hint() and value:
			_asignar_puntos_de_union()
		fijar_puntos_de_union = false
#endregion


# Funciones Basicas
# ---------------------------------------------------------------------------------------
func _ready():
	if Engine.is_editor_hint():
		_validar_camino_principal()
		
		for camino in caminos:
			if camino == null:
				continue
			
			# Desconectar primero si ya esta conectado
			if camino.is_connected("curve_changed", Callable(self , "_actualizar_posicion_casillas")):
				camino.disconnect("curve_changed", Callable(self , "_actualizar_posicion_casillas"))
				
			if camino.is_connected("curve_changed", Callable(self , "_sincronizar_puntos_de_union")):
				camino.disconnect("curve_changed", Callable(self , "_sincronizar_puntos_de_union"))
			
			# Reconectar
			camino.connect("curve_changed", Callable(self , "_actualizar_posicion_casillas"))
			camino.connect("curve_changed", Callable(self , "_sincronizar_puntos_de_union"))
		
		_actualizar_posicion_casillas()
		_asignar_puntos_de_union()
		_actualizar_cache_posiciones()

func _process(_delta):
	if Engine.is_editor_hint():
		_detectar_cambios_automatico()

# Sistema fallback para detectar cambios sin señales
func _detectar_cambios_automatico() -> void:
	for camino in caminos:
		if camino == null:
			continue
			
		var curva = camino.get_curve()
		var nombre_camino = camino.name
		
		if not posiciones_cache.has(nombre_camino):
			posiciones_cache[nombre_camino] = []
		
		var cache_actual = posiciones_cache[nombre_camino]
		var cambio_detectado = false
		
		# Verificar si el numero de puntos cambio
		if cache_actual.size() != curva.get_point_count():
			cambio_detectado = true
		else:
			# Verificar si alguna posicion cambio
			for i in range(curva.get_point_count()):
				var pos_actual = curva.get_point_position(i)
				if i >= cache_actual.size() or cache_actual[i].distance_to(pos_actual) > 0.001:
					cambio_detectado = true
					break
		
		if cambio_detectado:
			_actualizar_cache_posiciones()
			_actualizar_posicion_casillas()
			break

func _actualizar_cache_posiciones():
	for camino in caminos:
		if camino == null:
			continue
		var curva = camino.get_curve()
		var posiciones = []
		for i in range(curva.get_point_count()):
			posiciones.append(curva.get_point_position(i))
		posiciones_cache[camino.name] = posiciones


# Instanciacion de Casillas
# ---------------------------------------------------------------------------------------

#region
# Limpia las casillas existentes del tablero
func _limpiar_casillas() -> void:
	if not Engine.is_editor_hint():
		return
	for camino in caminos:
		for child in camino.get_children():
			if child.name.begins_with("Casilla_"):
				camino.remove_child(child)
				child.queue_free()

# Instancia casillas en los caminos, configura posiciones, rotaciones y tipos
func _instanciar_casillas() -> Array[Vector3]:
	if not Engine.is_editor_hint():
		return []
	
	# Validar camino principal antes de instanciar
	_validar_camino_principal()
	
	_limpiar_casillas()
	numero_casillas = 0
	var puntos: Array[Vector3] = []
	var todas_las_casillas: Array[Casilla] = []
	
	for camino in caminos:
		var curva = camino.get_curve()
		var point_count = curva.get_point_count()
		var is_abierto = not curva.is_closed()
		var start_idx = 1 if is_abierto and point_count > 2 else 0
		# Para caminos cerrados, excluir ultimo punto para evitar duplicacion con el primero
		var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count - 1
		
		for i in range(start_idx, end_idx):
			var punto = curva.get_point_position(i)
			puntos.append(punto)
			
			
			var casilla = casilla_escena.instantiate()
			casilla.name = "Casilla_" + str(numero_casillas)
			camino.add_child(casilla)
			casilla.owner = get_tree().edited_scene_root
			casilla.set_index(numero_casillas)
			casilla.set_punto_camino(i)
			casilla.set_camino(camino)
			
			# Asegurar posicion correcta inmediatamente
			casilla.global_position = camino.global_position + punto

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
	
	_establecer_tipo_casillas(todas_las_casillas)
	
	_configurar_conexiones_casillas(todas_las_casillas)
	return puntos

# Retorna array con todas las casillas instanciadas en el tablero
func obtener_casillas_del_tablero() -> Array[Casilla]:
	var casillas: Array[Casilla] = []
	for camino in caminos:
		for child in camino.get_children():
			if child is Casilla:
				casillas.append(child as Casilla)
	return casillas
#endregion


# Configuracion de Tipos de Casillas
# ---------------------------------------------------------------------------------------
#region
# Asigna tipos a las casillas segun patrones configurados
func _establecer_tipo_casillas(casillas: Array[Casilla]) -> void:
	if not Engine.is_editor_hint():
		return
	if casillas.size() == 0:
		return

	var total = casillas.size()
	var num_minijuegos = int(round(total * porcentaje_casillas_minijuego))

	for casilla in casillas:
		casilla.set_tipo(casilla.tipo_casilla.NORMAL)

	var i = 0
	while i < total:
		for j in range(cantidad_casillas_roja_juntas):
			var idx = i + j
			if idx >= total:
				break
			casillas[idx].set_tipo(casillas[idx].tipo_casilla.ROJA)

		
		i += cantidad_casillas_roja_juntas
		i += cantidad_casillas_entre_rojas

	var rojas_asignadas = 0
	for casilla in casillas:
		if casilla.tipo == casilla.tipo_casilla.ROJA:
			rojas_asignadas += 1

	if rojas_asignadas + num_minijuegos > total:
		num_minijuegos = max(0, total - rojas_asignadas)

	var disponibles: Array = []
	for idx in range(total):
		if casillas[idx].tipo == casillas[idx].tipo_casilla.NORMAL and idx >= casillas_inicio_prohibidas_minijuego:
			disponibles.append(idx)

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
#endregion


# Configuracion entre Casillas
# ---------------------------------------------------------------------------------------
#region
# Establece las conexiones de destino para cada casilla del tablero
func _configurar_conexiones_casillas(casillas: Array[Casilla]) -> void:
	var casillas_por_camino: Dictionary = {}
	for casilla in casillas:
		var camino = casilla.get_camino()
		if camino != null:
			if not casillas_por_camino.has(camino):
				casillas_por_camino[camino] = []
			casillas_por_camino[camino].append(casilla)
	
	for casilla_actual in casillas:
		var casillas_destino: Array[Casilla] = []
		
		if _es_ultima_casilla_camino_abierto(casilla_actual):
			var destino_final = _encontrar_casilla_destino_final(casilla_actual, casillas)
			if destino_final != null:
				casillas_destino.append(destino_final)
		
		else:
			var siguiente_casilla = _encontrar_siguiente_casilla_en_camino(casilla_actual, casillas_por_camino)
			if siguiente_casilla != null:
				casillas_destino.append(siguiente_casilla)
			
			var conexiones_bifurcacion = _encontrar_conexiones_bifurcacion(casilla_actual, casillas)
			for conexion in conexiones_bifurcacion:
				casillas_destino.append(conexion)
		
		casilla_actual.set_casillas_destino(casillas_destino)

# Verifica si la casilla pertenece a un camino no cerrado
func _es_casilla_de_camino_abierto(casilla: Casilla) -> bool:
	var padre = casilla.get_parent()
	return padre is Path3D and not padre.get_curve().is_closed()

# Verifica si la casilla es la ultima del camino abierto
func _es_ultima_casilla_camino_abierto(casilla: Casilla) -> bool:
	if not _es_casilla_de_camino_abierto(casilla):
		return false
	
	var camino_padre = casilla.get_parent() as Path3D
	var curva = camino_padre.get_curve()
	var punto_penultimo = curva.get_point_position(curva.get_point_count() - 2)
	var punto_penultimo_global = camino_padre.global_position + punto_penultimo
	
	return casilla.global_position.distance_to(punto_penultimo_global) <= 0.1

# Busca la casilla destino desde el final de un camino abierto
func _encontrar_casilla_punto_final(casilla_ultima_abierto: Casilla, todas_casillas: Array[Casilla]) -> Casilla:
	return _encontrar_casilla_destino_final(casilla_ultima_abierto, todas_casillas)

# Localiza casilla destino en el punto final del camino abierto
func _encontrar_casilla_destino_final(casilla_ultima_abierto: Casilla, todas_casillas: Array[Casilla]) -> Casilla:
	var camino_padre = casilla_ultima_abierto.get_parent() as Path3D
	var curva = camino_padre.get_curve()
	var punto_final = curva.get_point_position(curva.get_point_count() - 1)
	var punto_final_global = camino_padre.global_position + punto_final
	
	var casillas_candidatas: Array[Casilla] = []
	
	for casilla in todas_casillas:
		if casilla == casilla_ultima_abierto:
			continue
		
		if punto_final_global.distance_to(casilla.global_position) <= 0.1:
			casillas_candidatas.append(casilla)
	
	if casillas_candidatas.size() > 0:
		var casillas_cerradas = casillas_candidatas.filter(func(c): return c.get_camino() != null and c.get_camino().curve.is_closed())
		var casillas_abiertas = casillas_candidatas.filter(func(c): return c.get_camino() != null and not c.get_camino().curve.is_closed())
		
		if casillas_cerradas.size() > 0:
			return casillas_cerradas[0]
		
		if casillas_abiertas.size() > 0:
			return casillas_abiertas[0]
	
	return null

# Retorna la siguiente casilla en el mismo camino
func _encontrar_siguiente_casilla_en_camino(casilla_actual: Casilla, casillas_por_camino: Dictionary) -> Casilla:
	var camino_actual = casilla_actual.get_camino()
	if camino_actual == null or not casillas_por_camino.has(camino_actual):
		return null
	
	var casillas_del_camino = casillas_por_camino[camino_actual]
	var curva = camino_actual.get_curve()
	var punto_actual = casilla_actual.get_punto_camino()
	
	if curva.is_closed():
		var siguiente_punto = punto_actual + 1
		if siguiente_punto >= curva.get_point_count():
			siguiente_punto = 0
		
		for casilla in casillas_del_camino:
			if casilla.get_punto_camino() == siguiente_punto:
				return casilla
	
	else:
		var siguiente_punto = punto_actual + 1
		for casilla in casillas_del_camino:
			if casilla.get_punto_camino() == siguiente_punto:
				return casilla
	
	return null

# Busca casillas alcanzables desde bifurcaciones entre caminos
func _encontrar_conexiones_bifurcacion(casilla_objetivo: Casilla, todas_casillas: Array[Casilla]) -> Array[Casilla]:
	var conexiones: Array[Casilla] = []
	var posicion_objetivo = casilla_objetivo.global_position
	
	# Filtrar caminos abiertos excluyendo el primer camino que debe ser cerrado
	var abiertos = caminos.filter(func(c): return not c.curve.is_closed() and c != caminos[0])
	for camino_abierto in abiertos:
		var punto_inicial = camino_abierto.get_curve().get_point_position(0)
		var punto_inicial_global = camino_abierto.global_position + punto_inicial
		
		if posicion_objetivo.distance_to(punto_inicial_global) <= 0.1:
			var primera_casilla = _encontrar_primera_casilla_camino_abierto(camino_abierto, todas_casillas)
			if primera_casilla != null and primera_casilla != casilla_objetivo:
				conexiones.append(primera_casilla)
	
	return conexiones

# Localiza la primera casilla de un camino abierto
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
#endregion


# Gestion de Puntos de Union
# ---------------------------------------------------------------------------------------
#region
# Vincula extremos de caminos abiertos con puntos de caminos cerrados
func _asignar_puntos_de_union() -> void:
	if not Engine.is_editor_hint():
		return
	asociaciones_puntos.clear()
	posiciones_anteriores.clear()
	
	# Filtrar caminos abiertos excluyendo el primer camino que debe ser cerrado
	var abiertos = caminos.filter(func(c): return not c.curve.is_closed() and c != caminos[0])
	var todos_caminos = caminos.duplicate()
	
	if todos_caminos.is_empty():
		return
	
	for camino_abierto in abiertos:
		var curva_abierta = camino_abierto.get_curve()
		if curva_abierta.get_point_count() < 2:
			continue
		
		asociaciones_puntos[camino_abierto.name] = {}
		
		var punto_inicial = curva_abierta.get_point_position(0)
		var caminos_para_inicial = todos_caminos.filter(func(c): return c != camino_abierto)
		var asociacion_inicial = _encontrar_punto_mas_cercano(punto_inicial, caminos_para_inicial)
		if asociacion_inicial != null:
			asociaciones_puntos[camino_abierto.name]["inicial"] = asociacion_inicial
			curva_abierta.set_point_position(0, asociacion_inicial.posicion)
		
		var ultimo_idx = curva_abierta.get_point_count() - 1
		var punto_final = curva_abierta.get_point_position(ultimo_idx)
		var caminos_para_final = todos_caminos.filter(func(c): return c != camino_abierto)
		var asociacion_final = _encontrar_punto_mas_cercano(punto_final, caminos_para_final)
		if asociacion_final != null:
			asociaciones_puntos[camino_abierto.name]["final"] = asociacion_final
			curva_abierta.set_point_position(ultimo_idx, asociacion_final.posicion)
	
	_guardar_posiciones_actuales()

# Busca el punto mas cercano al objetivo entre los caminos candidatos
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
	
	if mejor_resultado != null and distancia_minima > 10.0:
		return null
	
	return mejor_resultado

# Almacena posiciones actuales de puntos para detectar cambios
func _guardar_posiciones_actuales() -> void:
	posiciones_anteriores.clear()
	
	for camino in caminos:
		var posiciones_camino = []
		var curva = camino.get_curve()
		
		for i in range(curva.get_point_count()):
			posiciones_camino.append(curva.get_point_position(i))
		
		posiciones_anteriores[camino.name] = posiciones_camino
#endregion


# Sincronizacion y Actualizacion
# ---------------------------------------------------------------------------------------
#region
# Reposiciona casillas cuando cambian las curvas de los caminos
func _actualizar_posicion_casillas() -> void:
	if not Engine.is_editor_hint():
		return
	
	for camino in caminos:
		var curva = camino.get_curve()
		var point_count = curva.get_point_count()
		var is_abierto = not curva.is_closed()
		var start_idx = 1 if is_abierto and point_count > 2 else 0
		# Para caminos cerrados, excluir ultimo punto para evitar duplicacion con el primero
		var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count - 1
		
		# Crear cache de casillas por punto para optimizar busqueda
		var casillas_por_punto: Dictionary = {}
		for child in camino.get_children():
			if child is Casilla:
				var punto_camino_int = int(child.get_punto_camino())
				casillas_por_punto[punto_camino_int] = child
		
		for i in range(start_idx, end_idx):
			var punto = curva.get_point_position(i)
			
			if casillas_por_punto.has(i):
				var casilla = casillas_por_punto[i]
				casilla.global_position = camino.global_position + punto
				
				if rotar_seguir_trayectoria:
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
							casilla.look_at(casilla.global_position + direccion, Vector3.UP)

# Mantiene sincronizados los puntos de union al cambiar curvas
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

# Identifica puntos que cambiaron de posicion desde la ultima actualizacion
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

# Actualiza puntos asociados cuando se detecta un cambio
func _sincronizar_extremos_asociados(cambio: Dictionary) -> void:
	if not Engine.is_editor_hint():
		return
	var camino_cambiado = cambio.camino
	var indice_cambiado = cambio.indice
	var nueva_posicion = cambio.posicion_nueva
	
	for nombre_camino_abierto in asociaciones_puntos.keys():
		var asociaciones = asociaciones_puntos[nombre_camino_abierto]
		var camino_abierto = _encontrar_camino_por_nombre(nombre_camino_abierto)
		
		if camino_abierto == null:
			continue
		
		if asociaciones.has("inicial"):
			var asoc_inicial = asociaciones.inicial
			if asoc_inicial.camino == camino_cambiado and asoc_inicial.indice == indice_cambiado:
				camino_abierto.curve.set_point_position(0, nueva_posicion)
				asociaciones.inicial.posicion = nueva_posicion
		
		if asociaciones.has("final"):
			var asoc_final = asociaciones.final
			if asoc_final.camino == camino_cambiado and asoc_final.indice == indice_cambiado:
				var ultimo_idx = camino_abierto.curve.get_point_count() - 1
				camino_abierto.curve.set_point_position(ultimo_idx, nueva_posicion)
				asociaciones.final.posicion = nueva_posicion
	
	if not camino_cambiado.curve.is_closed() and camino_cambiado != caminos[0]:
		var nombre_camino_cambiado = camino_cambiado.name
		if asociaciones_puntos.has(nombre_camino_cambiado):
			var asociaciones_actuales = asociaciones_puntos[nombre_camino_cambiado]
			var curva_cambiada = camino_cambiado.get_curve()
			
			if indice_cambiado == 0 and asociaciones_actuales.has("inicial"):
				var asoc = asociaciones_actuales.inicial
				asoc.camino.curve.set_point_position(asoc.indice, nueva_posicion)
				asoc.posicion = nueva_posicion
			
			elif indice_cambiado == curva_cambiada.get_point_count() - 1 and asociaciones_actuales.has("final"):
				var asoc = asociaciones_actuales.final
				asoc.camino.curve.set_point_position(asoc.indice, nueva_posicion)
				asoc.posicion = nueva_posicion

# Busca un camino por su nombre en el array de caminos
func _encontrar_camino_por_nombre(nombre: String) -> Path3D:
	for camino in caminos:
		if camino.name == nombre:
			return camino
	return null

# Verifica las asignaciones de puntos para debug
func _verificar_asignaciones_puntos() -> void:
	if not Engine.is_editor_hint():
		return
		
	print("=== Verificacion de Asignaciones de Puntos ===")
	
	for camino in caminos:
		print("Camino: ", camino.name)
		var curva = camino.get_curve()
		var point_count = curva.get_point_count()
		print("  Puntos en curva: ", point_count)
		
		var casillas_encontradas: Dictionary = {}
		for child in camino.get_children():
			if child is Casilla:
				var punto_camino_int = int(child.get_punto_camino())
				casillas_encontradas[punto_camino_int] = child
				print("    Casilla: ", child.name, " -> Punto: ", punto_camino_int)
		
		var is_abierto = not curva.is_closed()
		var start_idx = 1 if is_abierto and point_count > 2 else 0
		# Para caminos cerrados, excluir ultimo punto para evitar duplicacion con el primero
		var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count - 1
		
		print("  Puntos esperados: ", start_idx, " a ", end_idx - 1)
		
		for i in range(start_idx, end_idx):
			if not casillas_encontradas.has(i):
				print("    ⚠ Punto ", i, " sin casilla asignada")
			else:
				var casilla = casillas_encontradas[i]
				var punto_pos = curva.get_point_position(i)
				var esperada = camino.global_position + punto_pos
				var actual = casilla.global_position
				var distancia = esperada.distance_to(actual)
				if distancia > 0.1:
					print("    ⚠ Casilla ", casilla.name, " mal posicionada. Dist: ", distancia)
		print("  ---")

# Valida que el camino principal sea cerrado
func _validar_camino_principal() -> void:
	if not Engine.is_editor_hint():
		return
		
	if caminos.is_empty():
		print("⚠ No hay caminos configurados")
		return
		
	var camino_principal = caminos[0]
	if camino_principal == null:
		print("⚠ Camino principal es null")
		return
		
	var curva = camino_principal.get_curve()
	if curva.get_point_count() < 3:
		print("⚠ Camino principal necesita al menos 3 puntos")
		return
		
	if not curva.is_closed():
		print("Cerrando camino principal...")
		# Anclar ultimo punto al primero
		var primer_punto = curva.get_point_position(0)
		var ultimo_indice = curva.get_point_count() - 1
		curva.set_point_position(ultimo_indice, primer_punto)
		
		# Cerrar la curva
		curva.set_closed(true)
		print("Camino principal cerrado correctamente")
	else:
		# Verificar que primer y ultimo punto estan anclados
		var primer_punto = curva.get_point_position(0)
		var ultimo_indice = curva.get_point_count() - 1
		var ultimo_punto = curva.get_point_position(ultimo_indice)
		
		if primer_punto.distance_to(ultimo_punto) > 0.001:
			print("Anclando puntos inicial y final del camino principal...")
			curva.set_point_position(ultimo_indice, primer_punto)
#endregion