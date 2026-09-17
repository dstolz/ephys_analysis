function refreshNasTable(obj)
%refreshNasTable  Show NasSessions with the Copy ticks, the last copy results and row colours.
%   Unpaired rows are orange, ambiguous rows red (and cannot be ticked); a
%   failed copy result is red, a copied / already present one green.

tbl = obj.NasTable;
if isempty(tbl) || ~isvalid(tbl); return; end
removeStyle(tbl);
T = obj.NasSessions;
if isempty(T)
    T = findNasSessionsEmpty();
end
n = height(T);
if numel(obj.NasTicked) ~= n;     obj.NasTicked = false(n, 1); end
if numel(obj.NasCopyStatus) ~= n; obj.NasCopyStatus = strings(n, 1); end
if numel(obj.NasMessage) ~= n;    obj.NasMessage = strings(n, 1); end

D = table(obj.NasTicked(:), T.Status, leafName(T.IntanDir), timeText(T.IntanTime), ...
    leafName(T.EpsychFile), timeText(T.EpsychTime), deltaText(T.DeltaT), T.DestDir, ...
    obj.NasCopyStatus(:), obj.NasMessage(:), T.Note, ...
    'VariableNames', {'Copy', 'Status', 'Intan folder', 'Intan time', 'ePsych file', 'ePsych time', ...
    'ePsych - Intan', 'Destination', 'Result', 'Message', 'Note'});
tbl.Data = D;
tbl.ColumnEditable = [true, false(1, width(D) - 1)];
tbl.ColumnWidth = {45, 85, 185, 120, 205, 120, 95, 'auto', 105, 'auto', 'auto'};

for k = 1:n
    switch T.Status(k)
        case {"intan_only", "epsych_only"}
            addStyle(tbl, uistyle("BackgroundColor", [1 0.92 0.78]), "row", k);
        case "ambiguous"
            addStyle(tbl, uistyle("BackgroundColor", [1 0.85 0.85]), "row", k);
    end
    switch obj.NasCopyStatus(k)
        case {"copied", "already_present"}
            addStyle(tbl, uistyle("FontColor", [0.1 0.5 0.1], "FontWeight", "bold"), "cell", [k 9]);
        case {"failed", "cancelled"}
            addStyle(tbl, uistyle("FontColor", [0.75 0.1 0.1], "FontWeight", "bold"), "cell", [k 9]);
    end
end

if n == 0
    if isempty(obj.NasSessions)
        obj.NasSummaryLabel.Text = "Enter a subject and dates, then Find sessions.";
    else
        obj.NasSummaryLabel.Text = "No sessions found for these days.";
    end
else
    counts = arrayfun(@(s) nnz(T.Status == s), ["paired", "intan_only", "epsych_only", "ambiguous"]);
    obj.NasSummaryLabel.Text = sprintf("%d paired, %d Intan only, %d ePsych only, %d ambiguous; %d ticked.", ...
        counts, nnz(obj.NasTicked));
end
end


function T = findNasSessionsEmpty()
T = table(strings(0, 1), strings(0, 1), NaT(0, 1), strings(0, 1), NaT(0, 1), duration.empty(0, 1), ...
    strings(0, 1), strings(0, 1), strings(0, 1), 'VariableNames', ...
    {'Subject', 'IntanDir', 'IntanTime', 'EpsychFile', 'EpsychTime', 'DeltaT', 'Status', 'DestDir', 'Note'});
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


function s = deltaText(d)
s = strings(size(d));
ok = ~isnan(d);
s(ok) = string(d(ok), 'mm:ss');
end
