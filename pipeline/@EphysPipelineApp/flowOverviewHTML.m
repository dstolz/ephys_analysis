function [html, summary, model] = flowOverviewHTML(obj, opts)
%flowOverviewHTML  The Diagram's overview: how data flows through the pipeline.
%   [HTML, SUMMARY, MODEL] = app.flowOverviewHTML() is
%   PipelineDiagram.overview of obj.Config and the active dataset (see
%   there for the page and MODEL, the geometry it draws, for tests).
%
%   See also PipelineDiagram, flowChartHTML, onFlowNavigate, flowNavControls.

arguments
    obj
    opts.HideUnused (1,:) logical = logical.empty
end
if isempty(opts.HideUnused); opts.HideUnused = obj.hideUnused(); end
[html, summary, model] = PipelineDiagram.overview(obj.Config, obj.currentDataset(), HideUnused=opts.HideUnused);
end
