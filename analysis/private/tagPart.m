function h = tagPart(h, role, group, tile)
%tagPart  Name what a renderer drew, for remembered aesthetics (PlotAesthetics).
%   H = tagPart(H, ROLE) sets the Tag of the graphics objects H to ROLE (one
%   of PlotAesthetics.roles) and returns H, so it can wrap the call that
%   draws them. tagPart(H, ROLE, GROUP) also records the group, series or
%   channel label they draw; tagPart(AX, ROLE, "", TILE) names an axes'
%   tile (its unit or channel) for the aesthetics editor's list. The rules
%   renderPlot applies find components by role and group.
arguments
    h
    role (1,1) string
    group (1,1) string = ""
    tile (1,1) string = ""
end
ok = h(isgraphics(h));
if isempty(ok); return; end
set(ok, 'Tag', char(role));
for k = 1:numel(ok)
    if group ~= ""; setappdata(ok(k), 'PlotGroup', group); end
    if tile ~= ""; setappdata(ok(k), 'PlotTile', tile); end
end
end
