function applyConfig(obj, cfg, opts)
%applyConfig  Show a config in every control (MarkSaved=true: it is the saved state).
arguments
    obj (1,1) EphysAnalysisApp
    cfg (1,1) EphysAnalysisConfig
    opts.MarkSaved (1,1) logical = false
end
obj.Applying = true;
restore = onCleanup(@() setApplying(obj, false));
obj.Config = cfg;
obj.ConfigNameField.Value = char(cfg.Name);
obj.ConfigDescField.Value = char(cfg.Description);
obj.applySourceSection(cfg.Source);
D = cfg.Defaults;
obj.applyAlignControls(obj.AlignControls, D.EventRef, D.Window, D.Selection);
obj.applyExportSection(cfg.Export);
obj.applyReportSection(cfg.Report);
n = numel(cfg.Plots);
if n == 0
    obj.SelectedPlot = 0;
else
    obj.SelectedPlot = min(max(obj.SelectedPlot, 1), n);
end
obj.refreshPlotList();
obj.applyPlotEditor();
if opts.MarkSaved
    obj.SavedConfigStruct = cfg.toStruct();
end
clear restore
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
    if ~isequaln(cfg.Source, obj.ScannedSource)
        obj.ScanLabel.Text = "The source changed: Scan to list its datasets.";
    end
end
obj.updateTitle();
end


function setApplying(obj, tf)
if isvalid(obj); obj.Applying = tf; end
end
