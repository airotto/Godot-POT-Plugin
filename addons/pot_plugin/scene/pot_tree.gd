@tool
extends Tree


@export var class_icon:bool = false

##全ての子にチェックをいれるディレクトリのパスのリスト(フォルダーの右のチェックついてるやつ)
var all_check_dirs := PackedStringArray()
##チェック入ってるファイルのパス(uidがあればuid)のリスト
var pot_generate_files := PackedStringArray()

##キャッシュ 
var _path_uid_hashmap : Dictionary[String, String]
##前回展開していたディレクトリ
##
## save_expanded()参照
var last_expanded_dirs := PackedStringArray()

signal save

const COLUMN_CHECK:int = 0
const COLUMN_LOCK:int = 1


const FolderColorManager = preload("uid://comiy8ykyv6le")
@onready var folder_color_manager: FolderColorManager = $FolderColorManager

var reloaded:bool = false



func _ready() -> void:
	hide_root = false
	
	
	
	item_edited.connect(_on_item_edited)
	check_propagated_to_item.connect(_on_check_propagated_to_item)
	
	item_collapsed.connect(_on_item_collapsed)


func _on_item_collapsed(item: TreeItem) -> void:
	if not item.collapsed:
		for i in item.get_children():
			set_icon(i)
			
			set_color(i)
			
			
			if is_dir(i):
				var dir := get_dir(i)
				if last_expanded_dirs.has(dir):
					last_expanded_dirs.erase(dir)
					i.collapsed = false


func set_color(item:TreeItem) -> void:
	
	if is_file(item):
		var color_dic:Dictionary[StringName, Color] = folder_color_manager.get_dir_or_file_color(get_file(item))
		
		item.set_custom_bg_color(0, color_dic[&"bg"])
		item.set_custom_bg_color(1, color_dic[&"bg"])
		return
	if is_dir(item):
		var color_dic:Dictionary[StringName, Color] = folder_color_manager.get_dir_or_file_color(get_dir(item))
		
		item.set_custom_bg_color(0, color_dic[&"bg"])
		item.set_custom_bg_color(1, color_dic[&"bg"])
		item.set_icon_modulate(0, color_dic[&"icon"])


## scne/pot_plugin.gd の save_local_setting() で実行されます。
## save_local_setting() はプロジェクト設定ウィンドウを閉じたときに(も)実行されます
func save_expanded(item:TreeItem) -> void:
	if not item:return
	
	for i in item.get_children():
		if is_dir(i):
			
			if not i.collapsed:
				var dir := get_dir(i)
				if not last_expanded_dirs.has(dir):
					last_expanded_dirs.append(dir)
			
			save_expanded(i)


#region Reload



##リロードする
func reload() -> void:
	#var start_time = Time.get_ticks_usec()
	
	var root := get_root()
	
	if not root:
		root = create_item()
		
		root.set_text(COLUMN_CHECK, "res://")
		root.set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
		
		root.set_icon(COLUMN_CHECK, get_editor_icon(&"Folder") )
		root.set_icon_modulate(COLUMN_CHECK, FolderColorManager.DEFAULT_FOLDER_ICON_COLOR)
		
		add_theme_constant_override(&"icon_max_width", get_theme_constant(&"class_icon_size", &"Editor") )
	
	
	
	
	
	
	for dir_path:String in all_check_dirs:
		
		if DirAccess.dir_exists_absolute(dir_path) == false:
			all_check_dirs.erase(dir_path)
			print("POT Plugin : all check dir not exists " + dir_path + " (not error)")
			
	
	
	for file_path:String in pot_generate_files:
		if FileAccess.file_exists(file_path) == false:
			pot_generate_files.erase(file_path)
			print("POT Plugin : file not exists " + file_path + " (not error)")
	
	
	## uidをpathにするのは高速だが、逆は超低速なので　pathをuidに変換をしないような実装にしている
	_path_uid_hashmap.clear()
	for uid:String in pot_generate_files:
		_path_uid_hashmap[ResourceUID.ensure_path(uid)] = uid
	
	
	var resource_filesystem_dir:EditorFileSystemDirectory = EditorInterface.get_resource_filesystem().get_filesystem()
	_reload_iterate(root, resource_filesystem_dir)
	
	_on_item_collapsed(root)
	
	reloaded = true
	
	#var start_time = Time.get_ticks_usec()
	
	
	#for i in 1000:
	pass
	
	#var end_time = Time.get_ticks_usec()
	#var elapsed_time = end_time - start_time
	#print("経過時間: ", elapsed_time, " マイクロ秒")


##これは単独で実行しない  reloadを使用してください
func _reload_iterate(dir_item:TreeItem, dir:EditorFileSystemDirectory) -> void:
	
	## 足りなかったら作成　多かったら削除　オブジェクトプールみたいな感じ
	if dir_item.get_child_count() > dir.get_subdir_count() + dir.get_file_count():
		for i in dir_item.get_child_count() - dir.get_subdir_count() + dir.get_file_count():
			dir_item.remove_child(dir_item.get_first_child())
	elif dir_item.get_child_count() < dir.get_subdir_count() + dir.get_file_count():
		for i in dir.get_subdir_count() + dir.get_file_count() - dir_item.get_child_count():
			dir_item.create_child()
	
	
	for i in dir.get_file_count():
		var my_file_path:StringName = dir.get_file_path(i)
		
		var item:TreeItem = dir_item.get_child(i)
		
		
		item.remove_meta(&"dir_path")
		item.remove_meta(&"file_uid")
		item.set_meta(&"file_path", my_file_path)
		item.set_cell_mode(COLUMN_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_CHECK, true)
		item.set_text(COLUMN_CHECK, dir.get_file(i))
		item.set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
		
		
		item.set_tooltip_text(COLUMN_CHECK, "チェックがついているとPOT生成に含まれます")
		
		
		
		
		##データから読み込む
		if _path_uid_hashmap.keys().has(my_file_path):
			#print(uid)
			item.set_meta(&"file_uid", _path_uid_hashmap[my_file_path])
			
			item.set_checked(COLUMN_CHECK, true)
			item.propagate_check(COLUMN_CHECK, false)
		
	
	
	
	
	
	for i in dir.get_subdir_count():
		var sub_dir:EditorFileSystemDirectory = dir.get_subdir(i)
		var my_dir_path:StringName = sub_dir.get_path()
		
		
		var item:TreeItem = dir_item.get_child(dir.get_file_count() + i)
		item.set_collapsed_recursive(true)
		
		
		
		
		item.remove_meta(&"file_path")
		item.remove_meta(&"file_uid")
		item.set_meta(&"dir_path", my_dir_path)
		item.set_cell_mode(COLUMN_CHECK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_CHECK, false)
		item.set_cell_mode(COLUMN_LOCK, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_LOCK, true)
		item.set_text(COLUMN_CHECK, sub_dir.get_name())
		item.set_auto_translate_mode(COLUMN_CHECK, Node.AUTO_TRANSLATE_MODE_DISABLED)
		
		
		item.set_tooltip_text(COLUMN_CHECK, "誤操作を防ぐためにロックされています　操作は右のチェックボックスから")
		item.set_tooltip_text(COLUMN_LOCK, "このチェックがついているフォルダの中のファイルは自動でチェックが付きます。外すと、中のファイルはチェックが外れます。")
		
		
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
				_name = "POT Plugin : ファイル %s を追加" % get_file(item)
			else:
				_name = "POT Plugin : ファイル %s を除去" % get_file(item)
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
	
	var path:String = get_file(item)
	var uid:String = get_uid_if_selected(item) if has_uid_meta(item) else (path if ResourceLoader.get_resource_uid(path) == -1 else ResourceUID.path_to_uid(path))
	
	
	if item.is_checked(COLUMN_CHECK):
		if not pot_generate_files.has(uid):
			#print("POT Plugin : append file " + ResourceUID.ensure_path(uid))
			item.set_meta(&"file_uid", uid)
			pot_generate_files.append(uid)
	else:
		if pot_generate_files.has(uid):
			#print("POT Plugin : remove file " + ResourceUID.ensure_path(uid))
			#item.remove_meta(&"file_uid")
			pot_generate_files.erase(uid)
	




##itemからディレクトリのパスを取得
func get_dir(item:TreeItem) -> StringName:
	return item.get_meta(&"dir_path")

##itemからファイルのパスを取得
func get_file(item:TreeItem) -> StringName:
	return item.get_meta(&"file_path")

##itemからファイルのuidを取得
## 注意:選択されている場合のみ
func get_uid_if_selected(item:TreeItem) -> StringName:
	return item.get_meta(&"file_uid")

func has_uid_meta(item:TreeItem) -> bool:
	return item.has_meta(&"file_uid")

##これがディレクトリのデータを持ったアイテムかであるか
func is_dir(item:TreeItem) -> bool:
	return item.has_meta(&"dir_path")

##これがファイルのデータを持ったアイテムかであるか
func is_file(item:TreeItem) -> bool:
	return item.has_meta(&"file_path")

#endregion




#region Visuals

func set_icon(item:TreeItem) -> void:
	if is_file(item):
		var icon:Texture2D = await get_class_icon(get_file(item))
		item.set_icon(COLUMN_CHECK, icon)
	elif is_dir(item):
		item.set_icon(COLUMN_CHECK, get_editor_icon(&"Folder") )
		item.set_icon(COLUMN_LOCK, get_editor_icon(&"ThemeSelectAll") )


func get_class_icon(path:StringName) -> Texture2D:
	var script_icon:Texture2D
	
	
	if class_icon and ResourceLoader.exists(path):
		var res:Resource = await load(path)
		
		
		var resource_script_path:StringName
		var script:Script = res.get_script()
		if script:
			resource_script_path = script.resource_path
			
			
			var sc:Script = script
			var icon:Texture2D
			
			while true:
				
				for dic:Dictionary in ProjectSettings.get_global_class_list():
					if dic.path == sc.resource_path:
						if (dic.icon as String):
							icon = await load(dic.icon as String)
							break
				
				if icon:
					break
				
				sc = sc.get_base_script()
				if not sc:
					break
				
			if icon:
				return icon
		
		
		var resource_class_name:StringName = res.get_class()
		if has_theme_icon(resource_class_name, &"EditorIcons"):
			return get_editor_icon(resource_class_name)
		else:
			return get_editor_icon(&"Object")
		
	
	
	return get_editor_icon(&"File")

var _editor_icon_cache:Dictionary[StringName, Texture2D]
func get_editor_icon(_name:StringName) -> Texture2D:
	if not _editor_icon_cache.has(_name):
		_editor_icon_cache[_name] = get_theme_icon(_name, &"EditorIcons")
	return _editor_icon_cache[_name]


##UNUSED
func clear_cache() -> void:
	pass



##Cowが破壊されるのでやめとく
#func load_thread(path: String) -> Resource:
	#var error := ResourceLoader.load_threaded_request(path, "", true)
	#
	#if error != Error.OK:
		#return null
	#
	#while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.ThreadLoadStatus.THREAD_LOAD_IN_PROGRESS:
		#await get_tree().process_frame
	#
	#var status := ResourceLoader.load_threaded_get_status(path)
	#if status != ResourceLoader.ThreadLoadStatus.THREAD_LOAD_LOADED:
		#return null
	#
	#return ResourceLoader.load_threaded_get(path)

#endregion
