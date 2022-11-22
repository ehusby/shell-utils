this_script_dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

target_script_path = Wscript.Arguments(0)
output_shortcut_path = Wscript.Arguments(1)
If WScript.Arguments.Count > 2 Then
    shortcut_icon_path = Wscript.Arguments(2)
Else
    shortcut_icon_path = ""
End If

Set sh = CreateObject("WScript.Shell")
Set shortcut = sh.CreateShortcut(output_shortcut_path)
shortcut.TargetPath = target_script_path
shortcut.WorkingDirectory = ""
If NOT StrComp(shortcut_icon_name, "") Then
    shortcut.IconLocation = shortcut_icon_path
End If
shortcut.Save