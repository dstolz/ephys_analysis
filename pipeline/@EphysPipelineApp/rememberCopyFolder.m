function rememberCopyFolder(obj, field)
%rememberCopyFolder  Put the folder a Copy tab root or destination box shows at the top of its list.
%   FIELD is one of the Copy tab's editable drop-downs (the ePsych root, the
%   recording roots, the destination). Its list holds the folders last
%   entered in it, typed, picked or browsed to, newest first and at most
%   10. A folder already listed moves up instead of repeating, whatever its
%   case, slashes or trailing separator (the Recording roots box lists whole
%   ";" lists, compared root by root). The lists are preferences
%   (savePreferences); Forget... removes entries (onForgetCopyFolders).
%
%   See also forgetCopyFolders.
v = strtrim(string(field.Value));
if v == ""; return; end
items = string(field.Items);
items = [v, items(folderKey(items) ~= folderKey(v))];
field.Items = cellstr(items(1:min(end, 10)));
field.Value = char(v);
end


function k = folderKey(v)
%folderKey  One text per folder list, however it was typed.
k = lower(replace(v, "\", "/"));
k = regexprep(k, "\s*;\s*", ";");
k = regexprep(k, "(?<!:)/+(?=;|$)", "");
end
