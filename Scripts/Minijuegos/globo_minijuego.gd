extends MinijuegoBase


# Variables
# ---------------------------------------------------------------------------------------
@export var spawn_globo_escena: PackedScene
@export var spawn_center: Node3D
@export var spawn_elements_center: Node3D
@export var spawn_spacing: float = 2.5
@export var label_cuenta_atras: Label

const PUMP_AMOUNT: float = 0.02
const ESCALA_MAX: float = 3.5

# estados[nombre] = { fill, umbral, explotado, globo_mesh }
var estados: Dictionary = {}
var spawn_globos_instanciados: Array = []
var tension_players: Dictionary = {}


# Override: instanciar jugadores desde GameData
# ---------------------------------------------------------------------------------------
func _instanciar_jugadores() -> void:
	if jugador_escena == null:
		print("Error: jugador_escena no asignado en Globo")
		return
	if spawn_globo_escena == null:
		print("Error: spawn_globo_escena no asignado en Globo")
		return

	var n = GameData.jugadores_data.size()
	var player_center = spawn_center.global_position if spawn_center else Vector3.ZERO
	var player_right = spawn_center.global_transform.basis.x.normalized() if spawn_center else Vector3.RIGHT
	var element_center = spawn_elements_center.global_position if spawn_elements_center else Vector3.ZERO
	var element_right = spawn_elements_center.global_transform.basis.x.normalized() if spawn_elements_center else Vector3.RIGHT

	for i in range(n):
		var sg = spawn_globo_escena.instantiate()
		add_child(sg)
		var offset = (i - (n - 1) * 0.5) * spawn_spacing
		sg.global_position = element_center + element_right * offset
		if spawn_elements_center:
			sg.rotation = spawn_elements_center.rotation
		spawn_globos_instanciados.append(sg)

		var d = GameData.jugadores_data[i]
		var j = jugador_escena.instantiate()
		j.configurar(d.nombre, d.color)
		j.device_id = d.device_id
		add_child(j)
		j.global_position = player_center + player_right * offset
		j.rotation_degrees = Vector3.ZERO
		j.last_pos = j.global_position
		jugadores_instanciados.append(j)


# Override: tutorial especifico del globo
# ---------------------------------------------------------------------------------------
func _mostrar_tutorial() -> void:
	await _mostrar_tutorial_texto(tr("KEY_MINIJUEGO_GLOBO_DESC"))


# Override: iniciar logica del globo
# ---------------------------------------------------------------------------------------
func _iniciar_minijuego() -> void:
	for i in range(jugadores_instanciados.size()):
		var j = jugadores_instanciados[i]
		var ball: Node3D = null
		if i < spawn_globos_instanciados.size():
			ball = spawn_globos_instanciados[i].get_node_or_null("Ball")
		if ball:
			ball.scale = Vector3.ZERO
		estados[j.nombre] = {
			"fill": 0.0,
			"umbral": randf_range(0.7, 0.97),
			"explotado": false,
			"pressing": false,
			"tension_played": false,
			"globo_mesh": ball
		}
	if label_timer:
		label_timer.visible = false
	if label_cuenta_atras:
		label_cuenta_atras.visible = true
	await _countdown()
	_countdown_finish()
	activo = true


func _press_spawn_button(spawn: Node3D) -> void:
	var button = spawn.get_node_or_null("Button")
	if button == null:
		return
	if not button.has_meta("base_y"):
		button.set_meta("base_y", button.position.y)
	var base_y: float = button.get_meta("base_y")
	var pressed_y = base_y - 0.05
	var tween = button.create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(button, "position:y", pressed_y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.1)
	tween.tween_property(button, "position:y", base_y, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

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
	SoundManager.play_music(SoundManager.MUSIC_GLOBO_MINIJUEGO)
	if label_cuenta_atras:
		label_cuenta_atras.visible = false
	if label_timer:
		label_timer.visible = true


# Process: verificar si todos explotaron o solo queda uno vivo
# ---------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	super._process(delta)
	if activo and estados.size() > 0:
		var vivos = 0
		for nombre in estados:
			if not estados[nombre].explotado:
				vivos += 1
		if vivos == 0 or (vivos == 1 and estados.size() > 1):
			_terminar_minijuego()


# Input
# ---------------------------------------------------------------------------------------
func _on_device_action(device_id, action: String) -> void:
	var era_tutorial = en_tutorial
	super._on_device_action(device_id, action)
	if era_tutorial or not activo or action != "ui_accept":
		return
	var j = _get_jugador_por_device(device_id)
	if j == null:
		return
	var nombre = j.nombre
	if estados[nombre].explotado or estados[nombre].pressing:
		return
	estados[nombre].pressing = true
	var idx = jugadores_instanciados.find(j)
	if idx >= 0 and idx < spawn_globos_instanciados.size():
		_press_spawn_button(spawn_globos_instanciados[idx])
	SoundManager.play_sfx(SoundManager.SFX_GLOBO_BOMBA)
	j.set_interact_state(true)
	estados[nombre].fill = min(estados[nombre].fill + PUMP_AMOUNT, 1.0)
	_actualizar_visual(nombre)
	if not estados[nombre].tension_played and estados[nombre].fill >= estados[nombre].umbral * 0.75:
		estados[nombre].tension_played = true
		tension_players[nombre] = SoundManager.play_sfx_looping(SoundManager.SFX_GLOBO_TENSION)
	if estados[nombre].fill >= estados[nombre].umbral:
		_explotar(nombre, j)
	await get_tree().create_timer(0.5).timeout
	estados[nombre].pressing = false


# Logica del globo
# ---------------------------------------------------------------------------------------
func _actualizar_visual(nombre: String) -> void:
	var estado = estados[nombre]
	var ball: Node3D = estado.globo_mesh
	if ball == null:
		return
	var escala_obj = estado.fill * ESCALA_MAX
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ball, "scale", Vector3(escala_obj, escala_obj, escala_obj), 0.15)

func _explotar(nombre: String, jugador: Node3D) -> void:
	estados[nombre].fill = -1.0
	estados[nombre].explotado = true
	var ball: Node3D = estados[nombre].globo_mesh
	if ball:
		var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(ball, "scale", Vector3(ESCALA_MAX * 1.4, ESCALA_MAX * 1.4, ESCALA_MAX * 1.4), 0.1)
		tween.tween_property(ball, "scale", Vector3.ZERO, 0.15)
	SoundManager.play_sfx(SoundManager.SFX_GLOBO_EXPLOTAR)
	jugador.set_interact_state(true)
	print("💥 Globo de ", nombre, " ha explotado!")


# Override: ranking por fill descendente, explotados al final
# ---------------------------------------------------------------------------------------
func _terminar_minijuego() -> void:
	for nombre in tension_players:
		SoundManager.stop_sfx_player(tension_players[nombre])
	tension_players.clear()
	super._terminar_minijuego()

func _calcular_resultados() -> Array:
	var lista = []
	for nombre in estados:
		lista.append({"nombre": nombre, "fill": estados[nombre].fill})
	lista.sort_custom(func(a, b):
		if a.fill < 0.0:
			return false
		if b.fill < 0.0:
			return true
		return a.fill > b.fill
	)
	return lista
