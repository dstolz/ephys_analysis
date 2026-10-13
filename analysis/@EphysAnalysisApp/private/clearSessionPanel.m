function clearSessionPanel(obj, msg)
%clearSessionPanel  Empty the Sessions tab's preview panel and say MSG there and in its status line.
%   One page then (syncSessionPages).
delete(obj.SessionPreviewPanel.Children);
g = uigridlayout(obj.SessionPreviewPanel, [1 1]);
uilabel(g, "Text", msg, "WordWrap", "on", "HorizontalAlignment", "center", "FontColor", [0.4 0.4 0.4]);
obj.SessionPreviewLabel.Text = msg;
obj.SessionPreviewPages = 1;
obj.SessionPreviewPage = 1;
syncSessionPages(obj);
end
