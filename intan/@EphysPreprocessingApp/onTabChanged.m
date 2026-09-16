function onTabChanged(obj)
%onTabChanged  Refresh the status hint (and per-tab previews) on tab change.
switch obj.Tabs.SelectedTab
    case obj.TabProject
        msg = "Project: set the root and Scan; tick rows to select datasets (none = all).";
    case obj.TabProbe
        msg = "Probe: pick a probe .json and assign it; exclusions are saved per dataset.";
    case obj.TabArtifacts
        msg = "Artifacts: tune the detector and preview what would be silenced.";
        obj.refreshManualArtifactsTable();
    case obj.TabSorting
        msg = "Sorting: SpikeInterface + Kilosort4 settings; Run this step or the whole pipeline.";
        obj.refreshSortingLabel();
    case obj.TabSignals
        msg = "Signals: derive LFP / MUA / SPIKE for the selected datasets.";
        obj.refreshStepPlan("signals");
    case obj.TabSpikes
        msg = "Spikes: threshold detection and/or sorted units per dataset.";
    case obj.TabExport
        msg = "Export: write Chronux / FieldTrip files from the extract + spikes.";
        obj.refreshStepPlan("export");
    case obj.TabRun
        msg = "Run: validate, plan, then run the enabled steps.";
    case obj.TabVisualize
        msg = "Visualize: plot a short window; drag to mark manual artifacts.";
    case obj.TabReview
        msg = "Review: load a results folder to inspect sorted units.";
    otherwise
        msg = "Ready.";
end
obj.setStatus(msg);
end
