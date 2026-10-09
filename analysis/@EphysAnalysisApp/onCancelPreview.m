function onCancelPreview(obj)
%onCancelPreview  Stop the plot the preview is computing, at its next checkpoint.
%   The Cancel button on the busy card (and the toolbar's Cancel, onCancelRun).
%   refreshPreview polls while it computes (Runner.PollFcn), so this runs
%   in the middle of it; the compute then throws EphysAnalysisRunner:Canceled
%   at the next checkpoint and refreshPreview shows "Canceled". A step
%   already under way (reading a signal file) finishes first.
if obj.PreviewState ~= "computing" || isempty(obj.Runner); return; end
obj.Runner.cancel();
card = findobj(obj.PreviewPanel.Children, "flat", "Tag", "previewBusyCard");
if ~isempty(card)
    card.UserData.Cancel.Enable = "off";
    card.UserData.Text.Text = "Canceling ...";
end
end
