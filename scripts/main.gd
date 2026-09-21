extends Control

## Root scene. Tab toggles views. 1 is Simple, 2 is Complete.
## NOVA_KIOSK=1 fullscreens and hides the cursor for the Pi panel.

enum Mode { SIMPLE, COMPLETE }

@onready var simple_view: Control = $SimpleView
@onready var complete_view: Control = $CompleteView

var mode: Mode = Mode.SIMPLE


func _enter_tree() -> void:
	theme = NovaTheme.make()


func _ready() -> void:
	_apply_kiosk()
	_apply_mode()
	var args := OS.get_cmdline_user_args()
	if args.has("--self-check"):
		_self_check()
	elif args.has("--shot-dir"):
		_capture_shots()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	match key.keycode:
		KEY_TAB:
			mode = Mode.COMPLETE if mode == Mode.SIMPLE else Mode.SIMPLE
			_apply_mode()
		KEY_1, KEY_KP_1:
			mode = Mode.SIMPLE
			_apply_mode()
		KEY_2, KEY_KP_2:
			mode = Mode.COMPLETE
			_apply_mode()


func _apply_mode() -> void:
	var show_complete := mode == Mode.COMPLETE
	simple_view.visible = not show_complete
	complete_view.visible = show_complete
	complete_view.process_mode = Node.PROCESS_MODE_INHERIT if show_complete else Node.PROCESS_MODE_DISABLED


func _apply_kiosk() -> void:
	if OS.get_environment("NOVA_KIOSK") != "1":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _self_check() -> void:
	var failed := PackedStringArray()
	await get_tree().process_frame
	if simple_view.size != Vector2(1920, 480):
		failed.append("viewport %s" % simple_view.size)
	if not simple_view.visible or complete_view.visible:
		failed.append("default mode")
	var download := simple_view.get_node("Download") as NovaDial
	if download == null or not is_equal_approx(download.value, DemoTelemetry.SIMPLE_DOWNLOAD_MBPS):
		failed.append("simple download")
	if download == null or download.title_below != "DOWNLOAD Mbps":
		failed.append("simple caption")
	mode = Mode.COMPLETE
	_apply_mode()
	if not complete_view.visible or simple_view.visible:
		failed.append("complete toggle")
	var ping := complete_view.get_node("Ping") as NovaDial
	if ping == null or not is_equal_approx(ping.value, DemoTelemetry.COMPLETE_PING_MS):
		failed.append("complete ping")
	if complete_view.get_node_or_null("Sparkline") == null:
		failed.append("sparkline")
	if complete_view.get_node_or_null("Ribbon") == null:
		failed.append("ribbon")
	mode = Mode.SIMPLE
	_apply_mode()
	if failed.is_empty():
		print("NOVA self-check: ok")
		get_tree().quit(0)
	else:
		print("NOVA self-check: FAILED %s" % ", ".join(failed))
		get_tree().quit(1)


func _capture_shots() -> void:
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--shot-dir")
	if idx == -1 or idx + 1 >= args.size():
		return
	var dir := args[idx + 1]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(dir, "simple")
	mode = Mode.COMPLETE
	_apply_mode()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save_shot(dir, "complete")
	get_tree().quit(0)


func _save_shot(dir: String, stem: String) -> void:
	var image := get_viewport().get_texture().get_image()
	var path := dir.path_join("%s.png" % stem)
	var err := image.save_png(path)
	print("NOVA shot %s (%sx%s) err=%s" % [path, image.get_width(), image.get_height(), err])
