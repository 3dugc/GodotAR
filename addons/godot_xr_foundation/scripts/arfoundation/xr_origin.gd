extends Node
class_name XROrigin

signal TrackablesParentTransformChanged

@export var origin_path: NodePath
@export var camera_path: NodePath
@export var trackables_parent_path: NodePath
@export var camera_floor_offset_object_path: NodePath
@export var CameraYOffset := 1.7

var Camera: Camera3D = null
var Origin: Node3D = null
var TrackablesParent: Node3D = null
var CameraFloorOffsetObject: Node3D = null
var RequestedTrackingOriginMode := &"NotSpecified"
var CurrentTrackingOriginMode := &"Unknown"

var _last_trackables_parent_transform := Transform3D.IDENTITY


func _ready() -> void:
	_refresh_references()
	set_process(true)


func _process(_delta: float) -> void:
	_refresh_references()
	if TrackablesParent and TrackablesParent.global_transform != _last_trackables_parent_transform:
		_last_trackables_parent_transform = TrackablesParent.global_transform
		TrackablesParentTransformChanged.emit()


func get_origin_node() -> Node3D:
	_refresh_references()
	return Origin


func get_camera() -> Camera3D:
	_refresh_references()
	return Camera


func get_trackables_parent() -> Node3D:
	_refresh_references()
	return TrackablesParent


func get_camera_floor_offset_object() -> Node3D:
	_refresh_references()
	return CameraFloorOffsetObject


func get_camera_in_origin_space_pos() -> Vector3:
	_refresh_references()
	if Origin == null or Camera == null:
		return Vector3.ZERO
	return Origin.global_transform.affine_inverse() * Camera.global_position


func get_camera_in_origin_space_height() -> float:
	return get_camera_in_origin_space_pos().y


func get_origin_in_camera_space_pos() -> Vector3:
	_refresh_references()
	if Origin == null or Camera == null:
		return Vector3.ZERO
	return Camera.global_transform.affine_inverse() * Origin.global_position


func set_camera_y_offset(value: float) -> void:
	CameraYOffset = value
	_refresh_references()
	if CameraFloorOffsetObject and CameraFloorOffsetObject != Origin:
		var local_position := CameraFloorOffsetObject.position
		local_position.y = CameraYOffset
		CameraFloorOffsetObject.position = local_position


func SetCamera(camera: Camera3D) -> void:
	Camera = camera
	if camera:
		camera_path = get_path_to(camera)


func SetOrigin(origin: Node3D) -> void:
	Origin = origin
	if origin:
		origin_path = get_path_to(origin)


func SetTrackablesParent(parent: Node3D) -> void:
	TrackablesParent = parent
	if parent:
		trackables_parent_path = get_path_to(parent)
		_last_trackables_parent_transform = parent.global_transform


func MoveCameraToWorldLocation(desired_world_location: Vector3) -> bool:
	_refresh_references()
	if Origin == null or Camera == null:
		return false
	var delta := desired_world_location - Camera.global_position
	Origin.global_position += delta
	return true


func RotateAroundCameraUsingOriginUp(angle_degrees: float) -> bool:
	_refresh_references()
	if Origin == null or Camera == null:
		return false
	return RotateAroundCameraPosition(Origin.global_transform.basis.y.normalized(), angle_degrees)


func RotateAroundCameraPosition(vector: Vector3, angle_degrees: float) -> bool:
	_refresh_references()
	if Origin == null or Camera == null or vector == Vector3.ZERO:
		return false
	var rotation := Basis(vector.normalized(), deg_to_rad(angle_degrees))
	var pivot := Camera.global_position
	Origin.global_position = pivot + rotation * (Origin.global_position - pivot)
	Origin.global_basis = rotation * Origin.global_basis
	return true


func MatchOriginUp(destination_up: Vector3) -> bool:
	_refresh_references()
	if Origin == null or destination_up == Vector3.ZERO:
		return false
	var current_up := Origin.global_transform.basis.y.normalized()
	var target_up := destination_up.normalized()
	var axis := current_up.cross(target_up)
	if axis.length() < 0.0001:
		return true
	var angle := current_up.angle_to(target_up)
	var rotation := Basis(axis.normalized(), angle)
	Origin.global_basis = rotation * Origin.global_basis
	return true


func MatchOriginUpCameraForward(destination_up: Vector3, destination_forward: Vector3) -> bool:
	_refresh_references()
	if Origin == null or Camera == null:
		return false
	if not MatchOriginUp(destination_up):
		return false
	var current_forward := (-Camera.global_transform.basis.z).slide(destination_up).normalized()
	var target_forward := destination_forward.slide(destination_up).normalized()
	return _rotate_origin_forward(current_forward, target_forward, destination_up)


func MatchOriginUpOriginForward(destination_up: Vector3, destination_forward: Vector3) -> bool:
	_refresh_references()
	if Origin == null:
		return false
	if not MatchOriginUp(destination_up):
		return false
	var current_forward := (-Origin.global_transform.basis.z).slide(destination_up).normalized()
	var target_forward := destination_forward.slide(destination_up).normalized()
	return _rotate_origin_forward(current_forward, target_forward, destination_up)


func MakeContentAppearAt(content: Node3D, target: Variant, rotation: Variant = null) -> bool:
	return make_content_appear_at(content, target, rotation)


func make_content_appear_at(content: Node3D, target: Variant, rotation: Variant = null) -> bool:
	_refresh_references()
	if Origin == null or content == null:
		return false
	var desired_transform := _target_to_transform(content, target, rotation)
	var content_in_origin := Origin.global_transform.affine_inverse() * content.global_transform
	Origin.global_transform = desired_transform * content_in_origin.affine_inverse()
	return true


func TransformPose(pose: Variant) -> Transform3D:
	_refresh_references()
	var transform := _pose_to_transform(pose)
	if Origin == null:
		return transform
	return Origin.global_transform * transform


func InverseTransformPose(pose: Variant) -> Transform3D:
	_refresh_references()
	var transform := _pose_to_transform(pose)
	if Origin == null:
		return transform
	return Origin.global_transform.affine_inverse() * transform


func GetCamera() -> Camera3D:
	return get_camera()


func GetOrigin() -> Node3D:
	return get_origin_node()


func GetTrackablesParent() -> Node3D:
	return get_trackables_parent()


func GetCameraFloorOffsetObject() -> Node3D:
	return get_camera_floor_offset_object()


func GetCameraInOriginSpacePos() -> Vector3:
	return get_camera_in_origin_space_pos()


func GetCameraInOriginSpaceHeight() -> float:
	return get_camera_in_origin_space_height()


func GetOriginInCameraSpacePos() -> Vector3:
	return get_origin_in_camera_space_pos()


func to_dictionary() -> Dictionary:
	_refresh_references()
	return {
		"manager": true,
		"camera": Camera.name if Camera else "",
		"origin": Origin.name if Origin else "",
		"trackables_parent": TrackablesParent.name if TrackablesParent else "",
		"camera_floor_offset_object": CameraFloorOffsetObject.name if CameraFloorOffsetObject else "",
		"camera_y_offset": CameraYOffset,
		"camera_in_origin_space_height": get_camera_in_origin_space_height(),
		"camera_in_origin_space_pos": _vector3_array(get_camera_in_origin_space_pos()),
		"origin_in_camera_space_pos": _vector3_array(get_origin_in_camera_space_pos()),
		"requested_tracking_origin_mode": String(RequestedTrackingOriginMode),
		"current_tracking_origin_mode": String(CurrentTrackingOriginMode),
	}


func _refresh_references() -> void:
	Origin = _resolve_node3d(origin_path)
	if Origin == null:
		Origin = _find_origin_candidate()
	if Origin == null and get_parent() is Node3D:
		Origin = get_parent()

	Camera = _resolve_camera(camera_path)
	if Camera == null and Origin:
		Camera = _find_camera_in_tree(Origin)
	if Camera == null and get_viewport():
		Camera = get_viewport().get_camera_3d()

	CameraFloorOffsetObject = _resolve_node3d(camera_floor_offset_object_path)
	if CameraFloorOffsetObject == null:
		CameraFloorOffsetObject = Origin

	TrackablesParent = _resolve_node3d(trackables_parent_path)
	if TrackablesParent == null:
		TrackablesParent = _find_or_create_trackables_parent()


func _resolve_node3d(path: NodePath) -> Node3D:
	if path == NodePath():
		return null
	var node := get_node_or_null(path)
	if node is Node3D:
		return node
	return null


func _resolve_camera(path: NodePath) -> Camera3D:
	if path == NodePath():
		return null
	var node := get_node_or_null(path)
	if node is Camera3D:
		return node
	return null


func _find_origin_candidate() -> Node3D:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return _find_origin_in_tree(tree.current_scene)


func _find_origin_in_tree(node: Node) -> Node3D:
	if node is XRDeviceRig or node is XROrigin3D:
		return node
	for child in node.get_children():
		var found := _find_origin_in_tree(child)
		if found:
			return found
	return null


func _find_camera_in_tree(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	if node.has_method("get_camera"):
		var camera_value: Variant = node.call("get_camera")
		if camera_value is Camera3D:
			return camera_value
	for child in node.get_children():
		var found := _find_camera_in_tree(child)
		if found:
			return found
	return null


func _find_or_create_trackables_parent() -> Node3D:
	if Origin == null:
		return null
	var existing := Origin.get_node_or_null("TrackablesParent")
	if existing is Node3D:
		return existing
	var created := Node3D.new()
	created.name = "TrackablesParent"
	Origin.add_child(created)
	trackables_parent_path = get_path_to(created)
	_last_trackables_parent_transform = created.global_transform
	return created


func _target_to_transform(content: Node3D, target: Variant, rotation: Variant = null) -> Transform3D:
	if target is Transform3D:
		return target
	if target is Dictionary:
		return _pose_to_transform(target)
	if target is Quaternion or target is Basis:
		return Transform3D(_rotation_to_basis(target), content.global_position)
	if target is Vector3:
		var basis := content.global_transform.basis
		if rotation != null:
			basis = _rotation_to_basis(rotation)
		return Transform3D(basis, target)
	return content.global_transform


func _pose_to_transform(pose: Variant) -> Transform3D:
	if pose is Transform3D:
		return pose
	if pose is Node3D:
		return pose.global_transform
	if pose is Vector3:
		return Transform3D(Basis(), pose)
	if pose is Dictionary:
		var transform_value: Variant = pose.get("transform", pose.get("pose", null))
		if transform_value is Transform3D:
			return transform_value
		var position := Vector3.ZERO
		var position_value: Variant = pose.get("position", pose.get("origin", Vector3.ZERO))
		if position_value is Vector3:
			position = position_value
		var basis := Basis()
		var rotation_value: Variant = pose.get("rotation", null)
		if rotation_value != null:
			basis = _rotation_to_basis(rotation_value)
		return Transform3D(basis, position)
	return Transform3D.IDENTITY


func _rotation_to_basis(value: Variant) -> Basis:
	if value is Basis:
		return value
	if value is Quaternion:
		return Basis(value)
	if value is Vector3:
		return Basis.from_euler(value)
	return Basis()


func _rotate_origin_forward(current_forward: Vector3, target_forward: Vector3, up: Vector3) -> bool:
	if Origin == null or current_forward == Vector3.ZERO or target_forward == Vector3.ZERO or up == Vector3.ZERO:
		return false
	var signed_angle := current_forward.signed_angle_to(target_forward, up.normalized())
	var rotation := Basis(up.normalized(), signed_angle)
	var pivot := Camera.global_position if Camera else Origin.global_position
	Origin.global_position = pivot + rotation * (Origin.global_position - pivot)
	Origin.global_basis = rotation * Origin.global_basis
	return true


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]
