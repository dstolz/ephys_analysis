function onBrowseCopyFolder(obj, field)
%onBrowseCopyFolder  Pick a folder for one of the Copy tab's root fields.
%   The Recording roots field is a list: the folder picked is added to it.
isList = field == obj.CopyRecordingRootsField;
roots = string(field.Value);
if isList
    roots = obj.copyRecordingRoots();
end
start = "";
if ~isempty(roots); start = roots(1); end
if start == "" || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Select folder");
figure(obj.Fig);  % restore focus after modal dialog
if isequal(d, 0); return; end
if isList && ~any(strcmpi(roots, d))
    field.Value = char(strjoin([roots, string(d)], "; "));
elseif ~isList
    field.Value = d;
end
obj.savePreferences();
end
