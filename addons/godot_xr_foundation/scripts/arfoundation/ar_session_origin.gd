extends XROrigin
class_name ARSessionOrigin

var camera: Camera3D = null
var trackablesParent: Node3D = null


func _ready() -> void:
	super._ready()
	_sync_legacy_properties()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_legacy_properties()


func get_camera_node() -> Camera3D:
	_sync_legacy_properties()
	return camera


func get_trackables_parent_node() -> Node3D:
	_sync_legacy_properties()
	return trackablesParent


func MakeContentAppearAt(content: Node3D, target: Variant, rotation: Variant = null) -> bool:
	return make_content_appear_at(content, target, rotation)


func _sync_legacy_properties() -> void:
	camera = get_camera()
	trackablesParent = get_trackables_parent()
