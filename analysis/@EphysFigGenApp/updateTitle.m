function updateTitle(obj)
%updateTitle  Figure title: app, config name, file, and "*" while unsaved.
if isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
cfg = obj.Config;
t = "Ephys analysis - " + cfg.Name;
if cfg.File ~= ""
    [~, f, e] = fileparts(cfg.File);
    t = t + "  [" + f + e + "]";
end
if ~isequaln(cfg.toStruct(), obj.SavedConfigStruct)
    t = "* " + t;
end
obj.Fig.Name = char(t);
end
