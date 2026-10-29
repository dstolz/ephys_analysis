function tf = figureOverEpochs(p)
%figureOverEpochs  A coherence panel drawn over time from the event (a coherogram on the aligned time base): a time panel.
%
%   See also renderFigure, renderProbeFigure.
o = p.options;
tf = p.type == "coherence" && isfield(o, 'overTime') && o.overTime && isfield(o, 'timeBase') && o.timeBase == "aligned";
end
