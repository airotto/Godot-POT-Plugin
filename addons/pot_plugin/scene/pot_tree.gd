@tool
extends Tree


@export var class_icon:bool = false

##全ての子にチェックをいれるディレクトリのパスのリスト(フォルダーの右のチェックついてるやつ)
var all_check_dirs:PackedStringArray = []
##チェック入ってるファイルのパス(uidがあればuid)のリスト
var pot_generate_files:PackedStringArray = []

signal save

const COLUMN_CHECK:int = 0
const COLUMN_LOCK:int = 1


const FolderColorManager = preload("uid://comiy8ykyv6le")
@onready var folder_color_manager: FolderColorManager = $FolderColorManager





func _ready() -> void:
	hide_root = false
	
	
	
	item_edited.connect(_on_item_edited)
	check_propagated_to_item.connect(_on_check_propagated_to_item)
	





#region Reload



##リロードする
func reload() -> void:
	clear()
	create_item()
	
	get_root().set_text(COLUMN_CHECK, "res://")
	get_root().set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
	
	get_root().set_icon(COLUMN_CHECK, get_theme_icon("Folder", "EditorIcons") )
	get_root().set_icon_modulate(COLUMN_CHECK, FolderColorManager.DEFAULT_FOLDER_ICON_COLOR)
	
	
	
	
	
	
	
	
	for dir_path:String in all_check_dirs:
		
		if DirAccess.dir_exists_absolute(dir_path) == false:
			all_check_dirs.erase(dir_path)
			print("POT Plugin : all check dir not exists " + dir_path + " (not error)")
			
	
	
	for file_path:String in pot_generate_files:
		if FileAccess.file_exists(file_path) == false:
			pot_generate_files.erase(file_path)
			print("POT Plugin : file not exists " + file_path + " (not error)")
	
	
	
	
	
	var resource_filesystem_dir:EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()
	_reload_iterate(get_root(), resource_filesystem_dir)
	


##これは単独で実行しない  reloadを使用してください
func _reload_iterate(dir_item:TreeItem, dir:EditorFileSystemDirectory) -> void:
	
	for i in dir.get_file_count():
		var my_file_path:String = dir.get_file_path(i)
		
		
		var item:TreeItem = create_item(dir_item)
		
		var uid:String = ResourceUID.path_to_uid(my_file_path)
		
		item.set_metadata(COLUMN_CHECK, "file:" + uid)
		item.set_cell_mode(COLUMN_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_CHECK, true)
		item.set_text(COLUMN_CHECK, dir.get_file(i))
		item.set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
		
		item.set_icon(COLUMN_CHECK, get_class_icon_from_path_or_uid(my_file_path) )
		
		item.set_tooltip_text(COLUMN_CHECK, "チェックがついているとPOT生成に含まれます")
		
		
		
		var color_dic:Dictionary[String, Color] = folder_color_manager.get_dir_or_file_color(ResourceUID.ensure_path(my_file_path))
		
		item.set_custom_bg_color(0, color_dic.bg)
		item.set_custom_bg_color(1, color_dic.bg)
		
		
		
		##データから読み込む
		if pot_generate_files.has(uid):
			#print(uid)
			item.set_checked(COLUMN_CHECK, true)
			item.propagate_check(COLUMN_CHECK, false)
			
	
	
	
	
	
	for i in dir.get_subdir_count():
		var sub_dir:EditorFileSystemDirectory = dir.get_subdir(i)
		var my_dir_path:String = sub_dir.get_path()
		
		
		var item:TreeItem = dir_item.create_child()
		item.set_collapsed_recursive(true)
		
		
		
		
		
		item.set_metadata(COLUMN_CHECK, "dir:"  + my_dir_path)
		item.set_cell_mode(COLUMN_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_CHECK, false)
		item.set_cell_mode(COLUMN_LOCK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_LOCK, true)
		item.set_text(COLUMN_CHECK, sub_dir.get_name())
		item.set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
		
		item.set_icon(COLUMN_CHECK, get_theme_icon("Folder", "EditorIcons") )
		item.set_icon(COLUMN_LOCK, get_theme_icon("ThemeSelectAll", "EditorIcons") )
		
		item.set_tooltip_text(COLUMN_CHECK, "誤操作を防ぐためにロックされています　操作は右のチェックボックスから")
		item.set_tooltip_text(COLUMN_LOCK, "このチェックがついているフォルダの中のファイルは自動でチェックが付きます。外すと、中のファイルはチェックが外れます。")
		
		
		var color_dic:Dictionary[String, Color] = folder_color_manager.get_dir_or_file_color(my_dir_path)
		
		item.set_custom_bg_color(0, color_dic.bg)
		item.set_custom_bg_color(1, color_dic.bg)
		item.set_icon_modulate(0, color_dic.icon)
		
		
		#if my_dir_path.begins_with("res://new folder"):
			#print(color_dic.bg)
		
		
		_reload_iterate(item, sub_dir)
		
		##データから読み込む
		if all_check_dirs.has(my_dir_path):
			item.set_checked(COLUMN_CHECK, true)
			item.set_checked(COLUMN_LOCK, true)
			#item.set_editable(COLUMN_CHECK, false)
			
			item.propagate_check(COLUMN_CHECK, false)
			
			lock_iterate(item, true)
			
	

#endregion



var undo_redo:EditorUndoRedoManager
var _is_undo_redo:bool = false




#region Edit item

##チェック変更時
func _on_item_edited() -> void:
	var item:TreeItem = get_edited()
	
	var _is_dir:bool = is_dir(item)
	
	##Undo時にフォルダー選択を解除するとき中のファイルたちのチェックを保存する
	##(通常時はフォルダー選択解除時は中のファイルをすべて外すため)
	var add_dir_children_save_dic:Dictionary[String, bool]
	
	if _is_dir:
		if get_edited_column() != COLUMN_LOCK:return
		
		if item.is_checked(COLUMN_LOCK):
			
			add_dir_children_save_dic = {}
			get_child_check_iterate(item, add_dir_children_save_dic)
			
			item.set_checked(COLUMN_CHECK, true)
		else:
			item.set_checked(COLUMN_CHECK, false)
		
		item_action(item, COLUMN_LOCK)
		
		lock_iterate(item, item.is_checked(COLUMN_LOCK))
		
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	
	
	item.propagate_check(COLUMN_CHECK, true)
	item_action(item, COLUMN_CHECK)
	
	if _is_dir:
		await get_tree().process_frame
	
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	save.emit()
	
	
	
	if _is_undo_redo:
		_is_undo_redo = false
	else:
		undo_redo = EditorInterface.get_editor_undo_redo()
		
		
		var _name:String = ""
		if is_file(item):
			if item.is_checked(COLUMN_CHECK):
				_name = "POT Plugin : ファイル %s を追加" % ResourceUID.ensure_path(get_file(item) )
			else:
				_name = "POT Plugin : ファイル %s を除去" % ResourceUID.ensure_path(get_file(item) )
		elif is_dir(item):
			if item.is_checked(COLUMN_LOCK):
				_name = "POT Plugin : ディレクトリ %s を追加" % get_dir(item) 
			else:
				_name = "POT Plugin : ディレクトリ %s を除去" % get_dir(item) 
		
		
		undo_redo.create_action(_name, UndoRedo.MERGE_DISABLE, null, false, false)
		
		undo_redo.add_do_property(self, &"_is_undo_redo", true)
		undo_redo.add_do_method(self, &"undo_redo_select_and_edit", item, get_edited_column())
		
		undo_redo.add_undo_property(self, &"_is_undo_redo", true)
		undo_redo.add_undo_method(self, &"undo_redo_select_and_edit", item, get_edited_column())
		
		if is_dir(item):
			if item.is_checked(COLUMN_LOCK):
				undo_redo.add_undo_method(self, &"set_child_check_iterate", item, add_dir_children_save_dic)
		
		
		undo_redo.commit_action(false)




##_on_item_editedのadd_dir_children_save_dicを見て
func set_child_check_iterate(item:TreeItem, save_dic:Dictionary[String, bool]) -> void:
	for i:TreeItem in item.get_children():
		if is_file(i):
			i.set_checked(COLUMN_CHECK, save_dic[get_file(i)])
		
		get_child_check_iterate(i, save_dic)
	


##_on_item_editedのadd_dir_children_save_dicを見て
func get_child_check_iterate(item:TreeItem, save_dic:Dictionary[String, bool]) -> void:
	for i:TreeItem in item.get_children():
		if is_file(i):
			save_dic[get_file(i)] = i.is_checked(COLUMN_CHECK)
		
		get_child_check_iterate(i, save_dic)
	




func undo_redo_select_and_edit(item:TreeItem, column:int) -> void:
	set_selected(item, column)
	if get_selected() != item:
		_is_undo_redo = false
		return
	
	if not edit_selected():
		_is_undo_redo = false
	



##
func _on_check_propagated_to_item(item: TreeItem, column: int) -> void:
	
	
	if is_dir(item):
		if item.is_checked(COLUMN_LOCK):
			await get_tree().process_frame
			
			item.set_checked(COLUMN_CHECK, true)
			
			lock_iterate(item, true)
			
	
	
	item_action(item, COLUMN_CHECK)
	







##
func lock_iterate(item:TreeItem, lock:bool) -> void:
	for i:TreeItem in item.get_children():
		
		if is_file(i):
			i.set_editable(COLUMN_CHECK, not lock)
		
		
		i.set_checked(COLUMN_CHECK, lock)
		
		
		item_action(i, COLUMN_CHECK)
		item_action(i, COLUMN_LOCK)
		
		lock_iterate(i, lock)


#endregion



#region Item functions



##columnに応じてアイテムを　生成リストにデータを設定する
func item_action(item:TreeItem, column:int) -> void:
	
	
	if column == COLUMN_LOCK:
		dir_item_set_pot_generate_list(item)
	
	if column == COLUMN_CHECK:
		file_item_set_pot_generate_list(item)
	


##ディレクトリのデータを持ったアイテムなら　チェックに応じて　生成リストにデータを設定する
func dir_item_set_pot_generate_list(item:TreeItem) -> void:
	if  not is_dir(item):return
	
	var dir_path:String = get_dir(item)
	
	if item.is_checked(COLUMN_LOCK):##ロックされてたら
		if not all_check_dirs.has(dir_path):
			#print("POT Plugin : append all check dir " + dir_path)
			all_check_dirs.append(dir_path)
		
	else:##ロックされてなかったら
		
		if all_check_dirs.has(dir_path):
			#print("POT Plugin : remove all check dir " + dir_path)
			all_check_dirs.erase(dir_path)
	



##ファイルのデータを持ったアイテムなら　チェックに応じて　生成リストにデータを設定する
func file_item_set_pot_generate_list(item:TreeItem) -> void:
	if not is_file(item):return
	
	var uid:String = get_file(item)
	
	
	if item.is_checked(COLUMN_CHECK):
		if not pot_generate_files.has(uid):
			#print("POT Plugin : append file " + ResourceUID.ensure_path(uid))
			pot_generate_files.append(uid)
	else:
		if pot_generate_files.has(uid):
			#print("POT Plugin : remove file " + ResourceUID.ensure_path(uid))
			pot_generate_files.erase(uid)
	




##itemからディレクトリのパスを取得
func get_dir(item:TreeItem) -> String:
	var meta:String = item.get_metadata(COLUMN_CHECK)
	return meta.trim_prefix("dir:")

##itemからファイルのパスを取得
func get_file(item:TreeItem) -> String:
	var meta:String = item.get_metadata(COLUMN_CHECK)
	return meta.trim_prefix("file:")

##これがディレクトリのデータを持ったアイテムかであるか
func is_dir(item:TreeItem) -> bool:
	if item.get_metadata(COLUMN_CHECK) == null:return false
	
	var meta:String = item.get_metadata(COLUMN_CHECK)
	return meta.begins_with("dir:")

##これがファイルのデータを持ったアイテムかであるか
func is_file(item:TreeItem) -> bool:
	if item.get_metadata(COLUMN_CHECK) == null:return false
	
	var meta:String = item.get_metadata(COLUMN_CHECK)
	return meta.begins_with("file:")

#endregion




#region Visuals



##uid, class
##もしカスタムクラスアイコンならpreffix c: です
var resource_path_to_class_name_or_script_uid_cache:Dictionary[String, String]


func get_class_icon_from_path_or_uid(path_or_uid:String) -> Texture2D:
	var script_icon:Texture2D
	
	var res:Resource
	
	if class_icon and ResourceLoader.exists(path_or_uid):
		var uid:String = ResourceUID.path_to_uid(path_or_uid)
		##キャッシュが有ったらそれを使う
		if resource_path_to_class_name_or_script_uid_cache.has(uid): ##NOTE ##このhasが結構重いっぽい
			var c_name:String = resource_path_to_class_name_or_script_uid_cache[uid]
			if c_name.begins_with("uid") or c_name.begins_with("res"):##カスタムアイコンのはパスで記録しているので
				script_icon = find_custom_class_icon_or_null(c_name)
			else:
				script_icon = get_theme_icon(c_name, "EditorIcons")
			
		else:##なかったらロードして
			res = load(uid)
			
			
			
			if res.get_script():##カスタムスクリプトなら　そのクラスの独自のアイコンがないか探す
				var script_path:String = res.get_script().resource_path
				script_icon = find_custom_class_icon_or_null(script_path)
				if script_icon:
					resource_path_to_class_name_or_script_uid_cache[uid] = ResourceUID.path_to_uid(script_path)
				
			
			if script_icon == null:##なければベースクラスのアイコンを探す
				var c:String = res.get_class()
				if has_theme_icon(c, "EditorIcons"):
					script_icon = get_theme_icon(c, "EditorIcons")
					resource_path_to_class_name_or_script_uid_cache[uid] = c
	
	
	
	
	
	if script_icon == null:##なかったら　ファイルのアイコンにする
		script_icon = get_theme_icon("File", "EditorIcons")
	
	
	
	return script_icon


## icon_path, texture
## scriptのパスではなくiconのパスです
var custom_class_icon_cache:Dictionary[String, Texture2D]
##script_resource_path = res.get_script().resource_path
##scriptファイルのパスからもしあればカスタムクラスアイコン画像を返す
func find_custom_class_icon_or_null(script_resource_path:String) -> Texture2D:
	var script_icon:Texture2D
	
	for class_dic:Dictionary in ProjectSettings.get_global_class_list():
		if class_dic.path == ResourceUID.ensure_path(script_resource_path):
			if (class_dic.icon as String).is_empty():break
			
			if custom_class_icon_cache.has(class_dic.icon):
				script_icon = custom_class_icon_cache[class_dic.icon]
			else:
				script_icon = load(class_dic.icon)
				custom_class_icon_cache[class_dic.icon] = load(class_dic.icon)
			
			break
	
	return script_icon


##UNUSED
func clear_cache() -> void:
	resource_path_to_class_name_or_script_uid_cache.clear()
	custom_class_icon_cache.clear()






#endregion
