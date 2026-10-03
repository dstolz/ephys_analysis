function [html, summary, model] = flowOverviewHTML(obj)
%flowOverviewHTML  The Diagram's overview: how data flows through the pipeline.
%   [HTML, SUMMARY, MODEL] = app.flowOverviewHTML() is
%   PipelineDiagram.overview of obj.Config and the active dataset (see
%   there for the page and MODEL, the geometry it draws, for tests).
%
%   See also PipelineDiagram, flowChartHTML, onFlowNavigate, flowNavControls.

[html, summary, model] = PipelineDiagram.overview(obj.Config, obj.currentDataset());
end
