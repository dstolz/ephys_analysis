function onTabChanged(obj)
%onTabChanged  Refresh what the shown tab draws; a hint in the status bar.
switch obj.Tabs.SelectedTab
    case obj.TabData
        msg = "Data: where the datasets are; Scan, tick the ones to run, click one to make it active.";
    case obj.TabAlign
        msg = "Alignment: the event, window and trial selection every figure uses unless it sets its own.";
        obj.refreshAlignPreview();
    case obj.TabFigures
        msg = "Figures: design a figure for one unit, channel or the dataset; the preview draws the observation picked above it.";
        obj.refreshFigureObservations();
        if isempty(obj.FigurePreviewResult) || obj.FigurePreviewState == "stale"; obj.autoFigurePreview(); end
    case obj.TabExport
        msg = "Export: figure files and the report; Validate, Plan, Run over the ticked datasets.";
    case obj.TabChronux
        msg = "Chronux: spectra of the active dataset's Chronux file (create it if missing), over epochs or a stretch.";
        obj.refreshChronuxTab();
    otherwise
        msg = "Log: what the scans and runs reported.";
end
obj.setStatus(msg);
end
