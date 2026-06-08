extends RefCounted
class_name ARTrackable

var trackable_id: StringName = &""
var transform: Transform3D = Transform3D.IDENTITY
var tracking_state := XRFoundationTypes.TrackingState.TRACKING
var raw_tracker: Variant = null


func _init(
	p_trackable_id: StringName = &"",
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_raw_tracker: Variant = null
) -> void:
	trackable_id = p_trackable_id
	transform = p_transform
	raw_tracker = p_raw_tracker

