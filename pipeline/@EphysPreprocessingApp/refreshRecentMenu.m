function refreshRecentMenu(obj)
%refreshRecentMenu  Rebuild File > Open recent from RecentConfigs.
if isempty(obj.RecentMenu) || ~isvalid(obj.RecentMenu); return; end
delete(obj.RecentMenu.Children);
r = obj.RecentConfigs;
r = r(arrayfun(@(f) isfile(f), r));
obj.RecentConfigs = r;
if isempty(r)
    uimenu(obj.RecentMenu, "Text", "(none)", "Enable", "off");
    return
end
for k = 1:numel(r)
    uimenu(obj.RecentMenu, "Text", char(r(k)), "MenuSelectedFcn", @(~,~) openRecent(obj, r(k)));
end
end


function openRecent(obj, file)
if ~obj.confirmDiscard(); return; end
obj.openConfigFile(file);
end
