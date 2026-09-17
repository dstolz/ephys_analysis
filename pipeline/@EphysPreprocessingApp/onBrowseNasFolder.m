function onBrowseNasFolder(obj, field)
%onBrowseNasFolder  Pick a folder for one of the NAS tab's root fields.
start = field.Value;
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Select folder");
figure(obj.Fig);  % restore focus after modal dialog
if isequal(d, 0); return; end
field.Value = d;
obj.savePreferences();
end
