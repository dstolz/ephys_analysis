function refreshDatasetInfo(obj)
%refreshDatasetInfo  The Data tab's panes for the active dataset.
%   Files (DatasetOutputs.inventory), digital lines, behavior (subject,
%   trials, pairing, responses), the Epsych2 parameters with their values,
%   sorted units by class and shank, and the size of each signal extract
%   (a signal larger than PreviewMaxMB is previewed only on request).
if isempty(obj.Runner) || obj.ActiveIdx < 1
    obj.MemoryLabel.Text = "No dataset selected.";
    return
end
k = obj.ActiveIdx;
out = obj.Runner.Outputs(k);
try
    src = obj.Runner.source(k);
catch ME
    obj.MemoryLabel.Text = "Cannot read the dataset: " + string(ME.message);
    return
end

% --- signal sizes -------------------------------------------------------------------
parts = strings(1, 0);
big = strings(1, 0);
for sig = DatasetOutputs.SignalTypes
    if ~src.signals.(sig); continue; end
    f = out.signalFile(sig);
    mb = sum(arrayfun(@fileBytes, f)) / 2^20;
    parts(end+1) = sprintf("%s %.0f MB", sig, mb); %#ok<AGROW>
    if mb > obj.PreviewMaxMB; big(end+1) = sig; end %#ok<AGROW>
end
txt = src.name + ": " + ternary(isempty(parts), "no signal extracts", strjoin(parts, ", "));
if isfinite(src.durationSec); txt = txt + sprintf("; %.1f s recorded", src.durationSec); end
if ~isempty(big)
    txt = txt + sprintf(". %s above %g MB: previewed only with the Preview button.", strjoin(big, ", "), obj.PreviewMaxMB);
end
obj.MemoryLabel.Text = txt;

% --- files, lines --------------------------------------------------------------------
I = out.inventory();
obj.InventoryTable.Data = table(I.Kind, I.Exists, I.Source, I.Path, 'VariableNames', {'Kind', 'Exists', 'Source', 'File'});
obj.LinesTable.Data = src.lines;

% --- behavior ---------------------------------------------------------------------------
if ~src.hasBehavior
    obj.BehaviorLabel.Text = "No behavior file: align in recording scope; trials cannot be filtered or grouped.";
    obj.ParamsTable.Data = table();
else
    b = sprintf("%d trials", src.nTrials);
    if src.subject ~= ""; b = src.subject + ", " + b; end
    if src.hasTrials
        b = b + " paired with " + src.trialLine;
        if isstruct(src.pairing) && isfield(src.pairing, 'status'); b = b + " (" + string(src.pairing.status) + ")"; end
        fl = string(src.trials.PairingFlag);
        u = unique(fl);
        b = b + "; " + strjoin(u + " " + arrayfun(@(x) nnz(fl == x), u), ", ");
    else
        b = b + ", not paired with the recording (only recording scope works)";
    end
    if src.respField ~= ""
        [bits, words] = respCodeBits();
        rc = double(src.trials.(src.respField));
        c = arrayfun(@(w) nnz(bitand(rc, bits.(w)) > 0), words);
        b = b + ". Responses: " + strjoin(words(c > 0) + " " + c(c > 0), ", ");
    end
    obj.BehaviorLabel.Text = b;
    p = src.paramNames(:);
    vals = strings(numel(p), 1);
    for j = 1:numel(p)
        v = src.trials.(p(j));
        if iscell(v); v = string(v); end
        if size(v, 2) ~= 1; vals(j) = "(" + size(v, 2) + " values per trial)"; continue; end
        u = unique(v);
        if isnumeric(u); s = compose("%.6g", u); else; s = string(u); end
        vals(j) = strjoin(s(1:min(12, end)), ", ");
        if numel(u) > 12; vals(j) = vals(j) + sprintf(", ... (%d values)", numel(u)); end
    end
    obj.ParamsTable.Data = table(p, vals, 'VariableNames', {'Parameter', 'Values'});
end

% --- units -------------------------------------------------------------------------------
try
    S = reportSummaryTables(src);
    obj.UnitsTable.Data = S.units;
catch
    obj.UnitsTable.Data = table();
end
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end


function b = fileBytes(f)
d = dir(f);
b = 0;
if ~isempty(d); b = d(1).bytes; end
end