function ok = onSaveConfigAs(obj)
%onSaveConfigAs  Pick a file and save the working config there.
%   Refused while a text field does not parse (gatherConfig).
ok = false;
try
    cfg = obj.gatherConfig();
catch ME
    uialert(obj.Fig, string(ME.message), "Save config");
    return
end
start = char(cfg.File);
if isempty(start)
    d = char(obj.defaultConfigFolder());
    if ~isfolder(d); mkdir(d); end
    name = regexprep(char(cfg.Name), '[^\w\-]+', '_');
    if isempty(name); name = 'pipeline'; end
    start = fullfile(d, [name '.json']);
end
[f, p] = uiputfile({'*.json', 'Pipeline config (*.json)'}, "Save pipeline config as", start);
figure(obj.Fig);
if isequal(f, 0); return; end
file = fullfile(p, f);
try
    cfg = cfg.save(file);
catch ME
    uialert(obj.Fig, "Could not save config:" + newline + string(ME.message), "Save config");
    return
end
obj.Config = cfg;
obj.SavedConfigStruct = cfg.toStruct();
obj.addRecentConfig(file);
obj.savePreferences();
obj.updateTitle();
obj.setStatus("Saved " + string(file), "");
ok = true;
end
