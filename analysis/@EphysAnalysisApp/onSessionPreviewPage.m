function onSessionPreviewPage(obj, step)
%onSessionPreviewPage  Show the previous (-1) or next (+1) page of the session preview.
%   Every page was computed (refreshSessionPreview), so this only draws
%   (drawSessionPreview). Page Up and Page Down on the Sessions tab
%   (onKeyPress) call it too.
res = obj.SessionPreviewResults;
if isempty(res) || ismember(obj.SessionPreviewState, ["computing" "drawing"]); return; end
p = obj.SessionPreviewPage + step;
if p < 1 || p > obj.SessionPreviewPages; return; end
obj.SessionPreviewPage = p;
state = obj.drawSessionPreview();
if state ~= "drawn"; obj.setSessionPreviewState(state); end
end
