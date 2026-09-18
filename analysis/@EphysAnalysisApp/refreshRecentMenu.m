function refreshRecentMenu(obj)
%refreshRecentMenu  Rebuild File > Open recent from RecentConfigs (files that still exist).
if isempty(obj.RecentMenu) || ~isvalid(obj.RecentMenu); return; end
delete(obj.RecentMenu.Children);
r = obj.RecentConfigs;
r = r(arrayfun(@isfile, r));
obj.RecentConfigs = r;
if isempty(r)
    uimenu(obj.RecentMenu, "Text", "(none)", "Enable", "off");
    return
end
for k = 1:numel(r)
    f = r(k);
    uimenu(obj.RecentMenu, "Text", char(f), "MenuSelectedFcn", @(~,~) openRecent(obj, f));
end
end


function openRecent(obj, file)
if ~obj.confirmDiscard(); return; end
obj.openConfigFile(file);
end
