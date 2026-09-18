function onTabChanged(obj)
%onTabChanged  Refresh what the shown tab draws; a hint in the status bar.
switch obj.Tabs.SelectedTab
    case obj.TabData
        msg = "Data: where the datasets are; Scan, tick the ones to run, click one to make it active.";
    case obj.TabAlign
        msg = "Alignment: the event, window and trial selection every plot uses unless it sets its own.";
        obj.refreshAlignPreview();
    case obj.TabPlots
        msg = "Plots: add plots, edit them, preview them on the active dataset.";
        if isempty(obj.PreviewResult); obj.autoPreview(); end
    case obj.TabExport
        msg = "Export: figure files and the report; Validate, Plan, Run over the ticked datasets.";
    otherwise
        msg = "Log: what the scans and runs reported.";
end
obj.setStatus(msg);
end
