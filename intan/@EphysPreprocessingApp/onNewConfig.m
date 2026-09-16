function onNewConfig(obj)
%onNewConfig  Start from a default config (asks to save unsaved changes).
if ~obj.confirmDiscard(); return; end
cfg = EphysPipelineConfig();
cfg.Sorting.PythonExe = obj.defaultPythonExe();
obj.applyConfig(cfg, MarkSaved=true);
obj.setStatus("New config (defaults).", "Set the project root on the Project tab and Scan.");
end
