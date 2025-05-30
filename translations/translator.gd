class_name EditorRigidCharacterTranslator

const TRANSLATION_DIR := "res://addons/rigid_character/translations/"


static func get_translation(message: String) -> String:
	var f := FileAccess.open(TRANSLATION_DIR + OS.get_locale() + ".txt", FileAccess.READ)
	
	if not f:
		return message
	
	var line := f.get_line()
	
	while not f.eof_reached():
		var kv := line.split(":")
		
		if message == kv[0]:
			return kv[1]
		
		line = f.get_line()
	
	return message
