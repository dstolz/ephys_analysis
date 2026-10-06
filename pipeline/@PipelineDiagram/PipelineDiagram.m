classdef PipelineDiagram
    % PipelineDiagram  Draw a pipeline config as an HTML page: every parameter, or the data flow.
    %   Pure: it reads a config and, for the recording's details, a dataset,
    %   and returns HTML; nothing here touches a window. The pipeline app's
    %   (EphysPipelineApp) Diagram tab shows these pages
    %   (EphysPipelineApp.flowChartHTML / flowOverviewHTML call them), and a
    %   script can write them too:
    %
    %     cfg = EphysPipelineConfig.load("pipeline.json");
    %     html = PipelineDiagram.overview(cfg, []);
    %     writelines(html, "pipeline_overview.html");
    %
    %   Each box carries the name(s) of the app control(s) behind it
    %   (data-nav); in the app a click opens them, in a saved page the boxes
    %   are plain.
    %
    %   See also EphysPipelineApp, EphysPipelineConfig, EphysPipeline.

    methods (Static)
        [html, summary] = detail(cfg, d, opts)
        [html, summary, model] = overview(cfg, d, opts)
        z = zoomFrame(key, initial)
    end
end
