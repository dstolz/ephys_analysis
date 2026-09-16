function refreshDatasetsTable(obj)
%refreshDatasetsTable  Rebuild the datasets table from project metadata.
%   Preserves the existing "Select" ticks (matched by key).

vars = {'Select','Name','Key','AcqDate','NumChannels','Fs','DurationMin','Format', ...
        'Probe','Exclude','Sorting','Behavior','DatasetIdx'};
if isempty(obj.Project) || obj.Project.NumDatasets == 0
    obj.DatasetsTable.Data = table('Size', [0 13], ...
        'VariableTypes', {'logical','string','string','string','double','double','double', ...
                          'string','string','string','string','string','double'}, ...
        'VariableNames', vars);
    return
end

n = obj.Project.NumDatasets;
prev = obj.DatasetsTable.Data;
Select = false(n, 1);
Key = strings(n, 1);
for i = 1:n
    Key(i) = obj.Project.datasetKey(i);
end
if istable(prev) && any(strcmp('Select', prev.Properties.VariableNames)) ...
        && any(strcmp('Key', prev.Properties.VariableNames))
    for i = 1:n
        m = strcmpi(prev.Key, Key(i));
        if any(m); Select(i) = prev.Select(find(m, 1)); end
    end
end

Name = strings(n, 1); AcqDate = strings(n, 1); NumChannels = zeros(n, 1); Fs = zeros(n, 1);
DurationMin = zeros(n, 1); Format = strings(n, 1); Probe = strings(n, 1); Exclude = strings(n, 1);
Sorting = strings(n, 1); Behavior = strings(n, 1);

for i = 1:n
    d = obj.Project.Datasets(i);
    Name(i)   = d.Name;
    Format(i) = d.RecordingFormat;
    if ~isnat(d.AcqDate)
        AcqDate(i) = string(datetime(d.AcqDate, 'Format', 'yyyy-MM-dd HH:mm'));
    end
    NumChannels(i) = d.NumChannels;
    Fs(i) = d.Fs;
    if ~isnan(d.Duration); DurationMin(i) = d.Duration / 60; end
    if d.ProbeFile ~= "" && isfile(d.ProbeFile)
        [~, pn, pe] = fileparts(d.ProbeFile);
        Probe(i) = pn + pe;
    else
        Probe(i) = "-";
    end
    if isempty(d.ExcludeChannels)
        Exclude(i) = "-";
    else
        Exclude(i) = EphysDataset.formatChannelList(d.ExcludeChannels);
    end
    s = d.sortingStruct();
    if s.results_dir == ""
        Sorting(i) = "-";
    else
        txt = s.source;
        if isfinite(s.num_units); txt = txt + sprintf(": %d units", s.num_units); end
        if s.curated; txt = txt + ", curated"; end
        Sorting(i) = txt;
    end
    if d.BehaviorFile == "" || ~isfile(d.BehaviorFile)
        Behavior(i) = "-";
    else
        try
            m = epsychSessionMeta(d.BehaviorFile);
            Behavior(i) = sprintf("%s (%d trials)", m.subject, m.nTrials);
        catch
            [~, bf, be] = fileparts(d.BehaviorFile);
            Behavior(i) = bf + be;
        end
        if ~isempty(d.TrialPairing)
            Behavior(i) = Behavior(i) + ", pairing " + d.TrialPairing.status;
        end
    end
end

DatasetIdx = (1:n)';
T = table(Select, Name, Key, AcqDate, NumChannels, Fs, round(DurationMin, 2), Format, ...
    Probe, Exclude, Sorting, Behavior, DatasetIdx, 'VariableNames', vars);
obj.DatasetsTable.Data = T;
obj.updatePhyButtonState();
end
