function onSetCorners(obj)
%onSetCorners  The Layout section's Set corners (and a box's right-click menu): place the selected panel by two clicks on the preview.
%   Click one corner of the place the panel should take on the preview,
%   then the opposite one: the panel's rect becomes the rect between them
%   (snapped as Arrange snaps), one undo step "Set corners"
%   (startCornerMode "set", cornerClick). Arrange switches on for it; the
%   preview must show the selected figure (else the status bar says so).
%   Escape, or a click off the page, cancels.
%
%   See also EphysFigGenApp.startCornerMode, EphysFigGenApp.cancelArrange.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.SelectedPanel < 1 || obj.SelectedPanel > numel(obj.Config.Figures(k).panels)
    obj.setStatus("Set corners: select a panel first.");
    return
end
obj.startCornerMode("set");
end
