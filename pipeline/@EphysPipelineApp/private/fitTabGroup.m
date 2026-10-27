function fitTabGroup(obj)
%fitTabGroup  Size the tab group so its header row sits above the host's clip edge.
%   The host (TabHost) is the figure less the tab strip and the status bar
%   rows of the outer grid, which has no padding or spacing. Its size is
%   taken from the figure's, which MATLAB knows at once, not from the
%   host's own: a laid-out size reaches MATLAB only once the window's first
%   render is over, seconds to minutes after it shows, and the tab group
%   sat meanwhile at a new panel's 260 x 221 px in the bottom-left corner.
%   buildUI hangs it on the figure's SizeChangedFcn; the constructor calls
%   it before the window shows (the saved window position set since).
if isempty(obj.Tabs) || ~isvalid(obj.Tabs); return; end
hdr = 26;   % tab header height in R2025a, plus its bottom border
g = obj.TabHost.Parent;
f = obj.Fig.Position;
h = f(4) - g.RowHeight{1} - g.RowHeight{3};
obj.Tabs.Position = [-1 0 f(3) + 2, max(h, 1) + hdr];
end
