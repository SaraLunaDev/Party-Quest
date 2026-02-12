extends Label3D


# ############################################################
# Logica
# ############################################################

func _process(_delta):
	var cam = get_viewport().get_camera_3d()
	if cam:
		look_at(cam.global_transform.origin, Vector3.UP)
		rotate_y(PI)
