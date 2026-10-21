function h = stackMark(h, offset, scale)
%stackMark  Note on what a stack's row drew how its values map onto the axis (appdata 'StackMap').
%   H = stackMark(H, OFFSET, SCALE) sets appdata 'StackMap' = [OFFSET
%   SCALE] on the graphics objects H (a trace, band, curve or line drawn in
%   a stacked panel's row at OFFSET + SCALE x value: stackLayout) and
%   returns H, so it can wrap the call that draws them. A data tip reads
%   the part's own values back from it (FigureDataTips). In no stack
%   (OFFSET 0, SCALE 1) nothing is set.
%
%   See also stackLayout, stackBaseLines, FigureDataTips.
if offset == 0 && scale == 1; return; end
for o = reshape(h(isgraphics(h)), 1, [])
    setappdata(o, 'StackMap', [offset scale]);
end
end
