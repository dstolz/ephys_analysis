function ok = confirmDiscard(obj)
%confirmDiscard  Ask Save / Discard / Cancel when the config has unsaved changes.
%   Returns true when it is fine to go on (saved, discarded or clean).
ok = true;
try
    cfg = obj.gatherConfig();
catch
    cfg = obj.Config;
end
if isequaln(cfg.toStruct(), obj.SavedConfigStruct); return; end
sel = uiconfirm(obj.Fig, "The analysis config """ + cfg.Name + """ has unsaved changes.", "Unsaved changes", ...
    "Options", {'Save', 'Discard', 'Cancel'}, "DefaultOption", 1, "CancelOption", 3);
switch sel
    case 'Save',    ok = obj.onSaveConfig();
    case 'Discard', ok = true;
    otherwise,      ok = false;
end
end
