extends Node

const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"
# Musica
const MUSIC_MAIN_MENU = preload("res://Audio/Music/mainmenu.mp3")
const MUSIC_TUTORIAL_MINIJUEGO = preload("res://Audio/Music/tutorial_minigame.mp3")
const MUSIC_GLOBO_MINIJUEGO = preload("res://Audio/Music/globo_minigame.mp3")
const MUSIC_PALO_MINIJUEGO = preload("res://Audio/Music/palo_minigame.mp3")
const MUSIC_TABLERO = preload("res://Audio/Music/tablero.mp3")
var music_player: AudioStreamPlayer
var music_volume: float = 10.0
var sfx_volume: float = 80.0
var sfx_sound_volumes: Dictionary = {}
var music_track_volumes: Dictionary = {}


# SFX precargados
# ---------------------------------------------------------------------------------------
#region
# UI
const SFX_UI_HOVER = preload("res://Audio/SFX/ui_hover.mp3")
const SFX_UI_CONFIRM = preload("res://Audio/SFX/ui_confirm.mp3")
const SFX_UI_BACK = preload("res://Audio/SFX/ui_back.mp3")
const SFX_UI_CHARACTER = preload("res://Audio/SFX/ui_character.mp3")

# Dado
const SFX_DADO_GIRAR = preload("res://Audio/SFX/dado_girando.mp3")
const SFX_DADO_RESULTADO = preload("res://Audio/SFX/dado_resultado.wav")

# Movimiento
const SFX_PASO_CASILLA = preload("res://Audio/SFX/paso_casilla.wav")
const SFX_SALTO_IMPULSO = preload("res://Audio/SFX/salto_impulso.wav")
const SFX_SALTO_ATERRIZAJE = preload("res://Audio/SFX/salto_aterrizaje.wav")

# Tablero - anuncios
const SFX_ANUNCIO_RONDA = preload("res://Audio/SFX/anuncio_ronda.wav")
const SFX_ANUNCIO_MINIJUEGO = preload("res://Audio/SFX/anuncio_minijuego.wav")
const SFX_COUNTDOWN = preload("res://Audio/SFX/countdown.wav")
const SFX_COUNTDOWN_FINISH = preload("res://Audio/SFX/countdown_finish.wav")

# Bifurcacion
const SFX_BIFURCACION_FLECHA = preload("res://Audio/SFX/bifurcacion_flecha.wav")
const SFX_BIFURCACION_NAVEGAR = preload("res://Audio/SFX/bifurcacion_navegar.mp3")
const SFX_BIFURCACION_CONFIRMAR = preload("res://Audio/SFX/bifurcacion_confirmar.mp3")

# Casillas
const SFX_TRAMPILLA_ABRIR = preload("res://Audio/SFX/trampilla_abrir.wav")
const SFX_TRAMPILLA_CERRAR = preload("res://Audio/SFX/trampilla_cerrar.wav")
const SFX_CASILLA_BATERIA_APARECE = preload("res://Audio/SFX/casilla_bateria_aparece.wav")
const SFX_CASILLA_PRESIONAR = preload("res://Audio/SFX/casilla_presionar.wav")
const SFX_CASILLA_SOLTAR = preload("res://Audio/SFX/casilla_soltar.wav")

# Minijuego: Palo
const SFX_PALO_GIRO_LOOP = preload("res://Audio/SFX/palo_giro_loop.wav")
const SFX_PALO_ELIMINAR = preload("res://Audio/SFX/palo_eliminar_jugador.wav")
const SFX_JUGADOR_CHIPS = preload("res://Audio/SFX/jugador_chips.wav")

# Minijuego: Globo
const SFX_GLOBO_BOMBA = preload("res://Audio/SFX/globo_bomba.wav")
const SFX_GLOBO_EXPLOTAR = preload("res://Audio/SFX/globo_explotar.mp3")
const SFX_GLOBO_TENSION = preload("res://Audio/SFX/globo_tension.wav")

# Jugador
const SFX_JUGADOR_UNIRSE = preload("res://Audio/SFX/jugador_unirse.mp3")
const SFX_JUGADOR_DAÑO = preload("res://Audio/SFX/jugador_daño.mp3")
const SFX_JUGADOR_MOVER = [
	preload("res://Audio/SFX/jugador_mover.wav"),
	preload("res://Audio/SFX/jugador_mover2.wav"),
	preload("res://Audio/SFX/jugador_mover3.wav")
]
#endregion


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)

	_apply_music_volume(music_volume)
	_apply_sfx_volume(sfx_volume)

	set_sfx_sound_volume(SFX_CASILLA_BATERIA_APARECE, 10.0)
	set_sfx_sound_volume(SFX_JUGADOR_UNIRSE, 40.0)
	set_sfx_sound_volume(SFX_JUGADOR_DAÑO, 40.0)
	set_sfx_sound_volume(SFX_UI_CHARACTER, 50.0)
	set_sfx_sound_volume(SFX_DADO_GIRAR, 40.0)
	set_sfx_sound_volume(SFX_DADO_RESULTADO, 10.0)
	set_sfx_sound_volume(SFX_PASO_CASILLA, 30.0)
	set_sfx_sound_volume(SFX_TRAMPILLA_ABRIR, 50.0)
	set_sfx_sound_volume(SFX_TRAMPILLA_CERRAR, 50.0)
	set_sfx_sound_volume(SFX_SALTO_IMPULSO, 20.0)
	set_sfx_sound_volume(SFX_SALTO_ATERRIZAJE, 30.0)
	set_sfx_sound_volume(SFX_JUGADOR_MOVER, 10.0)
	set_sfx_sound_volume(SFX_GLOBO_BOMBA, 10.0)
	set_sfx_sound_volume(SFX_CASILLA_PRESIONAR, 10.0)
	set_sfx_sound_volume(SFX_CASILLA_SOLTAR, 10.0)
	set_sfx_sound_volume(SFX_GLOBO_TENSION, 40.0)
	set_sfx_sound_volume(SFX_PALO_GIRO_LOOP, 20.0)
	set_sfx_sound_volume(SFX_PALO_ELIMINAR, 30.0)
	set_sfx_sound_volume(SFX_JUGADOR_CHIPS, 40.0)
	set_sfx_sound_volume(SFX_GLOBO_EXPLOTAR, 35.0)
	set_sfx_sound_volume(SFX_COUNTDOWN, 35.0)
	set_sfx_sound_volume(SFX_COUNTDOWN_FINISH, 40.0)
	set_sfx_sound_volume(SFX_ANUNCIO_RONDA, 40.0)
	set_sfx_sound_volume(SFX_ANUNCIO_MINIJUEGO, 40.0)
	set_music_track_volume(MUSIC_MAIN_MENU, 60.0)
	set_music_track_volume(MUSIC_GLOBO_MINIJUEGO, 60.0)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


# Musica
# ---------------------------------------------------------------------------------------
#region
func play_music(stream: AudioStream, vol: float = -1.0) -> void:
	if not stream:
		return
	if music_player.stream == stream and music_player.playing:
		music_player.volume_db = linear_to_db(_resolve_music_volume(stream, vol) / 100.0)
		return
	music_player.stream = stream
	music_player.volume_db = linear_to_db(_resolve_music_volume(stream, vol) / 100.0)
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func set_music_volume(value: float) -> void:
	music_volume = value
	_apply_music_volume(value)

func _apply_music_volume(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(MUSIC_BUS)
	if bus_idx == -1:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func set_music_track_volume(stream, value: float) -> void:
	if not stream:
		return
	if stream is Array:
		for item in stream:
			if item:
				music_track_volumes[item.resource_path] = clamp(value, 0.0, 100.0)
		return
	music_track_volumes[stream.resource_path] = clamp(value, 0.0, 100.0)

func _resolve_music_volume(stream, override: float = -1.0) -> float:
	if override >= 0.0:
		return clamp(override, 0.0, 100.0)
	if stream is Array:
		for item in stream:
			if item and music_track_volumes.has(item.resource_path):
				return music_track_volumes[item.resource_path]
		return 100.0
	if music_track_volumes.has(stream.resource_path):
		return music_track_volumes[stream.resource_path]
	return 100.0
#endregion


# Efectos de Sonido
# ---------------------------------------------------------------------------------------
#region
func _resolve_stream(stream) -> AudioStream:
	if not stream:
		return null
	if stream is Array:
		if stream.size() == 0:
			return null
		return stream[randi() % stream.size()]
	return stream

func play_sfx(stream, vol: float = -1.0, pitch_scale: float = 1.0) -> void:
	var resolved_stream = _resolve_stream(stream)
	if not resolved_stream:
		return
	var player = AudioStreamPlayer.new()
	player.stream = resolved_stream
	player.bus = SFX_BUS
	player.volume_db = linear_to_db(_resolve_sound_volume(stream, vol) / 100.0)
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_sfx_looping(stream, vol: float = -1.0, pitch_scale: float = 1.0, loop_delay: float = 0.0, loop_pitch_variation: float = 0.0) -> AudioStreamPlayer:
	var resolved_stream = _resolve_stream(stream)
	if not resolved_stream:
		return null
	var player = AudioStreamPlayer.new()
	player.stream = resolved_stream
	player.bus = SFX_BUS
	player.volume_db = linear_to_db(_resolve_sound_volume(stream, vol) / 100.0)
	player.pitch_scale = pitch_scale
	add_child(player)
	# Custom loop with delay (assign to var for Godot compatibility)
	var _loop_with_delay = func():
		await get_tree().create_timer(loop_delay).timeout
		if is_instance_valid(player) and player.is_inside_tree() and player.playing == false:
			player.stream = _resolve_stream(stream)
			if loop_pitch_variation > 0.0:
				player.pitch_scale = pitch_scale + randf_range(-loop_pitch_variation, loop_pitch_variation)
			player.play()
	player.finished.connect(_loop_with_delay)
	player.play()
	return player

func stop_sfx_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	if player.is_inside_tree():
		player.stop()
		player.queue_free()

func set_sfx_sound_volume(stream, value: float) -> void:
	if not stream:
		return
	if stream is Array:
		for item in stream:
			if item:
				sfx_sound_volumes[item.resource_path] = clamp(value, 0.0, 100.0)
		return
	sfx_sound_volumes[stream.resource_path] = clamp(value, 0.0, 100.0)

func _resolve_sound_volume(stream, override: float) -> float:
	if override >= 0.0:
		return clamp(override, 0.0, 100.0)
	if stream is Array:
		for item in stream:
			if item and sfx_sound_volumes.has(item.resource_path):
				return sfx_sound_volumes[item.resource_path]
		return 100.0
	if sfx_sound_volumes.has(stream.resource_path):
		return sfx_sound_volumes[stream.resource_path]
	return 100.0

func set_sfx_volume(value: float) -> void:
	sfx_volume = value
	_apply_sfx_volume(value)

func _apply_sfx_volume(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(SFX_BUS)
	if bus_idx == -1:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
#endregion
