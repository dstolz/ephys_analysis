function ok = confirmDiscard(obj)
%confirmDiscard  Ask Save / Discard / Cancel when the config has unsaved changes.
%   Returns true when it is fine to go on (saved, discarded or clean).
%   The question comes at once: the config the app holds (obj.Config,
%   which every edit updates: onConfigChanged) is checked first, the same
%   check as the title's "*" (updateTitle). Only a config that is clean
%   there is also gathered from the controls (gatherConfig), in case an
%   edit has not reached it.
ok = true;
cfg = obj.Config;
if isequaln(cfg.toStruct(), obj.SavedConfigStruct)
    try
        cfg = obj.gatherConfig();
    catch
    end
    if isequaln(cfg.toStruct(), obj.SavedConfigStruct); return; end
end
sel = uiconfirm(obj.Fig, "The analysis config """ + cfg.Name + """ has unsaved changes.", "Unsaved changes", ...
    "Options", {'Save', 'Discard', 'Cancel'}, "DefaultOption", 1, "CancelOption", 3);
switch sel
    case 'Save',    ok = obj.onSaveConfig();
    case 'Discard', ok = true;
    otherwise,      ok = false;
end
end
