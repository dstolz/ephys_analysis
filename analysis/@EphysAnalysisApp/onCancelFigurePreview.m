function onCancelFigurePreview(obj)
%onCancelFigurePreview  Stop the figure the preview is computing, at its next checkpoint.
%   The Cancel button on the busy card over the Figures tab's preview.
%   refreshFigurePreview polls while it computes (Runner.PollFcn), so this
%   runs in the middle of it; computeFigure then throws
%   EphysAnalysisRunner:Canceled at its next checkpoint and the badge says
%   Canceled. A step already under way (reading a signal file) finishes
%   first.
if obj.FigurePreviewState ~= "computing" || isempty(obj.Runner); return; end
obj.Runner.cancel();
try   % the card goes as the drawing starts: it may be gone by now
    card = findobj(obj.FigurePreviewPanel.Children, "flat", "Tag", "previewBusyCard");
    if ~isempty(card) && isvalid(card)
        card.UserData.Cancel.Enable = "off";
        card.UserData.Text.Text = "Canceling ...";
    end
catch
end
end
