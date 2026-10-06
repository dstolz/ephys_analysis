function refreshAnalysisSummary(obj)
%refreshAnalysisSummary  Show what the Analysis step's config holds (Analysis tab).
%   Reads the analysis config the tab names (EphysPipelineConfig.
%   loadAnalysisConfig) and shows its name and description, the event its
%   plots align to and their window, where the figure files and the report
%   go (or that this pipeline does not write them), and what its own checks
%   find (EphysAnalysisConfig.validate without its source or paths, which
%   the step replaces and the Run tab's Validate checks); the plots table
%   lists its plots. When it cannot be read, the reason is shown instead.
if isempty(obj.AnaSummaryLabel) || ~isvalid(obj.AnaSummaryLabel); return; end
obj.AnaPlotsTable.Data = {};
file = string(strtrim(obj.AnaConfigField.Value));
if file == ""
    obj.AnaSummaryLabel.Text = "No analysis config chosen. Make one with Open in the analysis app, save it " + ...
        "there, then choose it here.";
    obj.AnaSummaryLabel.FontColor = [0.4 0.4 0.4];
    return
end
[acfg, msg] = EphysPipelineConfig.loadAnalysisConfig(file);
if isempty(acfg)
    obj.AnaSummaryLabel.Text = msg;
    obj.AnaSummaryLabel.FontColor = [0.75 0.1 0.1];
    return
end

name = """" + acfg.Name + """";
if acfg.Description ~= ""; name = name + ": " + acfg.Description; end
ref = acfg.Defaults.EventRef;
win = acfg.Defaults.Window;
lines = [name, sprintf("Aligned to the %s of %s, window %g to %g s (a plot may set its own).", ...
    ref.edge, ref.line, win.pre, win.post)];
X = acfg.Export;
if obj.AnaFiguresCheckBox.Value
    lines(end+1) = "Figures: " + strjoin(X.Formats, ", ") + " in " + X.Folder + ", named " + X.FilenamePattern + ".";
else
    lines(end+1) = "Figures: not written (Write the figure files is off).";
end
R = acfg.Report;
if obj.AnaReportCheckBox.Value
    lines(end+1) = "Report: " + upper(replace(R.Format, "both", "html + pdf")) + " in " + ...
        fullfile(R.Folder, R.FileName) + ternary(R.PerDataset, ", one per dataset.", ", one over every selected dataset.");
else
    lines(end+1) = "Report: not written (Write the report is off).";
end
issues = acfg.validate(CheckPaths=false);
issues = issues(issues.Section ~= "Source", :);
nErr = nnz(issues.Severity == "error");
nWarn = height(issues) - nErr;
if height(issues) == 0
    lines(end+1) = "Checks: nothing found.";
    obj.AnaSummaryLabel.FontColor = [0.15 0.15 0.15];
else
    first = issues(find(issues.Severity == "error", 1), :);
    if isempty(first); first = issues(1, :); end
    lines(end+1) = sprintf("Checks: %d error(s), %d warning(s). %s.%s: %s", nErr, nWarn, ...
        first.Section, first.Field, first.Message);
    obj.AnaSummaryLabel.FontColor = ternary(nErr > 0, [0.75 0.1 0.1], [0.6 0.4 0]);
end
obj.AnaSummaryLabel.Text = strjoin(lines, newline);

P = acfg.Plots;
if ~isempty(P)
    obj.AnaPlotsTable.Data = table(reshape([P.id], [], 1), reshape([P.kind], [], 1), reshape([P.source], [], 1), ...
        reshape([P.enabled], [], 1), 'VariableNames', {'Plot', 'Kind', 'Source', 'On'});
end
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
