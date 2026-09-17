function refreshCopyTable(obj)
%refreshCopyTable  Show CopySessions with the Copy ticks, the last copy results and row colours.
%   Unpaired rows are orange, ambiguous rows red (and cannot be ticked),
%   stitched rows blue (their ePsych files joined by " + "); a failed copy
%   result is red, a copied / already present one green.

tbl = obj.CopyTable;
if isempty(tbl) || ~isvalid(tbl); return; end
removeStyle(tbl);
T = obj.CopySessions;
if isempty(T)
    T = findCopySessionsEmpty();
end
n = height(T);
if numel(obj.CopyTicked) ~= n;     obj.CopyTicked = false(n, 1); end
if numel(obj.CopyStatus) ~= n; obj.CopyStatus = strings(n, 1); end
if numel(obj.CopyMessage) ~= n;    obj.CopyMessage = strings(n, 1); end

epsych = leafName(T.EpsychFile);
for k = find(T.Status == "stitched").'
    epsych(k) = strjoin(leafName(T.StitchFiles{k}), " + ");
end
D = table(obj.CopyTicked(:), T.Status, leafName(T.IntanDir), timeText(T.IntanTime), durationText(T.IntanDuration), ...
    epsych, timeText(T.EpsychTime), trialsText(T.EpsychTrials), deltaText(T.DeltaT), T.DestDir, ...
    obj.CopyStatus(:), obj.CopyMessage(:), T.Note, ...
    'VariableNames', {'Copy', 'Status', 'Intan folder', 'Intan time', 'Duration', 'ePsych file', 'ePsych time', ...
    'Trials', 'ePsych - Intan', 'Destination', 'Result', 'Message', 'Note'});
resultCol = find(D.Properties.VariableNames == "Result");
tbl.Data = D;
tbl.ColumnEditable = [true, false(1, width(D) - 1)];
tbl.ColumnWidth = {45, 85, 185, 120, 70, 205, 120, 50, 95, 'auto', 105, 'auto', 'auto'};

for k = 1:n
    switch T.Status(k)
        case {"intan_only", "epsych_only"}
            addStyle(tbl, uistyle("BackgroundColor", [1 0.92 0.78]), "row", k);
        case "ambiguous"
            addStyle(tbl, uistyle("BackgroundColor", [1 0.85 0.85]), "row", k);
        case "stitched"
            addStyle(tbl, uistyle("BackgroundColor", [0.86 0.92 1]), "row", k);
    end
    switch obj.CopyStatus(k)
        case {"copied", "already_present"}
            addStyle(tbl, uistyle("FontColor", [0.1 0.5 0.1], "FontWeight", "bold"), "cell", [k resultCol]);
        case {"failed", "cancelled"}
            addStyle(tbl, uistyle("FontColor", [0.75 0.1 0.1], "FontWeight", "bold"), "cell", [k resultCol]);
    end
end

if n == 0
    if isempty(obj.CopySessions)
        obj.CopySummaryLabel.Text = "Enter a subject and dates, then Find sessions.";
    else
        obj.CopySummaryLabel.Text = "No sessions found for these days.";
    end
else
    counts = arrayfun(@(s) nnz(T.Status == s), ["paired", "stitched", "intan_only", "epsych_only", "ambiguous"]);
    obj.CopySummaryLabel.Text = sprintf("%d paired, %d stitched, %d Intan only, %d ePsych only, %d ambiguous; %d ticked.", ...
        counts, nnz(obj.CopyTicked));
end
end


function T = findCopySessionsEmpty()
T = table(strings(0, 1), strings(0, 1), NaT(0, 1), strings(0, 1), NaT(0, 1), duration.empty(0, 1), ...
    strings(0, 1), strings(0, 1), strings(0, 1), duration.empty(0, 1), zeros(0, 1), cell(0, 1), 'VariableNames', ...
    {'Subject', 'IntanDir', 'IntanTime', 'EpsychFile', 'EpsychTime', 'DeltaT', 'Status', 'DestDir', 'Note', ...
    'IntanDuration', 'EpsychTrials', 'StitchFiles'});
end


function s = leafName(p)
s = strings(size(p));
for k = 1:numel(p)
    if p(k) == ""; continue; end
    [~, n, x] = fileparts(p(k));
    s(k) = n + x;
end
end


function s = timeText(t)
s = strings(size(t));
ok = ~isnat(t);
s(ok) = string(t(ok), 'yy-MM-dd HH:mm:ss');
end


function s = durationText(d)
s = strings(size(d));
ok = ~isnan(d);
s(ok) = string(d(ok), 'hh:mm:ss');
end


function s = trialsText(n)
s = strings(size(n));
ok = ~isnan(n);
s(ok) = string(n(ok));
end


function s = deltaText(d)
s = strings(size(d));
ok = ~isnan(d);
s(ok) = string(d(ok), 'mm:ss');
end
