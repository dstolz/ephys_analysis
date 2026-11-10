function tf = figureOverEpochs(p)
%figureOverEpochs  A coherence or phase coherence (itpc) panel drawn over time from the event (a coherogram on the aligned time base): a time panel.
%
%   See also renderFigure, renderProbeFigure, FigureDataTips.
o = p.options;
onEpochs = ~isfield(o, 'timeBase') || o.timeBase == "aligned";   % (an itpc panel has no other time base)
tf = ismember(p.type, ["coherence" "itpc"]) && isfield(o, 'overTime') && isequal(o.overTime, true) && onEpochs;
end
