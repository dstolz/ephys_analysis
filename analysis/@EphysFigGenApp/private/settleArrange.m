function settleArrange(obj)
%settleArrange  After Arrange off: the preview Arrange left out of date drawn again as after any edit, when Auto allows it.
%   settleArrange(OBJ) is the one-shot timer onArrangeToggled starts
%   (FigureSettleTimer) when Arrange laid the preview out at places that
%   change its labels (FigureArrangeDirty). Unless Arrange is on again or
%   the preview is no longer out of date, it calls autoFigurePreview: with
%   Auto's slider and limit allowing it, the preview is drawn again (from
%   the runner's cache with no busy card when it holds every step:
%   quickFigurePreview, the panels moved drawn anew, the others kept and
%   dressed anew); else it stays out of date and the status bar says
%   "Arrange off: the preview is out of date ...; press Preview".
%
%   See also EphysFigGenApp.onArrangeToggled, autoFigurePreview, arrangedPreview.
if ~isvalid(obj); return; end
obj.FigureSettleTimer = [];
if obj.FigureArrange || obj.FigurePreviewState ~= "stale"; return; end
try
    obj.autoFigurePreview();
catch ME
    obj.log("The preview could not be drawn after Arrange: " + string(ME.message));
end
if isvalid(obj) && ~obj.FigureArrange && obj.FigurePreviewState == "stale"
    obj.setStatus("Arrange off: the preview is out of date at the panels' new places (over Auto's limit); press Preview (Ctrl+P) to draw the labels again.");
end
end
