function onEditEntry(obj, kind)
%onEditEntry  Open the entry editor on the selected probe design, package or headstage.
%   Saving under the same name replaces the entry (after asking); under
%   another name it adds a copy.
switch kind
    case "probe"
        id = obj.ProbeId;
    case "package"
        id = obj.PackageId;
    case "headstage"
        id = obj.HeadstageId;
    otherwise
        error('ChannelMapperApp:BadKind', 'Edit a probe, a package or a headstage.');
end
if id == "" || ~obj.Bank.has(id)
    obj.setStatus("Choose a " + kind + " first.", true);
    return
end
obj.onNewEntry(kind, obj.Bank.get(id));
end
