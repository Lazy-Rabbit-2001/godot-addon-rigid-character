@tool
extends HBoxContainer

var mode: EditorRigidCharacterConverterMain.ScriptLang = EditorRigidCharacterConverterMain.ScriptLang.GDSCRIPT:
	set(value):
		if value == mode:
			return
		mode = value
		_update_button_theme()

@onready var button_convert: Button = $Convert

@onready var _button_warning: Button = $Warning


func _ready() -> void:
	mode = mode
	
	_button_warning.icon = EditorInterface.get_editor_theme().get_icon(&"NodeWarning", &"EditorIcons")
	
	_update_button_theme()


func show_warning(show_warning: bool) -> void:
	_button_warning.visible = show_warning


func _update_button_theme() -> void:
	var is_csharp := mode == EditorRigidCharacterConverterMain.ScriptLang.CSHARP and ClassDB.class_exists(&"CSharpScript")
	button_convert.icon = EditorInterface.get_editor_theme().get_icon(&"CSharpScript" if is_csharp else &"GDScript", &"EditorIcons")
	button_convert.text = EditorRigidCharacterTranslator.get_translation("Convert to") + " %s" % ("C#" if is_csharp else "GDScript")
	_button_warning.tooltip_text = EditorRigidCharacterTranslator.get_translation(
		"The C# script requires the current scene be reloaded to take effect."
	)
