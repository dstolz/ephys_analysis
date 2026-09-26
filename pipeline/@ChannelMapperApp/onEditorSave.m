function file = onEditorSave(obj)
%onEditorSave  Save the editor's entry to the bank, then choose it in the window.
%   Refused while the entry has problems (the editor's check label lists
%   them). Replacing an existing entry asks first. FILE is the file
%   written ("" when nothing was saved).
file = "";
E = obj.Editor;
if isempty(E)
    return
end
obj.editorRefresh();
E = obj.Editor;
if E.SaveButton.Enable == "off"
    E.Status.Text = 'Not saved: fix the problems listed on the right first.';
    return
end
raw = obj.editorEntry();
id = HardwareBank.entryId(E.Kind, HardwareBank.safeName(lower(string(raw.manufacturer))), HardwareBank.safeName(raw.name));
overwrite = false;
if obj.Bank.has(id)
    answer = uiconfirm(E.Fig, sprintf('%s is in the bank already. Replace it?', id), 'Save to bank', ...
        'Options', {'Replace', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
    if answer ~= "Replace"
        return
    end
    overwrite = true;
end
try
    file = obj.Bank.saveEntry(raw, Overwrite=overwrite);
catch ME
    E.Status.Text = char("Not saved: " + ME.message);
    return
end
delete(E.Fig);
obj.Editor = struct([]);
obj.refreshBank();
switch E.Kind
    case "probe"
        obj.selectProbe(id);
    case "package"
        obj.selectPackage(id);
    case "headstage"
        obj.selectHeadstage(id, 1);
end
obj.setStatus("Saved " + id + " to the bank (" + file + ").", false);
end
