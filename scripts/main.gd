extends Control

const SIMPLE_SCENE := preload("res://scenes/simple_view.tscn")
const COMPLETE_SCENE := preload("res://scenes/complete_view.tscn")

enum Mode { SIMPLE, COMPLETE }

var mode: Mode = Mode.SIMPLE
var _view: Node


func _ready() -> void:
	if _print_version():
		return
	_show_mode(Mode.SIMPLE)
	var preview := OS.get_environment("NOVA_PREVIEW")
	if not preview.is_empty():
		await _preview(preview)


## One stdout line for journald. NOVA_PRINT_VERSION=1 or a user arg `--version`
## (after `--`) prints that line and exits. The engine's own `--version` still
## prints the Godot version and never reaches this scene.
func _print_version() -> bool:
	var version := str(ProjectSettings.get_setting("application/config/version", "dev"))
	print("NOVA Letterbox %s" % version)
	var user_args := OS.get_cmdline_user_args()
	if OS.get_environment("NOVA_PRINT_VERSION") == "1" or user_args.has("--version"):
		get_tree().quit(0)
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	match code:
		KEY_1, KEY_KP_1:
			_show_mode(Mode.SIMPLE)
		KEY_2, KEY_KP_2:
			_show_mode(Mode.COMPLETE)
		KEY_TAB:
			_show_mode(Mode.COMPLETE if mode == Mode.SIMPLE else Mode.SIMPLE)
			get_viewport().set_input_as_handled()


func _show_mode(next: Mode) -> void:
	mode = next
	if is_instance_valid(_view):
		_view.queue_free()
		_view = null
	var packed: PackedScene = SIMPLE_SCENE if next == Mode.SIMPLE else COMPLETE_SCENE
	_view = packed.instantiate()
	add_child(_view)
	if _view is Control:
		var view := _view as Control
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_cursor()


func _update_cursor() -> void:
	var window_mode := DisplayServer.window_get_mode()
	var kiosk := window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if kiosk else Input.MOUSE_MODE_VISIBLE


## Headless/desktop capture: NOVA_PREVIEW=simple|complete|both and optional NOVA_PREVIEW_DIR.
func _preview(which: String) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(1920, 480))
	DisplayServer.window_set_position(Vector2i(0, 0))
	var dir := OS.get_environment("NOVA_PREVIEW_DIR")
	if dir.is_empty():
		dir = "user://"
	var shots: Array[String] = []
	if which == "both":
		shots = ["simple", "complete"]
	else:
		shots = [which]
	for shot in shots:
		if shot == "complete":
			_show_mode(Mode.COMPLETE)
		else:
			_show_mode(Mode.SIMPLE)
		for _frame in 4:
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := dir.path_join("%s.png" % shot)
		var err := image.save_png(path)
		print("NOVA_PREVIEW ", path, " ", image.get_size(), " err=", err)
	get_tree().quit()
