function refreshRecentMenu(obj)
%refreshRecentMenu  Rebuild File > Open recent from RecentConfigs.
%   Every entry stays in RecentConfigs, a config that is not there now
%   too: it is listed as "<file> (not found)", gray, and cannot be picked.
%   A config on a share that is not mounted at the moment (or a drive not
%   plugged in) is back in the list as it is again, instead of being
%   dropped for good; the list's limit of eight (addRecentConfig) is what
%   lets an entry go.
if isempty(obj.RecentMenu) || ~isvalid(obj.RecentMenu); return; end
delete(obj.RecentMenu.Children);
r = obj.RecentConfigs;
if isempty(r)
    uimenu(obj.RecentMenu, "Text", "(none)", "Enable", "off");
    return
end
for k = 1:numel(r)
    f = r(k);
    if isfile(f)
        uimenu(obj.RecentMenu, "Text", char(f), "MenuSelectedFcn", @(~,~) openRecent(obj, f));
    else
        uimenu(obj.RecentMenu, "Text", char(f + " (not found)"), "Enable", "off");
    end
end
end


function openRecent(obj, file)
if ~obj.confirmDiscard(); return; end
obj.openConfigFile(file);
end
