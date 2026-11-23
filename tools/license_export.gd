extends SceneTree
func _initialize() -> void:
	var file = FileAccess.open("res://../builds/GODOT-LICENSE.txt", FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file.close()
	var notices = FileAccess.open("res://../builds/GODOT-THIRD-PARTY-NOTICES.txt", FileAccess.WRITE)
	notices.store_string(JSON.stringify({"components": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
	notices.close()
	quit()
