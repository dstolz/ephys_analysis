function onSessionGroupChanged(obj, i)
%onSessionGroupChanged  Show figure I of the session preview (the Figure box): a subject's, or a trial group's.
%   Every figure was computed (refreshSessionPreview), so this only draws
%   it, from its first page (drawSessionPreview). A figure that could not
%   be made says why; going back to a drawn one keeps an Out of date badge.
res = obj.SessionPreviewResults;
if isempty(res) || i < 1 || i > numel(res) || ismember(obj.SessionPreviewState, ["computing" "drawing"]); return; end
obj.SessionPreviewIndex = i;
obj.SessionPreviewPage = 1;
if obj.SessionGroupDropDown.Value ~= i; obj.SessionGroupDropDown.Value = i; end
state = obj.drawSessionPreview();
if state ~= "drawn"
    obj.setSessionPreviewState(state);
elseif ismember(obj.SessionPreviewState, ["skipped" "failed"])
    obj.setSessionPreviewState("drawn");
end
end
