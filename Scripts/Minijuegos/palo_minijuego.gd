extends MinijuegoBase


# Variables
# ---------------------------------------------------------------------------------------
@export var palo: Node3D
@export var spawn_altura: Node3D
@export var spawn_escena: PackedScene
@export var radio_spawn: float = 5.0
@export var label_cuenta_atras: Label
@export var velocidad_inicial: float = 60.0
@export var aceleracion: float = 8.0
@export var palo_pitch_min: float = 0.8
@export var palo_pitch_max: float = 2.5
@export var palo_pitch_ramp_time: float = 90.0

var velocidad_actual: float = 0.0
var palo_pitch_time: float = 0.0
var eliminados: Array = []
var en_cuenta_atras: bool = false
var palo_giro_player: AudioStreamPlayer = null


# Override: instanciar jugadores y plataformas de spawn alrededor del palo
# ---------------------------------------------------------------------------------------
func _instanciar_jugadores() -> void:
	if jugador_escena == null:
		print("Error: jugador_escena no asignado en Palo")
		return
	if spawn_escena == null:
		print("Error: spawn_escena no asignado en Palo")
		return
	var n = GameData.jugadores_data.size()
	var centro = palo.global_position if palo else Vector3.ZERO
	var altura_y = spawn_altura.global_position.y if spawn_altura else centro.y
	for i in range(n):
		var angulo = deg_to_rad(i * 360.0 / n + 45.0)
		var offset = Vector3(sin(angulo) * radio_spawn, 0.0, cos(angulo) * radio_spawn)
		var spawn_inst = spawn_escena.instantiate()
		add_child(spawn_inst)
		spawn_inst.global_position = Vector3(centro.x + offset.x, altura_y, centro.z + offset.z)
		spawn_inst.rotation_degrees.y = rad_to_deg(angulo)
		var player_spawn = spawn_inst.get_node("PlayerSpawn")
		var d = GameData.jugadores_data[i]
		var j = jugador_escena.instantiate()
		j.configurar(d.nombre, d.color)
		j.device_id = d.device_id
		add_child(j)
		j.global_position = player_spawn.global_position
		jugadores_instanciados.append(j)


# Override: tutorial especifico del palo
# ---------------------------------------------------------------------------------------
func _mostrar_tutorial() -> void:
	await _mostrar_tutorial_texto(tr("KEY_MINIJUEGO_PALO_DESC"))


# Override: iniciar logica del palo con cuenta atras animada
# ---------------------------------------------------------------------------------------
func _iniciar_minijuego() -> void:
	if palo and jugadores_instanciados.size() > 0:
		palo.rotation_degrees.y = 360.0 / (2.0 * jugadores_instanciados.size())
	var area = palo.get_node_or_null("Area3D")
	if area:
		area.body_entered.connect(_on_palo_body_entered)
	if label_timer:
		label_timer.visible = false
	if label_cuenta_atras:
		label_cuenta_atras.visible = true
	en_cuenta_atras = true
	await _countdown()
	en_cuenta_atras = false
	_countdown_finish()
	velocidad_actual = velocidad_inicial
	palo_pitch_time = 0.0
	activo = true
	palo_giro_player = SoundManager.play_sfx_looping(SoundManager.SFX_PALO_GIRO_LOOP)

func _countdown() -> void:
	if label_cuenta_atras == null:
		await get_tree().create_timer(3.0).timeout
		return
	await get_tree().process_frame
	for numero in [3, 2, 1]:
		label_cuenta_atras.text = str(numero)
		label_cuenta_atras.pivot_offset = label_cuenta_atras.size / 2.0
		label_cuenta_atras.scale = Vector2(2.5, 2.5)
		SoundManager.play_sfx(SoundManager.SFX_COUNTDOWN)
		var tween = create_tween()
		tween.tween_property(label_cuenta_atras, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_interval(0.3)
		tween.tween_property(label_cuenta_atras, "scale", Vector2(0.2, 0.2), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tween.finished
	label_cuenta_atras.scale = Vector2(1.0, 1.0)
	label_cuenta_atras.visible = false

func _countdown_finish() -> void:
	SoundManager.play_sfx(SoundManager.SFX_COUNTDOWN_FINISH)
	SoundManager.play_music(SoundManager.MUSIC_PALO_MINIJUEGO)
	if label_cuenta_atras:
		label_cuenta_atras.visible = false
	if label_timer:
		label_timer.visible = true


# Process: rotar palo y condicion de victoria
# ---------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	super._process(delta)
	if not activo:
		if palo_giro_player:
			SoundManager.stop_sfx_player(palo_giro_player)
			palo_giro_player = null
		return
	if palo:
		velocidad_actual += aceleracion * delta
		palo.rotation_degrees.y += velocidad_actual * delta
		if palo_giro_player:
			palo_pitch_time = min(palo_pitch_ramp_time, palo_pitch_time + delta)
			var pitch_ratio = palo_pitch_time / palo_pitch_ramp_time
			palo_giro_player.pitch_scale = lerp(palo_pitch_min, palo_pitch_max, pitch_ratio)
	if jugadores_instanciados.size() > 0 and _vivos().size() <= 1:
		_terminar_minijuego()

func _on_palo_body_entered(body: Node3D) -> void:
	if not activo:
		return
	for j in jugadores_instanciados:
		if j == body and j.nombre not in eliminados:
			_eliminar_jugador(j)
			break

func _eliminar_jugador(jugador: Node3D) -> void:
	if jugador.nombre in eliminados:
		return
	eliminados.append(jugador.nombre)
	SoundManager.play_sfx(SoundManager.SFX_PALO_ELIMINAR)
	jugador.set_on_air(true)
	jugador.iniciar_explosion()
	print("❌ ", jugador.nombre, " eliminado!")
	var dir = jugador.global_position - palo.global_position
	dir.y = 0
	if dir.length() < 0.01:
		dir = Vector3(1, 0, 0)
	dir = dir.normalized()
	var pos_inicio = jugador.global_position
	var pos_vuelo = pos_inicio + dir * 2.5 + Vector3(0, 1.0, 0)
	var pos_caida = pos_vuelo + Vector3(0, -10.0, 0)
	var t = jugador.create_tween()
	t.tween_property(jugador, "global_position", pos_vuelo, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(jugador, "global_position", pos_caida, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.finished.connect(func(): jugador.visible = false, CONNECT_ONE_SHOT)


# Input: saltar
# ---------------------------------------------------------------------------------------
func _on_device_action(device_id, action: String) -> void:
	var era_tutorial = en_tutorial
	super._on_device_action(device_id, action)
	if era_tutorial or (not activo and not en_cuenta_atras) or action != "ui_accept":
		return
	var j = _get_jugador_por_device(device_id)
	if j == null or j.nombre in eliminados:
		return
	_saltar_jugador(j)

func _saltar_jugador(jugador: Node3D) -> void:
	if jugador.on_air:
		return
	SoundManager.play_sfx(SoundManager.SFX_SALTO_IMPULSO)
	jugador.set_on_air(true)
	jugador.set_jumping_insta_state()
	var pos_base = jugador.global_position
	var pos_arriba = pos_base + Vector3(0, 1.5, 0)
	var t = jugador.create_tween()
	t.tween_property(jugador, "global_position", pos_arriba, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(jugador, "global_position", pos_base, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.finished.connect(func(): jugador.set_on_air(false), CONNECT_ONE_SHOT)


# Utilidades
# ---------------------------------------------------------------------------------------
func _vivos() -> Array:
	var vivos = []
	for j in jugadores_instanciados:
		if j.nombre not in eliminados:
			vivos.append(j)
	return vivos


# Override: ganadores primero, luego eliminados en orden inverso (ultimo eliminado = mejor posicion)
# ---------------------------------------------------------------------------------------
func _calcular_resultados() -> Array:
	var resultado = []
	for v in _vivos():
		resultado.append({"nombre": v.nombre})
	for i in range(eliminados.size() - 1, -1, -1):
		resultado.append({"nombre": eliminados[i]})
	return resultado
