function S = reportSummaryTables(src)
%reportSummaryTables  The tables a report shows at the top of a dataset.
%   S = reportSummaryTables(SRC) for a dataset SRC (loadAnalysisSource):
%     recording  Field / Value: name, key, folder, rate, duration, subject,
%                session start, probe, signals, units, detections, pairing
%     lines      the digital lines (SRC.lines)
%     trials     Trials / Count: all, paired "ok", each response word, each
%                PairingFlag (empty without behavior)
%     units      Class / Shank / Units / Spikes: sorted units by class and
%                shank (empty without units)
%     topRates   the ten highest-rate units (else detection channels):
%                label, class, channel, shank, nSpikes, rateHz
%   A table that cannot be made (no units, no behavior) is empty.
%
%   See also addReportDataset, unitSummary, writeHtmlReport.

arguments
    src (1,1) struct
end

f = strings(0, 1); v = strings(0, 1);
    function add(field, value)
        f(end+1, 1) = field; v(end+1, 1) = string(value);
    end
add("Dataset", src.name);
if src.key ~= src.name; add("Key", src.key); end
add("Output folder", src.folder);
add("Recording rate (Hz)", num(src.fs));
add("Duration (s)", num(src.durationSec));
if src.subject ~= ""; add("Subject", src.subject); end
if ~isnat(src.startTime); add("Session start", string(src.startTime, 'yyyy-MM-dd HH:mm:ss')); end
if src.probeFile ~= ""
    [~, pn, pe] = fileparts(src.probeFile);
    add("Probe", pn + pe);
end
sig = DatasetOutputs.SignalTypes;
have = sig(arrayfun(@(s) src.signals.(s), sig));
if isempty(have)
    add("Signals", "none");
else
    add("Signals", strjoin(have + " (" + arrayfun(@(s) num(src.signalFs.(s)), have) + " Hz)", ", "));
end
add("Sorted units", yesNo(src.hasUnits, "from the " + src.unitsFrom + " " + ternary(src.unitsFrom == "spikes", "file", "folder")));
add("Detected spikes", yesNo(src.hasDetected, ""));
if src.hasBehavior
    p = "trials not paired";
    if src.hasTrials
        p = sprintf("%d trials paired with %s", src.nTrials, src.trialLine);
        if isstruct(src.pairing) && isfield(src.pairing, 'status'); p = p + " (" + string(src.pairing.status) + ")"; end
    end
    add("Behavior", p);
else
    add("Behavior", "none");
end
S = struct();
S.recording = table(f, v, 'VariableNames', {'Field', 'Value'});
S.lines = src.lines;

% --- trials --------------------------------------------------------------------
S.trials = table(strings(0, 1), zeros(0, 1), 'VariableNames', {'Trials', 'Count'});
if src.hasBehavior
    T = src.trials;
    rows = {"all", height(T)};
    vars = string(T.Properties.VariableNames);
    if ismember("PairingFlag", vars)
        for fl = unique(string(T.PairingFlag)).'
            rows(end+1, :) = {"PairingFlag " + fl, nnz(string(T.PairingFlag) == fl)}; %#ok<AGROW>
        end
    end
    if src.respField ~= ""
        [bits, words] = respCodeBits();
        rc = double(T.(src.respField));
        for w = words
            rows(end+1, :) = {w, nnz(bitand(rc, bits.(w)) > 0)}; %#ok<AGROW>
        end
    end
    S.trials = cell2table(rows, 'VariableNames', {'Trials', 'Count'});
    S.trials.Trials = string(S.trials.Trials);
end

% --- units ---------------------------------------------------------------------------
S.units = table(strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), 'VariableNames', {'Class', 'Shank', 'Units', 'Spikes'});
S.topRates = table();
U = [];
if src.hasUnits
    try
        U = unitSummary(src, Source="units", Units=struct('classes', string.empty(1, 0)));
    catch
    end
end
if ~isempty(U)
    [g, cls, sh] = findgroups(U.class, U.shank);
    S.units = table(cls, sh, splitapply(@numel, U.nSpikes, g), splitapply(@sum, U.nSpikes, g), ...
        'VariableNames', {'Class', 'Shank', 'Units', 'Spikes'});
elseif src.hasDetected
    try
        U = unitSummary(src, Source="detected");
    catch
    end
end
if ~isempty(U)
    [~, o] = sort(U.rateHz, 'descend');
    o = o(1:min(10, end));
    S.topRates = U(o, {'label', 'class', 'channel', 'shank', 'nSpikes', 'rateHz'});
end
end


function s = num(x)
if isfinite(x); s = string(sprintf('%.6g', x)); else; s = "unknown"; end
end


function s = yesNo(tf, detail)
if tf
    s = "yes";
    if detail ~= ""; s = s + ", " + detail; end
else
    s = "no";
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
