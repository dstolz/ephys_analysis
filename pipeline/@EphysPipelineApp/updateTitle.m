function updateTitle(obj)
%updateTitle  Figure title: app name, config name, file and the unsaved marker.
if isempty(obj.Fig) || ~isvalid(obj.Fig); return; end
cfg = obj.Config;
dirty = ~isequaln(cfg.toStruct(), obj.SavedConfigStruct);
t = "Ephys preprocessing - " + cfg.Name;
if cfg.File ~= ""
    [~, f, e] = fileparts(cfg.File);
    t = t + "  [" + f + e + "]";
end
if dirty
    t = "* " + t;
end
obj.Fig.Name = char(t);
end
