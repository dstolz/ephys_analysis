function onLoadMapping(obj)
%onLoadMapping  Choose a mapping from the bank, or a mapping / .chanmap.json file.
M = obj.Bank.list("mapping");
items = strings(1, numel(M));
for k = 1:numel(M)
    items(k) = M(k).Name;
    if M(k).Notes ~= ""
        items(k) = items(k) + "  -  " + extractBefore(M(k).Notes + " ", min(strlength(M(k).Notes) + 1, 80));
    end
end
items(end + 1) = "Open a file (mapping .json or <probe>.chanmap.json)...";
[k, ok] = ChannelMapperApp.pickFromList(obj.Fig, 'Open mapping', items, 'Saved mappings in the bank:');
if ~ok
    return
end
try
    if k <= numel(M)
        obj.loadMapping(M(k).Id);
    else
        [f, p] = uigetfile({'*.json', 'Mapping or sidecar (*.json)'}, 'Open a mapping');
        figure(obj.Fig);
        if isequal(f, 0)
            return
        end
        obj.loadMapping(fullfile(p, f));
    end
catch ME
    obj.setStatus("Could not open it: " + ME.message, true);
    uialert(obj.Fig, ME.message, 'Open mapping');
end
end
