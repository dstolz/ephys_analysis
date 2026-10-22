function onKeyRelease(obj, evt)
%onKeyRelease  The figure's key releases: Ctrl (Cmd) let go, an edit of the figure editor applies to its figure only again.
%   EVT is the WindowKeyReleaseFcn event (Key, Modifier). onKeyPress notes
%   Ctrl held (CtrlHeld); onConfigChanged opens Apply to figures for an
%   edit made while it is.
if any(ismember(string(evt.Key), ["control" "command"])); obj.CtrlHeld = false; end
end
