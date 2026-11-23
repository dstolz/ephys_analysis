function files = wikiToolScreenshots(outFolder, opts)
%wikiToolScreenshots  Take the wiki's screenshots of the other windows headlessly.
%   FILES = wikiToolScreenshots(OUTFOLDER, Project=P) takes the shots of
%   the windows besides EphysPipelineApp's tabs, over P, a synthetic
%   project wikiScreenshots has run (its Project= folder), and saves each
%   with exportapp (the example figures: as the analysis run wrote them)
%   into OUTFOLDER under the name the wiki's images/ folder uses.
%   FILES = wikiToolScreenshots(OUTFOLDER, Project=P, AnalysisConfig=A)
%   takes them over a project of real recordings instead: P its root, A an
%   analysis config of it (see AnalysisConfig below). "The shown dataset"
%   is the first, or Dataset=.
%     probe-designer.png    ProbeDesignerApp: a generated 2 x 8
%                           multi-column probe, Build pressed (needs the
%                           kilosort Python env for probeinterface)
%     channel-mapper.png    ChannelMapperApp on the bank's saved mapping
%                           H32_A1x32_RHD2132, site 1 selected
%     manifest-viewer.png   ManifestViewerApp on the shown dataset's
%                           manifest (the one beside its recording),
%                           Summary tab
%     analysis-data-tab.png       EphysFigGenApp at 1240x800 on P (or A):
%                           Data tab, the shown dataset active
%     analysis-alignment-tab.png  Alignment tab: Stim onset, grouped by
%                           Depth (A's own alignment)
%     analysis-figures-tab.png    Figures tab: the first figure (Figure=;
%                           the synthetic unit card: a raster over a PSTH)
%                           and its preview of the first unit, the Panels
%                           section (each panel's Position and Size) in
%                           view and Arrange on, a box over each panel
%                           (without the Image Processing Toolbox, the
%                           preview as it is)
%     analysis-export-tab.png     Export tab after Plan and a run of every
%                           figure on the shown dataset (with A, figure
%                           files on, as PNG, when examples are taken)
%     analysis-example-*.png  the PNGs that run wrote, one per Examples
%                           entry: by default the first unit's card
%                           (unit-card), and the dataset's heat map
%                           (heatmap) and unit correlation (corrmap)
%     dataset-browser.png   DatasetBrowser on P (on A's source root), every
%                           dataset ticked: sorted units around Stim onset,
%                           grouped by Depth, after Compute
%     dataset-browser-details.png  its Details window after that Compute
%   The synthetic analysis config is "Synthetic quick look": the default
%   event (the first Stim onset of each trial, -0.2 to 0.8 s), grouped by
%   Depth, the figures unit_card (raster over PSTH), tuning, heatmap,
%   probemap, corrmap (over every epoch) and lfp (a continuous panel), the
%   per-unit figures (unit_card, tuning) on at most six units, PNG figures
%   at 100 dpi. The run writes its figures and report into P (the analysis
%   folders next to the recording), or where A says.
%   Run it with MATLAB R2025a or later under -batch (see README.md here):
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiToolScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_shots\synthetic_ephys')"
%     matlab -batch "addpath('C:\src\ephys_analysis\tools\wiki'); wikiToolScreenshots('C:\temp\shots', Source='C:\temp\src', Project='C:\temp\wiki_real\OFC', AnalysisConfig='C:\temp\wiki_real\OFC_Analysis_Config.json', Dataset='SUBJ-ID-1278_261008_095925', Examples={'analysis-example-unit-card.png=SU_raster_StimOnset_byRespLatency'})"
%
%   Options
%     Project  (required) the synthetic project folder, run by
%              wikiScreenshots; or the root of a project of real recordings
%     AnalysisConfig  an analysis config (.json) of a project of real
%              recordings: the analysis app opens it as it is (its
%              datasets, alignment, figures and export settings), and the
%              dataset browser opens its source root. The run writes where
%              its Export and Report sections say, so give a config of a
%              COPY of the data whose output folders are scratch folders
%     Dataset  name of the shown dataset (default: the first)
%     Figure   id of the figure the Figures tab shows (default: the first)
%     PythonExe  the Python of the kilosort env, for the probe designer
%              (default: EphysPipelineApp.defaultPythonExe's guess)
%     Examples the example figures, as "FILE=ID": FILE the image's name,
%              ID the id of the figure whose first PNG of the run it is
%              (default: unit-card, heatmap and corrmap of the synthetic
%              config). With the default Shots, every one is taken
%     Source   source tree to run (default: this repository); only its
%              pipeline, analysis, vendor and toolboxes folders go on the path
%     Shots    names of the shots to take (default: all, as listed above)
%     Wait     seconds to let a window render before each shot (default 2)
%
%   The apps keep their preferences in a temporary file for the run
%   (AppPrefs.useTemporary), so they start from the defaults and your own
%   preferences are never read or changed. SOURCE must be a commit that
%   has AppPrefs. With the lab database client at hand (a CarasLabDB
%   checkout beside SOURCE, useCarasLabDB) its preferences are temporary
%   too, and the status bars' lamps read "Database: off".
%
%   See also wikiScreenshots, AppPrefs, EphysFigGenApp, exportapp.

arguments
    outFolder (1,1) string
    opts.Project (1,1) string {mustBeFolder}
    opts.AnalysisConfig (1,1) string = ""
    opts.Dataset (1,1) string = ""
    opts.Figure (1,1) string = ""
    opts.PythonExe (1,1) string = ""
    opts.Examples (1,:) string = ["analysis-example-unit-card.png=unit_card" ...
        "analysis-example-heatmap.png=heatmap" "analysis-example-corrmap.png=corrmap"]
    opts.Source (1,1) string = string(fileparts(fileparts(fileparts(mfilename('fullpath')))))
    opts.Shots (1,:) string = defaultShots()
    opts.Wait (1,1) double {mustBeNonnegative} = 2
end

src = opts.Source;
addpath(src);   % addpath_nogit and the root-level functions
for d = ["pipeline" "analysis" "vendor" "toolboxes"]
    if isfolder(fullfile(src, d)); addpath_nogit(fullfile(src, d)); end
end
fprintf('app: %s\n', which('EphysFigGenApp'));
if ~isfolder(outFolder); mkdir(outFolder); end
proj = opts.Project;
real = opts.AnalysisConfig ~= "";
exFile = extractBefore(opts.Examples, "=");
exId = extractAfter(opts.Examples, "=");
allShots = isequal(opts.Shots, defaultShots());
files = strings(1, 0);

restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU> the apps start from no preferences; yours are untouched
if LabBridge.available()   % the lab database client (a CarasLabDB checkout beside SOURCE): its settings too
    restoreClientPrefs = labclient.Prefs.useTemporary(); %#ok<NASGU> the lamp reads "Database: off"
end

% The designer and the mapper open from the pipeline app (its Python
% runs probeinterface, its probe folder takes what they save).
if want("probe-designer.png") || want("channel-mapper.png")
    app = EphysPipelineApp;
    closeApp = onCleanup(@() delete(app.Fig));
    if opts.PythonExe ~= ""
        app.PythonExeField.Value = char(opts.PythonExe);
    elseif string(app.PythonExeField.Value) == ""
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
    pat = "*_manifest.json";
    if opts.Dataset ~= ""; pat = opts.Dataset + "_manifest.json"; end
    M = dir(fullfile(proj, '*', '*', pat));
    M = M(~endsWith({M.name}, 'session_manifest.json'));
    % The manifest beside the recording (its folder its own), not a copy
    % among the outputs (the copy for the analysis app's)
    k = find(arrayfun(@(m) besideRecording(fullfile(m.folder, m.name)), M), 1);
    if isempty(k); k = 1; end
    v = ManifestViewerApp(fullfile(M(k).folder, M(k).name));
    shot(v.Fig, "manifest-viewer.png");
    delete(v);
end

analysisShots = ["analysis-data-tab.png" "analysis-alignment-tab.png" "analysis-figures-tab.png" "analysis-export-tab.png"];
wantEx = arrayfun(@(f) want(f) || allShots, exFile);
if any(ismember(analysisShots, opts.Shots)) || any(wantEx)
    if real
        a = EphysFigGenApp(opts.AnalysisConfig);    % the config as it is: its datasets, scanned
    else
        a = EphysFigGenApp(proj);    % a new config over the project, scanned
    end
    closeAnalysis = onCleanup(@() delete(a.Fig));
    a.Fig.Position = [40 40 1240 800];
    if ~real
        cfg = a.gatherConfig();
        cfg.Name = "Synthetic quick look";
        cfg.Defaults.Selection.groupBy = "Depth";
        cfg.Export.Formats = "png";
        cfg.Export.Dpi = 100;
        T = EphysAnalysisConfig.figureTemplates();
        ids = struct('rasterPsth', "unit_card", 'tuning', "tuning", 'heatmap', "heatmap", 'probemap', "probemap", ...
            'corrmap', "corrmap", 'continuous', "lfp");
        for t = string(fieldnames(ids)).'
            f = T.Figure{T.Template == t};
            f.id = ids.(t);
            if t == "corrmap"
                f.selection = trialSelection();   % over all epochs: a Depth group of two epochs has no correlation
            end
            cfg = cfg.addFigure(f);
            if ismember(t, ["rasterPsth" "tuning"])   % drawn per unit (the heat map, probe map and corrmap: once for the dataset)
                cfg.Figures(end).observe.units.maxUnits = 6;   % a few units' pages
            end
        end
        a.applyConfig(cfg);
    elseif any(wantEx)
        % The example images are the run's figure files: written, as PNG
        cfg = a.gatherConfig();
        if ~cfg.Export.Enabled || ~ismember("png", cfg.Export.Formats)
            cfg.Export.Enabled = true;
            cfg.Export.Formats = unique([reshape(string(cfg.Export.Formats), 1, []) "png"], 'stable');
            a.applyConfig(cfg);
        end
    end
    ds = 1;
    if opts.Dataset ~= ""
        ds = find(a.Runner.Names == opts.Dataset, 1);
        assert(~isempty(ds), "wikiToolScreenshots:NoDataset", "The analysis app has no dataset %s.", opts.Dataset);
    end
    a.selectDataset(ds);

    a.selectTab(a.TabData);
    shot(a.Fig, "analysis-data-tab.png");
    a.selectTab(a.TabAlign);
    shot(a.Fig, "analysis-alignment-tab.png");
    a.selectTab(a.TabFigures);
    fk = 1;
    if opts.Figure ~= ""
        fk = find([a.gatherConfig().Figures.id] == opts.Figure, 1);
        assert(~isempty(fk), "wikiToolScreenshots:NoFigure", "The analysis config has no figure %s.", opts.Figure);
    end
    a.onFigureSelected(fk);
    a.refreshFigureObservations();
    a.refreshFigurePreview(Force=true);
    a.gotoFigureSection("arrangement");   % the Layout section: New panel..., the Page (size, Boxes mean, Padding), the app preferences
    if license('test', 'Image_Toolbox')   % Arrange needs it
        a.FigureArrangeButton.Value = true;
        a.onArrangeToggled();             % a box over each panel
    end
    drawnow;
    shot(a.Fig, "analysis-figures-tab.png");
    if a.FigureArrange
        a.FigureArrangeButton.Value = false;
        a.onArrangeToggled();
    end
    if want("analysis-export-tab.png") || any(wantEx)
        a.selectTab(a.TabExport);
        a.onPlan();
        a.onRunExport(Datasets=ds);
        shot(a.Fig, "analysis-export-tab.png");
        fprintf('figures: %s\n', a.LastExportFolder);
        for k = find(wantEx)
            F = dir(fullfile(a.LastExportFolder, "*_" + exId(k) + "*.png"));
            if isempty(F)
                fprintf('no PNG of figure %s for %s\n', exId(k), exFile(k));
                continue
            end
            copyfile(fullfile(F(1).folder, F(1).name), fullfile(outFolder, exFile(k)));
            files(end+1) = fullfile(outFolder, exFile(k)); %#ok<AGROW>
            fprintf('wrote %s (from %s)\n', files(end), F(1).name);
        end
    end
end

if want("dataset-browser.png") || want("dataset-browser-details.png")
    if real
        A = EphysAnalysisConfig.load(opts.AnalysisConfig);
        B = DatasetBrowser(A.Source.Root, NamePattern=A.Source.NamePattern, Splash=false, Workers=0);
    else
        B = DatasetBrowser(proj, Splash=false, Workers=0);   % no saved state: the scan ticks every dataset
    end
    closeBrowser = onCleanup(@() delete(B));
    S = B.Settings;
    S.ref = eventRef(line="Stim");
    S.selection.groupBy = "Depth";
    B.Settings = S;
    B.compute();
    shot(B.Fig, "dataset-browser.png");
    if want("dataset-browser-details.png")
        w = B.showDetails();
        if ~isempty(w); shot(w, "dataset-browser-details.png"); end
    end
    clear closeBrowser
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


function tf = besideRecording(f)
%besideRecording  The manifest F names its own folder as the recording's.
try
    m = jsondecode(fileread(f));
    tf = isfield(m, 'folder') && strcmpi(string(m.folder), string(fileparts(f)));
catch
    tf = false;
end
end


function s = defaultShots()
%defaultShots  Every shot but the example figures (those Examples names, all taken with these).
s = ["probe-designer.png" "channel-mapper.png" "manifest-viewer.png" ...
    "analysis-data-tab.png" "analysis-alignment-tab.png" "analysis-figures-tab.png" "analysis-export-tab.png" ...
    "dataset-browser.png" "dataset-browser-details.png"];
end
