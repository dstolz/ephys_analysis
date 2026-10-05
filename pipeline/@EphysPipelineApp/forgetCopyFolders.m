function forgetCopyFolders(obj, field, folders)
%forgetCopyFolders  Remove FOLDERS from the list of a Copy tab root or destination box.
%   Only the list changes: FIELD keeps showing what it shows (entering
%   that folder again lists it again) and no folder on disk is touched.
%   The lists are saved at once.
%
%   See also rememberCopyFolder, onForgetCopyFolders.
shown = field.Value;
items = string(field.Items);
field.Items = cellstr(items(~ismember(items, string(folders))));
field.Value = shown;   % a new list moves a value it no longer holds to its first entry
obj.savePreferences();
end
