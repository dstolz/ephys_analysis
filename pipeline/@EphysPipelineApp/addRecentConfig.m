function addRecentConfig(obj, file)
%addRecentConfig  Put FILE at the top of the recent list and rebuild the menu.
file = string(file);
r = obj.RecentConfigs;
r = r(~strcmpi(r, file));
r = [file, r];
if numel(r) > 8; r = r(1:8); end
obj.RecentConfigs = r;
obj.refreshRecentMenu();
end
