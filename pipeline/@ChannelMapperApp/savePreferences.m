function savePreferences(obj)
%savePreferences  Remember the window position, the bank folder and the chain.
%   Called when the window closes (onClose), never from delete, so a test
%   that deletes the object leaves the preferences alone.
g = obj.PrefGroup;
if ~isempty(obj.Fig) && isvalid(obj.Fig)
    setpref(g, 'FigurePosition', obj.Fig.Position);
end
setpref(g, 'BankFolder', char(obj.Bank.Folder));
last = struct();
last.probe = char(obj.ProbeId);
last.package = char(obj.PackageId);
last.headstage = char(obj.HeadstageId);
last.count = obj.HeadstageCount;
last.offsets = obj.Offsets;
last.from = cellstr(strsOf(obj.Mates, 'From'));
last.to = cellstr(strsOf(obj.Mates, 'To'));
last.orientation = cellstr(strsOf(obj.Mates, 'Orientation'));
last.mapping = char(obj.MappingName);
setpref(g, 'LastChain', last);
end