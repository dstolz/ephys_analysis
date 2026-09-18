function onPreviewPage(obj, step)
%onPreviewPage  Show the previous (-1) or next (+1) page of the preview (no recompute).
R = obj.PreviewResult;
if isempty(R); return; end
p = obj.PreviewPage + step;
if p < 1 || p > obj.PreviewPages; return; end
obj.PreviewPage = p;
spec = obj.Config.plotFor(obj.SelectedPlot);
obj.Runner.renderPlotFigures(R, spec, Target=obj.PreviewPanel, Page=p);
obj.PrevPageButton.Enable = matlab.lang.OnOffSwitchState(p > 1);
obj.NextPageButton.Enable = matlab.lang.OnOffSwitchState(p < obj.PreviewPages);
obj.PageLabel.Text = sprintf("page %d of %d", p, obj.PreviewPages);
end
