@tool
extends EditorPlugin


var tab_name:String

func _enter_tree() -> void:
	
	var localization:Control = EditorInterface.get_base_control().find_child("*Localization*", true, false)
	
	var tab_container:TabContainer = localization.get_child(0)
	
	const POT_PLUGIN = preload("res://addons/pot_plugin/scene/pot_plugin.tscn")
	var screen := POT_PLUGIN.instantiate()
	
	tab_name = screen.name
	
	tab_container.add_child(screen)
	
	


func _exit_tree() -> void:
	var localization:Control = EditorInterface.get_base_control().find_child("*Localization*", true, false)
	var tab_container:TabContainer = localization.get_child(0)
	var screen:Control = tab_container.get_node_or_null(tab_name)
	if screen:
		screen.queue_free()
	
