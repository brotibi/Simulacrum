class_name SimulacrumBuilder
extends RefCounted

const OBJECTS_JSON_DIR := "res://content/objects"
const OBJECTS_SCENE_DIR := "res://scenes/objects"
const ROOMS_JSON_DIR := "res://content/rooms"
const ROOMS_SCENE_DIR := "res://scenes/rooms"

const PS1_SURFACE_SHADER_PATH := "res://shaders/ps1_surface.gdshader"
const PS1_POST_SHADER_PATH := "res://shaders/ps1_post_process.gdshader"

static var _tex_cache: Dictionary = {}


static func ensure_directories() -> void:
	for dir_path in [OBJECTS_JSON_DIR, OBJECTS_SCENE_DIR, ROOMS_JSON_DIR, ROOMS_SCENE_DIR, "res://assets/textures", "res://assets/models"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


static func default_material_config() -> Dictionary:
	return {
		"albedo_color": [0.72, 0.70, 0.66, 1.0],
		"texture_mode": "procedural_concrete",
		"custom_texture_path": "",
		"uv_scale": [2.0, 2.0],
		"uv_offset": [0.0, 0.0],
		"vertex_snap_enabled": true,
		"snap_resolution": [213.0, 120.0],
		"affine_amount": 1.0,
		"vertex_darkening_start": 4.0,
		"vertex_darkening_end": 18.0
	}


static func default_part_config(part_name: String = "Part_1") -> Dictionary:
	return {
		"name": part_name,
		"shape": "box", # box, cylinder, sphere, prism, plane, custom_model
		"model_path": "",
		"size": [1.0, 1.0, 1.0],
		"subdivide": 2,
		"position": [0.0, 0.5, 0.0],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"collision": true,
		"material": default_material_config()
	}


static func default_object_config(obj_name: String = "rusty_crate") -> Dictionary:
	return {
		"name": obj_name,
		"parts": [default_part_config("BaseMesh")],
		"light": {
			"enabled": false,
			"type": "omni", # omni or spot
			"color": [0.95, 0.80, 0.55],
			"energy": 1.2,
			"range": 6.0,
			"position": [0.0, 1.2, 0.0]
		}
	}


static func default_room_config(room_name: String = "corridor_01") -> Dictionary:
	var floor_mat := default_material_config()
	floor_mat["albedo_color"] = [0.38, 0.36, 0.34, 1.0]
	floor_mat["texture_mode"] = "procedural_tiles"
	floor_mat["uv_scale"] = [8.0, 12.0]

	var wall_mat := default_material_config()
	wall_mat["albedo_color"] = [0.46, 0.43, 0.38, 1.0]
	wall_mat["texture_mode"] = "procedural_concrete"
	wall_mat["uv_scale"] = [8.0, 3.0]

	var ceil_mat := default_material_config()
	ceil_mat["albedo_color"] = [0.30, 0.29, 0.28, 1.0]
	ceil_mat["texture_mode"] = "procedural_concrete"
	ceil_mat["uv_scale"] = [6.0, 8.0]

	return {
		"name": room_name,
		"dimensions": [10.0, 4.0, 14.0],
		"has_floor": true,
		"has_ceiling": true,
		"floor_thickness": 0.4,
		"ceiling_thickness": 0.4,
		"floor_y_offset": 0.0,
		"ceiling_y_offset": 0.0,
		"floor_subdivide": 6,
		"ceiling_subdivide": 6,
		"wall_north": true,
		"wall_south": true,
		"wall_east": true,
		"wall_west": true,
		"subdivide": 6,
		"skybox": {
			"mode": "procedural_sky", # solid_color, procedural_sky, custom_panorama
			"background_color": [0.10, 0.11, 0.13],
			"sky_top_color": [0.06, 0.07, 0.10],
			"sky_horizon_color": [0.22, 0.24, 0.27],
			"ground_horizon_color": [0.16, 0.17, 0.19],
			"ground_bottom_color": [0.05, 0.05, 0.06],
			"sky_energy": 0.85,
			"panorama_path": ""
		},
		"fog_enabled": true,
		"fog_color": [0.14, 0.15, 0.16],
		"fog_density": 0.14,
		"ambient_color": [0.18, 0.19, 0.21],
		"ambient_energy": 0.65,
		"player_spawn": [0.0, 0.1, 4.0],
		"floor_material": floor_mat,
		"wall_material": wall_mat,
		"ceiling_material": ceil_mat,
		"items": [],
		"lights": [
			{
				"name": "CeilingLight_1",
				"position": [0.0, 3.4, 0.0],
				"color": [0.85, 0.72, 0.52],
				"energy": 1.0,
				"range": 9.0
			}
		]
	}


static func get_procedural_texture(mode: String) -> Texture2D:
	if _tex_cache.has(mode):
		return _tex_cache[mode]

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.09

	match mode:
		"none":
			img.fill(Color.WHITE)
		"procedural_concrete":
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			for y in 64:
				for x in 64:
					var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
					var v := lerpf(0.55, 0.95, n)
					img.set_pixel(x, y, Color(v, v, v, 1.0))
		"procedural_rust":
			noise.noise_type = FastNoiseLite.TYPE_PERLIN
			noise.frequency = 0.14
			for y in 64:
				for x in 64:
					var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
					var c := Color(0.45, 0.22, 0.14).lerp(Color(0.82, 0.48, 0.28), n)
					img.set_pixel(x, y, c)
		"procedural_bricks":
			for y in 64:
				for x in 64:
					var row := y / 16
					var offset := (row % 2) * 16
					var bx := (x + offset) % 32
					var by := y % 16
					if bx < 2 or by < 2:
						img.set_pixel(x, y, Color(0.32, 0.30, 0.28))
					else:
						var n := (noise.get_noise_2d(x * 1.5, y * 1.5) + 1.0) * 0.5
						var v := lerpf(0.60, 0.88, n)
						img.set_pixel(x, y, Color(v, v * 0.85, v * 0.78))
		"procedural_tiles":
			for y in 64:
				for x in 64:
					var tx := x % 16
					var ty := y % 16
					if tx == 0 or ty == 0:
						img.set_pixel(x, y, Color(0.22, 0.22, 0.24))
					else:
						var checker := ((x / 16) + (y / 16)) % 2
						var base := 0.82 if checker == 0 else 0.64
						var n := noise.get_noise_2d(x, y) * 0.08
						var v := clampf(base + n, 0.1, 1.0)
						img.set_pixel(x, y, Color(v, v, v))
		"procedural_checker":
			for y in 64:
				for x in 64:
					var c := 0.9 if (((x / 8) + (y / 8)) % 2) == 0 else 0.35
					img.set_pixel(x, y, Color(c, c, c))
		"procedural_grate":
			for y in 64:
				for x in 64:
					var gx := x % 8
					var gy := y % 8
					if gx < 2 or gy < 2:
						img.set_pixel(x, y, Color(0.75, 0.76, 0.78))
					else:
						img.set_pixel(x, y, Color(0.12, 0.12, 0.14))
		_:
			img.fill(Color.WHITE)

	var tex := ImageTexture.create_from_image(img)
	_tex_cache[mode] = tex
	return tex


static func load_custom_texture(path: String) -> Texture2D:
	if path.is_empty():
		return get_procedural_texture("none")
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			return res
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return get_procedural_texture("none")


static func build_ps1_material(mat_cfg: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(PS1_SURFACE_SHADER_PATH)

	var col_arr: Array = mat_cfg.get("albedo_color", [0.75, 0.75, 0.75, 1.0])
	var col := Color(
		float(col_arr[0]) if col_arr.size() > 0 else 0.75,
		float(col_arr[1]) if col_arr.size() > 1 else 0.75,
		float(col_arr[2]) if col_arr.size() > 2 else 0.75,
		float(col_arr[3]) if col_arr.size() > 3 else 1.0
	)
	mat.set_shader_parameter("albedo_color", col)

	var tex_mode: String = str(mat_cfg.get("texture_mode", "procedural_concrete"))
	var tex: Texture2D
	if tex_mode == "custom_image":
		tex = load_custom_texture(str(mat_cfg.get("custom_texture_path", "")))
	else:
		tex = get_procedural_texture(tex_mode)
	mat.set_shader_parameter("albedo_texture", tex)

	var uv_s: Array = mat_cfg.get("uv_scale", [1.0, 1.0])
	mat.set_shader_parameter("uv_scale", Vector2(float(uv_s[0]), float(uv_s[1])))

	var uv_o: Array = mat_cfg.get("uv_offset", [0.0, 0.0])
	mat.set_shader_parameter("uv_offset", Vector2(float(uv_o[0]), float(uv_o[1])))

	mat.set_shader_parameter("vertex_snap_enabled", bool(mat_cfg.get("vertex_snap_enabled", true)))

	var snap_res: Array = mat_cfg.get("snap_resolution", [213.0, 120.0])
	mat.set_shader_parameter("snap_resolution", Vector2(float(snap_res[0]), float(snap_res[1])))

	mat.set_shader_parameter("affine_amount", float(mat_cfg.get("affine_amount", 1.0)))
	mat.set_shader_parameter("vertex_darkening_start", float(mat_cfg.get("vertex_darkening_start", 4.0)))
	mat.set_shader_parameter("vertex_darkening_end", float(mat_cfg.get("vertex_darkening_end", 18.0)))

	return mat


static func build_mesh_for_part(part_cfg: Dictionary, material: Material) -> Mesh:
	var shape: String = str(part_cfg.get("shape", "box"))
	var sz_arr: Array = part_cfg.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(
		maxf(float(sz_arr[0]), 0.05),
		maxf(float(sz_arr[1]), 0.05),
		maxf(float(sz_arr[2]), 0.05)
	)
	var subdiv: int = clampi(int(part_cfg.get("subdivide", 2)), 0, 16)

	match shape:
		"box":
			var m := BoxMesh.new()
			m.size = sz
			m.subdivide_width = subdiv
			m.subdivide_height = subdiv
			m.subdivide_depth = subdiv
			m.material = material
			return m
		"cylinder":
			var m := CylinderMesh.new()
			m.top_radius = sz.x * 0.5
			m.bottom_radius = sz.z * 0.5
			m.height = sz.y
			m.radial_segments = maxi(6, (subdiv + 2) * 3)
			m.rings = maxi(1, subdiv)
			m.material = material
			return m
		"sphere":
			var m := SphereMesh.new()
			m.radius = sz.x * 0.5
			m.height = sz.y
			m.radial_segments = maxi(6, (subdiv + 2) * 3)
			m.rings = maxi(3, subdiv + 2)
			m.material = material
			return m
		"prism":
			var m := PrismMesh.new()
			m.size = sz
			m.subdivide_width = subdiv
			m.subdivide_height = subdiv
			m.subdivide_depth = subdiv
			m.material = material
			return m
		"plane":
			var m := PlaneMesh.new()
			m.size = Vector2(sz.x, sz.z)
			m.subdivide_width = subdiv
			m.subdivide_depth = subdiv
			m.material = material
			return m
		"custom_model":
			var model_path: String = str(part_cfg.get("model_path", ""))
			if not model_path.is_empty() and ResourceLoader.exists(model_path):
				var res := load(model_path)
				if res is Mesh:
					var dup: Mesh = res.duplicate()
					for s_idx in dup.get_surface_count():
						dup.surface_set_material(s_idx, material)
					return dup
			var fallback := BoxMesh.new()
			fallback.size = sz
			fallback.material = material
			return fallback
		_:
			var m := BoxMesh.new()
			m.size = sz
			m.material = material
			return m


static func build_collision_shape_for_part(part_cfg: Dictionary) -> Shape3D:
	var shape: String = str(part_cfg.get("shape", "box"))
	var sz_arr: Array = part_cfg.get("size", [1.0, 1.0, 1.0])
	var sz := Vector3(
		maxf(float(sz_arr[0]), 0.05),
		maxf(float(sz_arr[1]), 0.05),
		maxf(float(sz_arr[2]), 0.05)
	)
	match shape:
		"cylinder":
			var s := CylinderShape3D.new()
			s.radius = maxf(sz.x, sz.z) * 0.5
			s.height = sz.y
			return s
		"sphere":
			var s := SphereShape3D.new()
			s.radius = sz.x * 0.5
			return s
		"plane":
			var s := BoxShape3D.new()
			s.size = Vector3(sz.x, 0.08, sz.z)
			return s
		_:
			var s := BoxShape3D.new()
			s.size = sz
			return s


static func _vec3_from_arr(arr: Array, default_val: Vector3 = Vector3.ZERO) -> Vector3:
	if arr.size() < 3:
		return default_val
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)


static func build_object_node(obj_cfg: Dictionary, owner_root: Node = null) -> StaticBody3D:
	var root := StaticBody3D.new()
	root.name = str(obj_cfg.get("name", "CustomObject"))
	var target_owner: Node = owner_root if owner_root != null else root

	var parts: Array = obj_cfg.get("parts", [])
	for idx in parts.size():
		var part_cfg: Dictionary = parts[idx]
		var p_name: String = str(part_cfg.get("name", "Part_%d" % (idx + 1)))
		var pos := _vec3_from_arr(part_cfg.get("position", [0.0, 0.5, 0.0]))
		var rot_deg := _vec3_from_arr(part_cfg.get("rotation", [0.0, 0.0, 0.0]))
		var scl := _vec3_from_arr(part_cfg.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
		var mat := build_ps1_material(part_cfg.get("material", default_material_config()))

		var shape_type: String = str(part_cfg.get("shape", "box"))
		var model_path: String = str(part_cfg.get("model_path", ""))

		if shape_type == "custom_model" and not model_path.is_empty() and ResourceLoader.exists(model_path):
			var loaded_res := load(model_path)
			if loaded_res is PackedScene:
				var inst: Node = (loaded_res as PackedScene).instantiate()
				inst.name = p_name
				if inst is Node3D:
					inst.position = pos
					inst.rotation_degrees = rot_deg
					inst.scale = scl
				_apply_material_recursive(inst, mat)
				root.add_child(inst, true)
				inst.owner = target_owner
				continue

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.name = p_name
		mesh_inst.mesh = build_mesh_for_part(part_cfg, mat)
		mesh_inst.position = pos
		mesh_inst.rotation_degrees = rot_deg
		mesh_inst.scale = scl
		root.add_child(mesh_inst, true)
		mesh_inst.owner = target_owner

		if bool(part_cfg.get("collision", true)):
			var col_node := CollisionShape3D.new()
			col_node.name = p_name + "_Collision"
			col_node.shape = build_collision_shape_for_part(part_cfg)
			col_node.position = pos
			col_node.rotation_degrees = rot_deg
			col_node.scale = scl
			root.add_child(col_node, true)
			col_node.owner = target_owner

	var light_cfg: Dictionary = obj_cfg.get("light", {})
	if bool(light_cfg.get("enabled", false)):
		var l_type: String = str(light_cfg.get("type", "omni"))
		var l_node: Light3D
		if l_type == "spot":
			var sl := SpotLight3D.new()
			sl.spot_range = float(light_cfg.get("range", 6.0))
			sl.spot_angle = 40.0
			l_node = sl
		else:
			var ol := OmniLight3D.new()
			ol.omni_range = float(light_cfg.get("range", 6.0))
			l_node = ol
		l_node.name = "ObjectLight"
		var l_col: Array = light_cfg.get("color", [0.95, 0.80, 0.55])
		l_node.light_color = Color(float(l_col[0]), float(l_col[1]), float(l_col[2]))
		l_node.light_energy = float(light_cfg.get("energy", 1.2))
		l_node.position = _vec3_from_arr(light_cfg.get("position", [0.0, 1.2, 0.0]))
		root.add_child(l_node, true)
		l_node.owner = target_owner

	return root


static func _add_room_surface(
	parent: Node3D,
	owner_root: Node,
	surf_name: String,
	size: Vector3,
	pos: Vector3,
	mat: Material,
	subdiv: int
) -> void:
	var body := StaticBody3D.new()
	body.name = surf_name
	body.position = pos
	parent.add_child(body, true)
	body.owner = owner_root

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box := BoxMesh.new()
	box.size = size
	box.subdivide_width = maxi(1, subdiv)
	box.subdivide_height = maxi(1, subdiv / 2)
	box.subdivide_depth = maxi(1, subdiv)
	box.material = mat
	mesh_inst.mesh = box
	body.add_child(mesh_inst, true)
	mesh_inst.owner = owner_root

	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col, true)
	col.owner = owner_root


static func build_room_node(room_cfg: Dictionary, include_player_and_post: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = str(room_cfg.get("name", "CustomRoom"))

	# Environment, Skybox & Fog
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var env := Environment.new()

	var fog_col_arr: Array = room_cfg.get("fog_color", [0.14, 0.15, 0.16])
	var fog_col := Color(float(fog_col_arr[0]), float(fog_col_arr[1]), float(fog_col_arr[2]))

	var sky_cfg: Dictionary = room_cfg.get("skybox", {})
	var sky_mode: String = str(sky_cfg.get("mode", "procedural_sky"))
	var sky_energy := float(sky_cfg.get("sky_energy", 0.85))

	if sky_mode == "procedural_sky":
		env.background_mode = Environment.BG_SKY
		env.background_energy_multiplier = sky_energy
		var sky := Sky.new()
		var proc_mat := ProceduralSkyMaterial.new()
		var top_arr: Array = sky_cfg.get("sky_top_color", [0.06, 0.07, 0.10])
		var hor_arr: Array = sky_cfg.get("sky_horizon_color", [0.22, 0.24, 0.27])
		var ghor_arr: Array = sky_cfg.get("ground_horizon_color", [0.16, 0.17, 0.19])
		var gbot_arr: Array = sky_cfg.get("ground_bottom_color", [0.05, 0.05, 0.06])
		proc_mat.sky_top_color = Color(float(top_arr[0]), float(top_arr[1]), float(top_arr[2]))
		proc_mat.sky_horizon_color = Color(float(hor_arr[0]), float(hor_arr[1]), float(hor_arr[2]))
		proc_mat.ground_horizon_color = Color(float(ghor_arr[0]), float(ghor_arr[1]), float(ghor_arr[2]))
		proc_mat.ground_bottom_color = Color(float(gbot_arr[0]), float(gbot_arr[1]), float(gbot_arr[2]))
		sky.sky_material = proc_mat
		env.sky = sky
	elif sky_mode == "custom_panorama":
		var pano_path: String = str(sky_cfg.get("panorama_path", ""))
		var pano_tex := load_custom_texture(pano_path)
		env.background_mode = Environment.BG_SKY
		env.background_energy_multiplier = sky_energy
		var sky := Sky.new()
		var pano_mat := PanoramaSkyMaterial.new()
		pano_mat.panorama = pano_tex
		pano_mat.filter = false
		sky.sky_material = pano_mat
		env.sky = sky
	else:
		env.background_mode = Environment.BG_COLOR
		var bg_arr: Array = sky_cfg.get("background_color", [fog_col.r, fog_col.g, fog_col.b])
		env.background_color = Color(float(bg_arr[0]), float(bg_arr[1]), float(bg_arr[2]))
		env.background_energy_multiplier = sky_energy

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb_arr: Array = room_cfg.get("ambient_color", [0.18, 0.19, 0.21])
	env.ambient_light_color = Color(float(amb_arr[0]), float(amb_arr[1]), float(amb_arr[2]))
	env.ambient_light_energy = float(room_cfg.get("ambient_energy", 0.65))
	env.fog_enabled = bool(room_cfg.get("fog_enabled", true))
	env.fog_light_color = fog_col
	env.fog_density = float(room_cfg.get("fog_density", 0.14))
	world_env.environment = env
	root.add_child(world_env, true)
	world_env.owner = root

	# Room Shell Geometry
	var shell := Node3D.new()
	shell.name = "RoomGeometry"
	root.add_child(shell, true)
	shell.owner = root

	var dims_arr: Array = room_cfg.get("dimensions", [10.0, 4.0, 14.0])
	var w := maxf(float(dims_arr[0]), 2.0)
	var h := maxf(float(dims_arr[1]), 2.0)
	var d := maxf(float(dims_arr[2]), 2.0)
	var wall_subdiv := clampi(int(room_cfg.get("subdivide", 6)), 1, 16)
	var floor_subdiv := clampi(int(room_cfg.get("floor_subdivide", wall_subdiv)), 1, 16)
	var ceil_subdiv := clampi(int(room_cfg.get("ceiling_subdivide", wall_subdiv)), 1, 16)

	var wall_thickness := 0.4
	var floor_thickness := maxf(float(room_cfg.get("floor_thickness", 0.4)), 0.05)
	var ceil_thickness := maxf(float(room_cfg.get("ceiling_thickness", 0.4)), 0.05)
	var floor_y_off := float(room_cfg.get("floor_y_offset", 0.0))
	var ceil_y_off := float(room_cfg.get("ceiling_y_offset", 0.0))

	var floor_mat := build_ps1_material(room_cfg.get("floor_material", default_material_config()))
	var wall_mat := build_ps1_material(room_cfg.get("wall_material", default_material_config()))
	var ceil_mat := build_ps1_material(room_cfg.get("ceiling_material", default_material_config()))

	if bool(room_cfg.get("has_floor", true)):
		_add_room_surface(
			shell,
			root,
			"Floor",
			Vector3(w, floor_thickness, d),
			Vector3(0, -floor_thickness * 0.5 + floor_y_off, 0),
			floor_mat,
			floor_subdiv
		)

	if bool(room_cfg.get("has_ceiling", true)):
		_add_room_surface(
			shell,
			root,
			"Ceiling",
			Vector3(w, ceil_thickness, d),
			Vector3(0, h + ceil_thickness * 0.5 + ceil_y_off, 0),
			ceil_mat,
			ceil_subdiv
		)

	if bool(room_cfg.get("wall_north", true)):
		_add_room_surface(shell, root, "WallNorth", Vector3(w, h, wall_thickness), Vector3(0, h * 0.5, -d * 0.5 + wall_thickness * 0.5), wall_mat, wall_subdiv)
	if bool(room_cfg.get("wall_south", true)):
		_add_room_surface(shell, root, "WallSouth", Vector3(w, h, wall_thickness), Vector3(0, h * 0.5, d * 0.5 - wall_thickness * 0.5), wall_mat, wall_subdiv)
	if bool(room_cfg.get("wall_west", true)):
		_add_room_surface(shell, root, "WallWest", Vector3(wall_thickness, h, d), Vector3(-w * 0.5 + wall_thickness * 0.5, h * 0.5, 0), wall_mat, wall_subdiv)
	if bool(room_cfg.get("wall_east", true)):
		_add_room_surface(shell, root, "WallEast", Vector3(wall_thickness, h, d), Vector3(w * 0.5 - wall_thickness * 0.5, h * 0.5, 0), wall_mat, wall_subdiv)

	# Placed Items
	var items_holder := Node3D.new()
	items_holder.name = "Items"
	root.add_child(items_holder, true)
	items_holder.owner = root

	var items: Array = room_cfg.get("items", [])
	for idx in items.size():
		var item_entry: Dictionary = items[idx]
		var obj_id: String = str(item_entry.get("object_name", ""))
		var inst_name: String = str(item_entry.get("instance_name", "Item_%d" % (idx + 1)))
		var obj_cfg := load_object_json(obj_id)
		var item_node: Node3D
		if not obj_cfg.is_empty():
			item_node = build_object_node(obj_cfg)
		else:
			item_node = build_object_node(default_object_config(obj_id if not obj_id.is_empty() else "placeholder"))
		item_node.name = inst_name
		item_node.position = _vec3_from_arr(item_entry.get("position", [0.0, 0.0, 0.0]))
		item_node.rotation_degrees = _vec3_from_arr(item_entry.get("rotation", [0.0, 0.0, 0.0]))
		item_node.scale = _vec3_from_arr(item_entry.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
		item_node.set_meta("item_index", idx)
		items_holder.add_child(item_node, true)
		_set_owner_recursive(item_node, root)

	# Room Lights
	var lights_holder := Node3D.new()
	lights_holder.name = "Lights"
	root.add_child(lights_holder, true)
	lights_holder.owner = root

	var lights: Array = room_cfg.get("lights", [])
	for idx in lights.size():
		var l_cfg: Dictionary = lights[idx]
		var omni := OmniLight3D.new()
		omni.name = str(l_cfg.get("name", "Light_%d" % (idx + 1)))
		omni.position = _vec3_from_arr(l_cfg.get("position", [0.0, h - 0.5, 0.0]))
		var lc: Array = l_cfg.get("color", [0.85, 0.72, 0.52])
		omni.light_color = Color(float(lc[0]), float(lc[1]), float(lc[2]))
		omni.light_energy = float(l_cfg.get("energy", 1.0))
		omni.omni_range = float(l_cfg.get("range", 9.0))
		omni.omni_attenuation = 1.4
		lights_holder.add_child(omni, true)
		omni.owner = root

	# Player Spawn Marker (or Player instance when exporting playable room scene)
	var spawn_pos := _vec3_from_arr(room_cfg.get("player_spawn", [0.0, 0.1, 4.0]))
	if include_player_and_post and ResourceLoader.exists("res://scenes/player.tscn"):
		var player_scene: PackedScene = load("res://scenes/player.tscn")
		var player := player_scene.instantiate()
		player.name = "Player"
		if player is Node3D:
			player.position = spawn_pos
		root.add_child(player, true)
		player.owner = root

		var canvas := CanvasLayer.new()
		canvas.name = "PS1PostProcessLayer"
		root.add_child(canvas, true)
		canvas.owner = root

		var dither := ColorRect.new()
		dither.name = "DitherOverlay"
		var post_mat := ShaderMaterial.new()
		post_mat.shader = load(PS1_POST_SHADER_PATH)
		post_mat.set_shader_parameter("color_levels", 32.0)
		post_mat.set_shader_parameter("dither_strength", 1.0)
		dither.material = post_mat
		dither.set_anchors_preset(Control.PRESET_FULL_RECT)
		dither.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(dither, true)
		dither.owner = root
	else:
		var spawn_marker := Marker3D.new()
		spawn_marker.name = "PlayerSpawn"
		spawn_marker.position = spawn_pos
		root.add_child(spawn_marker, true)
		spawn_marker.owner = root

	return root


static func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	node.owner = new_owner
	for child in node.get_children():
		_set_owner_recursive(child, new_owner)


static func save_object(obj_cfg: Dictionary) -> Dictionary:
	ensure_directories()
	var clean_name := str(obj_cfg.get("name", "custom_object")).strip_edges().to_snake_case()
	if clean_name.is_empty():
		clean_name = "custom_object"
	obj_cfg["name"] = clean_name

	var json_path := "%s/%s.json" % [OBJECTS_JSON_DIR, clean_name]
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(obj_cfg, "\t"))
		f.close()

	var node := build_object_node(obj_cfg)
	var packed := PackedScene.new()
	packed.pack(node)
	var scene_path := "%s/%s.tscn" % [OBJECTS_SCENE_DIR, clean_name]
	ResourceSaver.save(packed, scene_path)
	node.free()

	return {
		"name": clean_name,
		"json_path": json_path,
		"scene_path": scene_path
	}


static func load_object_json(obj_name: String) -> Dictionary:
	var clean := obj_name.trim_suffix(".json").trim_suffix(".tscn")
	var json_path := "%s/%s.json" % [OBJECTS_JSON_DIR, clean]
	if not FileAccess.file_exists(json_path):
		return {}
	var text := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func list_saved_objects() -> Array[String]:
	ensure_directories()
	var results: Array[String] = []
	var dir := DirAccess.open(OBJECTS_JSON_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir() and fname.ends_with(".json"):
				results.append(fname.trim_suffix(".json"))
			fname = dir.get_next()
		dir.list_dir_end()
	results.sort()
	return results


static func save_room(room_cfg: Dictionary, include_player_in_scene: bool = true) -> Dictionary:
	ensure_directories()
	var clean_name := str(room_cfg.get("name", "custom_room")).strip_edges().to_snake_case()
	if clean_name.is_empty():
		clean_name = "custom_room"
	room_cfg["name"] = clean_name

	var json_path := "%s/%s.json" % [ROOMS_JSON_DIR, clean_name]
	var f := FileAccess.open(json_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(room_cfg, "\t"))
		f.close()

	var node := build_room_node(room_cfg, include_player_in_scene)
	var packed := PackedScene.new()
	packed.pack(node)
	var scene_path := "%s/%s.tscn" % [ROOMS_SCENE_DIR, clean_name]
	ResourceSaver.save(packed, scene_path)
	node.free()

	return {
		"name": clean_name,
		"json_path": json_path,
		"scene_path": scene_path
	}


static func load_room_json(room_name: String) -> Dictionary:
	var clean := room_name.trim_suffix(".json").trim_suffix(".tscn")
	var json_path := "%s/%s.json" % [ROOMS_JSON_DIR, clean]
	if not FileAccess.file_exists(json_path):
		return {}
	var text := FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func list_saved_rooms() -> Array[String]:
	ensure_directories()
	var results: Array[String] = []
	var dir := DirAccess.open(ROOMS_JSON_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir() and fname.ends_with(".json"):
				results.append(fname.trim_suffix(".json"))
			fname = dir.get_next()
		dir.list_dir_end()
	results.sort()
	return results


static func ensure_starter_presets() -> void:
	ensure_directories()
	if list_saved_objects().is_empty():
		var crate := default_object_config("rusty_crate")
		crate["parts"][0]["shape"] = "box"
		crate["parts"][0]["size"] = [1.1, 1.1, 1.1]
		crate["parts"][0]["position"] = [0.0, 0.55, 0.0]
		crate["parts"][0]["material"]["texture_mode"] = "procedural_rust"
		crate["parts"][0]["material"]["albedo_color"] = [0.78, 0.55, 0.42, 1.0]
		save_object(crate)

		var pillar := default_object_config("bloodstained_pillar")
		pillar["parts"][0]["shape"] = "box"
		pillar["parts"][0]["size"] = [0.9, 4.0, 0.9]
		pillar["parts"][0]["subdivide"] = 4
		pillar["parts"][0]["position"] = [0.0, 2.0, 0.0]
		pillar["parts"][0]["material"]["texture_mode"] = "procedural_concrete"
		pillar["parts"][0]["material"]["albedo_color"] = [0.52, 0.34, 0.28, 1.0]
		pillar["parts"][0]["material"]["uv_scale"] = [2.0, 4.0]
		save_object(pillar)

		var barrel := default_object_config("industrial_drum")
		barrel["parts"][0]["shape"] = "cylinder"
		barrel["parts"][0]["size"] = [0.85, 1.25, 0.85]
		barrel["parts"][0]["position"] = [0.0, 0.625, 0.0]
		barrel["parts"][0]["material"]["texture_mode"] = "procedural_rust"
		barrel["parts"][0]["material"]["albedo_color"] = [0.45, 0.52, 0.48, 1.0]
		save_object(barrel)

		var lamp := default_object_config("flicker_lantern")
		lamp["parts"][0]["shape"] = "cylinder"
		lamp["parts"][0]["size"] = [0.35, 0.5, 0.35]
		lamp["parts"][0]["position"] = [0.0, 0.25, 0.0]
		lamp["parts"][0]["material"]["texture_mode"] = "procedural_grate"
		lamp["light"]["enabled"] = true
		lamp["light"]["energy"] = 1.6
		lamp["light"]["range"] = 7.5
		lamp["light"]["position"] = [0.0, 0.6, 0.0]
		save_object(lamp)

	if list_saved_rooms().is_empty():
		var room := default_room_config("silent_corridor")
		room["dimensions"] = [12.0, 4.0, 24.0]
		room["items"] = [
			{"instance_name": "Pillar_NW", "object_name": "bloodstained_pillar", "position": [-2.5, 0.0, -5.0], "rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]},
			{"instance_name": "Pillar_NE", "object_name": "bloodstained_pillar", "position": [2.5, 0.0, -5.0], "rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]},
			{"instance_name": "Pillar_SW", "object_name": "bloodstained_pillar", "position": [-2.5, 0.0, 3.0], "rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]},
			{"instance_name": "Pillar_SE", "object_name": "bloodstained_pillar", "position": [2.5, 0.0, 3.0], "rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]},
			{"instance_name": "Crate_1", "object_name": "rusty_crate", "position": [-3.8, 0.0, -1.5], "rotation": [0.0, 18.0, 0.0], "scale": [1.0, 1.0, 1.0]},
			{"instance_name": "Drum_1", "object_name": "industrial_drum", "position": [3.6, 0.0, -2.0], "rotation": [0.0, 0.0, 0.0], "scale": [1.0, 1.0, 1.0]}
		]
		save_room(room, true)
