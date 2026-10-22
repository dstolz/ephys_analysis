function ids = figureBatchPanels(spec)
%figureBatchPanels  The ids of a figure's panels whose y range is shared by every observation of a run (yLimMode "batch").
%   IDS = figureBatchPanels(SPEC) for a figure spec (EphysAnalysisConfig.
%   figureFor, or a Figures entry) is a string row: the panels whose
%   options.yLimMode is "batch" (empty: none). A run of the figure
%   (EphysAnalysisRunner.run, runSessionFigure; the standalone script)
%   measures those panels' y extents over every observation first
%   (figureYExtents, figureBatchYLim) and draws them at the union.
%
%   See also figureYExtents, figureBatchYLim, renderFigure.
ids = strings(1, 0);
if ~isfield(spec, 'panels'); return; end
for k = 1:numel(spec.panels)
    o = spec.panels(k).options;
    if isstruct(o) && isfield(o, 'yLimMode') && string(o.yLimMode) == "batch"
        ids(end+1) = spec.panels(k).id; %#ok<AGROW>
    end
end
end
