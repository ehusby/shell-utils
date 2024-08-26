this_script_dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)

target_script_name = Wscript.Arguments(0)
If WScript.Arguments.Count > 1 Then
    shortcut_icon_name = Wscript.Arguments(1)
Else
    shortcut_icon_name = ""
End If

Set sh = CreateObject("WScript.Shell")
Set shortcut = sh.CreateShortcut(this_script_dir & "\..\shortcuts\" & target_script_name & ".lnk")
shortcut.TargetPath = this_script_dir & "\..\starter_scripts\" & target_script_name & ".bat"
shortcut.WorkingDirectory = ""
If NOT StrComp(shortcut_icon_name, "") Then
    shortcut.IconLocation = this_script_dir & "\..\icons\" & shortcut_icon_name & ".ico"
End If
shortcut.Save
