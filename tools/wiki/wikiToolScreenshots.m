function files = wikiToolScreenshots(outFolder, opts)
%wikiToolScreenshots  Take the wiki's screenshots of the other windows headlessly.
%   FILES = wikiToolScreenshots(OUTFOLDER, Project=P) takes the shots of
%   the windows besides EphysPipelineApp's tabs, over P, a synthetic
%   project wikiScreenshots has run (its Project= folder), and saves each
%   with exportapp (the example figures: as the analysis run wrote them)
%   into OUTFOLDER under the name the wiki's images/ folder uses:
%     probe-designer.png    ProbeDesignerApp: a generated 2 x 8
%                           multi-column probe, Build pressed (needs the
%                           kilosort Python env for probeinterface)
%     channel-mapper.png    ChannelMapperApp on the bank's saved mapping
%                           H32_A1x32_RHD2132, site 1 selected
%     manifest-viewer.png   ManifestViewerApp on the first dataset's
%                           manifest, Summary tab
%     analysis-data-tab.png       EphysAnalysisApp at 1240x800 on P:
%                           Data tab, first dataset active
%     analysis-alignment-tab.png  Alignment tab: Stim onset, grouped by Depth
%     analysis-plots-tab.png      Plots tab: the PSTH and its preview
%     analysis-export-tab.png     Export tab after Plan and a run of every
%                           plot on the first dataset
%     analysis-example-psth.png   the PNGs that run wrote: the PSTH grid,
%     analysis-example-raster.png the rasters and the unit correlation
%     analysis-example-corrmap.png
%   The analysis config is "Synthetic quick look": the default event (the
%   first Stim onset of each trial, -0.2 to 0.8 s), grouped by Depth, one
%   plot of each kind but rate, PNG figures at 100 dpi. The run writes its
%   figures and report into P (the analysis folders next to the recording).
%   Run it with MATLAB R2025a under -batch (see README.md here):
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiToolScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_shots\synthetic_ephys')"
%
%   Options
%     Project  (required) the synthetic project folder, run by wikiScreenshots
%     Source   source tree to run (default: this repository); only its
%              pipeline, analysis, vendor and toolboxes folders go on the path
%     Shots    names of the shots to take (default: all, as listed above)
%     Wait     seconds to let a window render before each shot (default 2)
%
%   The apps keep their preferences in a temporary file for the run
%   (AppPrefs.useTemporary), so they start from the defaults and your own
%   preferences are never read or changed. SOURCE must be a commit that
%   has AppPrefs.
%
%   See also wikiScreenshots, AppPrefs, EphysAnalysisApp, exportapp.

arguments
    outFolder (1,1) string
    opts.Project (1,1) string {mustBeFolder}
    opts.Source (1,1) string = string(fileparts(fileparts(fileparts(mfilename('fullpath')))))
    opts.Shots (1,:) string = ["probe-designer.png" "channel-mapper.png" "manifest-viewer.png" ...
        "analysis-data-tab.png" "analysis-alignment-tab.png" "analysis-plots-tab.png" "analysis-export-tab.png" ...
        "analysis-example-psth.png" "analysis-example-raster.png" "analysis-example-corrmap.png"]
    opts.Wait (1,1) double {mustBeNonnegative} = 2
end

src = opts.Source;
addpath(src);   % addpath_nogit and the root-level functions
for d = ["pipeline" "analysis" "vendor" "toolboxes"]
    if isfolder(fullfile(src, d)); addpath_nogit(fullfile(src, d)); end
end
fprintf('app: %s\n', which('EphysAnalysisApp'));
if ~isfolder(outFolder); mkdir(outFolder); end
proj = opts.Project;
files = strings(1, 0);

restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU> the apps start from no preferences; yours are untouched

% The designer and the mapper open from the pipeline app (its Python
% runs probeinterface, its probe folder takes what they save).
if want("probe-designer.png") || want("channel-mapper.png")
    app = EphysPipelineApp;
    closeApp = onCleanup(@() delete(app.Fig));
    if string(app.PythonExeField.Value) == ""
        app.PythonExeField.Value = char(app.defaultPythonExe());
    end
    if want("probe-designer.png")
        pd = ProbeDesignerApp(app, 16);
        pd.SourceDrop.Value = 'generate';
        pd.SourceDrop.ValueChangedFcn(pd.SourceDrop, []);
        pd.GenTypeDrop.Value = 'Multi-column';
        pd.GenTypeDrop.ValueChangedFcn(pd.GenTypeDrop, []);
        pd.LabelChk.Value = true;
        pd.BuildButton.ButtonPushedFcn(pd.BuildButton, []);
        shot(pd.Fig, "probe-designer.png");
        delete(pd.Fig);
    end
    if want("channel-mapper.png")
        bank = fullfile(src, "pipeline", "hardware");
        m = ChannelMapperApp(app, BankFolder=bank, Mapping=fullfile(bank, "mappings", "H32_A1x32_RHD2132.json"));
        m.select("site", 1);
        shot(m.Fig, "channel-mapper.png");
        delete(m);
    end
    clear closeApp
end

if want("manifest-viewer.png")
    M = dir(fullfile(proj, '*', '*', '*_manifest.json'));
    v = ManifestViewerApp(fullfile(M(1).folder, M(1).name));
    shot(v.Fig, "manifest-viewer.png");
    delete(v);
end

analysisShots = ["analysis-data-tab.png" "analysis-alignment-tab.png" "analysis-plots-tab.png" "analysis-export-tab.png" ...
    "analysis-example-psth.png" "analysis-example-raster.png" "analysis-example-corrmap.png"];
if any(ismember(analysisShots, opts.Shots))
    a = EphysAnalysisApp(proj);    % a new config over the project, scanned
    closeAnalysis = onCleanup(@() delete(a.Fig));
    a.Fig.Position = [40 40 1240 800];
    cfg = a.gatherConfig();
    cfg.Name = "Synthetic quick look";
    cfg.Defaults.Selection.groupBy = "Depth";
    cfg.Export.Formats = "png";
    cfg.Export.Dpi = 100;
    six = struct('maxUnits', 6);   % six tiles fit the 18 x 12 cm page
    cfg = cfg.addPlot(struct('kind', "psth", 'units', six));
    cfg = cfg.addPlot(struct('kind', "raster", 'units', six));
    cfg = cfg.addPlot(struct('kind', "tuning", 'param', "Depth"));
    cfg = cfg.addPlot("heatmap");
    cfg = cfg.addPlot("probemap");
    % Over all epochs: a Depth group of two epochs has no correlation.
    cfg = cfg.addPlot(struct('kind', "corrmap", 'selection', trialSelection()));
    cfg = cfg.addPlot(struct('kind', "evoked", 'source', "LFP"));
    a.applyConfig(cfg);
    a.selectDataset(1);

    a.selectTab(a.TabData);
    shot(a.Fig, "analysis-data-tab.png");
    a.selectTab(a.TabAlign);
    shot(a.Fig, "analysis-alignment-tab.png");
    a.selectTab(a.TabPlots);
    a.onPlotSelected(1);
    a.refreshPreview(Force=true);
    shot(a.Fig, "analysis-plots-tab.png");
    if any(ismember(analysisShots(4:end), opts.Shots))
        a.selectTab(a.TabExport);
        a.onPlan();
        a.onRunExport(Datasets=1);
        shot(a.Fig, "analysis-export-tab.png");
        for k = ["psth" "raster" "corrmap"]
            name = "analysis-example-" + k + ".png";
            if ~want(name); continue; end
            F = dir(fullfile(a.LastExportFolder, "*_" + k + "_1*.png"));
            copyfile(fullfile(F(1).folder, F(1).name), fullfile(outFolder, name));
            files(end+1) = fullfile(outFolder, name); %#ok<AGROW>
            fprintf('wrote %s (from %s)\n', files(end), F(1).name);
        end
    end
end


    function tf = want(name)
        tf = any(opts.Shots == name);
    end

    function shot(fig, name)
        if ~want(name); return; end
        drawnow; pause(opts.Wait); drawnow;
        f = fullfile(outFolder, name);
        exportapp(fig, f);
        files(end+1) = f;
        fprintf('wrote %s\n', f);
    end
end
