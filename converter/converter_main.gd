@tool
class_name EditorRigidCharacterConverterMain
extends EditorPlugin

##
##
##

enum ScriptLang {
	GDSCRIPT, ##
	CSHARP ##
}

const _Converter := preload("uid://cbtx3cdvxn13t")

const _ConverterType := preload("uid://ba7ybryap4yem")

var _converter: _ConverterType = null

var _edited_object: Node = null
var _convert_to_script: Script = null


func _enter_tree() -> void:
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	
	_converter = _Converter.instantiate()
	_converter.pressed.connect(_on_convert_button_pressed)
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _converter)
	_converter.hide()

func _exit_tree() -> void:
	if not _converter:
		return
	
	remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _converter)
	
	_converter.queue_free()
	_converter = null
	
	_edited_object = null
	_convert_to_script = null


func _handles(_object: Object) -> bool:
	return true

func _edit(object: Object) -> void:
	if not ClassDB.class_exists(&"CSharpScript"):
		return
	
	if object is not CharacterBody2D and object is not CharacterBody3D:
		_converter.hide()
		return
	
	var script := object.get_script() as Script
	
	if not script:
		_converter.hide()
		return
	
	var gd := script is GDScript
	var cs := script.get_class() == &"CSharpScript"
	
	if gd or cs:
		_edited_object = object
		
		if gd and _get_script_file(script, ScriptLang.CSHARP):
			_convert_to_script = _get_script_file(script, ScriptLang.CSHARP)
			_converter.mode = ScriptLang.CSHARP
		elif cs and _get_script_file(script, ScriptLang.GDSCRIPT):
			_convert_to_script = _get_script_file(script, ScriptLang.GDSCRIPT)
			_converter.mode = ScriptLang.GDSCRIPT
		
		_converter.show()
		return
	
	_edited_object = null
	_converter.hide()


func _get_script_file(source: Script, lang: ScriptLang) -> Script:
	if source.resource_path.is_empty():
		return null
	
	var path := source.resource_path.get_slice(".", 0)
	var divide_count := path.get_slice_count("/")
	var file_name := path.get_slice("/", divide_count - 1)
	var dir := path.replace(file_name, "")
	
	#print(
		#"Path: %s;\nDirectory: %s;\nFile Name: %s" % [path, dir, file_name]
	#)
	
	var expected_file_name := ""
	match lang:
		ScriptLang.GDSCRIPT:
			expected_file_name = file_name.to_snake_case() + ".gd"
		ScriptLang.CSHARP:
			expected_file_name = file_name.to_pascal_case() + ".cs"
	
	var result := load(dir + expected_file_name)
	return result


func _on_convert_button_pressed() -> void:
	if _convert_to_script and _edited_object:
		_edited_object.set_script(_convert_to_script)
		EditorInterface.edit_node(_edited_object)
		EditorInterface.edit_node(_edited_object)
