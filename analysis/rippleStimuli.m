function S = rippleStimuli(src, E, ref, stim)
%rippleStimuli  Which TORC or DMR each epoch presented: its stimgen generation record.
%   S = rippleStimuli(SRC, E, REF, STIM) finds, for every epoch of E
%   (epochTable of the dataset SRC, aligned to the eventRef REF), the
%   stimgen generation record of the stimulus it presented, as STIM says
%   (an STRF panel's options.stim, EphysAnalysisConfig.defaults("RippleStim")):
%
%   STIM.source "log": a stimgen presentation log (STIM.file, a
%     stimgen_run_*.mat written by StimPlayer, FormatVersion 1). The k-th
%     onset of REF.line is presentation k of the log: the line's onsets are
%     every interval of the line over the recording, cleaned and filtered as
%     REF says (stitchGapSec, refractorySec, min/maxDurationSec, timeRange
%     in recording time), whatever REF.which and scope pick for the epochs.
%     Refused (rippleStimuli:Count) unless there are as many onsets as
%     presentations, and (rippleStimuli:Timing) unless every interval
%     between two onsets is within STIM.tolerance s of the interval between
%     the two presentations' StimOrderTime. Each epoch is the presentation
%     whose onset is its event (E.t0 - REF.offsetSec, to within half a
%     sample), so REF must align to the line's onsets (edge "onset", no
%     offsetParam, no sequence: rippleStimuli:Ref). Its record is the log's
%     StimRecord of that presentation. STIM.item (a bank item's name or
%     number, "" = every item) keeps the presentations of one bank item.
%   STIM.source "parameter": each epoch's trial holds the variant
%     (combination) index the stimulus played in the trial column
%     STIM.parameter, a positive whole number; STIM.file names where the
%     variant's record comes from: a presentation log (the StimRecord of a
%     presentation of that item and variant), a stimgen bank (.spl: the
%     item regenerated at that variant) or a stimgen.DMR envelope export
%     (DMR.export_envelope: the combination's Record). STIM.item names the
%     bank item of a log or bank ("" = its only item).
%
%   A record that does not carry what makes the envelope -- a TORC logged
%   before stimgen recorded its ripple phases -- is regenerated from the
%   log's bank at the variant played (stimgen.StimType.fromStruct and
%   set_variant_index), and refused unless its variant values and length
%   match the logged record and its Seed is not negative (a negative Seed
%   drew random phases that were never recorded). Regenerating needs
%   stimgen on the MATLAB path (rippleStimuli:NoStimgen); a record logged
%   with everything needs nothing.
%   STIM.file is an absolute path or one relative to the dataset's output
%   folder (SRC.folder).
%
%   S fields
%     records       1 x nU cell: the distinct generation records (stimgen.TORC
%                   or stimgen.DMR, Generated true)
%     kinds         1 x nU "TORC" | "DMR" | "RN" (a DMR record whose
%                   EnvelopeMode is "RippleNoise")
%     index         nE x 1: each epoch's record in records (NaN: none: not a
%                   ripple stimulus, another item, no record, no value)
%     item          nE x 1: each epoch's bank item (NaN: unknown)
%     itemNames     the bank's item names (string row; "" without a bank)
%     presentation  nE x 1: the presentation of the log ("log"; else NaN)
%     variant       nE x 1: the variant index played (NaN: unknown)
%     file          the file read
%     source        STIM.source
%     check         the log's match ("log"; else []): nOnsets, nPresented,
%                   maxIntervalError (s), tolerance (s)
%     dropped       counts of epochs left without a record, by reason:
%                   noPresentation, otherItem, notRipple, noRecord, noValue
%   Errors: rippleStimuli:NoFile, rippleStimuli:BadFile, rippleStimuli:Ref,
%   rippleStimuli:Count, rippleStimuli:Timing, rippleStimuli:Item,
%   rippleStimuli:NoParam, rippleStimuli:NoStimgen,
%   rippleStimuli:Regenerated (a regenerated stimulus that is not the one
%   logged), and resolveEvents' for REF.line.
%
%   See also rippleStrf, epochTable, resolveEvents.

arguments
    src (1,1) struct
    E table
    ref (1,1) struct
    stim (1,1) struct
end

source = string(stim.source);
file = resolveFile(src, string(stim.file));
nE = height(E);
S = struct('records', {{}}, 'kinds', strings(1, 0), 'index', NaN(nE, 1), 'item', NaN(nE, 1), ...
    'itemNames', strings(1, 0), 'presentation', NaN(nE, 1), 'variant', NaN(nE, 1), 'file', file, ...
    'source', source, 'check', [], ...
    'dropped', struct('noPresentation', 0, 'otherItem', 0, 'notRipple', 0, 'noRecord', 0, 'noValue', 0));
w = whos('-file', file);
names = string({w.name});
switch source
    case "log"
        S = fromLog(S, src, E, ref, stim, file, names);
    case "parameter"
        S = fromParameter(S, src, E, stim, file, names);
    otherwise
        error('rippleStimuli:BadFile', 'STIM.source is "log" or "parameter", not "%s".', source);
end
end


function file = resolveFile(src, file)
%resolveFile  The stimulus file: absolute, or relative to the dataset's output folder.
file = strtrim(file);
if file == ""
    error('rippleStimuli:NoFile', 'No stimulus file is named: the panel''s stimulus file is a stimgen presentation log, bank or DMR export.');
end
if ~isAbsolute(file) && isfield(src, 'folder') && string(src.folder) ~= ""
    file = string(fullfile(src.folder, file));
end
if ~isfile(file)
    error('rippleStimuli:NoFile', 'The stimulus file %s does not exist.', file);
end
end


function tf = isAbsolute(p)
c = char(p);
tf = startsWith(p, ["/" "\"]) || (numel(c) >= 2 && c(2) == ':');
end


function S = fromLog(S, src, E, ref, stim, file, names)
%fromLog  Presentation k of the log is the k-th onset of the line; each epoch is the presentation at its event.
if ~all(ismember(["FormatVersion" "StimRecord" "StimOrderTime" "StimOrder" "StimVariant"], names))
    error('rippleStimuli:BadFile', ['%s is not a stimgen presentation log (it lacks FormatVersion, StimRecord, ' ...
        'StimOrderTime, StimOrder or StimVariant).'], file);
end
L = load(file);
if L.FormatVersion ~= 1
    error('rippleStimuli:BadFile', '%s is a presentation log of format version %g; this reads version 1.', file, L.FormatVersion);
end
if string(ref.edge) ~= "onset" || string(ref.offsetParam) ~= "" || (isfield(ref, 'sequence') && ~isempty(ref.sequence))
    error('rippleStimuli:Ref', ['A presentation log is matched to the onsets of the stimulus line: align the panel to ' ...
        'the onset of %s, with no offset parameter and no event sequence.'], ref.line);
end
[S.itemNames, bank] = bankOf(L);
recs = L.StimRecord(:);
order = double(L.StimOrder(:));
variant = double(L.StimVariant(:));
tLog = double(L.StimOrderTime(:));
nP = numel(recs);

% the line's onsets over the recording, as the event reference cleans and filters them
r2 = ref;
r2.which = "all";
r2.scope = "recording";
r2.offsetSec = 0;
on = sort(resolveEvents(src, eventRef(r2), []));
if numel(on) ~= nP
    error('rippleStimuli:Count', ['%s has %d onsets of %s in its time range but the presentation log %s holds %d ' ...
        'presentations: the k-th onset cannot be taken for presentation k. Narrow the event reference''s time range ' ...
        'to the run''s part of the recording.'], src.name, numel(on), ref.line, file, nP);
end
err = abs(diff(on) - diff(tLog));
worst = 0;
if ~isempty(err)
    [worst, at] = max(err);
    if worst > stim.tolerance
        error('rippleStimuli:Timing', ['Onsets %d and %d of %s are %.4f s apart, presentations %d and %d of %s %.4f s: ' ...
            'they differ by %.4f s, more than the tolerance (%.4g s). The line and the log do not describe the same run.'], ...
            at, at + 1, ref.line, on(at + 1) - on(at), at, at + 1, file, tLog(at + 1) - tLog(at), worst, stim.tolerance);
    end
end
S.check = struct('nOnsets', numel(on), 'nPresented', nP, 'maxIntervalError', worst, 'tolerance', stim.tolerance);

keep = itemIndex(stim.item, S.itemNames, bank, true);
tol = 0.5 / src.fs + 1e-9;
t0 = double(E.t0(:)) - ref.offsetSec;
regen = containers.Map('KeyType', 'char', 'ValueType', 'any');
for e = 1:height(E)
    [d, k] = min(abs(on - t0(e)));
    if isempty(k) || d > tol
        S.dropped.noPresentation = S.dropped.noPresentation + 1;
        continue
    end
    S.presentation(e) = k;
    S.item(e) = order(k);
    S.variant(e) = variant(k);
    if ~isnan(keep) && order(k) ~= keep
        S.dropped.otherItem = S.dropped.otherItem + 1;
        continue
    end
    rec = recs{k};
    if isempty(rec) || ~isstruct(rec) || ~isfield(rec, 'Class')
        S.dropped.noRecord = S.dropped.noRecord + 1;
        continue
    end
    if ~ismember(string(rec.Class), ["stimgen.TORC" "stimgen.DMR"])
        S.dropped.notRipple = S.dropped.notRipple + 1;
        continue
    end
    if ~isComplete(rec)   % logged before stimgen recorded what makes the envelope: regenerate it from the bank
        key = sprintf('%d:%d', order(k), variant(k));
        if ~isKey(regen, key)
            regen(key) = regenerate(bank, order(k), variant(k), file, rec);
        end
        rec = regen(key);
    end
    [S, u] = addRecord(S, rec);
    S.index(e) = u;
end
end


function S = fromParameter(S, src, E, stim, file, names)
%fromParameter  Each epoch's trial names the variant played; the file gives that variant's record.
p = string(stim.parameter);
if p == "" || ~src.hasTrials || ~ismember(p, string(src.trials.Properties.VariableNames))
    error('rippleStimuli:NoParam', '%s: no trial parameter "%s" to read the variant played from.', src.name, p);
end
vals = src.trials.(p);
if ~isnumeric(vals) && ~islogical(vals)
    error('rippleStimuli:NoParam', '%s: the trial parameter "%s" is not numeric: it must hold the variant index played.', src.name, p);
end
vals = double(vals);
if all(ismember(["StimRecord" "StimOrder" "StimVariant"], names))
    kind = "log";
    L = load(file);
    [S.itemNames, bank] = bankOf(L);
elseif all(ismember(["Items" "NItems"], names))
    kind = "bank";
    L = load(file, '-mat');
    bank = L;
    S.itemNames = itemNamesOf(L);
elseif all(ismember(["FormatVersion" "Source" "CombinationVariables"], names))
    kind = "export";
    bank = [];
    S.itemNames = "DMR export";
else
    error('rippleStimuli:BadFile', '%s is not a stimgen presentation log, bank (.spl) or DMR envelope export.', file);
end
item = 1;
if kind ~= "export"; item = itemIndex(stim.item, S.itemNames, bank, false); end
cache = containers.Map('KeyType', 'double', 'ValueType', 'any');
for e = 1:height(E)
    tr = E.trial(e);
    v = NaN;
    if isfinite(tr) && tr >= 1 && tr <= numel(vals); v = vals(tr); end
    if ~(isfinite(v) && v >= 1 && v == round(v))
        S.dropped.noValue = S.dropped.noValue + 1;
        continue
    end
    S.variant(e) = v;
    S.item(e) = item;
    if ~isKey(cache, v)
        switch kind
            case "log"
                k = find(double(L.StimOrder(:)) == item & double(L.StimVariant(:)) == v, 1);
                if isempty(k)
                    rec = regenerate(bank, item, v, file, []);
                else
                    rec = L.StimRecord{k};
                    if isstruct(rec) && isfield(rec, 'Class') && ~isComplete(rec) ...
                            && ismember(string(rec.Class), ["stimgen.TORC" "stimgen.DMR"])
                        rec = regenerate(bank, item, v, file, rec);
                    end
                end
            case "bank"
                rec = regenerate(bank, item, v, file, []);
            case "export"
                var = sprintf('C%04d', v);
                if ~ismember(string(var), names)
                    error('rippleStimuli:BadFile', '%s holds no combination %d (%s).', file, v, var);
                end
                X = load(file, var);
                rec = X.(var).Record;
        end
        cache(v) = rec;
    end
    rec = cache(v);
    if isempty(rec) || ~isstruct(rec) || ~isfield(rec, 'Class')
        S.dropped.noRecord = S.dropped.noRecord + 1;
        continue
    end
    if ~ismember(string(rec.Class), ["stimgen.TORC" "stimgen.DMR"])
        S.dropped.notRipple = S.dropped.notRipple + 1;
        continue
    end
    [S, u] = addRecord(S, rec);
    S.index(e) = u;
end
end


function [names, bank] = bankOf(L)
%bankOf  A presentation log's bank and its item names.
bank = [];
if isfield(L, 'Bank'); bank = L.Bank; end
names = strings(1, 0);
if isfield(L, 'BankNames') && ~isempty(L.BankNames)
    names = reshape(string(L.BankNames), 1, []);
elseif isstruct(bank)
    names = itemNamesOf(bank);
end
end


function names = itemNamesOf(bank)
names = strings(1, 0);
if ~isstruct(bank) || ~isfield(bank, 'Items'); return; end
for k = 1:numel(bank.Items)
    it = bank.Items{k};
    nm = "item " + k;
    if isstruct(it) && isfield(it, 'Name') && string(it.Name) ~= ""; nm = string(it.Name); end
    names(k) = nm; %#ok<AGROW>
end
end


function k = itemIndex(item, names, bank, allowAll)
%itemIndex  The bank item STIM.item names: a number, or a name; "" = every item (ALLOWALL) or the only one.
item = strtrim(string(item));
nItems = numel(names);
if isstruct(bank) && isfield(bank, 'Items'); nItems = max(nItems, numel(bank.Items)); end
if item == ""
    if allowAll; k = NaN; return; end
    if nItems == 1; k = 1; return; end
    error('rippleStimuli:Item', 'The bank holds %d items (%s): name the one the trials presented.', nItems, strjoin(names, ", "));
end
v = str2double(item);
if isfinite(v) && v == round(v) && v >= 1 && v <= nItems
    k = v;
    return
end
k = find(strcmpi(names, item), 1);
if isempty(k)
    error('rippleStimuli:Item', 'The bank has no item "%s" (items: %s).', item, strjoin(names, ", "));
end
end


function tf = isComplete(rec)
%isComplete  A record that carries what makes its envelope (a TORC's ripple list, a DMR's knots).
tf = isfield(rec, 'Generated') && isequal(rec.Generated, true);
if ~tf; return; end
if string(rec.Class) == "stimgen.TORC"
    tf = all(isfield(rec, {'RippleRates' 'RippleDensities' 'RipplePhases' 'RippleAmplitude' 'OctaveAxis'}));
else
    tf = all(isfield(rec, {'Envelope' 'OctaveAxis' 'RateKnotRate' 'RippleKnotRate'}));
end
end


function rec = regenerate(bank, item, v, file, logged)
%regenerate  The record of bank item ITEM at variant V, generated again from the bank (stimgen on the path).
if ~isstruct(bank) || ~isfield(bank, 'Items') || item > numel(bank.Items)
    error('rippleStimuli:BadFile', '%s holds no bank to generate item %d again from.', file, item);
end
if exist('stimgen.StimType', 'class') ~= 8
    error('rippleStimuli:NoStimgen', ['The stimulus of item %d, variant %d must be generated again from the bank, ' ...
        'which needs stimgen on the MATLAB path.'], item, v);
end
it = bank.Items{item};
s = it.StimObj;
if isfield(s, 'ApplyCalibration'); s.ApplyCalibration = false; end   % the envelope does not depend on it
obj = stimgen.StimType.fromStruct(s);
obj.VariantReselectOnUpdate = false;
info = obj.get_variant_info();
if v > max(1, info.NumCombinations)
    error('rippleStimuli:Regenerated', '%s: item %d has %d variant combinations, not %d.', file, item, max(1, info.NumCombinations), v);
end
obj.set_variant_index(v);
rec = obj.generation_record();
if ~isComplete(rec)
    error('rippleStimuli:Regenerated', ['Item %d (%s), variant %d, generated again, carries no envelope: this stimgen ' ...
        'is older than the STRF analysis needs.'], item, string(rec.Class), v);
end
if isfield(rec, 'Seed') && rec.Seed < 0
    error('rippleStimuli:Regenerated', ['Item %d, variant %d was presented with a negative Seed (random phases each ' ...
        'update) and its phases were not logged: what it played cannot be generated again.'], item, v);
end
if isstruct(logged) && ~isempty(logged)
    same = isequal(double(logged.N), double(rec.N)) && isequal(double(logged.Fs), double(rec.Fs));
    if same && isfield(logged, 'VariantValues'); same = isequaln(logged.VariantValues, rec.VariantValues); end
    if ~same
        error('rippleStimuli:Regenerated', ['Item %d, variant %d generated again from the bank is not the stimulus ' ...
            'logged (length, rate or variant values differ).'], item, v);
    end
end
end


function [S, u] = addRecord(S, rec)
%addRecord  The index of REC among S.records, adding it when it is new (equal by what makes its envelope).
key = envelopeKey(rec);
for u = 1:numel(S.records)
    if isequal(envelopeKey(S.records{u}), key); return; end
end
S.records{end+1} = rec;
kind = "TORC";
if string(rec.Class) == "stimgen.DMR"
    kind = "DMR";
    if string(rec.EnvelopeMode) == "RippleNoise"; kind = "RN"; end
end
S.kinds(end+1) = kind;
u = numel(S.records);
end


function k = envelopeKey(rec)
%envelopeKey  What makes a record's envelope: two records with equal keys played the same spectrum.
k = struct('Class', string(rec.Class), 'Fs', double(rec.Fs), 'N', double(rec.N), 'OctaveAxis', double(rec.OctaveAxis));
if k.Class == "stimgen.TORC"
    k.RippleRates = double(rec.RippleRates);
    k.RippleDensities = double(rec.RippleDensities);
    k.RipplePhases = double(rec.RipplePhases);
    k.RippleAmplitude = double(rec.RippleAmplitude);
else
    k.GeneratorVersion = rec.GeneratorVersion;
    k.Seed = rec.Seed;
    k.EnvelopeMode = string(rec.EnvelopeMode);
    k.NumEnvelopes = rec.NumEnvelopes;
    k.ErfDivisor = rec.ErfDivisor;
    k.ModulationDepth = rec.ModulationDepth;
    k.RippleDensityRange = rec.RippleDensityRange;
    k.ModulationRateRange = rec.ModulationRateRange;
    k.RippleKnotRate = rec.RippleKnotRate;
    k.RateKnotRate = rec.RateKnotRate;
    k.Envelope = rec.Envelope;
end
end
