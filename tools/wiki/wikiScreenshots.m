function files = wikiScreenshots(outFolder, opts)
%wikiScreenshots  Take the wiki's EphysPreprocessingApp screenshots headlessly.
%   FILES = wikiScreenshots(OUTFOLDER) opens the app on a generated
%   synthetic project (createSyntheticProject, "standard" preset) at
%   1240x800, drives it through its own methods and saves each shot with
%   exportapp into OUTFOLDER under the name the wiki's images/ folder uses:
%     app-project-tab.png   Project tab, first dataset active
%     app-trials-clean.png  Trials tab: auto approval, prefetch, a clean
%                           dataset loaded with TrialType labels
%     app-sorting-tab.png   Sorting tab
%     app-export-tab.png    Export tab with the epochs format ticked
%     app-diagram-tab.png   Diagram tab
%     app-run-plan.png      Run tab after Validate + Plan (run diagram and
%                           resource monitor shown)
%     app-run-results.png   Run tab after a full serial run
%     app-cleanup-tab.png   Clean up tab after Preview
%   Run it with MATLAB R2025a under -batch (see README.md here):
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiScreenshots('C:\temp\shots', Source='C:\temp\src')"
%
%   Options
%     Source   source tree to run (default: this repository). Give a
%              git archive snapshot of the commit the wiki documents; only
%              its pipeline, analysis, vendor and toolboxes folders go on
%              the path, so .claude/worktrees copies never shadow the app.
%     Shots    names of the shots to take (default: all, as listed above)
%     Project  folder for the synthetic project (default: a new temp folder)
%     Wait     seconds to let the page render before each shot (default 2;
%              the results shot waits 10x as long). On a busy machine
%              exportapp can capture a stale frame, so run it when no other
%              MATLAB is working
%
%   The EphysPreprocessingApp preferences are backed up first (also to
%   OUTFOLDER/prefs_backup.mat) and restored when the function ends, even
%   on an error. Only a killed MATLAB skips that (kill it if exportapp
%   hangs: it has, now and then); then restoreAppPrefs(OUTFOLDER +
%   "/prefs_backup.mat") puts them back. Never run it next to another
%   app-driving MATLAB (the app's test suite included): both back up and
%   restore the same preferences.
%
%   See also restoreAppPrefs, EphysPreprocessingApp, exportapp.

arguments
    outFolder (1,1) string
    opts.Source (1,1) string = string(fileparts(fileparts(fileparts(mfilename('fullpath')))))
    opts.Shots (1,:) string = ["app-project-tab.png" "app-trials-clean.png" "app-sorting-tab.png" ...
        "app-export-tab.png" "app-diagram-tab.png" "app-run-plan.png" "app-run-results.png" "app-cleanup-tab.png"]
    opts.Project (1,1) string = ""
    opts.Wait (1,1) double {mustBeNonnegative} = 2
end

src = opts.Source;
addpath(src);   % addpath_nogit and the root-level functions
for d = ["pipeline" "analysis" "vendor" "toolboxes"]
    if isfolder(fullfile(src, d)); addpath_nogit(fullfile(src, d)); end
end
fprintf('app: %s\n', which('EphysPreprocessingApp'));
if ~isfolder(outFolder); mkdir(outFolder); end
proj = opts.Project;
if proj == ""
    proj = string(fullfile(tempdir, "wiki_shots_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')), "proj"));
end
files = strings(1, 0);

g = 'EphysPreprocessingApp';
saved = [];
if ispref(g); saved = getpref(g); end
save(fullfile(outFolder, 'prefs_backup.mat'), 'saved');
restore = onCleanup(@() restorePrefs(g, saved));
for p = ["LastConfigFile" "DatasetsColumnOrder" "TrialsParamColumns" "TrialsColumnOrder" "TrialsLabelParams" ...
        "MonitorResources" "ShowRunDiagram" "CleanupOptions" "FigurePosition" "QueueSortingRuns"]
    if ispref(g, p); rmpref(g, p); end
end

app = EphysPreprocessingApp;
closeApp = onCleanup(@() closeIt(app));
app.Fig.Position = [40 40 1240 800];
drawnow;
S = app.createSyntheticProject(proj, Preset="standard", Overwrite=true);
for T = S.datasets   % approve each dataset's pairing with the cuts its scenario needs
    c = T.expectedCuts;
    if any(c.trials) || any(c.intervals)
        d = app.Project.dataset(T.name);
        P = d.pairTrials(Cuts=c, Warn=false);
        d.setTrialPairing(P, "approved");
    end
end
app.refreshDatasetsTable();
app.selectDataset(1);
app.TrialsAutoApproveCheckBox.Value = true;
app.onTrialsSettingsChanged();
app.ExpEpochsCheckBox.Value = true;
app.ExpEpochsCheckBox.ValueChangedFcn(app.ExpEpochsCheckBox, []);

app.selectTab(app.TabProject);
shot("app-project-tab.png", 1);

if want("app-trials-clean.png")
    app.selectTab(app.TabTrials);
    app.onSelectDatasets("all");
    app.onTrialsPrefetch();
    app.onSelectDatasets("none");
    app.selectDataset(1);
    app.onTrialsLoad("recorded");
    app.onTrialsPlotMenu();
    item = findobj(app.TrialsLabelsMenu, 'Text', 'TrialType');
    if ~isempty(item); item(1).MenuSelectedFcn(item(1), []); end
    shot("app-trials-clean.png", 1);
end

app.selectTab(app.TabSorting);
shot("app-sorting-tab.png", 1);
app.selectTab(app.TabExport);
shot("app-export-tab.png", 1);
app.selectTab(app.TabFlow);
shot("app-diagram-tab.png", 2.5);

if want("app-run-plan.png") || want("app-run-results.png")
    app.RunParallelCheckBox.Value = false;   % a serial run
    app.onParallelControlsChanged();
    app.selectTab(app.TabRun);
    app.RunDiagramCheckBox.Value = true;
    app.onRunDiagramToggled();
    app.RunMonitorCheckBox.Value = true;
    app.onResourceMonitorToggled();
    waitSample(30);
    app.onValidate();
    app.onPlan();
    waitSample(5);
    shot("app-run-plan.png", 2);
    if want("app-run-results.png")
        t0 = tic;
        app.runPipeline();
        fprintf('run: %s (%.0f s)\n', app.RunStepLabel.Text, toc(t0));
        waitSample(5);
        % Freeze the panel on its last sample: exportapp has hung while the
        % monitor's 2 s timer kept updating the page.
        app.stopResourceMonitor();
        shot("app-run-results.png", 10);
    end
    app.RunMonitorCheckBox.Value = false;
    app.onResourceMonitorToggled();
end

if want("app-cleanup-tab.png")
    app.selectTab(app.TabCleanup);
    app.onCleanupPreview();
    shot("app-cleanup-tab.png", 1);
end


    function tf = want(name)
        tf = any(opts.Shots == name);
    end

    function shot(name, waitFactor)
        if ~want(name); return; end
        drawnow; pause(opts.Wait * waitFactor); drawnow;
        f = fullfile(outFolder, name);
        exportapp(app.Fig, f);
        files(end+1) = f;
        fprintf('wrote %s\n', f);
    end

    function waitSample(tmax)
        %waitSample  Until the resource monitor has shown a sample (or TMAX s).
        t0 = tic;
        while toc(t0) < tmax && ~startsWith(string(app.RunMonitorNote.Text), "Sampled every")
            pause(0.5);
        end
    end
end


function closeIt(app)
try
    if ~isempty(app) && isvalid(app.Fig)
        app.stopKSMonitor();
        app.stopResourceMonitor();
        delete(app.Fig);
    end
catch
end
end


function restorePrefs(g, saved)
try
    if ispref(g); rmpref(g); end
    if isstruct(saved)
        for f = string(fieldnames(saved)).'
            setpref(g, char(f), saved.(f));
        end
    end
    fprintf('preferences %s restored\n', g);
catch ME
    fprintf(2, 'restoring the preferences failed: %s\n', ME.message);
end
end
