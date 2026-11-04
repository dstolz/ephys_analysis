function selectTab(obj, tab)
%selectTab  Switch to TAB from code (setting SelectedTab fires no callback; this does).
obj.Tabs.SelectedTab = tab;
obj.onTabChanged();
end
