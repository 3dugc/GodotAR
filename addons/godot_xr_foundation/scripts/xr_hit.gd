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
	var hit := XRHit.new(
		data.get("transform", Transform3D.IDENTITY),
		float(data.get("distance", 0.0)),
		StringName(data.get("trackable_id", "")),
		int(data.get("trackable_type", XRFoundationTypes.TrackableType.UNKNOWN)),
		data.get("raw_hit", null)
	)
	hit.position = data.get("position", hit.transform.origin)
	hit.normal = data.get("normal", Vector3.UP)
	return hit

