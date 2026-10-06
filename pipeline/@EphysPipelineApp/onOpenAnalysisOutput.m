function onOpenAnalysisOutput(obj, what)
%onOpenAnalysisOutput  Open what the Analysis step writes: its report or a figure folder.
%   onOpenAnalysisOutput(OBJ, "report") opens the active dataset's report
%   (Report.PerDataset), else the one over every selected dataset: its
%   .html in the browser, else its .pdf. onOpenAnalysisOutput(OBJ,
%   "figures") shows the active dataset's figure folder, else the first
%   selected dataset's that exists. The places come from the step's plan
%   (EphysPipeline.analysisTargets), so they are where the next run writes
%   too; the status line says when nothing is there yet.
%
%   See also EphysPipelineApp.buildAnalysisTab, openInSystem.
arguments
    obj (1,1) EphysPipelineApp
    what (1,1) string {mustBeMember(what, ["report" "figures"])}
end
title = "Open " + what;
try
    pipe = obj.buildPipeline();
    [acfg, msg] = pipe.analysisConfig();
    if isempty(acfg); error('EphysPipelineApp:NoAnalysisConfig', '%s', msg); end
    T = pipe.analysisTargets(acfg, pipe.DatasetIdx);
catch ME
    uialert(obj.Fig, string(ME.message), title);
    return
end
if what == "report"
    rows = T(T.Step == "analysis:report", :);
else
    rows = T(startsWith(T.Step, "analysis:") & T.Step ~= "analysis:report", :);
end
d = obj.currentDataset();
if ~isempty(d)
    mine = rows.Dataset == d.Name;
    rows = [rows(mine, :); rows(~mine, :)];   % the active dataset's first
end
places = strings(1, 0);
for r = 1:height(rows)
    places = [places, reshape(strtrim(split(rows.Output(r), ";")), 1, [])]; %#ok<AGROW>
end
places = unique(places(places ~= ""), 'stable');
if isempty(places)
    if what == "report"
        obj.setStatus("No report is written: Write the report is off.", "");
    else
        obj.setStatus("No figure files are written: Write the figure files is off.", "");
    end
    return
end
if what == "report"
    places = [places(endsWith(places, ".html")), places(~endsWith(places, ".html"))];
    there = places(arrayfun(@isfile, places));
else
    there = places(arrayfun(@isfolder, places));
end
if isempty(there)
    obj.setStatus("Nothing there yet (run the Analysis step): " + places(1), "");
    return
end
try
    openInSystem(there(1));
    obj.setStatus("Opened " + there(1) + ".", "");
catch ME
    uialert(obj.Fig, string(ME.message), title);
end
end
