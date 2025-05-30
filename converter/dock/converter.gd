@tool
extends Button

var mode: EditorRigidCharacterConverterMain.ScriptLang = EditorRigidCharacterConverterMain.ScriptLang.GDSCRIPT:
	set(value):
		if value == mode:
			return
		mode = value
		_update_button_theme()


func _ready() -> void:
	mode = mode
	_update_button_theme()


func _update_button_theme() -> void:
	var is_csharp := mode == EditorRigidCharacterConverterMain.ScriptLang.CSHARP and ClassDB.class_exists(&"CSharpScript")
	icon = EditorInterface.get_editor_theme().get_icon(&"CSharpScript" if is_csharp else &"GDScript", &"EditorIcons")
	text = EditorRigidCharacterTranslator.get_translation("Convert to") + " %s" % ("C#" if is_csharp else "GDScript")
