function key = synthSourceKey(obj)
%synthSourceKey  Which source the Synthetic tab stands for now: "task", or "<mode>|<dataset folder>".
mode = string(obj.SynthSourceDropDown.Value);
key = mode;
if mode ~= "task"
    d = obj.currentDataset();
    if isempty(d)
        key = mode + "|";
    else
        key = mode + "|" + d.Folder;
    end
end
end
