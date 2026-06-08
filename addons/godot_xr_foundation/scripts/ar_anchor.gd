extends ARTrackable
class_name ARAnchor

var node: Node3D = null
var persistent_id: StringName = &""


func _init(
	p_trackable_id: StringName = &"",
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_raw_tracker: Variant = null
) -> void:
	super._init(p_trackable_id, p_transform, p_raw_tracker)


static func from_dictionary(data: Dictionary) -> ARAnchor:
	var transform: Transform3D = data.get("transform", data.get("pose", Transform3D.IDENTITY))
	var anchor := ARAnchor.new(
		StringName(data.get("trackable_id", data.get("id", data.get("anchor_id", "")))),
		transform,
		data.get("raw_tracker", data)
	)
	anchor.persistent_id = StringName(data.get("persistent_id", data.get("native_id", "")))
	anchor.tracking_state = int(data.get("tracking_state", XRFoundationTypes.TrackingState.TRACKING))
	return anchor


func to_dictionary() -> Dictionary:
	return {
		"trackable_id": trackable_id,
		"persistent_id": persistent_id,
		"transform": transform,
		"pose": transform,
		"tracking_state": tracking_state,
		"raw_tracker": raw_tracker,
	}
