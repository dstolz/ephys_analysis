function onCancelSessionPreview(obj)
%onCancelSessionPreview  Stop the session plot the Sessions tab's preview is computing, at its next checkpoint.
%   The Cancel button on its busy card. refreshSessionPreview polls while
%   it computes (Runner.PollFcn), so this runs in the middle of it; the
%   compute then throws EphysAnalysisRunner:Canceled at the next
%   checkpoint (between sessions, or inside one) and the badge says
%   Canceled. The sessions computed so far stay cached.
if obj.SessionPreviewState ~= "computing" || isempty(obj.Runner); return; end
obj.Runner.cancel();
card = findobj(obj.SessionPreviewPanel.Children, "flat", "Tag", "previewBusyCard");
if ~isempty(card)
    card.UserData.Cancel.Enable = "off";
    card.UserData.Text.Text = "Canceling ...";
end
end
