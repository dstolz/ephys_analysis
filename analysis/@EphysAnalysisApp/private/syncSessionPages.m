function syncSessionPages(obj)
%syncSessionPages  The Sessions tab's < > buttons and page label, for SessionPreviewPage of SessionPreviewPages.
n = obj.SessionPreviewPages;
p = obj.SessionPreviewPage;
obj.SessionPrevPageButton.Enable = matlab.lang.OnOffSwitchState(p > 1);
obj.SessionNextPageButton.Enable = matlab.lang.OnOffSwitchState(p < n);
if n > 1
    obj.SessionPageLabel.Text = sprintf("page %d of %d", p, n);
else
    obj.SessionPageLabel.Text = "";
end
end
