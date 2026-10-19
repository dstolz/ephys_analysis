function test_copyFigureSettings()
%test_copyFigureSettings  Verification suite for copying a figure's settings onto another figure.
%   figureSettingParts: the parts (observe, alignment, arrangement,
%   style, looks, sessions), each with its fields, label and
%   description. copyFigureSettings: each part alone (its fields copied,
%   the rest and the id, title and enabled kept), every part by default,
%   two parts (copied in the table's order), a copy that validates, an
%   unknown part (copyFigureSettings:BadPart).
%
%   Usage:  test_copyFigureSettings

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

nPass = 0; nFail = 0;
    function check(cond, msg)
        if cond
            nPass = nPass + 1;
            fprintf('  PASS: %s\n', msg);
        else
            nFail = nFail + 1;
            fprintf(2, '  FAIL: %s\n', msg);
            LegacySuiteTest.checkFailed(msg);   % one failure per check in run_all_tests' report
        end
    end
    function id = errorId(fcn)
        id = '';
        try
            fcn();
        catch ME
            id = ME.identifier;
        end
    end

fprintf('\n== 1. figureSettingParts, copyFigureSettings ==\n');
T = figureSettingParts();
check(isequal(T.Part.', ["observe" "alignment" "arrangement" "style" "looks" "sessions"]) ...
    && isequal(T.Fields{T.Part == "alignment"}, ["ref" "window" "selection"]) && isequal(T.Fields{T.Part == "arrangement"}, ["grid" "panels"]) ...
    && isequal(T.Fields{T.Part == "looks"}, "aesthetics") && isequal(T.Fields{T.Part == "sessions"}, "sessions") ...
    && all(T.Label ~= "") && all(T.Description ~= ""), ...
    'figureSettingParts: observe, alignment (ref, window, selection), arrangement (grid, panels), style, looks, sessions');
fc = EphysAnalysisConfig();
[fc, idA] = fc.addFigure("rasterPsth", Id="a");
[fc, idB] = fc.addFigure("heatmap", Id="b");
B = fc.Figures(2);
B.title = "B's";
B.enabled = false;
B.observe.kind = "dataset";
B.observe.units.maxUnits = 3;
B.ref = EphysAnalysisConfig.defaults("EventRef");
B.ref.line = "Stim";
B.selection = EphysAnalysisConfig.defaults("TrialSelection");
B.selection.groupBy = "Depth";
B.style.FontSize = 14;
B.sessions.series = "all";   % its sessions block differs, so the "sessions" part shows
B.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
fc.Figures(2) = B;
B = fc.Figures(2);
A0 = fc.Figures(1);
parts = T.Part.';
for i = 1:numel(parts)
    [A, copied] = copyFigureSettings(A0, B, parts(i));
    fs = T.Fields{i};
    same = all(arrayfun(@(f) isequaln(A.(f), B.(f)), fs));
    rest = setdiff(string(fieldnames(A0)).', [fs "id" "title" "enabled"]);
    kept = all(arrayfun(@(f) isequaln(A.(f), A0.(f)), rest));
    check(isequal(copied, parts(i)) && same && kept && A.id == idA && A.title == A0.title && A.enabled == A0.enabled, ...
        sprintf('copyFigureSettings "%s": %s from the other figure, the rest and the id, title and enabled kept', parts(i), strjoin(fs, ", ")));
end
[A, copied] = copyFigureSettings(A0, B);
check(isequal(copied, parts) && isequal([A.panels.id], [B.panels.id]) && A.grid.rows == B.grid.rows && A.id == idA ...
    && A.title == A0.title && A.enabled, 'by default every part copies: the heat map''s grid and panels (their ids) onto the raster + PSTH');
[A, copied] = copyFigureSettings(A0, B, ["looks" "alignment"]);
check(isequal(copied, ["alignment" "looks"]) && isstruct(A.ref) && A.ref.line == "Stim" && isscalar(A.aesthetics) ...
    && isequal([A.panels.type], ["raster" "psth"]), 'two parts named copy in the table''s order; the panels stay');
fc.Figures(1) = A;
I = fc.validate(CheckPaths=false);
check(~any(I.Section == "Figures" & I.Severity == "error" & startsWith(I.Field, idA)), 'the figure copied onto validates');
check(strcmp(errorId(@() copyFigureSettings(A0, B, "colors")), 'copyFigureSettings:BadPart') && idB == "b", ...
    'an unknown part raises BadPart');

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_copyFigureSettings:Failures', '%d checks failed.', nFail);
end
end
