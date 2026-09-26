function loadMapping(obj, what)
%loadMapping  Open a saved mapping: a bank mapping id, a mapping .json or a <probe>.chanmap.json.
%   The window takes the mapping's probe, package, headstage (and how
%   many), channel offsets, mates and recording rows, and resolves it.
%   Errors ChannelMapperApp:NoMapping when WHAT is neither,
%   HardwareBank:NotFound when the bank lacks a device it names.
what = string(what);
if isfile(what)
    raw = readJsonFile(what);
    if isfield(raw, 'schema') && string(raw.schema) == ChannelMap.SidecarSchema
        raw = raw.mapping;
        if ~isfield(raw, 'kind'); raw.kind = 'mapping'; end
    end
    e = HardwareBank.normalize(raw, what);
    if e.Kind ~= "mapping"
        error('ChannelMapperApp:NoMapping', '%s is not a mapping or a .chanmap.json file.', what);
    end
elseif obj.Bank.has(what) && obj.Bank.get(what).Kind == "mapping"
    e = obj.Bank.get(what);
else
    error('ChannelMapperApp:NoMapping', 'No mapping "%s" in the bank, and no such file.', what);
end
chain = obj.Bank.chainFromMapping(e);

ids = strings(1, numel(chain.headstages));
for i = 1:numel(chain.headstages)
    ids(i) = chain.headstages(i).Entry.Id;
end
obj.ProbeId = "";
if ~isempty(chain.probe)
    obj.ProbeId = chain.probe.Id;
end
obj.PackageId = chain.package.Id;
obj.HeadstageId = ids(1);
obj.HeadstageCount = numel(ids);
obj.Offsets = [chain.headstages.ChannelOffset];
mates = struct('From', {}, 'To', {}, 'Orientation', {});
for k = 1:numel(chain.mates)
    mates(k) = struct('From', string(chain.mates(k).From), 'To', string(chain.mates(k).To), ...
        'Orientation', string(chain.mates(k).Orientation));
end
obj.Mates = mates;
obj.RowsMode = chain.rowsMode;
obj.ChannelNumbers = double(chain.channelNumbers(:)');
obj.DatasetName = chain.dataset;
obj.MappingName = e.Name;
obj.fillCascade();
obj.refreshMatesTable();
obj.resolve();
if numel(unique(ids)) > 1
    obj.setStatus("Opened " + e.Name + ", but it uses different headstages; this window shows " + ids(1) + " for all of them.", true);
else
    obj.setStatus("Opened the mapping " + e.Name + ".", false);
end
end
