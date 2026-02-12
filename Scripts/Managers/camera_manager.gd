extends Node
class_name CameraManager


# ############################################################
# Variables
# ############################################################

signal state_changed(old_state, new_state)
signal state_reached(state)

const STATE_FOLLOW := 0
const STATE_OVERVIEW := 1
const STATE_LOOK_AT := 2
const STATE_LOOK_AT_FROM_SKY := 3

@export_group("General")
@export var smooth: float = 6.0
@export var fov: float = 70.0
@export var fov_smooth: float = 6.0

@export_group("Camera")
@export var camera: Camera3D

@export_group("Follow")
@export var follow_offset: Vector3 = Vector3(0, 2, -4)
@export var follow_look_at_offset: Vector3 = Vector3(0, 1, 0)

@export_group("Overview")
@export var overview_center: Vector3 = Vector3.ZERO
@export var overview_use_position: bool = false
@export var overview_position: Vector3 = Vector3(0, 12, 0)
@export var overview_distance: float = 18.0
@export var overview_pitch: float = 75.0
@export var overview_yaw: float = 0.0

@export_group("Look At")
@export var look_at_position_offset: Vector3 = Vector3.ZERO
@export var look_at_rotation_deg_offset: Vector3 = Vector3.ZERO
@export var look_at_from_sky_position_offset: Vector3 = Vector3(0, 8, 0)
@export var look_at_from_sky_rotation_deg_offset: Vector3 = Vector3.ZERO

var state: int = STATE_OVERVIEW
var target_player: Node3D = null

var _transitioning_to_state: int = -1
var _state_reached_emitted: bool = false

var _has_look_at_override: bool = false
var _look_at_tf: Transform3D = Transform3D()
var _has_look_at_from_sky_override: bool = false
var _look_at_from_sky_tf: Transform3D = Transform3D()


# ############################################################
# Funciones
# ############################################################

func _ready() -> void:
	if camera == null:
		push_warning("😢 No se ha asignado ninguna camara")
	# Asegurar FOV inicial
	if camera != null:
		camera.fov = fov

func set_target_player(p: Node3D) -> void:
	target_player = p

func set_state(new_state: int, look_position: Vector3 = Vector3.ZERO, look_rotation_deg: Vector3 = Vector3.ZERO, immediate: bool = false) -> void:
	var old = state
	state = new_state
	if old != new_state:
		emit_signal("state_changed", old, new_state)

	_transitioning_to_state = new_state
	_state_reached_emitted = false
	_has_look_at_override = false

	if new_state == STATE_LOOK_AT:
		if look_position == Vector3.ZERO:
			push_warning("😢 No hay posicion objetivo para LOOK_AT.")
		else:
			var target_pos: Vector3 = look_position
			var cam_origin: Vector3 = target_pos + look_at_position_offset
			var tf := Transform3D()
			tf.origin = cam_origin
			tf = tf.looking_at(target_pos, Vector3.UP)
			var euler_rad = tf.basis.get_euler()
			var euler_deg = Vector3(rad_to_deg(euler_rad.x), rad_to_deg(euler_rad.y), rad_to_deg(euler_rad.z))
			if look_rotation_deg != Vector3.ZERO:
				euler_deg += look_rotation_deg
			euler_deg += look_at_rotation_deg_offset
			var rot = _basis_from_euler_deg(euler_deg)
			_look_at_tf = Transform3D()
			_look_at_tf.basis = rot
			_look_at_tf.origin = cam_origin
			_has_look_at_override = true

	if new_state == STATE_LOOK_AT_FROM_SKY:
		if look_position == Vector3.ZERO:
			push_warning("😢 No hay posicion objetivo para LOOK_AT_FROM_SKY.")
		else:
			var target_pos: Vector3 = look_position
			var cam_origin: Vector3 = target_pos + look_at_from_sky_position_offset
			var tf := Transform3D()
			tf.origin = cam_origin
			tf = tf.looking_at(target_pos, Vector3.UP)
			var euler_rad = tf.basis.get_euler()
			var euler_deg = Vector3(rad_to_deg(euler_rad.x), rad_to_deg(euler_rad.y), rad_to_deg(euler_rad.z))
			if look_rotation_deg != Vector3.ZERO:
				euler_deg += look_rotation_deg
			euler_deg += look_at_from_sky_rotation_deg_offset
			var rot = _basis_from_euler_deg(euler_deg)
			_look_at_from_sky_tf = Transform3D()
			_look_at_from_sky_tf.basis = rot
			_look_at_from_sky_tf.origin = cam_origin
			_has_look_at_from_sky_override = true

	if camera == null:
		_state_reached_emitted = true
		_transitioning_to_state = -1
		emit_signal("state_reached", state)
		return

	if immediate:
		_update_camera(1.0, true)
		if _state_reached_emitted:
			_transitioning_to_state = -1
			return

	while true:
		var reached_state = await self.state_reached
		if reached_state == new_state:
			return

func _process(delta: float) -> void:
	if camera == null:
		return
	_update_camera(delta, false)

func _update_camera(delta: float, immediate: bool) -> void:
	var desired_tf: Transform3D = Transform3D()
	var target_fov = fov

	if state == STATE_FOLLOW and target_player != null:
		var desired_pos = target_player.global_transform.origin + follow_offset
		var desired_look_at = target_player.global_transform.origin + follow_look_at_offset
		if desired_pos.distance_to(desired_look_at) < 0.01:
			desired_look_at.y += 0.01
		desired_tf.origin = desired_pos
		desired_tf = desired_tf.looking_at(desired_look_at, Vector3.UP)
	elif state == STATE_LOOK_AT and _has_look_at_override:
		desired_tf = _look_at_tf
	elif state == STATE_LOOK_AT_FROM_SKY and _has_look_at_from_sky_override:
		desired_tf = _look_at_from_sky_tf
	else:
		if overview_use_position:
			desired_tf.origin = overview_position
			desired_tf = desired_tf.looking_at(overview_center, Vector3.UP)
		else:
			var pitch_r = deg_to_rad(clamp(overview_pitch, 1.0, 89.9))
			var yaw_r = deg_to_rad(overview_yaw)
			var height = sin(pitch_r) * overview_distance
			var horiz = cos(pitch_r) * overview_distance
			var x = sin(yaw_r) * horiz
			var z = - cos(yaw_r) * horiz
			desired_tf.origin = overview_center + Vector3(x, height, z)
			desired_tf = desired_tf.looking_at(overview_center, Vector3.UP)

	if immediate:
		camera.global_transform = desired_tf
		camera.fov = target_fov
		if _transitioning_to_state == state and not _state_reached_emitted:
			_state_reached_emitted = true
			_transitioning_to_state = -1
			emit_signal("state_reached", state)
		return

	var t = clamp(delta * smooth, 0.0, 1.0)
	camera.global_transform = camera.global_transform.interpolate_with(desired_tf, t)
	var fov_t = clamp(delta * fov_smooth, 0.0, 1.0)
	camera.fov = lerp(camera.fov, target_fov, fov_t)

	if _transitioning_to_state == state and not _state_reached_emitted:
		var pos_err = camera.global_transform.origin.distance_to(desired_tf.origin)
		var fov_err = abs(camera.fov - target_fov)
		if pos_err < 0.05 and fov_err < 0.5:
			_state_reached_emitted = true
			_transitioning_to_state = -1
			emit_signal("state_reached", state)

func _basis_from_euler_deg(e: Vector3) -> Basis:
	var b = Basis()
	b = b.rotated(Vector3(1, 0, 0), deg_to_rad(e.x))
	b = b.rotated(Vector3(0, 1, 0), deg_to_rad(e.y))
	b = b.rotated(Vector3(0, 0, 1), deg_to_rad(e.z))
	return b

func clear_look_at_override() -> void:
	# Limpia las sobrescrituras LOOK_AT para que la cámara vuelva a comportarse según su estado actual.
	_has_look_at_override = false
	_has_look_at_from_sky_override = false
