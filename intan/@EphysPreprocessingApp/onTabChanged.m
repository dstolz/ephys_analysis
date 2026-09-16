function onTabChanged(obj)
    % Refresh the status bar when the active tab changes: describe what
    % the tab is for and re-evaluate the suggested next step.
    switch obj.Tabs.SelectedTab
        case obj.TabDatasets
            msg = "Datasets: scan a folder, then tick rows to include in batch actions.";
        case obj.TabProbe
            msg = "Probe: pick a probe .json and assign it to the selected or all datasets.";
        case obj.TabArtifacts
            msg = "Artifacts: tune the detector and preview what would be silenced.";
        case obj.TabVisualize
            msg = "Visualize: plot a short window; drag to mark manual artifacts.";
        case obj.TabKilosort
            msg = "Kilosort: set paths + SpikeInterface preprocessing, then Run Kilosort4.";
        case obj.TabReview
            msg = "Review: load a results folder to inspect sorted units.";
        case obj.TabConvert
            msg = "Convert: derive LFP / MUA / SPIKE for the ticked datasets and save .mat files.";
            obj.refreshConvertTargets();
        otherwise
            msg = "Ready.";
    end
    obj.setStatus(msg);
end
