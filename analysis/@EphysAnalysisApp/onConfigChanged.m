function onConfigChanged(obj, what)
%onConfigChanged  A control changed: re-gather the config and refresh what depends on it.
%   WHAT says which part changed: "name", "source", "ticks", "defaults"
%   (the Alignment tab), "plot" (the plot editor) or "export". The runner
%   gets the new config; the Alignment count, the plot list and the preview
%   (auto-preview) follow.
arguments
    obj (1,1) EphysAnalysisApp
    what (1,1) string = ""
end
if obj.Applying; return; end
try
    cfg = obj.gatherConfig();
catch ME
    obj.setStatus("Config: " + string(ME.message));
    return
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
switch what
    case "source"
        obj.syncSourceEnable();
        if ~isempty(obj.Runner) && ~isempty(fieldnames(obj.ScannedSource)) && ~isequaln(rmfield(cfg.Source, {'Selection', 'Datasets'}), ...
                rmfield(obj.ScannedSource, {'Selection', 'Datasets'}))
            obj.ScanLabel.Text = "The source changed: Scan to list its datasets.";
        end
    case "defaults"
        C = obj.AlignControls;
        set([C.StopLine C.StopEdge C.StopWhich C.StopN C.StopScope], 'Enable', matlab.lang.OnOffSwitchState(C.StopOn.Value));
        obj.refreshAlignPreview();
        obj.applyPlotEditorDefaults();
        obj.autoPreview();
    case "plot"
        obj.refreshPlotList();
        obj.syncPlotEditorEnable();
        obj.autoPreview();
end
obj.updateTitle();
end
