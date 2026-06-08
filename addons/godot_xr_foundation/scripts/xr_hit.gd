extends RefCounted
class_name XRHit

var transform: Transform3D = Transform3D.IDENTITY
var position: Vector3 = Vector3.ZERO
var normal: Vector3 = Vector3.UP
var distance := 0.0
var trackable_id: StringName = &""
var trackable_type := XRFoundationTypes.TrackableType.UNKNOWN
var raw_hit: Variant = null


func _init(
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_distance: float = 0.0,
	p_trackable_id: StringName = &"",
	p_trackable_type: int = XRFoundationTypes.TrackableType.UNKNOWN,
	p_raw_hit: Variant = null
) -> void:
	transform = p_transform
	position = p_transform.origin
	distance = p_distance
	trackable_id = p_trackable_id
	trackable_type = p_trackable_type
	raw_hit = p_raw_hit


static func from_dictionary(data: Dictionary) -> XRHit:
	var type_value: Variant = data.get("trackable_type", data.get("trackable_type_name", XRFoundationTypes.TrackableType.UNKNOWN))
	var hit := XRHit.new(
		data.get("transform", Transform3D.IDENTITY),
		float(data.get("distance", 0.0)),
		StringName(data.get("trackable_id", "")),
		XRFoundationTypes.trackable_type_from_variant(type_value),
		data.get("raw_hit", null)
	)
	hit.position = data.get("position", hit.transform.origin)
	hit.normal = data.get("normal", Vector3.UP)
	return hit


func get_pose() -> Transform3D:
	return transform


func GetPose() -> Transform3D:
	return get_pose()


func to_dictionary() -> Dictionary:
	return {
		"transform": transform,
		"pose": transform,
		"position": position,
		"normal": normal,
		"distance": distance,
		"trackable_id": trackable_id,
		"trackable_type": trackable_type,
		"raw_hit": raw_hit,
	}
