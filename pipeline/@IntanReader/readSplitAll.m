function data = readSplitAll(obj, opts)
%readSplitAll  readData implementation for the split Intan recording formats.
%   DATA = ds.readSplitAll(opts) reads a "one-file-per-signal" or "one-file-per-
%   channel" recording into the SAME output struct shape produced by
%   EphysDataset.readData for the traditional format, so callers do not care
%   which layout a folder uses. readData delegates here whenever the recording is
%   not traditional; see readData for the option and field documentation.
%
%   The amplifier data are read one streamPlan window at a time into a
%   matrix of the requested Precision that holds only KeepChannels, so the
%   whole recording is never held in double; the digital inputs are decoded
%   window by window too (splitDigitalEvents).
%
%   Supported per layout
%   --------------------
%     amplifier (microvolts) and digital-input events are read for BOTH split
%     layouts. Board ADC and aux input are read only for one-file-per-signal
%     (the well-defined analogin.dat / auxiliary.dat); for one-file-per-channel
%     they return [] (the per-channel ADC/aux files are not yet mapped). Digital
%     events for one-file-per-channel are read from each line's
%     board-<native name>.dat (RHX) or board-DIN-<nn>.dat file; a line without
%     either is left out with a warning (see splitLayout).
%
%   See also EphysDataset.readData, EphysDataset.splitLayout,
%   EphysDataset.readSplitWindow.

arguments
    obj (1,1) IntanReader
    opts.Files (1,:) string = string.empty(1,0)  %#ok<INUSA> (no per-file split units)
    opts.KeepChannels (1,:) double {mustBeInteger, mustBePositive} = []
    opts.IncludeADC (1,1) logical = false
    opts.IncludeAux (1,1) logical = false
    opts.Concatenate (1,1) logical = true
    opts.ProgressFcn = []
    opts.Precision (1,1) string {mustBeMember(opts.Precision, ["double", "single"])} = "double"
end

if isnan(obj.Fs) || isempty(obj.PerFile)
    obj.refreshMetadata();
end
L  = obj.splitLayout();
Fs = L.Fs;

if ~isempty(opts.ProgressFcn)
    opts.ProgressFcn(1, 1, "info.rhd");
end

% --- Amplifier: streamPlan windows into one matrix of KeepChannels ----------
keep = opts.KeepChannels;
if ~isempty(keep) && max(keep) > L.nChan
    error('IntanReader:readSplitAll:BadKeepChannels', ...
        'KeepChannels references channel %d but recording has %d.', ...
        max(keep), L.nChan);
end
if isempty(keep)
    cols = 1:L.nChan;
    channelNames = L.ampCustom;
    nativeNames  = L.ampNative;
else
    cols = keep;
    channelNames = L.ampCustom(keep);
    nativeNames  = L.ampNative(keep);
end
X = zeros(L.nSamp, numel(cols), opts.Precision);
nSamp = 0;
for c = obj.streamPlan()
    W = obj.readSplitWindow(c.sampleOffset, c.nSamples);   % [got x nChan], microvolts
    X(nSamp + (1:size(W, 1)), :) = W(:, cols);
    nSamp = nSamp + size(W, 1);
    if size(W, 1) < c.nSamples; break; end                  % a shorter file ends the data
end
clear W
if nSamp < size(X, 1)
    X = X(1:nSamp, :);
end

% --- Digital-input events -----------------------------------------------------
[events, digInNames, digInNative] = obj.splitDigitalEvents(nSamp);

% --- Optional board ADC / aux (one-file-per-signal only) ----------------------
boardADC = [];
aux      = [];
auxFs    = NaN;
auxNames = string.empty(1, 0);
auxNative = string.empty(1, 0);
if opts.IncludeADC
    boardADC = readSplitADC(L, nSamp);
end
if opts.IncludeAux
    [aux, auxFs] = readSplitAux(L, nSamp);
    if ~isempty(aux)
        auxNames  = L.auxCustom;
        auxNative = L.auxNative;
    end
end

% --- Assemble (identical fields/orientation to readData) ----------------------
if opts.Concatenate
    amplifier = X;
    t = (0:nSamp-1).' / Fs;
else
    amplifier = {X};
    t = [];
end

data = struct();
data.amplifier        = amplifier;
data.Fs               = Fs;
data.t                = t;
data.channelNames     = channelNames;
data.nativeNames      = nativeNames;
if isempty(keep)
    data.channelOrder = 1:numel(channelNames);
else
    data.channelOrder = keep;
end
data.events           = events;
data.digInNames       = digInNames;
data.digInNativeNames = digInNative;
data.boardADC         = boardADC;
data.aux              = aux;
data.auxFs            = auxFs;
data.auxNames         = auxNames;
data.auxNativeNames   = auxNative;
data.files            = obj.Files;
data.fileSampleCounts = nSamp;
data.units            = "microvolts";
data.source           = struct('Folder', obj.Folder, 'Name', obj.Name);
end


% =========================================================================
function adc = readSplitADC(L, nSamp)
%readSplitADC  Board ADC (volts), one-file-per-signal only; [] otherwise.
adc = [];
if L.format ~= "one-file-per-signal" || L.numADC <= 0
    return
end
if L.adcFile == "" || ~isfile(L.adcFile)
    return
end
fid = fopen(char(L.adcFile), 'r', 'ieee-le');
if fid < 0; return; end
raw = fread(fid, [L.numADC, nSamp], 'uint16=>double');   % [nADC x n]
fclose(fid);
raw = raw.';                                             % [n x nADC]
if L.boardMode == 1
    adc = 152.59e-6 * (raw - 32768);
elseif L.boardMode == 13
    adc = 312.5e-6 * (raw - 32768);
else
    adc = 50.354e-6 * raw;
end
end


function [aux, auxFs] = readSplitAux(L, nAmpSamp)
%readSplitAux  Aux input (volts), one-file-per-signal only; [] otherwise.
%   The aux inputs are sampled at Fs/4. RHX writes auxiliary.dat at the full
%   amplifier rate (each value held for 4 samples), older writers at Fs/4, so
%   the rate is taken from the sample count relative to the amplifier's.
aux   = [];
auxFs = NaN;
if L.format ~= "one-file-per-signal" || L.numAux <= 0
    return
end
if L.auxFile == "" || ~isfile(L.auxFile)
    return
end
d = dir(char(L.auxFile));
nAuxSamp = floor(d.bytes / (2 * L.numAux));
fid = fopen(char(L.auxFile), 'r', 'ieee-le');
if fid < 0; return; end
raw = fread(fid, [L.numAux, nAuxSamp], 'uint16=>double');
fclose(fid);
aux   = 37.4e-6 * raw.';      % [n x nAux], volts
if nAmpSamp > 0 && abs(nAuxSamp - nAmpSamp) <= 4
    auxFs = L.Fs;
else
    auxFs = L.Fs / 4;
end
end
