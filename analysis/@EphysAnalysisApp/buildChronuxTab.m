function buildChronuxTab(obj)
%buildChronuxTab  The Chronux tab: a dataset's Chronux file, what to analyze, and the plot.
%   Left: the active dataset (the same as the other tabs'), its Chronux
%   file (<Name>_chronux.mat: found in its output folder or the local
%   cache, or missing) with Create (EphysDataset.exportChronux: from the
%   dataset's extract, sorted units and detections) and the local cache
%   folder for datasets whose output folder cannot be written (a share);
%   the signal and its channels, and the file's spike trains (the sorted
%   units or the threshold detections) for the spike analyses. Middle: the
%   analysis and its settings in collapsible sections (formSection) -- Time
%   base (epochs around the Alignment tab's event, or segments of a stretch
%   of the recording), Tapers, Frequency & errors, Moving window, Baseline, Display --
%   each showing the rows the analysis uses (syncChronuxControls). Right:
%   Compute (Chronux, on the active dataset), Cancel, Save figure, Save
%   results, the pages, the plot (renderChronux) and a badge saying where
%   it is (setChronuxState).
%   Edits to what is computed leave the plot Out of date until Compute;
%   edits to Display redraw it (onChronuxEdited).
g = uigridlayout(obj.TabChronux, [1 3]);
g.ColumnWidth = {285, 470, '1x'};
g.Padding = [8 8 8 8];
C = struct();
compute = @(~,~) obj.onChronuxEdited("compute");
display = @(~,~) obj.onChronuxEdited("display");

% --- left: dataset, file, signal and channels ------------------------------------------------
lg = uigridlayout(g, [16 2]);
lg.RowHeight = {22, 26, 22, 64, 30, 22, 36, 30, 26, 22, '1x', 30, 26, 22, '1x', 30};
C.left = lg;   % syncChronuxControls hides the rows the analysis does not use
lg.ColumnWidth = {'1x', '1x'};
lg.Padding = [0 0 0 0];
l = uilabel(lg, "Text", "Active dataset:", "FontWeight", "bold");
place(l, 1, [1 2]);
obj.ChronuxDatasetDropDown = uidropdown(lg, "Items", "(scan first)", "ItemsData", 0, ...
    "ValueChangedFcn", @(dd, ~) obj.selectDataset(dd.Value), ...
    "Tooltip", "The dataset analyzed: the same active dataset as the other tabs'.");
place(obj.ChronuxDatasetDropDown, 2, [1 2]);
l = uilabel(lg, "Text", "Chronux file", "FontWeight", "bold");
place(l, 3, [1 2]);
obj.ChronuxFileLabel = uilabel(lg, "Text", "Scan and pick a dataset.", "WordWrap", "on", "VerticalAlignment", "top", ...
    "FontColor", [0.3 0.3 0.3]);
place(obj.ChronuxFileLabel, 4, [1 2]);
obj.ChronuxCreateButton = uibutton(lg, "Text", "Create Chronux file", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onCreateChronuxExport(), ...
    "Tooltip", "Write <Name>_chronux.mat from the dataset's extract (the Signals step), its sorted units and " + ...
    "threshold detections (EphysDataset.exportChronux, as the pipeline's Export step does) into its output " + ...
    "folder; into the local cache below when that folder cannot be written.");
place(obj.ChronuxCreateButton, 5, 1);
obj.ChronuxOpenFolderButton = uibutton(lg, "Text", "Open folder", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) openFolderOf(obj.ChronuxFile), "Tooltip", "Open the folder holding the Chronux file.");
place(obj.ChronuxOpenFolderButton, 5, 2);
l = uilabel(lg, "Text", "Local cache", "FontWeight", "bold");
place(l, 6, 1);
obj.ChronuxCacheLabel = uilabel(lg, "Text", "not set", "WordWrap", "on", "VerticalAlignment", "top", ...
    "FontColor", [0.3 0.3 0.3], "Tooltip", "Where Chronux files go when a dataset's output folder cannot be " + ...
    "written (a read-only share): <cache>/<dataset key>/<Name>_chronux.mat. Kept between sessions.");
place(obj.ChronuxCacheLabel, 7, [1 2]);
obj.ChronuxCacheButton = uibutton(lg, "Text", "Choose cache...", "ButtonPushedFcn", @(~,~) obj.onChronuxCacheFolder(""), ...
    "Tooltip", "Pick the local folder for Chronux files of datasets whose output folder cannot be written.");
place(obj.ChronuxCacheButton, 8, [1 2]);
l = uilabel(lg, "Text", "Signal:");
place(l, 9, 1);
C.signalLabel = l;
C.signal = uidropdown(lg, "Items", "(none)", "ItemsData", "", "ValueChangedFcn", @(~,~) obj.onChronuxEdited("signal"), ...
    "Tooltip", "The continuous signal analyzed: those the Chronux file holds.");
place(C.signal, 9, 2);
l = uilabel(lg, "Text", "Channels (none picked = all):");
place(l, 10, [1 2]);
C.channelsLabel = l;
C.channels = uilistbox(lg, "Items", {}, "Multiselect", "on", "Value", {}, "ValueChangedFcn", compute, ...
    "Tooltip", "The channels analyzed, each its own spectrum. Ctrl- or Shift-click picks several; none picked = all.");
place(C.channels, 11, [1 2]);
C.allChannels = uibutton(lg, "Text", "All channels", "ButtonPushedFcn", @(~,~) pickAll(obj, C.channels), ...
    "Tooltip", "Clear the pick: every channel.");
place(C.allChannels, 12, [1 2]);
l = uilabel(lg, "Text", "Spikes:");
place(l, 13, 1);
C.spikeLabel = l;
C.spikeSource = uidropdown(lg, "Items", ["Sorted units" "Threshold detections"], "ItemsData", ["units" "detected"], ...
    "ValueChangedFcn", @(~,~) obj.onChronuxEdited("spikeSource"), ...
    "Tooltip", "The spike trains analyzed: the sorted units the Chronux file holds, or its threshold detections (a train per channel).");
place(C.spikeSource, 13, 2);
l = uilabel(lg, "Text", "Spike trains (none picked = all):");
place(l, 14, [1 2]);
C.unitsLabel = l;
C.units = uilistbox(lg, "Items", {}, "Multiselect", "on", "Value", {}, "ValueChangedFcn", compute, ...
    "Tooltip", "The spike trains analyzed, each its own spectrum (a coherence's seed train against each). Ctrl- or " + ...
    "Shift-click picks several; none picked = all.");
place(C.units, 15, [1 2]);
C.allUnits = uibutton(lg, "Text", "All spike trains", "ButtonPushedFcn", @(~,~) pickAll(obj, C.units), ...
    "Tooltip", "Clear the pick: every spike train.");
place(C.allUnits, 16, [1 2]);

% --- middle: the analysis and its settings ---------------------------------------------------
ep = uipanel(g, "Title", "Analysis");
eg = uigridlayout(ep, [8 1]);
eg.RowHeight = [repmat({0}, 1, 7) {'1x'}];
eg.RowSpacing = 6;
eg.Padding = [4 4 4 4];
eg.Scrollable = "on";
obj.ChronuxEditorGrid = eg;
order = ["time" "tapers" "freq" "moving" "baseline" "display"];
hue = turbo(256);
hue = hue(round(linspace(40, 216, numel(order))), :);
tint = @(name) hue(order == name, :);

S = formSection(eg, 1, "general", "");
[S, r] = formRow(S, "analysis", "Analysis:");
C.analysis = uidropdown(S.Body, "Items", ["Power spectrum (mtspectrumc)" "Spectrogram (mtspecgramc)" ...
    "Coherence of two channels (coherencyc)" "Spike spectrum (mtspectrumpt)" ...
    "Spike-field coherence (coherencycpt)" "Spike-train coherence (coherencypt)"], ...
    "ItemsData", ["spectrum" "specgram" "coherence" "spikeSpectrum" "spikeField" "unitCoherence"], ...
    "ValueChangedFcn", @(~,~) obj.onChronuxEdited("analysis"), ...
    "Tooltip", "The Chronux analysis run on the channels or spike trains picked.");
place(C.analysis, r, 2);
[S, r] = formRow(S, "overTime", "");
C.overTime = uicheckbox(S.Body, "Text", "Over time (cohgramc)", "Value", false, "ValueChangedFcn", ...
    @(~,~) obj.onChronuxEdited("analysis"), "Tooltip", "The coherence over time and frequency, over the moving " + ...
    "window, instead of one coherence per pair.");
place(C.overTime, r, [1 2]);
[S, r] = formRow(S, "pairMode", "Pairs:");
C.pairMode = uidropdown(S.Body, "Items", ["the seed with each other one picked" "the seed with its partner"], ...
    "ItemsData", ["seed" "pair"], "ValueChangedFcn", @(~,~) obj.onChronuxEdited("pairMode"), ...
    "Tooltip", "A coherence's pairs: the seed with every other channel (or spike train) picked (none picked: " + ...
    "all), or with one partner.");
place(C.pairMode, r, 2);
[S, r] = formRow(S, "seed", "Seed channel:");
C.seed = uidropdown(S.Body, "Items", "(none)", "ItemsData", 1, "ValueChangedFcn", compute, ...
    "Tooltip", "The channel the coherence is of. It is read even when it is not picked.");
place(C.seed, r, 2);
[S, r] = formRow(S, "partner", "Partner channel:");
C.partner = uidropdown(S.Body, "Items", "(none)", "ItemsData", 2, "ValueChangedFcn", compute, ...
    "Tooltip", "The channel the seed's coherence is with.");
place(C.partner, r, 2);
[S, r] = formRow(S, "unitSeed", "Seed train:");
C.unitSeed = uidropdown(S.Body, "Items", "(none)", "ItemsData", 1, "ValueChangedFcn", compute, ...
    "Tooltip", "The spike train the coherence is of. It is read even when it is not picked.");
place(C.unitSeed, r, 2);
[S, r] = formRow(S, "unitPartner", "Partner train:");
C.unitPartner = uidropdown(S.Body, "Items", "(none)", "ItemsData", 2, "ValueChangedFcn", compute, ...
    "Tooltip", "The spike train the seed's coherence is with.");
place(C.unitPartner, r, 2);
[S, r] = formRow(S, "fieldChannel", "Field channel:");
C.fieldChannel = uidropdown(S.Body, "Items", "(none)", "ItemsData", 1, "ValueChangedFcn", compute, ...
    "Tooltip", "The channel of the signal the spikes are coherent with: its field.");
place(C.fieldChannel, r, 2);
[S, r] = formRow(S, "about", "", 60);
C.about = uilabel(S.Body, "Text", "", "WordWrap", "on", "VerticalAlignment", "top", "FontColor", [0.35 0.35 0.35]);
place(C.about, r, [1 2]);
sec = S;

S = formSection(eg, 2, "time", "Time base", Color=tint("time"));
[S, r] = formRow(S, "timeBase", "Over:");
C.timeBase = uidropdown(S.Body, "Items", ["Epochs around the event (Alignment tab)" "A stretch of the recording"], ...
    "ItemsData", ["aligned" "range"], "ValueChangedFcn", @(~,~) obj.onChronuxEdited("timeBase"), ...
    "Tooltip", "Epochs: the Alignment tab's event and trial selection, a fixed window around each event; the " + ...
    "spectra average over the epochs. A stretch: the recording from / to, cut into segments, each a trial. " + ...
    "Either way, nothing touching an artifact period is used.");
place(C.timeBase, r, 2);
[S, r] = formRow(S, "eventText", "Event:", 36);
C.eventText = uilabel(S.Body, "Text", "", "WordWrap", "on", "VerticalAlignment", "top", ...
    "Tooltip", "The Alignment tab's event reference and trial selection (change them there).");
place(C.eventText, r, 2);
[S, r] = formRow(S, ["pre" "post"], "Window (s):");
wg = subgrid(S.Body, r, {'1x', 'fit', '1x', 'fit'});
C.pre = uieditfield(wg, "numeric", "Value", -0.5, "ValueChangedFcn", compute, "Tooltip", "The window's start, s from the event.");
uilabel(wg, "Text", "to");
C.post = uieditfield(wg, "numeric", "Value", 1, "ValueChangedFcn", compute, "Tooltip", "The window's end, s from the event.");
C.fromAlign = uibutton(wg, "Text", "From Alignment", "ButtonPushedFcn", @(~,~) obj.onChronuxEdited("fromAlign"), ...
    "Tooltip", "Take the Alignment tab's epoch window (a fixed one: Chronux needs epochs of one length).");
[S, r] = formRow(S, "useGroups", "");
C.useGroups = uicheckbox(S.Body, "Text", "One result per trial group (the Alignment tab's)", "Value", true, ...
    "ValueChangedFcn", compute, "Tooltip", "Ticked: each group of the trial selection its own spectrum, in its " + ...
    "color. Unticked: every epoch in one.");
place(C.useGroups, r, [1 2]);
[S, r] = formRow(S, ["from" "to"], "From / to (s):");
rg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.from = uieditfield(rg, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", compute, ...
    "Tooltip", "The stretch's start, s on the recording's clock.");
uilabel(rg, "Text", "to");
C.to = uieditfield(rg, "numeric", "AllowEmpty", "on", "Value", [], "Placeholder", "the end", "Limits", [0 Inf], ...
    "ValueChangedFcn", compute, "Tooltip", "The stretch's end, s (blank: the end of the recording).");
[S, r] = formRow(S, "segment", "Segments (s):");
C.segment = uieditfield(S.Body, "numeric", "Value", 2, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", compute, "Tooltip", "The stretch, clear of artifact periods, is cut into back-to-back " + ...
    "segments this long: the trials the spectra average over (and their tapers' T). What is left at the end of " + ...
    "a clear stretch is not used.");
place(C.segment, r, 2);
[S, r] = formRow(S, "coverage", "", 36);
C.coverage = uilabel(S.Body, "Text", "", "WordWrap", "on", "VerticalAlignment", "top", "FontColor", [0.35 0.35 0.35]);
place(C.coverage, r, [1 2]);
sec(end+1) = S;

S = formSection(eg, 3, "tapers", "Tapers", Color=tint("tapers"));
[S, r] = formRow(S, "taperMode", "Give:");
C.taperMode = uidropdown(S.Body, "Items", ["TW and K" "Half bandwidth W (Hz) and p"], "ItemsData", ["TWK" "Wp"], ...
    "ValueChangedFcn", @(~,~) obj.onChronuxEdited("taperMode"), "Tooltip", "TW and K: Chronux's tapers [TW K] as " + ...
    "given. W and p: the spectra smoothed over +/-W Hz over the trial's length T (a spectrogram's: its moving " + ...
    "window): TW = W*T, K = 2TW - p.");
place(C.taperMode, r, 2);
[S, r] = formRow(S, ["TW" "K"], "TW, K:");
tg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.TW = uieditfield(tg, "numeric", "Value", 3, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", compute, ...
    "Tooltip", "The time-bandwidth product: the spectra are smoothed over +/- TW/T Hz.");
uilabel(tg, "Text", "K");
C.K = uieditfield(tg, "numeric", "Value", 5, "Limits", [1 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", compute, ...
    "Tooltip", "The number of tapers: at most 2TW-1.");
[S, r] = formRow(S, ["W" "p"], "W (Hz), p:");
wpg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.W = uieditfield(wpg, "numeric", "Value", 4, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", compute, ...
    "Tooltip", "The half bandwidth: the spectra are smoothed over +/- W Hz.");
uilabel(wpg, "Text", "p");
C.p = uieditfield(wpg, "numeric", "Value", 1, "Limits", [0 Inf], "RoundFractionalValues", "on", "ValueChangedFcn", compute, ...
    "Tooltip", "K = 2TW - p tapers (1: the most Chronux allows).");
[S, r] = formRow(S, "taperText", "", 22);
C.taperText = uilabel(S.Body, "Text", "", "FontColor", [0.35 0.35 0.35]);
place(C.taperText, r, [1 2]);
sec(end+1) = S;

S = formSection(eg, 4, "freq", "Frequency & errors", Color=tint("freq"));
[S, r] = formRow(S, ["fmin" "fmax"], "Frequencies (Hz):");
fg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.fmin = uieditfield(fg, "numeric", "Value", 0, "Limits", [0 Inf], "ValueChangedFcn", compute, "Tooltip", "fpass: the lowest frequency.");
uilabel(fg, "Text", "to");
C.fmax = uieditfield(fg, "numeric", "AllowEmpty", "on", "Value", 100, "Placeholder", "Nyquist", "Limits", [0 Inf], ...
    "ValueChangedFcn", compute, "Tooltip", "fpass: the highest frequency (blank: half the signal's rate).");
[S, r] = formRow(S, "pad", "Padding:");
C.pad = uispinner(S.Body, "Limits", [-1 4], "Step", 1, "Value", 0, "RoundFractionalValues", "on", "ValueChangedFcn", compute, ...
    "Tooltip", "FFT padding: -1 none, 0 to the next power of two, 1 to twice that, ... (a finer grid of " + ...
    "frequencies, not a finer resolution).");
place(C.pad, r, 2);
[S, r] = formRow(S, ["err" "errP"], "Error bars:");
eg2 = subgrid(S.Body, r, {'1x', 'fit', 60});
C.err = uidropdown(eg2, "Items", ["none" "jackknife" "theoretical"], "Value", "jackknife", "ValueChangedFcn", compute, ...
    "Tooltip", "Jackknife over the tapers and trials, or the theoretical (chi-square) ones.");
uilabel(eg2, "Text", "p:");
C.errP = uieditfield(eg2, "numeric", "Value", 0.05, "Limits", [0 1], "LowerLimitInclusive", "off", "UpperLimitInclusive", "off", ...
    "ValueChangedFcn", compute, "Tooltip", "0.05: 95% confidence bars.");
[S, r] = formRow(S, "detrend", "Detrend:");
C.detrend = uidropdown(S.Body, "Items", ["each trial's mean" "each trial's line" "none"], ...
    "ItemsData", ["constant" "linear" "none"], "Value", "constant", "ValueChangedFcn", compute, ...
    "Tooltip", "Removed from every trial before its spectrum, so the power at 0 Hz does not leak into the low frequencies.");
place(C.detrend, r, 2);
[S, r] = formRow(S, "spikeFs", "Spike grid (Hz):");
C.spikeFs = uieditfield(S.Body, "numeric", "Value", 1000, "Limits", [0 Inf], "LowerLimitInclusive", "off", ...
    "ValueChangedFcn", compute, "Tooltip", "The rate of the grid the spike times are binned on for the spike " + ...
    "spectrum and the spike-train coherence (params.Fs: 1000 is a millisecond; its half is the highest frequency). " + ...
    "Spike-field coherence uses the signals own rate.");
place(C.spikeFs, r, 2);
[S, r] = formRow(S, "fscorr", "");
C.fscorr = uicheckbox(S.Body, "Text", "Finite-size correction", "Value", false, "ValueChangedFcn", compute, ...
    "Tooltip", "Chronuxs correction for the few spikes of a short trial (fscorr), for the spike analyses.");
place(C.fscorr, r, [1 2]);
sec(end+1) = S;

S = formSection(eg, 5, "moving", "Moving window", Color=tint("moving"));
[S, r] = formRow(S, ["mwWin" "mwStep"], "Window, step (s):");
mg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.mwWin = uieditfield(mg, "numeric", "Value", 0.5, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", compute, ...
    "Tooltip", "Each spectrum of the spectrogram is over this long (the tapers' T).");
uilabel(mg, "Text", "step");
C.mwStep = uieditfield(mg, "numeric", "Value", 0.05, "Limits", [0 Inf], "LowerLimitInclusive", "off", "ValueChangedFcn", compute, ...
    "Tooltip", "The window moves on by this much each time.");
sec(end+1) = S;

S = formSection(eg, 6, "baseline", "Baseline", Color=tint("baseline"));
[S, r] = formRow(S, "baseline", "Normalize:");
C.baseline = uidropdown(S.Body, "Items", ["none" "dB change" "% change" "z-score" "ratio"], ...
    "ItemsData", ["none" "db" "percent" "zscore" "ratio"], "ValueChangedFcn", compute, ...
    "Tooltip", "Each frequency against its mean power over the baseline window (z-score: and its SD over it).");
place(C.baseline, r, 2);
[S, r] = formRow(S, ["baseFrom" "baseTo"], "Window (s):");
bg = subgrid(S.Body, r, {'1x', 'fit', '1x'});
C.baseFrom = uieditfield(bg, "numeric", "Value", -0.5, "ValueChangedFcn", compute, "Tooltip", "The baseline's start, s from the event.");
uilabel(bg, "Text", "to");
C.baseTo = uieditfield(bg, "numeric", "Value", 0, "ValueChangedFcn", compute, "Tooltip", "The baseline's end, s from the event.");
sec(end+1) = S;

S = formSection(eg, 7, "display", "Display", Color=tint("display"));
[S, r] = formRow(S, "scale", "Power as:");
C.scale = uidropdown(S.Body, "Items", ["dB" "log axis" "linear"], "ItemsData", ["db" "log" "linear"], ...
    "ValueChangedFcn", display, "Tooltip", "dB: 10 log10 of the power; log axis: the power on a log axis (a " + ...
    "spectrogram: dB); linear.");
place(C.scale, r, 2);
[S, r] = formRow(S, "layout", "Layout:");
C.layout = uidropdown(S.Body, "Items", ["a tile per channel" "a tile per group"], "ItemsData", ["grid" "overlay"], ...
    "ValueChangedFcn", display, "Tooltip", "A tile per channel, the groups overlaid; or a tile per group, the channels overlaid.");
place(C.layout, r, 2);
[S, r] = formRow(S, "showErr", "");
C.showErr = uicheckbox(S.Body, "Text", "Error bars as bands", "Value", true, "ValueChangedFcn", display);
place(C.showErr, r, [1 2]);
[S, r] = formRow(S, "showPhase", "");
C.showPhase = uicheckbox(S.Body, "Text", "Phase under each coherence", "Value", true, "ValueChangedFcn", display, ...
    "Tooltip", "A panel under each coherence tile with its phase, at the frequencies where the coherence is over " + ...
    "the level independent signals stay under.");
place(C.showPhase, r, [1 2]);
[S, r] = formRow(S, "maxTiles", "Tiles per page:");
C.maxTiles = uispinner(S.Body, "Limits", [1 64], "Value", 16, "RoundFractionalValues", "on", "ValueChangedFcn", display);
place(C.maxTiles, r, 2);
[S, r] = formRow(S, "ylim", "Y limits:");
C.ylim = uieditfield(S.Body, "text", "Placeholder", "auto, or e.g. -10 30", "ValueChangedFcn", display, ...
    "Tooltip", "The power axis of a spectrum, low then high, in the units drawn.");
place(C.ylim, r, 2);
[S, r] = formRow(S, "clim", "Color limits:");
C.clim = uieditfield(S.Body, "text", "Placeholder", "auto, or e.g. -3 3", "ValueChangedFcn", display, ...
    "Tooltip", "A spectrogram's color scale, low then high, in the units drawn.");
place(C.clim, r, 2);
sec(end+1) = S;

for i = 2:numel(sec)
    name = sec(i).Name;
    sec(i).Toggle.ButtonPushedFcn = @(~,~) obj.onChronuxSectionToggled(name);
end
obj.ChronuxControls = C;
obj.ChronuxSections = sec;

% --- right: compute, the plot -----------------------------------------------------------------
pg = uigridlayout(g, [3 1]);
pg.RowHeight = {30, '1x', 26};
pg.Padding = [0 0 0 0];
bg = uigridlayout(pg, [1 8]);
bg.ColumnWidth = {110, 80, 'fit', 'fit', '1x', 30, 30, 'fit'};
bg.Padding = [0 0 0 0];
bg.ColumnSpacing = 6;
obj.ChronuxComputeButton = uibutton(bg, "Text", "Compute", "ButtonPushedFcn", @(~,~) obj.onChronuxCompute(), ...
    "Tooltip", "Run the analysis on the active dataset's Chronux file and draw it.");
obj.ChronuxCancelButton = uibutton(bg, "Text", "Cancel", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onCancelChronux(), ...
    "Tooltip", "Stop the analysis (at its next channel).");
obj.ChronuxSaveFigureButton = uibutton(bg, "Text", "Save figure...", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onSaveChronuxFigure(""), "Tooltip", "Save the page shown as a figure file (png, pdf, svg, fig ...).");
obj.ChronuxSaveResultsButton = uibutton(bg, "Text", "Save results...", "Enable", "off", ...
    "ButtonPushedFcn", @(~,~) obj.onSaveChronuxResults(""), "Tooltip", "Save the result (R: spectra, frequencies, " + ...
    "error bars, the Chronux params, trials, settings, provenance) as a .mat file.");
uilabel(bg, "Text", "");
obj.ChronuxPrevPageButton = uibutton(bg, "Text", "<", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onChronuxEdited("pagePrev"));
obj.ChronuxNextPageButton = uibutton(bg, "Text", ">", "Enable", "off", "ButtonPushedFcn", @(~,~) obj.onChronuxEdited("pageNext"));
obj.ChronuxPageLabel = uilabel(bg, "Text", "");
obj.ChronuxPanel = uipanel(pg, "BackgroundColor", "w", "BorderType", "line");
sg = uigridlayout(pg, [1 2], "ColumnWidth", {'fit', '1x'}, "Padding", [0 0 0 0], "ColumnSpacing", 8);
B.Grid = uigridlayout(sg, [1 2], "ColumnWidth", {18, 'fit'}, "Padding", [6 2 10 2], "ColumnSpacing", 5);
B.Icon = uiimage(B.Grid, "ScaleMethod", "fit");
B.Text = uilabel(B.Grid, "FontWeight", "bold");
obj.ChronuxBadge = B;
obj.ChronuxStatusLabel = uilabel(sg, "Text", "Scan and pick a dataset.", "FontColor", [0.35 0.35 0.35]);
obj.syncChronuxControls();
obj.setChronuxState("idle");
end


function pickAll(obj, list)
list.Value = {};
obj.onChronuxEdited("compute");
end


function openFolderOf(file)
if file == ""; return; end
d = fileparts(file);
if isfolder(d); openInSystem(d); end
end


function sg = subgrid(parent, row, widths)
%subgrid  A borderless one-row grid in column 2 of form row ROW.
sg = uigridlayout(parent, [1 numel(widths)]);
sg.ColumnWidth = widths;
sg.Padding = [0 0 0 0];
sg.ColumnSpacing = 6;
place(sg, row, 2);
end


function place(c, row, col)
c.Layout.Row = row;
c.Layout.Column = col;
end
