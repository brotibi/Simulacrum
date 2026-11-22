extends Control

const SimulacrumBuilder = preload("res://scripts/simulacrum_builder.gd")

const TEXTURE_MODES: Array[String] = [
	"procedural_concrete",
	"procedural_rust",
	"procedural_bricks",
	"procedural_tiles",
	"procedural_checker",
	"procedural_grate",
	"custom_image",
	"none"
]

const SHAPE_MODES: Array[String] = [
	"box",
	"cylinder",
	"sphere",
	"prism",
	"plane",
	"custom_model"
]

enum Mode { OBJECT_EDITOR, ROOM_EDITOR }

var current_mode: Mode = Mode.OBJECT_EDITOR
var object_cfg: Dictionary = {}
var selected_part_idx: int = 0

var room_cfg: Dictionary = {}
var selected_item_idx: int = -1
var selected_light_idx: int = 0
var room_surface_target: String = "floor_material" # floor_material, wall_material, ceiling_material

var _updating_ui: bool = false

# 3D Preview state
var vp_container: SubViewportContainer
var preview_subviewport: SubViewport
var preview_root_3d: Node3D
var preview_content_holder: Node3D
var preview_camera: Camera3D
var preview_key_light: DirectionalLight3D
var preview_post_rect: ColorRect
var preview_selection_box: MeshInstance3D

# 3D Translation Vector Arrows Gizmo (X = Red, Y = Green, Z = Blue)
var gizmo_root: Node3D
var _gizmo_axis_mats: Dictionary = {}
var _hovered_gizmo_axis: int = -1 # -1 none, 0 X, 1 Y, 2 Z
var _dragging_gizmo_axis: int = -1
var _gizmo_drag_start_pos: Vector3 = Vector3.ZERO
var _gizmo_drag_start_param: float = 0.0

var _cam_target: Vector3 = Vector3(0.0, 0.8, 0.0)
var _cam_yaw: float = -0.5
var _cam_pitch: float = -0.35
var _cam_distance: float = 4.2
var _orbit_dragging: bool = false
var _pan_dragging: bool = false
var _turntable_enabled: bool = false

# UI References
var status_label: Label
var mode_btn_object: Button
var mode_btn_room: Button

var left_object_panel: VBoxContainer
var left_room_panel: VBoxContainer
var right_object_panel: VBoxContainer
var right_room_panel: VBoxContainer

# Object UI controls
var obj_saved_dropdown: OptionButton
var obj_name_edit: LineEdit
var obj_parts_list: ItemList
var part_name_edit: LineEdit
var part_shape_option: OptionButton
var part_model_path_edit: LineEdit
var part_size_x: SpinBox
var part_size_y: SpinBox
var part_size_z: SpinBox
var part_subdiv_spin: SpinBox
var part_pos_x: SpinBox
var part_pos_y: SpinBox
var part_pos_z: SpinBox
var part_rot_x: SpinBox
var part_rot_y: SpinBox
var part_rot_z: SpinBox
var part_collision_chk: CheckBox

var obj_mat_color: ColorPickerButton
var obj_mat_tex_option: OptionButton
var obj_mat_custom_tex_edit: LineEdit
var obj_mat_uv_x: SpinBox
var obj_mat_uv_y: SpinBox
var obj_mat_snap_chk: CheckBox
var obj_mat_snap_x: SpinBox
var obj_mat_snap_y: SpinBox
var obj_mat_affine_slider: HSlider
var obj_mat_dark_start: SpinBox
var obj_mat_dark_end: SpinBox

var obj_light_chk: CheckBox
var obj_light_color: ColorPickerButton
var obj_light_energy: SpinBox
var obj_light_range: SpinBox

# Room UI controls
var room_saved_dropdown: OptionButton
var room_name_edit: LineEdit
var room_dim_w: SpinBox
var room_dim_h: SpinBox
var room_dim_d: SpinBox
var room_ceil_chk: CheckBox
var room_wall_n_chk: CheckBox
var room_wall_s_chk: CheckBox
var room_wall_e_chk: CheckBox
var room_wall_w_chk: CheckBox
var room_fog_chk: CheckBox
var room_fog_color: ColorPickerButton
var room_fog_density: SpinBox
var room_surface_selector: OptionButton
var room_surf_color: ColorPickerButton
var room_surf_tex_option: OptionButton
var room_surf_uv_x: SpinBox
var room_surf_uv_y: SpinBox
var room_surf_affine: HSlider

var room_catalog_option: OptionButton
var room_items_list: ItemList
var item_inst_name_edit: LineEdit
var item_pos_x: SpinBox
var item_pos_y: SpinBox
var item_pos_z: SpinBox
var item_rot_y: SpinBox
var item_scale_spin: SpinBox

var room_lights_list: ItemList
var rlight_pos_x: SpinBox
var rlight_pos_y: SpinBox
var rlight_pos_z: SpinBox
var rlight_color: ColorPickerButton
var rlight_energy: SpinBox
var rlight_range: SpinBox


func _ready() -> void:
	# Override project.godot's 426x240 integer viewport scaling so the studio UI gets full window pixels
	var root_win := get_tree().root
	root_win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root_win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	DisplayServer.window_set_size(Vector2i(1480, 880))
	root_win.content_scale_size = Vector2i(0, 0)

	SimulacrumBuilder.ensure_starter_presets()
	object_cfg = SimulacrumBuilder.load_object_json("rusty_crate")
	if object_cfg.is_empty():
		object_cfg = SimulacrumBuilder.default_object_config("rusty_crate")

	room_cfg = SimulacrumBuilder.load_room_json("silent_corridor")
	if room_cfg.is_empty():
		room_cfg = SimulacrumBuilder.default_room_config("silent_corridor")
	if not room_cfg.get("items", []).is_empty():
		selected_item_idx = 0

	_build_ui()
	_refresh_saved_lists()
	_switch_mode(Mode.OBJECT_EDITOR)


func _process(delta: float) -> void:
	if _turntable_enabled and current_mode == Mode.OBJECT_EDITOR and not _orbit_dragging:
		_cam_yaw += delta * 0.65
		_update_camera_transform()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.12, 0.14, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 10)
	outer_margin.add_theme_constant_override("margin_right", 10)
	outer_margin.add_theme_constant_override("margin_top", 8)
	outer_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(outer_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	outer_margin.add_child(main_vbox)

	# Top Toolbar
	var top_bar := PanelContainer.new()
	main_vbox.add_child(top_bar)
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(top_hbox)

	var title_lbl := Label.new()
	title_lbl.text = " SIMULACRUM STUDIO "
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.55))
	top_hbox.add_child(title_lbl)

	mode_btn_object = Button.new()
	mode_btn_object.text = "1. Object Editor"
	mode_btn_object.toggle_mode = true
	mode_btn_object.pressed.connect(func(): _switch_mode(Mode.OBJECT_EDITOR))
	top_hbox.add_child(mode_btn_object)

	mode_btn_room = Button.new()
	mode_btn_room.text = "2. Room Editor"
	mode_btn_room.toggle_mode = true
	mode_btn_room.pressed.connect(func(): _switch_mode(Mode.ROOM_EDITOR))
	top_hbox.add_child(mode_btn_room)

	var sep := VSeparator.new()
	top_hbox.add_child(sep)

	var dither_toggle := CheckButton.new()
	dither_toggle.text = "PS1 15-Bit Dither"
	dither_toggle.button_pressed = true
	dither_toggle.toggled.connect(func(on: bool):
		if preview_post_rect != null:
			preview_post_rect.visible = on
	)
	top_hbox.add_child(dither_toggle)

	var turntable_toggle := CheckButton.new()
	turntable_toggle.text = "Turntable"
	turntable_toggle.toggled.connect(func(on: bool): _turntable_enabled = on)
	top_hbox.add_child(turntable_toggle)

	var reset_cam_btn := Button.new()
	reset_cam_btn.text = "Reset Camera"
	reset_cam_btn.pressed.connect(_reset_camera_for_mode)
	top_hbox.add_child(reset_cam_btn)

	status_label = Label.new()
	status_label.text = "Ready."
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.70))
	top_hbox.add_child(status_label)

	# Main 3-Column Workspace
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(body_hbox)

	# Left Column (Scrollable with interior padding so controls are never clipped)
	var left_panel_bg := PanelContainer.new()
	left_panel_bg.custom_minimum_size = Vector2(360, 0)
	left_panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(left_panel_bg)

	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel_bg.add_child(left_scroll)

	var left_margin := MarginContainer.new()
	left_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_theme_constant_override("margin_left", 10)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_top", 8)
	left_margin.add_theme_constant_override("margin_bottom", 12)
	left_scroll.add_child(left_margin)

	var left_holder := VBoxContainer.new()
	left_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_holder)

	left_object_panel = VBoxContainer.new()
	left_object_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_object_panel.add_theme_constant_override("separation", 6)
	left_holder.add_child(left_object_panel)
	_build_left_object_panel()

	left_room_panel = VBoxContainer.new()
	left_room_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_room_panel.add_theme_constant_override("separation", 6)
	left_holder.add_child(left_room_panel)
	_build_left_room_panel()

	# Center 3D Preview Viewport
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(center_vbox)

	vp_container = SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.gui_input.connect(_on_preview_gui_input)
	center_vbox.add_child(vp_container)

	preview_subviewport = SubViewport.new()
	preview_subviewport.size = Vector2i(426, 240)
	preview_subviewport.handle_input_locally = false
	preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp_container.add_child(preview_subviewport)

	_setup_preview_3d_scene()

	var hint_lbl := Label.new()
	hint_lbl.text = "Room Editor: Drag Red(X) / Green(Y) / Blue(Z) Vector Arrows to move item | Left-Click item to select | Left-Drag = Orbit | Right-Drag = Pan | Scroll = Zoom"
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	center_vbox.add_child(hint_lbl)

	# Right Column (Scrollable Inspector with interior padding)
	var right_panel_bg := PanelContainer.new()
	right_panel_bg.custom_minimum_size = Vector2(360, 0)
	right_panel_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_child(right_panel_bg)

	var right_scroll := ScrollContainer.new()
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel_bg.add_child(right_scroll)

	var right_margin := MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 10)
	right_margin.add_theme_constant_override("margin_right", 14)
	right_margin.add_theme_constant_override("margin_top", 8)
	right_margin.add_theme_constant_override("margin_bottom", 12)
	right_scroll.add_child(right_margin)

	var right_holder := VBoxContainer.new()
	right_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_holder)

	right_object_panel = VBoxContainer.new()
	right_object_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_object_panel.add_theme_constant_override("separation", 6)
	right_holder.add_child(right_object_panel)
	_build_right_object_panel()

	right_room_panel = VBoxContainer.new()
	right_room_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_room_panel.add_theme_constant_override("separation", 6)
	right_holder.add_child(right_room_panel)
	_build_right_room_panel()


func _setup_preview_3d_scene() -> void:
	preview_root_3d = Node3D.new()
	preview_root_3d.name = "PreviewRoot3D"
	preview_subviewport.add_child(preview_root_3d)

	preview_camera = Camera3D.new()
	preview_camera.fov = 65.0
	preview_camera.near = 0.05
	preview_camera.far = 80.0
	preview_root_3d.add_child(preview_camera)

	preview_key_light = DirectionalLight3D.new()
	preview_key_light.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	preview_key_light.light_energy = 1.15
	preview_root_3d.add_child(preview_key_light)

	# Reference floor grid for Object Editor
	var grid_mesh := MeshInstance3D.new()
	grid_mesh.name = "ObjectFloorGrid"
	var plane := PlaneMesh.new()
	plane.size = Vector2(8.0, 8.0)
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	var grid_mat := SimulacrumBuilder.build_ps1_material({
		"albedo_color": [0.24, 0.25, 0.27, 1.0],
		"texture_mode": "procedural_tiles",
		"uv_scale": [4.0, 4.0],
		"vertex_snap_enabled": true,
		"snap_resolution": [213.0, 120.0],
		"affine_amount": 1.0,
		"vertex_darkening_start": 6.0,
		"vertex_darkening_end": 22.0
	})
	plane.material = grid_mat
	grid_mesh.mesh = plane
	preview_root_3d.add_child(grid_mesh)

	preview_content_holder = Node3D.new()
	preview_content_holder.name = "PreviewContentHolder"
	preview_root_3d.add_child(preview_content_holder)

	# Selection highlight box for selected room item
	preview_selection_box = MeshInstance3D.new()
	var sel_box := BoxMesh.new()
	sel_box.size = Vector3(1.15, 1.15, 1.15)
	var sel_mat := StandardMaterial3D.new()
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.16)
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sel_box.material = sel_mat
	preview_selection_box.mesh = sel_box
	preview_selection_box.visible = false
	preview_root_3d.add_child(preview_selection_box)

	# Build 3D Vector Translation Arrows Gizmo (X = Red, Y = Green, Z = Blue)
	_build_3d_translation_gizmo()

	# PS1 Post-process inside preview subviewport
	var post_layer := CanvasLayer.new()
	preview_subviewport.add_child(post_layer)
	preview_post_rect = ColorRect.new()
	var post_mat := ShaderMaterial.new()
	post_mat.shader = load(SimulacrumBuilder.PS1_POST_SHADER_PATH)
	post_mat.set_shader_parameter("color_levels", 32.0)
	post_mat.set_shader_parameter("dither_strength", 1.0)
	preview_post_rect.material = post_mat
	preview_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(preview_post_rect)


func _build_3d_translation_gizmo() -> void:
	gizmo_root = Node3D.new()
	gizmo_root.name = "TranslationGizmo3D"
	gizmo_root.visible = false
	preview_root_3d.add_child(gizmo_root)

	# Center origin cube
	var center_mesh := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.18, 0.18, 0.18)
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.no_depth_test = true
	cmat.render_priority = 10
	cmat.albedo_color = Color(0.95, 0.95, 0.95)
	cbox.material = cmat
	center_mesh.mesh = cbox
	gizmo_root.add_child(center_mesh)

	_create_gizmo_axis_arrow(0, Vector3.RIGHT, Color(0.95, 0.22, 0.22))   # +X Red
	_create_gizmo_axis_arrow(1, Vector3.UP, Color(0.25, 0.92, 0.30))      # +Y Green
	_create_gizmo_axis_arrow(2, Vector3.BACK, Color(0.25, 0.52, 0.98))    # +Z Blue


func _create_gizmo_axis_arrow(axis_id: int, axis_dir: Vector3, base_color: Color) -> void:
	var holder := Node3D.new()
	holder.name = "Axis_%d" % axis_id
	gizmo_root.add_child(holder)

	# Orient holder so its local +Y points along axis_dir
	if axis_dir == Vector3.RIGHT:
		holder.rotation_degrees = Vector3(0.0, 0.0, -90.0)
	elif axis_dir == Vector3.BACK:
		holder.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.albedo_color = base_color
	_gizmo_axis_mats[axis_id] = {
		"material": mat,
		"base_color": base_color
	}

	var shaft_mesh_inst := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.045
	shaft.bottom_radius = 0.045
	shaft.height = 1.2
	shaft.radial_segments = 10
	shaft.material = mat
	shaft_mesh_inst.mesh = shaft
	shaft_mesh_inst.position = Vector3(0.0, 0.6, 0.0)
	holder.add_child(shaft_mesh_inst)

	var tip_mesh_inst := MeshInstance3D.new()
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.14
	tip.height = 0.38
	tip.radial_segments = 12
	tip.material = mat
	tip_mesh_inst.mesh = tip
	tip_mesh_inst.position = Vector3(0.0, 1.35, 0.0)
	holder.add_child(tip_mesh_inst)


func _set_gizmo_highlight(active_axis: int) -> void:
	for axis_id in _gizmo_axis_mats.keys():
		var entry: Dictionary = _gizmo_axis_mats[axis_id]
		var mat: StandardMaterial3D = entry["material"]
		var base_col: Color = entry["base_color"]
		if axis_id == active_axis:
			mat.albedo_color = Color(1.0, 0.95, 0.35) # Bright yellow highlight when hovered/dragged
		else:
			mat.albedo_color = base_col


func _get_viewport_local_pos(local_pos: Vector2) -> Vector2:
	if vp_container == null or preview_subviewport == null:
		return local_pos
	var c_size := vp_container.size
	if c_size.x <= 1.0 or c_size.y <= 1.0:
		return local_pos
	return Vector2(
		local_pos.x * float(preview_subviewport.size.x) / c_size.x,
		local_pos.y * float(preview_subviewport.size.y) / c_size.y
	)


func _point_to_segment_dist_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return p.distance_to(proj)


func _pick_gizmo_axis_at_screen_pos(screen_pos: Vector2) -> int:
	if gizmo_root == null or not gizmo_root.visible or preview_camera == null or vp_container == null:
		return -1

	var origin_3d := gizmo_root.global_position
	if preview_camera.is_position_behind(origin_3d):
		return -1

	var vp_pos := _get_viewport_local_pos(screen_pos)
	var origin_2d := preview_camera.unproject_position(origin_3d)

	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var arrow_len := 1.55 * gizmo_root.scale.x
	var best_axis := -1
	var best_dist := 14.0 # Hit threshold in subviewport pixels (426x240)

	for axis_id in 3:
		var tip_3d := origin_3d + axes[axis_id] * arrow_len
		if preview_camera.is_position_behind(tip_3d):
			continue
		var tip_2d := preview_camera.unproject_position(tip_3d)
		var d := _point_to_segment_dist_2d(vp_pos, origin_2d, tip_2d)
		if d < best_dist:
			best_dist = d
			best_axis = axis_id

	return best_axis


func _ray_closest_axis_param(ray_origin: Vector3, ray_dir: Vector3, axis_origin: Vector3, axis_dir: Vector3) -> float:
	# Closest point parameter s along P(s) = axis_origin + s * axis_dir to ray R(t) = ray_origin + t * ray_dir
	var w0 := ray_origin - axis_origin
	var a := ray_dir.dot(ray_dir)
	var b := ray_dir.dot(axis_dir)
	var c := axis_dir.dot(axis_dir)
	var d := ray_dir.dot(w0)
	var e := axis_dir.dot(w0)
	var denom := a * c - b * b
	if absf(denom) < 0.00001:
		return 0.0
	return (a * e - b * d) / denom


func _get_axis_param_at_screen_pos(screen_pos: Vector2, axis_origin: Vector3, axis_id: int) -> float:
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var axis_dir := axes[axis_id]
	var vp_pos := _get_viewport_local_pos(screen_pos)
	var ray_origin := preview_camera.project_ray_origin(vp_pos)
	var ray_dir := preview_camera.project_ray_normal(vp_pos)
	return _ray_closest_axis_param(ray_origin, ray_dir, axis_origin, axis_dir)


func _try_select_room_item_at_screen_pos(screen_pos: Vector2) -> bool:
	if current_mode != Mode.ROOM_EDITOR or preview_camera == null:
		return false
	var items: Array = room_cfg.get("items", [])
	if items.is_empty():
		return false

	var vp_pos := _get_viewport_local_pos(screen_pos)
	var ray_origin := preview_camera.project_ray_origin(vp_pos)
	var ray_dir := preview_camera.project_ray_normal(vp_pos)

	var best_idx := -1
	var best_t := 99999.0

	for idx in items.size():
		var it: Dictionary = items[idx]
		var pos_arr: Array = it.get("position", [0.0, 0.0, 0.0])
		var center := Vector3(float(pos_arr[0]), float(pos_arr[1]) + 0.6, float(pos_arr[2]))
		var oc := center - ray_origin
		var t := oc.dot(ray_dir)
		if t <= 0.0:
			continue
		var closest_pt := ray_origin + ray_dir * t
		var dist := closest_pt.distance_to(center)
		if dist < 0.85 and t < best_t:
			best_t = t
			best_idx = idx

	if best_idx >= 0:
		selected_item_idx = best_idx
		_refresh_room_items_list()
		_populate_room_item_inspector()
		_update_room_selection_highlight()
		return true
	return false


func _build_left_object_panel() -> void:
	_add_header(left_object_panel, "OBJECT LIBRARY")

	var load_row := HBoxContainer.new()
	left_object_panel.add_child(load_row)
	obj_saved_dropdown = OptionButton.new()
	obj_saved_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	obj_saved_dropdown.clip_text = true
	load_row.add_child(obj_saved_dropdown)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_selected_object)
	load_row.add_child(load_btn)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_object)
	load_row.add_child(new_btn)

	obj_name_edit = _add_labeled_line_edit(left_object_panel, "Object Name:", "rusty_crate", func(v: String):
		object_cfg["name"] = v
	)

	var save_btn := Button.new()
	save_btn.text = "Save Object (.json + .tscn)"
	save_btn.pressed.connect(_on_save_object)
	left_object_panel.add_child(save_btn)

	_add_header(left_object_panel, "MESH PARTS (COMPOSITE)")
	obj_parts_list = ItemList.new()
	obj_parts_list.custom_minimum_size = Vector2(0, 100)
	obj_parts_list.item_selected.connect(func(idx: int):
		selected_part_idx = idx
		_populate_object_ui()
	)
	left_object_panel.add_child(obj_parts_list)

	var part_btns := HBoxContainer.new()
	left_object_panel.add_child(part_btns)
	var add_part_btn := Button.new()
	add_part_btn.text = "+ Add Part"
	add_part_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_part_btn.pressed.connect(_on_add_object_part)
	part_btns.add_child(add_part_btn)

	var dup_part_btn := Button.new()
	dup_part_btn.text = "Duplicate"
	dup_part_btn.pressed.connect(_on_duplicate_object_part)
	part_btns.add_child(dup_part_btn)

	var del_part_btn := Button.new()
	del_part_btn.text = "Remove"
	del_part_btn.pressed.connect(_on_remove_object_part)
	part_btns.add_child(del_part_btn)

	_add_header(left_object_panel, "SELECTED PART GEOMETRY")
	part_name_edit = _add_labeled_line_edit(left_object_panel, "Part Name:", "BaseMesh", func(v: String):
		if _updating_ui: return
		_current_part()["name"] = v
		_refresh_parts_list_labels()
		_rebuild_preview()
	)

	part_shape_option = _add_labeled_option(left_object_panel, "Shape:", SHAPE_MODES, func(idx: int):
		if _updating_ui: return
		_current_part()["shape"] = SHAPE_MODES[idx]
		_rebuild_preview()
	)

	part_model_path_edit = _add_labeled_line_edit(left_object_panel, "Model (res://):", "", func(v: String):
		if _updating_ui: return
		_current_part()["model_path"] = v
		_rebuild_preview()
	)

	var sz_spins := _add_vec3_spins(left_object_panel, "Size (X, Y, Z):", 0.05, 20.0, 0.05, Vector3.ONE, func(v: Vector3):
		if _updating_ui: return
		_current_part()["size"] = [v.x, v.y, v.z]
		_rebuild_preview()
	)
	part_size_x = sz_spins[0]
	part_size_y = sz_spins[1]
	part_size_z = sz_spins[2]

	part_subdiv_spin = _add_labeled_spin(left_object_panel, "PS1 Subdivisions:", 0, 12, 1, 2, func(v: float):
		if _updating_ui: return
		_current_part()["subdivide"] = int(v)
		_rebuild_preview()
	)

	var pos_spins := _add_vec3_spins(left_object_panel, "Offset (X, Y, Z):", -15.0, 15.0, 0.05, Vector3(0, 0.5, 0), func(v: Vector3):
		if _updating_ui: return
		_current_part()["position"] = [v.x, v.y, v.z]
		_rebuild_preview()
	)
	part_pos_x = pos_spins[0]
	part_pos_y = pos_spins[1]
	part_pos_z = pos_spins[2]

	var rot_spins := _add_vec3_spins(left_object_panel, "Rotation (Deg):", -360.0, 360.0, 5.0, Vector3.ZERO, func(v: Vector3):
		if _updating_ui: return
		_current_part()["rotation"] = [v.x, v.y, v.z]
		_rebuild_preview()
	)
	part_rot_x = rot_spins[0]
	part_rot_y = rot_spins[1]
	part_rot_z = rot_spins[2]

	part_collision_chk = _add_labeled_checkbox(left_object_panel, "Generate Collision Shape", true, func(on: bool):
		if _updating_ui: return
		_current_part()["collision"] = on
	)


func _build_right_object_panel() -> void:
	_add_header(right_object_panel, "PS1 TEXTURE & SHADER EFFECTS")

	obj_mat_color = _add_labeled_color(right_object_panel, "Albedo Tint:", Color.WHITE, func(c: Color):
		if _updating_ui: return
		_current_part_mat()["albedo_color"] = [c.r, c.g, c.b, c.a]
		_rebuild_preview()
	)

	obj_mat_tex_option = _add_labeled_option(right_object_panel, "Texture Preset:", TEXTURE_MODES, func(idx: int):
		if _updating_ui: return
		_current_part_mat()["texture_mode"] = TEXTURE_MODES[idx]
		_rebuild_preview()
	)

	obj_mat_custom_tex_edit = _add_labeled_line_edit(right_object_panel, "Image Path:", "", func(v: String):
		if _updating_ui: return
		_current_part_mat()["custom_texture_path"] = v
		_rebuild_preview()
	)

	var uv_row := _add_vec2_spins(right_object_panel, "UV Tiling (X, Y):", 0.1, 32.0, 0.25, Vector2(2, 2), func(v: Vector2):
		if _updating_ui: return
		_current_part_mat()["uv_scale"] = [v.x, v.y]
		_rebuild_preview()
	)
	obj_mat_uv_x = uv_row[0]
	obj_mat_uv_y = uv_row[1]

	obj_mat_snap_chk = _add_labeled_checkbox(right_object_panel, "PS1 Vertex Snapping (Jitter)", true, func(on: bool):
		if _updating_ui: return
		_current_part_mat()["vertex_snap_enabled"] = on
		_rebuild_preview()
	)

	var snap_row := _add_vec2_spins(right_object_panel, "Jitter Grid (W, H):", 32.0, 640.0, 8.0, Vector2(213, 120), func(v: Vector2):
		if _updating_ui: return
		_current_part_mat()["snap_resolution"] = [v.x, v.y]
		_rebuild_preview()
	)
	obj_mat_snap_x = snap_row[0]
	obj_mat_snap_y = snap_row[1]

	obj_mat_affine_slider = _add_labeled_slider(right_object_panel, "Affine Warping:", 0.0, 1.0, 0.05, 1.0, func(v: float):
		if _updating_ui: return
		_current_part_mat()["affine_amount"] = v
		_rebuild_preview()
	)

	obj_mat_dark_start = _add_labeled_spin(right_object_panel, "Darkness Start:", 0.5, 40.0, 0.5, 4.0, func(v: float):
		if _updating_ui: return
		_current_part_mat()["vertex_darkening_start"] = v
		_rebuild_preview()
	)

	obj_mat_dark_end = _add_labeled_spin(right_object_panel, "Darkness End:", 1.0, 60.0, 0.5, 18.0, func(v: float):
		if _updating_ui: return
		_current_part_mat()["vertex_darkening_end"] = v
		_rebuild_preview()
	)

	_add_header(right_object_panel, "ATTACHED LIGHT EFFECT")
	obj_light_chk = _add_labeled_checkbox(right_object_panel, "Enable Attached OmniLight", false, func(on: bool):
		if _updating_ui: return
		object_cfg["light"]["enabled"] = on
		_rebuild_preview()
	)

	obj_light_color = _add_labeled_color(right_object_panel, "Light Color:", Color(0.95, 0.80, 0.55), func(c: Color):
		if _updating_ui: return
		object_cfg["light"]["color"] = [c.r, c.g, c.b]
		_rebuild_preview()
	)

	obj_light_energy = _add_labeled_spin(right_object_panel, "Light Energy:", 0.0, 8.0, 0.1, 1.2, func(v: float):
		if _updating_ui: return
		object_cfg["light"]["energy"] = v
		_rebuild_preview()
	)

	obj_light_range = _add_labeled_spin(right_object_panel, "Light Range:", 0.5, 25.0, 0.5, 6.0, func(v: float):
		if _updating_ui: return
		object_cfg["light"]["range"] = v
		_rebuild_preview()
	)


func _build_left_room_panel() -> void:
	_add_header(left_room_panel, "ROOM CONFIG & SHELL")

	var load_row := HBoxContainer.new()
	left_room_panel.add_child(load_row)
	room_saved_dropdown = OptionButton.new()
	room_saved_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_saved_dropdown.clip_text = true
	load_row.add_child(room_saved_dropdown)

	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_selected_room)
	load_row.add_child(load_btn)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_room)
	load_row.add_child(new_btn)

	room_name_edit = _add_labeled_line_edit(left_room_panel, "Room Name:", "silent_corridor", func(v: String):
		room_cfg["name"] = v
	)

	var save_btn := Button.new()
	save_btn.text = "Save Room (.json + .tscn)"
	save_btn.pressed.connect(_on_save_room)
	left_room_panel.add_child(save_btn)

	var set_main_btn := Button.new()
	set_main_btn.text = "Save & Export to main.tscn"
	set_main_btn.pressed.connect(_on_save_room_as_main)
	left_room_panel.add_child(set_main_btn)

	var dim_spins := _add_vec3_spins(left_room_panel, "Room Size (W, H, D):", 2.0, 60.0, 0.5, Vector3(12, 4, 24), func(v: Vector3):
		if _updating_ui: return
		room_cfg["dimensions"] = [v.x, v.y, v.z]
		_rebuild_preview()
	)
	room_dim_w = dim_spins[0]
	room_dim_h = dim_spins[1]
	room_dim_d = dim_spins[2]

	# Compact 2-column grid for wall/ceiling toggles
	var wall_grid := GridContainer.new()
	wall_grid.columns = 2
	wall_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_room_panel.add_child(wall_grid)

	room_ceil_chk = _add_labeled_checkbox(wall_grid, "Ceiling", true, func(on: bool):
		if _updating_ui: return
		room_cfg["has_ceiling"] = on
		_rebuild_preview()
	)
	room_wall_n_chk = _add_labeled_checkbox(wall_grid, "North Wall (-Z)", true, func(on: bool):
		if _updating_ui: return
		room_cfg["wall_north"] = on
		_rebuild_preview()
	)
	room_wall_s_chk = _add_labeled_checkbox(wall_grid, "South Wall (+Z)", true, func(on: bool):
		if _updating_ui: return
		room_cfg["wall_south"] = on
		_rebuild_preview()
	)
	room_wall_w_chk = _add_labeled_checkbox(wall_grid, "West Wall (-X)", true, func(on: bool):
		if _updating_ui: return
		room_cfg["wall_west"] = on
		_rebuild_preview()
	)
	room_wall_e_chk = _add_labeled_checkbox(wall_grid, "East Wall (+X)", true, func(on: bool):
		if _updating_ui: return
		room_cfg["wall_east"] = on
		_rebuild_preview()
	)

	_add_header(left_room_panel, "SILENT HILL FOG & ATMOSPHERE")
	room_fog_chk = _add_labeled_checkbox(left_room_panel, "Enable Depth Fog", true, func(on: bool):
		if _updating_ui: return
		room_cfg["fog_enabled"] = on
		_rebuild_preview()
	)
	room_fog_color = _add_labeled_color(left_room_panel, "Fog Color:", Color(0.14, 0.15, 0.16), func(c: Color):
		if _updating_ui: return
		room_cfg["fog_color"] = [c.r, c.g, c.b]
		_rebuild_preview()
	)
	room_fog_density = _add_labeled_spin(left_room_panel, "Fog Density:", 0.0, 0.6, 0.01, 0.14, func(v: float):
		if _updating_ui: return
		room_cfg["fog_density"] = v
		_rebuild_preview()
	)

	_add_header(left_room_panel, "ROOM SURFACE MATERIALS")
	var surf_targets: Array[String] = ["floor_material", "wall_material", "ceiling_material"]
	room_surface_selector = _add_labeled_option(left_room_panel, "Surface:", surf_targets, func(idx: int):
		room_surface_target = surf_targets[idx]
		_populate_room_surface_ui()
	)

	room_surf_color = _add_labeled_color(left_room_panel, "Surface Tint:", Color(0.4, 0.4, 0.4), func(c: Color):
		if _updating_ui: return
		room_cfg[room_surface_target]["albedo_color"] = [c.r, c.g, c.b, 1.0]
		_rebuild_preview()
	)
	room_surf_tex_option = _add_labeled_option(left_room_panel, "Texture:", TEXTURE_MODES, func(idx: int):
		if _updating_ui: return
		room_cfg[room_surface_target]["texture_mode"] = TEXTURE_MODES[idx]
		_rebuild_preview()
	)
	var r_uv := _add_vec2_spins(left_room_panel, "UV Scale (X, Y):", 0.5, 40.0, 0.5, Vector2(8, 12), func(v: Vector2):
		if _updating_ui: return
		room_cfg[room_surface_target]["uv_scale"] = [v.x, v.y]
		_rebuild_preview()
	)
	room_surf_uv_x = r_uv[0]
	room_surf_uv_y = r_uv[1]

	room_surf_affine = _add_labeled_slider(left_room_panel, "Affine Warping:", 0.0, 1.0, 0.05, 1.0, func(v: float):
		if _updating_ui: return
		room_cfg[room_surface_target]["affine_amount"] = v
		_rebuild_preview()
	)


func _build_right_room_panel() -> void:
	_add_header(right_room_panel, "PLACE & MODIFY ROOM ITEMS")

	var place_row := HBoxContainer.new()
	right_room_panel.add_child(place_row)
	room_catalog_option = OptionButton.new()
	room_catalog_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_catalog_option.clip_text = true
	place_row.add_child(room_catalog_option)

	var place_btn := Button.new()
	place_btn.text = "+ Place Object"
	place_btn.pressed.connect(_on_place_item_in_room)
	place_row.add_child(place_btn)

	room_items_list = ItemList.new()
	room_items_list.custom_minimum_size = Vector2(0, 120)
	room_items_list.item_selected.connect(func(idx: int):
		selected_item_idx = idx
		_populate_room_item_inspector()
		_update_room_selection_highlight()
	)
	right_room_panel.add_child(room_items_list)

	var item_btns := HBoxContainer.new()
	right_room_panel.add_child(item_btns)
	var dup_item_btn := Button.new()
	dup_item_btn.text = "Duplicate"
	dup_item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_item_btn.pressed.connect(_on_duplicate_room_item)
	item_btns.add_child(dup_item_btn)

	var del_item_btn := Button.new()
	del_item_btn.text = "Delete"
	del_item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_item_btn.pressed.connect(_on_delete_room_item)
	item_btns.add_child(del_item_btn)

	_add_header(right_room_panel, "SELECTED ITEM TRANSFORM")
	item_inst_name_edit = _add_labeled_line_edit(right_room_panel, "Instance Name:", "", func(v: String):
		if _updating_ui or selected_item_idx < 0: return
		var items: Array = room_cfg.get("items", [])
		if selected_item_idx < items.size():
			items[selected_item_idx]["instance_name"] = v
			_refresh_room_items_list()
			_rebuild_preview()
	)

	var ipos := _add_vec3_spins(right_room_panel, "Position (X, Y, Z) [or Drag Arrows]:", -30.0, 30.0, 0.1, Vector3.ZERO, func(v: Vector3):
		if _updating_ui or selected_item_idx < 0: return
		var items: Array = room_cfg.get("items", [])
		if selected_item_idx < items.size():
			items[selected_item_idx]["position"] = [v.x, v.y, v.z]
			_rebuild_preview()
	)
	item_pos_x = ipos[0]
	item_pos_y = ipos[1]
	item_pos_z = ipos[2]

	item_rot_y = _add_labeled_spin(right_room_panel, "Yaw Rotation:", -360.0, 360.0, 15.0, 0.0, func(v: float):
		if _updating_ui or selected_item_idx < 0: return
		var items: Array = room_cfg.get("items", [])
		if selected_item_idx < items.size():
			items[selected_item_idx]["rotation"] = [0.0, v, 0.0]
			_rebuild_preview()
	)

	item_scale_spin = _add_labeled_spin(right_room_panel, "Uniform Scale:", 0.1, 10.0, 0.1, 1.0, func(v: float):
		if _updating_ui or selected_item_idx < 0: return
		var items: Array = room_cfg.get("items", [])
		if selected_item_idx < items.size():
			items[selected_item_idx]["scale"] = [v, v, v]
			_rebuild_preview()
	)

	_add_header(right_room_panel, "ROOM LIGHTS")
	room_lights_list = ItemList.new()
	room_lights_list.custom_minimum_size = Vector2(0, 75)
	room_lights_list.item_selected.connect(func(idx: int):
		selected_light_idx = idx
		_populate_room_light_inspector()
	)
	right_room_panel.add_child(room_lights_list)

	var l_btns := HBoxContainer.new()
	right_room_panel.add_child(l_btns)
	var add_l_btn := Button.new()
	add_l_btn.text = "+ Add Light"
	add_l_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_l_btn.pressed.connect(_on_add_room_light)
	l_btns.add_child(add_l_btn)

	var del_l_btn := Button.new()
	del_l_btn.text = "Remove Light"
	del_l_btn.pressed.connect(_on_remove_room_light)
	l_btns.add_child(del_l_btn)

	var lpos := _add_vec3_spins(right_room_panel, "Light Pos (X, Y, Z):", -30.0, 30.0, 0.25, Vector3(0, 3.4, 0), func(v: Vector3):
		if _updating_ui: return
		var lights: Array = room_cfg.get("lights", [])
		if selected_light_idx >= 0 and selected_light_idx < lights.size():
			lights[selected_light_idx]["position"] = [v.x, v.y, v.z]
			_rebuild_preview()
	)
	rlight_pos_x = lpos[0]
	rlight_pos_y = lpos[1]
	rlight_pos_z = lpos[2]

	rlight_color = _add_labeled_color(right_room_panel, "Light Color:", Color(0.85, 0.72, 0.52), func(c: Color):
		if _updating_ui: return
		var lights: Array = room_cfg.get("lights", [])
		if selected_light_idx >= 0 and selected_light_idx < lights.size():
			lights[selected_light_idx]["color"] = [c.r, c.g, c.b]
			_rebuild_preview()
	)

	rlight_energy = _add_labeled_spin(right_room_panel, "Light Energy:", 0.0, 8.0, 0.1, 1.0, func(v: float):
		if _updating_ui: return
		var lights: Array = room_cfg.get("lights", [])
		if selected_light_idx >= 0 and selected_light_idx < lights.size():
			lights[selected_light_idx]["energy"] = v
			_rebuild_preview()
	)

	rlight_range = _add_labeled_spin(right_room_panel, "Light Range:", 1.0, 30.0, 0.5, 9.0, func(v: float):
		if _updating_ui: return
		var lights: Array = room_cfg.get("lights", [])
		if selected_light_idx >= 0 and selected_light_idx < lights.size():
			lights[selected_light_idx]["range"] = v
			_rebuild_preview()
	)


func _switch_mode(new_mode: Mode) -> void:
	current_mode = new_mode
	mode_btn_object.button_pressed = (new_mode == Mode.OBJECT_EDITOR)
	mode_btn_room.button_pressed = (new_mode == Mode.ROOM_EDITOR)

	left_object_panel.visible = (new_mode == Mode.OBJECT_EDITOR)
	right_object_panel.visible = (new_mode == Mode.OBJECT_EDITOR)
	left_room_panel.visible = (new_mode == Mode.ROOM_EDITOR)
	right_room_panel.visible = (new_mode == Mode.ROOM_EDITOR)

	var grid := preview_root_3d.get_node_or_null("ObjectFloorGrid")
	if grid != null:
		grid.visible = (new_mode == Mode.OBJECT_EDITOR)
	preview_key_light.visible = (new_mode == Mode.OBJECT_EDITOR)

	_refresh_saved_lists()
	if new_mode == Mode.OBJECT_EDITOR:
		_populate_object_ui()
	else:
		if selected_item_idx < 0 and not room_cfg.get("items", []).is_empty():
			selected_item_idx = 0
		_populate_room_ui()

	_reset_camera_for_mode()
	_rebuild_preview()


func _reset_camera_for_mode() -> void:
	if current_mode == Mode.OBJECT_EDITOR:
		_cam_target = Vector3(0.0, 0.75, 0.0)
		_cam_yaw = -0.55
		_cam_pitch = -0.32
		_cam_distance = 3.4
	else:
		_cam_target = Vector3(0.0, 1.5, 0.0)
		_cam_yaw = -0.45
		_cam_pitch = -0.45
		_cam_distance = 12.0
	_update_camera_transform()


func _update_camera_transform() -> void:
	if preview_camera == null:
		return
	var dir := Vector3(
		cos(_cam_pitch) * sin(_cam_yaw),
		-sin(_cam_pitch),
		cos(_cam_pitch) * cos(_cam_yaw)
	)
	preview_camera.position = _cam_target + dir * _cam_distance
	preview_camera.look_at(_cam_target, Vector3.UP)
	_update_gizmo_scale()


func _update_gizmo_scale() -> void:
	if gizmo_root != null and gizmo_root.visible and preview_camera != null:
		var dist := preview_camera.global_position.distance_to(gizmo_root.global_position)
		var s := clampf(dist * 0.14, 0.55, 3.2)
		gizmo_root.scale = Vector3(s, s, s)


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_mode == Mode.ROOM_EDITOR:
					var hit_axis := _pick_gizmo_axis_at_screen_pos(event.position)
					if hit_axis >= 0 and selected_item_idx >= 0:
						_dragging_gizmo_axis = hit_axis
						_set_gizmo_highlight(hit_axis)
						var items: Array = room_cfg.get("items", [])
						var pos_arr: Array = items[selected_item_idx].get("position", [0.0, 0.0, 0.0])
						_gizmo_drag_start_pos = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
						_gizmo_drag_start_param = _get_axis_param_at_screen_pos(event.position, gizmo_root.global_position, hit_axis)
						var axis_names: Array[String] = ["X", "Y", "Z"]
						_set_status("Dragging %s-Axis Vector Arrow..." % axis_names[hit_axis])
						return
					# Click to select an object in the 3D room if not clicking gizmo
					if _try_select_room_item_at_screen_pos(event.position):
						_set_status("Selected '%s'" % str(room_cfg["items"][selected_item_idx].get("instance_name", "Item")))
				_orbit_dragging = true
			else:
				if _dragging_gizmo_axis >= 0:
					_dragging_gizmo_axis = -1
					_set_gizmo_highlight(_hovered_gizmo_axis)
					_set_status("Moved item position.")
				_orbit_dragging = false
		elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cam_distance = maxf(0.6, _cam_distance * 0.88)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cam_distance = minf(50.0, _cam_distance * 1.12)
			_update_camera_transform()

	elif event is InputEventMouseMotion:
		if _dragging_gizmo_axis >= 0 and current_mode == Mode.ROOM_EDITOR:
			var items: Array = room_cfg.get("items", [])
			if selected_item_idx >= 0 and selected_item_idx < items.size():
				var drag_origin := _gizmo_drag_start_pos + Vector3(0.0, 0.6, 0.0)
				var cur_param := _get_axis_param_at_screen_pos(event.position, drag_origin, _dragging_gizmo_axis)
				var delta_param := cur_param - _gizmo_drag_start_param
				var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
				var new_pos := _gizmo_drag_start_pos + axes[_dragging_gizmo_axis] * delta_param
				# Snap to 0.05m increments for clean PS1 placement
				new_pos = Vector3(
					snappedf(new_pos.x, 0.05),
					snappedf(new_pos.y, 0.05),
					snappedf(new_pos.z, 0.05)
				)
				items[selected_item_idx]["position"] = [new_pos.x, new_pos.y, new_pos.z]
				_update_selected_item_node_fast(new_pos)
				_populate_room_item_inspector()
			return

		if current_mode == Mode.ROOM_EDITOR and not _orbit_dragging and not _pan_dragging:
			var hover_axis := _pick_gizmo_axis_at_screen_pos(event.position)
			if hover_axis != _hovered_gizmo_axis:
				_hovered_gizmo_axis = hover_axis
				_set_gizmo_highlight(_hovered_gizmo_axis)

		if _orbit_dragging:
			_cam_yaw -= event.relative.x * 0.008
			_cam_pitch = clampf(_cam_pitch - event.relative.y * 0.008, -1.45, 1.45)
			_update_camera_transform()
		elif _pan_dragging:
			var right := preview_camera.global_transform.basis.x
			var up := preview_camera.global_transform.basis.y
			var pan_speed := _cam_distance * 0.0025
			_cam_target -= right * event.relative.x * pan_speed
			_cam_target += up * event.relative.y * pan_speed
			_update_camera_transform()


func _update_selected_item_node_fast(new_pos: Vector3) -> void:
	# Directly move the live 3D node and gizmo during arrow drag without full scene rebuild
	if preview_content_holder.get_child_count() > 0:
		var room_node := preview_content_holder.get_child(0)
		var items_holder := room_node.get_node_or_null("Items")
		if items_holder != null and selected_item_idx >= 0 and selected_item_idx < items_holder.get_child_count():
			var item_node := items_holder.get_child(selected_item_idx)
			if item_node is Node3D:
				item_node.position = new_pos
	_update_room_selection_highlight()


func _rebuild_preview() -> void:
	for child in preview_content_holder.get_children():
		child.queue_free()

	if current_mode == Mode.OBJECT_EDITOR:
		preview_selection_box.visible = false
		if gizmo_root != null:
			gizmo_root.visible = false
		var obj_node := SimulacrumBuilder.build_object_node(object_cfg)
		preview_content_holder.add_child(obj_node)
	else:
		var room_node := SimulacrumBuilder.build_room_node(room_cfg, false)
		preview_content_holder.add_child(room_node)
		_update_room_selection_highlight()


func _update_room_selection_highlight() -> void:
	if current_mode != Mode.ROOM_EDITOR:
		preview_selection_box.visible = false
		if gizmo_root != null:
			gizmo_root.visible = false
		return
	var items: Array = room_cfg.get("items", [])
	if selected_item_idx >= 0 and selected_item_idx < items.size():
		var item: Dictionary = items[selected_item_idx]
		var pos_arr: Array = item.get("position", [0.0, 0.0, 0.0])
		var center_pos := Vector3(float(pos_arr[0]), float(pos_arr[1]) + 0.6, float(pos_arr[2]))
		preview_selection_box.position = center_pos
		preview_selection_box.visible = true
		if gizmo_root != null:
			gizmo_root.position = center_pos
			gizmo_root.visible = true
			_update_gizmo_scale()
	else:
		preview_selection_box.visible = false
		if gizmo_root != null:
			gizmo_root.visible = false


func _current_part() -> Dictionary:
	var parts: Array = object_cfg.get("parts", [])
	if parts.is_empty():
		parts.append(SimulacrumBuilder.default_part_config("BaseMesh"))
	selected_part_idx = clampi(selected_part_idx, 0, parts.size() - 1)
	return parts[selected_part_idx]


func _current_part_mat() -> Dictionary:
	var part := _current_part()
	if not part.has("material"):
		part["material"] = SimulacrumBuilder.default_material_config()
	return part["material"]


func _refresh_saved_lists() -> void:
	var objs := SimulacrumBuilder.list_saved_objects()
	obj_saved_dropdown.clear()
	room_catalog_option.clear()
	for o in objs:
		obj_saved_dropdown.add_item(o)
		room_catalog_option.add_item(o)

	var rooms := SimulacrumBuilder.list_saved_rooms()
	room_saved_dropdown.clear()
	for r in rooms:
		room_saved_dropdown.add_item(r)


func _refresh_parts_list_labels() -> void:
	obj_parts_list.clear()
	var parts: Array = object_cfg.get("parts", [])
	for idx in parts.size():
		var p: Dictionary = parts[idx]
		obj_parts_list.add_item("%d: %s (%s)" % [idx + 1, str(p.get("name", "Part")), str(p.get("shape", "box"))])
	if selected_part_idx >= 0 and selected_part_idx < parts.size():
		obj_parts_list.select(selected_part_idx)


func _populate_object_ui() -> void:
	_updating_ui = true
	obj_name_edit.text = str(object_cfg.get("name", "custom_object"))
	_refresh_parts_list_labels()

	var part := _current_part()
	part_name_edit.text = str(part.get("name", "BaseMesh"))

	var shape_idx := SHAPE_MODES.find(str(part.get("shape", "box")))
	part_shape_option.selected = maxi(0, shape_idx)
	part_model_path_edit.text = str(part.get("model_path", ""))

	var sz: Array = part.get("size", [1.0, 1.0, 1.0])
	part_size_x.value = float(sz[0])
	part_size_y.value = float(sz[1])
	part_size_z.value = float(sz[2])

	part_subdiv_spin.value = int(part.get("subdivide", 2))

	var pos: Array = part.get("position", [0.0, 0.5, 0.0])
	part_pos_x.value = float(pos[0])
	part_pos_y.value = float(pos[1])
	part_pos_z.value = float(pos[2])

	var rot: Array = part.get("rotation", [0.0, 0.0, 0.0])
	part_rot_x.value = float(rot[0])
	part_rot_y.value = float(rot[1])
	part_rot_z.value = float(rot[2])

	part_collision_chk.button_pressed = bool(part.get("collision", true))

	var mat := _current_part_mat()
	var col: Array = mat.get("albedo_color", [0.75, 0.75, 0.75, 1.0])
	obj_mat_color.color = Color(float(col[0]), float(col[1]), float(col[2]), 1.0)

	var tex_idx := TEXTURE_MODES.find(str(mat.get("texture_mode", "procedural_concrete")))
	obj_mat_tex_option.selected = maxi(0, tex_idx)
	obj_mat_custom_tex_edit.text = str(mat.get("custom_texture_path", ""))

	var uvs: Array = mat.get("uv_scale", [2.0, 2.0])
	obj_mat_uv_x.value = float(uvs[0])
	obj_mat_uv_y.value = float(uvs[1])

	obj_mat_snap_chk.button_pressed = bool(mat.get("vertex_snap_enabled", true))
	var sres: Array = mat.get("snap_resolution", [213.0, 120.0])
	obj_mat_snap_x.value = float(sres[0])
	obj_mat_snap_y.value = float(sres[1])

	obj_mat_affine_slider.value = float(mat.get("affine_amount", 1.0))
	obj_mat_dark_start.value = float(mat.get("vertex_darkening_start", 4.0))
	obj_mat_dark_end.value = float(mat.get("vertex_darkening_end", 18.0))

	var l_cfg: Dictionary = object_cfg.get("light", {})
	obj_light_chk.button_pressed = bool(l_cfg.get("enabled", false))
	var lcol: Array = l_cfg.get("color", [0.95, 0.80, 0.55])
	obj_light_color.color = Color(float(lcol[0]), float(lcol[1]), float(lcol[2]))
	obj_light_energy.value = float(l_cfg.get("energy", 1.2))
	obj_light_range.value = float(l_cfg.get("range", 6.0))

	_updating_ui = false


func _populate_room_ui() -> void:
	_updating_ui = true
	room_name_edit.text = str(room_cfg.get("name", "silent_corridor"))
	var dims: Array = room_cfg.get("dimensions", [12.0, 4.0, 24.0])
	room_dim_w.value = float(dims[0])
	room_dim_h.value = float(dims[1])
	room_dim_d.value = float(dims[2])

	room_ceil_chk.button_pressed = bool(room_cfg.get("has_ceiling", true))
	room_wall_n_chk.button_pressed = bool(room_cfg.get("wall_north", true))
	room_wall_s_chk.button_pressed = bool(room_cfg.get("wall_south", true))
	room_wall_e_chk.button_pressed = bool(room_cfg.get("wall_east", true))
	room_wall_w_chk.button_pressed = bool(room_cfg.get("wall_west", true))

	room_fog_chk.button_pressed = bool(room_cfg.get("fog_enabled", true))
	var fcol: Array = room_cfg.get("fog_color", [0.14, 0.15, 0.16])
	room_fog_color.color = Color(float(fcol[0]), float(fcol[1]), float(fcol[2]))
	room_fog_density.value = float(room_cfg.get("fog_density", 0.14))

	_updating_ui = false
	_populate_room_surface_ui()
	_refresh_room_items_list()
	_populate_room_item_inspector()
	_refresh_room_lights_list()
	_populate_room_light_inspector()


func _populate_room_surface_ui() -> void:
	_updating_ui = true
	var mat: Dictionary = room_cfg.get(room_surface_target, SimulacrumBuilder.default_material_config())
	var col: Array = mat.get("albedo_color", [0.4, 0.4, 0.4, 1.0])
	room_surf_color.color = Color(float(col[0]), float(col[1]), float(col[2]))
	var tidx := TEXTURE_MODES.find(str(mat.get("texture_mode", "procedural_concrete")))
	room_surf_tex_option.selected = maxi(0, tidx)
	var uvs: Array = mat.get("uv_scale", [8.0, 8.0])
	room_surf_uv_x.value = float(uvs[0])
	room_surf_uv_y.value = float(uvs[1])
	room_surf_affine.value = float(mat.get("affine_amount", 1.0))
	_updating_ui = false


func _refresh_room_items_list() -> void:
	room_items_list.clear()
	var items: Array = room_cfg.get("items", [])
	for idx in items.size():
		var it: Dictionary = items[idx]
		room_items_list.add_item("%d: %s [%s]" % [idx + 1, str(it.get("instance_name", "Item")), str(it.get("object_name", ""))])
	if selected_item_idx >= 0 and selected_item_idx < items.size():
		room_items_list.select(selected_item_idx)


func _populate_room_item_inspector() -> void:
	_updating_ui = true
	var items: Array = room_cfg.get("items", [])
	if selected_item_idx >= 0 and selected_item_idx < items.size():
		var it: Dictionary = items[selected_item_idx]
		item_inst_name_edit.text = str(it.get("instance_name", "Item"))
		var pos: Array = it.get("position", [0.0, 0.0, 0.0])
		item_pos_x.value = float(pos[0])
		item_pos_y.value = float(pos[1])
		item_pos_z.value = float(pos[2])
		var rot: Array = it.get("rotation", [0.0, 0.0, 0.0])
		item_rot_y.value = float(rot[1])
		var scl: Array = it.get("scale", [1.0, 1.0, 1.0])
		item_scale_spin.value = float(scl[0])
	else:
		item_inst_name_edit.text = ""
	_updating_ui = false


func _refresh_room_lights_list() -> void:
	room_lights_list.clear()
	var lights: Array = room_cfg.get("lights", [])
	for idx in lights.size():
		var l: Dictionary = lights[idx]
		room_lights_list.add_item("%d: %s" % [idx + 1, str(l.get("name", "Light"))])
	if selected_light_idx >= 0 and selected_light_idx < lights.size():
		room_lights_list.select(selected_light_idx)


func _populate_room_light_inspector() -> void:
	_updating_ui = true
	var lights: Array = room_cfg.get("lights", [])
	if selected_light_idx >= 0 and selected_light_idx < lights.size():
		var l: Dictionary = lights[selected_light_idx]
		var pos: Array = l.get("position", [0.0, 3.4, 0.0])
		rlight_pos_x.value = float(pos[0])
		rlight_pos_y.value = float(pos[1])
		rlight_pos_z.value = float(pos[2])
		var col: Array = l.get("color", [0.85, 0.72, 0.52])
		rlight_color.color = Color(float(col[0]), float(col[1]), float(col[2]))
		rlight_energy.value = float(l.get("energy", 1.0))
		rlight_range.value = float(l.get("range", 9.0))
	_updating_ui = false


# Actions: Object Editor
func _on_load_selected_object() -> void:
	if obj_saved_dropdown.selected < 0:
		return
	var name_to_load := obj_saved_dropdown.get_item_text(obj_saved_dropdown.selected)
	var loaded := SimulacrumBuilder.load_object_json(name_to_load)
	if not loaded.is_empty():
		object_cfg = loaded
		selected_part_idx = 0
		_populate_object_ui()
		_rebuild_preview()
		_set_status("Loaded object '%s'" % name_to_load)


func _on_new_object() -> void:
	object_cfg = SimulacrumBuilder.default_object_config("new_object")
	selected_part_idx = 0
	_populate_object_ui()
	_rebuild_preview()
	_set_status("Created blank object config.")


func _on_save_object() -> void:
	var res := SimulacrumBuilder.save_object(object_cfg)
	_refresh_saved_lists()
	_populate_object_ui()
	_set_status("Saved Object -> %s & %s" % [res["json_path"], res["scene_path"]])


func _on_add_object_part() -> void:
	var parts: Array = object_cfg.get("parts", [])
	var new_part := SimulacrumBuilder.default_part_config("Part_%d" % (parts.size() + 1))
	new_part["position"] = [0.0, 1.0, 0.0]
	parts.append(new_part)
	selected_part_idx = parts.size() - 1
	_populate_object_ui()
	_rebuild_preview()


func _on_duplicate_object_part() -> void:
	var parts: Array = object_cfg.get("parts", [])
	if selected_part_idx >= 0 and selected_part_idx < parts.size():
		var copy: Dictionary = parts[selected_part_idx].duplicate(true)
		copy["name"] = str(copy.get("name", "Part")) + "_Copy"
		parts.append(copy)
		selected_part_idx = parts.size() - 1
		_populate_object_ui()
		_rebuild_preview()


func _on_remove_object_part() -> void:
	var parts: Array = object_cfg.get("parts", [])
	if parts.size() <= 1:
		_set_status("Object must have at least 1 mesh part.")
		return
	parts.remove_at(selected_part_idx)
	selected_part_idx = clampi(selected_part_idx, 0, parts.size() - 1)
	_populate_object_ui()
	_rebuild_preview()


# Actions: Room Editor
func _on_load_selected_room() -> void:
	if room_saved_dropdown.selected < 0:
		return
	var name_to_load := room_saved_dropdown.get_item_text(room_saved_dropdown.selected)
	var loaded := SimulacrumBuilder.load_room_json(name_to_load)
	if not loaded.is_empty():
		room_cfg = loaded
		selected_item_idx = 0 if not room_cfg.get("items", []).is_empty() else -1
		selected_light_idx = 0
		_populate_room_ui()
		_rebuild_preview()
		_set_status("Loaded room '%s'" % name_to_load)


func _on_new_room() -> void:
	room_cfg = SimulacrumBuilder.default_room_config("new_room")
	selected_item_idx = -1
	selected_light_idx = 0
	_populate_room_ui()
	_rebuild_preview()
	_set_status("Created blank room config.")


func _on_save_room() -> void:
	var res := SimulacrumBuilder.save_room(room_cfg, true)
	_refresh_saved_lists()
	_populate_room_ui()
	_set_status("Saved Room -> %s & %s" % [res["json_path"], res["scene_path"]])


func _on_save_room_as_main() -> void:
	var res := SimulacrumBuilder.save_room(room_cfg, true)
	var node := SimulacrumBuilder.build_room_node(room_cfg, true)
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed, "res://scenes/main.tscn")
	node.free()
	_refresh_saved_lists()
	_set_status("Saved Room '%s' AND updated res://scenes/main.tscn!" % res["name"])


func _on_place_item_in_room() -> void:
	if room_catalog_option.selected < 0:
		_set_status("Save an object first to place it in the room.")
		return
	var obj_name := room_catalog_option.get_item_text(room_catalog_option.selected)
	var items: Array = room_cfg.get("items", [])
	var entry := {
		"instance_name": "%s_%d" % [obj_name, items.size() + 1],
		"object_name": obj_name,
		"position": [0.0, 0.0, 0.0],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.0, 1.0, 1.0]
	}
	items.append(entry)
	selected_item_idx = items.size() - 1
	_refresh_room_items_list()
	_populate_room_item_inspector()
	_rebuild_preview()
	_set_status("Placed '%s' into room. Drag X/Y/Z arrows to move!" % obj_name)


func _on_duplicate_room_item() -> void:
	var items: Array = room_cfg.get("items", [])
	if selected_item_idx >= 0 and selected_item_idx < items.size():
		var copy: Dictionary = items[selected_item_idx].duplicate(true)
		copy["instance_name"] = "%s_copy" % str(copy.get("instance_name", "Item"))
		var pos: Array = copy.get("position", [0.0, 0.0, 0.0])
		copy["position"] = [float(pos[0]) + 1.0, float(pos[1]), float(pos[2])]
		items.append(copy)
		selected_item_idx = items.size() - 1
		_refresh_room_items_list()
		_populate_room_item_inspector()
		_rebuild_preview()


func _on_delete_room_item() -> void:
	var items: Array = room_cfg.get("items", [])
	if selected_item_idx >= 0 and selected_item_idx < items.size():
		items.remove_at(selected_item_idx)
		selected_item_idx = clampi(selected_item_idx, 0, items.size() - 1) if not items.is_empty() else -1
		_refresh_room_items_list()
		_populate_room_item_inspector()
		_rebuild_preview()


func _on_add_room_light() -> void:
	var lights: Array = room_cfg.get("lights", [])
	lights.append({
		"name": "Light_%d" % (lights.size() + 1),
		"position": [0.0, 3.2, 0.0],
		"color": [0.85, 0.72, 0.52],
		"energy": 1.0,
		"range": 9.0
	})
	selected_light_idx = lights.size() - 1
	_refresh_room_lights_list()
	_populate_room_light_inspector()
	_rebuild_preview()


func _on_remove_room_light() -> void:
	var lights: Array = room_cfg.get("lights", [])
	if selected_light_idx >= 0 and selected_light_idx < lights.size():
		lights.remove_at(selected_light_idx)
		selected_light_idx = clampi(selected_light_idx, 0, lights.size() - 1)
		_refresh_room_lights_list()
		_populate_room_light_inspector()
		_rebuild_preview()


func _set_status(msg: String) -> void:
	if status_label != null:
		status_label.text = msg + "  "


# UI Builder Helpers
func _add_header(parent: Control, title: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(0.90, 0.75, 0.48))
	parent.add_child(lbl)


func _add_labeled_line_edit(parent: Control, label_text: String, initial: String, cb: Callable) -> LineEdit:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	var edit := LineEdit.new()
	edit.text = initial
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(cb)
	row.add_child(edit)
	return edit


func _add_labeled_option(parent: Control, label_text: String, items: Array[String], cb: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.clip_text = true
	for it in items:
		opt.add_item(it)
	opt.item_selected.connect(cb)
	row.add_child(opt)
	return opt


func _add_labeled_spin(parent: Control, label_text: String, min_v: float, max_v: float, step_v: float, initial: float, cb: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(125, 0)
	row.add_child(lbl)
	var sp := SpinBox.new()
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = step_v
	sp.value = initial
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.value_changed.connect(cb)
	row.add_child(sp)
	return sp


func _add_labeled_slider(parent: Control, label_text: String, min_v: float, max_v: float, step_v: float, initial: float, cb: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(125, 0)
	row.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = step_v
	sl.value = initial
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(cb)
	row.add_child(sl)
	return sl


func _add_labeled_checkbox(parent: Control, label_text: String, initial: bool, cb: Callable) -> CheckBox:
	var chk := CheckBox.new()
	chk.text = label_text
	chk.button_pressed = initial
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk.toggled.connect(cb)
	parent.add_child(chk)
	return chk


func _add_labeled_color(parent: Control, label_text: String, initial: Color, cb: Callable) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(125, 0)
	row.add_child(lbl)
	var btn := ColorPickerButton.new()
	btn.color = initial
	btn.edit_alpha = false
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 26)
	btn.color_changed.connect(cb)
	row.add_child(btn)
	return btn


func _add_vec2_spins(parent: Control, label_text: String, min_v: float, max_v: float, step_v: float, initial: Vector2, cb: Callable) -> Array[SpinBox]:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)

	var sx := SpinBox.new()
	sx.min_value = min_v
	sx.max_value = max_v
	sx.step = step_v
	sx.value = initial.x
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sx)

	var sy := SpinBox.new()
	sy.min_value = min_v
	sy.max_value = max_v
	sy.step = step_v
	sy.value = initial.y
	sy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sy)

	var emit_vec := func(_val: float):
		cb.call(Vector2(sx.value, sy.value))
	sx.value_changed.connect(emit_vec)
	sy.value_changed.connect(emit_vec)
	return [sx, sy]


func _add_vec3_spins(parent: Control, label_text: String, min_v: float, max_v: float, step_v: float, initial: Vector3, cb: Callable) -> Array[SpinBox]:
	var lbl := Label.new()
	lbl.text = label_text
	parent.add_child(lbl)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var sx := SpinBox.new()
	sx.prefix = "X:"
	sx.min_value = min_v
	sx.max_value = max_v
	sx.step = step_v
	sx.value = initial.x
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sx)

	var sy := SpinBox.new()
	sy.prefix = "Y:"
	sy.min_value = min_v
	sy.max_value = max_v
	sy.step = step_v
	sy.value = initial.y
	sy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sy)

	var sz := SpinBox.new()
	sz.prefix = "Z:"
	sz.min_value = min_v
	sz.max_value = max_v
	sz.step = step_v
	sz.value = initial.z
	sz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sz)

	var emit_vec := func(_val: float):
		cb.call(Vector3(sx.value, sy.value, sz.value))
	sx.value_changed.connect(emit_vec)
	sy.value_changed.connect(emit_vec)
	sz.value_changed.connect(emit_vec)
	return [sx, sy, sz]
