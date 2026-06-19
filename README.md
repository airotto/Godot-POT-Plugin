[Japanese/日本語](README.ja.md)

# POT Plugin
This add-on allows you to select files to include in POT generation in a tree-like structure.

## Basics
Available in ProjectSettings>Localization>PotPlugin  
Files with a checkmark will be included in the generation.  
![](Media/general.png)  

## Folders
To prevent accidental operations and avoid the complexity of the features described below, you cannot manually select folders.  
(In Godot, checkboxes apply to the entire item, even if the checkbox is not selected.)  
Please use the checkbox on the right instead.  

Folders with the checkbox on the right selected will always check their child files (including nested ones).  
(For example, check the “Items” folder to automatically include all item resources.)  

If you uncheck it, the checkmark inside will be removed.  
(If the checkbox on the right is checked for a child folder (including nested folders), the checkmark for that child folder (including nested folders) will not be removed.)  

Therefore, if you accidentally check it, use Ctrl+Z or similar to undo the action.  

## Data locations
Save data, such as which files to include, is stored in res://pot_plugin_save_data.cfg.  
Local configuration data (such as personal settings like the dark theme) is stored in res://.godot/pot_plugin_local_setting.cfg. (Since it's inside the .godot directory, it's generally ignored by gitignore.)  


## Other
### Settings  
![](Media/setting.png)  
### Tools  
![](Media/tool.png)  

##
Supported Versions (Previous versions are available on the branch):
- 4.7
- 4.6.3
- 4.6.2
