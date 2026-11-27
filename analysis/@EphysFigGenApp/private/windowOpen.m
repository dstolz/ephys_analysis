function tf = windowOpen(obj)
%windowOpen  True while the app's window exists (isvalid(obj) stays true after the window is deleted).
%   What a callback that outlives a Close (a run's progress, a preview's
%   tail) asks before it writes to a control.
tf = isvalid(obj) && ~isempty(obj.Fig) && isvalid(obj.Fig);
end
