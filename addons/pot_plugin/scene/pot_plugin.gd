@tool
extends Control

##Addonのバージョンアップ時に入れなおすときにセーブデータを消さないようにaddonのフォルダ外にしている
##ここを変えればセーブデータの場所を変えれます。(セーブファイルの移動も忘れずに)
const SAVE_DATA_PATH:String = "res://pot_plugin_save_data.txt"
##ローカルの設定は消えてもいいかなって。それ以外は上と同じ感じです。
const LOCAL_SETTING_DATA_PATH:String = "res://.godot/pot_plugin_local_setting.txt"

@onready var tab_container: TabContainer = %TabContainer



const PotTree = preload("res://addons/pot_plugin/scene/pot_tree.gd")
@onready var pot_tree: PotTree = %POTTree

@onready var selecting_path_line_edit: LineEdit = %SelectingPathLineEdit

@onready var pot_generate_button: Button = %POTGenerateButton
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

@onready var pot_path_button: Button = %POTPathButton
var pot_path_select_dialog : EditorFileDialog
var pot_path_select_dialog_size:Vector2
var pot_path_select_dialog_position:Vector2





@onready var dark_theme_check_button: CheckButton = %DarkThemeCheckButton
@onready var class_icon_check_button: CheckButton = %ClassIconCheckButton
@onready var warning_check_button: CheckButton = %WarningCheckButton

@onready var sort_check_button: CheckButton = %SortCheckButton
@onready var add_buitin_strings_to_pot_check_button: CheckButton = %AddBuitinStringsToPOTCheckButton

@onready var load_from_pot_tab_button: Button = %LoadFromPOTTabButton
@onready var load_from_pot_tab_confirmation_dialog: ConfirmationDialog = %LoadFromPOTTabConfirmationDialog
@onready var save_to_pot_tab_button: Button = %SaveToPOTTabButton
@onready var save_to_pot_tab_confirmation_dialog: ConfirmationDialog = %SaveToPOTTabConfirmationDialog
@onready var debug_button: Button = %DebugButton


var localization:Control
var project_settings_window:Window


var can_reload:bool = true
var can_save:bool = false

func _ready() -> void:
	if get_parent() is not TabContainer:return
	
	
	localization = EditorInterface.get_base_control().find_child("*Localization*", true, false)
	confirmation_dialog.hide()
	load_from_pot_tab_confirmation_dialog.hide()
	
	pot_tree.item_selected.connect(_on_pot_tree_item_selected)
	
	
	pot_tree.save.connect(save_data)
	project_settings_window = localization.get_viewport()
	project_settings_window.visibility_changed.connect(_on_project_settings_window_visibility_changed)
	
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	
	
	
	
	tab_container.set_tab_icon(0, get_theme_icon("File", "EditorIcons") )
	tab_container.set_tab_icon(1, get_theme_icon("GDScript", "EditorIcons") )
	tab_container.set_tab_icon(2, get_theme_icon("Tools", "EditorIcons") )
	
	pot_generate_button.icon = get_theme_icon("File", "EditorIcons")
	pot_path_button.icon = get_theme_icon("Folder", "EditorIcons")
	dark_theme_check_button.icon = get_theme_icon("SphereOccluder3D", "EditorIcons")##Moon Icon
	class_icon_check_button.icon = get_theme_icon("Image", "EditorIcons")
	sort_check_button.icon = get_theme_icon("Sort", "EditorIcons")
	warning_check_button.icon = get_theme_icon("NodeWarning", "EditorIcons")
	add_buitin_strings_to_pot_check_button.icon = get_theme_icon("String", "EditorIcons")
	load_from_pot_tab_button.icon = get_theme_icon("MoveDown", "EditorIcons")
	save_to_pot_tab_button.icon = get_theme_icon("MoveUp", "EditorIcons")
	debug_button.icon = get_theme_icon("Debug", "EditorIcons")
	
	
	load_data()
	load_local_setting()
	
	
	can_save = true

#region Selecting Path Line


func _on_pot_tree_item_selected() -> void:
	if pot_tree.is_dir(pot_tree.get_selected()):
		selecting_path_line_edit.text = pot_tree.get_dir(pot_tree.get_selected())
		return
	
	if pot_tree.is_file(pot_tree.get_selected()):
		selecting_path_line_edit.text = ResourceUID.ensure_path(pot_tree.get_file(pot_tree.get_selected()))
		return
	
	selecting_path_line_edit.text = pot_tree.get_selected().get_text(0)


func _on_selecting_path_line_edit_text_submitted(new_text: String) -> void:
	
	var finded:TreeItem = find_iterate_from_path(pot_tree.get_root(), new_text)
	if finded == null:
		return
	
	pot_tree.set_selected(finded, pot_tree.COLUMN_CHECK)
	
	pot_tree.queue_redraw()

func find_iterate_from_path(item:TreeItem, path:String) -> TreeItem:
	
	if pot_tree.is_dir(item):
		if path == pot_tree.get_dir(item):
			return item
	elif pot_tree.is_file(item):
		if path == ResourceUID.ensure_path(pot_tree.get_file(item)):
			return item
	else:
		if path == item.get_text(0):
			return item
	
	
	for i:TreeItem in item.get_children():
		var result:TreeItem = find_iterate_from_path(i, path)
		if result:
			return result
	
	return null


#endregion



#region Generate POT



##POT生成ボタンを押したとき　もし警告がONなら警告を出し　OFFならそのまま生成
func _on_pot_generate_button_pressed() -> void:
	if warning_check_button.button_pressed:
		if FileAccess.file_exists(pot_path_button.text):
			confirmation_dialog.dialog_text = "ファイル \"%s\" はすでに存在します。\n上書きしますか？" % pot_path_button.text
			confirmation_dialog.show()
			return
	
	pot_generate()

##警告が出た場合OKすると生成
func _on_confirmation_dialog_confirmed() -> void:
	pot_generate()


##POTを生成
func pot_generate() -> void:
	##add_builtin_strings_to_potを保存しとく
	var last_add_builtin_strings_to_pot:bool = get_add_builtin_strings_to_pot()
	set_add_builtin_strings_to_pot(add_buitin_strings_to_pot_check_button.button_pressed)
	
	##POTリストを保存しとく
	var last_pot:Array = get_pot_files()
	
	
	
	
	
	set_pot_files(get_pot_generate_files() )
	
	var file_dialog: EditorFileDialog = localization.get_child(5)
	file_dialog.file_selected.emit(pot_path_button.text)
	
	##もとのPOTリストに戻す
	set_pot_files(last_pot)
	##もとのadd_builtin_strings_to_potに戻す
	set_add_builtin_strings_to_pot(last_add_builtin_strings_to_pot)
	
	print("POT generated (if not pushed error)")

#endregion


func get_pot_generate_files() -> Array:
	var pot_generate_files:PackedStringArray = []
	
	if sort_check_button.button_pressed:
		var sorted_files:PackedStringArray = []
		sort_iterate(pot_tree.get_root(), sorted_files)
		pot_generate_files = sorted_files
	else:
		pot_generate_files = pot_tree.pot_generate_files
	
	
	## uid convert to path
	var r:Array = []
	for uid:String in pot_generate_files:
		r.append(ResourceUID.ensure_path(uid))
	
	return r



#region Pot path select

##保存先設定ボタンを押してらダイアログを出す
func _on_pot_path_button_pressed() -> void:
	if pot_path_select_dialog == null:
		pot_path_select_dialog = EditorFileDialog.new()
		
		pot_path_select_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
		
		pot_path_select_dialog.access = EditorFileDialog.ACCESS_RESOURCES
		pot_path_select_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		pot_path_select_dialog.display_mode = EditorFileDialog.DISPLAY_THUMBNAILS
		
		pot_path_select_dialog.current_file = pot_path_button.text
		pot_path_select_dialog.filters = ["*.pot"]
		
		#pot_path_select_dialog.title = "生成場所を設定"
		
		pot_path_select_dialog.disable_overwrite_warning = true
		
		pot_path_select_dialog.file_selected.connect(_on_pot_path_select_dialog_file_selected)
		
		pot_path_select_dialog.visibility_changed.connect(_on_pot_path_select_dialog_visibility_changed)
		pot_path_select_dialog.size_changed.connect(_on_pot_path_select_dialog_size_changed)
		
		add_child(pot_path_select_dialog)
	
	
	
	
	##データがあったら位置とサイズをロード　なかったら初期位置
	if has_save_data():
		pot_path_select_dialog.size = pot_path_select_dialog_size
		pot_path_select_dialog.position = pot_path_select_dialog_position
	else:
		pot_path_select_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
		pot_path_select_dialog.size = Vector2(500, 300)
	
	
	pot_path_select_dialog.show()


##保存先設定ダイアログをサイズ変更時にサイズを保存
func _on_pot_path_select_dialog_size_changed() -> void:
	pot_path_select_dialog_size = pot_path_select_dialog.size

##保存先設定ダイアログを閉じるときに位置を保存
func _on_pot_path_select_dialog_visibility_changed() -> void:
	if pot_path_select_dialog.visible:return
	##位置を保存
	pot_path_select_dialog_position = pot_path_select_dialog.position
	
	save_local_setting()
	


##保存先を設定
func _on_pot_path_select_dialog_file_selected(path:String) -> void:
	pot_path_button.text = path
	save_data()


func _on_add_buitin_strings_to_pot_check_button_toggled(toggled_on: bool) -> void:
	save_data()



func _on_warning_check_button_toggled(toggled_on: bool) -> void:
	save_local_setting()




#endregion



#region Auto Reload

##ファイルシステムが何かしら変わったらリロード可能にする
func _on_filesystem_changed() -> void:
	can_reload = true



func _on_project_settings_window_visibility_changed() -> void:
	if not project_settings_window.visible:
		if is_node_ready():
			save_data()


##再表示時リロード可能ならリロードする
##常にタブを何回も開くたびにリロードすると重いので
##参照: _on_filesystem_changed
func _on_visibility_changed() -> void:
	if get_parent() is not TabContainer:return
	
	if visible:
		try_reload()


func try_reload() -> void:
	if not can_reload:return
	
	if is_node_ready() == false:
		await ready
		await get_tree().process_frame
	
	
	can_reload = false
	pot_tree.reload()

#endregion





#region Debug


var debug_error_counter:int = 0
##デバッグボタン 
func _on_debug_button_pressed() -> void:
	debug_error_counter = 0
	#print("")
	#print("デバッグ開始")
	
	#for i in pot_tree.pot_generate_files:
		#print(ResourceUID.ensure_path(i))
	
	debug_iterate(pot_tree.get_root())
	
	
	if debug_error_counter == 0:
		print("デバッグ完了 異常は検出されませんでした")
	else:
		print("デバッグ完了 異常が%s個検出されました" % debug_error_counter)

##チェックされてるのに　ある　もしくは　その逆など　矛盾した状態なら　エラーを出す
func debug_iterate(item:TreeItem) -> void:
	if item == null:return
	
	for i:TreeItem in item.get_children():
		
		if pot_tree.is_file(i):
			var uid:String = pot_tree.get_file(i)
			var path:String = ResourceUID.ensure_path(uid)
			if i.is_checked(pot_tree.COLUMN_CHECK):
				if not pot_tree.pot_generate_files.has(uid):
					push_error("file " + path + " が無い　期待する状態：有る")
					debug_error_counter += 1
			else:
				if pot_tree.pot_generate_files.has(uid):
					push_error("file " + path + " が有る　期待する状態：無い")
					debug_error_counter += 1
		elif pot_tree.is_dir(i):
			var dir:String = pot_tree.get_dir(i)
			if i.is_checked(pot_tree.COLUMN_LOCK):
				if i.is_checked(pot_tree.COLUMN_CHECK):
					if not pot_tree.all_check_dirs.has(dir):
						push_error("dir   " + dir + " が無い　期待する状態：all")
						debug_error_counter += 1
				else:
					if pot_tree.all_check_dirs.has(dir):
						push_error("dir   " + dir + " がall　期待する状態：無い")
						debug_error_counter += 1
					
			else:
				if pot_tree.all_check_dirs.has(dir):
					push_error("dir   " + dir + " がall　期待する状態：無い")
					debug_error_counter += 1
			
			
		
		debug_iterate(i)
		

#endregion


#region Save Load 


##セーブデータを持っているか
func has_save_data() -> bool:
	return FileAccess.file_exists(SAVE_DATA_PATH)

func has_local_setting_data() -> bool:
	return FileAccess.file_exists(LOCAL_SETTING_DATA_PATH)


##セーブする
func save_data() -> void:
	if not can_save:return
	
	var save_dictionary:Dictionary
	
	
	save_dictionary.all_check_dirs = pot_tree.all_check_dirs##常にオンにするディレクトリのリスト
	save_dictionary.pot_generate_files = pot_tree.pot_generate_files##生成するファイルのリスト
	
	save_dictionary.pot_generate_path = pot_path_button.text##生成するpotファイルの保存場所
	
	save_dictionary.enable_sort = sort_check_button.button_pressed##生成時のソート
	save_dictionary.add_builtin_strings_to_pot = add_buitin_strings_to_pot_check_button.button_pressed##生成時にビルトイン文字列を含むか
	
	
	var save_text:String = var_to_str(save_dictionary)
	
	if save_text.is_empty():
		push_error("POT Plugin : セーブを試みましたが、何らかの理由により空でセーブしようとしたため取りやめました")
		return
	
	var save_file := FileAccess.open(SAVE_DATA_PATH,FileAccess.WRITE)
	save_file.store_string(save_text)
	
	save_file.close()



func save_local_setting() -> void:
	if not can_save:return
	
	var save_dictionary:Dictionary
	
	save_dictionary.enable_warning = warning_check_button.button_pressed
	save_dictionary.is_dark_theme = dark_theme_check_button.button_pressed
	save_dictionary.class_icon = class_icon_check_button.button_pressed
	
	save_dictionary.pot_path_select_dialog_size = pot_path_select_dialog_size
	save_dictionary.pot_path_select_dialog_position = pot_path_select_dialog_position
	
	var save_text:String = var_to_str(save_dictionary)
	
	if save_text.is_empty():
		push_error("POT Plugin : ローカル設定のセーブを試みましたが、何らかの理由により空でセーブしようとしたため取りやめました")
		return
	
	var save_file := FileAccess.open(LOCAL_SETTING_DATA_PATH,FileAccess.WRITE)
	save_file.store_string(save_text)
	
	save_file.close()





##ロードする
func load_data() -> void:
	if not has_save_data():
		return
	
	var load_file := FileAccess.open(SAVE_DATA_PATH,FileAccess.READ)
	var load_data_text:String = load_file.get_as_text()
	load_file.close()
	
	if load_data_text.is_empty():
		return
	
	var save_dictionary:Dictionary = str_to_var(load_data_text)
	
	
	pot_tree.all_check_dirs = save_dictionary.all_check_dirs
	pot_tree.pot_generate_files = save_dictionary.pot_generate_files
	
	pot_path_button.text = save_dictionary.pot_generate_path
	
	sort_check_button.button_pressed = save_dictionary.enable_sort
	add_buitin_strings_to_pot_check_button.button_pressed = save_dictionary.add_builtin_strings_to_pot



func load_local_setting() -> void:
	if not has_local_setting_data():
		return
	
	var load_file := FileAccess.open(LOCAL_SETTING_DATA_PATH,FileAccess.READ)
	var load_data_text:String = load_file.get_as_text()
	load_file.close()
	
	if load_data_text.is_empty():
		return
	
	
	var save_dictionary:Dictionary = str_to_var(load_data_text)
	
	warning_check_button.button_pressed = save_dictionary.enable_warning
	dark_theme_check_button.button_pressed = save_dictionary.is_dark_theme
	class_icon_check_button.button_pressed = save_dictionary.class_icon
	
	pot_path_select_dialog_size = save_dictionary.pot_path_select_dialog_size
	pot_path_select_dialog_position = save_dictionary.pot_path_select_dialog_position
	
	





#endregion

func get_add_builtin_strings_to_pot() -> bool:
	return (ProjectSettings.get_setting("internationalization/locale/translation_add_builtin_strings_to_pot") as bool)

func set_add_builtin_strings_to_pot(value:bool) -> void:
	ProjectSettings.set_setting("internationalization/locale/translation_add_builtin_strings_to_pot", value)


func get_pot_files() -> Array:
	return (ProjectSettings.get_setting("internationalization/locale/translations_pot_files") as Array).duplicate_deep(Resource.DeepDuplicateMode.DEEP_DUPLICATE_ALL)

func set_pot_files(files:Array) -> void:
	ProjectSettings.set_setting("internationalization/locale/translations_pot_files", files)





func _on_load_from_pot_tab_button_pressed() -> void:
	load_from_pot_tab_confirmation_dialog.show()


func _on_load_from_pot_tab_confirmation_dialog_confirmed() -> void:
	
	var undo_redo:EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("POT Plugin : load from POT generation tab")
	
	var pot_files:Array = get_pot_files()
	load_from_pot_tab_iterate(pot_tree.get_root(), pot_files, undo_redo)
	
	undo_redo.commit_action()
	
	
	save_data()





func _on_save_to_pot_tab_button_pressed() -> void:
	save_to_pot_tab_confirmation_dialog.show()


func _on_save_to_pot_tab_confirmation_dialog_confirmed() -> void:
	
	var undo_redo:EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("POT Plugin : save to POT generation tab")
	
	var undo_array:Array = get_pot_files()
	undo_redo.add_do_method(self, &"set_pot_files", get_pot_generate_files())
	undo_redo.add_undo_method(self, &"set_pot_files", undo_array)
	
	undo_redo.commit_action()




func load_from_pot_tab_iterate(item:TreeItem, pot_files:Array, undo_redo:EditorUndoRedoManager) -> void:
	
	if pot_tree.is_file(item):
		if item.is_checked(PotTree.COLUMN_CHECK) == false:
			if pot_files.has( ResourceUID.ensure_path(pot_tree.get_file(item)) ):
				undo_redo.add_do_method(item, &"set_checked", PotTree.COLUMN_CHECK, true)
				undo_redo.add_do_method(pot_tree, &"item_action", item, PotTree.COLUMN_CHECK)
				
				undo_redo.add_undo_method(item, &"set_checked", PotTree.COLUMN_CHECK, false)
				undo_redo.add_undo_method(pot_tree, &"item_action", item, PotTree.COLUMN_CHECK)
				
	
	
	for i:TreeItem in item.get_children():
		load_from_pot_tab_iterate(i, pot_files, undo_redo)


func _on_dark_theme_check_button_toggled(toggled_on: bool) -> void:
	save_local_setting()
	pot_tree.folder_color_manager.is_dark_theme = toggled_on
	pot_tree.reload()




func _on_class_icon_check_button_toggled(toggled_on: bool) -> void:
	save_local_setting()
	pot_tree.class_icon = toggled_on
	pot_tree.reload()





func sort_iterate(item:TreeItem, sorted_files:PackedStringArray) -> void:
	
	if pot_tree.is_file(item):
		var file:String = pot_tree.get_file(item)
		if pot_tree.pot_generate_files.has(file):
			sorted_files.append(file)
	
	
	for i:TreeItem in item.get_children():
		sort_iterate(i, sorted_files)


func _on_sort_check_button_toggled(toggled_on: bool) -> void:
	save_data()
