function outs = datasets(obj)
%datasets  Find the config's datasets: one DatasetOutputs each.
%   OUTS = r.datasets() reads Config.Source and sets Outputs, Keys and
%   Names (and forgets any loaded source):
%     "project"  EphysProject(Root, OutputRoot=, NamePattern=) finds the
%                recording folders (only their folders: no header is read and
%                nothing is written); each dataset's outputs are found under
%                its output folder and recording folder. Selection "list"
%                keeps the Datasets keys (root-relative folders)
%     "folders"  DatasetOutputs(folder) for each of Folders; the key is the
%                folder, the name its last part
%   Every DatasetOutputs has CacheData=true: a plot's spikes and signals
%   are read once per dataset; runDataset clears them afterwards.
%
%   See also EphysAnalysisRunner.source, DatasetOutputs, EphysProject.

S = obj.Config.Source;
obj.clearSources();
outs = DatasetOutputs.empty(1, 0);
keys = string.empty(1, 0);
names = string.empty(1, 0);
obj.Project = [];
switch S.Mode
    case "project"
        if S.Root == "" || ~isfolder(S.Root)
            error('EphysAnalysisRunner:NoRoot', 'Project root does not exist: "%s".', S.Root);
        end
        ws = warning('off', 'EphysProject:NoData');
        P = EphysProject(S.Root, OutputRoot=S.OutputRoot, NamePattern=S.NamePattern);
        warning(ws);
        obj.Project = P;
        idx = 1:P.NumDatasets;
        if S.Selection == "list"
            idx = P.findByKey(S.Datasets);
            missing = S.Datasets(idx == 0);
            if ~isempty(missing)
                warning('EphysAnalysisRunner:UnknownDataset', 'Dataset key(s) not found under %s: %s', ...
                    S.Root, strjoin(missing, ', '));
            end
            idx = idx(idx > 0);
        end
        for k = reshape(idx, 1, [])
            d = P.Datasets(k);
            outs(end+1) = d.outputs('CacheData', true); %#ok<AGROW>
            keys(end+1) = P.datasetKey(k); %#ok<AGROW>
            names(end+1) = d.Name; %#ok<AGROW>
        end
    case "folders"
        for f = S.Folders
            if ~isfolder(f)
                error('EphysAnalysisRunner:NoFolder', 'Output folder does not exist: "%s".', f);
            end
            o = DatasetOutputs(f, CacheData=true);
            outs(end+1) = o; %#ok<AGROW>
            keys(end+1) = f; %#ok<AGROW>
            names(end+1) = o.Name; %#ok<AGROW>
        end
    otherwise
        error('EphysAnalysisRunner:BadSource', 'Source.Mode must be "project" or "folders".');
end
obj.Outputs = outs;
obj.Keys = keys;
obj.Names = names;
end
