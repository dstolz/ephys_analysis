function onPreviewPage(obj, step)
%onPreviewPage  Show the previous (-1) or next (+1) page of the preview.
%   A preview of every page (Ctrl+click on Preview) only draws it; one
%   computed for its page alone (R.page) computes the new page.
R = obj.PreviewResult;
if isempty(R); return; end
p = obj.PreviewPage + step;
if p < 1 || p > obj.PreviewPages; return; end
obj.PreviewPage = p;
if isfield(R, 'page')
    obj.refreshPreview(Force=true);
    return
end
spec = obj.Config.plotFor(obj.SelectedPlot);
obj.Runner.renderPlotFigures(R, spec, Target=obj.PreviewPanel, Page=p, ...
    OnRemember=@(rules) obj.rememberAesthetics(spec.id, rules));
obj.PrevPageButton.Enable = matlab.lang.OnOffSwitchState(p > 1);
obj.NextPageButton.Enable = matlab.lang.OnOffSwitchState(p < obj.PreviewPages);
obj.PageLabel.Text = sprintf("page %d of %d", p, obj.PreviewPages);
end
