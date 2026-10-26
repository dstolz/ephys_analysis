function test_EphysAnalysisFigures(opts)
%test_EphysAnalysisFigures  Verification suite for the analysis config's figures.
%   Config sections (1-6): the defaults of Figure / Panel / Layer /
%   Observe; panelTypes, sourceCategories, categoryOf, observeKind,
%   followedData and defaultLayer; addFigure's templates, ids and the
%   data each observes; figureFor's resolution
%   (Defaults, panel overrides, sharesTime, units.source, the observe kind,
%   options completed and re-seeded on a type change); a JSON round trip
%   with every panel type, relative sizes, custom gaps in % and a panel's
%   own size and alignment, an events layer with a sequence,
%   fixed and following layers and "default" sentinels, a cell Figures
%   from jsondecode, unknown fields in LoadWarnings; the grid editors
%   (placePanel in four directions, removePanel, movePanel, figureCells;
%   the gap lists kept sized to the grid, Remove undoing Add);
%   DuplicateFigureId / DuplicatePanelId; every validate rule of the
%   Figures section ("No figure is enabled." when none is), the style's
%   messages (checkStyle); a panel's text note and overlays (defaults, an
%   overlay's panel always "all", a JSON round trip, the validate rules
%   at the panel's fields).
%   Compute (7), on makeAnalysisFixture's "clean" dataset:
%   figureObservations (the filter's units in probe order, a tightened
%   filter, the LFP channels of a continuous figure, one row for a dataset
%   figure); computeFigure of the raster + PSTH figure (the first
%   observation by default, one unit in each layer, the PSTH equal to
%   spikePSTH's, Observation= as a row or a struct); an LFP layer
%   following the unit (its recording channel's column), a fixed AUX layer
%   with aggregate "mean" (R.layerMean) and an AUX layer following the unit
%   (skipped with its reason, in figureSkipReason too); a fixed layer of
%   three units averaged; events as marks (epochEvents) and as a train (a
%   one-unit PSTH peaking at 0 when aligned to its own line); a panel's own
%   window (its epochs, the figure's groups); a channel observation (its
%   column, the MUA column of the same channel, the units on it); a raster sorted by a
%   missing parameter skipped while the PSTH under it is computed; a
%   signal's baseline with no sample in the window skipping its layer;
%   probemap and corrmap as the compute functions give them (unitSummary +
%   probeMapValues, unitCorrelation), waveforms; PollFcn checkpoints
%   and cancel; figureCompute (no runner) equal to computeFigure, its
%   Check=; figureOutputName's names and figureCaption; a rate panel and a
%   tuning panel equal to firingRate's / tuningCurve's of the unit (the
%   tuning parameter from groupBy, else the first numeric one; a series
%   and the waveform inset; a missing parameter skipping the panel); a
%   rate layer of three units' mean (with the waveform inset read); an auROC PSTH equal to spikePSTH's;
%   a stacked PSTH; the waveforms' probe layout (a following layer to
%   ring); one observation faster than spikePSTH over every unit; the
%   first-spike latency (a PSTH with latencyBox keeping the raster's rows,
%   firstSpikeLatency against the unit's own train, the caption);
%   figureCompute's Reuse (the same spec: every step taken again; a look
%   edit: nothing computed; the PSTH's bins: that panel only, as from
%   scratch; another observation: its panels) and the runner's
%   FigureCache (computeFigure Reuse=true; clearSources forgets it).
%   Render (8): figureArrange (the labels' room and exact gaps between
%   rows and columns, px, % and per-gap lists, the presets, rows and
%   columns in exact proportion, spans, a panel's size and alignment in
%   its cell, a note band, a phase strip, the title's and legend's bands);
%   renderFigure's layout (flush with "none", an exact custom gap in px
%   and %, rows 1 : 2, a panel half its cell's width keeping its tick
%   labels, the legend east of the panels, the title over them, laid out
%   again when the figure is resized); a compute and a draw function for every panel type;
%   every panel type drawn by renderFigure into an axes, a uiaxes, a
%   figure, a uipanel and a grid layout, every component tagged with a
%   known role and the tiles named by panel; the title (automatic, and the
%   figure's own with the observation on the top-left panel); the artifact
%   note under it (epochs kept with an artifact period, by panel when the
%   counts differ, Style.ShowArtifactNote off); one time axis
%   down a stack (the window on every time panel, tick labels and "Time
%   (s)" at the bottom only, a panel's own window kept); one legend, each
%   group once; skipped layers' notes; events marks on a raster and as
%   latency lines and a rug on a PSTH; a stacked continuous panel of marks
%   alone; a raster of
%   five blocks keeping every block's name; a raster over a waveforms
%   panel keeping its time axis; a stacked PSTH (rows, the legend's
%   groups once, one group overlaid, a second layer in the rows), an
%   auROC PSTH (0-1, chance line, modulation window, calls; stacked too)
%   and heat map (diverging, 0-1), rate panels (bars, boxes of two
%   layers with the inset's place, size and time span, points), tuning curves (a series, the inset), the waveforms'
%   probe layout with the observed unit framed;
%   Editable, OnRemember and the context's redraw; the editor's colormap;
%   renderFigure Reuse (an edit of two panels draws those again, the
%   third kept with its menu, the drawing as a whole one; a title of the
%   figure's own draws every panel; an edit of text alone -- labels, a
%   panel title, the figure title -- set on the axes drawn, the drawing
%   a whole one's, the data tips and editor context following; InPlaceOnly
%   drawing nothing for a side, a title back to none drawn);
%   one observation drawn in under a second; data tips (FigureDataTips:
%   a PSTH line's rows, a raster tick's trial and group, a heat map cell's
%   and a heat map of trials' tips, a bar's rows, the chosen fields a
%   preference followed on refresh, DataTipFieldsDialog, the time they
%   add); a panel's note (below: in a
%   band of its tile; northeast: in its axes) and overlays (on its own
%   axes), their looks as rules under the figure's own; the first-spike
%   marks on their epochs' ticks (by group, descending with the groups
%   mixed, five blocks; their look and legend entry) and the PSTH's
%   latency box plot (prctile's quartiles, Tukey's whiskers, a band above
%   the traces; stacked, one box per row above its PSTH).
%   Spectral (9): the spectral templates and validate's rules (a coherence
%   panel's two layers, chronuxSettings' errors, a spectrogram's baseline
%   window, a coherogram of spikes and a spectrogram of units valid, a
%   spectrogram of events refused, a range spectrum's window, aggregate
%   "magnitude" where aggregates() offers it), figureFor's
%   shared time; with Chronux on the path (toolboxes/chronux, added for the
%   section; skipped with a note without it) on section 7's fixture: a
%   spectrum of the observed unit's LFP channel and of the unit, a
%   spectrogram, coherences LFP x LFP, spike-field and unit-unit, an AUX
%   magnitude (with the unit, with an LFP column at another rate, as a
%   seed with its axes, its spectrum against one computed here), a
%   spectrogram of the unit and spike coherograms (computed, drawn), the range
%   time base, the drawing (dB, a spectrogram on the raster's time axis,
%   the phase axes, every role known, a coherence in one axes) and the
%   skip reason with Chronux off the path.
%   Session figures (10), on makeAnalysisFixture's two datasets ("clean",
%   "late-start"): figureSessionObservations by site (each session's units
%   on the channel, minSessions) and by a mapping file (writeUnitMapping);
%   a raster + PSTH merged over both sessions (a series per session equal
%   to each session's own PSTH, every epoch), drawn with known roles and
%   "(2 sessions, n epochs)" in its title; series "all" with each session
%   a memberLine; trialGroups "combine" in line styles; a continuous
%   figure by channel; facet "subject" x trialGroups "each"; a probe map
%   skipped (and a validate error, a skip reason); events marks skipped;
%   minSessions per trial group ("each": a group one session holds is
%   skipped at 2, drawn from that session at 1); site matching with session
%   2's unit renamed and split in two on the site (plantUnits).
%   Stacks (11): stackModes (the types that stack, a continuous panel's
%   items), every stacking type's defaults, validate's stack rules and
%   Apply to all panels' (a stack a type does not take is kept); on the
%   "clean" fixture every stacking type drawn (PSTH, continuous by groups
%   and by channels, heat map, tuning; with Chronux the spectrum,
%   spectrogram, coherence and coherogram): a row per group, the first on
%   top, named on the y axis, the groups in the legend, every part a known
%   role, line rows on a yyaxis with a StackMap'd row line each, image
%   rows an image each with its color strip and one color bar; a
%   continuous stack's traces read back through their StackMap. Y limits:
%   yLimMode on every type with yLim (YLimModes, validate, Apply to all
%   panels keeping a "fixed" mode from a panel without limits), the modes
%   on a continuous stack (auto: each row its own scale; rows: one; batch
%   without a range: as rows; fixed and batch: their range per row) and a
%   PSTH's axis, figureBatchYLim's union; a run (EphysAnalysisRunner.run)
%   of a figure with a batch panel: r.BatchYLim the union of every
%   observation's own extent, each page drawn at it, the caption and the
%   standalone script saying so.
%   One edit to other figures (12): figureEditChanges (a panel option,
%   figure settings, nothing for an id, title, place, layer or note text,
%   one field of an own event reference), changeTargets (the panels whose
%   type takes the value, a row per figure for figure settings, the
%   targets that have it already, an alignment from the Defaults),
%   panelTakes' rules (stack, baseline, a type's own option) and
%   applyChanges to the rows picked.
%   Figure size (13): the default size, figureExportSize and newExportFigure (the
%   Export size taller for the rows, an own size in px at the dpi, in and cm),
%   figureSizeConvert, the suggestions and typed sizes (figureSizeParse,
%   figureSizeText), validate's size rules and a JSON round trip.
%   Scale (14), on the "clean" fixture: a raster + PSTH (a boxed note
%   below, an overlay) and a tuning curve drawn at Scale 1.5 into a panel
%   1.5 times the export page: every size of every part (fonts, lines,
%   markers, caps, the labels' fonts) 1.5 times the export's, the plot
%   areas in the same proportion to the page; the scale kept on the root
%   (PlotAesthetics.drawScale), getValue and setValue speaking of the
%   exported sizes; Reuse at a scale the same as a whole drawing.
%
%   The sections run on their own after the setup (TestSections): 1-6, 12 and 13 need
%   no data, 7, 9, 11 and 14 build the "clean" fixture once (fixtureA), 8 needs
%   7's results (declared), 10 builds its own two-dataset fixture.
%
%   Usage:  test_EphysAnalysisFigures
%           test_EphysAnalysisFigures(Sections="8")          % 8 pulls 7 in
%           run_all_tests({'test_EphysAnalysisFigures:1,2,3,4,5,6'})

arguments
    opts.Sections (1,:) string = string.empty(1, 0)
end

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
addpath(here);
addpath(fullfile(repo, 'pipeline'));
addpath(repo);

root = fullfile(tempdir, sprintf('AnaFigures_test_%s', datestr(now, 'yyyymmdd_HHMMSSFFF'))); %#ok<TNOW1,DATST>
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's'));

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
    function tf = has(cfg, field, sev)
        % a Figures issue with exactly this Field and Severity
        I = cfg.validate(CheckPaths=false);
        tf = any(I.Section == "Figures" & I.Field == field & I.Severity == sev);
    end
    function I = figIssues(cfg)
        I = cfg.validate(CheckPaths=false);
        I = I(I.Section == "Figures", :);
    end

% what a section needs from the data: makeAnalysisFixture's "clean" dataset (FX; sections 7 and 9)
% and the figures renderFigure draws into (sections 8 and 9), each made once
FX = []; cleanFixture = []; %#ok<NASGU>
    function fixtureA()
        if ~isempty(FX); return; end
        froot = string(root) + "_fixture";
        cleanFixture = onCleanup(@() rmdirQuiet(froot));
        FX = makeAnalysisFixture(froot, Scenarios="clean", NumTrials=12);
    end
fig = []; ufig = []; fe1 = []; closeFigs = []; %#ok<NASGU>
    function drawTargets()
        if ~isempty(fig) && isgraphics(fig); return; end
        fig = figure('Visible', 'off', 'Position', [100 100 700 800]);
        ufig = uifigure('Visible', 'off', 'Position', [100 100 700 800]);
        fe1 = figure('Visible', 'off', 'Position', [100 100 700 800]);
        closeFigs = onCleanup(@() delete([fig ufig fe1]));
    end

% section 7's oracles and counters, section 8's pixel probe, row readers and callback (nested: they
% share this function's variables, which their sections set before calling them)
    function [E, G] = epochsOf(baseline, columns)
        if nargin < 2; columns = string.empty(1, 0); end
        [E, G] = epochTable(src, D.EventRef, Window=wD, Selection=D.Selection, Baseline=baseline, Columns=columns);
    end
    function [st, m] = unitsOf(ids)
        hUnits = U0;
        if nargin > 0; hUnits.ids = ids; end
        [st, m] = selectUnits(src, hUnits, Ref=D.EventRef, Selection=D.Selection);
    end
    function [ep, on, off] = intervalsOf(line, E)
        % the oracle: every interval of the line overlapping each epoch's window, s from its event
        iv = double(src.events.(line));
        ep = zeros(0, 1); on = zeros(0, 1); off = zeros(0, 1);
        for hE = 1:height(E)
            hIn = find(iv(:, 1) <= E.tStop(hE) & iv(:, 2) >= E.tStart(hE));
            ep = [ep; repmat(hE, numel(hIn), 1)]; %#ok<AGROW>
            on = [on; iv(hIn, 1) - E.t0(hE)]; %#ok<AGROW>
            off = [off; iv(hIn, 2) - E.t0(hE)]; %#ok<AGROW>
        end
    end
    function countPoll()
        nPolls = nPolls + 1;
    end
    function countCheck()
        nChk = nChk + 1;
    end
    function px = rasterPixel(xv, yv)   % the pixel at data x XV, and fraction YV down the raster's box
        xl = xlim(axV);
        fpx = getpixelposition(fig);   % boxV is in the figure's pixels, the image scaled by the print resolution
        px = double(squeeze(imgV(max(1, round((1 - (boxV(2) + boxV(4) * (1 - yv)) / fpx(4)) * size(imgV, 1))), ...
            max(1, round((boxV(1) + boxV(3) * (xv - xl(1)) / diff(xl)) / fpx(3) * size(imgV, 2))), :))).';
    end
    function [hEp, hMid] = traceRows(hAx, hR, hW, hLabel)
        % each drawn bar of the layer HLABEL: its epoch (hR.epoch, the bars kept in the window) and its middle's y
        hB = findall(hAx, 'Tag', 'eventBar', 'Type', 'patch');
        hB = hB(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == hLabel && ~isempty(x.Faces), hB));
        hLo = max(hW(1), hR.window(hR.epoch, 1));
        hHi = min(hW(2), hR.window(hR.epoch, 2));
        hEp = hR.epoch(min(hR.off, hHi) >= max(hR.on, hLo));
        hMid = NaN(size(hEp));
        if isscalar(hB)
            hVy = hB.Vertices(:, 2);
            hMid = mean(reshape(hVy(hB.Faces.'), 4, []), 1).';
        end
    end
    function hOk = rowsAgree(hR, hO, hEp, hMid)
        % the bars' sub-rows (top = 1) are figEpochOrder's for the options hO
        [hOrd, ~] = figEpochOrder(hR, hO);
        hSlot = zeros(hR.nEpochs, 1);
        hSlot(hOrd) = 1:hR.nEpochs;
        [~, ~, hRank] = unique(-round(hMid, 9));   % the y order of the bars, top first
        [~, ~, hWant] = unique(hSlot(hEp));
        hOk = numel(hMid) == numel(hEp) && ~isempty(hEp) && isequal(hRank, hWant);
    end
    function remember(r)
        remembered = r;
    end

T = EphysAnalysisConfig.panelTypes();
types = ["raster" "psth" "continuous" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning"];
place = @EphysAnalysisConfig.placePanel;
remove = @EphysAnalysisConfig.removePanel;
move = @EphysAnalysisConfig.movePanel;
cellsOf = @EphysAnalysisConfig.figureCells;
layerOf = @EphysAnalysisConfig.defaultLayer;
spectralTypes = ["spectrum" "spectrogram" "coherence"];
FT = EphysAnalysisConfig.figureTemplates();
roles = PlotAesthetics.roles().Role;

% the sections: each runs alone after this setup; 8 reads 7's results, so it pulls 7 in
S = TestSections(mfilename, opts.Sections, Needs=["8" "7"]);
timing = onCleanup(@() S.done()); %#ok<NASGU>

%% ============================================================================ config
if S.sec("1", "config: defaults and the tables")
    F = EphysAnalysisConfig.defaults("Figure");
    check(F.id == "" && F.autoId && F.enabled && F.title == "" && F.observe.data == "units" && isequal(F.ref, "default") ...
        && isequal(F.window, "default") && isequal(F.selection, "default") && isequaln(F.style, EphysAnalysisConfig.defaults("Style")) ...
        && isempty(F.aesthetics) && isstruct(F.panels) && isempty(F.panels), 'defaults("Figure")');
    check(F.grid.rows == 1 && F.grid.cols == 1 && isequal(F.grid.rowHeights, []) && isequal(F.grid.colWidths, []) ...
        && F.grid.spacing == "tight", 'a figure''s grid: 1 x 1, equal sizes ([]), tight');
    check(isequal(fieldnames(F.panels), fieldnames(EphysAnalysisConfig.defaults("Panel"))), 'Figure.panels is an empty list of Panels');
    P = EphysAnalysisConfig.defaults("Panel");
    check(P.id == "" && P.type == "psth" && P.title == "" && P.row == 1 && P.col == 1 && P.rowSpan == 1 && P.colSpan == 1 ...
        && isequal(P.ref, "default") && isequal(P.window, "default") && isempty(P.layers) ...
        && isequal(fieldnames(P.layers), fieldnames(EphysAnalysisConfig.defaults("Layer"))) ...
        && isequaln(P.options, T.DefaultOptions{T.Type == "psth"}), 'defaults("Panel"): a PSTH with its options, no layers');
    L = EphysAnalysisConfig.defaults("Layer");
    check(L.name == "" && L.enabled && L.source == "units" && L.binding == "observation" && ~isfield(L.units, 'source') ...
        && isequaln(L.units, rmfield(EphysAnalysisConfig.defaults("UnitSelection"), 'source')) && isequal(L.channels, []) ...
        && L.aggregate == "each" && isequaln(L.event, EphysAnalysisConfig.defaults("EventMark")) && L.eventsAs == "marks" ...
        && L.color == "" && L.lineStyle == "" && ~isfield(L, 'yParam') && ~isfield(L, 'seriesParam'), 'defaults("Layer")');
    O = EphysAnalysisConfig.defaults("Observe");
    check(isequal(string(fieldnames(O)).', ["data" "units" "channels" "starred" "perGroup"]) && O.data == "units" && ~isfield(O.units, 'source') ...
        && isequal(O.channels, []) && ~O.starred && ~O.perGroup, 'defaults("Observe"): data (sorted units), units, channels, starred, perGroup');
    FS = EphysAnalysisConfig.defaults("FigureSessions");
    check(~FS.enabled && FS.datasets == "ticked" && isstring(FS.datasetKeys) && isequal(size(FS.datasetKeys), [1 0]) ...
        && FS.facet == "none" && FS.series == "session" && FS.colorOrder == "palette" && ~FS.showMembers && FS.error == "sem" ...
        && FS.match == "site" && FS.mappingFile == "" && FS.minSessions == 1 && FS.trialGroups == "pool" ...
        && isequaln(EphysAnalysisConfig.defaults("Figure").sessions, FS), 'defaults("FigureSessions"), the Figure''s sessions block');

    check(isequal(T.Type.', [types spectralTypes "eventTrace"]) && isequal(string(T.Properties.VariableNames), ["Type" "Label" "Short" "Categories" "Aligned" ...
        "SharesTime" "OneGroup" "MultiLayer" "DefaultBinding" "Description" "DefaultOptions"]), 'panelTypes: the thirteen types and the columns');
    check(isequal(T.Short.', ["Raster" "PSTH" "Continuous" "Heatmap" "Waveforms" "ProbeMap" "Correlation" "Rate" "Tuning" ...
        "Spectrum" "Spectrogram" "Coherence" "EventTraces"]) && all(~contains(T.Short, [" " "+"])), ...
        'panelTypes: a one-word Short name per type (the automatic figure id''s part)');
    check(isequal(T.SharesTime.', [true true true true false false false false false false true false true]) ...
        && isequal(T.Aligned.', [true true true true false false true true true true true true true]) ...
        && isequal(T.OneGroup.', [false false false true false false true false false false true false false]) ...
        && isequal(T.MultiLayer.', [true true true false false false false true true true false true true]) ...
        && isequal(T.DefaultBinding.', ["observation" "observation" "observation" "fixed" "observation" "fixed" "fixed" "observation" "observation" ...
            "observation" "observation" "observation" "fixed"]) && T.Label(13) == "Event traces" && isequal(T.Categories{13}, "point") ...
        && isequal(T.Categories{T.Type == "spectrum"}, ["point" "continuous"]) && isequal(T.Categories{T.Type == "spectrogram"}, ["continuous" "point"]) ...
        && isequal(T.Categories{T.Type == "coherence"}, ["point" "continuous"]) && isequal(T.Label(10:12).', ["Power spectrum" "Spectrogram" "Coherence"]) ...
        && isequal(T.Categories{T.Type == "rate"}, "point") && isequal(T.Categories{T.Type == "tuning"}, "point") && T.Label(8) == "Firing rate" && T.Label(9) == "Tuning curve" ...
        && isequal(T.Categories{T.Type == "heatmap"}, ["point" "continuous"]), 'panelTypes: aligned, shared time, one group, layers, binding, categories');
    O = T.DefaultOptions;
    check(isempty(O{1}.rasterSortEvent) && O{1}.rasterSortOrder == "ascending" && O{1}.waveform.mode == "off" ...
        && O{2}.bins.BinSec == 0.01 && O{2}.histStyle == "bar" && isnan(O{2}.fillAlpha) && isequal(O{2}.yLim, []) ...
        && O{2}.display == "trace" && O{2}.colormap == "" && isequal(O{2}.cLim, []) ...
        && O{3}.stack == "off" && O{3}.errorType == "sem" && O{3}.stackSpacing == 1.1 ...
        && O{4}.order == "probe" && O{4}.group == 1 && O{5}.waveform.mode == "both" ...
        && O{6}.value == "rate" && O{7}.metric == "mean" && O{7}.correlation == "pearson" && ~O{7}.fisherZ ...
        && O{2}.stack == "off" && O{2}.stackSpacing == 1.1 && isequaln(O{2}.auroc, EphysAnalysisConfig.defaults("Auroc")) ...
        && isequaln(O{4}.auroc, EphysAnalysisConfig.defaults("Auroc")) && O{5}.layout == "grid" ...
        && isequal(string(fieldnames(O{8})).', ["measure" "baseline" "display" "yLimMode" "yLim" "waveform"]) && O{8}.display == "bar" && O{8}.measure == "rate" ...
        && O{8}.waveform.mode == "off" && isempty(O{8}.waveform.timeMs) && O{8}.waveform.ampScale == "unit" && isempty(O{8}.waveform.ampLim) ...
        && O{8}.waveform.width == 1 && O{8}.waveform.height == 1 && ~isfield(O{8}.waveform, 'scale') ...
        && O{8}.baseline.Mode == "none" && isequal(O{8}.yLim, []) ...
        && isequal(string(fieldnames(O{9})).', ["param" "seriesParam" "stack" "stackSpacing" "measure" "baseline" "yLimMode" "yLim" "waveform"]) && O{9}.param == "" ...
        && O{9}.seriesParam == "" && O{9}.waveform.mode == "off", ...
        'panelTypes: each type''s DefaultOptions (psth stack / auroc, heatmap auroc, waveforms layout, rate and its inset, tuning)');
    srcCat = EphysAnalysisConfig.sourceCategories();
    check(isequal(srcCat.Category.', ["point" "continuous" "unit"]) && isequal(srcCat.Sources{1}, ["units" "detected" "events"]) ...
        && isequal(srcCat.Sources{3}, ["units" "detected"]) && isequal(srcCat.Aligned.', [true true false]), 'sourceCategories (no trial category)');
    check(isequal(EphysAnalysisConfig.FigureSources, ["units" "detected" "events" "LFP" "MUA" "SPIKE" "AUX"]), 'FigureSources (no trials)');
    catOf = @EphysAnalysisConfig.categoryOf;
    check(catOf("units", "raster") == "point" && catOf("detected", "waveforms") == "unit" && catOf("units", "corrmap") == "unit" ...
        && catOf("LFP", "heatmap") == "continuous" && catOf("units", "heatmap") == "point" ...
        && catOf("trials", "heatmap") == "" && catOf("units", "behavior") == "" && catOf("LFP", "raster") == "" && catOf("units", "continuous") == "" && catOf("units", "nope") == "", ...
        'categoryOf: the category a type draws a source in, else ""');
    check(catOf("events", "continuous") == "point" && catOf("events", "heatmap") == "point" && catOf("events", "raster") == "point" ...
        && catOf("events", "waveforms") == "" && catOf("events", "probemap") == "", 'categoryOf: events fit every time panel, and no other');
    Le = layerOf("eventTrace");
    Oe = T.DefaultOptions{T.Type == "eventTrace"};
    check(catOf("events", "eventTrace") == "point" && catOf("units", "eventTrace") == "" && catOf("detected", "eventTrace") == "" ...
        && catOf("LFP", "eventTrace") == "" && Le.source == "events" && Le.binding == "fixed" && Le.event.line == "Stim" ...
        && isempty(EphysAnalysisConfig.sharedFieldsOf("eventTrace")), ...
        'an event-trace panel draws events layers only (its default layer: an events layer, fixed); it shares no option with other types');
    check(isequal(string(fieldnames(Oe)).', ["display" "trials" "rasterSort" "rasterSortEvent" "rasterSortOrder" "rasterByGroup" ...
        "colorBy" "height" "alpha" "edgeColor" "edgeWidth" "minWidth" "lineWidth" ...
        "lineStyle" "showBaseline" "baselineColor" "baselineStyle" "baselineWidth" "rowSpacing" "groupBands"]) && Oe.display == "bars" ...
        && Oe.trials == "overlay" && Oe.rasterSort == "" && isempty(Oe.rasterSortEvent) && Oe.rasterSortOrder == "ascending" ...
        && Oe.rasterByGroup && Oe.minWidth == 1 && Oe.colorBy == "layer" && Oe.height == 0.6 && isnan(Oe.alpha) && Oe.edgeColor == "none" ...
        && Oe.showBaseline && Oe.baselineColor == "" && Oe.rowSpacing == 1.25 && Oe.groupBands, ...
        'panelTypes: the event-trace panel''s DefaultOptions (bars, every epoch overlaid, sorted by group then time, a 1 pt narrowest bar, colored per line, a baseline)');
    Em = EphysAnalysisConfig.defaults("EventMark");
    check(Em.spanStyle == "-" && Em.spanWidth == 1.5 && Em.spanAlpha == 1 && ~isfield(eventMarkRef(Em), 'spanStyle') ...
        && ~isfield(eventMarkRef(Em), 'spanAlpha'), 'EventMark: a span''s look (style, width, opacity), left out of its event reference');
    D1 = layerOf("continuous");
    D2 = layerOf("probemap");
    D3 = layerOf("heatmap");
    D4 = layerOf("waveforms");
    check(D1.source == "LFP" && D1.binding == "observation" && D2.source == "units" && D2.binding == "fixed" ...
        && D3.source == "units" && D3.binding == "fixed" && D4.source == "units" && D4.binding == "observation", ...
        'defaultLayer: the type''s first source with its default binding');
    check(strcmp(errorId(@() layerOf("violin")), 'EphysAnalysisConfig:BadValue') && strcmp(errorId(@() layerOf("behavior")), 'EphysAnalysisConfig:BadValue'), ...
        'defaultLayer of an unknown type (behavior is not a panel type): BadValue');
    fnF = string(fieldnames(F)).';
    check(~isfield(F, 'common') && find(fnF == "panels") == find(fnF == "grid") + 1 ...
        && strcmp(errorId(@() EphysAnalysisConfig.defaults("FigureCommon")), 'EphysAnalysisConfig:BadSection'), ...
        'a figure has no options of its own for its panels: panels right after grid');
    fnP = string(fieldnames(P)).';
    check(~isfield(P, 'common') && find(fnP == "selection") == find(fnP == "window") + 1 ...
        && find(fnP == "layers") == find(fnP == "selection") + 1 && isequal(P.selection, "default"), ...
        'Panel.selection: "default", after window, then layers (its options are its own)');
    check(isequaln(P.note, EphysAnalysisConfig.defaults("Note")) && isstruct(P.overlays) && isempty(P.overlays) ...
        && isequal(fieldnames(P.overlays), fieldnames(EphysAnalysisConfig.defaults("Overlay"))) ...
        && find(fnP == "note") == find(fnP == "options") + 1 && find(fnP == "overlays") == numel(fnP), ...
        'Panel.note: a Note (no text); Panel.overlays: an empty list of Overlays; both after options');
    check(P.box == "auto" && find(fnP == "box") == find(fnP == "title") + 1 && T.DefaultOptions{T.Type == "raster"}.yTicks == false ...
        && ~isfield(T.DefaultOptions{T.Type == "heatmap"}, 'yTicks'), ...
        'Panel.box: "auto", after title; the raster''s options.yTicks is false (no other type has it)');
    check(P.xLabel == "" && P.yLabel == "" && P.xSide == "bottom" && P.ySide == "left" ...
        && isequal(fnP(find(fnP == "box") + (1:4)), ["xLabel" "yLabel" "xSide" "ySide"]), ...
        'Panel.xLabel / yLabel: "" (automatic), xSide "bottom", ySide "left", after box');
    pn = EphysAnalysisConfig.normalizePanel(struct('type', "psth", 'note', struct('text', "n = 12", 'placement', "northeast"), ...
        'overlays', struct('shape', "region", 'panel', "raster", 'from', 0, 'to', 0.2)));
    check(isscalar(pn.overlays) && pn.overlays.panel == "all" && pn.overlays.shape == "region" && pn.overlays.to == 0.2 ...
        && pn.note.text == "n = 12" && pn.note.placement == "northeast" && pn.note.align == "left", ...
        'normalizePanel: a note completed from the defaults; an overlay''s panel is always "all" (its own axes)');
    Oc = T.DefaultOptions{T.Type == "continuous"};
    Oh = T.DefaultOptions{T.Type == "heatmap"};
    check(Oc.trials == "off" && Oc.maxTrials == 100 && Oh.rows == "items" && Oh.rasterSort == "" && isempty(Oh.rasterSortEvent) ...
        && Oh.rasterSortOrder == "ascending" && Oh.rasterByGroup && ~EphysAnalysisConfig.defaults("Observe").perGroup, ...
        'continuous trials "off", maxTrials 100; heat map rows "items" with a raster''s sort fields; observe.perGroup false');
    cfo = @EphysAnalysisConfig.sharedFieldsOf;
    stk = ["stack" "stackSpacing"];
    check(isequal(cfo("raster"), ["maskAfterStop" "waveform"]) && isequal(cfo("psth"), ["bins" "measure" "baseline" "auroc" "maskAfterStop" "waveform" stk "yLimMode"]) ...
        && isequal(cfo("continuous"), ["baseline" stk "yLimMode"]) && isequal(cfo("heatmap"), ["bins" "measure" "baseline" "auroc" "maskAfterStop" stk]) ...
        && isequal(cfo("rate"), ["measure" "baseline" "waveform" "yLimMode"]) && isequal(cfo("tuning"), ["measure" "baseline" "waveform" stk "yLimMode"]) ...
        && isequal(cfo("waveforms"), "yLimMode") && isequal(cfo("corrmap"), ["bins" "baseline"]) && isequal(cfo("spectrogram"), stk) ...
        && isequal(cfo("spectrum"), [stk "yLimMode"]) ...
        && isempty(cfo("probemap")) && isempty(cfo("violin")), ...
        'sharedFieldsOf(type): the options several types share (a waveforms panel''s waveform is its own, not an inset; the spectral types share the stack alone)');
    cbm = @EphysAnalysisConfig.baselineModes;
    check(isequal(cbm("psth"), ["none" "subtract" "zscore" "percent" "auroc"]) && isequal(cbm("heatmap"), cbm("psth")) ...
        && isequal(cbm("heatmap", "units"), cbm("psth")) && isequal(cbm("heatmap", "LFP"), ["none" "subtract"]) ...
        && isequal(cbm("continuous"), ["none" "subtract"]) && isequal(cbm("corrmap"), ["none" "subtract"]) ...
        && isequal(cbm("rate"), ["none" "subtract" "ratio" "zscore"]) && isequal(cbm("tuning"), cbm("rate")) ...
        && isequal(cbm("spectrogram"), ["none" "db" "percent" "zscore" "ratio"]) && isequal(cbm("raster"), "none") ...
        && isequal(cbm("waveforms"), "none"), ...
        'baselineModes(type, source): the baseline Modes a type takes (a heat map of a signal none and subtract; "none" for a type without one)');
    Osp = T.DefaultOptions{T.Type == "spectrum"};
    Osg = T.DefaultOptions{T.Type == "spectrogram"};
    Och = T.DefaultOptions{T.Type == "coherence"};
    cxs = chronuxSettings();
    check(Osp.timeBase == "aligned" && isequal(Osp.range, [0 Inf]) && Osp.segmentSec == 2 && Osp.taperMode == "TWK" && Osp.TW == cxs.TW ...
        && Osp.K == cxs.K && Osp.W == cxs.W && Osp.p == cxs.p && Osp.pad == 0 && isequal(Osp.fpass, cxs.fpass) && Osp.err == cxs.err ...
        && Osp.errP == 0.05 && Osp.detrend == cxs.detrend && Osp.scale == "db" && Osp.spikeFs == 1000 && isequal(Osp.yLim, []) ...
        && ~isfield(Osg, 'timeBase') && isequal(Osg.movingwin, cxs.movingwin) && Osg.baseline.Mode == "none" && isequal(Osg.baseline.Window, [-0.5 0]) ...
        && Osg.group == 1 && isequal(Osg.cLim, []) && ~Och.overTime && Och.showPhase && isequal(Och.movingwin, cxs.movingwin) && ~isfield(Och, 'scale') ...
        && Och.group == 1 && isequal(cfo("spectrum"), ["stack" "stackSpacing" "yLimMode"]) && isequal(cfo("spectrogram"), ["stack" "stackSpacing"]) ...
        && isequal(cfo("coherence"), ["stack" "stackSpacing" "yLimMode"]), ...
        'the spectral types'' DefaultOptions are chronuxSettings'' defaults (a spectrogram''s baseline a {Mode, Window}); none but the stack and yLimMode is a shared option');
    check(catOf("LFP", "spectrum") == "continuous" && catOf("units", "spectrum") == "point" && catOf("events", "spectrum") == "" ...
        && catOf("LFP", "spectrogram") == "continuous" && catOf("units", "spectrogram") == "point" && catOf("events", "spectrogram") == "point" ...
        && catOf("detected", "coherence") == "point" && catOf("AUX", "coherence") == "continuous" && catOf("events", "coherence") == "", ...
        'categoryOf: spectra, spectrograms and coherence of spikes or signals; a spectrogram''s events marks');
    FTs = EphysAnalysisConfig.figureTemplates();
    ctp = FTs.Figure{FTs.Template == "coherence"}.panels{1};
    check(layerOf("spectrum").source == "units" && layerOf("spectrogram").source == "LFP" && layerOf("spectrogram").binding == "observation" ...
        && numel(ctp.layers) == 2 && isequal([ctp.layers.source], ["units" "LFP"]) && all([ctp.layers.binding] == "observation"), ...
        'defaultLayer of the spectral types; the coherence template: the observed unit with its channel''s LFP');

    fu = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "raster", 'layers', layerOf("raster"))}}));
    fc = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "continuous", 'layers', layerOf("continuous"))}}));
    fd = EphysAnalysisConfig.normalizeFigure(struct('panels', {{struct('type', "probemap", 'layers', layerOf("probemap"))}}));
    foff = fu; foff.panels(1).layers(1).enabled = false;
    fdet = fu; fdet.panels(1).layers(1).source = "detected";
    fmua = fc; fmua.panels(1).layers(1).source = "MUA";
    fboth = fc; fboth.panels(1).layers(end+1) = layerOf("raster");
    check(EphysAnalysisConfig.followedData(fu) == "units" && EphysAnalysisConfig.followedData(fdet) == "detected" ...
        && EphysAnalysisConfig.followedData(fc) == "LFP" && EphysAnalysisConfig.followedData(fmua) == "MUA" ...
        && EphysAnalysisConfig.followedData(fboth) == "units" && EphysAnalysisConfig.followedData(fd) == "dataset" ...
        && EphysAnalysisConfig.followedData(foff) == "dataset", ...
        'followedData: units, detected, the first signal a following layer reads (spikes first), else the dataset (a disabled layer does not count)');
    kindOf = @(d) EphysAnalysisConfig.observeKind(setfield(fd, 'observe', setfield(fd.observe, 'data', d))); %#ok<SFLD>
    check(isequal(EphysAnalysisConfig.ObserveData, ["units" "detected" "LFP" "MUA" "SPIKE" "AUX" "dataset"]) ...
        && kindOf("units") == "unit" && kindOf("detected") == "unit" && all(arrayfun(@(s) kindOf(s) == "channel", ["LFP" "MUA" "SPIKE" "AUX"])) ...
        && kindOf("dataset") == "dataset" && kindOf("bogus") == "dataset" && EphysAnalysisConfig.observeKind(fu) == "unit", ...
        'observeKind follows observe.data: units and detected -> unit, a signal -> channel, the dataset (an unknown value too) -> dataset; the layers do not change it');
end

if S.sec("2", "config: addFigure, templates and ids")
    check(FT.Template(1) == "rasterPsth" && FT.Label(1) == "Raster over PSTH (per unit)" ...
        && isequal(FT.Template(2:end-1).', ["psth" "raster" "continuous" "eventTrace" "heatmap" "waveforms" "probemap" "corrmap" "rate" "tuning" spectralTypes]) ...
        && FT.Template(end) == "blank", 'figureTemplates: rasterPsth first, one per type, blank last');
    ct = EphysAnalysisConfig();
    ct = ct.addFigure("rate");
    ct = ct.addFigure("tuning");
    check(ct.Figures(1).panels.id == "rate_1" && ct.Figures(2).panels.id == "tuning_1" && isscalar(ct.Figures(1).panels.layers) ...
        && ct.Figures(1).panels.layers.source == "units" && ct.Figures(1).panels.layers.binding == "observation" ...
        && ct.Figures(2).panels.layers.source == "units" && ct.Figures(2).panels.layers.binding == "observation" ...
        && FT.Label(FT.Template == "rate") == "Firing rate" && FT.Label(FT.Template == "tuning") == "Tuning curve", ...
        'the rate and tuning templates: one panel, one units layer following the observed unit');
    cfg = EphysAnalysisConfig();
    [cfg, id1] = cfg.addFigure();
    f1 = cfg.Figures(1);
    check(id1 == "Raster+PSTH units" && f1.autoId && f1.grid.rows == 2 && f1.grid.cols == 1 && isequal(f1.grid.rowHeights, [1 1]) && f1.grid.spacing == "none" ...
        && isequal([f1.panels.id], ["raster_1" "psth_1"]) && isequal([f1.panels.row], [1 2]) && isequal([f1.panels.col], [1 1]), ...
        'addFigure(): an automatic id ("Raster+PSTH units"), raster_1 flush over psth_1 on a 2 x 1 grid');
    check(isscalar(f1.panels(1).layers) && isscalar(f1.panels(2).layers) && f1.panels(1).layers.source == "units" ...
        && f1.panels(1).layers.binding == "observation" && f1.panels(2).layers.binding == "observation", ...
        'rasterPsth: each panel one units layer following the observation');
    [cfg, id2] = cfg.addFigure("continuous");
    [cfg, id3] = cfg.addFigure("blank", Id="empty");
    [cfg, id4] = cfg.addFigure(struct('panels', struct('type', "heatmap")));
    check(isequal([id2 id3 id4], ["Continuous LFP" "empty" "Blank dataset"]) && cfg.Figures(2).panels.id == "continuous_1" ...
        && cfg.Figures(2).panels.layers.source == "LFP" && isempty(cfg.Figures(3).panels) && cfg.Figures(4).panels.id == "heatmap_1" ...
        && isequal([cfg.Figures.autoId], [true true false true]), ...
        'addFigure: automatic ids (a heat map panel without layers is not active: "Blank dataset"), a given id is the figure''s own, a partial struct gets panel ids');
    [cfg5, id5] = cfg.addFigure(struct('observe', struct('data', "MUA"), 'panels', struct('type', "raster", 'layers', layerOf("raster"))));
    check(f1.observe.data == "units" && cfg.Figures(2).observe.data == "LFP" && cfg.Figures(3).observe.data == "dataset" ...
        && cfg.Figures(4).observe.data == "dataset" && cfg5.Figures(cfg5.figureIndex(id5)).observe.data == "MUA", ...
        'addFigure observes what the following layers read (units, LFP; the dataset for a blank figure or fixed layers) unless observe.data is given');
    check(strcmp(errorId(@() cfg.addFigure("nope")), 'EphysAnalysisConfig:BadValue'), 'an unknown template: BadValue');
    check(strcmp(errorId(@() cfg.addFigure("psth", Id="empty")), 'EphysAnalysisConfig:DuplicateFigureId'), 'a taken id: DuplicateFigureId');
    cfg.Figures(3).enabled = false;
    check(isequal(cfg.figureIds(), ["Raster+PSTH units" "Continuous LFP" "empty" "Blank dataset"]) && cfg.figureIndex("empty") == 3 && cfg.figureIndex("x") == 0 ...
        && isequal(cfg.enabledFigures(), ["Raster+PSTH units" "Continuous LFP" "Blank dataset"]), 'figureIds, figureIndex, enabledFigures');
    c2 = cfg.removeFigure("empty");
    check(isequal(c2.figureIds(), ["Raster+PSTH units" "Continuous LFP" "Blank dataset"]) && strcmp(errorId(@() cfg.removeFigure("x")), 'EphysAnalysisConfig:NoFigure'), ...
        'removeFigure (NoFigure for an unknown id)');
    c2.Figures = {struct(), struct('id', "figure_1"), struct('autoId', false)};
    check(isequal(c2.figureIds(), ["Blank units" "figure_1" "figure_2"]) && isequal([c2.Figures.autoId], [true false false]), ...
        'a cell of partial figures: no id -> an automatic id; an id given -> its own; autoId false and no id -> "figure_<n>"');

    % automatic ids (autoFigureId): the active panel types in grid order, then the data; " (n)" for uniqueness
    ca = EphysAnalysisConfig();
    [ca, a1] = ca.addFigure("rasterPsth");
    [ca, a2] = ca.addFigure("rasterPsth");
    [ca, a3] = ca.addFigure("coherence");
    [ca, a4] = ca.addFigure("eventTrace");
    fa = ca.Figures(1);
    fa = place(fa, struct('type', "continuous", 'layers', layerOf("continuous")), "below", "psth_1");
    ca.Figures(1) = fa;
    check(isequal([a1 a2 a3 a4], ["Raster+PSTH units" "Raster+PSTH units (2)" "Coherence units+LFP" "EventTraces events"]) ...
        && ca.Figures(1).id == "Raster+PSTH+Continuous units+LFP" && ca.Figures(2).id == "Raster+PSTH units (2)", ...
        'autoFigureId: types in grid order joined by +, then observe.data and the layers'' sources; the second gets " (2)", and keeps it when the first is renamed');
    ca.Figures(1).panels(1).layers(1).enabled = false;   % an inactive panel (no enabled layer) is not named
    check(ca.Figures(1).id == "PSTH+Continuous units+LFP", 'a panel with no enabled layer is not in the id');
    fe = ca.Figures(2);
    ev = layerOf("eventTrace");
    fe.panels(1).layers(end+1) = ev;   % marks annotate: not data
    fe.panels(1).layers(end).eventsAs = "train";
    fe.id = "";
    fe.autoId = true;
    ca = ca.addFigure(fe);
    check(ca.Figures(end).id == "Raster+PSTH units+events" && endsWith(EphysAnalysisConfig.autoFigureId(ca.Figures(2)), "units"), ...
        'events count as data only drawn as a train (or on an event-trace panel), not as marks');
    ca.Figures(2).panels(1).type = "heatmap";
    check(ca.Figures(2).id == "Heatmap+PSTH units" && ca.Figures(2).autoId, 'the id follows a type change');
    ca.Figures(2).observe.data = "MUA";
    check(ca.Figures(2).id == "Heatmap+PSTH MUA+units", 'and observe.data');
    ca.Figures(2).autoId = false;
    ca.Figures(2).panels(1).type = "raster";
    check(ca.Figures(2).id == "Heatmap+PSTH MUA+units", 'autoId false: the id stays whatever the panels');
    ca.Figures(2).id = "mine";
    ca.Figures(2).autoId = true;
    check(ca.Figures(2).id == "Raster+PSTH MUA+units", 'autoId true again: back to the automatic id');
    [ca, d1] = ca.duplicateFigure(2);
    [ca, d2] = ca.duplicateFigure(2);
    check(d1 == "Raster+PSTH MUA+units (2)" && d2 == "Raster+PSTH MUA+units (3)" && isequal(ca.figureIds(), ...
        ["PSTH+Continuous units+LFP" "Raster+PSTH MUA+units" "Raster+PSTH MUA+units (3)" "Raster+PSTH MUA+units (2)" "Coherence units+LFP" ...
        "EventTraces events" "Raster+PSTH units+events"]) && ca.Figures(3).autoId, ...
        'duplicateFigure: right after the figure, "<id> (n)" with the next free n, still automatic');
    ca.Figures(2).autoId = false;   % first: an automatic id would take over an id typed while autoId is true
    ca.Figures(2).id = "unit_card";
    [ca, d3] = ca.duplicateFigure("unit_card");
    [ca, d4] = ca.duplicateFigure("unit_card (2)");
    check(d3 == "unit_card (2)" && d4 == "unit_card (3)" && ~ca.Figures(3).autoId && strcmp(errorId(@() ca.duplicateFigure("x")), ...
        'EphysAnalysisConfig:NoFigure'), 'an id of one''s own duplicates as "<id> (n)" (a " (n)" it ends in is not doubled), still its own');
    cb = EphysAnalysisConfig();
    cb = cb.addFigure("psth", Id="psth units");   % names the same files as "PSTH units" ({Plot}, case-blind)
    [cb, b1] = cb.addFigure("psth");
    check(b1 == "PSTH units (2)" && EphysAnalysisConfig.nextFreeId("PSTH units", ["PSTH_units" "x"]) == "PSTH units (2)" ...
        && EphysAnalysisConfig.nextFreeId("a", "b") == "a" && EphysAnalysisConfig.nextFreeId("a", "b", Suffix=true) == "a (2)", ...
        'an automatic id never names the files another figure names (compared as {Plot} writes them, case-blind)');
    fj2 = string(tempname) + ".json";
    ca.save(fj2);
    cl = EphysAnalysisConfig.load(fj2);
    delete(fj2);
    check(isequal(cl.figureIds(), ca.figureIds()) && isequal([cl.Figures.autoId], [ca.Figures.autoId]), 'automatic ids and autoId survive save / load');
    fOwn = cfg.Figures(1);
    fOwn.autoId = false;
    c3 = setFigures(c2, [cfg.Figures(1) cfg.Figures(1)]);
    check(strcmp(errorId(@() setFigures(c2, [fOwn fOwn])), 'EphysAnalysisConfig:DuplicateFigureId') ...
        && isequal(c3.figureIds(), ["Raster+PSTH units" "Raster+PSTH units (2)"]), ...
        'two figures with one id of their own: DuplicateFigureId; two with one automatic id: the second gets " (2)"');
    dupPanels = struct('panels', {{struct('id', "a", 'type', "psth"), struct('id', "a", 'type', "raster")}});
    check(strcmp(errorId(@() setFigures(c2, dupPanels)), 'EphysAnalysisConfig:DuplicatePanelId'), 'two panels with one id: DuplicatePanelId');
    c2.Figures = [];
    check(isempty(c2.Figures) && isstruct(c2.Figures), 'Figures = [] empties them');
end

if S.sec("3", "config: figureFor")
    cfg = EphysAnalysisConfig();
    cfg.Defaults.EventRef.line = "Platform";
    cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.5, 'post', 1.5);
    cfg.Defaults.Selection.groupBy = "Depth";
    cfg = cfg.addFigure();
    cfg = cfg.addFigure("continuous");
    cfg = cfg.addFigure("probemap");
    s = cfg.figureFor(1);
    check(isequaln(s.ref, cfg.Defaults.EventRef) && isequaln(s.window, cfg.Defaults.Window) && isequaln(s.selection, cfg.Defaults.Selection), ...
        'figureFor: the figure''s "default" ref / window / selection from Defaults');
    check(s.observe.kind == "unit" && s.observe.data == "units" && s.observe.units.source == "units" ...
        && isequal(fieldnames(s.observe.units), fieldnames(EphysAnalysisConfig.defaults("UnitSelection"))), ...
        'figureFor: observe.kind added (unit for sorted units), and a complete observe.units (source = observe.data)');
    cd0 = cfg; cd0.Figures(1).observe.data = "detected";
    sd0 = cd0.figureFor(1);
    check(sd0.observe.kind == "unit" && sd0.observe.units.source == "detected", 'figureFor: detected -> a unit observation of detections');
    check(all([s.panels.aligned]) && all([s.panels.sharesTime]) && isequaln(s.panels(1).ref, s.ref) && isequaln(s.panels(2).window, s.window), ...
        'figureFor: panels take the figure''s ref and window, aligned and sharing its time');
    Lr = s.panels(1).layers;
    check(Lr.category == "point" && Lr.units.source == "units" && isequal(fieldnames(Lr.units), fieldnames(EphysAnalysisConfig.defaults("UnitSelection"))), ...
        'figureFor: a layer''s category and units.source');
    check(isequal(sort(fieldnames(s.panels(2).options)), sort(fieldnames(T.DefaultOptions{T.Type == "psth"}))), 'figureFor: options complete');
    cfg.Figures(1).panels(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
    cfg.Figures(1).panels(1).ref = struct('line', "Stim", 'edge', "offset");
    s = cfg.figureFor(1);
    check(~s.panels(1).sharesTime && ~s.panels(2).sharesTime && s.panels(2).window.post == 0.3 && s.panels(1).ref.edge == "offset" ...
        && isequaln(s.panels(1).window, s.window) && isequaln(s.panels(2).ref, s.ref), ...
        'a panel''s own ref or window: kept, the other part from the figure, and it no longer shares time');
    s = cfg.figureFor(2);
    check(s.observe.kind == "channel" && s.observe.data == "LFP" && s.panels.layers.category == "continuous" && s.panels.layers.units.source == "LFP", ...
        'figureFor: LFP observed (the continuous template) -> channel observations');
    s = cfg.figureFor(3);
    check(s.observe.kind == "dataset" && ~s.panels.aligned && ~s.panels.sharesTime && s.panels.layers.category == "unit", ...
        'figureFor: a probe map with a fixed layer -> the dataset; not aligned');
    check(strcmp(errorId(@() cfg.figureFor("x")), 'EphysAnalysisConfig:NoFigure') && strcmp(errorId(@() cfg.figureFor(9)), 'EphysAnalysisConfig:NoFigure'), ...
        'figureFor: NoFigure');
    cfg.Figures(1).panels(2).options.bins.BinSec = 0.02;
    cfg.Figures(1).panels(2).options.histStyle = "line";
    cfg.Figures(1).panels(2).type = "heatmap";
    op = cfg.Figures(1).panels(2).options;
    check(isequal(sort(fieldnames(op)), sort(fieldnames(T.DefaultOptions{T.Type == "heatmap"}))) && op.bins.BinSec == 0.02 && ~isfield(op, 'histStyle'), ...
        'a type change re-seeds the options: the new type''s fields, shared values kept, the others dropped');
    cfg.Figures(1).panels(2).type = "violin";
    s = cfg.figureFor(1);
    check(isempty(fieldnames(cfg.Figures(1).panels(2).options)) && ~s.panels(2).aligned && s.panels(2).layers.category == "", ...
        'an unknown type keeps empty options (validate reports it)');
    cc = EphysAnalysisConfig();
    cc = cc.addFigure();
    cc = cc.addFigure("waveforms", Id="wf");
    cc.Figures(1).panels(1).options.waveform.mode = "mean";
    cc.Figures(1).panels(2).options.histStyle = "line";
    cc.Figures(1).panels(2).options.bins = struct('BinSec', 0.002, 'SmoothSec', 0);
    cc.Figures(1).panels(2).options.baseline = struct('Mode', "zscore", 'Window', [-0.3 0]);
    s = cc.figureFor(1);
    check(~isfield(s, 'common') && ~isfield(s.panels, 'common') && s.panels(2).options.bins.BinSec == 0.002 ...
        && s.panels(2).options.bins.SmoothSec == 0 && s.panels(2).options.baseline.Mode == "zscore" && s.panels(2).options.histStyle == "line" ...
        && s.panels(2).options.waveform.mode == "off" && s.panels(1).options.waveform.mode == "mean", ...
        'figureFor: each panel draws its own options (the PSTH''s bins and baseline, the raster''s inset; nothing from the figure)');
    check(cc.figureFor("wf").panels.options.waveform.mode == "both", 'figureFor: a waveforms panel''s own waveform, mode "both" by default');
    ca = EphysAnalysisConfig();
    ca.Defaults.Selection.groupBy = "Depth";
    ca = ca.addFigure();
    ca = ca.addFigure("heatmap", Id="hm");
    ca = ca.addFigure("rate", Id="rt");
    ca = ca.addFigure("tuning", Id="tc");
    ca.Figures(1).panels(2).options.baseline = struct('Mode', "auroc", 'Window', [-0.3 0]);
    ca.Figures(1).panels(2).options.auroc.windowSec = 0.05;
    ca.Figures(1).panels(2).options.auroc.cutoff = "fixed";
    ca.Figures(1).panels(2).options.stack = "groups";
    ca.Figures(1).panels(2).options.stackSpacing = 1.4;
    ca.Figures(2).panels.options.baseline.Mode = "auroc";
    ca.Figures(2).panels.options.auroc.modulationWindow = [0 0.2];
    ca.Figures(3).panels.options.measure = "count";
    ca.Figures(3).panels.options.baseline = struct('Mode', "zscore", 'Window', [-0.4 0]);
    ca.Figures(3).panels.options.display = "points";
    ca.Figures(4).panels.options.param = "Depth";
    ca.Figures(4).panels.options.seriesParam = "TrialType";
    ca.Figures(4).panels.options.waveform.mode = "mean";
    s = ca.figureFor(1);
    s2 = ca.figureFor("hm");
    s3 = ca.figureFor("rt");
    s4 = ca.figureFor("tc");
    check(s.panels(2).options.baseline.Mode == "auroc" && s.panels(2).options.auroc.windowSec == 0.05 && s.panels(2).options.auroc.cutoff == "fixed" ...
        && s.panels(2).options.stack == "groups" && s.panels(2).options.stackSpacing == 1.4 && ~isfield(s.panels(1).options, 'auroc') ...
        && s2.panels.options.baseline.Mode == "auroc" && isequal(s2.panels.options.auroc.modulationWindow, [0 0.2]), ...
        'figureFor: a PSTH and a heat map with their own auroc settings; the PSTH''s stack options');
    check(s3.panels.aligned && ~s3.panels.sharesTime && s3.panels.options.measure == "count" && s3.panels.options.baseline.Mode == "zscore" ...
        && s3.panels.options.display == "points" && s3.panels.layers.category == "point" ...
        && s4.panels.aligned && ~s4.panels.sharesTime && s4.panels.options.param == "Depth" && s4.panels.options.seriesParam == "TrialType" ...
        && s4.panels.options.waveform.mode == "mean" && s4.observe.kind == "unit", ...
        'figureFor: rate and tuning panels: aligned, not on the time axis, their measure / baseline / waveform, display / param / series');
    cw = EphysAnalysisConfig();
    cw = cw.addFigure("waveforms");
    cw.Figures(1).panels.options.layout = "probe";
    cw2 = cw; cw2.Figures(1).panels.options.layout = "grid";
    check(cw.figureFor(1).panels.options.layout == "probe" && cw2.figureFor(1).panels.options.layout == "grid", 'figureFor: the waveforms layout');
    cs = EphysAnalysisConfig();
    cs.Defaults.Selection.groupBy = "Depth";
    cs = cs.addFigure();
    cs.Figures(1).panels(2).selection = struct('groupBy', "TrialType");
    s = cs.figureFor(1);
    check(isequaln(s.panels(1).selection, cs.Defaults.Selection) && isstruct(s.panels(2).selection) ...
        && isequal(s.panels(2).selection.groupBy, "TrialType") && s.panels(2).sharesTime && s.panels(1).sharesTime, ...
        'figureFor: a panel''s "default" selection is the figure''s; its own is kept, and time stays shared (ref + window only)');
    ap2 = cs.Figures(1);
    ap2.panels(1).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.2);
    al3 = EphysAnalysisConfig.adoptPanelAlignment(ap2, "psth_1");
    rl3 = EphysAnalysisConfig.relinkPanels(ap2);
    check(isequal(al3.selection.groupBy, "TrialType") && all(arrayfun(@(p) isequal(p.selection, "default"), al3.panels)) ...
        && isequal(al3.window, "default") && all(arrayfun(@(p) isequal(p.selection, "default") && isequal(p.window, "default"), rl3.panels)), ...
        'adoptPanelAlignment takes a panel''s own selection as the figure''s; both link every panel''s selection again');
end

if S.sec("4", "config: a JSON round trip")
    cfg = EphysAnalysisConfig();
    cfg.Source.Root = root;
    Pc = cell(1, numel(types));
    for t = 1:numel(types)
        Pc{t} = struct('type', types(t), 'row', ceil(t / 2), 'col', 2 - mod(t, 2), 'layers', layerOf(types(t)));
    end
    ev = layerOf("raster");
    ev.source = "events"; ev.binding = "fixed"; ev.name = "licks after a trough";
    ev.event.line = "Lick"; ev.event.marker = "|"; ev.event.color = "#ff0000"; ev.event.size = 6;
    ev.event.sequence = struct('line', {"Trough" "Stim"}, 'maxGapSec', {1 Inf}, 'relation', {"followedBy" "notFollowedBy"});
    Pc{1}.layers = [Pc{1}.layers, ev];
    Pc{1}.options = struct('rasterSort', "event", 'rasterSortEvent', struct('line', "Platform", 'edge', "offset"), 'waveform', struct('mode', "mean"));
    fixedUnits = layerOf("psth");
    fixedUnits.binding = "fixed"; fixedUnits.units.ids = [3 5]; fixedUnits.aggregate = "mean"; fixedUnits.color = "#1f77b4"; fixedUnits.lineStyle = "--";
    Pc{2}.layers = [Pc{2}.layers, fixedUnits];
    Pc{2}.options = struct('yLim', [0 50], 'baseline', struct('Mode', "zscore", 'Window', [-0.3 0]), 'stack', "groups", 'stackSpacing', 1.3, ...
        'auroc', struct('windows', "sliding", 'stepSec', 0.02, 'modulationWindow', [0 0.3]));
    Pc{2}.window = struct('mode', "fixed", 'pre', -0.5, 'post', 1);
    aux = layerOf("continuous");
    aux.source = "AUX"; aux.binding = "fixed"; aux.channels = [1 2]; aux.aggregate = "mean";
    Pc{3}.layers = [Pc{3}.layers, aux];
    Pc{3}.options = struct('errorType', "std", 'stack', "items");
    Pc{4}.layers.source = "LFP"; Pc{4}.layers.channels = [1 2 3];
    Pc{4}.options = struct('cLim', [-1 1], 'group', 2);
    Pc{6}.options = struct('value', "nUnits");
    Pc{7}.ref = struct('line', "Platform");
    Pc{7}.window = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform", 'edge', "offset"));
    Pc{5}.options = struct('layout', "probe");
    Pc{8}.options = struct('display', "points", 'measure', "probability", 'baseline', struct('Mode', "ratio", 'Window', [-0.3 0]));
    Pc{9}.options = struct('param', "Depth", 'seriesParam', "TrialType", 'yLim', [0 20]);
    Pc{2}.note = struct('text', "Stim at 0" + newline + "n = 12", 'placement', "right", 'color', "#1f77b4", 'fontSize', 8);
    Pc{3}.size = [0.6 0.8]; Pc{3}.align = "left"; Pc{3}.valign = "bottom";
    Pc{2}.overlays = struct('name', {"stim" "window"}, 'shape', {"line" "region"}, 'value', {0 0}, 'from', {0 0.05}, ...
        'to', {0.1 0.25}, 'layer', {"over" "under"}, 'faceAlpha', {0.25 0.4});
    allTypes = struct('id', "all_types", 'title', "Every panel type", ...
        'observe', struct('data', "units", 'units', struct('classes', "su", 'maxUnits', 4)), ...
        'sessions', struct('datasets', "list", 'datasetKeys', ["S1/a" "S2/b"]), ...
        'grid', struct('rows', 5, 'cols', 2, 'rowHeights', [1 1.5 1 1 1], 'colWidths', [2 1], 'spacing', "custom", ...
        'gapUnits', "%", 'colGap', 3, 'rowGaps', [2 4 6 8]), ...
        'panels', {Pc}, 'ref', struct('line', "Stim", 'timeRange', [0 Inf]), 'selection', struct('groupBy', ["Depth" "TrialType"]), ...
        'aesthetics', struct('role', "rate", 'group', "", 'property', "LineWidth", 'value', 2));
    cfg = cfg.addFigure(allTypes);
    cfg = cfg.addFigure("rasterPsth", Id="unit_card");
    cfg.Figures(2).grid.rowHeights = [1 1.5];
    f = fullfile(root, 'figures.json');
    cfg.save(f);
    txt = fileread(f);
    c2 = EphysAnalysisConfig.load(f);
    check(cfg.isequalConfig(c2) && isempty(c2.LoadWarnings), 'a config with figures survives save / load exactly');
    fn = string(fieldnames(cfg.toStruct())).';
    check(isequal(fn, ["schema" "version" "name" "description" "Source" "Defaults" "Figures" "Export" "Report"]) ...
        && contains(txt, '"Figures"') && contains(txt, '"rowHeights"') && ~contains(txt, '"Plots"'), ...
        'toStruct writes Figures after Defaults (no Plots or SessionPlots)');
    g = c2.Figures(1);
    check(isequal(g.grid.rowHeights, [1 1.5 1 1 1]) && isequal(g.grid.colWidths, [2 1]) && isequal(c2.Figures(2).grid.rowHeights, [1 1.5]) ...
        && isequal(c2.Figures(2).grid.colWidths, []), 'relative sizes come back as rows; [] stays []');
    check(g.grid.spacing == "custom" && g.grid.gapUnits == "%" && g.grid.colGap == 3 && isequal(g.grid.rowGaps, [2 4 6 8]) ...
        && isempty(g.grid.colGaps) && isequal(g.panels(3).size, [0.6 0.8]) && g.panels(3).align == "left" && g.panels(3).valign == "bottom" ...
        && isequal(g.panels(1).size, [1 1]) && g.panels(1).align == "center" && c2.Figures(2).grid.spacing == "none", ...
        'custom gaps in % (one each way, the row gaps set apart) and a panel''s own size and alignment survive save / load');
    check(isequal([g.panels.type], types) && isequal([g.panels.id], types + "_1") && g.panels(3).options.stack == "items" ...
        && g.panels(6).options.value == "nUnits" && g.panels(4).options.group == 2, ...
        'every panel type, with its options');
    check(g.panels(2).options.stack == "groups" && g.panels(2).options.stackSpacing == 1.3 && g.panels(2).options.auroc.windows == "sliding" ...
        && g.panels(2).options.auroc.stepSec == 0.02 && isequal(g.panels(2).options.auroc.modulationWindow, [0 0.3]) ...
        && g.panels(2).options.auroc.windowSec == 0.1 && g.panels(5).options.layout == "probe" ...
        && g.panels(8).options.display == "points" && g.panels(8).options.measure == "probability" && g.panels(8).options.baseline.Mode == "ratio" ...
        && g.panels(9).options.param == "Depth" && g.panels(9).options.seriesParam == "TrialType" && isequal(g.panels(9).options.yLim, [0 20]), ...
        'the PSTH''s stack and auroc, the waveforms layout, the rate and tuning options');
    e = g.panels(1).layers(2);
    check(e.source == "events" && e.binding == "fixed" && numel(e.event.sequence) == 2 && e.event.sequence(2).relation == "notFollowedBy" ...
        && isinf(e.event.sequence(2).maxGapSec) && e.event.sequence(1).maxGapSec == 1 && e.event.marker == "|" && e.event.color == "#ff0000" ...
        && e.event.size == 6 && e.name == "licks after a trough", 'an events layer with a sequence');
    check(isequal(g.panels(2).layers(2).units.ids, [3 5]) && g.panels(2).layers(2).aggregate == "mean" && g.panels(2).layers(1).binding == "observation" ...
        && g.panels(2).layers(2).lineStyle == "--" && isequal(g.panels(3).layers(2).channels, [1 2]) && isequal(g.panels(4).layers.channels, [1 2 3]), ...
        'fixed and following layers');
    check(isequal(c2.Figures(2).ref, "default") && isequal(c2.Figures(2).window, "default") && isequal(c2.Figures(2).panels(1).ref, "default") ...
        && isstruct(g.panels(2).window) && isequal(g.panels(2).ref, "default") && isstruct(g.panels(7).window.stop) ...
        && g.panels(7).window.mode == "between" && isequal(g.ref.timeRange, [0 Inf]), '"default" sentinels and overrides');
    check(isequal(g.sessions.datasetKeys, ["S1/a" "S2/b"]) && g.sessions.datasets == "list" && ~g.sessions.enabled && isequal(g.observe.units.classes, "su") && g.observe.units.maxUnits == 4 ...
        && isequal(g.selection.groupBy, ["Depth" "TrialType"]) && isscalar(g.aesthetics) && isstruct(g.panels(1).options.rasterSortEvent) ...
        && g.panels(1).options.rasterSortEvent.edge == "offset" && isnan(g.panels(2).options.fillAlpha) && g.panels(2).options.baseline.Mode == "zscore", ...
        'lists of one and two, an event to sort by, NaN and aesthetics');
    nt2 = g.panels(2).note;
    ov2 = g.panels(2).overlays;
    check(nt2.text == "Stim at 0" + newline + "n = 12" && nt2.placement == "right" && nt2.color == "#1f77b4" && nt2.fontSize == 8 ...
        && isnan(g.panels(1).note.fontSize) && g.panels(1).note.text == "" && numel(ov2) == 2 && isequal([ov2.name], ["stim" "window"]) ...
        && isequal([ov2.shape], ["line" "region"]) && ov2(2).to == 0.25 && ov2(2).faceAlpha == 0.4 && ov2(2).layer == "under" ...
        && all([ov2.panel] == "all") && isempty(g.panels(1).overlays) && contains(txt, '"overlays"'), ...
        'a panel''s note (two lines) and two overlays survive save / load; the other panels keep none');

    s = cfg.toStruct();
    s.Figures(1).bogus = 1;
    s.Figures(1).observe.qux = 1;
    s.Figures(1).panels(1).foo = 1;
    s.Figures(1).panels(1).layers(1).bar = 1;
    s.Figures(1).panels(1).options.baz = 1;
    f2 = fullfile(root, 'unknown.json');
    writeJsonFile(f2, s, NonFinite="string");
    ws = warning('off', 'EphysAnalysisConfig:LoadWarnings');
    c3 = EphysAnalysisConfig.load(f2);
    warning(ws);
    w = strjoin(c3.LoadWarnings, " | ");
    check(contains(w, "Figures: dropped unknown field(s)") && contains(w, "Figures(1).bogus") && contains(w, "Figures(1).observe.qux") ...
        && contains(w, "Figures(1).panels(1).foo") && contains(w, "Figures(1).panels(1).layers(1).bar") ...
        && contains(w, "Figures(1).panels(1).options.baz") && ~contains(w, "top-level"), ...
        'unknown figure, observe, panel, layer and options fields are dropped and listed in LoadWarnings');
    check(c3.isequalConfig(cfg), 'and the rest loads unchanged');
    check(~contains(txt, '"common"'), 'the file holds no figure-level options block and no panel link flag: each panel''s options are its own');
    fj = fullfile(root, 'template.json');
    rpt = EphysAnalysisConfig();
    rpt = rpt.addFigure("rasterPsth");
    rpt.save(fj);
    check(rpt.isequalConfig(EphysAnalysisConfig.load(fj)), 'the rasterPsth template round-trips');
    rn4 = EphysAnalysisConfig();
    rn4 = rn4.addFigure("rasterPsth");
    rn4 = rn4.addFigure("continuous", Id="ct4");
    rn4 = rn4.addFigure("heatmap", Id="hm4");
    rn4.Figures(1).observe.perGroup = true;
    rn4.Figures(1).panels(2).selection = struct('groupBy', "TrialType", 'filter', "Depth > 0");
    rn4.Figures(2).panels.options.trials = "faint";
    rn4.Figures(2).panels.options.maxTrials = 25;
    rn4.Figures(3).panels.options.rows = "trials";
    rn4.Figures(3).panels.options.rasterSort = "Depth";
    rn4.Figures(3).panels.options.rasterSortOrder = "descending";
    rn4.save(fj);
    rn5 = EphysAnalysisConfig.load(fj);
    check(rn4.isequalConfig(rn5) && isempty(rn5.LoadWarnings) && rn5.Figures(1).observe.perGroup ...
        && isequal(rn5.Figures(1).panels(2).selection.groupBy, "TrialType") && rn5.Figures(1).panels(2).selection.filter == "Depth > 0" ...
        && isequal(rn5.Figures(1).panels(1).selection, "default") && rn5.Figures(2).panels.options.trials == "faint" ...
        && rn5.Figures(2).panels.options.maxTrials == 25 && rn5.Figures(3).panels.options.rows == "trials" ...
        && rn5.Figures(3).panels.options.rasterSort == "Depth" && rn5.Figures(3).panels.options.rasterSortOrder == "descending", ...
        'perGroup, a panel''s own selection, continuous trials / maxTrials and a heat map of trials survive save / load');
    v = jsondecode('[{"id": "a", "panels": [{"type": "raster"}]}, {"grid": {"rows": 2, "rowHeights": [1, 1.5]}, "panels": {"type": "psth", "row": 2}}]');
    c4 = EphysAnalysisConfig();
    c4.Figures = v;
    check(iscell(v) && isequal(c4.figureIds(), ["a" "Blank units"]) && c4.Figures(1).panels.id == "raster_1" ...
        && isequal(c4.Figures(2).grid.rowHeights, [1 1.5]) && c4.Figures(2).panels.row == 2, ...
        'a cell Figures from jsondecode (figures with different fields)');
    c5 = EphysAnalysisConfig(struct('schema', EphysAnalysisConfig.Schema, 'version', EphysAnalysisConfig.Version, 'Figures', struct('id', "solo")));
    check(isequal(c5.figureIds(), "solo") && isempty(c5.LoadWarnings), 'one figure as a JSON object (not a list)');
    s = rmfield(cfg.toStruct(), 'Figures');
    fo = fullfile(root, 'no_figures.json');
    writeJsonFile(fo, s, NonFinite="string");
    co = EphysAnalysisConfig.load(fo);
    check(isempty(co.Figures) && isstruct(co.Figures) && isempty(co.LoadWarnings), ...
        'a config file without Figures loads with none and no warning');
end

if S.sec("5", "config: grid editing")
    f = EphysAnalysisConfig.normalizeFigure(struct());
    f = place(f, struct('type', "raster"));
    check(isscalar(f.panels) && f.panels.id == "raster_1" && f.panels.row == 1 && f.panels.col == 1 && f.grid.rows == 1 && f.grid.cols == 1, ...
        'placePanel: the first panel goes to (1,1), no anchor needed');
    f = place(f, struct('type', "psth"), "below", "raster_1");
    check(f.grid.rows == 2 && f.panels(2).id == "psth_1" && f.panels(2).row == 2 && f.panels(2).col == 1, 'below: a new row under the anchor');
    f.grid.rowHeights = [1 2];
    f = place(f, struct('type', "psth"), "below", "psth_1");
    check(f.grid.rows == 3 && isequal(f.grid.rowHeights, [1 2 2]) && f.panels(3).id == "psth_2" && f.panels(3).row == 3, ...
        'below copies the anchor row''s height; a second PSTH gets psth_2');
    f = place(f, struct('type', "continuous"), "above", "raster_1");
    check(f.grid.rows == 4 && isequal(f.grid.rowHeights, [1 1 2 2]) && f.panels(4).row == 1 && isequal([f.panels(1:3).row], [2 3 4]), ...
        'above: a new row before the anchor, the rows below shift down');

    lr = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 2, 'cols', 2, 'rowHeights', [1 3]), 'panels', {{ ...
        struct('id', "L", 'type', "heatmap", 'row', 1, 'col', 1, 'rowSpan', 2), struct('id', "R1", 'type', "raster", 'row', 1, 'col', 2), ...
        struct('id', "R2", 'type', "psth", 'row', 2, 'col', 2)}}));
    check(isequal(cellsOf(lr), [1 2; 1 3]), 'figureCells: the panel in each cell, spans included');
    g = place(lr, struct('id', "N", 'type', "continuous"), "below", "R1");
    check(g.grid.rows == 3 && isequal(g.grid.rowHeights, [1 1 3]) && g.panels(1).rowSpan == 3 && g.panels(3).row == 3 ...
        && g.panels(4).row == 2 && g.panels(4).col == 2 && isequal(cellsOf(g), [1 2; 1 4; 1 3]), ...
        'below: a span crossing the new row stretches, the panels past it shift down');
    check(isequaln(remove(g, "N"), lr), 'removePanel undoes below exactly');
    g2 = place(lr, struct('id', "N", 'type', "continuous"), "above", "R2");
    check(isequaln(g2.panels, g.panels) && g2.grid.rows == 3 && isequal(g2.grid.rowHeights, [1 3 3]) && isequaln(remove(g2, "N"), lr), ...
        'above the lower panel: the same panels (its own row''s height copied); removed, the original');
    tb = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 2, 'cols', 2, 'colWidths', [1 3]), 'panels', {{ ...
        struct('id', "T", 'type', "heatmap", 'row', 1, 'col', 1, 'colSpan', 2), struct('id', "B1", 'type', "raster", 'row', 2, 'col', 1), ...
        struct('id', "B2", 'type', "psth", 'row', 2, 'col', 2)}}));
    g = place(tb, struct('id', "N", 'type', "psth"), "right", "B1");
    check(g.grid.cols == 3 && isequal(g.grid.colWidths, [1 1 3]) && g.panels(1).colSpan == 3 && g.panels(3).col == 3 ...
        && g.panels(4).col == 2 && g.panels(4).row == 2 && isequal(cellsOf(g), [1 1 1; 2 4 3]), ...
        'right: a span crossing the new column stretches, the panels past it shift right');
    check(isequaln(remove(g, "N"), tb), 'removePanel undoes right exactly');
    g = place(tb, struct('id', "N", 'type', "psth"), "left", "B1");
    check(g.grid.cols == 3 && isequal(g.grid.colWidths, [1 1 3]) && isequal([g.panels.col], [2 2 3 1]) && g.panels(1).colSpan == 2 ...
        && isequal(cellsOf(g), [0 1 1; 4 2 3]) && isequaln(remove(g, "N"), tb), ...
        'left: a new column before the anchor (a cell left blank); removed, the original');
    tri = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 3, 'cols', 1, 'spacing', "custom", 'rowGaps', [4 9]), ...
        'panels', {{struct('id', "A", 'type', "raster", 'row', 1), struct('id', "B", 'type', "psth", 'row', 2), ...
        struct('id', "C", 'type', "psth", 'row', 3)}}));
    gA = place(tri, struct('id', "N", 'type', "psth"), "below", "A");
    gT = place(tri, struct('id', "N", 'type', "psth"), "above", "A");
    gC = place(tri, struct('id', "N", 'type', "psth"), "below", "C");
    gR = place(tri, struct('id', "N", 'type', "psth"), "right", "B");
    tg = tb; tg.grid.colGaps = 5;
    gB = place(tg, struct('id', "N", 'type', "psth"), "right", "B1");
    check(isequal(gA.grid.rowGaps, [4 4 9]) && isequal(gT.grid.rowGaps, [4 4 9]) && isequal(gC.grid.rowGaps, [4 9 9]) ...
        && isempty(gR.grid.colGaps) && isequal(gR.grid.rowGaps, [4 9]) && isequal(gB.grid.colGaps, [5 5]) ...
        && isequaln(remove(gA, "N"), tri) && isequaln(remove(gT, "N"), tri) && isequaln(remove(gC, "N"), tri) ...
        && isequaln(remove(gR, "N"), tri) && isequaln(remove(gB, "N"), tg), ...
        'a gap list gets the gap where the new row (column) goes on both sides (at an edge the outer one again); [] stays []; Remove undoes it');
    z = remove(remove(remove(tri, "A"), "B"), "C");
    check(isempty(z.grid.rowGaps) && z.grid.rows == 1, 'removing the last panel drops the gap lists');
    x = remove(lr, "R2");
    check(x.grid.rows == 1 && x.panels(1).rowSpan == 1 && isequal(x.grid.rowHeights, 1) && isequal(cellsOf(x), [1 2]), ...
        'removePanel drops a row no panel starts in, shrinking the span across it');
    y = remove(remove(x, "R1"), "L");
    check(isempty(y.panels) && y.grid.rows == 1 && y.grid.cols == 1, 'removing the last panel leaves a 1 x 1 grid');
    check(strcmp(errorId(@() remove(lr, "Z")), 'EphysAnalysisConfig:NoPanel') ...
        && strcmp(errorId(@() place(lr, struct('type', "psth"), "below", "Z")), 'EphysAnalysisConfig:NoPanel') ...
        && strcmp(errorId(@() place(lr, struct('type', "psth"))), 'EphysAnalysisConfig:NoPanel') ...
        && strcmp(errorId(@() place(lr, struct('id', "R1", 'type', "psth"), "below", "L")), 'EphysAnalysisConfig:DuplicatePanelId'), ...
        'placePanel / removePanel: NoPanel (no or an unknown anchor), DuplicatePanelId');
    rp = EphysAnalysisConfig.normalizeFigure(FT.Figure{1});
    [m1, moved1] = move(rp, "psth_1", "up");
    [m2, moved2] = move(rp, "psth_1", "left");
    [m3, moved3] = move(lr, "R1", "left");
    [~, moved4] = move(rp, "raster_1", "up");
    [m5, moved5] = move(lr, "R1", "down");
    check(moved1 && isequal([m1.panels.row], [2 1]) && moved5 && m5.panels(2).row == 2 && m5.panels(3).row == 1, ...
        'movePanel swaps a panel with its same-shaped neighbor');
    check(~moved2 && isequaln(m2, rp) && ~moved3 && isequaln(m3, lr) && ~moved4, 'no neighbor there, or one of another shape: no move');
    ov = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 1, 'cols', 2), 'panels', ...
        {{struct('type', "psth", 'colSpan', 2), struct('type', "raster", 'col', 2)}}));
    [cl, over] = cellsOf(ov);
    check(isequal(cl, [1 1]) && isequal(over, [1 2]), 'figureCells lists overlapping panels once');

    % apply to all panels, re-link
    ap = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 4, 'cols', 1), 'panels', {{ ...
        struct('id', "p1", 'type', "psth", 'row', 1, 'ref', struct('line', "Platform"), ...
            'options', struct('bins', struct('BinSec', 0.05), 'baseline', struct('Mode', "zscore"), 'histStyle', "line", 'yLim', [0 9], ...
            'waveform', struct('mode', "mean"))), ...
        struct('id', "p2", 'type', "psth", 'row', 2, 'window', struct('mode', "fixed", 'pre', -1, 'post', 2)), ...
        struct('id', "c1", 'type', "continuous", 'row', 3, 'options', struct('statistic', "median")), ...
        struct('id', "h1", 'type', "heatmap", 'row', 4, 'options', struct('order', "peak"))}}));
    [ad, chg] = EphysAnalysisConfig.adoptPanelOptions(ap, "p1");
    check(ad.panels(2).options.bins.BinSec == 0.05 && ad.panels(2).options.baseline.Mode == "zscore" && ad.panels(2).options.histStyle == "line" ...
        && isequal(ad.panels(2).options.yLim, [0 9]) && ad.panels(2).options.waveform.mode == "mean" ...
        && ad.panels(4).options.bins.BinSec == 0.05 && ad.panels(4).options.baseline.Mode == "zscore" && ad.panels(4).options.order == "peak" ...
        && isequaln(ad.panels(3).options, ap.panels(3).options) && isequaln(ad.panels(1), ap.panels(1)) ...
        && isequal(ad.panels(2).window, ap.panels(2).window), ...
        ['adoptPanelOptions: the shared rows go to every panel that has them (the heat map''s bins and baseline), every option to ' ...
        'the panel of the same type; the continuous panel keeps its baseline (it takes no zscore)']);
    check(isequal([chg.id], ["p2" "c1" "h1"]) && isempty(setxor(chg(1).fields, ["bins" "baseline" "histStyle" "yLim" "waveform"])) ...
        && isempty(chg(1).kept) && isempty(chg(2).fields) && chg(2).kept == "baseline" ...
        && isempty(setxor(chg(3).fields, ["bins" "baseline"])) && isempty(chg(3).kept), ...
        'adoptPanelOptions says what changed: each panel''s changed options, and the panel that kept its baseline');
    [ad2, chg2] = EphysAnalysisConfig.adoptPanelOptions(ad, "p2");
    check(isequaln(ad2, ad) && isequal([chg2.id], "c1"), 'applied again: nothing changes (the continuous panel still keeps its baseline)');
    apS = ap;
    apS.panels(1).xSide = "top"; apS.panels(1).ySide = "right"; apS.panels(1).xLabel = "Lag (s)"; apS.panels(1).yLabel = "Rate";
    [adS, chgS] = EphysAnalysisConfig.adoptPanelOptions(apS, "p1");
    check(all([adS.panels.xSide] == "top") && all([adS.panels.ySide] == "right") && all([adS.panels(2:4).xLabel] == "") ...
        && all([adS.panels(2:4).yLabel] == "") && adS.panels(1).xLabel == "Lag (s)" && isequal([chgS.id], ["p2" "c1" "h1"]) ...
        && all(arrayfun(@(c) all(ismember(["xSide" "ySide"], c.fields)), chgS)) && isequaln(adS.panels(3).options, ap.panels(3).options), ...
        'adoptPanelOptions: the axis sides go to every panel, of any type (listed with the changed fields); the label texts stay the panel''s own');
    al = EphysAnalysisConfig.adoptPanelAlignment(ap, "p1");
    al2 = EphysAnalysisConfig.adoptPanelAlignment(ap, "p2");
    check(isstruct(al.ref) && al.ref.line == "Platform" && isequal(al.window, "default") && all([al.panels.ref] == "default") ...
        && all([al.panels.window] == "default") && isequal(al2.ref, "default") && al2.window.pre == -1, ...
        'adoptPanelAlignment: the panel''s own ref / window become the figure''s; every panel follows it');
    rl = EphysAnalysisConfig.relinkPanels(ap);
    check(all([rl.panels.ref] == "default") && all([rl.panels.window] == "default") ...
        && all(arrayfun(@(i) isequaln(rl.panels(i).options, ap.panels(i).options), 1:4)), ...
        'relinkPanels: every panel''s ref, window and selection linked again; the options stay each panel''s own');
    check(strcmp(errorId(@() EphysAnalysisConfig.adoptPanelOptions(ap, "zz")), 'EphysAnalysisConfig:NoPanel') ...
        && strcmp(errorId(@() EphysAnalysisConfig.adoptPanelAlignment(ap, "zz")), 'EphysAnalysisConfig:NoPanel'), ...
        'adoptPanelOptions / adoptPanelAlignment: NoPanel');
end

if S.sec("6", "config: validate")
    base = EphysAnalysisConfig();
    base.Source.Root = root;
    base = base.addFigure(Id="figure_1");   % an id of its own: the edits below keep it
    check(isempty(figIssues(base)), 'the rasterPsth figure validates clean');
    tc = base;
    for t = FT.Template.'
        tc = tc.addFigure(t, Id="t_" + t);
    end
    I = figIssues(tc);
    check(isempty(I(~startsWith(I.Field, "t_blank."), :)), 'every template validates clean but blank');
    check(has(tc, "t_blank.panels", "warning"), 'a blank figure has no panels');
    nf = EphysAnalysisConfig();
    nf.Source.Root = root;
    nf = nf.addFigure();
    I = nf.validate(CheckPaths=false);
    nf.Figures(1).enabled = false;
    I0 = nf.validate(CheckPaths=false);
    check(~any(I.Field == "enabled" & I.Severity == "error") && any(I0.Section == "Figures" & I0.Field == "enabled" ...
        & I0.Severity == "error" & I0.Message == "No figure is enabled."), ...
        'the "nothing enabled" rule counts figures: one enabled figure is something to run; none is "No figure is enabled."');

    % 1. ids
    b = base.addFigure("psth", Id="Figure_1");
    check(has(b, "Figure_1.id", "error"), 'figure ids that name the same files');
    b = base.addFigure("psth", Id="a:b");
    check(has(b, "a:b.id", "error"), 'a figure id that is not file-name safe');

    % 2. observe
    b = base; b.Figures(1).observe.data = "bogus";
    check(has(b, "figure_1.observe.data", "error"), 'observe.data is one of ObserveData');
    b = base; b.Figures(1).observe.channels = 0.5;
    check(has(b, "figure_1.observe.channels", "error"), 'observe.channels are whole numbers >= 1');
    b = base; b.Figures(1).observe.units.maxUnits = 0;
    check(has(b, "figure_1.observe.units.maxUnits", "error"), 'observe.units.maxUnits >= 1');
    b = base; b.Figures(1).sessions.datasets = "some";
    check(has(b, "figure_1.sessions.datasets", "error"), 'sessions.datasets is ticked or list');
    b = base; b.Figures(1).sessions.enabled = true; b.Figures(1).sessions.datasets = "list";
    check(has(b, "figure_1.sessions.datasetKeys", "warning"), 'a session figure''s "list" without dataset keys warns');
    b = base; b.Figures(1).observe.data = "dataset";
    check(has(b, "figure_1.observe.data", "error"), 'a layer following a dataset observation');
    b = base.addFigure("probemap", Id="pm"); b.Figures(2).observe.data = "units";
    check(has(b, "pm.observe.data", "warning") && ~has(base.addFigure("probemap", Id="pm"), "pm.observe.data", "warning"), ...
        'a unit observation that no layer follows warns (the probe map template observes the dataset: no warning)');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).observe.data = "MUA";
    check(has(b, "ct.continuous_1.layers(1).source", "warning"), 'an LFP layer following a MUA channel warns (the channel''s number)');
    auxFollow = layerOf("continuous"); auxFollow.source = "AUX";
    b = base; b.Figures(1) = place(b.Figures(1), struct('type', "continuous", 'layers', auxFollow), "below", "psth_1");
    check(has(b, "figure_1.continuous_1.layers(1).binding", "error"), 'AUX cannot follow a unit (no recording channel)');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.layers.source = "AUX";   % it observes LFP
    I = figIssues(b);
    check(any(I.Field == "ct.continuous_1.layers(1).binding" & I.Severity == "error" ...
        & I.Message == "AUX has no recording channel: bind it to fixed channels.") && ~has(b, "ct.continuous_1.layers(1).source", "warning"), ...
        'AUX cannot follow an LFP channel (no recording channel): an error, as the compute skips it');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).observe.data = "AUX";
    I = figIssues(b);
    check(any(I.Field == "ct.continuous_1.layers(1).binding" & I.Severity == "error" ...
        & I.Message == "The observed AUX channel has no recording channel for LFP to follow.") && ~has(b, "ct.continuous_1.layers(1).source", "warning"), ...
        'an LFP layer cannot follow an AUX channel (no recording channel): an error, as the compute skips it');

    % 3. grid
    b = base; b.Figures(1).grid.rows = 0;
    check(has(b, "figure_1.grid.rows", "error"), 'grid.rows is a whole number >= 1');
    b = base; b.Figures(1).grid.cols = 1.5;
    check(has(b, "figure_1.grid.cols", "error"), 'grid.cols is a whole number >= 1');
    b = base; b.Figures(1).grid.rowHeights = [1 2 3];
    check(has(b, "figure_1.grid.rowHeights", "error"), 'rowHeights: one per row');
    b = base; b.Figures(1).grid.colWidths = -1;
    check(has(b, "figure_1.grid.colWidths", "error"), 'colWidths: positive');
    b = base; b.Figures(1).grid.spacing = "wide";
    check(has(b, "figure_1.grid.spacing", "error"), 'grid.spacing is loose, compact, tight, none or custom');
    b = base; b.Figures(1).grid.gapUnits = "cm";
    check(has(b, "figure_1.grid.gapUnits", "error"), 'grid.gapUnits is px or %');
    b = base; b.Figures(1).grid.rowGap = -2;
    b2 = base; b2.Figures(1).grid.colGap = NaN;
    check(has(b, "figure_1.grid.rowGap", "error") && has(b2, "figure_1.grid.colGap", "error"), 'grid.rowGap and colGap are numbers >= 0');
    b = base; b.Figures(1).grid.spacing = "custom"; b.Figures(1).grid.rowGaps = [4 5];
    b2 = base; b2.Figures(1).grid.colGaps = 3;
    check(has(b, "figure_1.grid.rowGaps", "error") && has(b2, "figure_1.grid.colGaps", "error"), ...
        'rowGaps / colGaps: [] or a gap between every two rows / columns (two rows: one gap; one column: none)');
    b = base; b.Figures(1).grid.spacing = "custom"; b.Figures(1).grid.gapUnits = "%"; b.Figures(1).grid.rowGaps = 8;
    check(~any(figIssues(b).Severity == "error"), 'custom gaps in %, the one between the two rows listed: clean');
    b = base; b.Figures(1).panels(1).size = [1.2 1];
    b2 = base; b2.Figures(1).panels(1).size = [0.5 0];
    b3 = base; b3.Figures(1).panels(1).size = 0.5;
    check(has(b, "figure_1.raster_1.size", "error") && has(b2, "figure_1.raster_1.size", "error") && has(b3, "figure_1.raster_1.size", "error"), ...
        'a panel''s size is [width height], each over 0 and at most 1');
    b = base; b.Figures(1).panels(1).align = "middle";
    b2 = base; b2.Figures(1).panels(1).valign = "center";
    check(has(b, "figure_1.raster_1.align", "error") && has(b2, "figure_1.raster_1.valign", "error"), ...
        'a panel''s align is left, center or right; its valign top, middle or bottom');
    b = base; b.Figures(1).panels(1).size = [0.5 0.75]; b.Figures(1).panels(1).align = "right"; b.Figures(1).panels(1).valign = "top";
    check(~any(figIssues(b).Severity == "error"), 'a panel half its cell''s width and three quarters its height, at its top right: clean');

    % 4. panels
    b = base; b.Figures(1).panels(1).type = "violin";
    check(has(b, "figure_1.raster_1.type", "error"), 'an unknown panel type');
    b = base; b.Figures(1).panels(1).row = 0;
    check(has(b, "figure_1.raster_1.row", "error"), 'a panel''s row is a whole number >= 1');
    b = base; b.Figures(1).panels(2).rowSpan = 2;
    check(has(b, "figure_1.psth_1.row", "error"), 'a panel reaching past the grid''s rows');
    b = base; b.Figures(1).panels(2).colSpan = 2;
    check(has(b, "figure_1.psth_1.col", "error"), 'a panel reaching past the grid''s columns');
    b = base; b.Figures(1).panels(2).row = 1;
    check(has(b, "figure_1.psth_1.row", "error") && has(b, "figure_1.grid", "warning"), 'overlapping panels (and the cell they leave blank)');
    b = base; b.Figures(1).grid.rows = 3; b.Figures(1).grid.rowHeights = [];
    I = figIssues(b);
    check(has(b, "figure_1.grid", "warning") && contains(I.Message(I.Field == "figure_1.grid"), "(3,1)"), 'a cell no panel covers warns');

    % 5. layers
    evL = layerOf("raster"); evL.source = "events"; evL.binding = "fixed"; evL.event.line = "Stim";
    b = base; b.Figures(1).panels(1).layers(1).source = "spikes";
    check(has(b, "figure_1.raster_1.layers(1).source", "error"), 'a layer source not in FigureSources');
    b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.layers.source = "LFP";
    I = figIssues(b);
    check(any(I.Field == "wf.waveforms_1.layers(1).source" & I.Severity == "error" ...
        & I.Message == "A unit waveforms panel draws unit-summary layers, not LFP."), 'a source the panel type does not draw');
    b = base; b.Figures(1).panels(1).layers(1).source = "trials";
    check(has(b, "figure_1.raster_1.layers(1).source", "error"), 'trials is no layer source (the behavior panel type is gone)');
    b = base; b.Figures(1).panels(1).layers(1).binding = "both";
    check(has(b, "figure_1.raster_1.layers(1).binding", "error"), 'binding is observation or fixed');
    b = base; ev2 = evL; ev2.binding = "observation"; b.Figures(1).panels(1).layers(2) = ev2;
    check(has(b, "figure_1.raster_1.layers(2).binding", "error"), 'an events layer is always fixed');
    b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.layers.binding = "observation";
    check(has(b, "hm.heatmap_1.layers(1).binding", "error"), 'a heat map''s layers are fixed');
    b = base; b.Figures(1).panels(1).layers(1).enabled = false;
    check(has(b, "figure_1.raster_1.layers", "warning"), 'a panel without an enabled layer warns');
    b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.layers(2) = layerOf("waveforms");
    check(has(b, "wf.waveforms_1.layers", "warning"), 'two layers on a one-layer type warn');
    b = base; b.Figures(1).panels(2).layers(1).binding = "fixed";
    b2 = b; b2.Figures(1).panels(2).layers(1).units.ids = [1 2];
    check(has(b, "figure_1.psth_1.layers(1).units.maxUnits", "warning") && ~has(b2, "figure_1.psth_1.layers(1).units.maxUnits", "warning"), ...
        'a fixed layer of possibly more than 8 units drawn each in a PSTH warns');
    b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.type = "psth";   % a heat map's fixed all-units layer, its panel made a PSTH
    check(has(b, "hm.heatmap_1.layers(1).units.maxUnits", "warning"), ...
        'so does a heat map''s fixed all-units layer left in a panel made a PSTH (the app makes it follow the observation)');
    b = base; b.Figures(1).panels(1).layers(1).aggregate = "sum";
    check(has(b, "figure_1.raster_1.layers(1).aggregate", "error"), 'aggregate is each or mean');
    b = base; b.Figures(1).panels(1).layers(1).units.maxUnits = 0;
    check(has(b, "figure_1.raster_1.layers(1).units.maxUnits", "error"), 'a layer''s maxUnits >= 1');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.layers.channels = 1.5;
    check(has(b, "ct.continuous_1.layers(1).channels", "error"), 'a layer''s channels are whole numbers >= 1');
    b = base; b.Figures(1).panels(1).type = "behavior";
    check(has(b, "figure_1.raster_1.type", "error") && strcmp(errorId(@() base.addFigure("behavior")), 'EphysAnalysisConfig:BadValue'), ...
        'behavior is no panel type, nor a figure template');
    b = base; b.Figures(1).panels(1).layers(1).color = "plaid";
    check(has(b, "figure_1.raster_1.layers(1).color", "warning"), 'a layer color that is not one warns');
    b = base; b.Figures(1).panels(1).layers(1).lineStyle = "~";
    check(has(b, "figure_1.raster_1.layers(1).lineStyle", "error"), 'a layer''s line style');

    % 6. events layers
    b = base; b.Figures(1).panels(1).layers(2) = evL;
    check(isempty(figIssues(b)), 'events marks on a raster with rows validate clean');
    b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.layers(2) = evL;
    check(has(b, "pm.probemap_1.layers(2).source", "error"), 'events layers only on time panels');
    b = base.addFigure("continuous", Id="ct"); evT = evL; evT.eventsAs = "train"; b.Figures(2).panels.layers(2) = evT;
    b2 = base.addFigure("continuous", Id="ct"); b2.Figures(2).panels.layers(2) = evL;
    check(has(b, "ct.continuous_1.layers(2).eventsAs", "error") && isempty(figIssues(b2)), 'a train only on raster / psth / heatmap (marks on continuous)');
    b = base; evB = evL; evB.eventsAs = "bogus"; b.Figures(1).panels(1).layers(2) = evB;
    check(has(b, "figure_1.raster_1.layers(2).eventsAs", "error"), 'eventsAs is marks, train or span');
    evS = evL; evS.eventsAs = "span";
    b = base; b.Figures(1).panels(1).layers(2) = evS; b.Figures(1).panels(2).layers(2) = evS;
    b2 = base.addFigure("continuous", Id="ct"); b2.Figures(2).panels.layers(2) = evS;
    b3 = base; b3.Figures(1).panels(1).layers(1) = evS;
    check(isempty(figIssues(b)) && isempty(figIssues(b2)) && has(b3, "figure_1.raster_1.layers", "error"), ...
        'spans validate clean on a raster with rows, a PSTH and a continuous panel; a raster of spans alone has no rows');
    b = base; evS2 = evS; evS2.event.spanStyle = "~"; evS2.event.spanWidth = 0; evS2.event.spanAlpha = 2; b.Figures(1).panels(1).layers(2) = evS2;
    check(has(b, "figure_1.raster_1.layers(2).event.spanStyle", "error") && has(b, "figure_1.raster_1.layers(2).event.spanWidth", "error") ...
        && has(b, "figure_1.raster_1.layers(2).event.spanAlpha", "error"), 'a span''s line style, width and opacity');
    b = base.addFigure("eventTrace", Id="et");
    b.Figures(2).panels.layers(2) = evT;   % a train: eventsAs is not used on an event-trace panel
    b.Figures(2).panels.layers(3) = layerOf("raster");
    b.Figures(2).panels.layers(3).binding = "fixed";
    I = figIssues(b);
    check(isempty(I(I.Field ~= "et.eventTrace_1.layers(3).source", :)) && any(I.Field == "et.eventTrace_1.layers(3).source" & I.Severity == "error" ...
        & I.Message == "An event traces panel draws events layers only (a digital or derived line each), not units."), ...
        'an event-trace panel takes events layers only (a train among them is fine: eventsAs is not used there)');
    b = base.addFigure("eventTrace", Id="et");
    o = b.Figures(2).panels.options;
    o.display = "dots"; o.trials = "all"; o.colorBy = "unit"; o.height = 1.5; o.alpha = 2; o.edgeColor = "plaid"; o.edgeWidth = 0;
    o.lineStyle = "~"; o.baselineColor = "plaid"; o.baselineStyle = ""; o.baselineWidth = -1; o.rowSpacing = 0; o.lineWidth = NaN;
    o.minWidth = -1;
    b.Figures(2).panels.options = o;
    bad = ["display" "trials" "colorBy" "height" "alpha" "edgeWidth" "lineStyle" "baselineStyle" "baselineWidth" "rowSpacing" "lineWidth" ...
        "minWidth"];
    check(all(arrayfun(@(f) has(b, "et.eventTrace_1.options." + f, "error"), bad)) && has(b, "et.eventTrace_1.options.edgeColor", "warning") ...
        && has(b, "et.eventTrace_1.options.baselineColor", "warning"), 'an event-trace panel''s options: ' + strjoin(bad, ", ") + ...
        ' errors, a color that is not one a warning');
    b = base.addFigure("eventTrace", Id="et");
    o = b.Figures(2).panels.options;
    o.rasterSort = "event"; o.rasterSortOrder = "up";
    b.Figures(2).panels.options = o;
    b2 = b; b2.Figures(2).panels.options.trials = "rows";
    check(~has(b, "et.eventTrace_1.options.rasterSortEvent", "error") && ~has(b, "et.eventTrace_1.options.rasterSortOrder", "error") ...
        && has(b2, "et.eventTrace_1.options.rasterSortEvent", "error") && has(b2, "et.eventTrace_1.options.rasterSortOrder", "error"), ...
        'an event trace''s sort is checked as a raster''s with trials "rows" (no sort event, a bad order), not when overlaid');
    b = base.addFigure("eventTrace", Id="et"); b.Figures(2).sessions.enabled = true;
    check(~has(b, "et.eventTrace_1.type", "error") && figureSessionSkipReason(b.figureFor("et"), "") == "" ...
        && ~ismember("eventTrace", EphysAnalysisConfig.FigureSessionUnmerged), ...
        'a session figure may hold an event-trace panel (validate, figureSessionSkipReason)');
    b = base; b.Figures(1).panels(1).layers(1) = evL;
    b2 = base; b2.Figures(1).panels(1).layers(1) = evT;
    check(has(b, "figure_1.raster_1.layers", "error") && ~has(b2, "figure_1.raster_1.layers", "error"), 'a raster of marks alone has no rows (a train has)');
    b = base; evE = evL; evE.event.line = ""; b.Figures(1).panels(1).layers(2) = evE;
    check(has(b, "figure_1.raster_1.layers(2).event", "error"), 'the mark''s event reference is checked');
    b = base; evM = evL; evM.event.marker = "star"; evM.event.size = 0; evM.event.color = "nope"; b.Figures(1).panels(1).layers(2) = evM;
    check(has(b, "figure_1.raster_1.layers(2).event.marker", "error") && has(b, "figure_1.raster_1.layers(2).event.size", "error") ...
        && has(b, "figure_1.raster_1.layers(2).event.color", "warning"), 'the mark''s marker, size and color');

    % 7. the figure's alignment
    b = base; b.Figures(1).ref = struct('line', "Stim", 'edge', "middle");
    check(has(b, "figure_1.ref", "error"), 'the figure''s ref');
    b = base; b.Figures(1).window = struct('mode', "fixed", 'pre', 1, 'post', 0);
    check(has(b, "figure_1.window", "error"), 'the figure''s window');
    b = base; b.Figures(1).selection = struct('groupBy', ["A" "B" "C"]);
    check(has(b, "figure_1.selection", "error"), 'the figure''s selection (groupBy <= 2)');

    % 8. a panel's alignment
    b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.ref = struct('line', "Stim");
    check(has(b, "pm.probemap_1.ref", "error"), 'a panel''s own ref only on aligned types');
    b = base; b.Figures(1).panels(2).window = struct('mode', "fixed", 'pre', 1, 'post', 0);
    check(has(b, "figure_1.psth_1.window", "error"), 'a panel''s own window is checked');
    between = struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Platform"));
    b = base; b.Figures(1).window = between;
    b2 = base.addFigure("corrmap", Id="cm"); b2.Figures(2).window = between;
    check(has(b, "figure_1.raster_1.window", "error") && has(b, "figure_1.psth_1.window", "error") && isempty(figIssues(b2)), ...
        'a "between" window only on a unit correlation panel');

    % 9. options
    ub = base;
    o = "figure_1.raster_1.options.";
    b = base; b.Figures(1).panels(1).options.rasterSortOrder = "up";
    check(has(b, o + "rasterSortOrder", "error"), 'raster: rasterSortOrder');
    b = base; b.Figures(1).panels(1).options.rasterSort = "event";
    b2 = b; b2.Figures(1).panels(1).options.rasterSortEvent = struct('line', "Platform", 'edge', "middle");
    check(has(b, o + "rasterSortEvent", "error") && has(b2, o + "rasterSortEvent", "error"), 'raster: rasterSort "event" needs a valid rasterSortEvent');
    b = ub; b.Figures(1).panels(1).options.waveform.mode = "huge";
    check(has(b, o + "waveform.mode", "error"), 'raster: the waveform inset''s mode');
    b = ub; b.Figures(1).panels(1).options.waveform = struct('mode', "mean", 'width', 5, 'height', 0, 'location', "up", 'maxSpikes', 0.5, ...
        'ampScale', "x", 'timeMs', [1 -1]);
    check(has(b, o + "waveform.width", "error") && has(b, o + "waveform.height", "error") && has(b, o + "waveform.location", "error") ...
        && has(b, o + "waveform.maxSpikes", "error") && has(b, o + "waveform.ampScale", "error") && has(b, o + "waveform.timeMs", "error"), ...
        'raster: the waveform inset''s width, height, location, maxSpikes, ampScale, time span');
    b = ub; b.Figures(1).panels(1).options.waveform = struct('mode', "both", 'ampScale', "fixed");
    b2 = ub; b2.Figures(1).panels(1).options.waveform = struct('mode', "both", 'ampScale', "fixed", 'ampLim', [-80 40], 'timeMs', [-Inf 1]);
    check(has(b, o + "waveform.ampLim", "error") && ~has(b2, o + "waveform.ampLim", "error") && ~has(b2, o + "waveform.timeMs", "error"), ...
        'raster: a fixed waveform amplitude needs ampLim [lo hi]; a time span may run to the cut''s edge (-Inf)');
    o = "figure_1.psth_1.options.";
    b = ub; b.Figures(1).panels(2).options.bins.BinSec = 0; b.Figures(1).panels(2).options.bins.SmoothSec = -1;
    check(has(b, o + "bins.BinSec", "error") && has(b, o + "bins.SmoothSec", "error"), 'psth: bins');
    b = ub; b.Figures(1).panels(2).options.measure = "volts";
    check(has(b, o + "measure", "error"), 'psth: measure');
    b = ub; b.Figures(1).panels(2).options.baseline.Mode = "ratio";
    b2 = ub; b2.Figures(1).panels(2).options.baseline = struct('Mode', "subtract", 'Window', [0 -1]);
    check(has(b, o + "baseline.Mode", "error") && has(b2, o + "baseline.Window", "error"), 'psth: baseline mode (no ratio) and window');
    haveAuroc = license('test', 'Statistics_Toolbox') && exist('tiedrank', 'file');
    b = ub; b.Figures(1).panels(2).options.baseline.Mode = "auroc";
    b2 = b; b2.Figures(1).panels(2).options.auroc.windowSec = 0.015; b2.Figures(1).panels(2).options.auroc.cutoff = "maybe";
    b3 = b; b3.Figures(1).panels(2).options.auroc.modulatedOnly = true; b3.Figures(1).panels(2).options.auroc.cutoff = "none";
    check(~has(b, o + "baseline.Mode", "error") && has(b, o + "auroc", "error") == ~haveAuroc && has(b2, o + "auroc.windowSec", "error") ...
        && has(b2, o + "auroc.cutoff", "error") && has(b3, o + "auroc.modulatedOnly", "error"), ...
        'psth: the auROC baseline, its settings checked as a plot''s (windows of whole bins, cutoff, modulatedOnly)');
    b = ub; b.Figures(1).panels(2).options.stackSpacing = 0;
    b2 = ub; b2.Figures(1).panels(2).options.stack = "groups";
    b3 = ub; b3.Figures(1).panels(2).options.stack = "true";
    check(has(b, o + "stackSpacing", "error") && isempty(figIssues(b2)) && has(b3, o + "stack", "error"), ...
        'psth: stack (off or groups), and a positive stackSpacing');
    b = base; b.Figures(1).panels(2).options.histStyle = "pie"; b.Figures(1).panels(2).options.normalize = "max";
    b.Figures(1).panels(2).options.fillAlpha = 2; b.Figures(1).panels(2).options.yLim = [1 0];
    check(has(b, o + "histStyle", "error") && has(b, o + "normalize", "error") && has(b, o + "fillAlpha", "error") && has(b, o + "yLim", "error"), ...
        'psth: histStyle, normalize, fillAlpha, yLim');
    b = ub; b.Figures(1).panels(2).options.display = "image"; b.Figures(1).panels(2).options.cLim = [2 1];
    b2 = ub; b2.Figures(1).panels(2).options.colormap = "noSuchColormap";
    b3 = ub; b3.Figures(1).panels(2).options.display = "heatmap"; b3.Figures(1).panels(2).options.colormap = "turbo";
    b3.Figures(1).panels(2).options.cLim = [0 40];
    check(has(b, o + "display", "error") && has(b, o + "cLim", "error") && has(b2, o + "colormap", "warning") ...
        && ~has(b2, o + "colormap", "error") && isempty(figIssues(b3)), ...
        'psth: display (trace or heatmap), a colormap that is no function (a warning), cLim');
    b = base.addFigure("continuous", Id="ct");
    b.Figures(2).panels.options = struct('stack', "rows", 'statistic', "mode", 'transform', "log", 'errorType', "mad", 'stackSpacing', -1, ...
        'baseline', struct('Mode', "zscore"));
    o = "ct.continuous_1.options.";
    check(has(b, o + "stack", "error") && has(b, o + "statistic", "error") && has(b, o + "transform", "error") && has(b, o + "errorType", "error") ...
        && has(b, o + "stackSpacing", "error") && has(b, o + "baseline.Mode", "error"), 'continuous: stack, statistic, transform, errorType, stackSpacing, baseline');
    haveBoot = license('test', 'Statistics_Toolbox') && exist('bootci', 'file');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.options.errorType = "ci95";
    check(has(b, o + "errorType", "error") == ~haveBoot, 'continuous: the bootstrap CI needs the Statistics and Machine Learning Toolbox');
    b = base.addFigure("continuous", Id="ct"); b.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-1 -0.5]);
    b2 = base.addFigure("continuous", Id="ct"); b2.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-0.5 -0.1]);
    b3 = base.addFigure("continuous", Id="ct"); b3.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [-0.2 -0.15]);
    b3.Figures(2).panels.window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
    b4 = base.addFigure("heatmap", Id="hm"); b4.Figures(2).panels.layers.source = "LFP";
    b4.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [1 2]);
    b5 = base.addFigure("heatmap", Id="hm"); b5.Figures(2).panels.options.baseline = struct('Mode', "subtract", 'Window', [1 2]);
    check(has(b, o + "baseline", "error") && ~has(b2, o + "baseline", "error") && has(b3, o + "baseline", "error") ...
        && has(b4, "hm.heatmap_1.options.baseline", "error") && ~has(b5, "hm.heatmap_1.options.baseline", "error"), ...
        'a signal''s baseline window must overlap the panel''s resolved window (continuous, a heat map of a signal; not of spikes)');
    b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.options.order = "modulation"; b.Figures(2).panels.options.group = 0;
    b.Figures(2).panels.options.cLim = [2 1];
    o = "hm.heatmap_1.options.";
    check(has(b, o + "order", "error") && has(b, o + "group", "error") && has(b, o + "cLim", "error"), 'heatmap: order, group, cLim');
    b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.options.baseline.Mode = "auroc"; b.Figures(2).panels.options.order = "modulation";
    b2 = b; b2.Figures(2).panels.layers.source = "LFP";
    check(~has(b, o + "order", "error") && ~has(b, o + "baseline.Mode", "error") && has(b2, o + "baseline.Mode", "error") ...
        && has(b2, o + "order", "error"), 'heatmap: the auROC baseline and modulation order for spikes, not for a signal');
    b = base.addFigure("heatmap", Id="hm"); b.Figures(2).panels.layers.source = "LFP"; b.Figures(2).panels.options.baseline.Mode = "zscore";
    b2 = base.addFigure("heatmap", Id="hm"); b2.Figures(2).panels.options.baseline.Mode = "zscore";
    check(has(b, o + "baseline.Mode", "error") && isempty(figIssues(b2)), 'heatmap: z-score for spikes, not for a signal');
    b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.options.waveform.mode = "off";
    check(has(b, "wf.waveforms_1.options.waveform.mode", "error"), 'waveforms: the mode is never off');
    b = base.addFigure("waveforms", Id="wf"); b.Figures(2).panels.options.layout = "map";
    b2 = base.addFigure("waveforms", Id="wf"); b2.Figures(2).panels.options.layout = "probe";
    b3 = b2; b3.Figures(2).panels.layers(1).binding = "fixed"; b3.Figures(2).panels.layers(2) = layerOf("waveforms");
    check(has(b, "wf.waveforms_1.options.layout", "error") && has(b2, "wf.waveforms_1.options.layout", "warning") ...
        && isempty(figIssues(b3)), 'waveforms: layout grid or probe; a probe of the observed unit alone warns; a fixed layer ringing a following one is clean');
    b = base.addFigure("rate", Id="rt");
    b.Figures(2).panels.options = struct('display', "pie", 'measure', "volts", 'baseline', struct('Mode', "percent", 'Window', [-0.2 0]), 'yLim', [3 1]);
    o = "rt.rate_1.options.";
    b2 = base.addFigure("rate", Id="rt"); b2.Figures(2).panels.options.baseline.Mode = "percent";
    b3 = base.addFigure("rate", Id="rt"); b3.Figures(2).panels.options.baseline.Mode = "ratio";
    b4 = base.addFigure("rate", Id="rt"); b4.Figures(2).window = between;
    b5 = base.addFigure("rate", Id="rt"); b5.Figures(2).panels.layers.binding = "fixed";
    check(has(b, o + "display", "error") && has(b, o + "measure", "error") && has(b, o + "baseline.Mode", "error") && has(b, o + "yLim", "error") ...
        && has(b2, o + "baseline.Mode", "error") && isempty(figIssues(b3)) && isempty(figIssues(b4)) ...
        && has(b5, "rt.rate_1.layers(1).units.maxUnits", "warning"), ...
        'rate: display, measure, baseline (firingRate''s modes: ratio, not percent), yLim; a "between" window; many fixed units warn');
    b = base.addFigure("tuning", Id="tc");
    b.Figures(2).panels.options.param = "Depth"; b.Figures(2).panels.options.seriesParam = "Depth"; b.Figures(2).panels.options.waveform.mode = "huge";
    b2 = base.addFigure("tuning", Id="tc"); b2.Figures(2).panels.options.param = "not a name";
    b3 = base.addFigure("tuning", Id="tc"); b3.Figures(2).panels.options.param = "Depth"; b3.Figures(2).panels.options.seriesParam = "TrialType";
    b3.Figures(2).window = between;
    b4 = base.addFigure("tuning", Id="tc"); b4.Figures(2).panels.options.baseline.Mode = "auroc";
    o = "tc.tuning_1.options.";
    check(has(b, o + "seriesParam", "error") && has(b, o + "waveform.mode", "error") && has(b2, o + "param", "error") ...
        && isempty(figIssues(b3)) && has(b4, o + "baseline.Mode", "error"), ...
        'tuning: param and seriesParam (names, not the same), its waveform inset; a "between" window; no auROC baseline');
    b = base.addFigure("probemap", Id="pm"); b.Figures(2).panels.options.value = "x";
    check(has(b, "pm.probemap_1.options.value", "error"), 'probemap: value');
    b = base.addFigure("corrmap", Id="cm"); b.Figures(2).panels.options.metric = "max"; b.Figures(2).panels.options.correlation = "kendall";
    b2 = base.addFigure("corrmap", Id="cm"); b2.Figures(2).panels.options.metric = "peak"; b2.Figures(2).panels.options.bins.BinSec = 0;
    check(has(b, "cm.corrmap_1.options.metric", "error") && has(b, "cm.corrmap_1.options.correlation", "error") ...
        && has(b2, "cm.corrmap_1.options.bins.BinSec", "error"), 'corrmap: metric, correlation, bins of a peak rate');
    b3 = base; b3.Figures(1).panels(2).options.baseline.Mode = "auroc";
    b3.Figures(1).panels(2).options.bins.BinSec = 0.04;   % its bins: the 0.1 s auROC windows no longer fit
    check(has(b3, "figure_1.psth_1.options.auroc.windowSec", "error"), 'a PSTH''s auROC windows must be whole numbers of its bins');
    b = base.addFigure("waveforms", Id="wf");
    check(isempty(figIssues(b)), 'a waveforms panel''s own default waveform (mode "both") validates');

    % 10. the style (checkStyle)
    st = base.Figures(1).style;
    st.MaxTiles = 0; st.TileSpacing = "wide"; st.LegendLocation = "northeast"; st.LegendOrientation = "diagonal";
    st.ErrorType = "iqr"; st.ErrorResamples = 2.5; st.ErrorFaceAlpha = 1.5; st.ErrorFaceColor = "plaid"; st.ErrorEdgeColor = "nope";
    st.ErrorEdgeStyle = "~"; st.ErrorEdgeWidth = 0; st.FontSize = 0; st.LineWidth = 0; st.SiteSize = 0;
    st.Colormap = "nope"; st.HeatColormap = "notacolormap";
    expect = [ ...
        "MaxTiles"          "error"   "MaxTiles must be >= 1."
        "TileSpacing"       "error"   "TileSpacing is loose, compact, tight or none."
        "LegendLocation"    "error"   "LegendLocation is auto, inside, north, south, east or west."
        "LegendOrientation" "error"   "LegendOrientation is auto, vertical or horizontal."
        "ErrorType"         "error"   "ErrorType is sem (mean +/- SEM), std (mean +/- SD) or ci95 (bootstrap 95% CI)."
        "ErrorResamples"    "error"   "ErrorResamples is a whole number of bootstrap resamples, at least 1."
        "ErrorFaceAlpha"    "error"   "ErrorFaceAlpha is an opacity from 0 to 1 (NaN = opaque, the trace's color paled)."
        "ErrorFaceColor"    "warning" "No color ""plaid""; the bands take their trace's color."
        "ErrorEdgeColor"    "warning" "No color ""nope""; the bands have no edge."
        "ErrorEdgeStyle"    "error"   "ErrorEdgeStyle is one of -  --  :  -.."
        "ErrorEdgeWidth"    "error"   "ErrorEdgeWidth must be positive (points)."
        "FontSize"          "error"   "FontSize must be positive."
        "LineWidth"         "error"   "LineWidth must be positive."
        "SiteSize"          "error"   "SiteSize must be positive."
        "Colormap"          "warning" "No colormap function or color ""nope""; the default is used."
        "HeatColormap"      "warning" "No colormap function ""notacolormap""; the default is used."];
    b = base; b.Figures(1).style = st;
    I = figIssues(b);
    I = I(startsWith(I.Field, "figure_1.style."), :);
    check(isequal(I.Field, "figure_1.style." + expect(:, 1)) && isequal(I.Severity, expect(:, 2)) && isequal(I.Message, expect(:, 3)), ...
        'a figure''s style: every value checked, with these messages');
    b = base; b.Figures(1).style.ErrorType = "ci95";
    b2 = base; b2.Figures(1).style.ErrorType = "ci95"; b2.Figures(1).panels(2).type = "raster";
    check(has(b, "figure_1.style.ErrorType", "error") == ~haveBoot && ~has(b2, "figure_1.style.ErrorType", "error"), ...
        'a figure''s bootstrap CI needs the toolbox only where a panel draws the style''s error');

    % phase 4b: per-trial traces, a heat map of trials, a panel's own selection, per trial group
    b = base.addFigure("continuous", Id="ct");
    b.Figures(2).panels.options.trials = "faint";
    b.Figures(2).panels.options.maxTrials = 40;
    check(isempty(figIssues(b)), 'continuous trials "faint" with maxTrials 40 validates clean');
    b.Figures(2).panels.options.trials = "some";
    b.Figures(2).panels.options.maxTrials = 0.5;
    check(has(b, "ct.continuous_1.options.trials", "error") && has(b, "ct.continuous_1.options.maxTrials", "error"), ...
        'continuous trials is off / faint / only, maxTrials a whole number >= 1');
    hmT = EphysAnalysisConfig.defaultLayer("heatmap");
    hmT.binding = "observation";
    b = base.addFigure(struct('panels', {{struct('id', "ht", 'type', "heatmap", 'layers', hmT, ...
        'options', struct('rows', "trials", 'rasterSort', "stop"))}}), Id="trialmap");
    check(isempty(figIssues(b)), 'a heat map of trials following the observed unit validates clean (it may follow)');
    b2 = b; b2.Figures(2).panels.options.rows = "rows";
    check(has(b2, "trialmap.ht.options.rows", "error"), 'heat map rows are items or trials');
    b2 = b; b2.Figures(2).panels.layers.binding = "fixed";
    check(has(b2, "trialmap.ht.layers(1).units", "error"), 'a heat map of trials fixed to every unit: one unit only');
    b2.Figures(2).panels.layers.units.ids = 7;
    check(~has(b2, "trialmap.ht.layers(1).units", "error"), '... one fixed id is fine');
    b2 = b; b2.Figures(2).panels.layers.source = "LFP";
    check(has(b2, "trialmap.ht.options.rows", "error"), 'a heat map of trials of a signal: an error');
    b2 = b; b2.Figures(2).panels.options.baseline.Mode = "auroc";
    check(has(b2, "trialmap.ht.options.baseline.Mode", "error"), 'a heat map of trials takes no auROC baseline');
    b2 = b; b2.Figures(2).panels.options.rasterSort = "event";
    check(has(b2, "trialmap.ht.options.rasterSortEvent", "error"), 'a heat map of trials sorted by "event" needs its event (the raster''s rule)');
    b2 = b; b2.Figures(2).panels.options.rows = "items";
    check(has(b2, "trialmap.ht.layers(1).binding", "error"), 'a heat map of items still draws fixed layers only');
    b2 = b; b2.Figures(2).panels.layers.source = "detected";   % the observed units are sorted: the detections on its channel
    b3 = b; b3.Figures(2).observe.data = "LFP";               % every unit on the observed channel
    check(~has(b, "trialmap.ht.layers(1).binding", "error") && has(b2, "trialmap.ht.layers(1).binding", "error") ...
        && has(b3, "trialmap.ht.layers(1).binding", "error"), ...
        'a heat map of trials following through a channel (the other spike source, a channel observation): several units, an error');
    b = base; b.Figures(1).panels(2).selection = struct('groupBy', "TrialType");
    check(isempty(figIssues(b)), 'a PSTH with a trial selection of its own validates clean');
    b.Figures(1).panels(2).selection = struct('groupBy', ["A" "B" "C"]);
    check(has(b, "figure_1.psth_1.selection", "error"), 'a panel''s own selection is checked as the figure''s (groupBy <= 2)');
    b = base.addFigure("probemap", Id="pm6");
    b.Figures(2).panels.selection = struct('groupBy', "TrialType");
    check(has(b, "pm6.probemap_1.selection", "error"), 'a selection of its own only on an aligned panel type');
    b = base; b.Figures(1).observe.perGroup = true;
    b2 = b; b2.Defaults.Selection.groupBy = "Depth";
    check(has(b, "figure_1.observe.perGroup", "warning") && ~has(b2, "figure_1.observe.perGroup", "warning"), ...
        'perGroup warns while the figure''s selection groups by nothing');

    % 11. a panel's text note and overlays: the plot's rules, at "<figure>.<panel>.note.<field>" / ".overlays(<k>).<field>"
    b = base;
    nb = EphysAnalysisConfig.defaults("Note");
    nb.text = "n = 12";
    b.Figures(1).panels(2).note = nb;
    b.Figures(1).panels(2).overlays = EphysAnalysisConfig.defaults("Overlay");
    check(isempty(figIssues(b)), 'a panel with a note and an overlay validates clean');
    bx = b; bx.Figures(1).panels(2).box = "on";
    bx2 = b; bx2.Figures(1).panels(2).box = "maybe";
    check(isempty(figIssues(bx)) && has(bx2, "figure_1.psth_1.box", "error"), 'a panel''s box is auto, on or off (anything else is an error)');
    bx = b; bx.Figures(1).panels(2).xSide = "top"; bx.Figures(1).panels(2).ySide = "right"; bx.Figures(1).panels(2).xLabel = "Lag (s)";
    bx2 = b; bx2.Figures(1).panels(2).xSide = "left"; bx2.Figures(1).panels(2).ySide = "top";
    check(isempty(figIssues(bx)) && has(bx2, "figure_1.psth_1.xSide", "error") && has(bx2, "figure_1.psth_1.ySide", "error"), ...
        'a panel''s xSide is bottom or top, its ySide left or right (anything else is an error); a label is any text');
    nb.placement = "nowhere"; nb.align = "justify"; nb.valign = "up"; nb.interpreter = "latex"; nb.rotation = NaN;
    nb.fontSize = -1; nb.color = "plaid";
    b2 = b; b2.Figures(1).panels(2).note = nb;
    n0 = "figure_1.psth_1.note.";
    check(has(b2, n0 + "placement", "error") && has(b2, n0 + "align", "error") && has(b2, n0 + "valign", "error") ...
        && has(b2, n0 + "interpreter", "error") && has(b2, n0 + "rotation", "error") && has(b2, n0 + "fontSize", "error") ...
        && has(b2, n0 + "color", "warning"), 'a panel''s note: placement, alignments, interpreter, rotation, font size (errors), color (a warning)');
    b3 = b2; b3.Figures(1).panels(2).note.text = "";
    b4 = b; b4.Figures(1).panels(2).note.placement = "custom"; b4.Figures(1).panels(2).note.x = NaN;
    check(isempty(figIssues(b3)) && has(b4, n0 + "x", "error"), 'a note without text is not checked; a custom place needs a finite x and y');
    ov = EphysAnalysisConfig.defaults("Overlay");
    o1 = ov; o1.value = Inf;
    o2 = ov; o2.shape = "region"; o2.from = 0.1; o2.to = 0.1;
    o3 = ov; o3.axis = "z"; o3.layer = "middle"; o3.lineStyle = "~"; o3.lineWidth = 0; o3.alpha = 2; o3.color = "plaid";
    o4 = ov; o4.name = "Stim";
    o0 = "figure_1.psth_1.overlays";
    b5 = b; b5.Figures(1).panels(2).overlays = [o1 o2 o3 o4 o4];
    check(has(b5, o0 + "(1).value", "error") && has(b5, o0 + "(2).to", "error") && has(b5, o0 + "(3).axis", "error") ...
        && has(b5, o0 + "(3).layer", "error") && has(b5, o0 + "(3).lineStyle", "error") && has(b5, o0 + "(3).lineWidth", "error") ...
        && has(b5, o0 + "(3).alpha", "error") && has(b5, o0 + "(3).color", "warning") && has(b5, o0 + "(5).name", "warning") ...
        && ~has(b5, o0 + "(4).name", "warning"), ...
        'a panel''s overlays: a line''s position, a region''s edges, axis, layer, line style and width, opacity (errors), color and a shared name (warnings)');
    b6 = b; b6.Figures(1).panels(1).overlays = setfield(ov, 'panel', "data"); %#ok<SFLD>
    I6 = figIssues(b6);
    check(b6.Figures(1).panels(1).overlays.panel == "all" && ~any(contains(I6.Field, ".overlays(1).panel")), ...
        'a panel''s overlay names no panel: set to "data", it is "all" (its own axes), and no panel warning comes');
    I7 = b5.validate(CheckPaths=false);
    I7 = I7(contains(I7.Field, ".overlays(5).name"), :);
    check(height(I7) == 1 && contains(I7.Message, "Another overlay of this figure"), 'the shared-name warning names the figure');
    b8 = b; b8.Figures(1).panels(1).overlays = o4; b8.Figures(1).panels(2).overlays = o4;
    check(has(b8, "figure_1.psth_1.overlays(1).name", "warning") && ~has(b8, "figure_1.raster_1.overlays(1).name", "warning"), ...
        'two panels'' overlays of one name warn (one aesthetics rule on the name reaches both)');
    bR = base; kR = find([bR.Figures(1).panels.type] == "raster", 1);
    bRg = bR; bRg.Figures(1).panels(kR).options.tickColor = "groups";
    bRb = bR; bRb.Figures(1).panels(kR).options.tickColor = "";
    bRw = bR; bRw.Figures(1).panels(kR).options.tickWidth = 2;
    bRn = bR; bRn.Figures(1).panels(kR).options.tickWidth = -1;
    check(bR.Figures(1).panels(kR).options.tickColor == "groups" && bR.Figures(1).panels(kR).options.tickWidth == 0 ...
        && ~has(bRg, "figure_1.raster_1.options.tickColor", "warning") && has(bRb, "figure_1.raster_1.options.tickColor", "warning") ...
        && ~has(bRw, "figure_1.raster_1.options.tickWidth", "error") && has(bRn, "figure_1.raster_1.options.tickWidth", "error"), ...
        'a raster''s tickColor is "groups" or a color (default "groups"), its tickWidth 0 (the design''s) or a width in points');
    kP = find([bR.Figures(1).panels.type] == "psth", 1);
    bF = bR; bF.Figures(1).panels(kR).options.firstSpike.enabled = true;
    bF.Figures(1).panels(kP).options.latencyBox.enabled = true;
    bFw = bF; bFw.Figures(1).panels(kR).options.firstSpike.minSec = 0.2; bFw.Figures(1).panels(kR).options.firstSpike.maxSec = 0.1;
    bFo = bF; bFo.Figures(1).panels(kR).options.firstSpike.minSec = 10;
    bFc = bF; bFc.Figures(1).panels(kR).options.firstSpike.color = "nocolor";
    bFm = bF; bFm.Figures(1).panels(kR).options.firstSpike.marker = "blob";
    bFh = bF; bFh.Figures(1).panels(kP).options.latencyBox.boxHeight = 0.9;
    bFs = bF; bFs.Figures(1).panels(kP).options.latencyBox.lineStyle = "~";
    bFa = bF; bFa.Figures(1).panels(kP).options.latencyBox.fillAlpha = 2;
    bFx = bF; bFx.Figures(1).panels(kP).options.latencyBox.outlierMarker = "none";
    bFoff = bR; bFoff.Figures(1).panels(kP).options.latencyBox.boxHeight = 0.9;   % off: not checked
    oF = bR.Figures(1).panels(kR).options.firstSpike;
    oB = bR.Figures(1).panels(kP).options.latencyBox;
    rF = "figure_1.raster_1.options.firstSpike.";
    pB = "figure_1.psth_1.options.latencyBox.";
    check(~oF.enabled && oF.minSec == 0 && oF.maxSec == Inf && oF.marker == "o" && oF.color == "groups" && ~oB.enabled ...
        && oB.maxSec == Inf && oB.boxHeight == 0.1 && isempty(figIssues(bF)) && has(bFw, rF + "minSec", "error") ...
        && has(bFo, rF + "minSec", "warning") && ~has(bFo, rF + "minSec", "error") && has(bFc, rF + "color", "warning") ...
        && has(bFm, rF + "marker", "error") && has(bFh, pB + "boxHeight", "error") && has(bFs, pB + "lineStyle", "error") ...
        && has(bFa, pB + "fillAlpha", "error") && isempty(figIssues(bFx)) && isempty(figIssues(bFoff)), ...
        ['a raster''s firstSpike and a PSTH''s latencyBox: off by default (0 to the window''s end, groups); checked while on: ' ...
        'minSec <= maxSec, a window past the panel''s warns, a color, a marker, boxHeight 0.02-0.5, line style, fillAlpha']);
    bTc = bR; bTc.Figures(1).panels(kP).options.trialCount = "text";
    bTl = bR; bTl.Figures(1).panels(kP).options.trialCount = "legend";
    bTx = bR; bTx.Figures(1).panels(kP).options.trialCount = "all";
    bSl = bR; bSl.Figures(1).panels(kR).options.rasterSort = "latency";
    check(bR.Figures(1).panels(kP).options.trialCount == "off" && isempty(figIssues(bTc)) && isempty(figIssues(bTl)) ...
        && has(bTx, "figure_1.psth_1.options.trialCount", "error") && isempty(figIssues(bSl)), ...
        'a PSTH''s trialCount is off, text or legend (off by default); a raster may sort by latency');
    I9 = figIssues(b4);
    I9 = I9(I9.Field == n0 + "x", :);
    b10 = b2; b10.Figures(1).panels(2).type = "bogus";
    check(height(I9) == 1 && contains(I9.Message, "up the panel") && has(b10, "figure_1.psth_1.type", "error") ...
        && has(b10, n0 + "placement", "error"), 'a custom note''s message names the panel; a panel of an unknown type still has its note checked');
end

%% ============================================================================ compute
if S.sec("7", "compute: observations, bindings, panels and layers")
    fixtureA();
    cfg = EphysAnalysisConfig();
    cfg.Source.Root = FX.proj;
    cfg.Defaults.EventRef.line = "Stim";
    cfg.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    cfg.Defaults.Selection.groupBy = "Depth";
    cfg = cfg.addFigure("rasterPsth", Id="rp");
    cfg = cfg.addFigure("continuous", Id="ct");
    cfg = cfg.addFigure("probemap", Id="pm");
    rn = EphysAnalysisRunner(cfg, LogFcn=[]);
    src = rn.source(1);
    spec = cfg.figureFor("rp");
    % the oracles: the compute functions called directly, as a figure's panels call them (Defaults' alignment, every unit)
    D = cfg.Defaults;
    wD = D.Window;
    U0 = EphysAnalysisConfig.defaults("UnitSelection");
    varsObs =["kind" "label" "unitId" "channel" "column" "shank" "depth" "meta" "group" "groupLabel" "starred"];

    % observations
    Tu = figureObservations(src, spec);
    [~, mU] = selectUnits(src, spec.observe.units);
    ordU = probeOrder(mU, height(mU), spec.style);
    nU = height(Tu);
    check(nU == height(mU) && nU >= 2 && all(Tu.kind == "unit") && isequal(Tu.unitId, mU.unitId(ordU)) ...
        && isequal(Tu.channel, mU.channel(ordU)) && isequaln(Tu.depth, mU.y(ordU)) && all(isnan(Tu.column)) ...
        && isequal(string(Tu.Properties.VariableNames), varsObs) && isequal(Tu.meta{1}.unitId, Tu.unitId(1)) ...
        && all(arrayfun(@(k) contains(Tu.label(k), "ch " + Tu.channel(k)), 1:nU)), ...
        sprintf('figureObservations: the filter''s %d units in probe order ("%s", ...)', nU, Tu.label(1)));
    s2 = spec; s2.observe.units.ids = Tu.unitId([1 end]).';
    T2 = figureObservations(src, s2);
    s3 = spec; s3.observe.units.ids = 9999;
    T3 = figureObservations(src, s3);
    check(height(T2) == 2 && isequal(sort(T2.unitId), sort(Tu.unitId([1 end]))) && height(T3) == 0 ...
        && isequal(string(T3.Properties.VariableNames), varsObs), 'a tightened filter lists its units only; none left gives an empty table');
    sc = cfg.figureFor("ct");
    Tc = figureObservations(src, sc);
    [~, ~, mL] = selectChannels(src, "LFP");
    check(sc.observe.kind == "channel" && height(Tc) == height(mL) && all(Tc.kind == "channel") && isequal(sort(Tc.column), sort(mL.channel)) ...
        && isequal(Tc.channel, mL.recordingChannel(Tc.column)) && all(startsWith(Tc.label, "LFP ch ")) && all(isnan(Tc.unitId)), ...
        sprintf('figureObservations: the LFP channels of a continuous-only figure ("%s", ...)', Tc.label(1)));
    sp = cfg.figureFor("pm");
    Td = figureObservations(src, sp);
    check(sp.observe.kind == "dataset" && isscalar(Td.kind) && Td.kind == "dataset" && Td.label == src.name && isnan(Td.unitId), ...
        'figureObservations: one row, the dataset, for a dataset figure');

    % the stars (DatasetFavorites beside the data): the starred column, Starred only (observe.starred), the caption
    favS = DatasetFavorites(src);
    cleanStars = onCleanup(@() deleteQuiet(favS.File));
    check(~any(Tu.starred) && ~any(Tc.starred) && ~Td.starred, 'figureObservations: no favorites file, no star');
    favS.star("unit", Tu.unitId([1 end]));
    favS.star("channel", Tc.channel(2));
    sS = spec; sS.observe.starred = true;
    TuS = figureObservations(src, spec);
    TuF = figureObservations(src, sS);
    check(isequal(TuS.starred, ismember(TuS.unitId, Tu.unitId([1 end]))) && height(TuF) == 2 && all(TuF.starred) ...
        && isequal(TuF.unitId, Tu.unitId([1 end])) && isequal(string(TuF.Properties.VariableNames), varsObs), ...
        'figureObservations: the starred column marks the starred units; Starred only keeps just them, in probe order');
    scS = sc; scS.observe.starred = true;
    TcF = figureObservations(src, scS);
    check(isscalar(TcF.channel) && TcF.channel == Tc.channel(2) && TcF.starred, 'Starred only on an extract keeps the starred channel');
    sdet = cfg.figureFor("rp"); sdet.observe.data = "detected"; sdet.observe.kind = "unit"; sdet.observe.units.source = "detected";
    if src.hasDetected
        TdA = figureObservations(src, sdet);
        sdet.observe.starred = true;
        TdF = figureObservations(src, sdet);
        check(isequal(TdA.starred, TdA.channel == Tc.channel(2)) && height(TdF) == nnz(TdA.starred) && all(TdF.starred), ...
            'a detection channel is starred as its recording channel; Starred only keeps those');
    end
    spS = sp; spS.observe.starred = true;
    TdNo = figureObservations(src, spS);
    favS.star("dataset");
    TdYes = figureObservations(src, spS);
    check(height(TdNo) == 0 && isscalar(TdYes.kind) && TdYes.starred, 'Starred only on a dataset figure: the dataset only when it is starred');
    favMem = DatasetFavorites(src);
    favMem.star("unit", Tu.unitId(2));   % Favorites= is used as given, not read again
    TuM = figureObservations(src, sS, Favorites=favMem);
    check(height(TuM) == 3 && ismember(Tu.unitId(2), TuM.unitId), 'figureObservations Favorites=: the stars given');
    favMem.star("unit", Tu.unitId(2), false);
    capS = figureCaption(spec, TuS, Dataset=src.name);
    capF = figureCaption(sS, TuF);
    capN = figureCaption(spec, Tu);
    check(contains(capS, sprintf("%d observations (sorted units", nU)) && contains(capS, "; 2 starred) of " + src.name) ...
        && startsWith(capF, "rp: 2 observations (sorted units") && contains(capF, "; starred only);") ...
        && ~contains(capN, "starred"), "figureCaption: the stars counted, Starred only named: " + capS + " / " + capF);
    favS.star("dataset", [], false);
    favS.star("unit", Tu.unitId([1 end]), false);
    favS.star("channel", Tc.channel(2), false);
    check(~isfile(favS.File), 'the stars taken away again');

    % raster + PSTH of one unit
    F1 = rn.computeFigure(src, spec);
    L1 = F1.panels(1).layers;
    L2 = F1.panels(2).layers;
    check(F1.kind == "figure" && F1.id == "rp" && F1.dataset == src.name && F1.observation.kind == "unit" ...
        && F1.observation.unitId == Tu.unitId(1) && F1.observation.label == Tu.label(1) && isequal([F1.panels.id], ["raster_1" "psth_1"]) ...
        && all([F1.panels.sharesTime]) && isempty(F1.panels(1).epochs) && istable(F1.epochs) && isequal(F1.panels(2).groups, F1.groups), ...
        'computeFigure: the first observation by default; both panels on the figure''s epochs and groups');
    check(isscalar(L1) && L1.skip == "" && L2.skip == "" && isscalar(L1.R.raster) && size(L2.R.rate, 2) == 1 ...
        && L1.meta.unitId == Tu.unitId(1) && L2.meta.unitId == Tu.unitId(1) && L2.name == shortUnitLabels(Tu.meta{1}.label) ...
        && L2.binding == "observation" && L2.category == "point", 'one unit in each layer''s R: the observed one, named by its label');
    [Eo, Go] = epochsOf([]);
    [sto, mo] = unitsOf();
    Rp = spikePSTH(sto, Eo, Window=[wD.pre wD.post], BinSec=0.01, SmoothSec=0.01, Measure="rate", Raster=true, Groups=Go, Meta=mo, ...
        ErrorType="sem", ErrorResamples=1000);
    u1 = find(Rp.meta.unitId == Tu.unitId(1));
    check(isscalar(u1) && isequaln(L2.R.rate, Rp.rate(:, u1, :)) && isequaln(L2.R.err.lo, Rp.err.lo(:, u1, :)) ...
        && isequaln(F1.epochs.t0, Eo.t0), 'the PSTH layer is spikePSTH''s PSTH of that unit over every unit''s epochs (the same epochs, bins and band)');
    F2 = rn.computeFigure(src, spec, Observation=Tu(2, :));
    Fs = rn.computeFigure(src, spec, Observation=struct('kind', "unit", 'unitId', Tu.unitId(2), 'channel', Tu.channel(2)));
    check(F2.observation.unitId == Tu.unitId(2) && F2.panels(2).layers(1).meta.unitId == Tu.unitId(2) ...
        && isequaln(Fs.panels(2).layers(1).R.rate, F2.panels(2).layers(1).R.rate), 'Observation= picks another unit (a table row or a struct)');

    % what an earlier compute made is taken again (Reuse): a look edit computes nothing, a data edit its panel only
    [Fr1, K1] = figureCompute(src, spec, Observation=Tu(1, :));
    [Fr2, K2] = figureCompute(src, spec, Observation=Tu(1, :), Reuse=K1);
    sl = spec;   % looks only: the titles, the grid, a font, a tick color, a layer's color, a note
    sl.title = "Looks"; sl.grid.spacing = "loose"; sl.style.FontSize = 13; sl.panels(1).title = "Rows";
    sl.panels(1).options.tickColor = "red"; sl.panels(2).layers(1).color = "#ff0000"; sl.panels(2).note.text = "a note";
    [Fr3, K3] = figureCompute(src, sl, Observation=Tu(1, :), Reuse=K2);
    sd = spec;   % the PSTH's bins
    sd.panels(2).options.bins.BinSec = 0.02;
    [Fr4, K4] = figureCompute(src, sd, Observation=Tu(1, :), Reuse=[K3 K2]);
    Fr5 = figureCompute(src, sd, Observation=Tu(1, :));
    [~, K6] = figureCompute(src, spec, Observation=Tu(2, :), Reuse=K2);
    made = @(K) sort(unique([K([K.from] == 0).kind]));
    check(~isempty(K1) && all([K1.from] == 0) && isequal(sort(unique([K1.kind])), ["epochs" "panel" "skip"]) ...
        && all([K2.from] > 0) && isequaln(Fr2.panels, Fr1.panels) && isequaln(Fr2.epochs, Fr1.epochs) && isequaln(Fr2.groups, Fr1.groups), ...
        'figureCompute Reuse: the same spec and observation take every step again (skip reasons, epochs, each panel), the same result');
    check(all([K3.from] > 0) && isequaln(Fr3.panels, Fr1.panels) && isequaln(Fr3.spec, sl), ...
        'an edit of the looks only (titles, grid, font, a tick or layer color, a note) computes nothing again');
    check(isequal(made(K4), ["panel" "skip"]) && nnz([K4.from] == 0 & [K4.kind] == "panel") == 1 && isequaln(Fr4.panels(1), Fr1.panels(1)) ...
        && isequaln(noCreated(Fr4.panels(2)), noCreated(Fr5.panels(2))) && ~isequaln(noCreated(Fr4.panels(2)), noCreated(Fr1.panels(2))), ...
        'an edit of the PSTH''s bins computes that panel (and the skip reasons) again, as a compute from scratch; the raster is taken again');
    check(isequal(made(K6), "panel") && nnz([K6.from] == 0) == 2, 'another observation computes its panels again, on the epochs kept');
    % the figure's own epochs, as the Export code script takes them: figureCompute's
    [Ee, Ge] = figureEpochs(src, spec);
    sb = spec;   % a PSTH baseline reaching before the recording for the first event, a raster sorted by a trial parameter
    sb.panels(2).options.baseline.Mode = "subtract";
    sb.panels(2).options.baseline.Window = [-(min(Ee.t0) + 0.005) 0];
    sb.panels(1).options.rasterSort = "Depth";
    Fb = figureCompute(src, sb, Observation=Tu(1, :));
    [Eb, Gb] = figureEpochs(src, sb);
    check(isequaln(Ee, Fr1.epochs) && isequaln(Ge, Fr1.groups) && isequaln(Eb, Fb.epochs) && isequaln(Gb, Fb.groups) ...
        && height(Eb) == height(Ee) - 1 && ismember("Depth", string(Eb.Properties.VariableNames)), ...
        'figureEpochs: the figure''s epochs and groups as figureCompute aligns them (a panel''s baseline drops the epoch it takes out of the recording, a raster''s sort parameter is copied)');
    rnC = EphysAnalysisRunner(cfg, LogFcn=[]);
    srcC = rnC.source(1);
    FC1 = rnC.computeFigure(srcC, spec, Observation=Tu(1, :), Reuse=true);
    nC = numel(rnC.FigureCache);
    FC2 = rnC.computeFigure(srcC, sl, Observation=Tu(1, :), Reuse=true);
    nC2 = numel(rnC.FigureCache);
    rnC.computeFigure(srcC, spec, Observation=Tu(1, :));   % a run's compute: nothing kept
    nC3 = numel(rnC.FigureCache);
    rnC.clearSources();
    check(nC == numel(K1) && nC2 == nC && nC3 == nC && isempty(rnC.FigureCache) && isequaln(FC2.panels, FC1.panels) ...
        && isequaln(arrayfun(@noCreated, FC1.panels, 'UniformOutput', false), arrayfun(@noCreated, Fr1.panels, 'UniformOutput', false)) && rnC.FigureCacheMB > 0, ...
        sprintf(['computeFigure Reuse=true keeps what it computed in FigureCache (%d entries) and takes it again for a look edit; ' ...
        'a compute without Reuse keeps nothing; clearSources forgets it'], nC));

    % a continuous panel: LFP following the unit, AUX fixed, AUX following (skipped)
    lfpL = EphysAnalysisConfig.defaultLayer("continuous");
    auxL = lfpL; auxL.source = "AUX"; auxL.binding = "fixed"; auxL.channels = [1 2]; auxL.aggregate = "mean";
    auxF = lfpL; auxF.source = "AUX";
    stack = EphysAnalysisConfig.placePanel(cfg.Figures(cfg.figureIndex("rp")), ...
        struct('id', "sig", 'type', "continuous", 'layers', [lfpL auxL auxF]), "below", "psth_1");
    stack.id = "stack";
    cfg = cfg.addFigure(stack);
    ss = cfg.figureFor("stack");
    F3 = rn.computeFigure(src, ss, Observation=Tu(2, :));
    Ls = F3.panels(3).layers;
    [Yl, fsl] = selectChannels(src, "LFP");
    col = find(mL.recordingChannel == Tu.channel(2), 1);
    Rref = evokedPotential(Yl, fsl, F3.epochs, Window=[ss.window.pre ss.window.post], Channels=col, Groups=F3.groups, Meta=mL(col, :));
    check(Ls(1).skip == "" && isequal(Ls(1).R.channels, col) && isequaln(Ls(1).R.mean, Rref.mean) && Ls(1).name == "LFP ch " + Tu.channel(2) ...
        && Ls(1).meta.recordingChannel == Tu.channel(2), 'an LFP layer following the unit reads the column of its recording channel, as evokedPotential does');
    d2 = Ls(2).R.layerMean;
    check(Ls(2).skip == "" && isequal(Ls(2).R.channels(:).', [1 2]) && Ls(2).R.units == "V" && size(Ls(2).R.mean, 2) == 2 ...
        && isequaln(d2.mean, mean(Ls(2).R.mean, 2, 'omitnan')) && isequal(size(d2.lo), size(d2.mean)) && d2.over == "channels" && d2.n == 2, ...
        'a fixed AUX layer reads its columns; aggregate "mean" adds their mean with a band across them (R.layerMean)');
    auxMsg = "AUX has no recording channel: bind it to fixed channels";
    [~, lr] = figureSkipReason(src, ss);
    hit = [lr.panel] == "sig" & [lr.layer] == 3;
    check(Ls(3).skip == auxMsg && isempty(Ls(3).R) && F3.panels(3).skip == "" && isscalar(lr(hit)) && lr(hit).reason == auxMsg ...
        && all([lr(~hit).reason] == ""), 'an AUX layer following a unit is skipped with its reason (figureSkipReason''s too); the others are computed');
    sm = ss;
    sm.panels(3).layers = auxL;
    sm.panels(3).options.transform = "magnitude";
    sm.panels(3).options.baseline.Mode = "subtract";
    sm.panels(3).options.baseline.Window = [ss.window.pre 0];
    Fm = rn.computeFigure(src, sm, Observation=Tu(2, :));
    Lm = Fm.panels(3).layers(1);
    [Ya, fsa, mA] = selectChannels(src, "AUX");
    Rm = evokedPotential(Ya, fsa, Fm.epochs, Window=[ss.window.pre ss.window.post], Channels=[1 2], Baseline=[ss.window.pre 0], ...
        Groups=Fm.groups, Meta=mA([1 2], :), Units=mA.units(1), Magnitude=true);
    check(Lm.skip == "" && size(Lm.R.mean, 2) == 1 && Lm.R.magnitude && isequaln(Lm.R.mean, Rm.mean) ...
        && Lm.name == "magnitude of 2 AUX channels", ...
        'transform "magnitude": the AUX layer''s channels as one trace, their vector magnitude after the baseline (evokedPotential''s Magnitude)');

    % a fixed point layer keeping three units, aggregate "mean"
    n3 = min(3, nU);
    fx = EphysAnalysisConfig.defaultLayer("psth");
    fx.binding = "fixed"; fx.units.ids = Tu.unitId(1:n3).'; fx.aggregate = "mean";
    cfg = cfg.addFigure(struct('panels', {{struct('id', "mean3", 'type', "psth", 'layers', fx)}}), Id="agg");
    sa = cfg.figureFor("agg");
    Fa = rn.computeFigure(src, sa);
    Ra = Fa.panels(1).layers(1).R;
    semU = std(Ra.rate, 0, 2, 'omitnan') / sqrt(n3);
    check(sa.observe.kind == "dataset" && Fa.observation.kind == "dataset" && size(Ra.rate, 2) == n3 && isequal(sort(Ra.meta.unitId), sort(Tu.unitId(1:n3))) ...
        && isequaln(Ra.layerMean.mean, mean(Ra.rate, 2, 'omitnan')) && Ra.layerMean.n == n3 && Ra.layerMean.over == "units" ...
        && max(abs(Ra.layerMean.hi - Ra.layerMean.mean - semU), [], 'all') < 1e-9 && Fa.panels(1).layers(1).name == "mean of " + n3 + " units", ...
        sprintf('a fixed layer keeping %d units, aggregate "mean": each in R.rate, their mean +/- SEM across them in R.layerMean', n3));

    % events: marks and a train
    ev = EphysAnalysisConfig.defaultLayer("raster");
    ev.source = "events"; ev.binding = "fixed"; ev.event.line = "Stim";
    tr = ev; tr.eventsAs = "train";
    fe = cfg.Figures(cfg.figureIndex("rp"));
    fe.id = "events";
    fe.panels(1).layers = [fe.panels(1).layers ev tr];
    fe.panels(2).layers = tr;
    cfg = cfg.addFigure(fe);
    se = cfg.figureFor("events");
    Fe = rn.computeFigure(src, se, Observation=Tu(1, :));
    Lm = Fe.panels(1).layers(2);
    Lt = Fe.panels(1).layers(3);
    Lp = Fe.panels(2).layers(1);
    M = epochEvents(src, Fe.epochs, Sequences=eventMarkRef(ev.event));
    nE = height(Fe.epochs);
    check(Lm.skip == "" && Lm.R.kind == "events" && isequaln(Lm.R.marks, M) && Lm.name == "Stim onset" && Lm.eventsAs == "marks", ...
        'events marks: epochEvents of the line over the figure''s epochs, named by the line');
    at0 = abs(Lt.R.raster.times) < 1e-9;
    check(Lt.skip == "" && Lt.name == "Stim onset" && Lt.R.labels == "Stim onset" && Lt.R.meta.class == "event" && Lt.eventsAs == "train" ...
        && isscalar(Lt.R.raster) && isequal(unique(Lt.R.raster.epoch(at0)).', 1:nE), ...
        'events as a train: a one-unit spike train named by the line, with a raster event at 0 in every epoch');
    [~, kPk] = max(sum(Lp.R.rate, 3));
    check(Lp.skip == "" && abs(Lp.R.edges(kPk)) < 1e-9 && nnz(abs(M.t) < 1e-9) == nE && nnz(at0) == nE, ...
        'the train''s PSTH of the Stim line peaks in the bin from 0 when aligned to Stim onset, as epochEvents'' latencies of 0 say');

    % events as spans, and an event-trace panel (the Stim and Platform lines, a units layer it refuses); intervalsOf is the oracle
    spanL = ev; spanL.eventsAs = "span";
    fSpan = cfg.Figures(cfg.figureIndex("rp"));
    fSpan.id = "spans";
    fSpan.panels(1).layers = [fSpan.panels(1).layers spanL];
    fSpan.panels(2).layers = [fSpan.panels(2).layers spanL];
    cfg = cfg.addFigure(fSpan);
    Fsp = rn.computeFigure(src, cfg.figureFor("spans"), Observation=Tu(1, :));
    Ss = Fsp.panels(1).layers(2);
    [epS, onS, offS] = intervalsOf("Stim", Fsp.epochs);
    check(Ss.skip == "" && Ss.R.kind == "events" && isempty(Ss.R.marks) && isequal(Ss.R.spans.epoch, epS) ...
        && max(abs(Ss.R.spans.on - onS)) < 1e-9 && max(abs(Ss.R.spans.off - offS)) < 1e-9 ...
        && Ss.eventsAs == "span" && Ss.name == "Stim onset" && isequaln(Fsp.panels(2).layers(2).R.spans, Ss.R.spans), ...
        sprintf('events as spans: each epoch''s Stim intervals from onset to offset (%d), the same on the raster and the PSTH', numel(onS)));
    et2 = ev; et2.event.line = "Platform";
    etU = layerOf("raster"); etU.binding = "fixed";
    cfg = cfg.addFigure(struct('panels', {{struct('id', "et", 'type', "eventTrace", 'layers', [ev et2 etU])}}), Id="trace");
    Ftrace = rn.computeFigure(src, cfg.figureFor("trace"));
    Lt1 = Ftrace.panels(1).layers(1);
    Lt2 = Ftrace.panels(1).layers(2);
    [epP, onP, offP] = intervalsOf("Platform", Ftrace.epochs);
    check(Ftrace.panels(1).sharesTime && Lt1.skip == "" && Lt1.R.kind == "eventTrace" && Lt1.name == "Stim" && Lt2.name == "Platform" ...
        && isequal(Lt2.R.epoch, epP) && max(abs(Lt2.R.on - onP)) < 1e-9 && max(abs(Lt2.R.off - offP)) < 1e-9 ...
        && Lt1.R.nEpochs == height(Ftrace.epochs) && isequal(size(Lt1.R.window), [height(Ftrace.epochs) 2]) ...
        && contains(Ftrace.panels(1).layers(3).skip, "event-trace panels do not draw units"), ...
        sprintf('an event-trace panel: each line''s intervals overlapping each epoch (%d Platform), named by the line; a units layer skipped', numel(onP)));
    srcZ = src;
    srcZ.events.Stim(:, 2) = srcZ.events.Stim(:, 1);   % every interval a single instant
    check(strcmp(errorId(@() epochIntervals(srcZ, Ftrace.epochs, eventMarkRef(ev.event))), 'epochIntervals:NoOffsets') ...
        && isempty(epochIntervals(src, Ftrace.epochs, struct('line', "Stim", 'which', "all", 'timeRange', [1e6 Inf], 'scope', "recording")).on), ...
        'a line without an offset after its onsets is refused (epochIntervals:NoOffsets); a reference picking no event gives no interval');
    check(isequal(Lt1.R.epochGroup, double(Ftrace.epochs.groupIndex)) && isequaln(Lt1.R.epochStop, Ftrace.epochs.t1 - Ftrace.epochs.t0) ...
        && isequal(Lt1.R.groups, Ftrace.groups) && height(Lt1.R.epochs) == height(Ftrace.epochs) && ~isfield(Lt1.R, 'rasterSortEvent'), ...
        'an event trace''s result holds what sorts its sub-rows: each epoch''s group and stop latency, the groups and the epochs');
    srcZ1 = src;   % one Stim interval in the first epoch made zero length: kept among the others
    kZ = find(src.events.Stim(:, 1) >= Ftrace.epochs.tStart(1) & src.events.Stim(:, 1) <= Ftrace.epochs.tStop(1), 1);
    srcZ1.events.Stim(kZ, 2) = srcZ1.events.Stim(kZ, 1);
    FtZ = rn.computeFigure(srcZ1, cfg.figureFor("trace"));
    RZ = FtZ.panels(1).layers(1).R;
    zOn = src.events.Stim(kZ, 1) - Ftrace.epochs.t0(1);
    check(numel(RZ.on) == numel(Lt1.R.on) && any(RZ.on == RZ.off & abs(RZ.on - zOn) < 1e-9 & RZ.epoch == 1), ...
        'a zero-length interval among longer ones is kept (onset = offset), not dropped');
    cfg = cfg.addFigure(struct('panels', {{struct('id', "et", 'type', "eventTrace", 'layers', [ev et2], 'options', ...
        struct('trials', "rows", 'rasterSort', "event", 'rasterSortEvent', struct('line', "Platform", 'edge', "onset")))}}), Id="traceSort");
    FtS = rn.computeFigure(src, cfg.figureFor("traceSort"));
    oS = FtS.spec.panels(1).options;
    [tS, labS] = eventLatency(src, FtS.epochs, oS.rasterSortEvent);
    check(all(arrayfun(@(l) isequaln(l.R.rasterSortEvent.t, tS) && l.R.rasterSortEvent.label == labS, FtS.panels(1).layers)), ...
        sprintf('trials "rows" sorted by an event: each layer''s result holds the epochs'' latencies to it (%s)', labS));

    % a panel's own window
    fo = cfg.Figures(cfg.figureIndex("rp"));
    fo.id = "own";
    fo.panels(2).window = struct('mode', "fixed", 'pre', -0.1, 'post', 0.3);
    cfg = cfg.addFigure(fo);
    so = cfg.figureFor("own");
    Fo = rn.computeFigure(src, so, Observation=Tu(1, :));
    Po = Fo.panels(2);
    check(istable(Po.epochs) && ~Po.sharesTime && Fo.panels(1).sharesTime && isempty(Fo.panels(1).epochs) ...
        && all(abs(Po.epochs.tStop - Po.epochs.t0 - 0.3) < 1e-9) && all(abs(Po.epochs.tStart - Po.epochs.t0 + 0.1) < 1e-9) ...
        && isequal(Po.groups.label, Fo.groups.label) && sum(Po.groups.n) == height(Po.epochs) ...
        && all(abs(Po.layers(1).R.window - [-0.1 0.3]) < 1e-9) && isequal(Po.layers(1).R.groups.label, Fo.groups.label), ...
        'a panel''s own window: its own epochs over it, with the figure''s groups');

    % a channel observation
    k1 = find(Tc.channel == Tu.channel(1), 1);
    fc = cfg.Figures(cfg.figureIndex("ct"));
    fc.id = "chan";
    fc.observe.data = "LFP";
    muaL = lfpL; muaL.source = "MUA";
    fc.panels(1).layers = [fc.panels(1).layers muaL];
    fc = EphysAnalysisConfig.placePanel(fc, struct('id', "r", 'type', "raster", 'layers', EphysAnalysisConfig.defaultLayer("raster")), ...
        "below", "continuous_1");
    cfg = cfg.addFigure(fc);
    sch = cfg.figureFor("chan");
    Fc = rn.computeFigure(src, sch, Observation=Tc(k1, :));
    [~, ~, mM] = selectChannels(src, "MUA");
    Lc = Fc.panels(1).layers;
    check(isscalar(k1) && Fc.observation.kind == "channel" && Fc.observation.column == Tc.column(k1) && isequal(Lc(1).R.channels, Tc.column(k1)) ...
        && isequal(Lc(2).R.channels, find(mM.recordingChannel == Tc.channel(k1), 1)) && Fc.panels(2).layers(1).skip == "" ...
        && all(Fc.panels(2).layers(1).meta.channel == Tc.channel(k1)) && any(Fc.panels(2).layers(1).meta.unitId == Tu.unitId(1)), ...
        'a channel observation: its own column, the same recording channel in the MUA extract, the units on that channel');

    % a panel whose only layer is skipped (an AUX layer following a unit)
    auxOnly = EphysAnalysisConfig.defaultLayer("continuous");
    auxOnly.source = "AUX";
    cfg = cfg.addFigure(struct('observe', struct('data', "units"), 'panels', {{struct('id', "auxonly", 'type', "continuous", ...
        'layers', auxOnly)}}), Id="auxonly");
    Fn = rn.computeFigure(src, cfg.figureFor("auxonly"), Observation=Tu(1, :));
    check(Fn.panels(1).skip == "" && Fn.panels(1).layers(1).skip == auxMsg && isempty(Fn.panels(1).layers(1).R), ...
        'a panel whose only layer is skipped keeps the layer and its reason');

    % a parameter or a baseline the panel cannot use skips it, not the figure
    fr = cfg.Figures(cfg.figureIndex("rp"));
    fr.id = "nosort";
    fr.panels(1).options.rasterSort = "NoSuchSort";
    cfg = cfg.addFigure(fr);
    Fr = rn.computeFigure(src, cfg.figureFor("nosort"), Observation=Tu(1, :));
    check(~ismember("NoSuchSort", string(src.trials.Properties.VariableNames)) && Fr.panels(1).skip == "no trial parameter NoSuchSort" ...
        && Fr.panels(1).layers(1).skip == "no trial parameter NoSuchSort" && isempty(Fr.panels(1).layers(1).R) ...
        && Fr.panels(2).skip == "" && Fr.panels(2).layers(1).skip == "" && isequaln(Fr.panels(2).layers(1).R.rate, L2.R.rate), ...
        'a raster sorted by a parameter the trials lack is skipped with that reason; the PSTH under it is still computed');
    fbb = cfg.Figures(cfg.figureIndex("ct"));
    fbb.id = "badbase";
    fbb.panels(1).options.baseline = struct('Mode', "subtract", 'Window', [-1 -0.5]);
    cfg = cfg.addFigure(fbb);
    Fbb = rn.computeFigure(src, cfg.figureFor("badbase"), Observation=Tc(1, :));
    check(Fbb.panels(1).skip == "" && startsWith(Fbb.panels(1).layers(1).skip, "Baseline [") && isempty(Fbb.panels(1).layers(1).R), ...
        sprintf('a signal''s baseline with no sample in the window skips the layer with the reason ("%s")', Fbb.panels(1).layers(1).skip));

    % probemap, corrmap, waveforms
    Fp = rn.computeFigure(src, sp);
    Lpm = Fp.panels(1).layers(1);
    if isempty(src.probe)
        check(Fp.panels(1).skip == "no probe map", 'probemap: no probe map in the fixture, the panel says so');
    else
        Tsum = unitSummary(src, Source="units", Units=U0, Ref=D.EventRef, Selection=D.Selection);
        Rpm = probeMapValues(Tsum, src.probe, Value="rate");
        check(Lpm.skip == "" && Lpm.R.kind == "probemap" && isequaln(Lpm.R.value, Rpm.value) && isempty(Fp.epochs) && isempty(Fp.panels(1).groups), ...
            'probemap: the units'' rates on the probe sites, as unitSummary + probeMapValues give them; no epochs');
    end
    cfg = cfg.addFigure("corrmap", Id="cm");
    Fcm = rn.computeFigure(src, cfg.figureFor("cm"));
    Rcm = unitCorrelation(sto, Eo, Metric="mean", Type="pearson", FisherZ=false, BinSec=0.01, SmoothSec=0.01, Baseline=[], ...
        BaselineMode="none", Groups=Go, Meta=mo);
    Lcm = Fcm.panels(1).layers(1);
    check(Lcm.skip == "" && Lcm.R.kind == "corrmap" && isequaln(Lcm.R.r, Rcm.r) && size(Lcm.R.r, 1) == height(Rcm.meta) && size(Lcm.R.r, 1) >= 2, ...
        'corrmap: the units'' pairwise correlations, as unitCorrelation gives them');
    cfg = cfg.addFigure("waveforms", Id="wf");
    sw = cfg.figureFor("wf");
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Fw = rn.computeFigure(src, sw, Observation=Tu(1, :));
    warning(wsn); warning(wsw);
    Lw = Fw.panels(1).layers(1);
    check(sw.observe.kind == "unit" && Lw.skip == "" && Lw.R.kind == "waveforms" && Lw.R.n == 1 && Lw.meta.unitId == Tu.unitId(1) ...
        && isscalar(Lw.R.waveforms.mean) && ismember(Lw.R.waveforms.from, ["spikes" "template"]) && isempty(Fw.epochs), ...
        'waveforms: the observed unit''s mean waveform (unitWaveforms); not aligned, no epochs');

    % cancel, checkpoints
    nPolls = 0;
    rn.clearCancel();
    rn.PollFcn = @countPoll;
    Fq = rn.computeFigure(src, spec, Observation=Tu(1, :));
    rn.PollFcn = @() rn.cancel();
    cid = string(errorId(@() rn.computeFigure(src, spec, Observation=Tu(1, :))));
    rn.PollFcn = [];
    rn.clearCancel();
    check(nPolls >= 5 && isequaln(Fq.panels(2).layers(1).R.rate, L2.R.rate) && cid == "EphysAnalysisRunner:Canceled", ...
        sprintf('with PollFcn set, computeFigure reaches %d checkpoints; a cancel() there stops it (EphysAnalysisRunner:Canceled)', nPolls));

    % figureCompute: the runner's computeFigure without a runner
    Fg = figureCompute(src, spec, Observation=Tu(2, :));
    Fr2 = rn.computeFigure(src, spec, Observation=Tu(2, :));
    nChk = 0;
    Fg2 = figureCompute(src, spec, Observation=Tu(2, :), Check=@countCheck);
    cidF = string(errorId(@() figureCompute(src, spec, Observation=Tu(2, :), Check=@() error('test:Stop', 'stop'))));
    check(isequaln(rmfield(Fg, 'created'), rmfield(Fr2, 'created')) && isequaln(rmfield(Fg2, 'created'), rmfield(Fr2, 'created')) ...
        && nChk >= 5 && cidF == "test:Stop", ...
        sprintf('figureCompute equals computeFigure''s result; Check= is called at %d checkpoints and what it throws stops the compute', nChk));

    % figureOutputName: {Plot} the figure, {Unit} the observation, "_<Unit>" when the pattern does not tell them apart
    pat = "{Name}_{Plot}";
    u2 = shortUnitLabels(Tu.meta{2}.label);
    n1 = figureOutputName(pat, "DS-1", spec, Tu(2, :), 2, nU);
    n2 = figureOutputName("{Name}_{Plot}_{Unit}", "DS-1", spec, Tu(2, :), 2, nU);
    n3 = figureOutputName("{Plot}_{Index}_{Kind}", "DS-1", spec, Tu(2, :), 2, nU);
    n4 = figureOutputName(pat, "DS-1", spec, Tu(2, :), 1, 1);
    n5 = figureOutputName(pat, "DS-1", sc, Tc(1, :), 1, height(Tc));
    n6 = figureOutputName(pat, "DS-1", sp, Td, 1, 1);
    n7 = figureOutputName(pat, "DS-1", spec, struct('kind', "unit", 'unitId', 7), 1, 2);
    check(n1 == "DS-1_rp_" + u2 && n2 == "DS-1_rp_" + u2 && n3 == "rp_2_figure" && n4 == "DS-1_rp" ...
        && n5 == "DS-1_ct_ch" + Tc.channel(1) && n6 == "DS-1_pm" && n7 == "DS-1_rp_u7", ...
        sprintf('figureOutputName: "%s", "%s" ({Unit}), "%s" ({Index}: no suffix), "%s" (one observation), "%s", "%s", "%s"', ...
        n1, n2, n3, n4, n5, n6, n7));

    detObs = @(lbl, ch) struct('kind', "unit", 'unitId', ch, 'meta', table(lbl, ch, "det", 'VariableNames', {'label', 'unitId', 'class'}));
    d1 = figureOutputName(pat, "DS-1", spec, detObs("Shank_1", 1), 1, 2);
    d2 = figureOutputName(pat, "DS-1", spec, detObs("Shank_2", 2), 2, 2);
    check(d1 == "DS-1_rp_Shank_1" && d2 == "DS-1_rp_Shank_2", ...
        sprintf('figureOutputName: detections keep their channel''s whole name ("%s", "%s"), never one shared short label', d1, d2));

    % figureCaption
    capU =figureCaption(spec, Tu, Dataset=src.name);
    capD = figureCaption(sp, Td);
    check(startsWith(capU, sprintf("rp: %d observations (sorted units", nU)) && contains(capU, " of " + src.name) ...
        && contains(capU, "panels: raster, PSTH") && contains(capU, "aligned to Stim onset") && contains(capU, "window [-0.2 0.8] s") ...
        && contains(capU, "groups by Depth") && startsWith(capD, "pm: 1 observation (the dataset); panels: probe map") ...
        && ~contains(capD, "aligned") && endsWith(capD, "."), "figureCaption: " + capU + " / " + capD);

    % firing rate and tuning curve panels, an auROC PSTH, a stacked PSTH, the waveforms' probe layout
    m3 = min(3, nU);
    cfg = cfg.addFigure("rate", Id="rt");
    Frt = rn.computeFigure(src, cfg.figureFor("rt"), Observation=Tu(1, :));
    [st1, m1] = unitsOf(Tu.unitId(1));
    Rrt = firingRate(st1, Eo, Measure="rate", Baseline=[], Normalize="none", Groups=Go, Meta=m1, ErrorType="sem", ErrorResamples=1000);
    Lrt = Frt.panels(1).layers(1);
    check(Lrt.skip == "" && Lrt.R.kind == "rate" && size(Lrt.R.meanRate, 1) == 1 && Lrt.meta.unitId == Tu.unitId(1) ...
        && isequaln(Lrt.R.meanRate, Rrt.meanRate) && isequaln(Lrt.R.rate, Rrt.rate) && isequaln(Lrt.R.err.lo, Rrt.err.lo) ...
        && isequal(Lrt.R.groups.label, Rrt.groups.label) && ~Frt.panels(1).sharesTime && istable(Frt.epochs), ...
        'a rate panel of the observed unit is firingRate''s rates of that unit (the same epochs, groups and error)');
    fr3 = cfg.Figures(cfg.figureIndex("rt"));
    fr3.id = "rt3";
    fx3 = EphysAnalysisConfig.defaultLayer("rate");
    fx3.binding = "fixed"; fx3.units.ids = Tu.unitId(1:m3).'; fx3.aggregate = "mean";
    fr3.panels(1).layers = [fr3.panels(1).layers fx3];
    fr3.panels(1).options.display = "box";
    fr3.panels(1).options.waveform = struct('mode', "both", 'location', "southwest", 'width', 1.5, 'height', 0.75, ...
        'timeMs', [-0.5 1], 'ampScale', "fixed", 'ampLim', [-300 150]);
    cfg = cfg.addFigure(fr3);
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Frt3 = rn.computeFigure(src, cfg.figureFor("rt3"), Observation=Tu(2, :));
    warning(wsn); warning(wsw);
    Lr3 = Frt3.panels(1).layers(2);
    check(Lr3.skip == "" && size(Lr3.R.meanRate, 1) == m3 && isequaln(Lr3.R.layerMean.mean, reshape(mean(Lr3.R.meanRate, 1, 'omitnan'), 1, 1, [])) ...
        && Lr3.R.layerMean.n == m3 && Frt3.panels(1).layers(1).meta.unitId == Tu.unitId(2), ...
        'a rate panel''s second layer: three fixed units and their mean (R.layerMean over the units'' means)');
    check(isfield(Frt3.panels(1).layers(1).R, 'waveforms') && ~isfield(Frt.panels(1).layers(1).R, 'waveforms'), ...
        'a rate panel with its waveform on reads its units'' waveforms (the inset); off, none');
    cfg = cfg.addFigure("tuning", Id="tc");
    stc = cfg.figureFor("tc");
    Ftc = rn.computeFigure(src, stc, Observation=Tu(1, :));
    Et = epochsOf([], "Depth");
    Ft = firingRate(st1, Et, Measure="rate", Baseline=[], Normalize="none", Groups=Go, Meta=m1);
    Rtc = tuningCurve(Ft.rate, Et.Depth, Series=[], Param="Depth", SeriesParam="", Meta=m1, Units=Ft.units, ErrorType="sem", ...
        ErrorResamples=1000);
    Ltc = Ftc.panels(1).layers(1);
    check(Ltc.skip == "" && Ltc.R.kind == "tuning" && Ltc.R.param == "Depth" && stc.panels.options.param == "" ...
        && isequal(Ltc.R.x, Rtc.x) && isequaln(Ltc.R.mean, Rtc.mean) && isequaln(Ltc.R.err.lo, Rtc.err.lo) && isequal(Ltc.R.series, Rtc.series) ...
        && ismember("Depth", string(Ftc.epochs.Properties.VariableNames)), ...
        'a tuning panel (param "" = the figure''s groupBy, Depth) is tuningCurve''s curve of that unit (firingRate over Depth)');
    ft2 = cfg.Figures(cfg.figureIndex("tc"));
    ft2.id = "tc2";
    ft2.panels(1).options.seriesParam = "TrialType";
    ft2.panels(1).options.waveform.mode = "mean";
    ft2.selection = struct('groupBy', string.empty(1, 0));
    cfg = cfg.addFigure(ft2);
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Ftc2 = rn.computeFigure(src, cfg.figureFor("tc2"), Observation=Tu(1, :));
    warning(wsn); warning(wsw);
    Lt2 = Ftc2.panels(1).layers(1);
    expParam = figureTuningParamOf(src);
    check(Lt2.skip == "" && Lt2.R.param == expParam && Lt2.R.seriesParam == "TrialType" && height(Lt2.R.groups) >= 1 ...
        && isfield(Lt2.R, 'waveforms') && isequal(sort(string(Ftc2.epochs.Properties.VariableNames(end-1:end))), sort([expParam "TrialType"])), ...
        sprintf('a tuning panel without groupBy tunes over the first numeric trial parameter (%s), a series per TrialType, with the waveform inset', expParam));
    fm2 = cfg.Figures(cfg.figureIndex("tc"));
    fm2.id = "tcmiss";
    fm2.panels(1).options.param = "NoSuchParam";
    cfg = cfg.addFigure(fm2);
    Ftm = rn.computeFigure(src, cfg.figureFor("tcmiss"), Observation=Tu(1, :));
    [rm, lrm] = figureSkipReason(src, cfg.figureFor("tcmiss"));
    check(rm == "" && Ftm.panels(1).skip == "no trial parameter NoSuchParam" && Ftm.panels(1).layers(1).skip == "no trial parameter NoSuchParam" ...
        && isempty(Ftm.panels(1).layers(1).R) && any([lrm.reason] == "no trial parameter NoSuchParam"), ...
        'a tuning panel over a parameter the trials lack is skipped: "no trial parameter NoSuchParam" (figureSkipReason too)');
    fa4 = cfg.Figures(cfg.figureIndex("rp"));
    fa4.id = "auroc";
    fa4.panels(2).options.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
    cfg = cfg.addFigure(fa4);
    wa1 = warning('off', 'aurocCall:NoCutoff');
    wa2 = warning('off', 'aurocCall:WideCutoff');
    Fau = rn.computeFigure(src, cfg.figureFor("auroc"), Observation=Tu(1, :));
    [Ea, Ga] = epochsOf([-0.2 0]);
    Rau = spikePSTH(st1, Ea, Window=[wD.pre wD.post], BinSec=0.01, SmoothSec=0.01, Measure="rate", Baseline=[-0.2 0], ...
        BaselineMode="auroc", Raster=true, Groups=Ga, Meta=m1, Auroc=EphysAnalysisConfig.defaults("Auroc"), ErrorType="sem", ...
        ErrorResamples=1000);
    warning(wa2); warning(wa1);
    Lau = Fau.panels(2).layers(1);
    check(Lau.skip == "" && isfield(Lau.R, 'auroc') && ~isempty(Lau.R.auroc) && Lau.R.units == "auROC" && isequaln(Lau.R.rate, Rau.rate) ...
        && isequaln(Lau.R.t, Rau.t) && isequal(Lau.R.auroc.direction, Rau.auroc.direction) && isequaln(Lau.R.auroc.mean, Rau.auroc.mean), ...
        'an auROC PSTH (its baseline Mode "auroc") is spikePSTH''s PSTH with the auROC baseline, its calls too');
    fs4 = cfg.Figures(cfg.figureIndex("rp"));
    fs4.id = "stacked";
    fs4.panels(2).options.stack = "groups";
    fs4.panels(2).options.stackSpacing = 1.5;
    cfg = cfg.addFigure(fs4);
    Fst = rn.computeFigure(src, cfg.figureFor("stacked"), Observation=Tu(1, :));
    check(Fst.panels(2).layers(1).skip == "" && isequaln(Fst.panels(2).layers(1).R.rate, L2.R.rate) && height(Fst.groups) >= 2, ...
        sprintf('a stacked PSTH computes as an overlaid one (%d groups; stacking is the draw''s)', height(Fst.groups)));
    % first-spike latency: the raster's marks and the PSTH's box plot read the raster's rows (a PSTH keeps them for its box)
    ffs = cfg.Figures(cfg.figureIndex("rp"));
    ffs.id = "fsl";
    ffs.panels(1).options.firstSpike = struct('enabled', true, 'minSec', 0.005, 'maxSec', 0.3);
    ffs.panels(2).options.latencyBox = struct('enabled', true, 'minSec', 0.005, 'maxSec', 0.3);
    cfg = cfg.addFigure(ffs);
    Ffs = rn.computeFigure(src, cfg.figureFor("fsl"), Observation=Tu(1, :));
    ffsS = cfg.Figures(cfg.figureIndex("fsl"));
    ffsS.id = "fslstack";
    ffsS.panels(2).options.stack = "groups";
    cfg = cfg.addFigure(ffsS);
    FfsS = rn.computeFigure(src, cfg.figureFor("fslstack"), Observation=Tu(1, :));
    Rfr = Ffs.panels(1).layers(1).R;
    Rfp = Ffs.panels(2).layers(1).R;
    Lfs = firstSpikeLatency(Rfr, MinSec=0.005, MaxSec=0.3);
    stF = unitsOf(Tu.unitId(1));
    EF = Rfr.epochs;
    wantF = NaN(height(EF), 1);   % the oracle: from the spike train itself, s from each epoch's event on the spikes' clock
    for eF = 1:height(EF)
        dF = stF{1} - EF.t0Continuous(eF);
        dF = dF(dF >= 0.005 - 1e-9 & dF <= 0.3 + 1e-9);
        if ~isempty(dF); wantF(eF) = min(dF); end
    end
    check(Ffs.panels(1).layers(1).skip == "" && isequal(Rfp.raster, Rfr.raster) && ~isempty(Rfp.raster(1).times) ...
        && all(arrayfun(@(r) isempty(r.times), L2.R.raster)) && isequaln(Rfp.rate, L2.R.rate) && isequal(size(Lfs.lat), [height(EF) 1]) ...
        && isequal(isnan(Lfs.lat), isnan(wantF)) && max(abs(Lfs.lat - wantF), [], 'omitnan') < 1e-12 && nnz(isfinite(wantF)) >= 2 ...
        && isequal(Lfs.n, accumarray(EF.groupIndex(isfinite(wantF)), 1, [height(Ffs.groups) 1])) ...
        && isequaln(FfsS.panels(2).layers(1).R.raster, Rfp.raster), ...
        sprintf(['first-spike latency (5 to 300 ms): the PSTH keeps the raster''s rows for its box plot (one without it, ' ...
        'none), its rates unchanged; firstSpikeLatency of the raster equals the first spike in the window from the ' ...
        'unit''s own train (%d of %d epochs)'], nnz(isfinite(wantF)), height(EF)));
    capF = figureCaption(cfg.figureFor("fsl"), Tu);
    capS = figureCaption(cfg.figureFor("fslstack"), Tu);
    check(contains(capF, "each epoch's first spike in [5 300] ms marked on the raster") ...
        && contains(capF, "a box plot of the first-spike latencies in [5 300] ms per trial group over the PSTH") ...
        && contains(capS, "per trial group in each row of the PSTH") && ~contains(figureCaption(spec, Tu), "first spike"), ...
        "figureCaption names the first-spike marks and the latency box plot with their window: " + capF);
    fwp = cfg.Figures(cfg.figureIndex("wf"));
    fwp.id = "wfprobe";
    fwp.panels(1).options.layout = "probe";
    fxw = EphysAnalysisConfig.defaultLayer("waveforms");
    fxw.binding = "fixed"; fxw.units.ids = Tu.unitId(1:m3).';
    fwp.panels(1).layers = [fxw EphysAnalysisConfig.defaultLayer("waveforms")];
    cfg = cfg.addFigure(fwp);
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Fwp = rn.computeFigure(src, cfg.figureFor("wfprobe"), Observation=Tu(2, :));
    warning(wsn); warning(wsw);
    Lwp = Fwp.panels(1).layers;
    check(numel(Lwp) == 2 && Lwp(1).skip == "" && Lwp(1).R.kind == "waveforms" && Lwp(1).R.n == m3 && numel(Lwp(1).R.waveforms.mean) == m3 ...
        && Lwp(2).skip == "" && Lwp(2).R.kind == "ring" && Lwp(2).meta.unitId == Tu.unitId(2) && ~isfield(Lwp(2).R, 'waveforms'), ...
        'a waveforms panel in the probe layout: its first layer''s units with their waveforms, a following layer naming the unit to ring');

    % per-trial continuous traces: every epoch's, and at most maxTrials of them
    ftr = cfg.Figures(cfg.figureIndex("ct"));
    ftr.id = "trials";
    ftr.panels.options.trials = "faint";
    cfg = cfg.addFigure(ftr);
    str = cfg.figureFor("trials");
    Ttr = figureObservations(src, str);
    Ftr = rn.computeFigure(src, str, Observation=Ttr(1, :));
    Rtr = Ftr.panels.layers(1).R;
    nK = numel(Rtr.keptEpochs);
    gTr = Ftr.epochs.groupIndex(ismember(Ftr.epochs.epoch, Rtr.keptEpochs));
    m1 = mean(double(Rtr.data(:, 1, Rtr.trialGroup == 1)), 3);
    check(Ftr.panels.layers(1).skip == "" && isequal(size(Rtr.data, [1 2 3]), [numel(Rtr.t) 1 nK]) && isa(Rtr.data, 'single') ...
        && isequal(Rtr.trialEpochs, Rtr.keptEpochs(:)) && isequal(Rtr.trialGroup, gTr) ...
        && max(abs(m1 - Rtr.mean(:, 1, 1))) <= 1e-4 * max(abs(Rtr.mean(:, 1, 1))) + 1e-9, ...
        sprintf('continuous trials "faint": R.data holds every epoch''s trace [%d x 1 x %d], their epochs and groups; a group''s traces average to its mean', ...
        numel(Rtr.t), nK));
    ftr5 = ftr;
    ftr5.id = "trials5";
    ftr5.panels.options.trials = "only";
    ftr5.panels.options.maxTrials = 5;
    cfg = cfg.addFigure(ftr5);
    Ftr5 = rn.computeFigure(src, cfg.figureFor("trials5"), Observation=Ttr(1, :));
    R5 = Ftr5.panels.layers(1).R;
    pick = unique(round(linspace(1, nK, 5)));
    check(nK > 5 && size(R5.data, 3) == 5 && isequal(R5.trialEpochs, reshape(Rtr.keptEpochs(pick), [], 1)) ...
        && isequaln(R5.data, Rtr.data(:, :, pick)) && isequaln(R5.trialGroup, Rtr.trialGroup(pick)) && isequaln(R5.mean, Rtr.mean), ...
        'maxTrials 5: five epochs picked evenly over their order (the mean still over every epoch)');
    check(isempty(F3.panels(3).layers(1).R.data) && ~isfield(F3.panels(3).layers(1).R, 'trialEpochs'), 'trials "off" keeps no traces');
    E300 = Ftr.epochs(repmat((1:height(Ftr.epochs)).', 25, 1), :);   % 300 epochs: the fixture's, 25 times over
    E300.epoch = (1:height(E300)).';
    obsC = struct('kind', "channel", 'unitId', NaN, 'channel', Ttr.channel(1), 'column', Ttr.column(1));
    ctx300 = struct('checkpoint', @() [], 'check', [], 'observation', obsC, 'observe', str.observe, 'errorType', "sem", 'nBoot', 1000);
    lay300 = figurePanelLayers(str.panels(1));
    lay300 = figureSignalLayer(src, str.panels(1).layers(1), lay300(1), E300, Ftr.groups, ctx300, ...
        Window=[str.window.pre str.window.post], KeepEpochs=true, MaxTrials=str.panels(1).options.maxTrials);
    check(str.panels(1).options.maxTrials == 100 && lay300.skip == "" && size(lay300.R.data, 3) == 100 && numel(lay300.R.trialEpochs) == 100 ...
        && isa(lay300.R.data, 'single') && size(Rtr.data, 3) == nK, ...
        'maxTrials defaults to 100: a layer over 300 epochs keeps 100 traces (single); 12 epochs keep all 12');

    % a heat map of one unit's trials
    hmL = EphysAnalysisConfig.defaultLayer("heatmap");
    hmL.binding = "observation";
    fth = struct('panels', {{struct('id', "tm", 'type', "heatmap", 'layers', hmL, 'options', struct('rows', "trials", ...
        'measure', "count", 'bins', struct('BinSec', 0.02, 'SmoothSec', 0), 'rasterSort', "Depth", 'rasterSortOrder', "descending"))}});
    cfg = cfg.addFigure(fth, Id="trialmap");
    sth = cfg.figureFor("trialmap");
    Fth = rn.computeFigure(src, sth, Observation=Tu(1, :));
    Rth = Fth.panels.layers(1).R;
    nEh = height(Fth.epochs);
    withSpikes = unique(Rth.raster.epoch);
    e1 = withSpikes(1);
    byHand = histcounts(Rth.raster.times(Rth.raster.epoch == e1) + 1e-9, Rth.edges);
    okMean = true;
    for g = 1:height(Fth.groups)
        okMean = okMean && max(abs(mean(Rth.trialMatrix(Rth.trialGroup == g, :), 1).' - Rth.rate(:, 1, g)), [], 'omitnan') < 1e-12;
    end
    check(Fth.panels.layers(1).skip == "" && sth.observe.kind == "unit" && Fth.panels.layers(1).meta.unitId == Tu.unitId(1) ...
        && isequal(size(Rth.trialMatrix), [nEh numel(Rth.t)]) && isequal(Rth.trialMatrix(e1, :), byHand) && okMean, ...
        sprintf('a heat map of trials: [%d epochs x %d bins], epoch %d''s row the raster binned by hand; each group''s rows average to its PSTH', ...
        nEh, numel(Rth.t), e1));
    og = Rth.trialGroup(Rth.trialOrder);
    dep = Fth.epochs.Depth(Rth.trialOrder);
    okOrder = isequal(sort(Rth.trialOrder(:)), (1:nEh).') && issorted(og);
    for g = reshape(unique(og), 1, [])
        okOrder = okOrder && issorted(flipud(dep(og == g)));
    end
    check(okOrder && Rth.trialRowsName == "Epoch (by Depth), descending", ...
        'its rows go as a raster sorts them: by group, then Depth descending');
    check(~isfield(Rth, 'trains'), 'the trains the rows were binned from are not kept in the result');
    fth2 = cfg.Figures(cfg.figureIndex("trialmap"));
    fth2.id = "trialmap2";
    fth2.panels.layers.binding = "fixed";
    fth2.panels.layers.units.ids = Tu.unitId(1:2).';
    fth2.panels.layers.units.classes = string.empty(1, 0);
    cfg = cfg.addFigure(fth2);
    Fth2 = rn.computeFigure(src, cfg.figureFor("trialmap2"));
    check(Fth2.panels.layers(1).skip == "A heat map of trials draws one unit: this layer keeps 2" && isempty(Fth2.panels.layers(1).R), ...
        'a heat map of trials whose layer keeps two units is skipped, saying so');
    fth3 = cfg.Figures(cfg.figureIndex("trialmap"));
    fth3.id = "trialmap3";
    fth3.window = struct('mode', "fixed", 'pre', -0.2, 'post', 3, 'stop', struct('line', "Stim", 'edge', "offset"));
    fth3.panels.options.maskAfterStop = true;
    fth3.panels.options.rasterSort = "";
    fth3.panels.options.bins.BinSec = 0.037;   % an odd bin: the stops fall inside bins
    cfg = cfg.addFigure(fth3);
    Fth3 = rn.computeFigure(src, cfg.figureFor("trialmap3"), Observation=Tu(1, :));
    R3 = Fth3.panels.layers(1).R;
    stopIn = R3.epochStop(isfinite(R3.epochStop));
    inBin = any(abs(stopIn / 0.037 - round(stopIn / 0.037)) > 1e-6);   % a stop inside a bin: its bin keeps the spikes after it
    okMask = Fth3.panels.layers(1).skip == "" && any(isnan(R3.trialMatrix(:)));
    for g = 1:height(Fth3.groups)
        gm = mean(R3.trialMatrix(R3.trialGroup == g, :), 1, 'omitnan').';
        okMask = okMask && isequal(isnan(gm), isnan(R3.rate(:, 1, g))) && max(abs(gm - R3.rate(:, 1, g)), [], 'omitnan') < 1e-12;
    end
    check(okMask && inBin, 'with maskAfterStop (the stop inside a bin) each group''s rows still average to its PSTH, masked bins alike');

    % a panel with a trial selection of its own: its own epochs and groups
    fos = cfg.Figures(cfg.figureIndex("rp"));
    fos.id = "ownsel";
    fos.panels(2).selection = struct('groupBy', string.empty(1, 0));
    cfg = cfg.addFigure(fos);
    Fos = rn.computeFigure(src, cfg.figureFor("ownsel"), Observation=Tu(1, :));
    check(~Fos.panels(1).ownSelection && Fos.panels(2).ownSelection && height(Fos.groups) > 1 && height(Fos.panels(2).groups) == 1 ...
        && istable(Fos.panels(2).epochs) && height(Fos.panels(2).epochs) == height(Fos.epochs) && size(Fos.panels(2).layers(1).R.rate, 3) == 1 ...
        && Fos.panels(2).sharesTime && isempty(Fos.panels(1).epochs), ...
        sprintf('a PSTH with a selection of its own (no groupBy): its own epochs and one group, the raster on the figure''s %d groups', ...
        height(Fos.groups)));

    % one figure per trial group
    fpg = cfg.Figures(cfg.figureIndex("rp"));
    fpg.id = "pergroup";
    fpg.observe.perGroup = true;
    cfg = cfg.addFigure(fpg);
    spg = cfg.figureFor("pergroup");
    Tpg = figureObservations(src, spg);
    gOn = find(F1.groups.n > 0);
    nGg = numel(gOn);
    check(nGg >= 2 && height(Tpg) == nU * nGg && isequal(Tpg.unitId, repelem(Tu.unitId, nGg)) && isequal(Tpg.group(1:nGg), gOn) ...
        && isequal(Tpg.groupLabel(1:nGg), string(F1.groups.label(gOn))) && all(endsWith(Tpg.label, " · " + Tpg.groupLabel)) ...
        && all(isnan(Tu.group)) && all(Tu.groupLabel == ""), ...
        sprintf('perGroup: one observation per unit and trial group (%d units x %d groups), the label ending in its group', nU, nGg));
    Fpg = rn.computeFigure(src, spg, Observation=Tpg(2, :));
    g2 = Tpg.group(2);
    check(height(Fpg.groups) == 1 && string(Fpg.groups.label) == Tpg.groupLabel(2) && Fpg.groups.n == F1.groups.n(g2) ...
        && height(Fpg.epochs) == F1.groups.n(g2) && all(Fpg.epochs.groupIndex == 1) && all(string(Fpg.epochs.group) == Tpg.groupLabel(2)) ...
        && isequaln(Fpg.panels(2).layers(1).R.rate, F1.panels(2).layers(1).R.rate(:, :, g2)) && Fpg.observation.groupLabel == Tpg.groupLabel(2), ...
        'a per-group figure keeps that group''s epochs only (one group, n recounted): its PSTH is the unit''s PSTH of the group');
    fpo = fpg;
    fpo.id = "pergroupown";
    fpo.panels(2).selection = struct('groupBy', string.empty(1, 0));
    cfg = cfg.addFigure(fpo);
    Fpo = rn.computeFigure(src, cfg.figureFor("pergroupown"), Observation=Tpg(2, :));
    check(height(Fpo.epochs) == F1.groups.n(g2) && height(Fpo.panels(2).epochs) == height(F1.epochs), ...
        'a panel with a selection of its own is not cut to the observation''s group');
    Fgone = rn.computeFigure(src, spg, Observation=struct('kind', "unit", 'unitId', Tu.unitId(1), 'channel', Tu.channel(1), ...
        'group', 99, 'groupLabel', "nope"));
    hgone = renderFigure(Fgone, Fgone.spec, figure('Visible', 'off'));
    goneNotes = strjoin(string(get(findall(hgone.layout, 'Tag', 'layerNote'), 'String')), " | ");
    close(ancestor(hgone.layout, 'figure'));
    check(contains(Fgone.skip, "nope") && all([Fgone.panels.skip] == Fgone.skip) && height(Fgone.epochs) == 0 && contains(goneNotes, "nope"), ...
        'an observation of a trial group with no epoch here is no error: F.skip and its panels say why, and it draws with notes');
    fpb = fpg;
    fpb.id = "pergroupbase";
    fpb.panels(2).options.baseline = struct('Mode', "subtract", 'Window', [-6 -5.9]);   % far back: early epochs lose their baseline
    cfg = cfg.addFigure(fpb);
    spb = cfg.figureFor("pergroupbase");
    Tpb = figureObservations(src, spb);
    try
        [~, Gb] = epochTable(src, spb.ref, Window=spb.window, Selection=spb.selection, Baseline=[-6 -5.9]);
        wantG = string(Gb.label(Gb.n > 0));
    catch
        wantG = strings(0, 1);
    end
    okB = isequal(unique(Tpb.groupLabel, 'stable'), wantG);
    if height(Tpb) > 0
        for i = find(Tpb.unitId == Tpb.unitId(1)).'   % the first unit's groups
            okB = okB && rn.computeFigure(src, spb, Observation=Tpb(i, :)).skip == "";
        end
    end
    check(okB, sprintf('perGroup lists the groups with epochs after the panels'' baseline hull, as compute reads them (%d of %d groups)', ...
        numel(wantG), height(F1.groups)));
    u1 = figureOutputName("{Unit}", "DS", spg, Tu(1, :), 1, 1);
    gs = regexprep(Tpg.groupLabel(2), '[^\w\-\.]', '_');
    nm1 = figureOutputName("{Name}_{Plot}", "DS", spg, Tpg(2, :), 2, height(Tpg));
    nm2 = figureOutputName("{Name}_{Plot}_{Group}", "DS", spg, Tpg(2, :), 2, height(Tpg));
    nm3 = figureOutputName("{Name}_{Plot}_{Index}", "DS", spg, Tpg(2, :), 2, height(Tpg));
    check(nm1 == "DS_pergroup_" + u1 + "_" + gs && nm2 == "DS_pergroup_" + gs + "_" + u1 && nm3 == "DS_pergroup_2" ...
        && contains(figureCaption(spg, Tpg), "one figure per trial group") && ~contains(figureCaption(spec, Tu), "per trial group"), ...
        sprintf('figureOutputName: {Group} = the group ("%s"; "_<Group>" appended without {Group} or {Index}); figureCaption says per trial group', nm1));

    % one observation costs a fraction of every unit
    haveBootT = license('test', 'Statistics_Toolbox') && exist('bootci', 'file');
    if nU >= 4 && haveBootT
        % bootstrap bands make the per-unit work, not the fixed steps, the bulk of the time
        cfgT = cfg;
        cfgT.Figures(cfgT.figureIndex("rp")).style.ErrorType = "ci95";
        specT = cfgT.figureFor("rp");
        allUnits = @() spikePSTH(sto, epochsOf([]), Window=[wD.pre wD.post], BinSec=0.01, SmoothSec=0.01, Measure="rate", ...
            Raster=true, Groups=Go, Meta=mo, ErrorType="ci95", ErrorResamples=1000);
        rn.computeFigure(src, specT, Observation=Tu(1, :));   % warm both
        allUnits();
        tF = Inf; tP = Inf;
        for rep = 1:3
            tc0 = tic; rn.computeFigure(src, specT, Observation=Tu(1, :)); tF = min(tF, toc(tc0));
            tc0 = tic; allUnits(); tP = min(tP, toc(tc0));
        end
        check(tF <= 0.5 * tP, sprintf(['one observation of the raster + PSTH figure (%.3f s) takes at most half the time of ' ...
            'the PSTH of all %d units (%.3f s)'], tF, nU, tP));
    else
        fprintf('  (timing check skipped: %d unit(s), bootci %d)\n', nU, haveBootT);
    end
end

%% ============================================================================ render
if S.sec("8", "render: renderFigure, its layout, the draw functions")
    % figureArrange: the layout's arithmetic (pure)
    gd = EphysAnalysisConfig.defaults("Figure").grid;
    gd.rows = 2; gd.rowHeights = [1 2]; gd.spacing = "custom"; gd.rowGap = 10;
    ca = [arrangeCell(1, 1, 1, 1, [40 30 0 0]) arrangeCell(2, 2, 1, 1, [40 30 0 15])];
    La = figureArrange([600 400], gd, ca, Margin=6);
    hA = La.rows(:, 2) - La.rows(:, 1);
    check(abs(La.rows(1, 1) - La.rows(2, 2) - (30 + 10 + 15)) < 1e-9 && abs(hA(2) / hA(1) - 2) < 1e-9 && abs(La.rows(1, 2) - 394) < 1e-9 ...
        && abs(La.rows(2, 1) - 36) < 1e-9 && abs(La.cols(1, 1) - 46) < 1e-9 && abs(La.cols(1, 2) - 594) < 1e-9, ...
        'figureArrange: between two rows the labels'' room and the gap exactly (30 + 10 + 15 px); the plot heights exactly 1 : 2');
    gd.gapUnits = "%";
    Lp = figureArrange([600 400], gd, ca, Margin=6);
    gp = Lp.rows(1, 1) - Lp.rows(2, 2) - 45;
    check(abs(gp - 0.1 * mean(Lp.rows(:, 2) - Lp.rows(:, 1))) < 1e-9 && abs(Lp.gaps.rows - gp) < 1e-9, ...
        sprintf('figureArrange: a gap of 10 %% is a tenth of the mean row''s plot height (%.1f px)', gp));
    g3 = gd; g3.rows = 3; g3.rowHeights = []; g3.gapUnits = "px"; g3.rowGaps = [5 20];
    c3 = [arrangeCell(1, 1, 1, 1, [0 0 0 0]) arrangeCell(2, 2, 1, 1, [0 0 0 0]) arrangeCell(3, 3, 1, 1, [0 0 0 0])];
    L3 = figureArrange([300 300], g3, c3, Margin=0);
    g3.spacing = "none";
    Ln = figureArrange([300 300], g3, c3, Margin=0);
    g3.spacing = "loose";
    Ll = figureArrange([300 300], g3, c3, Margin=0);
    check(all(abs(L3.rows(1:2, 1) - L3.rows(2:3, 2) - [5; 20]) < 1e-9) && all(abs(Ln.rows(1:2, 1) - Ln.rows(2:3, 2)) < 1e-9) ...
        && all(abs(Ll.rows(1:2, 1) - Ll.rows(2:3, 2) - 24) < 1e-9), ...
        'figureArrange: rowGaps set each gap apart (5, 20 px); "none" is flush and "loose" 24 px (the lists unused)');
    g2 = EphysAnalysisConfig.defaults("Figure").grid;
    g2.rows = 2; g2.cols = 2; g2.colWidths = [1 3]; g2.spacing = "custom"; g2.colGap = 12; g2.rowGap = 0;
    c2 = [arrangeCell(1, 1, 1, 2, [30 0 0 0]) arrangeCell(2, 2, 1, 1, [30 20 0 0]) arrangeCell(2, 2, 2, 2, [25 20 5 0])];
    L2 = figureArrange([500 300], g2, c2, Margin=0);
    w2 = L2.cols(:, 2) - L2.cols(:, 1);
    check(abs(w2(2) / w2(1) - 3) < 1e-9 && abs(L2.cols(2, 1) - L2.cols(1, 2) - 37) < 1e-9 && abs(L2.panels(1).box(1) - L2.cols(1, 1)) < 1e-9 ...
        && abs(sum(L2.panels(1).box([1 3])) - L2.cols(2, 2)) < 1e-9, ...
        'figureArrange: columns exactly 1 : 3, the left labels'' room and the gap between them (12 + 25 px); a panel over both spans them');
    g1 = EphysAnalysisConfig.defaults("Figure").grid;
    cs = arrangeCell(1, 1, 1, 1, [0 0 0 0]);
    cs.size = [0.5 0.25]; cs.align = "right"; cs.valign = "top";
    Ls = figureArrange([400 400], g1, cs, Margin=0);
    cb = arrangeCell(1, 1, 1, 1, [0 0 0 0]);
    cb.band = "below"; cb.need = 50; cb.shares = [2 1];
    Lb = figureArrange([400 400], g1, cb, Margin=0, Top=20, Legend=struct('side', "east", 'size', [60 40]));
    Ab = Lb.panels(1).axes;
    check(isequal(Ls.panels(1).box, [200 300 200 100]) && isequal(Lb.panels(1).band, [0 0 332 50]) && isequal(Lb.panels(1).box, [0 50 332 330]) ...
        && abs(Ab(1, 4) - 220) < 1e-9 && abs(Ab(2, 4) - 110) < 1e-9 && abs(Ab(1, 2) - Ab(2, 2) - Ab(2, 4)) < 1e-9 ...
        && isequal(Lb.title, [0 380 400 20]) && isequal(Lb.legend, [340 170 60 40]), ...
        'figureArrange: a panel half as wide, a quarter as high, at its cell''s top right; a band below; a phase strip a third under its axes; the title''s and the legend''s bands');

    % the registry
    reg = figurePanelRegistry();
    okReg = all(arrayfun(@(t) isfield(reg, t) && isa(reg.(t).compute, 'function_handle') && isa(reg.(t).draw, 'function_handle'), T.Type));
    check(okReg && isequal(sort(string(fieldnames(reg))), sort(T.Type)), 'figurePanelRegistry: a compute and a draw function for every panel type');

    % two more figures: a heat map, and a PSTH with latency marks
    cfg = cfg.addFigure("heatmap", Id="hm");
    Fh = rn.computeFigure(src, cfg.figureFor("hm"));
    evOff = ev;
    evOff.event.edge = "offset";
    fm = cfg.Figures(cfg.figureIndex("rp"));
    fm.id = "marks";
    fm.panels(2).layers = [fm.panels(2).layers evOff];
    cfg = cfg.addFigure(fm);
    Fm = rn.computeFigure(src, cfg.figureFor("marks"), Observation=Tu(1, :));

    % every panel type into every kind of target
    drawTargets();
    rcases = {
        "raster + PSTH",                    F1
        "raster / PSTH / continuous stack", F3
        "events as marks and a train",      Fe
        "events as spans",                  Fsp
        "event traces",                     Ftrace
        "PSTH with latency marks",          Fm
        "a layer's mean of three units",    Fa
        "a panel's own window",             Fo
        "a channel observation",            Fc
        "heat map",                         Fh
        "a panel of one skipped layer",     Fn
        "probe map",                        Fp
        "unit correlation",                 Fcm
        "unit waveforms",                   Fw
        "firing rate",                      Frt
        "a rate of a unit and a 3-unit mean (box)", Frt3
        "tuning curve",                     Ftc
        "tuning curves per series, inset",  Ftc2
        "an auROC PSTH",                    Fau
        "a stacked PSTH",                   Fst
        "first-spike marks, a latency box plot", Ffs
        "a stacked PSTH's latency boxes",   FfsS
        "unit waveforms on the probe",      Fwp
        "continuous trials, faint",         Ftr
        "continuous trials only, 5 of them", Ftr5
        "a heat map of trials",             Fth
        "a PSTH with its own selection",    Fos
        "one trial group's figure",         Fpg};
    for k = 1:size(rcases, 1)
        Fk = rcases{k, 2};
        ids = [Fk.panels.id];
        okAll = true;
        msgs = "";
        for mode = ["axes" "uiaxes" "figure" "panel" "grid"]
            try
                switch mode
                    case "axes",   clf(fig); tg = axes(fig); %#ok<LAXES>
                    case "uiaxes", delete(ufig.Children); tg = uiaxes(ufig);
                    case "figure", tg = fig;
                    case "panel",  delete(ufig.Children); tg = uipanel(ufig);
                    case "grid",   delete(ufig.Children); tg = uigridlayout(ufig, [1 1]);
                end
                h = renderFigure(Fk, Fk.spec, tg);
                drawnow;
                ok = ~isempty(h.axes) && all(isgraphics(h.axes)) && ~isempty(h.axes(1).Children) && h.title ~= "" ...
                    && isequal([h.panels.id], ids);
                if ismember(mode, ["axes" "uiaxes"])
                    ok = ok && isempty(h.layout) && isscalar(h.axes) && h.axes == tg;
                    C = PlotAesthetics.components(tg);
                else
                    ok = ok && ~isempty(h.layout) && numel(h.axes) == numel(ids) && figTitle(h) == h.title;
                    C = PlotAesthetics.components(h.layout);
                    named = all(ismember(ids, C.TileName(C.Tile > 0)));
                    if ~named; msgs = msgs + mode + ": tiles " + strjoin(unique(C.TileName(C.Tile > 0)), ", ") + "  "; end
                    ok = ok && named;
                end
                bad = C.Role == "" | ~ismember(C.Role, roles);
                if any(bad); msgs = msgs + mode + ": untagged " + strjoin(C.Type(bad) + " " + C.Role(bad), ", ") + "  "; end
                ok = ok && ~any(bad);
            catch ME
                ok = false;
                msgs = msgs + mode + ": " + ME.message + "  ";
            end
            okAll = okAll && ok;
        end
        msg = rcases{k, 1} + " draws into an axes, a uiaxes, a figure, a uipanel and a grid layout, every component tagged, the tiles named by panel";
        if msgs ~= ""; msg = msg + " (" + msgs + ")"; end
        check(okAll, msg);
    end

    % a panel's text note and overlays (phase 6): drawn on that panel, their looks as rules, the figure's own winning
    sN = F1.spec;
    nPs = EphysAnalysisConfig.defaults("Note");
    nPs.text = "n = 12";
    nPs.color = "#ff0000";
    nPs.placement = "below";
    sN.panels(2).note = nPs;
    nR = EphysAnalysisConfig.defaults("Note");
    nR.text = "raster note";
    nR.placement = "northeast";
    nR.bold = true;
    sN.panels(1).note = nR;
    oR = EphysAnalysisConfig.defaults("Overlay");
    oR.shape = "region"; oR.from = 0; oR.to = 0.05; oR.faceColor = "#00ff00"; oR.name = "window";
    sN.panels(1).overlays = oR;
    sN.panels(2).overlays = EphysAnalysisConfig.defaults("Overlay");
    sN.aesthetics = struct('role', "overlayRegion", 'group', "window", 'property', "FaceAlpha", 'value', 0.6);
    clf(fig);
    hN = renderFigure(F1, sN, fig);
    drawnow;
    tP = hN.panels(2).note;
    tR = hN.panels(1).note;
    gR = hN.panels(1).overlays;
    gL = hN.panels(2).overlays;
    band = ancestor(tP, 'axes');
    bP = figureBox(band, fig);
    aP = figureBox(hN.panels(2).axes, fig);
    check(isscalar(tP) && isgraphics(tP) && string(tP.String) == "n = 12" && string(tP.Tag) == "note" && isequal(tP.Color, [1 0 0]) ...
        && string(band.Tag) == "noteHost" && band.Visible == "off" && band.Parent == hN.layout && bP(2) + bP(4) <= aP(2) + 0.5 ...
        && abs(bP(1) - aP(1)) < 0.5 && abs(bP(3) - aP(3)) < 0.5, ...
        'a note below a panel sits in a band under its axes, as wide (a hidden noteHost axes), its own color a rule');
    check(isscalar(tR) && ancestor(tR, 'axes') == hN.panels(1).axes && string(tR.FontWeight) == "bold" && string(tR.String) == "raster note" ...
        && hN.panels(1).axes.Parent == hN.layout, 'a note over a panel (northeast) is in its axes; that panel keeps its plain tile');
    check(isscalar(gR) && string(gR.Tag) == "overlayRegion" && isequal(gR.FaceColor, [0 1 0]) && abs(gR.FaceAlpha - 0.6) < 1e-9 ...
        && ancestor(gR, 'axes') == hN.panels(1).axes && isscalar(gL) && string(gL.Tag) == "overlayLine" ...
        && ancestor(gL, 'axes') == hN.panels(2).axes, ...
        'each panel''s overlays are drawn on its own axes (a region on the raster, a line on the PSTH); the figure''s rule wins over the overlay''s own opacity');
    CN = PlotAesthetics.components(hN.layout);
    check(~any(CN.Role == "" | ~ismember(CN.Role, roles)) && any(CN.Role == "note" & CN.TileName == "raster_1") ...
        && any(CN.Role == "overlayRegion" & CN.Group == "window") && any(CN.Role == "overlayLine"), ...
        'the note over a panel and every overlay are tagged components of that panel''s tile');
    % a patch overlay over a raster is seen: its group bands are opaque, and a constant region (xregion) is drawn behind them
    sV = F1.spec;
    oV = EphysAnalysisConfig.defaults("Overlay");
    oV.shape = "region"; oV.from = 0.1; oV.to = 0.3; oV.faceColor = "#00ff00"; oV.faceAlpha = 1; oV.name = "seen";
    oU = oV; oU.from = 0.5; oU.to = 0.7; oU.layer = "under"; oU.name = "hidden";
    oY = oV; oY.axis = "y"; oY.from = 2; oY.to = 5; oY.name = "rows";
    sV.panels(1).overlays = [oV oU oY];
    sV.panels(1).options.backColor = "groups";   % the raster's group bands are what hides an "under" region
    clf(fig);
    hV = renderFigure(F1, sV, fig);
    drawnow;
    axV = hV.panels(1).axes;
    gV = hV.panels(1).overlays;
    gX = gV(arrayfun(@(g) string(getappdata(g, 'PlotGroup')) == "seen", gV));
    bandsV = findall(axV, 'Tag', 'rasterBand');
    imgV = print(fig, '-RGBImage', '-r60');
    boxV = figureBox(axV, fig);
    green = [0 255 0];
    check(isscalar(gX) && isa(gX, 'matlab.graphics.primitive.Patch') && string(gX.Tag) == "overlayRegion" && all(isgraphics(gV)) ...
        && isequal(sort(unique(gX.XData)).', [0.1 0.3]) && isequal(sort(unique(gX.YData)).', ylim(axV)), ...
        'a patch overlay is a patch object (a region of the raster, over its whole height), tagged overlayRegion');
    check(max(abs(rasterPixel(0.2, 0.5) - green)) <= 3 && max(abs(rasterPixel(0.2, 0.95) - green)) <= 3 ...
        && max(abs(rasterPixel(0.6, 0.5) - green)) > 40 && ~isempty(bandsV), ...
        sprintf('over the raster''s opaque group bands a patch "over" the data shows (pixel %s), one "under" them does not (%s)', ...
        mat2str(rasterPixel(0.2, 0.5)), mat2str(rasterPixel(0.6, 0.5))));
    xlim(axV, [0.15 0.25]);
    ylim(axV, [3 4]);
    yR = gV(arrayfun(@(g) string(getappdata(g, 'PlotGroup')) == "rows", gV));
    check(isequal(sort(unique(gX.XData)).', [0.15 0.25]) && isequal(sort(unique(gX.YData)).', [3 4]) && isequal(sort(unique(yR.YData)).', [3 4]) ...
        && isequal(sort(unique(yR.XData)).', [0.15 0.25]), ...
        'the patches follow the axes'' limits (a region is clamped to them, so it never widens the axes)');
    sV.panels(1).overlays = oV;
    sV.panels(2).overlays = oV;
    clf(fig);
    hV = renderFigure(F1, sV, fig);
    drawnow;
    imgV = print(fig, '-RGBImage', '-r60');
    axV = hV.panels(2).axes;
    boxV = figureBox(axV, fig);
    check(max(abs(rasterPixel(0.2, 0.5) - green)) <= 3 && isa(hV.panels(2).overlays, 'matlab.graphics.primitive.Patch'), ...
        'a patch overlay on a PSTH panel shows too');
    % a raster has no y tick marks or labels unless options.yTicks; the y label stays
    rY = F1.spec;
    clf(fig);
    hY = renderFigure(F1, rY, fig);
    drawnow;
    axY = hY.panels(1).axes;
    check(rY.panels(1).options.yTicks == false && isempty(axY.YTick) && isempty(axY.YTickLabel) && string(axY.YLabel.String) ~= "", ...
        'a raster panel hides its y tick marks and labels by default, the y label stays');
    rY.panels(1).options.yTicks = true;
    clf(fig);
    hY = renderFigure(F1, rY, fig);
    drawnow;
    check(numel(hY.panels(1).axes.YTick) >= 2 && numel(hY.panels(1).axes.YTickLabel) >= 2, 'options.yTicks brings the raster''s y ticks back');
    % the ticks are each group's color (a line per group, tagged with its label), no bands; tickColor makes every tick one
    % color; backColor "groups" gives each group a pale band, a color one color on every band and the axes behind them
    rC = F1.spec;
    clf(fig);
    hC = renderFigure(F1, rC, fig);
    drawnow;
    axC = hC.panels(1).axes;
    tkC = rasterTickLines(axC);
    tk0 = vertcat(tkC.Color);   % values: the redraw deletes these objects
    lab0 = arrayfun(@(t) string(getappdata(t, 'PlotGroup')), tkC);
    nBd0 = numel(findall(axC, 'Tag', 'rasterBand'));
    rC.panels(1).options.backColor = "groups";
    clf(fig);
    hC = renderFigure(F1, rC, fig);
    drawnow;
    bdG = vertcat(findall(hC.panels(1).axes, 'Tag', 'rasterBand').FaceColor);   % values: the redraw deletes these objects
    rC.panels(1).options.tickColor = "red";
    rC.panels(1).options.backColor = "#102030";
    clf(fig);
    hC = renderFigure(F1, rC, fig);
    drawnow;
    axC = hC.panels(1).axes;
    tk1 = rasterTickLines(axC);
    bd1 = findall(axC, 'Tag', 'rasterBand');
    check(numel(tkC) == nnz(F1.groups.n > 0) && isequal(sort(lab0), sort(string(F1.groups.label(F1.groups.n > 0)))) ...
        && size(unique(tk0, 'rows'), 1) == numel(tkC) && ~any(all(tk0 == 0, 2)) && nBd0 == 0, ...
        'raster ticks: one line per trial group in the group''s color (as the PSTH''s traces), tagged with the group; no bands by default');
    check(size(bdG, 1) == numel(tkC) && ~any(all(bdG == [16 32 48] / 255, 2)), ...
        'options.backColor "groups": a pale band of each group''s color behind its rows');
    check(numel(tk1) == numel(tkC) && all(arrayfun(@(t) isequal(t.Color, [1 0 0]), tk1)) && ~isempty(bd1) ...
        && all(arrayfun(@(b) isequal(b.FaceColor, [16 32 48] / 255), bd1)) && isequal(axC.Color, [16 32 48] / 255), ...
        'options.tickColor colors every raster tick alike, a color for options.backColor every band and the axes');
    % a layer's own color draws its block's ticks, over the groups' colors
    rC = F1.spec;
    rC.panels(1).layers(1).color = "blue";
    clf(fig);
    hC = renderFigure(F1, rC, fig);
    drawnow;
    tk2 = rasterTickLines(hC.panels(1).axes);
    check(numel(tk2) == numel(tkC) && all(arrayfun(@(t) isequal(t.Color, [0 0 1]), tk2)), ...
        'a raster layer''s own color draws its ticks in it, as a PSTH layer''s color draws its traces');
    % a design keeps the groups' colors (it sets the tick width, not the color); a rule for one group's ticks recolors just them
    rC = F1.spec;
    clf(fig);
    hC = renderFigure(F1, rC, fig, Design="Journal", UserAesthetics=false);
    drawnow;
    tkJ = rasterTickLines(hC.panels(1).axes);
    labJ = arrayfun(@(t) string(getappdata(t, 'PlotGroup')), tkJ);
    colJ = vertcat(tkJ.Color);
    rC.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', labJ(1), 'property', "Color", 'value', [0 1 0]));
    clf(fig);
    hC = renderFigure(F1, rC, fig, Design="Journal", UserAesthetics=false);
    drawnow;
    tk3 = rasterTickLines(hC.panels(1).axes);
    lab3 = arrayfun(@(t) string(getappdata(t, 'PlotGroup')), tk3);
    col3 = vertcat(tk3.Color);
    own = lab3 == labJ(1);
    check(size(unique(colJ, 'rows'), 1) == numel(tkJ) && all(col3(own, :) == [0 1 0], 'all') && isequal(col3(~own, :), colJ(labJ ~= labJ(1), :)) ...
        && all([tk3.LineWidth] == 0.5), ...
        'a design leaves the raster ticks'' group colors; a rule for one group recolors only that group''s ticks');
    % tickWidth: 0 follows the design's tick width; a width wins over it (and over the user's kind rules), not over the figure's own rules
    rW = F1.spec;
    clf(fig);
    hW = renderFigure(F1, rW, fig, Design="Talk", UserAesthetics=false);
    drawnow;
    tkT = rasterTickLines(hW.panels(1).axes);
    wT = [tkT.LineWidth];   % values: the redraw deletes these objects
    rW.panels(1).options.tickWidth = 3;
    clf(fig);
    hW = renderFigure(F1, rW, fig, Design="Talk", UserAesthetics=false);
    drawnow;
    wW = [rasterTickLines(hW.panels(1).axes).LineWidth];
    rW.aesthetics = PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', "", 'property', "LineWidth", 'value', 2));
    clf(fig);
    hW = renderFigure(F1, rW, fig, Design="Talk", UserAesthetics=false);
    drawnow;
    wF = [rasterTickLines(hW.panels(1).axes).LineWidth];
    rW.panels(1).options.tickColor = "red";
    rW.aesthetics = PlotAesthetics.emptyRules();
    clf(fig);
    hW = renderFigure(F1, rW, fig, Design="Talk", UserAesthetics=false);
    drawnow;
    tkR = rasterTickLines(hW.panels(1).axes);
    wR = [tkR.LineWidth];
    cR = vertcat(tkR.Color);
    check(all(wT == 1.25) && numel(wW) == numel(wT) && all(wW == 3) && all(wF == 2) ...
        && all(wR == 3) && all(cR == [1 0 0], 'all'), ...
        'options.tickWidth 0 leaves the design''s tick width (Talk 1.25), a width overrides it, the figure''s own rules override that, and it goes with a tickColor');
    % a panel's box: "on" / "off" win over the design's rule and the figure's own aesthetics; "auto" leaves them
    sBx = F1.spec;
    sBx.panels(1).box = "on";
    sBx.panels(2).box = "auto";
    clf(fig);
    hBx = renderFigure(F1, sBx, fig, Design="Journal", UserAesthetics=false);
    drawnow;
    check(string(hBx.panels(1).axes.Box) == "on" && string(hBx.panels(2).axes.Box) == "off", ...
        'a panel''s box "on" shows the box a design turns off; "auto" keeps the design''s');
    sBx.panels(1).box = "off";
    sBx.panels(2).box = "on";
    sBx.aesthetics = PlotAesthetics.normalizeRules(struct('role', "axes", 'group', "", 'property', "Box", 'value', "on"));
    clf(fig);
    hBx = renderFigure(F1, sBx, fig, Design="Journal", UserAesthetics=false);
    drawnow;
    check(string(hBx.panels(1).axes.Box) == "off" && string(hBx.panels(2).axes.Box) == "on", ...
        'a panel''s box "off" and "on" also win over the figure''s own aesthetics rule');
    % a panel's axis sides and labels; the time stack (raster over PSTH) tells the time once, on the side its axes take
    xshown = @(ax) ~isempty(ax.XTickLabel) && strjoin(string(ax.XLabel.String), "") ~= "";
    sAx = F1.spec;
    sAx.panels(2).yLabel = "Spikes per second";
    sAx.panels(2).xLabel = "Latency (s)";
    sAx.panels(1).ySide = "right";
    clf(fig);
    hAx = renderFigure(F1, sAx, fig);
    drawnow;
    [ra, pa] = deal(hAx.panels(1).axes, hAx.panels(2).axes);
    check(~xshown(ra) && xshown(pa) && string(pa.XLabel.String) == "Latency (s)" && string(pa.YLabel.String) == "Spikes per second" ...
        && strcmp(ra.YAxisLocation, 'right') && strcmp(pa.YAxisLocation, 'left') && strcmp(pa.XAxisLocation, 'bottom'), ...
        'xLabel / yLabel replace the drawn labels (a time axis: where it tells the time); ySide "right" moves that panel''s y axis only');
    sAx = F1.spec;
    [sAx.panels.xSide] = deal("top");
    clf(fig);
    hAx = renderFigure(F1, sAx, fig);
    drawnow;
    [ra, pa] = deal(hAx.panels(1).axes, hAx.panels(2).axes);
    check(strcmp(ra.XAxisLocation, 'top') && strcmp(pa.XAxisLocation, 'top') && xshown(ra) && ~xshown(pa) ...
        && string(ra.XLabel.String) == "Time (s)", ...
        'a stack whose x axes are all on top tells the time once, at its top panel');
    sAx.panels(1).xSide = "bottom";   % the raster's at its bottom, on a PSTH whose x axis is on top: the PSTH's tells the time between them
    clf(fig);
    hAx = renderFigure(F1, sAx, fig);
    drawnow;
    check(~xshown(hAx.panels(1).axes) && xshown(hAx.panels(2).axes) && strcmp(hAx.panels(2).axes.XAxisLocation, 'top'), ...
        'a panel with its x axis at the bottom drops it over a time panel whose x axis is on top (that one tells the time)');
    sAx.panels(1).xSide = "top";
    sAx.panels(2).xSide = "bottom";
    clf(fig);
    hAx = renderFigure(F1, sAx, fig);
    drawnow;
    check(xshown(hAx.panels(1).axes) && xshown(hAx.panels(2).axes), ...
        'x axes facing away from each other (the top panel''s on top, the bottom one''s at the bottom) both keep their ticks');
    clf(fig);   % the note-band checks below use the figure drawn with the notes
    hN = renderFigure(F1, sN, fig);
    drawnow;
    xlR = xlim(hN.panels(1).axes);
    check(isequal(xlR, xlim(hN.panels(2).axes)) && isempty(hN.panels(1).axes.XTickLabel), ...
        'with a note band under the PSTH the raster still shares its time axis (no tick labels above the PSTH)');
    % a band below keeps the axes' left edge and width those of the plain panel under it; a band beside them keeps both panels' tick labels
    sB = F1.spec;
    sB.panels(1).options.yTicks = true;   % a nested note tile's inner edge follows its tick labels: with none the raster is a few pixels wider than the PSTH
    nB = EphysAnalysisConfig.defaults("Note");
    nB.text = "a band" + newline + "of two lines";
    nB.placement = "below";
    sB.panels(1).note = nB;
    clf(fig);
    hB = renderFigure(F1, sB, fig);
    drawnow;
    r1 = figureBox(hB.panels(1).axes, fig);
    r2 = figureBox(hB.panels(2).axes, fig);
    check(abs(r1(1) - r2(1)) <= 1 && abs(r1(3) - r2(3)) <= 1 && isempty(hB.panels(1).axes.XTickLabel) ...
        && string(ancestor(hB.panels(1).note, 'axes').Tag) == "noteHost", ...
        sprintf('a raster with a note below keeps the left edge and width of the PSTH under it (x %.1f / %.1f px, width %.1f / %.1f px)', ...
        r1(1), r2(1), r1(3), r2(3)));
    nB.placement = "right";
    sB.panels(1).note = nB;
    clf(fig);
    hB = renderFigure(F1, sB, fig);
    drawnow;
    r1 = figureBox(hB.panels(1).axes, fig);
    check(r1(3) < r2(3) - 5 && ~isempty(hB.panels(1).axes.XTickLabel) && ~isempty(hB.panels(2).axes.XTickLabel) ...
        && string(hB.panels(1).axes.XLabel.String) == "Time (s)", ...
        'a raster with a note right of it is narrower than the PSTH under it, so each keeps its own time tick labels');
    nB.placement = "below";
    nB.text = join(repmat("a long note line", 1, 4), newline);
    nB.fontSize = 14;
    sB.panels(2).note = nB;
    sB.panels(1).note = EphysAnalysisConfig.defaults("Note");
    clf(fig);
    hB = renderFigure(F1, sB, fig);
    drawnow;
    tB = hB.panels(2).note;
    bandB = ancestor(tB, 'axes');
    tB.Units = 'normalized';
    eB = tB.Extent;
    tB.Units = 'pixels';
    pxB = tB.Extent;
    check(eB(2) >= -0.02 && eB(2) + eB(4) <= 1.02 && bandB.Position(4) > pxB(4), ...
        sprintf('a four-line note below at 14 pt gets a band it fits in (its extent %s of the band)', mat2str(eB, 2)));
    nR = EphysAnalysisConfig.defaults("Note");
    nR.text = "turned";
    nR.placement = "left";
    nR.rotation = 90;
    nR.valign = "top";
    sB.panels(2).note = nR;
    clf(fig);
    hB = renderFigure(F1, sB, fig);
    drawnow;
    tR = hB.panels(2).note;
    check(string(tR.HorizontalAlignment) == "right" && string(tR.VerticalAlignment) == "middle" && tR.Position(2) > 0.8, ...
        'a note turned 90 degrees, valign top: right-aligned along y, at the band''s top');
    clf(fig);
    axN = axes(fig);
    hA = renderFigure(F1, sN, axN);
    check(isscalar(hA.panels(1).note) && ancestor(hA.panels(1).note, 'axes') == axN && isscalar(hA.panels(1).overlays), ...
        'into one axes the first panel draws its note and overlays in that axes');

    % title and subtitle
    h1 = renderFigure(F1, F1.spec, fig);
    want = "rp: " + F1.observation.label + " — " + eventRefLabel(F1.spec.ref) + " (" + height(F1.epochs) + " epochs)";
    [t1, s1] = figTitle(h1);
    check(h1.title == want && t1 == want && s1 == src.name ...
        && isequal([h1.panels.type], ["raster" "psth"]) && isequal(h1.panels(2).axes, h1.axes(2)), ...
        sprintf('the title names the figure, the observation, the event and the epochs ("%s"); the dataset is the subtitle', want));
    sT = F1.spec;
    sT.title = "My figure";
    hT = renderFigure(F1, sT, fig);
    check(hT.title == "My figure" && figTitle(hT) == "My figure" ...
        && string(hT.axes(1).Title.String) == F1.observation.label && string(hT.axes(2).Title.String) == "", ...
        'a title of the figure''s own: the top-left panel names the observation');
    % epochs kept with an artifact period (excludeArtifacts off): a line under the subtitle, by panel when their counts differ
    cfgA = cfg;
    cfgA.Defaults.Selection.excludeArtifacts = false;
    sA = cfgA.figureFor("rp");
    srcA = src;
    srcA.artifacts = [F1.epochs.t0Continuous(1:2) F1.epochs.t0Continuous(1:2) + 0.005];
    FA = rn.computeFigure(srcA, sA, Observation=Tu(1, :));
    nA = nnz(FA.epochs.artifact);
    wantA = sprintf("%d of %d epochs touch an artifact period", nA, height(FA.epochs));
    [~, sAn] = figTitle(renderFigure(FA, sA, fig));
    sOff = sA;
    sOff.style.ShowArtifactNote = false;
    [~, sOffT] = figTitle(renderFigure(FA, sOff, fig));
    FB = FA;   % the PSTH on epochs of its own, none with an artifact
    FB.panels(2).epochs = FA.epochs;
    FB.panels(2).epochs.artifact(:) = false;
    [~, sB] = figTitle(renderFigure(FB, sA, fig));
    wantB = sprintf("Epochs that touch an artifact period: %d of %d (raster_1)", nA, height(FA.epochs));
    check(nA >= 2 && height(FA.epochs) == height(F1.epochs) && sAn == src.name + " " + wantA && sOffT == src.name ...
        && sB == src.name + " " + wantB && s1 == src.name, ...
        sprintf('excludeArtifacts off: "%s" under the dataset; "%s" when a panel''s count differs; none with ShowArtifactNote off or clear epochs', ...
        wantA, wantB));

    % the layout: flush, exact gaps in px and %, rows in proportion, a panel's own size, the legend's band, a resize
    sL = F1.spec;
    hL = renderFigure(F1, sL, fig);
    drawnow;
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    check(sL.grid.spacing == "none" && abs(rA(2) - rB(2) - rB(4)) < 0.5 && abs(rA(1) - rB(1)) < 0.5 && abs(rA(3) - rB(3)) < 0.5, ...
        sprintf('spacing "none": the raster sits flush on the PSTH (%.2f px apart), with its left edge and width', rA(2) - rB(2) - rB(4)));
    sL.grid.spacing = "custom"; sL.grid.rowGap = 20; sL.grid.rowHeights = [1 2];
    hL = renderFigure(F1, sL, fig);
    drawnow;
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    check(abs(rA(2) - rB(2) - rB(4) - 20) < 0.5 && abs(rB(4) / rA(4) - 2) < 0.01, ...
        sprintf('a custom 20 px gap between the rows (no label between them: %.2f px between the plot areas); the rows exactly 1 : 2 (%.3f)', ...
        rA(2) - rB(2) - rB(4), rB(4) / rA(4)));
    sL.grid.gapUnits = "%"; sL.grid.rowGap = 10;
    hL = renderFigure(F1, sL, fig);
    drawnow;
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    gL = rA(2) - rB(2) - rB(4);
    check(abs(gL - 0.1 * (rA(4) + rB(4)) / 2) < 0.5, sprintf('a gap of 10 %% is a tenth of the mean row''s plot height (%.1f px)', gL));
    sL.grid.gapUnits = "px"; sL.grid.rowGap = 20; sL.grid.rowHeights = [];
    sL.panels(1).size = [0.5 1]; sL.panels(1).align = "right";
    hL = renderFigure(F1, sL, fig);
    drawnow;
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    check(abs(rA(3) - rB(3) / 2) < 0.5 && abs(rA(1) + rA(3) - rB(1) - rB(3)) < 0.5 && ~isempty(hL.panels(1).axes.XTickLabel) ...
        && string(hL.panels(1).axes.XLabel.String) == "Time (s)", ...
        'a raster half its cell''s width at its right: that panel only (the PSTH keeps the column''s width), its time tick labels kept');
    sL.panels(1).size = [1 1];
    hL = renderFigure(F1, sL, fig);
    drawnow;
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    lgL = findall(fig, 'Type', 'legend');
    lgL(1).Units = 'pixels';
    pg = lgL(1).Position;
    [~, sTitle] = figTitle(hL);
    thL = findall(hL.layout, 'Type', 'axes', 'Tag', 'titleHost');
    check(isscalar(lgL) && pg(1) > max(rA(1) + rA(3), rB(1) + rB(3)) && sTitle == src.name && figureBox(thL, fig) * [0 1 0 0].' >= rA(2) + rA(4) - 0.5 ...
        && all(ismember(["plotTitle" "plotSubtitle"], PlotAesthetics.components(hL.layout).Role)), ...
        'the legend in its band east of the panels; the title and subtitle over them (the editor''s plotTitle and plotSubtitle)');
    wB = rB(3);
    fig.Position(3) = fig.Position(3) + 200;
    fig.SizeChangedFcn(fig, []);   % MATLAB runs it for a visible figure only
    rA = figureBox(hL.panels(1).axes, fig);
    rB = figureBox(hL.panels(2).axes, fig);
    fig.Position(3) = fig.Position(3) - 200;
    fig.SizeChangedFcn(fig, []);
    check(abs(rB(3) - wB - 200) < 1 && abs(rA(2) - rB(2) - rB(4) - 20) < 0.5, ...
        sprintf('the figure 200 px wider is laid out again (its SizeChangedFcn): the PSTH %.1f px wider, the gap still 20 px', rB(3) - wB));

    % one time axis down a stack
    h3 = renderFigure(F3, F3.spec, fig);
    A = h3.axes;
    W = [F3.spec.window.pre F3.spec.window.post];
    check(numel(A) == 3 && all(arrayfun(@(a) isequal(xlim(a), W), A)), ...
        sprintf('the three time panels of a stack all show the figure''s window [%g %g]', W));
    check(isempty(A(1).XTickLabel) && isempty(A(2).XTickLabel) && ~isempty(A(3).XTickLabel) ...
        && string(A(3).XLabel.String) == "Time (s)" && string(A(1).XLabel.String) == "" && string(A(2).XLabel.String) == "", ...
        'the upper time panels of a column drop their x tick labels; the bottom one has them and "Time (s)"');
    ho = renderFigure(Fo, Fo.spec, fig);
    check(~isempty(ho.axes(1).XTickLabel) && ~isempty(ho.axes(2).XTickLabel) && isequal(xlim(ho.axes(2)), [-0.1 0.3]) ...
        && isequal(xlim(ho.axes(1)), [Fo.spec.window.pre Fo.spec.window.post]), ...
        'a panel with a window of its own keeps its own time axis, and the panel above keeps its tick labels');
    hr = renderFigure(F3, F3.spec, fig);
    lg = findall(fig, 'Type', 'legend');
    ls3 = string(lg(1).String);
    check(isscalar(lg) && all(arrayfun(@(g) nnz(ls3 == g) == 1, string(F3.groups.label))) && numel(unique(ls3)) == numel(ls3) ...
        && isequal(ls3(1:height(F3.groups)), reshape(string(F3.groups.label), 1, [])) && isgraphics(hr.layout), ...
        sprintf('one legend for the figure: each group once, first, then the layers (%s)', strjoin(ls3, ", ")));

    % per-trial traces, a heat map of trials, a panel's own legend, one group's figure
    htr = renderFigure(Ftr, Ftr.spec, fig);
    tt = findall(htr.axes(1), 'Tag', 'trialTrace');
    mt = findall(htr.axes(1), 'Tag', 'trace');
    nGtr = height(Ftr.groups);
    check(numel(tt) == nGtr && numel(mt) == nGtr && all(arrayfun(@(x) nnz(isnan(x.YData)), tt) >= 1) ...
        && sum(arrayfun(@(x) nnz(isnan(x.YData)), tt)) == nK && ismember("trialTrace", PlotAesthetics.roles().Role) ...
        && PlotAesthetics.roleLabel("trialTrace") == "Trial traces" && tt(1).LineWidth < mt(1).LineWidth ...
        && ~isequal(tt(1).Color, mt(1).Color), ...
        sprintf('trials "faint": one NaN-joined pale line of traces per group (%d epochs in all) under each mean, role trialTrace', nK));
    kids = htr.axes(1).Children;   % top first
    tags = string(get(kids, 'Tag'));
    iT = find(tags == "trialTrace");
    iM = find(ismember(tags, ["trace" "sem"]));
    check(~isempty(iT) && ~isempty(iM) && min(iT) > max(iM), ...
        'every group''s trial traces lie under every band and mean (drawn first: below them in the axes'' children)');
    ht5 = renderFigure(Ftr5, Ftr5.spec, fig);
    lg5 = findall(fig, 'Type', 'legend');
    check(numel(findall(ht5.axes(1), 'Tag', 'trialTrace')) == nGtr && isempty(findall(ht5.axes(1), 'Tag', 'trace')) ...
        && isempty(findall(ht5.axes(1), 'Tag', 'sem')) && (nGtr < 2 || (isscalar(lg5) && numel(lg5.String) >= nGtr)), ...
        'trials "only": the traces without the mean or its band; they stand for the groups in the legend');
    hth = renderFigure(Fth, Fth.spec, fig);
    ath = hth.axes(1);
    img = findall(ath, 'Tag', 'image');
    bands = findall(ath, 'Tag', 'rasterBand');
    check(isscalar(img) && isequal(size(img.CData), [nEh numel(Rth.t)]) && isequaln(img.CData, Rth.trialMatrix(Rth.trialOrder, :)) ...
        && numel(bands) >= height(Fth.groups) && string(ath.YLabel.String) == "Epoch (by Depth), descending" ...
        && isequal(xlim(ath), [Fth.spec.window.pre Fth.spec.window.post]) && string(ath.YDir) == "reverse", ...
        'a heat map of trials draws a row per epoch in its order, the groups as a strip at the left, y label "Epoch (by ...)"');
    hos = renderFigure(Fos, Fos.spec, fig);
    check(string(hos.axes(2).Title.String) == "all trials" && isscalar(findall(fig, 'Type', 'legend')), ...
        'a PSTH with a selection of its own that groups by nothing: titled "all trials", no legend of one group');
    fod = cfg.Figures(cfg.figureIndex("rp"));
    fod.id = "ownsel2";
    fod.panels(2).selection = struct('groupBy', "Depth", 'groupOrder', "descending");
    cfg = cfg.addFigure(fod);
    Fod = rn.computeFigure(src, cfg.figureFor("ownsel2"), Observation=Tu(1, :));
    hod = renderFigure(Fod, Fod.spec, fig);
    lgs = findall(fig, 'Type', 'legend');
    mine = arrayfun(@(l) isequal(l.Axes, hod.axes(2)), lgs);
    inPanel = lgs(mine);
    outer = lgs(~mine);
    gl = reshape(string(Fod.groups.label), 1, []);
    check(Fod.panels(2).ownSelection && numel(lgs) == 2 && isscalar(inPanel) && isscalar(outer) && string(inPanel.Location) == "best" ...
        && isequal(string(inPanel.String), reshape(string(Fod.panels(2).groups.label), 1, [])) && isequal(string(inPanel.String), fliplr(gl)) ...
        && isequal(string(outer.String(1:numel(gl))), gl) && string(hod.axes(2).Title.String) == "", ...
        'a PSTH with its own selection (groups in descending order): its own legend inside it; the figure''s legend the raster''s groups');
    hpg = renderFigure(Fpg, Fpg.spec, fig);
    sTg = Fpg.spec;
    sTg.title = "Card";
    hpg2 = renderFigure(Fpg, sTg, fig);
    check(endsWith(hpg.title, "(" + height(Fpg.epochs) + " epochs)") && contains(hpg.title, Tpg.label(2)) ...
        && hpg2.title == "Card · " + Tpg.groupLabel(2), ...
        sprintf('one trial group''s figure names its group in the title ("%s")', hpg.title));

    % skipped layers say why
    hr = renderFigure(F3, F3.spec, fig);   % again: the checks above drew other figures into fig
    notes = findall(hr.layout, 'Tag', 'layerNote');
    noteText = strjoin(string(get(notes, 'String')), " | ");
    check(~isempty(notes) && contains(noteText, auxMsg), sprintf('a skipped layer shows its reason in its panel ("%s")', noteText));
    hn = renderFigure(Fn, Fn.spec, fig);
    notes = findall(hn.layout, 'Tag', 'layerNote');
    check(isscalar(notes) && contains(string(notes.String), auxMsg) && notes.HorizontalAlignment == "center", ...
        'a panel with nothing to draw says why, in its middle');

    % events: raster marks, PSTH latency lines and rug
    he = renderFigure(Fe, Fe.spec, fig);
    rm = findall(he.axes(1), 'Tag', 'rasterEvent');
    okE = ~isempty(rm) && any(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim onset", rm)) ...
        && isequal(xlim(he.axes(1)), [Fe.spec.window.pre Fe.spec.window.post]);
    check(okE, 'events marks on a raster: every block''s rows marked in the mark''s look');
    hm = renderFigure(Fm, Fm.spec, fig);
    el = findall(hm.axes(2), 'Tag', 'eventLine');
    er = findall(hm.axes(2), 'Tag', 'eventRug');
    lg = findall(fig, 'Type', 'legend');
    check(~isempty(el) && numel(el) <= height(Fm.groups) && isscalar(er) && string(getappdata(er, 'PlotGroup')) == "Stim offset" ...
        && all(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim offset", el)) && any(string(lg(1).String) == "Stim offset"), ...
        sprintf('events marks on a PSTH: %d latency line(s) (one per group) and a rug, in the legend', numel(el)));

    % events as spans: a line on every raster row from onset to offset; a line per group on the PSTH, near its top
    hs = renderFigure(Fsp, Fsp.spec, fig);
    Wsp = [Fsp.spec.window.pre Fsp.spec.window.post];
    rs = findall(hs.axes(1), 'Tag', 'eventSpan', 'Type', 'line');
    rs = rs(arrayfun(@(x) any(isfinite(x.XData)), rs));
    inW = min(offS, Wsp(2)) >= max(onS, Wsp(1));
    okR = isscalar(rs) && nnz(isfinite(rs.XData)) == 2 * nnz(inW) && min(rs.XData) >= Wsp(1) - 1e-9 && max(rs.XData) <= Wsp(2) + 1e-9 ...
        && all(rs.YData(1:3:end) == rs.YData(2:3:end)) && string(getappdata(rs, 'PlotGroup')) == "Stim onset";
    ps = findall(hs.axes(2), 'Tag', 'eventSpan', 'Type', 'line');
    ps = ps(arrayfun(@(x) any(isfinite(x.XData)), ps));
    ylP = ylim(hs.axes(2));
    lg = findall(fig, 'Type', 'legend');
    check(okR && ~isempty(ps) && numel(ps) <= height(Fsp.groups) && all(arrayfun(@(x) x.YData(1) > ylP(1) + 0.8 * diff(ylP), ps)) ...
        && all(arrayfun(@(x) diff(x.XData) > 0, ps)) && any(string(lg(1).String) == "Stim onset"), ...
        sprintf('spans: %d raster rows each a horizontal line clipped to the window; %d PSTH line(s) (one per group) near the top; in the legend', ...
        nnz(inW), numel(ps)));

    % an event-trace panel: a row per line, bars clipped to the window, a baseline each; the rows display, by group
    ht = renderFigure(Ftrace, Ftrace.spec, fig);
    axT = ht.axes(1);
    Wt = [Ftrace.spec.window.pre Ftrace.spec.window.post];
    bars = findall(axT, 'Tag', 'eventBar', 'Type', 'patch');
    bars = bars(arrayfun(@(x) ~isempty(x.Faces), bars));
    bl = findall(axT, 'Tag', 'eventBaseline');
    groupsOf = reshape(string(arrayfun(@(x) string(getappdata(x, 'PlotGroup')), bars)), 1, []);
    kept = @(on, off) nnz(min(off, Wt(2)) >= max(on, Wt(1)));
    vx = vertcat(bars.Vertices);
    bPlat = bars(groupsOf == "Platform");
    check(numel(bars) == 2 && isequal(sort(groupsOf), ["Platform" "Stim"]) && size(bPlat.Faces, 1) == kept(onP, offP) ...
        && min(vx(:, 1)) >= Wt(1) - 1e-9 && max(vx(:, 1)) <= Wt(2) + 1e-9 && abs(bPlat.FaceAlpha - 0.3) < 1e-9 ...
        && numel(bl) == 2 && isequal(string(axT.YTickLabel).', ["Platform" "Stim"]) && isequal(xlim(axT), Wt) ...
        && any(contains(string(get(findall(axT, 'Tag', 'layerNote'), 'String')), "do not draw units")), ...
        sprintf('event traces: a row per line (Stim on top), %d Platform bars clipped to the window, translucent when overlaid, a baseline each; the units layer noted', ...
        size(bPlat.Faces, 1)));
    long = offP > Wt(2) | onP < Wt(1);
    check(~any(long) || any(abs(vx(:, 1) - Wt(1)) < 1e-9 | abs(vx(:, 1) - Wt(2)) < 1e-9), ...
        'an interval that starts before or ends after the window is drawn to its edge');
    sTrace = Ftrace.spec;
    sTrace.panels(1).options.display = "line";
    sTrace.panels(1).options.trials = "rows";
    sTrace.panels(1).options.colorBy = "group";
    sTrace.panels(1).options.showBaseline = false;
    ht2 = renderFigure(Ftrace, sTrace, fig);
    lv = findall(ht2.axes(1), 'Tag', 'eventLevel');
    gb = findall(ht2.axes(1), 'Tag', 'eventGroupBand');
    gb = gb(arrayfun(@(x) all(isfinite(x.XData(:))), gb));
    lvGroups = unique(string(arrayfun(@(x) string(getappdata(x, 'PlotGroup')), lv)));
    nGt = height(Ftrace.groups);
    lg = findall(fig, 'Type', 'legend');
    check(~isempty(lv) && numel(lv) <= 2 * nGt && all(ismember(lvGroups, string(Ftrace.groups.label))) && numel(gb) == nGt ...
        && isempty(findall(ht2.axes(1), 'Tag', 'eventBaseline')) && all(arrayfun(@(x) all(isnan(x.XData(:))), findall(ht2.axes(1), 'Tag', 'eventBar'))) ...
        && all(ismember(string(Ftrace.groups.label), string(lg(1).String))), ...
        sprintf('event traces as logic levels, a sub-row per epoch, by group: %d level lines in the groups'' colors, a band per group, no baseline, the groups in the legend', numel(lv)));
    check(all(arrayfun(@(x) isa(x, 'matlab.graphics.primitive.Patch') && strcmp(x.FaceColor, 'none') && x.EdgeAlpha == 1, lv)) ...
        && isempty(findall(ht2.axes(1), 'Type', 'line', 'Tag', 'eventLevel')), ...
        'the logic levels are patch edges (EdgeAlpha: the opacity, documented), not lines with an RGBA color');

    % the sub-rows in a raster's order (figEpochOrder): the default by group then time; descending time, groups mixed; by an event
    % (traceRows reads the drawn bars' epochs and heights, rowsAgree compares them with figEpochOrder's order)
    sRows = Ftrace.spec;
    sRows.panels(1).options.trials = "rows";
    ht3 = renderFigure(Ftrace, sRows, fig);
    [epF, yF] = traceRows(ht3.axes(1), Lt1.R, Wt, "Stim");
    okDefault = rowsAgree(Lt1.R, sRows.panels(1).options, epF, yF);
    gF = Lt1.R.epochGroup(epF);
    okGroups = all(arrayfun(@(g) issorted(-yF(gF == g)), unique(gF)));   % in a group, a later epoch lower
    sRows.panels(1).options.rasterByGroup = false;
    sRows.panels(1).options.rasterSortOrder = "descending";
    ht3 = renderFigure(Ftrace, sRows, fig);
    [epF2, yF2] = traceRows(ht3.axes(1), Lt1.R, Wt, "Stim");
    check(okDefault && okGroups && rowsAgree(Lt1.R, sRows.panels(1).options, epF2, yF2) && issorted(yF2) && yF2(end) > yF2(1), ...
        'trials "rows": by group then time by default (as before); descending, groups mixed: the last epoch on top');
    htS = renderFigure(FtS, FtS.spec, fig);
    RS1 = FtS.panels(1).layers(1).R;
    [epS1, yS1] = traceRows(htS.axes(1), RS1, Wt, "Stim");
    check(rowsAgree(RS1, oS, epS1, yS1), 'trials "rows" sorted by the Platform latency (by group first): the sub-rows in figEpochOrder''s order');

    % a zero-length (or very short) bar: a tick minWidth points wide through its middle, in its color; none with minWidth 0
    htZ = renderFigure(FtZ, FtZ.spec, fig);
    tk = findall(htZ.axes(1), 'Tag', 'eventTick');
    tk = tk(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim", tk));
    bZ = findall(htZ.axes(1), 'Tag', 'eventBar', 'Type', 'patch');
    bZ = bZ(arrayfun(@(x) string(getappdata(x, 'PlotGroup')) == "Stim" && ~isempty(x.Faces), bZ));
    okTick = isscalar(tk) && isscalar(bZ) && tk.LineWidth == FtZ.spec.panels(1).options.minWidth && isequal(tk.EdgeColor, bZ.FaceColor) ...
        && abs(tk.EdgeAlpha - bZ.FaceAlpha) < 1e-9 && any(abs(tk.XData - zOn) < 1e-9) && strcmp(tk.FaceColor, 'none');
    svgZ = fullfile(root, "eventTick.svg");
    exportgraphics(fig, svgZ, 'ContentType', 'vector');
    txtZ = fileread(svgZ);
    sZ = FtZ.spec;
    sZ.panels(1).options.minWidth = 0;
    htZ0 = renderFigure(FtZ, sZ, fig);
    check(okTick && contains(txtZ, "stroke-opacity=""0.3") && isempty(findall(htZ0.axes(1), 'Tag', 'eventTick')), ...
        'a zero-length interval: a tick minWidth (1 pt) wide in the bar''s color and opacity, which the SVG keeps (stroke-opacity 0.3); none with minWidth 0');
    sL = Ftrace.spec;
    sL.panels(1).options.display = "line";   % overlaid: translucent levels
    renderFigure(Ftrace, sL, fig);
    svgL = fullfile(root, "eventLevel.svg");
    exportgraphics(fig, svgL, 'ContentType', 'vector');
    check(contains(fileread(svgL), "stroke-opacity=""0.3"), 'translucent logic levels keep their opacity in an SVG export (stroke-opacity 0.3)');

    % a stacked continuous panel whose only signal layer is skipped still draws its marks
    cfg = cfg.addFigure(struct('observe', struct('data', "LFP"), 'panels', {{struct('id', "sig", 'type', "continuous", ...
        'layers', [auxF ev], 'options', struct('stack', "items"))}}), Id="cmarks");   % the AUX layer cannot follow an LFP channel
    try
        Fk1 = rn.computeFigure(src, cfg.figureFor("cmarks"));
        hk1 = renderFigure(Fk1, Fk1.spec, fig);
        nt = findall(hk1.axes(1), 'Tag', 'layerNote');
        noteText = "";
        if ~isempty(nt); noteText = strjoin(string(get(nt, 'String')), " "); end
        sk1 = Fk1.panels(1).layers(1).skip;
        ok1 = sk1 ~= "" && sk1 ~= "disabled" && Fk1.panels(1).layers(2).skip == "" ...
            && isscalar(findall(hk1.axes(1), 'Tag', 'eventRug')) && contains(noteText, sk1);
        msg1 = "";
    catch ME
        ok1 = false;
        msg1 = " (" + ME.message + ")";
    end
    check(ok1, "a stacked continuous panel whose signal layers are all skipped still draws its marks, and says why" + msg1);

    % a raster of five or more blocks keeps every block's name on a flush stack
    fixedAll = EphysAnalysisConfig.defaultLayer("raster");
    fixedAll.binding = "fixed";
    trOff = tr;
    trOff.event.edge = "offset";
    fr5 = cfg.Figures(cfg.figureIndex("rp"));
    fr5.id = "blocks";
    fr5.panels(1).layers = [fr5.panels(1).layers fixedAll tr trOff];
    cfg = cfg.addFigure(fr5);
    F5 = rn.computeFigure(src, cfg.figureFor("blocks"), Observation=Tu(1, :));
    h5 = renderFigure(F5, F5.spec, fig);
    ra = h5.axes(1);
    nb = 1 + numel(F5.panels(1).layers(2).R.raster) + 2;
    check(nb >= 5 && numel(ra.YTick) == nb && numel(ra.YTickLabel) == nb && string(ra.YTickLabel{end}) == "Stim offset" ...
        && isempty(ra.XTickLabel), sprintf('a raster of %d blocks over a PSTH keeps every block''s name (no seam clearing of named ticks)', nb));

    % a raster over a waveforms panel over a PSTH keeps its own time axis
    fw3 = cfg.Figures(cfg.figureIndex("rp"));
    fw3.id = "rwp";
    fw3 = EphysAnalysisConfig.placePanel(fw3, struct('id', "wave", 'type', "waveforms", ...
        'layers', EphysAnalysisConfig.defaultLayer("waveforms")), "below", "raster_1");
    cfg = cfg.addFigure(fw3);
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Fw3 = rn.computeFigure(src, cfg.figureFor("rwp"), Observation=Tu(1, :));
    warning(wsn); warning(wsw);
    h6 = renderFigure(Fw3, Fw3.spec, fig);
    axOf = @(id) h6.panels([h6.panels.id] == id).axes;
    r6 = axOf("raster_1");
    check(Fw3.spec.panels([Fw3.spec.panels.id] == "wave").row == 2 && ~isempty(r6.XTickLabel) && string(r6.XLabel.String) == "Time (s)" ...
        && ~isempty(axOf("psth_1").XTickLabel) && string(axOf("psth_1").XLabel.String) == "Time (s)", ...
        'a raster over a waveforms panel keeps its tick labels and "Time (s)": the next time panel down is not what sits under it');

    % a stacked PSTH, an auROC PSTH, rate and tuning panels, the waveforms' probe layout
    hs = renderFigure(Fst, Fst.spec, fig);
    as = hs.axes(2);
    nGs = height(Fst.groups);
    sb = findall(as, 'Tag', 'stackBase');
    lg = findall(fig, 'Type', 'legend');
    lgs = string(lg(1).String);
    check(numel(as.YAxis) == 2 && numel(sb) == nGs && numel(as.YAxis(1).TickValues) == nGs ...
        && all(arrayfun(@(g) nnz(lgs == g) == 1, string(Fst.groups.label))) && string(as.YAxis(1).Label.String) == "Depth" ...
        && isequal(xlim(as), [Fst.spec.window.pre Fst.spec.window.post]) && isempty(findall(as, 'Tag', 'chanceLine')), ...
        sprintf('a stacked PSTH: %d rows (a baseline each, the groups'' values on the left axis, named Depth), each group once in the legend', nGs));
    sbY = arrayfun(@(h) h.YData(1), sb);
    sbG = arrayfun(@(h) string(getappdata(h, 'PlotGroup')), sb);
    [~, top] = max(sbY);
    [~, bot] = min(sbY);
    lbl = string(as.YAxis(1).TickLabels);
    rl = rowLabels(Fst.panels(2).layers(1).R);
    check(sbG(top) == string(Fst.groups.label(1)) && sbG(bot) == string(Fst.groups.label(end)) && lbl(end) == rl(1), ...
        'a stacked PSTH lists its groups as a raster does: the first on top, its value the top tick label');
    fs5 = Fst;   % the PSTH's result cut to one group (figSliceGroup)
    fs5.panels(2).layers(1).R = figSliceGroup(Fst.panels(2).layers(1).R, 1);
    h1g = renderFigure(fs5, fs5.spec, fig);
    check(numel(h1g.axes(2).YAxis) == 1 && isempty(findall(h1g.axes(2), 'Tag', 'stackBase')), 'a stack of one group is drawn overlaid');
    fixedM = EphysAnalysisConfig.defaultLayer("psth");
    fixedM.binding = "fixed"; fixedM.units.ids = Tu.unitId(1:m3).'; fixedM.aggregate = "mean";
    cfgS = cfg;
    k4 = cfgS.figureIndex("stacked");
    cfgS.Figures(k4).panels(2).layers = [cfgS.Figures(k4).panels(2).layers fixedM];
    Fs2 = rn.computeFigure(src, cfgS.figureFor("stacked"), Observation=Tu(1, :));
    hs2 = renderFigure(Fs2, Fs2.spec, fig);
    yl2 = ylim(hs2.axes(2));
    rl2 = findall(hs2.axes(2), 'Tag', 'rate');
    lg = findall(fig, 'Type', 'legend');
    lgs2 = string(lg(1).String);
    check(any(lgs2 == Fs2.panels(2).layers(2).name) && numel(rl2) >= 2 * nGs && yl2(2) > 0, ...
        'a stacked PSTH with a second layer: its mean drawn into the same rows, named in the legend');

    % first-spike latency: a mark on each epoch's first spike, on that epoch's tick, whatever the rows' order
    Rfr = Ffs.panels(1).layers(1).R;
    Lfr = firstSpikeLatency(Rfr, MinSec=0.005, MaxSec=0.3);
    sF = Ffs.spec;
    hF = renderFigure(Ffs, sF, fig);
    [okF, nF, epF] = marksOnTicks(hF.axes(1), Lfr.lat);
    lgF = findall(fig, 'Type', 'legend');
    lgF = string(lgF(1).String);   % before the redraw deletes it
    sF.panels(1).options.rasterByGroup = false;
    sF.panels(1).options.rasterSortOrder = "descending";
    sF.panels(1).options.firstSpike.marker = "square";
    sF.panels(1).options.firstSpike.color = "red";
    sF.panels(1).options.firstSpike.filled = true;
    sF.panels(1).options.firstSpike.size = 7;
    hF2 = renderFigure(Ffs, sF, fig);
    [okF2, nF2] = marksOnTicks(hF2.axes(1), Lfr.lat);
    mk2 = findall(hF2.axes(1), 'Tag', 'firstSpike');
    mk2 = mk2(arrayfun(@(h) any(isfinite(h.XData)), mk2));
    look2 = all(arrayfun(@(h) strcmp(h.Marker, 'square') && h.MarkerSize == 7 && isequal(h.Color, [1 0 0]) ...
        && isequal(h.MarkerFaceColor, [1 0 0]), mk2));
    yAll = cell2mat(arrayfun(@(h) h.YData(:), mk2, 'UniformOutput', false));
    check(okF && okF2 && nF == nnz(isfinite(Lfr.lat)) && nF2 == nF && isequal(sort(epF), find(isfinite(Lfr.lat))) && look2 ...
        && any(lgF == "First spike") && numel(unique(yAll)) == nF, ...
        sprintf(['first-spike marks: one per epoch with a spike in [5 300] ms (%d), at its latency on that epoch''s tick, by ' ...
        'group and time, then descending with the groups mixed; marker, size, color and fill from the options; "First spike" ' ...
        'in the legend'], nF));
    sF.panels(1).options.firstSpike.color = "gray";   % a name validatecolor lacks, which the editor's list offers
    hFg = renderFigure(Ffs, sF, fig);
    mkG = findall(hFg.axes(1), 'Tag', 'firstSpike');
    mkG = mkG(arrayfun(@(h) any(isfinite(h.XData)), mkG));
    check(~isempty(mkG) && all(arrayfun(@(h) isequal(h.Color, [0.5 0.5 0.5]), mkG)), ...
        'first-spike marks in "gray" are gray, not their group''s color');
    sF5 = F5.spec;   % the five blocks: the further blocks' bands (rasterInto's stack mode) carry their own marks
    sF5.panels(1).options.firstSpike = EphysAnalysisConfig.normalizeSection("FirstSpike", struct('enabled', true, 'maxSec', 0.3));
    hF5 = renderFigure(F5, sF5, fig);
    want5 = 0;
    for jF = 1:numel(F5.panels(1).layers)
        RF = F5.panels(1).layers(jF).R;
        if F5.panels(1).layers(jF).skip ~= "" || ~isfield(RF, 'raster') || isempty(RF.raster); continue; end
        LF = firstSpikeLatency(RF, MaxSec=0.3);
        want5 = want5 + nnz(isfinite(LF.lat));
    end
    [ok5, n5] = marksOnTicks(hF5.axes(1), []);
    check(ok5 && n5 == want5 && n5 > nF, sprintf(['first-spike marks in a raster of several blocks: every block''s ' ...
        'unit marked on its own ticks (%d marks)'], n5));
    % a PSTH's box plot: prctile's statistics per group, in a band above the traces
    Rfp = Ffs.panels(2).layers(1).R;
    Lfp = firstSpikeLatency(Rfp, MinSec=0.005, MaxSec=0.3);
    hF = renderFigure(Ffs, Ffs.spec, fig);   % drawn again: the redraws above replaced its axes
    ap = hF.axes(2);
    okB = true;
    nBox = 0;
    for gB = 1:height(Ffs.groups)
        glF = string(Ffs.groups.label(gB));
        vF = Lfp.lat(Lfp.epochGroup == gB);
        vF = vF(isfinite(vF));
        bxF = findall(ap, 'Tag', 'latencyBox', '-function', @(h) string(getappdata(h, 'PlotGroup')) == glF);
        mdF = findall(ap, 'Tag', 'latencyMedian', '-function', @(h) string(getappdata(h, 'PlotGroup')) == glF);
        wkF = findall(ap, 'Tag', 'latencyWhisker', '-function', @(h) string(getappdata(h, 'PlotGroup')) == glF);
        if isempty(vF); okB = okB && isempty(bxF); continue; end
        nBox = nBox + 1;
        qF = prctile(vF, [25 50 75]);
        iqF = qF(3) - qF(1);
        inF = vF >= qF(1) - 1.5 * iqF & vF <= qF(3) + 1.5 * iqF;
        stB = getappdata(bxF, 'LatencyStats');
        okB = okB && isscalar(bxF) && isscalar(mdF) && isscalar(wkF) && max(abs(sort(unique(bxF.XData(:))).' - qF([1 3]))) < 1e-12 ...
            && all(abs(mdF.XData - qF(2)) < 1e-12) && abs(min(wkF.XData) - min(vF(inF))) < 1e-12 && abs(max(wkF.XData) - max(vF(inF))) < 1e-12 ...
            && stB.n == numel(vF) && stB.nEpochs == nnz(Lfp.epochGroup == gB);
    end
    trF = [findall(ap, 'Tag', 'rate'); findall(ap, 'Tag', 'rateFill'); findall(ap, 'Tag', 'sem')];
    yTr = cell2mat(arrayfun(@(h) reshape(h.YData, [], 1), trF, 'UniformOutput', false));
    yTr = yTr(isfinite(yTr));
    bxAll = findall(ap, '-regexp', 'Tag', '^latency');
    yBx = cell2mat(arrayfun(@(h) reshape(h.YData, [], 1), bxAll, 'UniformOutput', false));
    yBx = yBx(isfinite(yBx));
    ylp = ylim(ap);
    check(okB && nBox >= 1 && min(yBx) > max(yTr) && max(yBx) <= ylp(2) && all(ap.YTick < min(yBx)), ...
        sprintf(['a PSTH''s latency box plot: one box per group with a first spike (%d), its box, median and whiskers ' ...
        'prctile''s quartiles and Tukey''s 1.5 IQR, in a band above every trace, the y ticks under it'], nBox));
    % stacked: one box per row, in that row's lane above its PSTH, under the next row up
    hS = renderFigure(FfsS, FfsS.spec, fig);
    aS = hS.axes(2);
    sbS = findall(aS, 'Tag', 'stackBase');
    baseOf = containers.Map(arrayfun(@(h) char(string(getappdata(h, 'PlotGroup'))), sbS, 'UniformOutput', false), ...
        arrayfun(@(h) h.YData(1), sbS, 'UniformOutput', false));
    bases = sort(cell2mat(values(baseOf)));
    okS = true;
    nS = 0;
    for gB = 1:height(FfsS.groups)
        glF = char(string(FfsS.groups.label(gB)));
        bxF = findall(aS, 'Tag', 'latencyBox', '-function', @(h) string(getappdata(h, 'PlotGroup')) == glF);
        if isempty(bxF); continue; end
        nS = nS + 1;
        b0 = baseOf(glF);
        above = bases(bases > b0 + 1e-9);
        trgF = findall(aS, '-regexp', 'Tag', '^(rate|rateFill|sem)$', '-function', @(h) string(getappdata(h, 'PlotGroup')) == glF);
        ygF = cell2mat(arrayfun(@(h) reshape(h.YData, [], 1), trgF, 'UniformOutput', false));
        ygF = ygF(isfinite(ygF));
        okS = okS && isscalar(bxF) && min(bxF.YData) > max(ygF) && (isempty(above) || max(bxF.YData) < min(above));
    end
    check(okS && nS == nBox && numel(sbS) == height(FfsS.groups), sprintf(['a stacked PSTH''s latency boxes: one per row ' ...
        '(%d), each above its own PSTH and under the next row up'], nS));
    % with the y limits: the band stays outside the traces' range in every yLimMode, and the panel's yExtent is the traces'
    okY = true;
    for ym = ["auto" "rows" "fixed" "batch"]
        sY = FfsS.spec;
        sY.panels(2).options.yLimMode = ym;
        sY.panels(2).options.yLim = [0 5];
        hY = renderFigure(FfsS, sY, fig, BatchYLim=struct('id', sY.panels(2).id, 'lim', [0 7], 'n', 2));
        aY = hY.panels(2).axes;
        sbY = findall(aY, 'Tag', 'stackBase');
        for h = reshape(sbY, 1, [])
            glY = string(getappdata(h, 'PlotGroup'));
            mp = getappdata(h, 'StackMap');
            bxY = findall(aY, 'Tag', 'latencyBox', '-function', @(x) string(getappdata(x, 'PlotGroup')) == glY);
            if isempty(bxY); continue; end
            topY = NaN;   % the row's top value on the axis: its range's top in a shared mode, its reach (any group's trace) in auto
            switch ym
                case "fixed", topY = mp(1) + mp(2) * 5;
                case "batch", topY = mp(1) + mp(2) * 7;
                otherwise
                    trY = findall(aY, '-regexp', 'Tag', '^(rate|rateFill|sem)$', '-function', @(x) string(getappdata(x, 'PlotGroup')) == glY);
                    yv = cell2mat(arrayfun(@(x) reshape(x.YData, [], 1), trY, 'UniformOutput', false));
                    topY = max(yv(isfinite(yv)));
            end
            above = sort(arrayfun(@(x) x.YData(1), sbY));
            above = above(above > mp(1) + 1e-9);
            okY = okY && min(bxY.YData) > topY && (isempty(above) || max(bxY.YData) < min(above));
        end
    end
    sO = Ffs.spec;
    sO.panels(2).options.yLimMode = "fixed";
    sO.panels(2).options.yLim = [0 10];
    hO = renderFigure(Ffs, sO, fig);
    bxO = findall(hO.panels(2).axes, '-regexp', 'Tag', '^latency');
    yO = cell2mat(arrayfun(@(h) reshape(h.YData, [], 1), bxO, 'UniformOutput', false));
    eO = figureYExtents(Ffs, setfield(sO, 'panels', setfield(sO.panels, {2}, 'options', ...
        setfield(sO.panels(2).options, 'yLimMode', "batch"))));   %#ok<SFLD>
    hA = renderFigure(Ffs, Ffs.spec, fig);
    check(okY && min(yO(isfinite(yO))) > 10 && isequal(hO.panels(2).yExtent, [0 10]) ...
        && isscalar(eO) && eO.lim(2) < max(ylim(hA.panels(2).axes)), ...
        ['the latency boxes stay outside the traces'' range in every yLimMode (stacked: above each row''s top, under the next ' ...
        'row; overlaid fixed: above yLim), and the panel''s yExtent (a run''s batch range) is the traces'' range, not the band']);
    % rasterSort "latency": the rows by the first spike's latency in firstSpike's window, epochs without one last, within the groups
    sL = Ffs.spec;
    sL.panels(1).options.rasterSort = "latency";
    hL = renderFigure(Ffs, sL, fig);
    [okL, nL] = marksOnTicks(hL.axes(1), Lfr.lat);
    oL = struct('rasterSort', "latency", 'rasterSortOrder', "ascending", 'rasterByGroup', true, ...
        'firstSpike', sL.panels(1).options.firstSpike);
    [ordL, nameL] = figEpochOrder(Rfr, oL, 1);
    rowL = zeros(size(ordL)); rowL(ordL) = 1:numel(ordL);
    okRowL = true;   % each mark on its epoch's row in that order
    for h = reshape(findall(hL.axes(1), 'Tag', 'firstSpike'), 1, [])
        eL = reshape(getappdata(h, 'PlotEpochs'), [], 1);
        if ~isempty(eL); okRowL = okRowL && isequal(h.YData(:), rowL(eL)); end
    end
    okOrdL = issorted(Rfr.epochGroup(ordL));
    for gL = reshape(unique(Rfr.epochGroup), 1, [])
        vL = Lfr.lat(ordL(Rfr.epochGroup(ordL) == gL));
        kL = find(isnan(vL), 1);
        okOrdL = okOrdL && issorted(vL(~isnan(vL))) && (isempty(kL) || all(isnan(vL(kL:end))));
    end
    oLd = oL; oLd.rasterSortOrder = "descending"; oLd.rasterByGroup = false;
    [ordD, nameD] = figEpochOrder(Rfr, oLd, 1);
    vD = Lfr.lat(ordD);
    nanD = find(isnan(vD), 1);
    oLw = oL; oLw.firstSpike.minSec = 0.1;   % the window moves the key
    Lw = firstSpikeLatency(Rfr, MinSec=0.1, MaxSec=0.3);
    [ordW, ~] = figEpochOrder(Rfr, oLw, 1);
    [~, wantW] = sortrows([Rfr.epochGroup(:) Lw.lat(:) (1:numel(ordW)).'], [1 2 3]);
    Rno = rmfield(Rfr, 'raster');   % no raster rows: time order, as for any key a result lacks
    ordN = figEpochOrder(Rno, oL, 1);
    [~, wantN] = sort(Rno.epochGroup(:));
    check(okL && okRowL && okOrdL && nL == nnz(isfinite(Lfr.lat)) && nameL == "Epoch (by first-spike latency)" ...
        && issorted(vD(1:(min([nanD numel(vD) + 1]) - 1)), 'descend') && (isempty(nanD) || all(isnan(vD(nanD:end)))) ...
        && nameD == "Epoch (by first-spike latency), descending, groups mixed" && isequal(ordW(:), wantW(:)) ...
        && isequal(ordN(:), wantN(:)), ...
        ['a raster sorted by rasterSort "latency": within each group ascending by the first spike''s latency in firstSpike''s ' ...
        'window with the epochs without one last, the marks on their epochs'' rows; descending with the groups mixed; ' ...
        'the window moves the key; a result without raster rows keeps the time order']);
    % the PSTH's trial counts: "n = 24" per group in the plot, in the legend entries, at the rows' right ends, beside a heat map's rows
    nEp = double(Rfp.nEpochs(:));
    glC = string(Ffs.groups.label);
    sC = Ffs.spec;
    sC.panels(2).options.trialCount = "text";
    hC = renderFigure(Ffs, sC, fig);
    txC = findall(hC.panels(2).axes, 'Tag', 'trialCount');
    okTx = numel(txC) == height(Ffs.groups);
    for gC = 1:height(Ffs.groups)
        tC = findall(txC, '-function', @(h) string(getappdata(h, 'PlotGroup')) == glC(gC));
        okTx = okTx && isscalar(tC) && string(tC.String) == "n = " + nEp(gC);
    end
    sC.panels(2).options.trialCount = "legend";
    hC = renderFigure(Ffs, sC, fig);
    lgC = findall(fig, 'Type', 'legend');
    lgC = string(lgC(1).String);
    okLg = isempty(findall(hC.panels(2).axes, 'Tag', 'trialCount')) && all(ismember(glC + " (n = " + nEp + ")", lgC));
    sC = FfsS.spec;
    sC.panels(2).options.trialCount = "text";
    hC = renderFigure(FfsS, sC, fig);
    aC = hC.panels(2).axes;
    txS = findall(aC, 'Tag', 'trialCount');
    okSt = numel(txS) == height(FfsS.groups);
    for gC = 1:height(FfsS.groups)   % at the right end of the group's row, above its baseline
        tC = findall(txS, '-function', @(h) string(getappdata(h, 'PlotGroup')) == string(FfsS.groups.label(gC)));
        bC = findall(aC, 'Tag', 'stackBase', '-function', @(h) string(getappdata(h, 'PlotGroup')) == string(FfsS.groups.label(gC)));
        okSt = okSt && isscalar(tC) && isscalar(bC) && tC.Position(2) > bC.YData(1) ...
            && abs(tC.Position(1) - FfsS.panels(2).layers(1).R.edges(end)) < 1e-9 && strtrim(string(tC.String)) == "n = " + nEp(gC);   % padded by a space
    end
    sC = Ffs.spec;
    sC.panels(2).options.display = "heatmap";
    sC.panels(2).options.trialCount = "text";
    hC = renderFigure(Ffs, sC, fig);
    txH = findall(hC.panels(2).axes, 'Tag', 'trialCount');
    okHt = numel(txH) == height(Ffs.groups) && isequal(sort(arrayfun(@(h) h.Position(2), txH)).', 1:height(Ffs.groups));
    sC.panels(2).options.trialCount = "legend";
    hC = renderFigure(Ffs, sC, fig);
    ylC = string(hC.panels(2).axes.YTickLabel);
    okHl = isempty(findall(hC.panels(2).axes, 'Tag', 'trialCount')) && all(endsWith(ylC(:), ")")) && all(contains(ylC(:), "(n = "));
    check(okTx && okLg && all(nEp > 0), ...
        ['a PSTH''s trialCount: text "n = <trials>" per group, tagged with the group; "legend" appends it to the legend ' ...
        'entries instead']);
    check(okSt, 'a stacked PSTH''s trialCount: the text at the right end of each row, above its baseline');
    check(okHt && okHl, 'a PSTH heat map''s trialCount: the text beside each row (text), or in the row''s label (legend)');
    ha = renderFigure(Fau, Fau.spec, fig);
    aa = ha.axes(2);
    check(isscalar(findall(aa, 'Tag', 'chanceLine')) && isequal(ylim(aa), [0 1]) && ~isempty(findall(aa, '-regexp', 'Tag', '^rate(Fill)?$')) ...
        && (Lau.R.auroc.cutoff == "none" || (isscalar(findall(aa, 'Tag', 'modWindow')) && isscalar(findall(aa, 'Tag', 'modMarks')))) ...
        && string(aa.YLabel.String) == "auROC", ...
        'an auROC PSTH: on 0-1 from the chance line at 0.5, the modulation window shaded and the unit''s calls marked');
    if Lau.R.auroc.cutoff ~= "none"
        mk = string(findall(aa, 'Tag', 'modMarks').String);
        mk = strtrim(split(regexprep(mk, '\\color\[rgb\]\{[^}]*\}', ''), "  "));
        dirs = Lau.R.auroc.direction(1, :);
        want = repmat("-", 1, numel(dirs));
        want(dirs == "increase") = "\uparrow";
        want(dirs == "decrease") = "\downarrow";
        want(dirs == "none") = "n.s.";
        check(isequal(reshape(mk, 1, []), want), ...
            'an auROC PSTH''s marks: per trial group the unit''s call, an up or down arrow or n.s., in the group''s color');
    end
    acA = figureAurocCalls(Fau);
    capA = figureCaption(cfg.figureFor("auroc"), Tu(1, :), Dataset="d1", Auroc={acA});
    capCalls = "units called over [0 0.5] s by the 95% CI cutoff";
    check(isstruct(acA) && acA.cutoff == Lau.R.auroc.cutoff && acA.nUnits == Lau.R.auroc.nUnits ...
        && contains(capA, "auROC against the baseline [-0.2 0] s, from the PSTH's bins in 100 ms windows, tiled") ...
        && (acA.cutoff == "none" || (contains(capA, capCalls) && contains(capA, sprintf("(of %d units)", acA.nUnits)))) ...
        && ~contains(figureCaption(cfg.figureFor("rp"), Tu(1, :)), "auROC"), ...
        'an auROC figure''s caption: how the auROC is made, and with the calls (figureAurocCalls) what the cutoff called');
    fau2 =cfg.Figures(cfg.figureIndex("auroc"));
    fau2.id = "aurocStack";
    fau2.panels(2).options.stack = "groups";
    cfgA = cfg.addFigure(fau2);
    wa1 = warning('off', 'aurocCall:NoCutoff');
    wa2 = warning('off', 'aurocCall:WideCutoff');
    Fas = rn.computeFigure(src, cfgA.figureFor("aurocStack"), Observation=Tu(1, :));
    warning(wa2); warning(wa1);
    hAs = renderFigure(Fas, Fas.spec, fig);
    check(numel(findall(hAs.axes(2), 'Tag', 'stackBase')) == nGs && numel(hAs.axes(2).YAxis) == 2, 'an auROC PSTH can be stacked too');
    % a PSTH drawn as a heat map (display "heatmap"): a row per trial group, colored on the unit's own range
    sh = F1.spec;
    sh.panels(2).options.display = "heatmap";
    hh = renderFigure(F1, sh, fig);
    ah = hh.axes(2);
    imh = findall(ah, 'Type', 'image');
    Rh = F1.panels(2).layers(1).R;
    nGh = height(Rh.groups);
    Mh = reshape(Rh.rate(:, 1, :), [], nGh).';
    cl1 = [min(Mh, [], 'all') max(Mh, [], 'all')];
    [rlh, rnh] = rowLabels(Rh);
    cbh = ah.Colorbar;
    Ch = PlotAesthetics.components(hh.layout);
    check(nGh >= 2 && isscalar(imh) && isequaln(imh.CData, Mh) && isequal(reshape(imh.XData([1 end]), [], 1), reshape(Rh.t([1 end]), [], 1)) && strcmp(ah.YDir, 'reverse') ...
        && isequal(ah.YTick, 1:nGh) && isequal(reshape(string(ah.YTickLabel), 1, []), reshape(rlh(1:nGh), 1, [])) ...
        && string(ah.YLabel.String) == rnh && rnh == "Depth" && isequal(clim(ah), cl1) && ~isempty(cbh) ...
        && string(cbh.Label.String) == Rh.units && string(cbh.Location) == "east" && isempty(findall(ah, '-regexp', 'Tag', '^rate(Fill)?$')) ...
        && isscalar(findall(ah, 'Tag', 'zeroLine')) && isequal(xlim(ah), [F1.spec.window.pre F1.spec.window.post]) ...
        && all(Ch.Role ~= "") && all(ismember(Ch.Role, roles)), ...
        sprintf(['a PSTH as a heat map: one image, a row per trial group (%d) in order, the first on top, labeled with ' ...
        'Depth''s values; colored on the unit''s own range, its color bar in %s inside the axes (a raster shares its column); ' ...
        'every part a known role'], nGh, Rh.units));
    F1b = rn.computeFigure(src, spec, Observation=Tu(2, :));
    hh2 = renderFigure(F1b, sh, fig);
    Mh2 = reshape(F1b.panels(2).layers(1).R.rate(:, 1, :), [], nGh).';
    cl2 = [min(Mh2, [], 'all') max(Mh2, [], 'all')];
    check(isequal(clim(hh2.axes(2)), cl2) && ~isequal(cl1, cl2), sprintf(['two units with other rates each fill their own color ' ...
        'range: [%.3g %.3g] and [%.3g %.3g], never one scale across units'], cl1, cl2));
    sc2 = sh;
    sc2.panels(2).options.colormap = "gray";
    sc2.panels(2).options.cLim = [0 5];
    hc2 = renderFigure(F1, sc2, fig);
    cl3 = clim(hc2.axes(2));
    cm3 = hc2.axes(2).Colormap;
    sc3 = sh;
    sc3.panels(2).options.colormap = "noSuchColormap";
    hc3 = renderFigure(F1, sc3, fig);
    check(isequal(cl3, [0 5]) && isequal(cm3, gray(256)) && ~isequal(hc3.axes(2).Colormap, gray(256)) ...
        && size(hc3.axes(2).Colormap, 2) == 3, 'a PSTH heat map''s colormap and color limits are honored; a name that is no colormap takes the design''s');
    ex = exportFigure(fig, string(tempname), Format=["png" "svg"]);
    check(numel(ex) == 2 && all(isfile(ex)), 'a PSTH heat map exports (PNG, SVG)');
    for f = reshape(ex(isfile(ex)), 1, []); delete(f); end
    st2 = sh;
    st2.panels(2).options.display = "trace";
    ht2 = renderFigure(F1, st2, fig);
    check(isempty(findall(ht2.axes(2), 'Type', 'image')) && ~isempty(findall(ht2.axes(2), '-regexp', 'Tag', '^rate(Fill)?$')) ...
        && isempty(ht2.axes(2).Colorbar), 'display back to "trace": the PSTH''s bars, no image or color bar');
    sm = Fs2.spec;
    sm.panels(2).options.display = "heatmap";   % stack stays ticked: not used by a heat map
    hm2 = renderFigure(Fs2, sm, fig);
    im2 = findall(hm2.axes(2), 'Type', 'image');
    nt2 = findall(hm2.axes(2), 'Tag', 'layerNote');
    check(isscalar(im2) && isequaln(im2.CData, reshape(Fs2.panels(2).layers(1).R.rate(:, 1, :), [], nGs).') && isscalar(nt2) ...
        && contains(strjoin(string(nt2.String), " "), "not in the heat map") && contains(strjoin(string(nt2.String), " "), Fs2.panels(2).layers(2).name) ...
        && isempty(findall(hm2.axes(2), 'Tag', 'stackBase')), ...
        'a PSTH heat map of two layers draws the first item; the other is noted at the bottom left; stack is not used');
    sa2 = Fau.spec;
    sa2.panels(2).options.display = "heatmap";
    hA2 = renderFigure(Fau, sa2, fig);
    aA2 = hA2.axes(2);
    mw2 = findall(aA2, 'Tag', 'modWindow');
    check(isequal(clim(aA2), [0 1]) && isempty(findall(aA2, 'Type', 'constantregion')) && string(aA2.Colorbar.Label.String) == "auROC" ...
        && (Lau.R.auroc.cutoff == "none" || (isscalar(mw2) && isa(mw2, 'matlab.graphics.primitive.Line') ...
        && isequal(mw2.XData(:), Lau.R.auroc.modulationWindow(:)))), ...
        'an auROC PSTH as a heat map: on 0-1, the modulation window a bar over the image (a line, not an xregion)');
    fhm = cfg.Figures(cfg.figureIndex("hm"));
    fhm.id = "hmAuroc";
    fhm.panels(1).options.baseline = struct('Mode', "auroc", 'Window', [-0.2 0]);
    fhm.panels(1).options.order = "modulation";
    cfgH = cfg.addFigure(fhm);
    wa1 = warning('off', 'aurocCall:NoCutoff');
    wa2 = warning('off', 'aurocCall:WideCutoff');
    Fha = rn.computeFigure(src, cfgH.figureFor("hmAuroc"));
    warning(wa2); warning(wa1);
    feA = figure('Visible', 'off', 'Position', [100 100 700 800]);   % its own: fe1 must start without an editor below
    hha = renderFigure(Fha, Fha.spec, feA, Editable=true);
    ctxA = getappdata(feA, PlotAesthetics.ContextKey);
    im = findall(hha.axes(1), 'Type', 'image');
    check(isfield(Fha.panels(1).layers(1).R, 'auroc') && isscalar(im) && isequal(clim(hha.axes(1)), [0 1]) && ctxA.mapField == "diverging", ...
        'a heat map of auROCs: on 0-1, its group''s calls kept (figSliceGroup), the editor''s colormap diverging');
    delete(feA);
    hrt = renderFigure(Frt, Frt.spec, fig);
    art = hrt.axes(1);
    bars = findall(art, 'Tag', 'bar');
    check(numel(bars) == height(Frt.groups) && isequal(art.XTick, 1:height(Frt.groups)) && string(art.XLabel.String) == "Depth" ...
        && string(art.YLabel.String) == Lrt.R.units && ~isempty(findall(art, 'Tag', 'errorBar')), ...
        'a rate panel: a bar per trial group along x (named by Depth), with error bars, the rate''s unit on y');
    hr3 = renderFigure(Frt3, Frt3.spec, fig);
    lg = findall(fig, 'Type', 'legend');
    lgr = string(lg(1).String);
    check(numel(findall(hr3.axes(1), 'Tag', 'box')) >= 2 && any(lgr == Frt3.panels(1).layers(2).name) ...
        && any(lgr == Frt3.panels(1).layers(1).name), 'a rate panel of two layers: boxes side by side, each layer in the legend');
    ar3 = hr3.axes(1);
    wb = findall(ar3, 'Tag', 'waveBox');
    wm = findall(ar3, 'Tag', 'waveMean');
    W3 = Frt3.panels(1).layers(1).R.waveforms;
    nIn = nnz(W3.timeMs{1} >= -0.5 & W3.timeMs{1} <= 1);
    check(isscalar(wb) && isscalar(wm) && abs(max(wb.XData) - min(wb.XData) - 0.5 * diff(ar3.XLim)) < 1e-9 ...
        && abs(max(wb.YData) - min(wb.YData) - 0.25 * diff(ar3.YLim)) < 1e-9 && abs(min(wb.XData) - ar3.XLim(1) - 0.03 * diff(ar3.XLim)) < 1e-9 ...
        && abs(min(wb.YData) - ar3.YLim(1) - 0.03 * diff(ar3.YLim)) < 1e-9 && numel(wm.XData) == nIn, ...
        'a rate panel''s waveform inset: the first unit''s, south-west, 1.5 x a third wide and 0.75 x a third high, the samples of [-0.5 1] ms');
    fpts = Frt; fpts.spec.panels(1).options.display = "points";
    hpt = renderFigure(fpts, fpts.spec, fig);
    check(~isempty(findall(hpt.axes(1), 'Tag', 'points')) && ~isempty(findall(hpt.axes(1), 'Tag', 'meanBar')), ...
        'a rate panel''s points display: each epoch a dot over its mean''s bar');
    htc = renderFigure(Ftc, Ftc.spec, fig);
    atc = htc.axes(1);
    cv = findall(atc, 'Tag', 'curve');
    check(isscalar(cv) && isequal(cv.XData(:), double(Ltc.R.x(:))) && string(atc.XLabel.String) == "Depth" ...
        && string(atc.YLabel.String) == Ltc.R.units, 'a tuning panel: the curve over Depth''s values, labeled');
    htc2 = renderFigure(Ftc2, Ftc2.spec, fig);
    cv2 = findall(htc2.axes(1), 'Tag', 'curve');
    check(numel(cv2) == height(Lt2.R.groups) && ~isempty(findall(htc2.axes(1), 'Tag', 'waveMean')), ...
        sprintf('a tuning panel with a series: %d curves, and the unit''s waveform inset', numel(cv2)));
    hwp = renderFigure(Fwp, Fwp.spec, fig);
    awp = hwp.axes(1);
    ring = findall(awp, 'Tag', 'unitDots');
    check(~isempty(findall(awp, 'Tag', 'waveMean')) && startsWith(string(awp.XLabel.String), "x (") ...
        && (isscalar(ring) || ~all(isfinite(Tu.meta{2}.y))), ...
        'a waveforms panel in the probe layout: the units at their places, the observed unit framed');
    Fwx = Fwp;   % the ring layer made a detected one naming a sorted unit's id: its id is a channel, not that unit
    Fwx.panels(1).layers(2).source = "detected";
    Fwx.panels(1).layers(2).R.source = "detected";
    hwx = renderFigure(Fwx, Fwx.spec, fig);
    fwd = cfg.Figures(cfg.figureIndex("wfprobe"));
    fwd.id = "wfprobeDet";
    fwd.panels(1).layers(2).source = "detected";
    cfgD = cfg.addFigure(fwd);
    wsw = warning('off', 'unitWaveforms:Templates');
    wsn = warning('off', 'unitWaveforms:NoWaveforms');
    Fwd = rn.computeFigure(src, cfgD.figureFor("wfprobeDet"), Observation=Tu(2, :));
    warning(wsn); warning(wsw);
    hwd = renderFigure(Fwd, Fwd.spec, fig);
    check(ismember(Tu.unitId(2), Fwx.panels(1).layers(2).R.meta.unitId) && isempty(findall(hwx.axes(1), 'Tag', 'unitDots')) ...
        && Fwd.panels(1).layers(2).skip == "" && Fwd.panels(1).layers(2).R.source == "detected" ...
        && isempty(findall(hwd.axes(1), 'Tag', 'unitDots')), ...
        'a probe layout of sorted units rings nothing a detected layer names (its unit ids are channels)');

    % editing, OnRemember and redraw
    remembered = [];
    renderFigure(F1, F1.spec, fe1);
    noCtx = ~isappdata(fe1, PlotAesthetics.ContextKey);
    hE = renderFigure(F1, F1.spec, fe1, Editable=true, OnRemember=@remember);
    ctx = getappdata(fe1, PlotAesthetics.ContextKey);
    menus = findall(fe1, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag);
    check(noCtx && isstruct(ctx) && ctx.kind == "figure" && ctx.id == "rp" && isequal(ctx.root, hE.layout) && isequal(ctx.target, fe1) ...
        && ~isempty(menus) && ctx.mapField == "" && isempty(ctx.plotRules) && isa(ctx.redraw, 'function_handle'), ...
        sprintf('Editable=true installs the aesthetics editor (%d context menus, context kind "figure"); "auto" in an invisible figure does not', numel(menus)));
    rules = PlotAesthetics.normalizeRules(struct('role', "rasterTicks", 'group', "", 'property', "LineWidth", 'value', 2));
    ctx.onRemember(rules);
    ctx.redraw(rules);
    ctx2 = getappdata(fe1, PlotAesthetics.ContextKey);
    tk = findall(fe1, 'Tag', 'rasterTicks');
    check(isequaln(remembered, rules) && isequaln(ctx2.plotRules, rules) && ~isvalid(hE.axes(1)) && ~isempty(tk) && all([tk.LineWidth] == 2), ...
        'OnRemember receives the rules; the context''s redraw draws the figure again with them as its own aesthetics');
    renderFigure(Fh, Fh.spec, fe1, Editable=true);
    ctxH = getappdata(fe1, PlotAesthetics.ContextKey);
    renderFigure(Fcm, Fcm.spec, fe1, Editable=true);
    ctxC = getappdata(fe1, PlotAesthetics.ContextKey);
    check(ctxH.mapField == "heat" && ctxC.mapField == "diverging", 'the editor''s colormap: "heat" for a heat map, "diverging" for a correlation map');

    % Reuse: an edit of one panel draws that panel again, the others kept; the figure as a whole drawing makes it
    drawTargets();
    delete(ufig.Children);
    pA = uipanel(ufig, 'Units', 'pixels', 'Position', [1 1 690 790], 'BorderType', 'none');
    pB = uipanel(ufig, 'Units', 'pixels', 'Position', [1 1 690 790], 'BorderType', 'none', 'Visible', 'off');
    s3 = F3.spec;
    renderFigure(F3, s3, pA, Reuse=true, Editable=true, DataTips=true);
    D0 = getappdata(pA, 'FigureDrawing');
    m0 = D0.axes(1).ContextMenu;
    s3b = s3;
    s3b.panels(2).options.histStyle = "line";   % the PSTH's look
    s3b.panels(3).title = "Signals";            % the continuous panel's title
    hR = renderFigure(F3, s3b, pA, Reuse=true, Editable=true, DataTips=true);
    D1 = getappdata(pA, 'FigureDrawing');
    renderFigure(F3, s3b, pB, Editable=true, DataTips=true);
    drawnow;
    [same1, why1] = sameDrawing(pA, pB);
    keptR = D1.axes(1) == D0.axes(1) && ~any(D1.axes(2:3) == D0.axes(2:3));
    tipsR = ~isempty(findall(D1.axes(2), '-function', @(o) isappdata(o, FigureDataTips.InfoKey)));
    check(keptR && same1 && isequal(D1.axes(1).ContextMenu, m0) && tipsR && isequal(hR.axes, D1.axes) && figTitle(hR) == hR.title, ...
        sprintf(['renderFigure Reuse: an edit of two panels draws those again and keeps the raster (its menu too), the drawing ' ...
        'the same as a whole one (%s)'], why1));
    s3c = s3b;
    s3c.title = "Own title";   % a title of the figure's own: the top-left panel names the observation, every panel is drawn
    renderFigure(F3, s3c, pA, Reuse=true);
    D2 = getappdata(pA, 'FigureDrawing');
    renderFigure(F3, s3c, pB);
    drawnow;
    [same2, why2] = sameDrawing(pA, pB);
    renderFigure(F3, s3c, pA);   % without Reuse: nothing kept for next time
    check(~any(D2.axes == D1.axes) && same2 && ~isappdata(pA, 'FigureDrawing'), ...
        sprintf('a change that reaches every panel (a title of the figure''s own) draws them all; a drawing without Reuse keeps nothing (%s)', why2));
    % Reuse, text alone: new label, panel title and figure title texts set on what is drawn (inPlace), the drawing a whole one's
    renderFigure(F3, s3c, pA, Reuse=true, Editable=true, DataTips=true);
    D3 = getappdata(pA, 'FigureDrawing');
    s3d = s3c;
    s3d.panels(2).yLabel = "Firing (Hz)";   % the PSTH's y label: its own text over the type's
    s3d.panels(3).xLabel = "Lag (s)";       % the stack's time label, at its bottom
    s3d.panels(1).xLabel = "Hidden";        % the raster's, which the stack hides: kept, nothing shown
    s3d.panels(3).title = "LFP and AUX";    % a panel title of its own, before and after
    s3d.title = "Own title, again";         % the figure's own title, before and after
    [hI, howI] = renderFigure(F3, s3d, pA, Reuse=true, Editable=true, DataTips=true);
    DI = getappdata(pA, 'FigureDrawing');
    ctxI = getappdata(pA, PlotAesthetics.ContextKey);
    renderFigure(F3, s3d, pB, Editable=true, DataTips=true);
    drawnow;
    [sameI, whyI] = sameDrawing(pA, pB);
    [textI, whyT] = sameTexts(pA, pB);
    rI = findall(DI.axes(2), '-regexp', 'Tag', '^(rate|rateFill)$');
    rI = rI(arrayfun(@(o) ~all(isnan(o.XData(:))), rI));
    LrI = strings(0, 1);
    if ~isempty(rI); LrI = FigureDataTips.tipText(rI(1), 2); end
    check(howI == "inplace" && isequal(DI.axes, D3.axes) && isequal(DI.title, D3.title) && sameI && textI ...
        && string(DI.axes(3).XLabel.String) == "Lag (s)" && string(DI.axes(2).YLabel.String) == "Firing (Hz)" ...
        && strjoin(string(DI.axes(1).XLabel.String), "") == "" && string(DI.axes(3).Title.String) == "LFP and AUX" ...
        && figTitle(hI) == "Own title, again" && hI.title == "Own title, again" && isequal(hI.axes, DI.axes) ...
        && isequaln(DI.spec, s3d) && ctxI.title == hI.title && any(startsWith(LrI, "Firing: ")), ...
        sprintf(['renderFigure Reuse, text alone (labels, a panel title, the figure title): set on the axes drawn (inPlace), ' ...
        'nothing drawn again, the drawing a whole one''s (%s; texts: %s); the PSTH''s data tips name the new quantity; ' ...
        'the editor''s context takes the new spec'], whyI, whyT));
    s3e = s3d;
    s3e.panels(2).yLabel = "Rate";
    s3e.panels(2).ySide = "right";   % a side: the place keys change, so it is drawn
    [hN, howN] = renderFigure(F3, s3e, pA, InPlaceOnly=true, Editable=true, DataTips=true);
    DN = getappdata(pA, 'FigureDrawing');
    keptN = isempty(hN) && howN == "" && isequal(DN.axes, DI.axes) && string(DN.axes(2).YLabel.String) == "Firing (Hz)";
    [~, howE] = renderFigure(F3, s3e, pA, Reuse=true, Editable=true, DataTips=true);
    DE = getappdata(pA, 'FigureDrawing');
    s3f = s3d;
    s3f.panels(3).title = "";   % back to no title of its own: not set in place
    renderFigure(F3, s3d, pB, Reuse=true);
    [~, howF] = renderFigure(F3, s3f, pB, Reuse=true);
    check(keptN && howE == "drawn" && ~isequal(DE.axes, DI.axes) && strcmp(DE.axes(2).YAxisLocation, 'right') ...
        && string(DE.axes(2).YLabel.String) == "Rate" && howF == "drawn", ...
        ['InPlaceOnly with an edit that is not text alone (a side) draws nothing and says so; Reuse draws it; a title ' ...
        'that goes back to none is drawn']);
    renderFigure(F3, s3c, pA, Reuse=true, Scale=0.7);   % drawn at a scale (the app's preview): the text set, every size left scaled
    DS = getappdata(pA, 'FigureDrawing');
    [~, howS] = renderFigure(F3, s3d, pA, Reuse=true, Scale=0.7);
    renderFigure(F3, s3d, pB, Scale=0.7);
    drawnow;
    [sameS, whyS] = sameDrawing(pA, pB);
    [textS, whyTS] = sameTexts(pA, pB);
    check(howS == "inplace" && isequal(getappdata(pA, 'FigureDrawing').axes, DS.axes) && sameS && textS ...
        && isequal(drawnSizes(pA), drawnSizes(pB)), ...
        sprintf('drawn at Scale 0.7, a text edit is set in place too: the drawing, its texts and every size a whole one''s at that scale (%s; texts: %s)', ...
        whyS, whyTS));
    delete([pA pB]);

    % one observation draws fast
    renderFigure(F1, F1.spec, fig);
    drawnow;
    tR = Inf;
    for rep = 1:3
        tc0 = tic;
        renderFigure(F1, F1.spec, fig);
        drawnow;
        tR = min(tR, toc(tc0));
    end
    check(tR < 1, sprintf('the raster + PSTH figure of one observation renders in %.3f s (under 1 s)', tR));

    % data tips: named quantities, a raster tick's trial, a heat map's rows; the fields a preference
    prefsTips = AppPrefs.useTemporary();
    tipKey = FigureDataTips.InfoKey;
    renderFigure(F1, F1.spec, fe1);
    noTips = isempty(findall(fe1, '-function', @(o) isappdata(o, tipKey)));
    renderFigure(F3, F3.spec, fe1, Editable=true, DataTips=true);
    pl = findall(fe1, '-regexp', 'Tag', '^(trace|channelTrace)$');
    pl = pl(arrayfun(@(o) isprop(o, 'DataTipTemplate') && ~all(isnan(o.XData)), pl));
    labs = strings(1, 0);
    if ~isempty(pl); labs = string({pl(1).DataTipTemplate.DataTipRows.Label}); end
    arrayfun(@PlotAesthetics.fillMenu, findall(fe1, 'Type', 'uicontextmenu', 'Tag', PlotAesthetics.MenuTag));   % (their items are made when they open)
    check(noTips && ~isempty(pl) && any(startsWith(labs, "Time from")) && any(labs == "Trial group") ...
        && all(ismember(["Panel" "Observation" "Dataset"], labs)) && ~isempty(findall(fe1, 'Tag', FigureDataTips.MenuTag)), ...
        sprintf('DataTips=true: a continuous trace''s tip rows are %s; the right-click menus have "Data tip fields..."; "auto" in an invisible figure gives none', ...
        strjoin(labs, " | ")));
    renderFigure(F1, F1.spec, fe1, Editable=true, DataTips=true);
    rf = findall(fe1, '-regexp', 'Tag', '^(rate|rateFill)$');
    rf = rf(arrayfun(@(o) ~all(isnan(o.XData(:))), rf));
    Lrf = strings(0, 1);
    if ~isempty(rf); Lrf = FigureDataTips.tipText(rf(1), 2); end
    check(~isempty(rf) && any(startsWith(Lrf, "Time from")) && any(startsWith(Lrf, "Rate: ")) && any(startsWith(Lrf, "Trial group: ")) ...
        && any(startsWith(Lrf, "Panel: psth")), sprintf('a PSTH''s tip names the time, the rate in its unit, the group and panel (%s)', strjoin(Lrf, " | ")));
    tk = rasterTickLines(fe1);
    Ltk = strings(0, 1);
    if ~isempty(tk); Ltk = FigureDataTips.tipText(tk(1), 1); end
    check(~isempty(tk) && any(startsWith(Ltk, "Trial: ")) && any(startsWith(Ltk, "Trial group: ")) && any(startsWith(Ltk, "Time from")) ...
        && ~any(startsWith(Ltk, "Y")) && any(startsWith(Ltk, "Dataset: ")), ...
        sprintf('a raster tick''s tip: its trial and trial group, time, dataset (%s)', strjoin(Ltk, " | ")));
    renderFigure(Fh, Fh.spec, fe1, DataTips=true);
    im = findall(fe1, 'Type', 'image');
    Lim = strings(0, 1);
    if ~isempty(im); Lim = FigureDataTips.tipText(im(1), [im(1).XData(1) im(1).YData(1)]); end
    renderFigure(Fth, Fth.spec, fe1, DataTips=true);
    it = findall(fe1, 'Type', 'image');
    Lit = strings(0, 1);
    if ~isempty(it); Lit = FigureDataTips.tipText(it(1), [it(1).XData(1) it(1).YData(1)]); end
    check(~isempty(im) && numel(Lim) >= 4 && any(startsWith(Lim, "Time from")) && ~isempty(it) && any(startsWith(Lit, "Trial: ")), ...
        sprintf('a heat map cell''s tip: %s; a heat map of trials: %s', strjoin(Lim, " | "), strjoin(Lit, " | ")));
    renderFigure(Frt, Frt.spec, fe1, DataTips=true);
    br = findall(fe1, 'Type', 'bar');
    blabs = strings(1, 0);
    if ~isempty(br); blabs = string({br(1).DataTipTemplate.DataTipRows.Label}); end
    check(~isempty(br) && all(ismember(["Panel" "Dataset"], blabs)), sprintf('a rate panel''s bar: %s', strjoin(blabs, " | ")));
    renderFigure(F3, F3.spec, fe1, DataTips=true);
    FigureDataTips.setChosen(["x" "dataset"]);
    nR = FigureDataTips.refresh(fe1);
    pl = findall(fe1, '-regexp', 'Tag', '^(trace|channelTrace)$');
    pl = pl(arrayfun(@(o) isprop(o, 'DataTipTemplate') && ~all(isnan(o.XData)), pl));
    labs2 = string({pl(1).DataTipTemplate.DataTipRows.Label});
    tk = rasterTickLines(fe1);
    Ltk2 = FigureDataTips.tipText(tk(1), 1);
    FigureDataTips.setChosen(strings(1, 0));
    FigureDataTips.refresh(fe1);
    labs3 = string({pl(1).DataTipTemplate.DataTipRows.Label});
    check(nR > 0 && numel(labs2) == 2 && startsWith(labs2(1), "Time from") && labs2(2) == "Dataset" && numel(Ltk2) == 2 ...
        && isequal(labs3, ["X" "Y"]), ...
        'the chosen fields (a preference) follow on refresh: time and dataset only; none gives MATLAB''s X and Y');
    d = DataTipFieldsDialog(Visible=false);
    nBox = numel(fieldnames(d.Boxes));
    d.reset();
    dflt = d.Chosen;
    d.none();
    d.setField("trial", true);
    d.setField("dataset", true);
    d.ok();
    afterOk = FigureDataTips.chosen();
    d = DataTipFieldsDialog(Visible=false);
    d.all();
    d.cancel();
    check(nBox == height(FigureDataTips.fields()) && isequal(dflt, FigureDataTips.fields().Key(FigureDataTips.fields().Default).') ...
        && isequal(afterOk, ["trial" "dataset"]) && isequal(FigureDataTips.chosen(), ["trial" "dataset"]) ...
        && isequal(string({pl(1).DataTipTemplate.DataTipRows.Label}), "Dataset"), ...
        'DataTipFieldsDialog: a box per field; Reset the defaults; OK keeps the choice and shows it on the figures on screen; Cancel keeps nothing');
    FigureDataTips.setChosen([]);
    tOff = Inf; tOn = Inf;
    for rep = 1:3
        tc0 = tic; renderFigure(F1, F1.spec, fe1, DataTips=false); drawnow; tOff = min(tOff, toc(tc0));
        tc0 = tic; renderFigure(F1, F1.spec, fe1, DataTips=true); drawnow; tOn = min(tOn, toc(tc0));
    end
    check(tOn - tOff < 0.25, sprintf('data tips add %.3f s to the raster + PSTH figure (%.3f s without, %.3f s with)', tOn - tOff, tOff, tOn));
    clear prefsTips
end

%% ============================================================================ spectral
if S.sec("9", "spectral panels (Chronux)")
    % the config side needs no Chronux: chronuxSettings is the repository's
    cv = EphysAnalysisConfig();
    cv.Source.Root = root;
    cv.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    cv = cv.addFigure("coherence", Id="coh");
    cv = cv.addFigure("spectrogram", Id="sg");
    cv = cv.addFigure("spectrum", Id="sp");
    check(isempty(figIssues(cv)), 'the spectral templates validate clean');
    c1 = cv; c1.Figures(1).panels.layers(2) = [];
    c2 = cv; c2.Figures(1).panels.options.TW = -1;
    c3 = cv; c3.Figures(2).panels.options.baseline = struct('Mode', "db", 'Window', [-0.6 0]);
    c4 = cv; c4.Figures(1).panels.options.overTime = true;
    c5 = cv; c5.Figures(2).panels.options.baseline = struct('Mode', "zscore", 'Window', [-0.2 0]);
    c6 = cv; c6.Figures(3).panels.options.timeBase = "range"; c6.Figures(3).panels.options.segmentSec = 0;
    c7 = cv; c7.Figures(3).panels.options.timeBase = "range"; c7.Figures(3).window = struct('mode', "between", 'pre', 0, 'post', 0, ...
        'stop', struct('line', "Stim", 'edge', "offset"));
    c8 = cv; c8.Figures(2).panels.layers(1).source = "units";
    c9 = cv; c9.Figures(2).panels.layers(1).source = "events";
    I2 = figIssues(c2);
    I3 = figIssues(c3);
    I6 = figIssues(c6);
    check(has(c1, "coh.coherence_1.layers", "error") && has(c2, "coh.coherence_1.options", "error") && any(contains(I2.Message, "TW")) ...
        && has(c3, "sg.spectrogram_1.options", "error") && any(contains(I3.Message, "inside the window")) ...
        && isempty(figIssues(c4)) && isempty(figIssues(c5)) && isempty(figIssues(c8)) && has(c9, "sg.spectrogram_1.layers", "error") ...
        && has(c6, "sp.spectrum_1.options", "error") && any(contains(I6.Message, "segmentSec")) ...
        && ~any(contains(figIssues(c7).Field, "sp.spectrum_1")), ...
        ['validate: a coherence panel''s two layers; chronuxSettings'' errors with their messages (TW, a range segment); a spectrogram''s ' ...
        'baseline window inside its window; a coherogram of spikes and a spectrogram of units validate, a spectrogram of events marks only does not; ' ...
        'a range spectrum needs no fixed window']);
    am = layerOf("continuous"); am.source = "AUX"; am.binding = "fixed"; am.channels = 1:3; am.aggregate = "magnitude";
    ag1 = cv; ag1.Figures(1).panels.layers = [ag1.Figures(1).panels.layers(1) am];   % the unit x an accelerometer's magnitude
    ag2 = cv; ag2.Figures(1).panels.layers = [am ag2.Figures(1).panels.layers(1)];   % the magnitude seeds: one item, three channels
    ag3 = cv; ag3.Figures(1).panels.layers(2).aggregate = "magnitude";               % the template's LFP layer follows the unit
    ag4 = cv.addFigure(struct('id', "ct", 'panels', {{struct('id', "c", 'type', "continuous", 'layers', am)}}));
    check(~any(figIssues(ag1).Severity == "error") && ~any(startsWith(figIssues(ag2).Field, "coh.coherence_1.layers(1)")) ...
        && has(ag3, "coh.coherence_1.layers(2).binding", "error") && has(ag4, "ct.c.layers(1).aggregate", "error") ...
        && isequal(EphysAnalysisConfig.aggregates("coherence", "AUX"), ["each" "magnitude"]) ...
        && isequal(EphysAnalysisConfig.aggregates("spectrum", "units"), "each") && isequal(EphysAnalysisConfig.aggregates("psth", "units"), ["each" "mean"]), ...
        'validate: aggregate "magnitude" on a fixed signal layer of a spectral panel (a seed of three channels without the one-channel warning), not on a following layer or a continuous panel (aggregates)');
    s0 = cv.figureFor("coh");
    s4 = c4.figureFor("coh");
    check(~s0.panels.sharesTime && s4.panels.sharesTime && cv.figureFor("sg").panels.sharesTime && ~cv.figureFor("sp").panels.sharesTime, ...
        'figureFor: a spectrogram shares the figure''s time axis, a coherence panel only over time, a spectrum never');

    % the computes and the drawing need the toolbox: toolboxes/chronux, on the path for this section only
    cxAdded = "";
    if ~ChronuxDataset.hasChronux() && isfolder(fullfile(repo, 'toolboxes', 'chronux'))
        cxAdded = string(genpath(fullfile(repo, 'toolboxes', 'chronux')));
        addpath(cxAdded);
    end
    cxBack = onCleanup(@() rmpathQuiet(cxAdded));   % Chronux's findpeaks must not stay ahead of MATLAB's
    if ~ChronuxDataset.hasChronux()
        fprintf('  SKIP: Chronux is not on the path and toolboxes/chronux is missing: the spectral computes are not tested\n');
    else
        fixtureA();       % section 7's "clean" dataset, and the figures to draw into
        drawTargets();
        cs = EphysAnalysisConfig();
        cs.Source.Root = FX.proj;
        cs.Defaults.EventRef.line = "Stim";
        cs.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
        cs.Defaults.Selection.groupBy = "Depth";
        lfpU = layerOf("continuous");          % LFP following the observed unit: its channel's column
        unitU = layerOf("raster");             % the observed unit
        lfpA = lfpU; lfpA.binding = "fixed"; lfpA.channels = 1;
        lfpB = lfpA; lfpB.channels = [2 3];
        lfpF = lfpA; lfpF.channels = 2;
        figS = struct('id', "spectral", 'observe', struct('data', "units"), 'grid', struct('rows', 3, 'cols', 2), 'panels', {{ ...
            struct('id', "ras", 'type', "raster", 'row', 1, 'col', 1, 'layers', unitU), ...
            struct('id', "spec_lfp", 'type', "spectrum", 'row', 1, 'col', 2, 'layers', lfpU), ...
            struct('id', "sgram", 'type', "spectrogram", 'row', 2, 'col', 1, 'layers', lfpU), ...
            struct('id', "spec_unit", 'type', "spectrum", 'row', 2, 'col', 2, 'layers', unitU), ...
            struct('id', "coh_lfp", 'type', "coherence", 'row', 3, 'col', 1, 'layers', [lfpA lfpB]), ...
            struct('id', "coh_sf", 'type', "coherence", 'row', 3, 'col', 2, 'layers', [unitU lfpF])}});
        cs = cs.addFigure(figS);
        Is = figIssues(cs);
        check(~any(Is.Severity == "error"), sprintf('a figure of every spectral kind validates (%d issue(s))', height(Is)));
        rs = EphysAnalysisRunner(cs, LogFcn=[]);
        srcS = rs.source(1);
        specS = cs.figureFor("spectral");
        Ts = figureObservations(srcS, specS);
        t0 = tic;
        Fs = rs.computeFigure(srcS, specS, Observation=Ts(1, :));
        tS = toc(t0);
        pid = [Fs.panels.id];
        nG = height(Fs.groups);
        Ll = Fs.panels(pid == "spec_lfp").layers;
        Lu = Fs.panels(pid == "spec_unit").layers;
        Lg = Fs.panels(pid == "sgram").layers;
        Lc = Fs.panels(pid == "coh_lfp").layers;
        Lsf = Fs.panels(pid == "coh_sf").layers;
        Rl = Ll.R; Ru = Lu.R; Rg = Lg.R;
        check(Ll.skip == "" && Rl.kind == "chronuxSpectrum" && iscolumn(Rl.f) && isequal(size(Rl.S), [numel(Rl.f) 1 nG]) ...
            && isequal(size(Rl.Slo), size(Rl.S)) && Ll.meta.recordingChannel == Ts.channel(1) && endsWith(Rl.units, "²/Hz") ...
            && all(Rl.f >= 0 & Rl.f <= 100) && isequal(Rl.groups.label, Fs.groups.label) && all(Rl.nTrials(:) > 0) && Ll.name == "LFP ch " + Ts.channel(1), ...
            sprintf('a spectrum of the observed unit''s LFP channel ("%s"): f [%d x 1], S [nF x 1 x %d groups], jackknife bars (%.1f s for the figure)', ...
            Ll.name, numel(Rl.f), nG, tS));
        check(Lu.skip == "" && Ru.kind == "chronuxSpikeSpectrum" && isequal(size(Ru.S), [numel(Ru.f) 1 nG]) && isequal(size(Ru.rate), [1 nG]) ...
            && Lu.meta.unitId == Ts.unitId(1) && Ru.units == "spikes/s", 'a spike spectrum of the observed unit, with its mean rate per group');
        check(Lg.skip == "" && Rg.kind == "chronuxSpecgram" && isequal(size(Rg.S), [numel(Rg.t) numel(Rg.f) 1 nG]) && all(Rg.t > -0.2 & Rg.t < 0.8) ...
            && Rg.aligned && Lg.meta.recordingChannel == Ts.channel(1), 'a spectrogram of the observed unit''s LFP channel over the epochs');
        Rc = Lc(1).R;
        check(all([Lc.skip] == "") && Rc.kind == "chronuxCoherence" && isequal(size(Rc.C), [numel(Rc.f) 2 nG]) && ~isempty(Rc.Clo) ...
            && all(startsWith(Rc.labels, Lc(1).name + " x LFP ch ")) && isequal(Rc.labels, reshape(Rc.pairs.label, 1, [])) ...
            && Lc(2).R.kind == "coherencePartner" && all(isfinite(Rc.confC(:))), ...
            sprintf('a coherence of LFP x LFP (two fixed columns): the seed with each partner column ("%s", ...)', Rc.labels(1)));
        Rsf = Lsf(1).R;
        check(all([Lsf.skip] == "") && Rsf.kind == "chronuxSpikeField" && isequal(size(Rsf.C), [numel(Rsf.f) 1 nG]) ...
            && Rsf.labels == Lsf(1).name + " x " + Lsf(2).name, sprintf('a spike-field coherence: the observed unit x a fixed LFP column ("%s")', Rsf.labels));
        fixU = unitU; fixU.binding = "fixed"; fixU.units.ids = Ts.unitId(2);
        cs = cs.addFigure(struct('id', "unitcoh", 'observe', struct('data', "units"), ...
            'panels', {{struct('id', "cu", 'type', "coherence", 'layers', [unitU fixU])}}));
        Fu = rs.computeFigure(srcS, cs.figureFor("unitcoh"), Observation=Ts(1, :));
        Luc = Fu.panels.layers;
        Ruc = Luc(1).R;
        check(all([Luc.skip] == "") && Ruc.kind == "chronuxUnitCoherence" && isequal(size(Ruc.C), [numel(Ruc.f) 1 nG]) ...
            && Ruc.labels == Luc(1).name + " x " + Luc(2).name && Luc(2).meta.unitId == Ts.unitId(2), ...
            sprintf('a unit-unit coherence: the observed unit x a fixed unit ("%s")', Ruc.labels));
        % an accelerometer's vector magnitude (AUX, aggregate "magnitude") as one item: with the unit, with an LFP column (the
        % AUX is at a quarter of the amplifier rate, the LFP at its own), as a seed with the axes themselves, and its spectrum
        auxM = lfpA; auxM.source = "AUX"; auxM.channels = 1:3; auxM.aggregate = "magnitude";
        auxE = auxM; auxE.aggregate = "each";
        cs = cs.addFigure(struct('id', "auxmag", 'observe', struct('data', "units"), 'grid', struct('rows', 3, 'cols', 2), 'panels', {{ ...
            struct('id', "uxm", 'type', "coherence", 'row', 1, 'col', 1, 'layers', [unitU auxM]), ...
            struct('id', "lxm", 'type', "coherence", 'row', 1, 'col', 2, 'layers', [lfpA auxM]), ...
            struct('id', "mxa", 'type', "coherence", 'row', 2, 'col', 1, 'layers', [auxM auxE]), ...
            struct('id', "mxm", 'type', "coherence", 'row', 2, 'col', 2, 'layers', [auxM auxM]), ...
            struct('id', "sm", 'type', "spectrum", 'row', 3, 'col', 1, 'layers', auxM)}}));
        Im = figIssues(cs);
        specM = cs.figureFor("auxmag");
        FmA = rs.computeFigure(srcS, specM, Observation=Ts(1, :));
        pidM = [FmA.panels.id];
        Lum = FmA.panels(pidM == "uxm").layers;
        Llm = FmA.panels(pidM == "lxm").layers;
        Lma = FmA.panels(pidM == "mxa").layers;
        Lmm = FmA.panels(pidM == "mxm").layers;
        Lsm = FmA.panels(pidM == "sm").layers;
        [Yaux, fsa] = selectChannels(srcS, "AUX");
        [~, fsl] = selectChannels(srcS, "LFP");
        wAux = 2 * floor(2 * fsa / 2) + 1;   % each axis's 2 s running mean out, then the magnitude
        Maux = zeros(size(Yaux, 1), 1);
        for kAux = 1:3
            xAux = double(Yaux(:, kAux));
            Maux = Maux + (xAux - movmean(xAux, wAux)) .^ 2;
        end
        Maux = single(sqrt(Maux));
        pm = specM.panels([specM.panels.id] == "sm");
        TBm = chronuxTimeBaseOf(srcS, FmA.epochs, FmA.groups, pm, Fs=fsa, NRows=numel(Maux));
        Rm0 = chronuxSpectrum(chronuxBlockOf(Maux, fsa, [], "AUX", "m"), TBm, figureChronuxSettings("spectrum", pm.options, [pm.window.pre pm.window.post]));
        mag = "magnitude of 3 AUX channels";
        Rum = Lum(1).R; Rlm = Llm(1).R; Rma = Lma(1).R;
        check(~any(Im.Severity == "error" & startsWith(Im.Field, "auxmag")) && all([Lum.skip Llm.skip Lma.skip Lsm.skip] == "") ...
            && Lum(2).name == mag && Rum.kind == "chronuxSpikeField" && isequal(size(Rum.C), [numel(Rum.f) 1 nG]) ...
            && Rum.labels == Lum(1).name + " x " + mag && Rum.fs == fsa && height(Lum(2).meta) == 3, ...
            sprintf('a spike-field coherence of the observed unit with an accelerometer''s magnitude ("%s"), at the AUX rate', Rum.labels));
        check(fsa ~= fsl && Rlm.kind == "chronuxCoherence" && isequal(size(Rlm.C), [numel(Rlm.f) 1 nG]) && Rlm.fs == min(fsa, fsl) ...
            && Rlm.labels == Llm(1).name + " x " + mag && all(isfinite(Rlm.C(:))), ...
            sprintf('an LFP column x the AUX magnitude at two rates (%g and %g Hz): the faster resampled to %g Hz', fsl, fsa, Rlm.fs));
        check(isequal(size(Rma.C), [numel(Rma.f) 3 nG]) && all(startsWith(Rma.labels, mag + " x AUX ")) ...
            && all([Lmm.skip] == "the partner is the seed's channel itself: pick another"), ...
            'the magnitude as the seed: paired with each of its own axes (another item), but not with the same magnitude');
        check(isequaln(Lsm.R.S, Rm0.S) && isequal(size(Lsm.R.S), [numel(Lsm.R.f) 1 nG]) && isequal(Lsm.R.names, mag) && Lsm.name == mag, ...
            'a power spectrum of the magnitude: chronuxSpectrum of sqrt of the sum of the axes'' squares, each less its 2 s running mean');
        % sorted units in every spectral panel: a spike spectrogram, spike-field and unit-unit coherograms
        cs = cs.addFigure(struct('id', "spikegrams", 'observe', struct('data', "units"), 'grid', struct('rows', 3, 'cols', 1), 'panels', {{ ...
            struct('id', "sgu", 'type', "spectrogram", 'row', 1, 'col', 1, 'layers', unitU, ...
                'options', struct('baseline', struct('Mode', "db", 'Window', [-0.2 0.1]), 'movingwin', [0.25 0.05])), ...
            struct('id', "cgf", 'type', "coherence", 'row', 2, 'col', 1, 'layers', [unitU lfpF], 'options', struct('overTime', true)), ...
            struct('id', "cgu", 'type', "coherence", 'row', 3, 'col', 1, 'layers', [unitU fixU], 'options', struct('overTime', true))}}));
        Ig = figIssues(cs);
        Ig = Ig(startsWith(Ig.Field, "spikegrams."), :);
        specG = cs.figureFor("spikegrams");
        Fg = rs.computeFigure(srcS, specG, Observation=Ts(1, :));
        Lsg = Fg.panels(1).layers;
        Lcf = Fg.panels(2).layers;
        Lcu = Fg.panels(3).layers;
        Rsg = Lsg.R;
        check(~any(Ig.Severity == "error") && Lsg.skip == "" && Rsg.kind == "chronuxSpikeSpecgram" && isequal(size(Rsg.S, [1 2 3 4]), [numel(Rsg.t) numel(Rsg.f) 1 nG]) ...
            && all(Rsg.t > -0.2 & Rsg.t < 0.8) && Rsg.baseline.units == "dB change" && Lsg.meta.unitId == Ts.unitId(1) && Rsg.units == "spikes/s", ...
            'a spectrogram of the observed unit (chronuxSpikeSpecgram) over the epochs, against its baseline');
        check(all([Lcf.skip] == "") && Lcf(1).R.kind == "chronuxCohgram" && isequal(size(Lcf(1).R.C, [1 2 3]), [numel(Lcf(1).R.t) numel(Lcf(1).R.f) 1]) ...
            && Lcf(1).R.aligned && size(Lcf(1).R.C, 4) == nG && Lcf(1).R.labels == Lcf(1).name + " x " + Lcf(2).name ...
            && all([Lcu.skip] == "") && Lcu(1).R.kind == "chronuxCohgram" && size(Lcu(1).R.C, 4) == nG && Lcu(1).R.labels == Lcu(1).name + " x " + Lcu(2).name, ...
            'coherograms of spikes: the observed unit x a fixed LFP column, and x a fixed unit, over time from the event');
        hG = renderFigure(Fg, specG, fig);
        drawnow;
        imgs = arrayfun(@(p) ~isempty(findobj(p.axes, 'Tag', 'image')), hG.panels);
        C = PlotAesthetics.components(hG.layout);
        check(all(imgs) && string(hG.panels(1).axes.YLabel.String) == "Frequency (Hz)" && ~any(C.Role == "" | ~ismember(C.Role, roles)), ...
            'the spike spectrogram and both spike coherograms are drawn as images over time, every component tagged');
        % the range time base: segments of the recording, whatever the figure's alignment
        cs = cs.addFigure(struct('id', "ranged", 'observe', struct('data', "units"), 'ref', struct('line', "NoSuchLine"), ...
            'panels', {{struct('id', "sr", 'type', "spectrum", 'layers', lfpU, 'options', struct('timeBase', "range", 'segmentSec', 1))}}));
        Frg = rs.computeFigure(srcS, cs.figureFor("ranged"), Observation=Ts(1, :));
        Rr = Frg.panels.layers.R;
        check(Frg.panels.layers.skip == "" && Rr.timeBase.mode == "range" && height(Rr.groups) == 1 && Rr.nTrials(1) >= 2 ...
            && isempty(Frg.epochs) && isempty(Rr.epochs) && size(Rr.S, 1) == numel(Rr.f) && size(Rr.S, 2) == 1 && size(Rr.S, 3) == 1, ...
            sprintf('the range time base: %d one-second segments of the recording, one group, no epochs (the figure''s missing line not needed)', Rr.nTrials(1)));
        % what validate cannot see skips the layer, not the figure: a baseline with no window centered in it, fpass above Nyquist
        [~, fsL] = selectChannels(srcS, "LFP", Channels=1);
        cs = cs.addFigure(struct('id', "edges", 'observe', struct('data', "units"), 'grid', struct('rows', 3, 'cols', 1), 'panels', {{ ...
            struct('id', "sgb", 'type', "spectrogram", 'row', 1, 'col', 1, 'layers', lfpU, ...
                'options', struct('baseline', struct('Mode', "db", 'Window', [-0.2 -0.1]), 'movingwin', [0.5 0.05])), ...
            struct('id', "spu", 'type', "spectrum", 'row', 2, 'col', 1, 'layers', unitU, 'options', struct('spikeFs', 100, 'fpass', [60 100])), ...
            struct('id', "spl", 'type', "spectrum", 'row', 3, 'col', 1, 'layers', lfpU, 'options', struct('fpass', [fsL 2 * fsL]))}}));
        Ie = figIssues(cs);
        Ie = Ie(startsWith(Ie.Field, "edges."), :);
        Fe2 = rs.computeFigure(srcS, cs.figureFor("edges"), Observation=Ts(1, :));
        sk = [Fe2.panels(1).layers.skip Fe2.panels(2).layers.skip Fe2.panels(3).layers.skip];
        check(~any(Ie.Severity == "error") && contains(sk(1), "baseline") && contains(sk(2), "Nyquist") && contains(sk(3), "Nyquist") ...
            && all(arrayfun(@(P) isempty(P.layers.R), Fe2.panels)), ...
            sprintf('a spectrogram baseline no moving window is centered in, and fpass above a layer''s Nyquist (spikeFs 100; %g Hz LFP): validate passes, each layer is skipped with the reason ("%s")', ...
            fsL, sk(1)));
        % a range panel ignores the panel's window: a "between" window of pre = post = 0 does not matter
        cs = cs.addFigure(struct('id', "rangedBetween", 'observe', struct('data', "units"), ...
            'window', struct('mode', "between", 'pre', 0, 'post', 0, 'stop', struct('line', "Stim", 'edge', "offset")), 'panels', {{ ...
            struct('id', "srb", 'type', "spectrum", 'layers', lfpU, 'options', struct('timeBase', "range", 'segmentSec', 1)), ...
            struct('id', "crb", 'type', "coherence", 'row', 1, 'col', 2, 'layers', [lfpA lfpF], 'options', struct('timeBase', "range", 'segmentSec', 1))}}, ...
            'grid', struct('rows', 1, 'cols', 2)));
        Ib = figIssues(cs);
        Ib = Ib(startsWith(Ib.Field, "rangedBetween."), :);
        Fb = rs.computeFigure(srcS, cs.figureFor("rangedBetween"), Observation=Ts(1, :));
        Lb = Fb.panels(1).layers;
        Lcb = Fb.panels(2).layers;
        check(~any(Ib.Severity == "error") && Lb.skip == "" && Lb.R.timeBase.mode == "range" && all([Lcb.skip] == "") ...
            && Lcb(1).R.kind == "chronuxCoherence" && Lcb(1).R.timeBase.mode == "range", ...
            'range spectrum and coherence panels under a "between" window of pre = post = 0 compute: the window they do not use is not checked');

        % drawing
        hS = renderFigure(Fs, specS, fig);
        drawnow;
        axOf = @(id) hS.panels([hS.panels.id] == id).axes;
        want = 10 * log10(Rl.S(:, 1, 1));
        tr = findobj(axOf("spec_lfp"), 'Tag', 'trace');
        dbOk = any(arrayfun(@(h) numel(h.YData) == numel(want) && max(abs(h.YData(:) - want(:))) < 1e-6, tr));
        check(dbOk && string(axOf("spec_lfp").XLabel.String) == "Frequency (Hz)" && startsWith(string(axOf("spec_lfp").YLabel.String), "Power (dB re 1 ") ...
            && ~isempty(findall(axOf("spec_lfp"), 'Tag', 'sem')) && ~isempty(findall(axOf("spec_unit"), 'Tag', 'rateLine')), ...
            'a spectrum drawn in dB (10 log10 of its power) over its band, x Frequency (Hz); the spike spectrum''s rate line');
        as = axOf("sgram");
        ar = axOf("ras");
        cb = findobj(hS.layout, 'Type', 'colorbar', 'Tag', 'colorbar');
        check(isequal(xlim(ar), [-0.2 0.8]) && isequal(xlim(as), [-0.2 0.8]) && isempty(ar.XTickLabel) && string(as.XLabel.String) == "Time (s)" ...
            && ~isempty(findobj(as, 'Tag', 'image')) && string(as.YLabel.String) == "Frequency (Hz)" && any(arrayfun(@(c) strcmp(c.Location, 'east'), cb)), ...
            'a spectrogram shares the time axis with the raster above it (the raster''s tick labels go), its color bar inside');
        pxs = hS.panels([hS.panels.id] == "coh_lfp").extraAxes;
        ac = axOf("coh_lfp");
        check(isscalar(pxs) && isgraphics(pxs) && isequal(ylim(pxs), [-pi pi]) && ~isempty(findall(pxs, 'Tag', 'phase')) && isequal(ylim(ac), [0 1]) ...
            && ~isempty(findall(ac, 'Tag', 'confLine')) && numel(findobj(ac, 'Tag', 'channelTrace')) >= 2 && string(getappdata(pxs, 'PlotTile')) == "coh_lfp" ...
            && string(pxs.XLabel.String) == "Frequency (Hz)" && ac.Parent == hS.layout && pxs.Parent == hS.layout ...
            && abs(ac.Position(2) - pxs.Position(2) - pxs.Position(4)) < 0.5 && abs(ac.Position(4) - 2 * pxs.Position(4)) < 0.5 ...
            && abs(ac.Position(1) - pxs.Position(1)) < 0.5 && isempty(ac.XTickLabel), ...
            'a coherence panel: magnitude 0-1 with its confidence lines, the phase axes flush under it (a third of the panel), both tagged with the panel id');
        C = PlotAesthetics.components(hS.layout);
        bad = C.Role == "" | ~ismember(C.Role, roles);
        check(~any(bad), sprintf('every component of the spectral figure is tagged with a known role (%d components%s)', height(C), ...
            strjoin("; untagged " + C.Type(bad) + " " + C.Role(bad), "")));
        hu = renderFigure(Fu, Fu.spec, axes(fig));
        check(isscalar(hu.axes) && isempty(hu.panels.extraAxes) && ~isempty(findobj(hu.axes, 'Tag', 'trace')), ...
            'a coherence panel drawn into one axes: the magnitude, no phase axes');

        % without Chronux on the path: the spectral panels say so, the others are drawn
        if cxAdded ~= ""
            rmpath(cxAdded);
            [~, LRoff] = figureSkipReason(srcS, specS);
            Foff = rs.computeFigure(srcS, specS, Observation=Ts(1, :));
            addpath(cxAdded);
            spectral = ismember([Foff.panels.type], ["spectrum" "spectrogram" "coherence"]);
            offOk = all(arrayfun(@(P) P.skip == "Chronux is not on the path" && all([P.layers.skip] == "Chronux is not on the path"), Foff.panels(spectral)));
            hOff = renderFigure(Foff, specS, fig);
            notes = findall(hOff.layout, 'Tag', 'layerNote');
            check(offOk && Foff.panels(pid == "ras").layers.skip == "" && any([LRoff.reason] == "Chronux is not on the path") ...
                && any(contains(string(get(notes, 'String')), "Chronux is not on the path")), ...
                'Chronux off the path: every spectral panel is skipped with "Chronux is not on the path" (and says so), the raster is drawn');
        else
            fprintf('  SKIP: Chronux was on the path before the suite (not toolboxes/chronux): the check without it is left out\n');
        end
    end
    rmpathQuiet(cxAdded);
end

%% ============================================================================ session figures
if S.sec("10", "session figures: one figure across datasets")
    sroot = string(root) + "_sessions";
    cleanSessions = onCleanup(@() rmdirQuiet(sroot));
    FS2 = makeAnalysisFixture(sroot, Scenarios=["clean" "late-start"], NumTrials=12);
    sc = EphysAnalysisConfig();
    sc.Source.Root = FS2.proj;
    sc.Defaults.EventRef.line = "Stim";
    sc.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    sc.Defaults.Selection.groupBy = "Depth";
    sc = sc.addFigure("rasterPsth", Id="srp");
    sc.Figures(1).sessions.enabled = true;
    sc = sc.addFigure("continuous", Id="sct");
    sc.Figures(2).sessions.enabled = true;
    rq = EphysAnalysisRunner(sc, LogFcn=[]);
    check(isempty(sc.enabledFigures()) && isequal(sc.enabledSessionFigures(), ["srp" "sct"]) && sc.isSessionFigure("srp") ...
        && isequal(sc.sessionFigureIds(), ["srp" "sct"]), 'session figures are listed apart: enabledFigures (per dataset) leaves them out');
    sp1 = sc.figureFor("srp");
    [Tq, Sq, srcQ] = rq.sessionFigureObservations(sp1);
    perOwn = cellfun(@(s) figureObservations(s, setfield(sp1, 'observe', setfield(sp1.observe, 'perGroup', false))), srcQ, 'UniformOutput', false); %#ok<SFLD>
    chs = intersect(perOwn{1}.channel, perOwn{2}.channel);
    okIds = true;
    for i = 1:height(Tq)
        for s = 1:2
            okIds = okIds && isequal(sort(Tq.unitIds{i}{s}(:)), sort(perOwn{s}.unitId(perOwn{s}.channel == Tq.channel(i))));
        end
    end
    check(height(Sq) == 2 && all(Sq.status == "done") && height(Tq) >= 1 && all(Tq.kind == "unit") && all(startsWith(Tq.label, "site ch ")) ...
        && all(ismember(Tq.channel(Tq.nSessions == 2), chs)) && all(Tq.nSessions >= 1) && okIds ...
        && all(cellfun(@(P) height(P) == 2 && islogical(P.present), Tq.perSession)), ...
        sprintf('figureSessionObservations by site: %d sites ("%s", ...), each session''s units on the channel', height(Tq), Tq.label(1)));
    both = find(Tq.nSessions == 2, 1);
    sc2 = sc; sc2.Figures(1).sessions.minSessions = 2;
    Tq2 = figureSessionObservations(srcQ, sc2.figureFor("srp"));
    check(~isempty(both) && height(Tq2) == nnz(Tq.nSessions == 2) && all(Tq2.nSessions == 2), 'minSessions 2 keeps the sites both sessions hold');

    % the stars across sessions: a match is starred when it is starred on any of its sessions, and Starred only keeps it whole
    favQ = DatasetFavorites(srcQ{1});
    cleanStarsQ = onCleanup(@() deleteQuiet(favQ.File));
    check(~any(Tq.starred), 'figureSessionObservations: no star, no starred match');
    favQ.star("unit", Tq.unitIds{both}{1}(1));   % starred on the first session only
    TqA = figureSessionObservations(srcQ, sp1);
    spQ = sp1; spQ.observe.starred = true;
    TqS = figureSessionObservations(srcQ, spQ);
    check(isequal(TqA.starred, (1:height(TqA)).' == both) && isscalar(TqS.channel) && TqS.channel == Tq.channel(both) ...
        && TqS.nSessions == 2 && TqS.starred && all(TqS.perSession{1}.present) && ~TqS.perSession{1}.starred(2), ...
        'a site starred on one session is starred; Starred only keeps it, still drawn on both sessions');
    capQ = figureCaption(spQ, TqS, Sessions=Sq);
    capQ2 = figureCaption(sp1, TqA, Sessions=Sq);
    check(contains(capQ, Tq.label(both) + " (starred) across 2 sessions") && contains(capQ2, "matched by site; 1 starred) across 2 sessions"), ...
        "figureCaption across sessions: " + capQ + " / " + capQ2);
    favQ.star("unit", Tq.unitIds{both}{1}(1), false);

    % observations by a mapping file
    mapFile = fullfile(sroot, "unit_map.csv");
    P1 = Tq.perSession{both};
    M = table(["cellA"; "cellB"], [P1.unitId(1); P1.unitId(1)], [P1.unitId(2); NaN], 'VariableNames', ["cell" Sq.key(1) Sq.key(2)]);
    writeUnitMapping(mapFile, M, Overwrite=true);
    sm = sc; sm.Figures(1).sessions.match = "mapping"; sm.Figures(1).sessions.mappingFile = mapFile;
    Tm = figureSessionObservations(srcQ, sm.figureFor("srp"));
    check(isequal(Tm.label, ["cellA"; "cellB"]) && isequal(Tm.nSessions, [2; 1]) && Tm.unitIds{1}{1} == P1.unitId(1) ...
        && Tm.unitIds{1}{2} == P1.unitId(2) && isempty(Tm.unitIds{2}{2}) && ~Tm.perSession{2}.present(2), ...
        'figureSessionObservations by mapping: a row per cell, each session''s unit from its column (none where empty)');

    % a raster + PSTH merged over the two sessions: a color per session
    [resQ, SQ, ~, FsQ] = rq.computeSessionFigure("srp", [], Observation=Tq(both, :));
    Fq = resQ(1).F;
    Rq = Fq.panels(2).layers(1).R;
    Rr = Fq.panels(1).layers(1).R;
    own = arrayfun(@(s) FsQ{s}.panels(2).layers(1).R, 1:2);
    check(isscalar(resQ) && resQ(1).status == "done" && all(SQ.status == "done") && height(Fq.sessions) == 2 && Fq.nSessions == 2 ...
        && height(Rq.sessions) == 2 && height(Rq.groups) == 2 && Rq.sessionSeries.mode == "session" && size(Rq.rate, 2) == 1 ...
        && isequaln(Rq.rate(:, 1, 1), own(1).rate) && isequaln(Rq.rate(:, 1, 2), own(2).rate) && ~isequal(Rq.groups.color(1, :), Rq.groups.color(2, :)) ...
        && height(Fq.epochs) == height(FsQ{1}.epochs) + height(FsQ{2}.epochs) && contains(Fq.dataset, "2 sessions") ...
        && height(Rr.epochs) == height(Fq.epochs) && isscalar(Rr.raster) && Fq.observation.label == Tq.label(both), ...
        'computeSessionFigure: each session''s PSTH of its unit on the site is one series of the merged layer (sessions, colors, every epoch)');
    fgS = figure('Visible', 'off', 'Position', [0 0 900 700]);
    closeS = onCleanup(@() close(fgS));
    hq = renderFigure(Fq, sp1, fgS, Editable=false);
    Cq = PlotAesthetics.components(hq.layout);
    check(contains(hq.title, "(2 sessions, " + height(Fq.epochs) + " epochs)") && all(ismember(Cq.Role(Cq.Role ~= ""), roles)) && all(Cq.Role ~= "") ...
        && numel(findall(fgS, 'Type', 'Legend')) >= 1, sprintf('the merged figure renders: "%s", every component a known role', hq.title));

    % series "all" with members; trial groups combined by line style
    sa = sc; sa.Figures(1).sessions.series = "all"; sa.Figures(1).sessions.showMembers = true;
    ra = EphysAnalysisRunner(sa, LogFcn=[]);
    resA = ra.computeSessionFigure("srp", [], Observation=Tq(both, :));
    Ra = resA(1).F.panels(2).layers(1).R;
    clf(fgS);
    renderFigure(resA(1).F, sa.figureFor("srp"), fgS, Editable=false);
    check(height(Ra.groups) == 1 && Ra.groups.label == "All sessions" && isequal(size(Ra.members.rate), [size(Ra.rate, 1) 1 2]) ...
        && numel(findall(fgS, 'Tag', 'memberLine')) == 2 && ismember("memberLine", roles), ...
        'series "all" with showMembers: one series, each session a pale memberLine under it');
    sb = sc; sb.Figures(1).sessions.trialGroups = "combine";
    rb = EphysAnalysisRunner(sb, LogFcn=[]);
    resB = rb.computeSessionFigure("srp", [], Observation=Tq(both, :));
    Rb = resB(1).F.panels(2).layers(1).R;
    clf(fgS);
    renderFigure(resB(1).F, sb.figureFor("srp"), fgS, Editable=false);
    styles = unique(string(get(findall(fgS, 'Tag', 'rate', 'Type', 'line'), 'LineStyle')));
    check(ismember("lineStyle", string(Rb.groups.Properties.VariableNames)) && height(Rb.groups) > 2 && numel(unique(Rb.groups.base)) == 2 ...
        && numel(styles) >= 2 && figureSessionSpec(sb.figureFor("srp")).panels(2).options.histStyle == "line", ...
        sprintf('trialGroups "combine": %d series (session x group), the groups drawn in %d line styles', height(Rb.groups), numel(styles)));
    sbh = sb.figureFor("srp");
    sbh.panels(2).options.display = "heatmap";
    clf(fgS);
    hbh = renderFigure(resB(1).F, sbh, fgS, Editable=false);
    imb = findall(hbh.axes(2), 'Type', 'image');
    [~, rnb] = rowLabels(Rb);
    Cb = PlotAesthetics.components(hbh.layout);
    check(isscalar(imb) && size(imb.CData, 1) == height(Rb.groups) && string(hbh.axes(2).YLabel.String) == rnb ...
        && isempty(findall(fgS, 'Tag', 'memberLine')) && all(Cb.Role ~= "") && all(ismember(Cb.Role, roles)), ...
        sprintf('a merged PSTH as a heat map: a row per series (%d, named "%s"), every part a known role', height(Rb.groups), rnb));

    % a continuous figure by channel
    spc = sc.figureFor("sct");
    [Tc2, ~, srcC] = rq.sessionFigureObservations(spc);
    resC = rq.computeSessionFigure("sct", [], Observation=Tc2(1, :));
    Rc = resC(1).F.panels(1).layers(1).R;
    clf(fgS);
    renderFigure(resC(1).F, spc, fgS, Editable=false);
    check(all(Tc2.kind == "channel") && all(Tc2.nSessions == 2) && resC(1).status == "done" && Rc.kind == "evoked" && size(Rc.mean, 2) == 1 ...
        && height(Rc.groups) == 2 && Rc.sessionSeries.match == "channel" && numel(srcC) == 2, ...
        sprintf('a continuous session figure by channel: "%s" across both sessions, one channel, a series each', Tc2.label(1)));

    % facet "subject" and trialGroups "each": several figures
    se = sc; se.Figures(1).sessions.trialGroups = "each"; se.Figures(1).sessions.facet = "subject";
    spe = se.figureFor("srp");
    Sx = Sq; Sx.subject(2) = "SYNTH-99";   % two subjects
    resE = figureSessionCompute(srcQ, Sx, spe, Observation=Tq(both, :));
    facetsE = unique([resE.facet]);
    check(numel(resE) > 2 && numel(facetsE) == 2 && all([resE.group] ~= "") && all(contains([resE.label], " / ")), ...
        sprintf('facet "subject" x trialGroups "each": %d figures over %d subjects, one per trial group', numel(resE), numel(facetsE)));
    okE = resE([resE.status] == "done");
    check(~isempty(okE) && all(arrayfun(@(e) e.F.observation.groupLabel == e.group && height(e.F.panels(2).layers(1).R.groups) == 1, okE)), ...
        'each figure of a trial group holds that group alone, named in its observation');

    % unsupported panels: skipped with the reason, an error to validate, a skip reason
    su = sc;
    fu = su.Figures(1);
    fu = EphysAnalysisConfig.placePanel(fu, struct('id', "pm", 'type', "probemap"), "right", "psth_1");
    su.Figures(1) = fu;
    Iu = su.validate(CheckPaths=false);
    spu = su.figureFor("srp");
    resU = figureSessionCompute(srcQ, Sq, spu, Observation=Tq(both, :));
    pu = resU(1).F.panels([resU(1).F.panels.id] == "pm");
    check(any(Iu.Section == "Figures" & Iu.Field == "srp.pm.type" & Iu.Severity == "error" ...
        & Iu.Message == "A session figure cannot hold probe map panels: combineSessions does not merge them across sessions.") ...
        && pu.skip == "probe map panels are not merged across sessions" ...
        && figureSessionSkipReason(spu, ["" ""]) == "probe map panels are not merged across sessions" && resU(1).status == "done", ...
        'a probe map in a session figure: a validate error, the panel skipped with the reason (its label, no article), the rest drawn');

    % an event-trace panel in a session figure: every session's epochs, the sessions as its groups
    st = sc;
    etP = struct('id', "et", 'type', "eventTrace", 'layers', EphysAnalysisConfig.defaultLayer("eventTrace"), ...
        'options', struct('trials', "rows", 'colorBy', "group"));
    st.Figures(1) = EphysAnalysisConfig.placePanel(st.Figures(1), etP, "right", "psth_1");
    It = st.validate(CheckPaths=false);
    spt = st.figureFor("srp");
    [resT, ~, FsT] = figureSessionCompute(srcQ, Sq, spt, Observation=Tq(both, :));
    kT = find([resT(1).F.panels.id] == "et");
    RT = resT(1).F.panels(kT).layers(1).R;
    ownT = cellfun(@(f) f.panels(kT).layers(1).R, FsT, 'UniformOutput', false);
    nOwn = cellfun(@(r) r.nEpochs, ownT);
    clf(fgS);
    hT = renderFigure(resT(1).F, spt, fgS, Editable=false);
    bT = findall(hT.panels(kT).axes, 'Tag', 'eventBar', 'Type', 'patch');
    bT = bT(arrayfun(@(x) any(isfinite(x.Vertices(:))), bT));   % not the legend's swatches
    gT = string(arrayfun(@(x) string(getappdata(x, 'PlotGroup')), bT));
    check(~any(It.Field == "srp.et.type") && figureSessionSkipReason(spt, ["" ""]) == "" && resT(1).status == "done" ...
        && resT(1).F.panels(kT).skip == "" && RT.kind == "eventTrace" && RT.nEpochs == sum(nOwn) && numel(RT.on) == numel(ownT{1}.on) + numel(ownT{2}.on) ...
        && isequal(RT.epoch, [ownT{1}.epoch; nOwn(1) + ownT{2}.epoch]) && isequal(RT.epochGroup, [ones(nOwn(1), 1); 2 * ones(nOwn(2), 1)]) ...
        && height(RT.groups) == 2 && isequal(sort(gT(:)), sort(string(RT.groups.label(:)))), ...
        sprintf(['an event-trace panel in a session figure: merged as a raster is (%d + %d epochs, a sub-row each), ' ...
        'its bars in each session''s color'], nOwn(1), nOwn(2)));
    check(figureSessionSkipReason(sp1, ["" "no line Stim"], Labels=["a" "b"]) == "" && contains(figureSessionSkipReason(sc2.figureFor("srp"), ["" "no line Stim"], Labels=["a" "b"]), "fewer than 2") ...
        && figureSessionSkipReason(setfield(sp1, 'enabled', false), ["" ""]) == "disabled", ...
        'figureSessionSkipReason: minSessions against the sessions'' own reasons; disabled'); %#ok<SFLD>
    evS = sc; evS.Figures(1).panels(1).layers(end+1) = EphysAnalysisConfig.defaultLayer("raster");
    evS.Figures(1).panels(1).layers(end).source = "events"; evS.Figures(1).panels(1).layers(end).binding = "fixed";
    evS.Figures(1).panels(1).layers(end).event.line = "Stim";
    resV = figureSessionCompute(srcQ, Sq, evS.figureFor("srp"), Observation=Tq(both, :));
    check(resV(1).F.panels(1).layers(end).skip == "event marks are not drawn across sessions" && resV(1).F.panels(1).layers(1).skip == "", ...
        'events drawn as marks are skipped across sessions with the reason; the raster''s rows are drawn');

    % trialGroups "each" with minSessions 2: a group only one session holds is skipped, not drawn from one session.
    % The fixture's sessions ran the same depths, so session 2's first depth is moved (in a copy of its source)
    % to a depth only it ran: then each session holds a group the other lacks.
    srcG = srcQ;
    dep = srcG{2}.trials.Depth;
    d1 = dep(find(~ismissing(dep), 1));
    if isnumeric(dep); srcG{2}.trials.Depth(dep == d1) = max(dep) + 1000; else; srcG{2}.trials.Depth(dep == d1) = "elsewhere"; end
    sg = sc; sg.Figures(1).sessions.trialGroups = "each"; sg.Figures(1).sessions.minSessions = 2;
    spg = sg.figureFor("srp");
    resG = figureSessionCompute(srcG, Sq, spg, Observation=Tq(both, :));
    [~, Gq2] = selectTrials(srcG{2}, trialSelection(struct('groupBy', "Depth")));
    [~, Gq1] = selectTrials(srcG{1}, trialSelection(struct('groupBy', "Depth")));
    gl1 = string(Gq1.label); gl2 = string(Gq2.label);
    only1 = setxor(gl1, gl2);   % a depth only one of the sessions ran
    okG = true;
    for e = resG
        if ismember(e.group, only1)
            okG = okG && e.status == "skipped" && contains(e.message, "fewer than 2");
        elseif e.status == "done"
            okG = okG && e.F.nSessions == 2 && all(e.F.sessions.status == "done") && contains(e.F.dataset, "2 sessions") ...
                && sum(e.F.sessions.nEpochs) == height(e.F.epochs);
        end
    end
    check(okG && any([resG.status] == "done"), sprintf(['minSessions per trial group: a group held by one session is skipped ' ...
        '(%s), the others count only that group''s sessions and epochs'], strjoin(only1, ", ")));
    check(~isempty(only1), 'the fixture''s two sessions differ in their trial groups (the case above is not vacuous)');
    sg1 = sg; sg1.Figures(1).sessions.minSessions = 1;
    resG1 = figureSessionCompute(srcG, Sq, sg1.figureFor("srp"), Observation=Tq(both, :));
    e1 = resG1(ismember([resG1.group], only1));
    check(isempty(only1) || (~isempty(e1) && e1(1).status == "done" && e1(1).F.nSessions == 1 ...
        && any(e1(1).F.sessions.status == "missing") && contains(e1(1).F.dataset, "1 session")), ...
        'with minSessions 1 that group is drawn from its one session: nSessions 1, the other session "missing", the title''s count agrees');

    % site matching with different unit ids, and two units on one site (planted in session 2's sorting folder)
    u1 = P1.unitId(1);
    u2 = P1.unitId(2);
    dir2 = string(EphysDataset.resolvePhyDir(srcQ{2}.outputs.SortingDir));
    plantUnits(dir2, u2, 900, 901);   % session 2's unit on the site becomes 900, half its spikes 901: two units there
    rp = EphysAnalysisRunner(sc, LogFcn=[]);
    Tp = rp.sessionFigureObservations(sp1);
    r = find(Tp.channel == Tq.channel(both), 1);
    Pp = Tp.perSession{r};
    check(~isempty(r) && Pp.unitId(1) == u1 && ismember(Pp.unitId(2), [900 901]) && isequal(sort(Tp.unitIds{r}{2}(:)).', [900 901]) ...
        && ismember(u1, Tp.unitIds{r}{1}) && isnan(Tp.unitId(r)), ...
        sprintf('site matching: session 2''s units on ch %d are 900 and 901 (ids of their own), the first in probe order (%d) is drawn', ...
        Tq.channel(both), Pp.unitId(2)));
    [resP, ~, ~, FsP] = rp.computeSessionFigure("srp", [], Observation=Tp(r, :));
    Rp = resP(1).F.panels(2).layers(1).R;
    check(resP(1).status == "done" && size(Rp.rate, 2) == 1 && height(Rp.sessions) == 2 && all(Rp.sessions.status == "done") ...
        && Rp.meta.unitId(1) == u1 && FsP{2}.panels(2).layers(1).meta.unitId == Pp.unitId(2) ...
        && FsP{1}.panels(2).layers(1).meta.unitId == u1 && isequaln(Rp.rate(:, 1, 2), FsP{2}.panels(2).layers(1).R.rate), ...
        'the merged PSTH has one tile: session 1''s unit and session 2''s own (another id), the merged meta keeps session 1''s id');
    clear closeS
end

%% ============================================================================ stacks
if S.sec("11", "stacks and y limits: every panel type that stacks, one vocabulary; yLimMode auto / rows / batch / fixed")
    % the vocabulary: which types stack, how validate and adoptPanelOptions treat it
    sm = @EphysAnalysisConfig.stackModes;
    check(isequal(sm("psth"), ["off" "groups"]) && isequal(sm("continuous"), ["off" "groups" "items"]) ...
        && isequal(sm("heatmap"), sm("psth")) && isequal(sm("tuning"), sm("psth")) && isequal(sm("spectrum"), sm("psth")) ...
        && isequal(sm("spectrogram"), sm("psth")) && isequal(sm("coherence"), sm("psth")) ...
        && all(arrayfun(@(t) isempty(sm(t)), ["raster" "rate" "waveforms" "probemap" "corrmap" "eventTrace"])), ...
        'stackModes: PSTH, continuous (also items), heat map, tuning and the spectral types stack; raster, rate, waveforms, probe map, unit correlation and event traces do not');
    PTk = EphysAnalysisConfig.panelTypes();
    okDef = true;
    for t = reshape(PTk.Type, 1, [])
        o0 = PTk.DefaultOptions{PTk.Type == t};
        okDef = okDef && isfield(o0, 'stack') == ~isempty(sm(t));
        if isfield(o0, 'stack'); okDef = okDef && o0.stack == "off" && o0.stackSpacing == 1.1; end
    end
    check(okDef && ~isfield(PTk.DefaultOptions{PTk.Type == "continuous"}, 'display'), ...
        'every type that stacks has stack "off" and stackSpacing 1.1 by default, no other type has them; a continuous panel has no display');
    cv = EphysAnalysisConfig();
    cv.Source.Root = root;
    cv.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    cv = cv.addFigure("psth", Id="p");
    cv = cv.addFigure("heatmap", Id="h");
    cv = cv.addFigure("spectrum", Id="s");
    v1 = cv; v1.Figures(1).panels.options.stack = "items";
    v2 = cv; v2.Figures(2).panels.options.rows = "trials"; v2.Figures(2).panels.layers(1).binding = "observation";
    v2.Figures(2).panels.options.stack = "groups";
    v3 = cv; v3.Figures(3).panels.options.stackSpacing = 0;
    v4 = cv; v4.Figures(3).panels.options.stack = "groups"; v4.Figures(3).panels.options.stackSpacing = 0.8;
    check(has(v1, "p.psth_1.options.stack", "error") && has(v2, "h.heatmap_1.options.stack", "warning") ...
        && has(v3, "s.spectrum_1.options.stackSpacing", "error") && ~any(startsWith(figIssues(v4).Field, "s.")), ...
        'validate: a stack the type does not take (items on a PSTH), a heat map of trials'' stack (a warning: not used), a positive stackSpacing (below 1 overlaps: fine)');
    ap = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 3, 'cols', 1), 'panels', {{ ...
        struct('id', "p1", 'type', "psth", 'row', 1, 'options', struct('stack', "groups", 'stackSpacing', 1.4)), ...
        struct('id', "c1", 'type', "continuous", 'row', 2, 'options', struct('stack', "items")), ...
        struct('id', "r1", 'type', "rate", 'row', 3)}}));
    [ad, chg] = EphysAnalysisConfig.adoptPanelOptions(ap, "p1");
    [ad2, chg2] = EphysAnalysisConfig.adoptPanelOptions(ap, "c1");
    check(ad.panels(2).options.stack == "groups" && ad.panels(2).options.stackSpacing == 1.4 && ~isfield(ad.panels(3).options, 'stack') ...
        && isempty(setxor(chg([chg.id] == "c1").fields, ["stack" "stackSpacing"])) ...
        && ad2.panels(1).options.stack == "groups" && ad2.panels(1).options.stackSpacing == 1.4 && ismember("stack", chg2([chg2.id] == "p1").kept), ...
        'Apply to all panels: a PSTH''s stack goes to a continuous panel; a continuous panel''s "items" does not go to a PSTH, which keeps its own (kept "stack")');

    % the drawing, on section 7's "clean" dataset: every stacking type, its rows, their order, labels and roles
    fixtureA();
    drawTargets();
    ck = EphysAnalysisConfig();
    ck.Source.Root = FX.proj;
    ck.Defaults.EventRef.line = "Stim";
    ck.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    ck.Defaults.Selection.groupBy = "Depth";
    ck = ck.addFigure("psth", Id="k_psth");
    ck.Figures(end).panels(1).options.stack = "groups";
    ck = ck.addFigure("continuous", Id="k_cgroups");
    ck.Figures(end).panels(1).options.stack = "groups";
    ck = ck.addFigure("continuous", Id="k_citems");
    ck.Figures(end).panels(1).layers(1).binding = "fixed";
    ck.Figures(end).panels(1).layers(1).channels = [1 2 3];
    ck.Figures(end).panels(1).options.stack = "items";
    ck = ck.addFigure("heatmap", Id="k_heat");
    ck.Figures(end).panels(1).options.stack = "groups";
    ck = ck.addFigure("tuning", Id="k_tuning");
    ck.Figures(end).selection = EphysAnalysisConfig.defaults("TrialSelection");
    ck.Figures(end).selection.groupBy = "TrialType";
    ck.Figures(end).panels(1).options.param = "Depth";
    ck.Figures(end).panels(1).options.seriesParam = "TrialType";
    ck.Figures(end).panels(1).options.stack = "groups";
    kIds = ["k_psth" "k_cgroups" "k_citems" "k_heat" "k_tuning"];
    cxAdded = "";
    if ~ChronuxDataset.hasChronux() && isfolder(fullfile(repo, 'toolboxes', 'chronux'))
        cxAdded = string(genpath(fullfile(repo, 'toolboxes', 'chronux')));
        addpath(cxAdded);
    end
    cxBack = onCleanup(@() rmpathQuiet(cxAdded));
    if ChronuxDataset.hasChronux()
        for t = ["spectrum" "spectrogram" "coherence"]
            ck = ck.addFigure(t, Id="k_" + t);
            ck.Figures(end).panels(1).options.stack = "groups";
            kIds(end+1) = "k_" + t; %#ok<AGROW>
        end
        ck = ck.addFigure("coherence", Id="k_cohgram");
        ck.Figures(end).panels(1).options.overTime = true;
        ck.Figures(end).panels(1).options.stack = "groups";
        kIds(end+1) = "k_cohgram";
    else
        fprintf('  SKIP: Chronux is not on the path: the spectral stacks are not drawn\n');
    end
    Ik = figIssues(ck);
    check(~any(Ik.Severity == "error"), sprintf('the stacked figures validate (%d issue(s))', height(Ik)));
    rk = EphysAnalysisRunner(ck, LogFcn=[]);
    srcK = rk.source(1);
    images = ["k_heat" "k_spectrogram" "k_cohgram"];
    why = strings(1, 0);
    for id = kIds
        try
            spK = ck.figureFor(id);
            Tk = figureObservations(srcK, spK);
            Fk = rk.computeFigure(srcK, spK, Observation=Tk(1, :));
            hk = renderFigure(Fk, spK, fig);
            ax = hk.panels(1).axes;
            R = Fk.panels(1).layers(find([Fk.panels(1).layers.skip] == "", 1)).R;
            if id == "k_tuning"
                nRow = numel(R.series); first = string(R.series(1)); names = string(R.series);
            elseif id == "k_citems"
                nRow = size(R.mean, 2); first = ""; names = strings(1, 0);
            else
                nRow = height(R.groups); first = string(R.groups.label(1)); names = string(R.groups.label);
            end
            Cm = PlotAesthetics.components(hk.layout);
            sb = findall(ax, 'Tag', 'stackBase');
            lg = findall(fig, 'Type', 'legend');
            lgs = strings(1, 0);
            if ~isempty(lg); lgs = string(lg(1).String); end
            if ismember(id, images)
                im = findall(ax, 'Tag', 'image');
                gIm = arrayfun(@(x) string(getappdata(x, 'PlotGroup')), im);
                yIm = arrayfun(@(x) mean(x.YData), im);
                [~, topI] = max(yIm);
                if strcmp(ax.YDir, 'reverse'); [~, topI] = min(yIm); end
                ok = numel(im) == nRow && gIm(topI) == first && numel(findall(ax, 'Tag', 'rasterBand', 'Type', 'patch')) >= nRow ...
                    && numel(findall(fig, 'Type', 'colorbar')) == 1 && numel(ax.YTick) == nRow ...
                    && all(ismember(names, lgs));
            else
                yb = arrayfun(@(x) x.YData(1), sb);
                gb = arrayfun(@(x) string(getappdata(x, 'PlotGroup')), sb);
                [~, topB] = max(yb);
                ok = numel(ax.YAxis) == 2 && numel(sb) == nRow && numel(ax.YAxis(1).TickValues) == nRow ...
                    && (first == "" || gb(topB) == first || id == "k_cgroups" || id == "k_psth") ...
                    && all(arrayfun(@(x) isappdata(x, 'StackMap'), sb));
                if id ~= "k_citems"; ok = ok && all(ismember(names, lgs)); end
            end
            ok = ok && ~any(Cm.Role == "" | ~ismember(Cm.Role, roles));
            if ~ok; why(end+1) = id; end %#ok<AGROW>
        catch ME
            why(end+1) = id + ": " + ME.message; %#ok<AGROW>
        end
    end
    failTxt = "";
    if ~isempty(why); failTxt = ": failed " + strjoin(why, "; "); end
    check(isempty(why), sprintf(['every stacking type draws a row per group (a continuous panel''s items: per channel), the first ' ...
        'on top, named on the y axis, its groups in the legend, every part a known role: line rows a yyaxis with a row line each ' ...
        '(StackMap), image rows an image each with its color strip and one color bar (%s)%s'], strjoin(kIds, ", "), ...
        failTxt));
    % the order and labels of a stack of groups: the first group's row on top, its value the top tick label
    spP = ck.figureFor("k_psth");
    TkP = figureObservations(srcK, spP);
    FkP = rk.computeFigure(srcK, spP, Observation=TkP(1, :));
    spC = ck.figureFor("k_cgroups");
    TkC = figureObservations(srcK, spC);
FkC = rk.computeFigure(srcK, spC, Observation=TkC(1, :));
    hC = renderFigure(FkC, spC, fig);
    axC = hC.panels(1).axes;
    RC = FkC.panels(1).layers(1).R;
    rlC = rowLabels(RC);
    sbC = findall(axC, 'Tag', 'stackBase');
    [~, iTop] = max(arrayfun(@(x) x.YData(1), sbC));
    lblC = string(axC.YAxis(1).TickLabels);
    mC = findall(axC, 'Tag', 'trace');
    gm = arrayfun(@(x) string(getappdata(x, 'PlotGroup')), mC);
    m1 = mC(gm == string(RC.groups.label(1)));
    k1 = getappdata(m1(1), 'StackMap');
    check(string(getappdata(sbC(iTop), 'PlotGroup')) == rlC(1) && lblC(end) == rlC(1) && numel(axC.YAxis) == 2 ...
        && max(abs((m1(1).YData(:) - k1(1)) / k1(2) - double(RC.mean(:, 1, 1)))) < 1e-6 ...
        && contains(string(axC.YAxis(1).Label.String), "own scale"), ...
        'a continuous stack of groups: the first group on top (its value the top tick label), each trace its own values through its row''s StackMap, "... (each row on its own scale)" on the y axis (yLimMode auto)');
    hP = renderFigure(FkP, spP, fig);
    check(numel(hP.panels(1).axes.YAxis) == 2 && numel(findall(hP.panels(1).axes, 'Tag', 'stackBase')) == height(FkP.groups), ...
        'a PSTH stack of groups: a row each, a y axis on each side');

    % y limits: one yLimMode on every type with yLim; auto / rows / fixed / batch on a stack and an axis
    okY = true;
    for t = reshape(PTk.Type, 1, [])
        o0 = PTk.DefaultOptions{PTk.Type == t};
        okY = okY && isfield(o0, 'yLimMode') == isfield(o0, 'yLim');
        if isfield(o0, 'yLimMode'); okY = okY && o0.yLimMode == "auto"; end
    end
    check(okY && isequal(EphysAnalysisConfig.YLimModes, ["auto" "rows" "batch" "fixed"]) ...
        && ismember("yLimMode", EphysAnalysisConfig.sharedFieldsOf("continuous")) && ~ismember("yLim", EphysAnalysisConfig.sharedFieldsOf("rate")), ...
        'every type with yLim has yLimMode "auto" by default (YLimModes); it is a shared option, yLim itself is not');
    y1 = cv; y1.Figures(1).panels.options.yLimMode = "free";
    y2 = cv; y2.Figures(1).panels.options.yLimMode = "fixed";
    y3 = y2; y3.Figures(1).panels.options.yLim = [0 40];
    y4 = cv; y4.Figures(3).panels.options.yLimMode = "batch";
    check(has(y1, "p.psth_1.options.yLimMode", "error") && has(y2, "p.psth_1.options.yLim", "error") ...
        && ~any(startsWith(figIssues(y3).Field, "p.")) && ~any(startsWith(figIssues(y4).Field, "s.")), ...
        'validate: yLimMode one of YLimModes; "fixed" needs its yLim; "batch" on a spectrum is fine');
    ay = EphysAnalysisConfig.normalizeFigure(struct('grid', struct('rows', 2, 'cols', 1), 'panels', {{ ...
        struct('id', "p1", 'type', "psth", 'row', 1, 'options', struct('yLimMode', "fixed", 'yLim', [0 30])), ...
        struct('id', "c1", 'type', "continuous", 'row', 2)}}));
    [ady, chy] = EphysAnalysisConfig.adoptPanelOptions(ay, "p1");
    ay2 = ay; ay2.panels(1).options.yLimMode = "batch";
    ady2 = EphysAnalysisConfig.adoptPanelOptions(ay2, "p1");
    check(ady.panels(2).options.yLimMode == "auto" && isempty(ady.panels(2).options.yLim) && ismember("yLimMode", chy.kept) ...
        && ady2.panels(2).options.yLimMode == "batch", ...
        'Apply to all panels: yLimMode goes to a panel of another type, but "fixed" not to one without limits of its own (kept); yLim stays the type''s');

    % the modes on a continuous stack of groups (each row's StackMap) and on a PSTH's axis
    mapsOf = @(ax) cell2mat(arrayfun(@(x) getappdata(x, 'StackMap'), findall(ax, 'Tag', 'stackBase'), 'UniformOutput', false));
    yMode = @(sp, m, lim) setfield(sp, 'panels', setfield(sp.panels, 'options', ...
        setfield(setfield(sp.panels.options, 'yLimMode', m), 'yLim', lim))); %#ok<SFLD>
    hA = renderFigure(FkC, yMode(spC, "auto", []), fig);
    mA = mapsOf(hA.panels(1).axes);
    yA = string(hA.panels(1).axes.YAxis(1).Label.String);
    extC = hA.panels(1).yExtent;
    hR = renderFigure(FkC, yMode(spC, "rows", []), fig);
    mR = mapsOf(hR.panels(1).axes);
    hB0 = renderFigure(FkC, yMode(spC, "batch", []), fig);
    mB0 = mapsOf(hB0.panels(1).axes);
    hF = renderFigure(FkC, yMode(spC, "fixed", [-500 500]), fig);
    LF = hF.panels(1).axes.YAxis(1).Label.String;
    hB = renderFigure(FkC, yMode(spC, "batch", []), fig, BatchYLim=struct('id', spC.panels.id, 'lim', [-400 400], 'n', 7));
    LB = hB.panels(1).axes.YAxis(1).Label.String;
    check(numel(unique(round(mA(:, 2), 9))) > 1 && contains(yA, "own scale") && all(mR(:, 2) == 1) ...
        && isequal(mB0, mR) && contains(string(LF), "1e+03") && contains(string(LB), "800") ...
        && all(isfinite(extC)) && extC(2) > extC(1), ...
        ['a continuous stack: Auto scales each row to itself ("each row on its own scale"), Shared by rows puts every row on one ' ...
        'scale, Batch without a run''s range is as rows, Fixed spans yLim per row (1e+03 µV per row), Batch with BatchYLim its range (800); ' ...
        'its yExtent is the rows'' reach in µV']);
    spPf = spP; spPf.panels.options.yLimMode = "fixed"; spPf.panels.options.yLim = [0 77]; spPf.panels.options.stack = "off";
    hPf = renderFigure(FkP, spPf, fig);
    ylF = ylim(hPf.panels(1).axes);
    spPb = spPf; spPb.panels.options.yLimMode = "batch";
    hPb = renderFigure(FkP, spPb, fig, BatchYLim=struct('id', spPb.panels.id, 'lim', [-3 66], 'n', 2));
    ylB = ylim(hPb.panels(1).axes);
    hPa = renderFigure(FkP, setfield(spPf, 'panels', setfield(spPf.panels, 'options', setfield(spPf.panels.options, 'yLimMode', "auto"))), fig); %#ok<SFLD>
    check(isequal(ylF, [0 77]) && isequal(ylB, [-3 66]) && ~isequal(ylim(hPa.panels(1).axes), [0 77]) ...
        && all(isfinite(hPa.panels(1).yExtent)) && diff(hPa.panels(1).yExtent) > 0, ...
        'an overlaid PSTH: Fixed at yLim, Batch at the run''s range, Auto from the data (its yExtent the axis'' limits as drawn)');
    Bu = figureBatchYLim({struct('id', "a", 'lim', [0 5]), struct('id', {"a" "b"}, 'lim', {[-1 3] [NaN NaN]}), struct('id', "a", 'lim', [2 9])});
    check(isequal([Bu.id], ["a" "b"]) && isequal(Bu(1).lim, [-1 9]) && Bu(1).n == 3 && all(isnan(Bu(2).lim)) && Bu(2).n == 0 ...
        && isequal(figureBatchPanels(spPb), spPb.panels.id) && isempty(figureBatchPanels(spPf)), ...
        'figureBatchYLim: the union of the observations'' extents per panel, how many gave one; figureBatchPanels lists the batch panels');

    % a run (EphysAnalysisRunner.run: Generate and Export): every observation of the run on one range
    cb = ck;
    kb = cb.figureIndex("k_psth");
    cb.Figures(kb).panels.options.stack = "off";
    cb.Figures(kb).panels.options.yLimMode = "batch";
    cb.Export.Folder = string(fullfile(root, "batch_out"));
    cb.Export.Formats = "png";
    rb = EphysAnalysisRunner(cb, LogFcn=[]);
    Rb = rb.run(Figures="k_psth", Export=true, Report=false);
    spB = cb.figureFor("k_psth");
    srcB = rb.source(1);
    TB = figureObservations(srcB, spB);
    own = zeros(0, 2);
    drawn = zeros(0, 2);
    for i = 1:height(TB)
        FB = rb.computeFigure(srcB, spB, Observation=TB(i, :));
        Ei = figureYExtents(FB, spB);
        own(end+1, :) = Ei.lim; %#ok<AGROW>
        hBi = renderFigure(FB, spB, fig, BatchYLim=rb.BatchYLim);
        drawn(end+1, :) = ylim(hBi.panels(1).axes); %#ok<AGROW>
    end
    BB = rb.BatchYLim;
    check(all(Rb.Status == "done") && isscalar(BB) && BB.figure == "k_psth" && BB.n == height(TB) ...
        && isequal(BB.lim, [min(own(:, 1)) max(own(:, 2))]) && size(unique(drawn, 'rows'), 1) == 1 && isequal(drawn(1, :), BB.lim) ...
        && size(unique(own, 'rows'), 1) > 1 && isempty(rb.BatchCache), ...
        sprintf(['a run of a figure with Y limits shared by batch measures every observation first: r.BatchYLim is the union of ' ...
        'their own extents (%d observations, [%g %g]), and every page drawn with it has that one y range; the figures kept ' ...
        'while measuring are gone after the run'], height(TB), BB.lim));
    capB = figureCaption(spB, TB, YShared=BB.n);
    txtB = EphysAnalysisScript.standalone(cb);
    check(contains(capB, sprintf("y shared across %d observations", BB.n)) && contains(figureCaption(spB, TB), "y shared across the run's observations") ...
        && ~contains(figureCaption(spP, TB), "y shared") && contains(txtB, "figureBatchYLim(yext)") && contains(txtB, "BatchYLim=batchYLim"), ...
        'the caption says the y range is shared across the run''s observations; the standalone script measures them first and draws with BatchYLim');
    clear cxBack
end

if S.sec("12", "config: one edit given to other figures (figureEditChanges, changeTargets, applyChanges, panelTakes)")
    ca = EphysAnalysisConfig();
    ca = ca.addFigure("rasterPsth", Id="rp");
    ca = ca.addFigure("psth", Id="p");
    ca = ca.addFigure("continuous", Id="c");
    ca = ca.addFigure("rate", Id="r");
    D = ca.Defaults;
    F0 = ca.Figures;
    F1 = F0;
    F1(1).panels(2).options.stack = "groups";
    C = EphysAnalysisConfig.figureEditChanges(F0(1), F1(1), 2);
    ca.Figures = F1;
    T = EphysAnalysisConfig.changeTargets(ca.Figures, D, 1, 2, C);
    check(isscalar(C) && C.scope == "panel" && C.path == "options.stack" && C.value == "groups" ...
        && isequal(string({T.figureId}), ["p" "c"]) && all([T.panel] == 1) && ~any([T.same]) && isequal(T(1).current, {"off"}) ...
        && isequal(string({T.panelType}), ["psth" "continuous"]), ...
        'a PSTH''s stack edited: one change, options.stack; the other figures'' PSTH and continuous panels can take it, "off" now (not the raster beside it, not a rate panel: no stack)');
    G = EphysAnalysisConfig.applyChanges(ca.Figures, D, T(2), C);
    check(G(3).panels(1).options.stack == "groups" && G(2).panels(1).options.stack == "off" && isequaln(G([1 2 4]), ca.Figures([1 2 4])), ...
        'applyChanges gives it to the row picked only (the continuous panel)');
    F2 = ca.Figures;
    F2(3).panels(1).options.stack = "items";
    C2 = EphysAnalysisConfig.figureEditChanges(ca.Figures(3), F2(3), 1);
    T2 = EphysAnalysisConfig.changeTargets(F2, D, 3, 1, C2);
    [tf1, k1] = EphysAnalysisConfig.panelTakes(F2(3).panels(1), F2(2).panels(1), "stack");
    [tf2, k2] = EphysAnalysisConfig.panelTakes(F2(2).panels(1), F2(1).panels(1), "stack");
    Pz = F2(2).panels(1);
    Pz.options.baseline.Mode = "zscore";
    [tf3, k3] = EphysAnalysisConfig.panelTakes(Pz, F2(3).panels(1), "baseline.Mode");
    tf4 = EphysAnalysisConfig.panelTakes(Pz, F2(3).panels(1), "baseline.Window");
    tf5 = EphysAnalysisConfig.panelTakes(Pz, F2(1).panels(2), "histStyle");
    tf6 = EphysAnalysisConfig.panelTakes(Pz, F2(3).panels(1), "histStyle");
    check(isempty(T2) && ~tf1 && k1 == "stack" && ~tf2 && k2 == "" && ~tf3 && k3 == "baseline" && tf4 && tf5 && ~tf6, ...
        ['panelTakes: a continuous panel''s "items" goes to no other type (kept "stack"); a raster has no stack; a zscore ' ...
        'baseline does not go to a continuous panel, its window does; a PSTH''s own options go to PSTHs only']);
    F3 = ca.Figures;
    F3(2).panels(1).options.stack = "groups";
    T3 = EphysAnalysisConfig.changeTargets(F3, D, 2, 1, EphysAnalysisConfig.figureEditChanges(ca.Figures(2), F3(2), 1));
    check(isequal(string({T3.figureId}), ["rp" "c"]) && isequal([T3.same], [true false]), 'a target with the value already is marked same');
    F4 = ca.Figures;
    F4(2).style.FontSize = 15;
    F4(2).grid.spacing = "loose";
    C4 = EphysAnalysisConfig.figureEditChanges(ca.Figures(2), F4(2), 1);
    T4 = EphysAnalysisConfig.changeTargets(F4, D, 2, 1, C4);
    G4 = EphysAnalysisConfig.applyChanges(F4, D, T4, C4);
    check(isequal(sort([C4.path]), sort(["style.FontSize" "grid.spacing"])) && all([C4.scope] == "figure") ...
        && isequal(string({T4.figureId}), ["rp" "c" "r"]) && all([T4.panel] == 0) ...
        && all(arrayfun(@(f) f.style.FontSize == 15 && f.grid.spacing == "loose", G4)), ...
        'figure settings (font size, spacing): every other figure is a row, one per figure; applied, every figure has them');
    F5 = ca.Figures;
    F5(1).title = "t";
    F5(1).id = "rp2";
    F5(1).panels(2).title = "x";
    F5(1).panels(2).layers(1).enabled = false;
    F5(1).panels(2).note.text = "n";
    F5(1).panels(2).row = 3;
    check(isempty(EphysAnalysisConfig.figureEditChanges(ca.Figures(1), F5(1), 2)), ...
        'a figure''s id and title, a panel''s title, place, layers and note text are each one''s own: no change to give');
    F6 = ca.Figures;
    F6(1).ref = D.EventRef;
    ca.Figures = F6;
    F7 = ca.Figures;
    F7(1).ref.edge = "offset";
    C7 = EphysAnalysisConfig.figureEditChanges(ca.Figures(1), F7(1), 1);
    T7 = EphysAnalysisConfig.changeTargets(F7, D, 1, 1, C7);
    G7 = EphysAnalysisConfig.applyChanges(F7, D, T7(1), C7);
    check(isscalar(C7) && C7.path == "ref.edge" && numel(T7) == 3 && isequal(T7(1).current, {D.EventRef.edge}) ...
        && isstruct(G7(2).ref) && G7(2).ref.edge == "offset" && isequaln(rmfield(G7(2).ref, 'edge'), rmfield(D.EventRef, 'edge')) ...
        && isequal(G7(3).ref, "default"), ...
        'one field of a figure''s own event reference: a figure using the Defaults'' shows theirs, and takes it as its own, the Defaults'' with the field changed');
end

if S.sec("13", "figure size: the page a figure is exported on (figureExportSize, newExportFigure, the suggestions and typed sizes, validate, JSON)")
    cz = EphysAnalysisConfig();
    cz = cz.addFigure("rasterPsth", Id="rp");
    cz = cz.addFigure("psth", Id="p");
    sz0 = EphysAnalysisConfig.defaults("Figure").size;
    check(isequal(sz0, struct('source', "export", 'width', 18, 'height', 12, 'units', "cm", 'lock', false)) && isequal(cz.Figures(1).size, sz0), ...
        'a figure''s size defaults to the Export tab''s (source export), 18 x 12 cm kept for an own size');
    X = cz.Export;
    fp = cz.figureFor(1);
    check(all(abs(figureExportSize(X, [], fp) - [18 12]) < 1e-12) && all(abs(figureExportSize(X) - [18 12]) < 1e-12), ...
        'source export: the Export size (a 2-row figure fits in 12 cm)');
    fp.grid.rows = 5;
    check(all(abs(figureExportSize(X, [], fp) - [18 19.5]) < 1e-12), 'source export: taller for the rows, 3.5 cm each plus 2');
    fp.size = struct('source', "own", 'width', 1200, 'height', 800, 'units', "px", 'lock', false);
    X.Dpi = 150;
    check(all(abs(figureExportSize(X, [], fp) - [1200 800] / 150 * 2.54) < 1e-12), 'source own, px: pixels of the PNG at the Export dpi (rows do not matter)');
    X.Dpi = 300;
    check(all(abs(figureExportSize(X, [], fp) - [1200 800] / 300 * 2.54) < 1e-12), 'px follow the dpi');
    fp.size.units = "in";
    fp.size.width = 7;
    fp.size.height = 4.5;
    check(all(abs(figureExportSize(X, [], fp) - [7 4.5] * 2.54) < 1e-12), 'source own, in');
    fp.size.units = "cm";
    check(all(abs(figureExportSize(X, [], fp) - [7 4.5]) < 1e-12), 'source own, cm');
    fz = newExportFigure(X, [], fp);
    posz = fz.Position(3:4);
    papz = fz.PaperSize;
    close(fz);
    check(all(abs(posz - [7 4.5]) < 1e-9) && all(abs(papz - [7 4.5]) < 1e-9), 'newExportFigure draws the export page at the own size');
    fz = newExportFigure(cz.Export, [], cz.figureFor(1));
    posz = fz.Position(3:4);
    close(fz);
    check(all(abs(posz - [18 12]) < 1e-9), 'newExportFigure without an own size: the Export size');

    % the units, the suggestions and what is typed
    check(abs(figureSizeConvert(2.54, "cm", "in") - 1) < 1e-12 && abs(figureSizeConvert(150, "px", "in", 150) - 1) < 1e-12 ...
        && abs(figureSizeConvert(1, "in", "px", 300) - 300) < 1e-12 && isequal(figureSizeConvert([1 2], "cm", "cm"), [1 2]), ...
        'figureSizeConvert: cm, in and px (a pixel is 1 / dpi inch)');
    T = figureSizePresets();
    check(T.Label(1) == "Export tab size" && T.Label(end) == "Fit preview" && all(isnan(T.Width([1 end]))) && all(isfinite(T.Width(2:end - 1))) ...
        && all(ismember(T.Units(2:end - 1), EphysAnalysisConfig.FigureSizeUnits)) && numel(unique(T.Label)) == height(T), ...
        'the suggestions: Export tab size first, Fit preview last, the rest with a size in px, in or cm');
    ok = true;
    for i = 2:height(T) - 1
        [s, good] = figureSizeParse(T.Label(i));
        ok = ok && good && s.width == T.Width(i) && s.height == T.Height(i) && s.units == T.Units(i) ...
            && figureSizeText(s.width, s.height, s.units) == T.Label(i);
    end
    check(ok, 'every suggestion parses to its size, and figureSizeText gives its label back');
    [s1, g1] = figureSizeParse("6 x 4 in");
    [s2, g2] = figureSizeParse("1200x800 px");
    [s3, g3] = figureSizeParse("15 X 10", "in");
    [s4, g4] = figureSizeParse("150 x 100 mm");
    [s5, g5] = figureSizeParse("  3.5*2.25 inches ");
    [s6, g6] = figureSizeParse("8 x 5");
    check(g1 && isequal(s1, struct('width', 6, 'height', 4, 'units', "in")) && g2 && s2.width == 1200 && s2.units == "px" ...
        && g3 && s3.units == "in" && g4 && abs(s4.width - 15) < 1e-12 && s4.units == "cm" && g5 && s5.width == 3.5 && s5.height == 2.25 && s5.units == "in" ...
        && g6 && s6.units == "cm", ...
        'typed sizes: "6 x 4 in", "1200x800 px", a capital X, mm (kept in cm), inches, no unit = the units given (cm)');
    bad = ["" "abc" "6 x" "x 4 in" "0 x 4 in" "6 x 4 furlongs" "Export tab size" "Fit preview"];
    nbad = 0;
    for b = bad
        [~, g] = figureSizeParse(b);
        nbad = nbad + ~g;
    end
    check(nbad == numel(bad) && figureSizeText(7.25, 4.5, "in") == "7.25 x 4.5 in", ...
        'text that is no size (and the two labels without one) is not read; figureSizeText of a size with no suggestion');

    % validate, normalize, JSON
    cv = cz;
    cv.Source.Root = root;
    cv.Figures(1).size = struct('source', "own", 'width', 7, 'height', 4.5, 'units', "in", 'lock', true);
    check(~has(cv, "rp.size", "error") && ~has(cv, "rp.size.units", "error") && ~has(cv, "rp.size.source", "error"), 'an own size in inches validates');
    cb = cv;
    cb.Figures(1).size.width = 0;
    cb2 = cv;
    cb2.Figures(1).size.units = "mm";
    cb3 = cv;
    cb3.Figures(1).size.source = "fixed";
    check(has(cb, "rp.size", "error") && has(cb2, "rp.size.units", "error") && has(cb3, "rp.size.source", "error"), ...
        'a size of 0, units mm and a source "fixed" are errors');
    cb4 = cv;
    cb4.Figures(1).size.source = "export";
    cb4.Figures(1).size.width = 0;
    check(~has(cb4, "rp.size", "error"), 'the own width and height are not checked while the source is export');
    fj = [tempname '.json'];
    cv.save(fj);
    cl = EphysAnalysisConfig.load(fj);
    delete(fj);
    check(isequal(cl.Figures(1).size, cv.Figures(1).size) && isequal(cl.Figures(2).size, sz0), 'the size round-trips through JSON; a figure without one keeps the default');
    pk = EphysAnalysisConfig.figureEditChanges(cv.Figures(1), cz.Figures(1), 0);
    check(any([pk.path] == "size.source") && any([pk.path] == "size.width"), 'a size edit is a change another figure can take (Apply to figures)');
end

%% ============================================================================ scale
if S.sec("14", "render at a scale: the preview in proportion to the export page (renderFigure Scale, PlotAesthetics.drawScale)")
    fixtureA();
    cs = EphysAnalysisConfig();
    cs.Source.Root = FX.proj;
    cs.Defaults.EventRef.line = "Stim";
    cs.Defaults.Window = struct('mode', "fixed", 'pre', -0.2, 'post', 0.8, 'stop', []);
    cs = cs.addFigure("rasterPsth", Id="z_rp");
    nt = EphysAnalysisConfig.defaults("Note");
    nt.text = "n = 12"; nt.placement = "below"; nt.box = true;
    cs.Figures(1).panels(2).note = nt;
    ov = EphysAnalysisConfig.defaults("Overlay");
    ov.value = 0.1;
    cs.Figures(1).panels(2).overlays = ov;
    cs = cs.addFigure("tuning", Id="z_tu");
    cs.Figures(2).panels(1).options.param = "Depth";
    rz = EphysAnalysisRunner(cs, LogFcn=[]);
    srcZ = rz.source(1);
    sc = 1.5;
    uz = uifigure('Visible', 'off', 'Position', [50 50 1100 760]);
    closeUz = onCleanup(@() delete(uz));
    for id = ["z_rp" "z_tu"]
        spZ = cs.figureFor(id);
        Tz = figureObservations(srcZ, spZ);
        Fz = rz.computeFigure(srcZ, spZ, Observation=Tz(1, :));
        fz = newExportFigure(cs.Export, Fz, spZ);
        hE = renderFigure(Fz, spZ, fz);
        pg = getpixelposition(fz);
        delete(uz.Children);
        pz = uipanel(uz, 'Units', 'pixels', 'Position', [1 1 round(sc * pg(3:4))], 'BorderType', 'none');
        hP = renderFigure(Fz, spZ, pz, Scale=sc);
        E = drawnSizes(fz);
        V = drawnSizes(pz);
        k = 1 + (V.prop == "SizeData");
        same = height(E) == height(V) && all(E.key == V.key) && all(E.prop == V.prop);
        dev = Inf;
        worst = "the parts differ";
        if same
            [dev, iw] = max(abs(V.val ./ (E.val .* sc .^ k) - 1));
            worst = sprintf('%s %s %g vs %g', V.key(iw), V.prop(iw), V.val(iw), E.val(iw));
        end
        wE = hE.panels(1).axes.InnerPosition(3) / pg(3);
        wP = hP.panels(1).axes.InnerPosition(3) / (sc * pg(3));
        check(same && dev < 1e-6 && abs(wP / wE - 1) < 0.02, ...
            sprintf(['%s at Scale %g: every size of its %d parts %g times the export''s (largest deviation %.2g: %s; fonts, lines, ' ...
            'markers, caps, labels), the first plot area %.3f of the page''s width vs %.3f exported'], ...
            id, sc, height(E), sc, dev, worst, wP, wE));
        if id == "z_rp"
            ax = hP.panels(2).axes;
            lw = ax.LineWidth;
            v0 = PlotAesthetics.getValue(ax, "LineWidth");
            PlotAesthetics.setValue(ax, "LineWidth", 1);
            check(PlotAesthetics.drawScale(pz) == sc && PlotAesthetics.drawScale(ax) == sc && abs(v0 - lw / sc) < 1e-6 ...
                && abs(ax.LineWidth - sc) < 1e-9 && PlotAesthetics.drawScale(fz) == 1, ...
                'the root keeps the scale; getValue gives a size as exported, setValue takes one so (1 pt is drawn 1.5 pt); an export has scale 1');
            renderFigure(Fz, spZ, pz, Reuse=true, Scale=sc);
            s2 = spZ;
            s2.panels(2).options.histStyle = "line";
            renderFigure(Fz, s2, pz, Reuse=true, Scale=sc);
            pw = uipanel(uz, 'Units', 'pixels', 'Position', pz.Position, 'BorderType', 'none', 'Visible', 'off');
            renderFigure(Fz, s2, pw, Scale=sc);
            drawnow;
            [sameR, whyR] = sameDrawing(pz, pw);
            Ra = drawnSizes(pz);
            Rb = drawnSizes(pw);
            sizesR = height(Ra) == height(Rb) && all(Ra.key == Rb.key) && all(Ra.prop == Rb.prop) && all(abs(Ra.val - Rb.val) <= 1e-9 * Rb.val);
            check(sameR && sizesR, ...
                sprintf('Reuse at a scale: the kept raster is not scaled twice, the drawing the same as a whole one (%s)', whyR));
            renderFigure(Fz, spZ, pz);
            check(PlotAesthetics.drawScale(pz) == 1, 'drawn again at Scale 1, the root keeps no scale');
        end
        close(fz);
    end
end

fprintf('\n================  %d passed, %d failed  ================\n', nPass, nFail);
if nFail > 0
    error('test_EphysAnalysisFigures:Failures', '%d checks failed.', nFail);
end
end


function P = noCreated(P)
%noCreated  A panel result without its layers' creation times (a compute made at another second).
for j = 1:numel(P.layers)
    if isstruct(P.layers(j).R) && isfield(P.layers(j).R, 'created'); P.layers(j).R = rmfield(P.layers(j).R, 'created'); end
end
end


function [ok, why] = sameTexts(A, B)
%sameTexts  The titles and axis labels of two drawings of renderFigure alike: every axes in order, each text's string, place and look.
why = "the same";
a = flipud(findall(A, 'Type', 'axes'));
b = flipud(findall(B, 'Type', 'axes'));
ok = numel(a) == numel(b);
if ~ok; why = sprintf('%d vs %d axes', numel(a), numel(b)); return; end
props = {'Interpreter', 'FontSize', 'FontWeight', 'FontAngle', 'Color', 'Visible', 'HorizontalAlignment', 'Rotation'};
for i = 1:numel(a)
    ta = [a(i).Title a(i).Subtitle a(i).XLabel reshape([a(i).YAxis.Label], 1, [])];
    tb = [b(i).Title b(i).Subtitle b(i).XLabel reshape([b(i).YAxis.Label], 1, [])];
    if numel(ta) ~= numel(tb); ok = false; why = sprintf('axes %d: its texts', i); return; end
    for j = 1:numel(ta)
        if ~isequal(string(ta(j).String), string(tb(j).String)) || any(abs(ta(j).Position - tb(j).Position) > 1e-6)
            ok = false; why = sprintf('axes %d (%s): text %d "%s"', i, a(i).Tag, j, strjoin(string(ta(j).String), " ")); return
        end
        for p = props
            if ~isequal(get(ta(j), p{1}), get(tb(j), p{1}))
                ok = false; why = sprintf('axes %d (%s): text %d %s', i, a(i).Tag, j, p{1}); return
            end
        end
    end
end
end


function T = drawnSizes(root)
%drawnSizes  Every size a scale multiplies (PlotAesthetics.SizeProps) of the parts renderFigure tagged in ROOT, its panels' axes and their labels: key, prop, val, sorted.
%   The hidden hosts of the title and of a note band (their own font shows
%   nothing) are left out; a vector (a legend's ItemTokenSize) gives its first value.
key = strings(0, 1); prop = strings(0, 1); val = zeros(0, 1);
for o = reshape(findall(root), 1, [])
    if ~startsWith(class(o), "matlab.graphics.") || o.Tag == "" || ismember(o.Tag, ["titleHost" "noteHost"]); continue; end
    parts = {o, string(class(o)) + ":" + o.Tag};
    if isa(o, 'matlab.graphics.axis.Axes')
        parts = [parts; {o.XLabel, o.Tag + ":xlabel"; o.YLabel, o.Tag + ":ylabel"; o.Title, o.Tag + ":title"}]; %#ok<AGROW>
    end
    for i = 1:size(parts, 1)
        for p = PlotAesthetics.SizeProps
            if ~isprop(parts{i, 1}, p); continue; end
            v = double(get(parts{i, 1}, p));
            if isempty(v); continue; end
            key(end+1, 1) = parts{i, 2}; %#ok<AGROW>
            prop(end+1, 1) = p; %#ok<AGROW>
            val(end+1, 1) = v(1); %#ok<AGROW>
        end
    end
end
T = sortrows(table(key, prop, val), {'key', 'prop', 'val'});
end


function [ok, why] = sameDrawing(A, B)
%sameDrawing  Two drawings of renderFigure alike: every axes in order (place, limits, ticks, labels, children), the legends and color bars.
%   A color bar kept from an earlier drawing may sit within a pixel of a
%   new one.
why = "the same";
a = flipud(findall(A, 'Type', 'axes'));
b = flipud(findall(B, 'Type', 'axes'));
ok = numel(a) == numel(b);
if ~ok; why = sprintf('%d vs %d axes', numel(a), numel(b)); return; end
props = {'Position', 'XLim', 'YLim', 'XTick', 'YTick', 'XTickLabel', 'YTickLabel', 'FontSize', 'Visible', 'Tag', ...
    'XAxisLocation', 'YAxisLocation', 'Color', 'Box'};
for i = 1:numel(a)
    for p = props
        va = get(a(i), p{1});
        vb = get(b(i), p{1});
        if isnumeric(va)
            same = isequal(size(va), size(vb)) && all(abs(va(:) - vb(:)) < 1e-6 | (isnan(va(:)) & isnan(vb(:))));
        else
            same = isequal(va, vb);
        end
        if ~same; ok = false; why = sprintf('axes %d (%s): %s', i, a(i).Tag, p{1}); return; end
    end
    for t = {'Title', 'XLabel', 'YLabel'}
        if ~isequal(string(a(i).(t{1}).String), string(b(i).(t{1}).String)) || ~isequal(a(i).(t{1}).FontSize, b(i).(t{1}).FontSize)
            ok = false; why = sprintf('axes %d: %s', i, t{1}); return
        end
    end
    ka = allchild(a(i));
    kb = allchild(b(i));
    if numel(ka) ~= numel(kb); ok = false; why = sprintf('axes %d: %d vs %d children', i, numel(ka), numel(kb)); return; end
    for j = 1:numel(ka)
        if ~strcmp(class(ka(j)), class(kb(j))) || ~strcmp(ka(j).Tag, kb(j).Tag)
            ok = false; why = sprintf('axes %d: child %d', i, j); return
        end
        for p = {'Color', 'LineWidth', 'FaceColor', 'XData', 'YData', 'Visible', 'LineStyle'}
            if isprop(ka(j), p{1}) && ~isequaln(get(ka(j), p{1}), get(kb(j), p{1}))
                ok = false; why = sprintf('axes %d: child %d (%s) %s', i, j, ka(j).Tag, p{1}); return
            end
        end
    end
end
la = findall(A, 'Type', 'legend');
lb = findall(B, 'Type', 'legend');
if numel(la) ~= numel(lb); ok = false; why = "the legends"; return; end
for i = 1:numel(la)
    if ~isequal(la(i).String, lb(i).String) || any(abs(la(i).Position - lb(i).Position) > 1e-6); ok = false; why = "legend " + i; return; end
end
ca = findall(A, 'Type', 'colorbar');
cb = findall(B, 'Type', 'colorbar');
if numel(ca) ~= numel(cb); ok = false; why = "the color bars"; return; end
px = getpixelposition(A);
for i = 1:numel(ca)
    if any(abs(ca(i).Position - cb(i).Position) .* px([3 4 3 4]) > 1); ok = false; why = "color bar " + i; return; end
end
end


function [ok, n, ep] = marksOnTicks(ax, lat)
%marksOnTicks  Every first-spike mark in AX sits on a tick of its row: a tick at its x whose middle is at its y.
%   N: the marks; EP: their epochs (appdata PlotEpochs, every mark line's); with LAT (a column, [] = not checked) each mark's
%   x is LAT of its epoch.
mk = findall(ax, 'Tag', 'firstSpike');
mk = mk(arrayfun(@(h) any(isfinite(h.XData)), mk));
tk = rasterTickLines(ax);
TX = zeros(0, 1); TY = zeros(0, 1);
for t = reshape(tk, 1, [])
    TX = [TX; reshape(t.XData(1:3:end), [], 1)]; %#ok<AGROW>
    TY = [TY; reshape((t.YData(1:3:end) + t.YData(2:3:end)) / 2, [], 1)]; %#ok<AGROW>
end
ok = ~isempty(mk);
n = 0;
ep = zeros(0, 1);
for h = reshape(mk, 1, [])
    x = h.XData(:);
    y = h.YData(:);
    e = reshape(getappdata(h, 'PlotEpochs'), [], 1);
    n = n + numel(x);
    ep = [ep; e]; %#ok<AGROW>
    for i = 1:numel(x)
        ok = ok && any(abs(TX - x(i)) < 1e-12 & abs(TY - y(i)) < 1e-9);
    end
    if ~isempty(lat); ok = ok && numel(e) == numel(x) && max(abs(lat(e) - x)) < 1e-12; end
end
end


function tk = rasterTickLines(h)
%rasterTickLines  The raster tick lines under H that hold ticks (not the legend's empty swatches).
tk = findall(h, 'Tag', 'rasterTicks');
tk = tk(arrayfun(@(t) ~all(isnan(t.XData(:))), tk));
end


function plantUnits(sortDir, from, to, splitId)
%plantUnits  Rename cluster FROM to TO in a phy folder (spike_clusters.npy and every cluster_*.tsv), then give every
%   other spike of TO to a new cluster SPLITID (same templates: the same peak channel, i.e. a second unit on the site).
f = fullfile(sortDir, 'spike_clusters.npy');
c = readNPY(f);
cls = class(c);
c = double(c);
c(c == from) = to;
mine = find(c == to);
c(mine(2:2:end)) = splitId;
writeNPY(f, cast(c, cls));
for t = reshape(dir(fullfile(sortDir, 'cluster_*.tsv')), 1, [])
    p = fullfile(t.folder, t.name);
    L = splitlines(string(fileread(p)));
    L = L(L ~= "");
    keep = L(1);
    extra = strings(0, 1);
    for i = 2:numel(L)
        parts = split(L(i), sprintf('\t'));
        if str2double(parts(1)) == from
            parts(1) = string(to);
            L(i) = strjoin(parts, sprintf('\t'));
            parts(1) = string(splitId);
            extra(end+1, 1) = strjoin(parts, sprintf('\t')); %#ok<AGROW>
        end
        keep(end+1, 1) = L(i); %#ok<AGROW>
    end
    writelines([keep; extra], p);
end
end


function p = figureTuningParamOf(src)
%figureTuningParamOf  The parameter a tuning panel without param or groupBy tunes over: the first numeric one with two values.
p = "";
for n = reshape(string(src.paramNames), 1, [])
    if n == "TrialType" || ~ismember(n, string(src.trials.Properties.VariableNames)); continue; end
    v = src.trials.(n);
    if (isnumeric(v) || islogical(v)) && numel(unique(double(v(isfinite(double(v)))))) >= 2
        p = n;
        return
    end
end
end


function cfg = setFigures(cfg, f)
cfg.Figures = f;
end


function rmpathQuiet(p)
%rmpathQuiet  Take the folders P (a path string; "" = none) off the MATLAB path, quietly (also when they are already off).
if p == ""; return; end
w = warning('off', 'MATLAB:rmpath:DirNotFound');
restore = onCleanup(@() warning(w));
rmpath(char(p));
end


function rmdirQuiet(root)
if isfolder(root)
    try
        rmdir(root, 's');
    catch
    end
end
end


function r = figureBox(ax, ~)
%figureBox  An axes' plot box in its figure's pixels, [x y w h] (renderFigure places it in pixels on what it draws into).
u = ax.Units;
ax.Units = 'pixels';
r = ax.InnerPosition;
ax.Units = u;
if ~isa(ax.Parent, 'matlab.ui.Figure')
    p = getpixelposition(ax.Parent, true);
    r(1:2) = r(1:2) + p(1:2) - 1;
end
end


function [t, s] = figTitle(h)
%figTitle  The title and subtitle renderFigure gave a figure drawn on its canvas (its hidden titleHost axes').
th = findall(h.layout, 'Type', 'axes', 'Tag', 'titleHost');
t = "";
s = "";
if ~isscalar(th); return; end
t = strjoin(string(th.Title.String), " ");
s = strjoin(string(th.Subtitle.String), " ");
end


function c = arrangeCell(r1, r2, c1, c2, inset)
%arrangeCell  A panel's cell for figureArrange: its rows and columns and its labels' room, at its full size, no band, one axes.
c = struct('r1', r1, 'r2', r2, 'c1', c1, 'c2', c2, 'size', [1 1], 'align', "center", 'valign', "middle", ...
    'inset', inset, 'band', "", 'need', 0, 'shares', 1);
end


function deleteQuiet(f)
%deleteQuiet  Delete file F when it is there.
if isfile(f); delete(f); end
end
