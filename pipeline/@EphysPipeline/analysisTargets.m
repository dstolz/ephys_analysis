function T = analysisTargets(obj, acfg, idx)
%analysisTargets  What the Analysis step draws and writes for datasets IDX.
%   T = pipe.analysisTargets(ACFG, IDX), ACFG the analysis config
%   (analysisConfig) and IDX indices into Project.Datasets, has one row per
%   dataset and enabled plot -- Step "analysis:<plot id>", Output the
%   dataset's figure folder (the analysis config's Export.Folder; "" when
%   Analysis.Figures is off) -- and, with Analysis.Report, one row per
%   report: Step "analysis:report", Output its file(s) joined by "; ",
%   Dataset "" and Index 0 for one report over every dataset, else the
%   dataset (Report.PerDataset). Columns: Step, Dataset, Index (into
%   Project.Datasets), Output, Status ("ready", or "error: figure folder" /
%   "error: report folder" when a folder pattern cannot be filled, Note then
%   saying why) and Note (the plot's kind and source and what is written).
%   Made from names alone: nothing is read. plan() lists these rows, and
%   runAnalysis with DryRun.
%
%   See also EphysPipeline.runAnalysis, EphysPipeline.analysisTokens,
%   figureFileName, EphysAnalysisRunner.reportFiles.

arguments
    obj (1,1) EphysPipeline
    acfg (1,1)              % an EphysAnalysisConfig (the analysis module is needed only when the step is used)
    idx (1,:) double
end

A = obj.Config.Analysis;
X = acfg.Export;
ds = obj.Project.Datasets(idx);
ids = acfg.enabledPlots();

Step = strings(0, 1); Dataset = strings(0, 1); Index = zeros(0, 1);
Output = strings(0, 1); Status = strings(0, 1); Note = strings(0, 1);
    function add(step, dataset, index, out, st, note)
        Step(end+1, 1) = step; Dataset(end+1, 1) = dataset; Index(end+1, 1) = index;
        Output(end+1, 1) = out; Status(end+1, 1) = st; Note(end+1, 1) = note;
    end

if A.Figures
    how = "figures " + strjoin(X.Formats, ", ");
elseif A.Report
    how = "drawn for the report only (no figure files)";
else
    how = "drawn only (no figure files, no report)";
end
for k = 1:numel(ds)
    d = ds(k);
    folder = "";
    st = "ready";
    why = "";
    if A.Figures
        try
            folder = figureFileName(X.Folder, obj.analysisTokens(d), Kind="folder");
        catch ME
            st = "error: figure folder";
            why = string(ME.message);
        end
    end
    for id = ids
        spec = acfg.plotFor(id);
        note = spec.kind + " of " + spec.source + "; " + how;
        if why ~= ""; note = why; end
        add("analysis:" + id, d.Name, idx(k), folder, st, note);
    end
end

if A.Report && ~isempty(ds)
    R = acfg.Report;
    fmt = upper(replace(R.Format, "both", "html + pdf"));
    if R.PerDataset
        for k = 1:numel(ds)
            [files, st, note] = reportOf(acfg, obj.analysisTokens(ds(k)), fmt + " report of this dataset");
            add("analysis:report", ds(k).Name, idx(k), files, st, note);
        end
    else
        [files, st, note] = reportOf(acfg, obj.analysisTokens(ds(1)), ...
            sprintf("%s report over %d dataset(s)", fmt, numel(ds)));
        add("analysis:report", "", 0, files, st, note);
    end
end

T = table(Step, Dataset, Index, Output, Status, Note);
end


function [files, st, note] = reportOf(acfg, tokens, note)
%reportOf  The report file(s) for these folder tokens, or why there are none.
st = "ready";
files = "";
try
    files = strjoin(EphysAnalysisRunner.reportFiles(acfg, tokens), "; ");
catch ME
    st = "error: report folder";
    note = string(ME.message);
end
end
