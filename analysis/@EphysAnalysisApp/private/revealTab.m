function revealTab(obj, tab, hide)
%revealTab  Show a tab's contents the first time the tab shows (the startup leaves them hidden).
%   revealTab(OBJ, TAB) shows TAB's contents when buildUI left them hidden;
%   later calls do nothing. revealTab(OBJ, TAB, true) hides them (buildUI,
%   for every tab but the one the app opens on).
%
%   MATLAB makes a UI component's view (what draws it on the screen) when
%   the window first lays it out, and the hidden ones wait until they
%   show: with the tabs not shown at the start hidden, the window that
%   shows lays out the Data tab alone, and each other tab is laid out
%   when it is first shown (onTabChanged), the Figures tab, three
%   quarters of the window's components, among them.
if nargin < 3; hide = false; end
if isempty(tab) || ~isvalid(tab); return; end
key = 'EphysAnalysisAppHidden';
if hide
    set(tab.Children, 'Visible', 'off');
    setappdata(tab, key, true);
elseif isappdata(tab, key)
    rmappdata(tab, key);
    set(tab.Children, 'Visible', 'on');
end
end
