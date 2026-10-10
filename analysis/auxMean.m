function A = auxMean(Y, fs, E, opts)
%auxMean  Event-locked mean of aux (accelerometer) channels, or of their vector magnitude.
%   A = auxMean(Y, FS, E, Name=Value) cuts every epoch of E (epochTable)
%   out of the aux signal Y ([nSamples x nChannels], row k at t = (k-1)/FS;
%   selectChannels(src, "AUX"): volts) and averages them per group of E, or
%   over every epoch, with evokedPotential: the same samples, the same
%   onset rule (offset 0 is the sample nearest the one that produced the
%   event) and the same rule for epochs that leave the signal or hold a
%   non-finite sample (dropped and counted). Pure: no I/O, no graphics.
%   A PSTH or raster plot of spikes draws it with each unit's tile
%   (EphysAnalysisRunner.computePlot puts it in R.aux; renderPSTH,
%   renderRaster).
%
%   Options
%     Window    [pre post] s (default [-0.1 0.5])
%     Mode      "channels" (default): each channel's mean; "magnitude": the
%               mean of each epoch's vector magnitude, sqrt of the sum of
%               the squares of the channels at every sample, taken after
%               the baseline subtraction (evokedPotential Magnitude=true).
%               For three accelerometer axes without a baseline it includes
%               the static offsets and gravity; with one, it is the size of
%               the change from each epoch's baseline
%     Baseline  [b0 b1] s: subtract each epoch's mean over this span from
%               each channel first; [] (default) = none
%     ByGroup   true (default): one mean per group of E (Groups); false:
%               one over every epoch, its group "all epochs"
%     Groups    the groups table (epochTable); default from E
%     Meta      the channel table (selectChannels); its units name A.units
%     Check     called before every 16th epoch (evokedPotential's Check)
%     ErrorType, ErrorResamples   the error band around each trace, over
%               the epochs: "sem" (default), "std" or "ci95" (bootstrap,
%               evokedPotential's)
%
%   A: evokedPotential's result -- t, mean / sem [nTime x nTraces x
%   nGroups] (nTraces: the channels, or 1 for the magnitude), labels (one
%   per trace), channelLabels (the channels used), channels, nEpochs,
%   keptEpochs, droppedEdge, droppedNonFinite, groups, units, fs, err, params --
%   with kind "aux", mode and byGroup.
%
%   See also evokedPotential, selectChannels, renderPSTH, renderRaster.

arguments
    Y {mustBeNumeric}
    fs (1,1) double {mustBePositive}
    E table
    opts.Window (1,2) double = [-0.1 0.5]
    opts.Mode (1,1) string {mustBeMember(opts.Mode, ["channels" "magnitude"])} = "channels"
    opts.Baseline double = []
    opts.ByGroup (1,1) logical = true
    opts.Groups = []
    opts.Meta = []
    opts.Check = []
    opts.ErrorType (1,1) string {mustBeMember(opts.ErrorType, ["sem" "std" "ci95"])} = "sem"
    opts.ErrorResamples (1,1) double {mustBePositive, mustBeInteger} = 1000
end

G = opts.Groups;
if ~opts.ByGroup
    E.groupIndex(:) = 1;
    G = table(1, "all epochs", [0.25 0.25 0.25], height(E), 'VariableNames', {'index', 'label', 'color', 'n'});
end
units = "V";
if istable(opts.Meta) && ismember("units", string(opts.Meta.Properties.VariableNames)) && height(opts.Meta) > 0
    units = string(opts.Meta.units(1));
end
A = evokedPotential(Y, fs, E, Window=opts.Window, Baseline=opts.Baseline, Groups=G, Meta=opts.Meta, Units=units, ...
    Magnitude=opts.Mode == "magnitude", Check=opts.Check, ErrorType=opts.ErrorType, ErrorResamples=opts.ErrorResamples);
A.kind = "aux";
A.mode = opts.Mode;
A.byGroup = opts.ByGroup;
end
