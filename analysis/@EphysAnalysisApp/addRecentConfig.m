function addRecentConfig(obj, file)
%addRecentConfig  Put FILE at the top of the recent list and rebuild the menu.
file = string(file);
r = obj.RecentConfigs;
r = [file, r(~strcmpi(r, file))];
obj.RecentConfigs = r(1:min(8, end));
obj.refreshRecentMenu();
end
