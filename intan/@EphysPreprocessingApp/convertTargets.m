function T = convertTargets(obj, cfg)
    % One row per dataset a Convert run would process (Datasets-tab
    % ticks, or all), with its output file and a pre-run status.
    T = table('Size', [0 5], ...
        'VariableTypes', {'double', 'string', 'string', 'string', 'string'}, ...
        'VariableNames', {'DatasetIdx', 'Dataset', 'Format', 'OutputFile', 'Status'});
    if isempty(obj.Project) || obj.Project.NumDatasets == 0; return; end
    outRoot = strtrim(string(cfg.OutputDir));
    for k = obj.selectedDatasetIndices()
        d = obj.Project.Datasets(k);
        if strlength(outRoot) == 0
            outDir = d.Folder;   % default: next to the raw data
        else
            outDir = outRoot;
        end
        f = string(fullfile(outDir, d.Name + string(cfg.Suffix) + ".mat"));
        if d.RecordingFormat == "unknown"
            st = "will skip: no Intan files";
        elseif isfile(f) && cfg.Overwrite
            st = "exists: will overwrite";
        elseif isfile(f)
            st = "exists: will skip";
        else
            st = "ready";
        end
        T(end+1, :) = {k, d.Name, d.RecordingFormat, f, st}; %#ok<AGROW>
    end
end
