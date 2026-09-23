function src = loadAnalysisSource(out, opts)
%loadAnalysisSource  What one dataset offers for analysis, without its bulk data.
%   SRC = loadAnalysisSource(OUT) takes a DatasetOutputs (or a folder, which
%   becomes DatasetOutputs(folder, CacheData=true)) and reads the small
%   things every analysis needs: the digital events, the paired trials, the
%   recording's rate and duration, which signals / spikes / units exist and
%   the probe map. No signal (Y) and no spike times are loaded; selectUnits
%   and selectChannels load those through SRC.outputs when a plot needs
%   them.
%
%   SRC fields
%     name, key         dataset name; key (Key= option, else the name)
%     folder            the dataset's output folder
%     outputs           the DatasetOutputs
%     fs, durationSec   recording rate and length (the manifest's metadata,
%                       else the extract: info.origFs and info.<SIG>.nSamples
%                       / Fs, else the pairing), NaN when unknown. Rates and
%                       counts use durationSec, never the time of the last
%                       spike. fs is also the rate the digital-event times
%                       count rows of (t = row/fs), which epochTable uses to
%                       place events on the clock of the signals and spikes
%     events            struct: line -> [k x 2] [t_on t_off] s, t = row/Fs,
%                       polarity applied (from the extract; struct() when
%                       there is none)
%     invertedLines     lines whose polarity was inverted
%     lines             table: Line, Count, MeanDurationSec, First, Last,
%                       Inverted
%     labels            amplifier channel labels (extract info.labels)
%     signals           struct LFP / MUA / SPIKE / AUX -> logical: extract
%                       file present
%     signalFs          struct: signal -> Hz (from the extract's
%                       importOptions / info; NaN when not known yet)
%     hasBehavior       a behavior file (or Epsych2 session) was found
%     hasTrials         the behavior carries the pairing (TrialOnset, ...)
%     nTrials, trials   behavior.trials (text columns as string)
%     pairing           behavior.pairing ([] without pairing): status,
%                       trialLine, invertedLines, Fs, signalFs, countMismatch
%     paramNames        the Epsych2 parameters (behavior.info.WriteParams
%                       that are trial columns, else the non-bookkeeping
%                       columns)
%     respField         "RespCode" | "ResponseCode" | ""
%     trialLine         the pairing's trial line ("" without pairing)
%     subject, startTime   from the behavior ("" / NaT without)
%     probe, probeFile  the probe map (decoded JSON: chanMap 0-based, xc, yc,
%                       kcoords) from the manifest's probe.file, or []
%     hasUnits, unitsFrom   sorted units exist: "spikes" (the spikes file's
%                       units, preferred) | "sorting" (the sorting folder) | ""
%     hasDetected       the spikes file holds threshold detections
%     spikesFile        the spikes file ("" when none)
%
%   See also DatasetOutputs, selectTrials, resolveEvents, epochTable,
%   selectUnits, selectChannels.

arguments
    out
    opts.Key (1,1) string = ""
end

if isstring(out) || ischar(out)
    out = DatasetOutputs(string(out), CacheData=true);
elseif ~isa(out, 'DatasetOutputs')
    error('loadAnalysisSource:BadSource', 'Pass a DatasetOutputs or an output folder.');
end

src = struct();
src.name = out.Name;
src.key = opts.Key;
if src.key == ""; src.key = out.Name; end
if ~isempty(out.Dataset)
    src.folder = string(out.Dataset.outputFolder());
else
    src.folder = out.Folder;
end
src.outputs = out;

% --- manifest: rate, duration, probe --------------------------------------------
m = struct();
if out.has("manifest")
    try
        m = out.Manifest;
    catch
    end
end
src.fs = NaN;
src.durationSec = NaN;
if isfield(m, 'metadata') && isstruct(m.metadata)
    src.fs = numOr(m.metadata, 'fs', NaN);
    src.durationSec = numOr(m.metadata, 'duration_s', NaN);
end
src.probeFile = "";
src.probe = [];
if isfield(m, 'probe') && isstruct(m.probe) && isfield(m.probe, 'file')
    pf = string(m.probe.file);
    if pf ~= "" && isfile(pf)
        src.probeFile = pf;
        src.probe = readJsonFile(pf, ErrorOnFail=false);
    end
end

% --- extract: events, labels, signal rates (the smallest file's info) -----------
sigs = DatasetOutputs.SignalTypes;
src.signals = cell2struct(num2cell(false(1, numel(sigs))), cellstr(sigs), 2);
src.signalFs = cell2struct(num2cell(NaN(1, numel(sigs))), cellstr(sigs), 2);
src.events = struct();
src.invertedLines = string.empty(1, 0);
src.labels = string.empty(0, 1);
files = string.empty(1, 0);
for sig = sigs
    f = out.signalFile(sig);
    if ~isempty(f)
        src.signals.(sig) = true;
        files(end+1) = f; %#ok<AGROW>
    end
end
files = unique(files, 'stable');
if ~isempty(files)
    bytes = arrayfun(@(f) fileBytes(f), files);
    [~, smallest] = min(bytes);
    f = files(smallest);
    L = load(f, 'info', 'events');
    if isfield(L, 'events') && isstruct(L.events)
        src.events = L.events;
    end
    if isfield(L, 'info') && isstruct(L.info)
        I = L.info;
        if isfield(I, 'invertedLines'); src.invertedLines = reshape(string(I.invertedLines), 1, []); end
        if isfield(I, 'labels'); src.labels = reshape(string(I.labels), [], 1); end
        if isnan(src.fs) && isfield(I, 'origFs'); src.fs = double(I.origFs); end
        if isfield(I, 'importOptions') && isstruct(I.importOptions)
            o = I.importOptions;
            src.signalFs.LFP = numOr(o, 'LFP_Fs', NaN);
            src.signalFs.MUA = numOr(o, 'MUA_Fs', NaN);
            src.signalFs.SPIKE = numOr(o, 'SPIKE_Fs', NaN);
        end
        for sig = sigs
            if isfield(I, sig) && isstruct(I.(sig)) && isfield(I.(sig), 'Fs')
                src.signalFs.(sig) = double(I.(sig).Fs);
                if isnan(src.durationSec) && isfield(I.(sig), 'nSamples')
                    src.durationSec = double(I.(sig).nSamples) / double(I.(sig).Fs);
                end
            end
        end
    end
end
for sig = sigs
    if ~src.signals.(sig); src.signalFs.(sig) = NaN; end
end

% --- behavior ---------------------------------------------------------------------
src.hasBehavior = false;
src.hasTrials = false;
src.trials = table();
src.nTrials = 0;
src.pairing = [];
src.paramNames = string.empty(1, 0);
src.respField = "";
src.trialLine = "";
src.subject = "";
src.startTime = NaT;
if out.has("behavior")
    B = out.Behavior;
    src.hasBehavior = true;
    T = textToString(B.trials);
    src.trials = T;
    src.nTrials = height(T);
    vars = string(T.Properties.VariableNames);
    if isfield(B, 'pairing') && ~isempty(B.pairing) && ismember("TrialOnset", vars)
        src.pairing = B.pairing;
        src.hasTrials = true;
        if isfield(B.pairing, 'trialLine'); src.trialLine = string(B.pairing.trialLine); end
        if isnan(src.fs) && isfield(B.pairing, 'Fs'); src.fs = double(B.pairing.Fs); end
        if isnan(src.durationSec) && isfield(B.pairing, 'nSamples') && isfield(B.pairing, 'Fs')
            src.durationSec = double(B.pairing.nSamples) / double(B.pairing.Fs);
        end
        if isempty(src.invertedLines) && isfield(B.pairing, 'invertedLines')
            src.invertedLines = reshape(string(B.pairing.invertedLines), 1, []);
        end
    end
    for f = ["RespCode" "ResponseCode"]
        if ismember(f, vars); src.respField = f; break; end
    end
    wp = string.empty(1, 0);
    if isfield(B, 'info') && isstruct(B.info) && isfield(B.info, 'WriteParams')
        wp = reshape(string(B.info.WriteParams), 1, []);
    end
    wp = wp(ismember(wp, vars));
    if isempty(wp)
        book = ["TrialIndex" "TrialID" "computerTimestamp" "isTest" "RespCode" "ResponseCode" ...
            "TrialInterval" "TrialOnset" "TrialOffset" "TrialOnsetSample" "TrialOffsetSample" ...
            "PairingFlag" "TrialEvents" "TrialEventSamples"];
        wp = vars(~ismember(vars, book) & ~startsWith(vars, "TrialOnsetSample_") & ~startsWith(vars, "TrialOffsetSample_"));
    end
    src.paramNames = wp;
    if isfield(B, 'subject'); src.subject = string(B.subject); end
    if isfield(B, 'startTime') && isdatetime(B.startTime); src.startTime = B.startTime; end
end

% --- lines table ----------------------------------------------------------------------
src.lines = linesTable(src.events, src.invertedLines);

% --- spikes / units -----------------------------------------------------------------------
src.spikesFile = "";
src.hasDetected = false;
src.hasUnits = false;
src.unitsFrom = "";
if out.has("spikes")
    src.spikesFile = string(out.SpikesFile);
    w = whos('-file', src.spikesFile);
    names = string({w.name});
    nonEmpty = @(v) any(names == v) && prod(w(names == v).size) > 0;
    src.hasDetected = nonEmpty("detected");
    if nonEmpty("units")
        src.hasUnits = true;
        src.unitsFrom = "spikes";
    end
end
if ~src.hasUnits && out.has("sorting")
    src.hasUnits = true;
    src.unitsFrom = "sorting";
end
end


function v = numOr(s, f, d)
v = d;
if isfield(s, f) && ~isempty(s.(f))
    x = s.(f);
    if isstring(x) || ischar(x); x = str2double(x); end
    if isnumeric(x) && isscalar(x); v = double(x); end
end
end


function b = fileBytes(f)
d = dir(f);
b = Inf;
if ~isempty(d); b = d(1).bytes; end
end


function T = textToString(T)
%textToString  cellstr / char columns as string, so filters compare with ==.
for v = string(T.Properties.VariableNames)
    x = T.(v);
    if iscellstr(x) || ischar(x) %#ok<ISCLSTR>
        T.(v) = string(x);
    end
end
end


function L = linesTable(events, inverted)
%linesTable  One row per digital line: counts, durations and extent.
names = string(fieldnames(events));
n = numel(names);
Count = zeros(n, 1); MeanDurationSec = NaN(n, 1); First = NaN(n, 1); Last = NaN(n, 1);
for k = 1:n
    iv = double(events.(names(k)));
    Count(k) = size(iv, 1);
    if Count(k) > 0
        MeanDurationSec(k) = mean(iv(:, 2) - iv(:, 1));
        First(k) = iv(1, 1);
        Last(k) = iv(end, 1);
    end
end
Line = names;
Inverted = ismember(names, inverted);
L = table(Line, Count, MeanDurationSec, First, Last, Inverted);
end
