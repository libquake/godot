extends SceneTree
## Runs the test_ methods of every script in res://tests, prints the failures and quits with their count. An error
## while a test runs fails it too: a script error ends the test early, and it would pass otherwise.


## Collects the errors Godot logs, script errors included; warnings are left alone.
class ErrorLog extends Logger:
	var _errors := PackedStringArray()
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_errors.append("%s (%s:%d in %s)" % [rationale if rationale else code, file, line, function])
		_mutex.unlock()

	## The errors since the last call.
	func take() -> PackedStringArray:
		_mutex.lock()
		var taken := _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return taken


func _init() -> void:
	await process_frame
	var errors := ErrorLog.new()
	OS.add_logger(errors)
	var failed := 0
	var count := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not file.begins_with("test_") or file.get_extension() != "gd":
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var test: QuakeTest = script.new()
			root.add_child(test)
			errors.take()
			await test.call(test_name)
			count += 1
			for error in errors.take():
				test.failures.append("error: " + error)
			if test.failures.is_empty():
				print("ok    %s.%s" % [file.get_basename(), test_name])
			else:
				failed += 1
				print("FAIL  %s.%s" % [file.get_basename(), test_name])
				for failure in test.failures:
					print("      " + failure)
			test.free()
	OS.remove_logger(errors)
	print("%d of %d tests passed" % [count - failed, count])
	quit(failed)
