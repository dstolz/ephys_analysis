function onSaveMapping(obj, asNew)
%onSaveMapping  Save mapping (to the name it has, else ask) / Save mapping as (always ask).
if isempty(obj.Result)
    obj.setStatus('Nothing to save: choose a package and a headstage.', true);
    return
end
name = obj.MappingName;
if asNew || name == ""
    def = name;
    if def == ""
        parts = [extractAfter(obj.PackageId, "/"), extractAfter(obj.HeadstageId, "/")];
        if obj.ProbeId ~= ""
            parts = [extractAfter(obj.ProbeId, "/"), parts];
        end
        def = strjoin(parts, "_");
    end
    [name, ok] = ChannelMapperApp.promptText(obj.Fig, 'Save mapping', ...
        'Name of the mapping (saved to the bank''s mappings folder):', def);
    if ~ok || strtrim(name) == ""
        return
    end
end
overwrite = false;
target = HardwareBank.safeName(name);
if obj.Bank.has(target)
    if target ~= obj.MappingName || asNew
        answer = uiconfirm(obj.Fig, sprintf('A mapping called %s exists. Replace it?', target), 'Save mapping', ...
            'Options', {'Replace', 'Cancel'}, 'DefaultOption', 2, 'CancelOption', 2);
        if answer ~= "Replace"
            return
        end
    end
    overwrite = true;
end
try
    obj.saveMapping(name, Overwrite=overwrite);
catch ME
    obj.setStatus("Not saved: " + ME.message, true);
    uialert(obj.Fig, ME.message, 'Save mapping');
end
end
