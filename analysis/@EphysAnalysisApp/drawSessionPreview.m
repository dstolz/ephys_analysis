function state = drawSessionPreview(obj)
%drawSessionPreview  Draw the session preview's figure and page shown; nothing is computed.
%   STATE = drawSessionPreview(obj) draws SessionPreviewResults(
%   SessionPreviewIndex) -- one figure of the session plot -- at page
%   SessionPreviewPage into SessionPreviewPanel (renderPlotFigures, with its
%   R.spec; a right-click remembers looks through rememberSessionAesthetics)
%   and sets the page buttons. A figure that could not be made (too few
%   sessions or tiles, or an error) shows why. STATE is "drawn", "skipped"
%   or "failed"; the caller sets the badge (refreshSessionPreview,
%   onSessionPreviewPage, onSessionGroupChanged).
res = obj.SessionPreviewResults;
i = obj.SessionPreviewIndex;
if isempty(res) || i < 1 || i > numel(res)
    clearSessionPanel(obj, "Nothing to draw: none of the session plot's datasets were found.");
    state = "skipped";
    return
end
e = res(i);
if e.status ~= "done" || isempty(e.R)
    clearSessionPanel(obj, e.label + " cannot be drawn: " + e.message);
    state = "skipped";
    if e.status == "error"; state = "failed"; end
    return
end
R = e.R;
spec = R.spec;
id = string(spec.id);
obj.SessionPreviewPages = plotPageCount(R, spec);
obj.SessionPreviewPage = min(max(obj.SessionPreviewPage, 1), obj.SessionPreviewPages);
try
    obj.Runner.renderPlotFigures(R, spec, Target=obj.SessionPreviewPanel, Page=obj.SessionPreviewPage, ...
        OnRemember=@(rules) obj.rememberSessionAesthetics(id, rules));
catch ME
    clearSessionPanel(obj, id + " could not be drawn: " + string(ME.message));
    obj.log(id + " session preview could not be drawn: " + string(ME.message));
    state = "failed";
    return
end
syncSessionPages(obj);
state = "drawn";
end
