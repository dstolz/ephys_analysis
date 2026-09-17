function populateReviewDatasets(obj)
    % Fill the Review dataset dropdown from scanned datasets that have
    % sorted output. The dataset's own association (sortingResultsDir:
    % an explicit SortingDir, else the auto-discovered run) wins; the
    % DatasetTracker's latest run is the fallback so results in
    % non-default folders are still found. Both gate on the same
    % spike_clusters.npy that loadReviewResults requires.
    obj.ReviewDatasetDropDown.Items = {'(pick folder, or scan first)'};
    obj.ReviewDatasetDropDown.ItemsData = {};
    if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
    obj.applyConfigToProject();
    names = {};
    dirs  = {};
    for k = 1:obj.Project.NumDatasets
        d = obj.Project.Datasets(k);
        if d.hasKilosortResults()
            names{end+1} = char(d.Name);                  %#ok<AGROW>
            dirs{end+1}  = char(d.sortingResultsDir());   %#ok<AGROW>
            continue
        end
        run = d.tracker().latestKilosortRun();
        if ~isempty(run) && run.HasResults
            names{end+1} = char(d.Name);    %#ok<AGROW>
            dirs{end+1}  = char(run.Dir);   %#ok<AGROW>
        end
    end
    if isempty(names)
        obj.ReviewDatasetDropDown.Items = {'(no kilosort4 results found)'};
    else
        obj.ReviewDatasetDropDown.Items = names;
        obj.ReviewDatasetDropDown.ItemsData = dirs;
    end
end
