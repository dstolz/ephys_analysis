function onTabChanged(obj)
%onTabChanged  Refresh the tab strip, the status hint and per-tab previews on tab change.
obj.syncTabStrip();
switch obj.Tabs.SelectedTab
    case obj.TabNas
        msg = "NAS: find a subject's sessions, check the pairing, Preview, then Copy selected (nothing on the NAS is changed).";
    case obj.TabProject
        msg = "Project: set the root and Scan; tick rows to select datasets (none = all).";
    case obj.TabTrials
        msg = "Trials: Load a dataset, check how its Epsych2 trials pair with the trial line, edit if needed, then Approve.";
    case obj.TabProbe
        msg = "Probe: pick a probe .json and assign it; exclusions are saved per dataset.";
    case obj.TabArtifacts
        msg = "Artifacts: tune the detector and preview what would be silenced.";
        obj.refreshManualArtifactsTable();
    case obj.TabSorting
        msg = "Sorting: SpikeInterface + Kilosort4 settings; Run this step or the whole pipeline.";
        obj.refreshSortingLabel();
    case obj.TabSignals
        msg = "Signals: derive LFP / MUA / SPIKE / AUX for the selected datasets.";
        obj.refreshStepPlan("signals");
    case obj.TabSpikes
        msg = "Spikes: threshold detection and/or sorted units per dataset.";
    case obj.TabExport
        msg = "Export: write Chronux / FieldTrip files from the extract + spikes.";
        obj.refreshStepPlan("export");
    case obj.TabRun
        msg = "Run: validate, plan, then run the enabled steps.";
    case obj.TabFlow
        msg = "Flow: the processing each enabled step applies, from the raw recording to the files written.";
        obj.refreshFlowChart();
    case obj.TabVisualize
        msg = "Visualize: plot a short window; drag to mark manual artifacts.";
    case obj.TabReview
        msg = "Review: the active dataset's sorted units (or Browse... for any results folder).";
    otherwise
        msg = "Ready.";
end
obj.setStatus(msg);
% The Review tab shows the active dataset's sorted output (after the status
% line, so the load's own message stays).
if obj.Tabs.SelectedTab == obj.TabReview && obj.ReviewDatasetIdx ~= obj.SelectedDatasetIdx
    obj.syncReviewDataset();
end
end
