function stopSelectTimer(obj)
%stopSelectTimer  The timer fillSelectLater started stopped (it deletes itself); FigureSelectTimer [].
%
%   See also fillSelectLater, finishPendingSelect.
if ~isvalid(obj); return; end
t = obj.FigureSelectTimer;
obj.FigureSelectTimer = [];
if ~isempty(t) && isvalid(t); stop(t); end
end
