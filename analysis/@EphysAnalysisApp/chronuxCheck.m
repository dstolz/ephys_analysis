function chronuxCheck(obj)
%chronuxCheck  The Chronux analysis' checkpoint: let callbacks (Cancel) run, and stop when asked.
%   Throws EphysAnalysisApp:ChronuxCanceled once onCancelChronux was pressed.
drawnow limitrate;
if ~isvalid(obj) || obj.ChronuxCancelRequested
    error('EphysAnalysisApp:ChronuxCanceled', 'The Chronux analysis was canceled.');
end
end
