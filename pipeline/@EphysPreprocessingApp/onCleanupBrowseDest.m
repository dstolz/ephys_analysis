function onCleanupBrowseDest(obj)
%onCleanupBrowseDest  Pick the folder the Clean up tab moves removed files into.
start = string(obj.CleanupDestField.Value);
if start == "" || ~isfolder(start); start = string(pwd); end
p = uigetdir(char(start), "Move removed files into");
figure(obj.Fig);   % uigetdir can leave the app behind other windows
if isequal(p, 0); return; end
obj.CleanupDestField.Value = p;
end
