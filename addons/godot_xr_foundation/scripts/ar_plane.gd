extends ARTrackable
class_name ARPlane

var size: Vector2 = Vector2.ONE
var alignment: StringName = &"unknown"
var label: StringName = &""


func _init(
	p_trackable_id: StringName = &"",
	p_transform: Transform3D = Transform3D.IDENTITY,
	p_size: Vector2 = Vector2.ONE,
	p_alignment: StringName = &"unknown",
	p_raw_tracker: Variant = null
) -> void:
	super._init(p_trackable_id, p_transform, p_raw_tracker)
	size = p_size
	alignment = p_alignment

