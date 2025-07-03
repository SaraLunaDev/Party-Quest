@tool
extends Node3D

@export var caminos: Array[Path3D]
@export var casilla_escena: PackedScene

var numero_casillas: int
var asociaciones_puntos: Dictionary = {}
var posiciones_anteriores: Dictionary = {}

@export_category("Casillas")
@export var instanciar_casillas: bool:
    set(value):
        if value: _instanciar_casillas()
        instanciar_casillas = false

@export var limpiar_casillas: bool:
    set(value):
        if value: _limpiar_casillas()
        limpiar_casillas = false

@export_category("Puntos de Union")
@export var fijar_puntos_de_union: bool:
    set(value):
        if value: _asignar_puntos_de_union()
        fijar_puntos_de_union = false

func _ready():
    for camino in caminos:
        camino.connect("curve_changed", Callable(self, "_actualizar_posicion_casillas"))
        camino.connect("curve_changed", Callable(self, "_sincronizar_puntos_de_union"))
    _asignar_puntos_de_union()

# ====================================================================
# SECCION: GESTION DE CASILLAS
# ====================================================================

func _limpiar_casillas() -> void:
    for camino in caminos:
        for child in camino.get_children():
            if child is PathFollow3D:
                camino.remove_child(child)
                child.queue_free()

func _instanciar_casillas() -> Array[Vector3]:
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
            
            # Crear PathFollow3D
            var path_follow = PathFollow3D.new()
            path_follow.name = "PathFollow_" + str(numero_casillas)
            
            # Verificar si es un salto (punto extendido apunta hacia el cielo)
            var punto_in = curva.get_point_in(i)
            var punto_out = curva.get_point_out(i)
            var es_salto = punto_in.y > 0.5 or punto_out.y > 0.5
            
            # Verificar si el punto anterior es un salto
            var punto_anterior_es_salto = false
            if i > 0:
                var punto_anterior_in = curva.get_point_in(i - 1)
                var punto_anterior_out = curva.get_point_out(i - 1)
                punto_anterior_es_salto = punto_anterior_in.y > 0.5 or punto_anterior_out.y > 0.5
            
            if es_salto or punto_anterior_es_salto:
                path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
            else:
                path_follow.rotation_mode = PathFollow3D.ROTATION_XY
            
            camino.add_child(path_follow)
            path_follow.owner = get_tree().edited_scene_root
            
            # Calcular la posición exacta en la curva usando el punto
            var offset_distancia = curva.get_closest_offset(punto)
            path_follow.progress = offset_distancia
            
            # Bloquear el PathFollow3D para que no se pueda mover
            path_follow.set_process_mode(Node.PROCESS_MODE_DISABLED)
            path_follow.set_physics_process(false)
            
            # Crear casilla como hijo del PathFollow3D
            var casilla = casilla_escena.instantiate()
            casilla.name = "Casilla_" + str(numero_casillas)
            path_follow.add_child(casilla)
            casilla.owner = get_tree().edited_scene_root
            casilla.set_index(numero_casillas)
            
            todas_las_casillas.append(casilla)
            numero_casillas += 1
    
    # Configurar conexiones entre casillas
    _configurar_conexiones_casillas(todas_las_casillas)
    return puntos

func _configurar_conexiones_casillas(casillas: Array[Casilla]) -> void:
    for i in range(casillas.size()):
        var casilla_actual = casillas[i]
        var casillas_destino: Array[Casilla] = []
        
        # Logica especial para ultima casilla del camino abierto
        if _es_ultima_casilla_camino_abierto(casilla_actual):
            var casilla_destino_final = _encontrar_casilla_punto_final(casilla_actual, casillas)
            if casilla_destino_final != null:
                casillas_destino.append(casilla_destino_final)
        else:
            # Conexion normal: siguiente casilla
            var siguiente_indice = (i + 1) % casillas.size()
            casillas_destino.append(casillas[siguiente_indice])
            
            # Conexiones adicionales para puntos de union
            var conexiones_union = _encontrar_conexiones_union(casilla_actual, casillas)
            for conexion in conexiones_union:
                casillas_destino.append(conexion)
        
        # Asignar conexiones
        casilla_actual.set_casillas_destino(casillas_destino)

# ====================================================================
# SECCION: DETECCION DE CASILLAS ESPECIALES
# ====================================================================

func _es_casilla_de_camino_abierto(casilla: Casilla) -> bool:
    var padre = casilla.get_parent()
    return padre is Path3D and not padre.get_curve().is_closed()

func _es_ultima_casilla_camino_abierto(casilla: Casilla) -> bool:
    if not _es_casilla_de_camino_abierto(casilla):
        return false
    
    var camino_padre = casilla.get_parent() as Path3D
    var curva = camino_padre.get_curve()
    var punto_penultimo = curva.get_point_position(curva.get_point_count() - 2)
    
    return casilla.global_position.distance_to(punto_penultimo) <= 0.1

# ====================================================================
# SECCION: BUSQUEDA DE CONEXIONES
# ====================================================================

func _encontrar_casilla_punto_final(casilla_ultima_abierto: Casilla, todas_casillas: Array[Casilla]) -> Casilla:
    var camino_padre = casilla_ultima_abierto.get_parent() as Path3D
    var curva = camino_padre.get_curve()
    var punto_final = curva.get_point_position(curva.get_point_count() - 1)
    
    for casilla in todas_casillas:
        if casilla == casilla_ultima_abierto or _es_casilla_de_camino_abierto(casilla):
            continue
        if punto_final.distance_to(casilla.global_position) <= 0.1:
            return casilla
    
    return null

func _encontrar_conexiones_union(casilla_objetivo: Casilla, todas_casillas: Array[Casilla]) -> Array[Casilla]:
    var conexiones: Array[Casilla] = []
    var posicion_objetivo = casilla_objetivo.global_position
    
    # Verificar si la casilla esta en punto inicial de camino abierto
    var abiertos = caminos.filter(func(c): return not c.curve.is_closed())
    for camino_abierto in abiertos:
        var punto_inicial = camino_abierto.get_curve().get_point_position(0)
        if posicion_objetivo.distance_to(punto_inicial) <= 0.1:
            var primera_casilla = _encontrar_primera_casilla_camino_abierto(camino_abierto, todas_casillas)
            if primera_casilla != null:
                conexiones.append(primera_casilla)
    
    return conexiones

func _encontrar_primera_casilla_camino_abierto(camino_abierto: Path3D, todas_casillas: Array[Casilla]) -> Casilla:
    var curva = camino_abierto.get_curve()
    if curva.get_point_count() <= 2:
        return null
    
    var punto_primera_casilla = curva.get_point_position(1)
    for casilla in todas_casillas:
        if punto_primera_casilla.distance_to(casilla.global_position) <= 0.1:
            return casilla
    
    return null

# ====================================================================
# SECCION: SINCRONIZACION DE PUNTOS
# ====================================================================

var ignorar_sincronizacion := false

func _asignar_puntos_de_union() -> void:
    asociaciones_puntos.clear()
    posiciones_anteriores.clear()
    
    var abiertos = caminos.filter(func(c): return not c.curve.is_closed())
    var cerrados = caminos.filter(func(c): return c.curve.is_closed())
    
    if cerrados.is_empty():
        return
    
    for camino_abierto in abiertos:
        var curva_abierta = camino_abierto.get_curve()
        if curva_abierta.get_point_count() < 2:
            continue
        
        asociaciones_puntos[camino_abierto.name] = {}
        
        # Asociar punto inicial
        var punto_inicial = curva_abierta.get_point_position(0)
        var asociacion_inicial = _encontrar_punto_mas_cercano(punto_inicial, cerrados)
        if asociacion_inicial != null:
            asociaciones_puntos[camino_abierto.name]["inicial"] = asociacion_inicial
            curva_abierta.set_point_position(0, asociacion_inicial.posicion)
        
        # Asociar punto final
        var ultimo_idx = curva_abierta.get_point_count() - 1
        var punto_final = curva_abierta.get_point_position(ultimo_idx)
        var asociacion_final = _encontrar_punto_mas_cercano(punto_final, cerrados)
        if asociacion_final != null:
            asociaciones_puntos[camino_abierto.name]["final"] = asociacion_final
            curva_abierta.set_point_position(ultimo_idx, asociacion_final.posicion)
    
    _guardar_posiciones_actuales()

func _encontrar_punto_mas_cercano(punto_objetivo: Vector3, caminos_cerrados: Array):
    var mejor_resultado = null
    var distancia_minima = 999999.0
    
    for camino_cerrado in caminos_cerrados:
        if camino_cerrado == null:
            continue
        
        var curva_cerrada = camino_cerrado.get_curve()
        if curva_cerrada == null:
            continue
        
        for i in range(curva_cerrada.get_point_count()):
            var punto_candidato = curva_cerrada.get_point_position(i)
            var distancia = punto_objetivo.distance_to(punto_candidato)
            
            if distancia < distancia_minima:
                distancia_minima = distancia
                mejor_resultado = {
                    "camino": camino_cerrado,
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
        if camino.curve.is_closed():
            var posiciones_camino = []
            var curva = camino.get_curve()
            
            for i in range(curva.get_point_count()):
                posiciones_camino.append(curva.get_point_position(i))
            
            posiciones_anteriores[camino.name] = posiciones_camino

func _actualizar_posicion_casillas() -> void:
    var casilla_global_idx = 0
    
    for camino in caminos:
        var curva = camino.get_curve()
        var point_count = curva.get_point_count()
        var is_abierto = not curva.is_closed()
        var start_idx = 1 if is_abierto and point_count > 2 else 0
        var end_idx = point_count - 1 if is_abierto and point_count > 2 else point_count
        
        for i in range(start_idx, end_idx):
            var punto = curva.get_point_position(i)
            for child in camino.get_children():
                if child is PathFollow3D and child.name == "PathFollow_" + str(casilla_global_idx):
                    # Calcular la posición exacta en la curva usando el punto
                    var offset_distancia = curva.get_closest_offset(punto)
                    child.progress = offset_distancia
                    
                    # Bloquear el PathFollow3D para que no se pueda mover
                    child.set_process_mode(Node.PROCESS_MODE_DISABLED)
                    child.set_physics_process(false)
                    break
            casilla_global_idx += 1

func _sincronizar_puntos_de_union() -> void:
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
        if not camino.curve.is_closed():
            continue
        
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
    var camino_cambiado = cambio.camino
    var indice_cambiado = cambio.indice
    var nueva_posicion = cambio.posicion_nueva
    
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

func _encontrar_camino_por_nombre(nombre: String) -> Path3D:
    for camino in caminos:
        if camino.name == nombre:
            return camino
    return null