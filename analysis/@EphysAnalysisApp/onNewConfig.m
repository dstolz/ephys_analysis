function onNewConfig(obj)
%onNewConfig  Start from a default config (asks to save unsaved changes).
if ~obj.confirmDiscard(); return; end
obj.SelectedPlot = 0;
obj.applyConfig(EphysAnalysisConfig(), MarkSaved=true);
obj.setStatus("New analysis config (defaults). Set where the datasets are on the Data tab and Scan.");
end
