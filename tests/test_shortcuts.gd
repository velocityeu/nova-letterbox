extends Node

## Headless check that the letterbox keys switch views and quit.
## Quit key is the user arg after `--`: Q (default) or ESCAPE.
## get_tree().quit() only sets a flag, so a missed quit is caught by the timer.

const MainScene := preload("res://scenes/main.tscn")
const MainScript := preload("res://scripts/main.gd")

var _failed := 0


func _ready() -> void:
	# Adding the letterbox during this node's _ready hits a busy root.
	call_deferred("_run")


func _run() -> void:
	var main: MainScript = MainScene.instantiate()
	get_tree().root.add_child(main)
	_eq(main.mode, MainScript.Mode.SIMPLE, "boots simple")
	_eq(_view_file(main), "simple_view.gd", "simple scene")
	_press(main, KEY_2)
	_eq(main.mode, MainScript.Mode.COMPLETE, "2 complete")
	_eq(_view_file(main), "complete_view.gd", "complete scene")
	_press(main, KEY_1)
	_eq(main.mode, MainScript.Mode.SIMPLE, "1 simple")
	_eq(_view_file(main), "simple_view.gd", "simple scene again")
	_press(main, KEY_KP_2)
	_eq(main.mode, MainScript.Mode.COMPLETE, "keypad 2")
	_press(main, KEY_KP_1)
	_eq(main.mode, MainScript.Mode.SIMPLE, "keypad 1")
	_press(main, KEY_TAB)
	_eq(main.mode, MainScript.Mode.COMPLETE, "tab to complete")
	_eq(_view_file(main), "complete_view.gd", "tab scene")
	_press(main, KEY_TAB)
	_eq(main.mode, MainScript.Mode.SIMPLE, "tab to simple")
	var echo := _key(KEY_2)
	echo.echo = true
	main._unhandled_input(echo)
	_eq(main.mode, MainScript.Mode.SIMPLE, "echo ignored")
	var release := _key(KEY_2)
	release.pressed = false
	main._unhandled_input(release)
	_eq(main.mode, MainScript.Mode.SIMPLE, "release ignored")
	var before := DisplayServer.window_get_mode()
	_press(main, KEY_F11)
	var after := DisplayServer.window_get_mode()
	_press(main, KEY_F11)
	_eq(DisplayServer.window_get_mode(), before, "f11 toggles back")
	if after == before and before != DisplayServer.WINDOW_MODE_FULLSCREEN:
		print("NOTE headless display server did not change window mode")
	if _failed > 0:
		print("FAILED ", _failed)
		get_tree().quit(1)
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 0.5
	timer.timeout.connect(_quit_missed)
	add_child(timer)
	timer.start()
	print("OK modes")
	print("quit key ", "ESCAPE" if _quit_code() == KEY_ESCAPE else "Q")
	_press(main, _quit_code())


func _quit_missed() -> void:
	push_error("quit key did not call get_tree().quit()")
	get_tree().quit(1)


func _quit_code() -> Key:
	var args := OS.get_cmdline_user_args()
	if args.has("ESCAPE"):
		return KEY_ESCAPE
	return KEY_Q


func _press(main: MainScript, code: Key) -> void:
	main._unhandled_input(_key(code))


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	return event


func _view_file(main: Node) -> String:
	var found := ""
	for child in main.get_children():
		var script: Script = child.get_script()
		if script == null:
			continue
		var file := script.resource_path.get_file()
		if file.ends_with("_view.gd"):
			found = file
	return found


func _eq(got: Variant, expected: Variant, label: String) -> void:
	if got != expected:
		_failed += 1
		print("FAIL ", label, " got=", got, " expected=", expected)
