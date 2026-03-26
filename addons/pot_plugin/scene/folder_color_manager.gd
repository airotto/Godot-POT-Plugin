@tool
extends Node

@export var is_dark_theme:bool = true


##Dictionary
##icon:Color
##bg:Color
func get_dir_or_file_color(dir:String) -> Dictionary[String, Color]:
	var color_dic:Dictionary[String, Color]
	
	##---------------------------------------------------------
	##先祖の一番近い色付きフォルダーの位置と色の名前を取得 ない場合は空
	var ps:Dictionary = {}
	
	if ProjectSettings.has_setting("file_customization/folder_colors"):
		ps = ProjectSettings.get_setting("file_customization/folder_colors")
	
	
	var max_length:int = 0
	var final_folder:String = ""
	for folder:String in ps.keys():
		var fl:int = folder.length()
		if fl > max_length:
			if dir.begins_with(folder):
				max_length = fl
				final_folder = folder
	
	var color_name:String = ""
	if final_folder.is_empty() == false:
		color_name = ps[final_folder]
	
	##-----------------------------------------------------------
	##色を取得し、github filesystem_dock.cpp の色調整をやる (cpp内で"_modulate"で検索するとわかりやすい)
	var custom_color:Color = get_color_from_folder_color_name(color_name)
	
	var icon_color:Color = custom_color
	if not is_dark_theme:
		icon_color *= ITEM_COLOR_SCALE
	
	
	var bg_color:Color = custom_color
	if bg_color == DEFAULT_FOLDER_ICON_COLOR:##デフォルトアイコン色なら背景を透明（無）にする
		bg_color = Color.TRANSPARENT
	else:##色付きなら
		if is_dark_theme:
			bg_color.a = ITEM_ALPHA_MIN
		else:
			bg_color.a = ITEM_ALPHA_MAX
		
		
		if final_folder != dir:
			bg_color = bg_color.darkened(ITEM_BG_DARK_SCALE)
	
	
	
	##-------------------------------------------------------
	
	color_dic.bg = bg_color
	color_dic.icon = icon_color
	return color_dic


const DEFAULT_FOLDER_ICON_COLOR := Color(0.482, 0.832, 1.0, 1.0)


const FOLDER_COLOR_LIST:Dictionary[String, Color] = {
	"red" = Color(1.0, 0.271, 0.271),
	"orange" = Color(1.0, 0.561, 0.271),
	"yellow" = Color(1.0, 0.890, 0.271),
	"green" = Color(0.502, 1.0, 0.271),
	"teal" = Color(0.271, 1.0, 0.635),
	"blue" = Color(0.271, 0.843, 1.0),
	"purple" = Color(0.502, 0.271, 1.0),
	"pink" = Color(1.0, 0.271, 0.588),
	"gray" = Color(0.616, 0.616, 0.616),
}

const ITEM_COLOR_SCALE:float = 1.75
const ITEM_ALPHA_MIN:float = 0.1
const ITEM_ALPHA_MAX:float = 0.15
const ITEM_BG_DARK_SCALE:float = 0.3

##色の名前から色を取得 or 無ければデフォルトのアイコン色(水色っぽい奴)
func get_color_from_folder_color_name(color_name:String) -> Color:
	if FOLDER_COLOR_LIST.has(color_name):
		return FOLDER_COLOR_LIST[color_name]
	
	return DEFAULT_FOLDER_ICON_COLOR
