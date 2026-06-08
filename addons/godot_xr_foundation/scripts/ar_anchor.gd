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

