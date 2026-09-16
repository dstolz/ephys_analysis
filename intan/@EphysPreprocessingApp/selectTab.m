function selectTab(obj, tab)
%selectTab  Switch to TAB from the tab strip or from code.
%   Setting obj.Tabs.SelectedTab from code does not fire the tab group's
%   SelectionChangedFcn; this does, and keeps the tab strip underline in step.
if obj.Tabs.SelectedTab == tab
    obj.syncTabStrip();
    return
end
obj.Tabs.SelectedTab = tab;
obj.onTabChanged();
end
