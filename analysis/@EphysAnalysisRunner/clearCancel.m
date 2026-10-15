function clearCancel(obj)
%clearCancel  Forget an earlier cancel(), before work that can be canceled starts.
%   run() does this itself; the app's preview calls it before computeFigure.
obj.CancelRequested = false;
end
