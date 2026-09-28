function onUseDataset(obj)
%onUseDataset  Take the recording rows from a dataset's ChannelNumbers.
%   From the preprocessing app: pick one of the project's datasets.
%   Standalone: choose a recording folder, read as an EphysDataset.
d = EphysDataset.empty;
if ~isempty(obj.App) && isvalid(obj.App) && ~isempty(obj.App.Project) && obj.App.Project.NumDatasets > 0
    D = obj.App.Project.Datasets;
    items = strings(1, numel(D));
    for k = 1:numel(D)
        items(k) = sprintf("%s (%d channels)", D(k).Name, numel(D(k).ChannelNumbers));
    end
    [k, ok] = ChannelMapperApp.pickFromList(obj.Fig, 'Recording rows from a dataset', items, ...
        'The dataset whose channels (in recording order) are the rows:');
    if ~ok
        return
    end
    d = D(k);
else
    folder = uigetdir('', 'Choose a recording folder');
    figure(obj.Fig);
    if isequal(folder, 0)
        return
    end
    obj.setStatus("Reading " + folder + " ...", false);
    drawnow;
    try
        d = EphysDataset(folder);
    catch ME
        obj.setStatus("Could not read the recording: " + ME.message, true);
        return
    end
end
if isempty(d.ChannelNumbers)
    obj.setStatus("The dataset " + d.Name + " has no channel numbers yet (scan it first).", true);
    return
end
obj.setRows("dataset", d.ChannelNumbers, d.Name);
obj.setStatus(sprintf('Rows from %s: %d channels.', d.Name, numel(d.ChannelNumbers)), false);
end
