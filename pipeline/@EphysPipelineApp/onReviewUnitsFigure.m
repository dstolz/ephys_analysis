function fig = onReviewUnitsFigure(obj)
%onReviewUnitsFigure  Draw the selected units on their shanks in a new figure, side by side.
%   The Review tab's Plot in new figure button. The units are the rows
%   selected in the units table (Ctrl+click or Shift+click for more), left
%   to right in the order the table shows them; with no row selected, the
%   unit the plots focus on. Each gets a tile drawn as the tab's shank plot
%   draws it (drawUnitOnShank): every sorted channel on its shank at its
%   site, with the spikes, spike count, mean and band chosen above that
%   plot. The figure is a plain MATLAB figure the app leaves alone, to save
%   or export with the figure's own tools. FIG is the figure, empty when
%   there is no unit to draw (the status bar then says why).
%
%   See also EphysPipelineApp.renderReviewUnitShank, EphysPipelineApp.reviewSpikeWaves.

fig = gobjects(0);
R = obj.ReviewData;
if isempty(R)
    obj.setStatus("No sort is loaded.", "Click a dataset in the Datasets table, or Browse... to a sorted-output folder and press Load.");
    return
end
units = selectedUnits(obj, R);
if isempty(units)
    obj.setStatus("Pick one or more units in the units table first.", "Ctrl+click or Shift+click rows to pick more than one.");
    return
end
opts = struct('spikes', obj.ReviewShankSpikesCheckBox.Value, 'mean', obj.ReviewShankMeanCheckBox.Value, ...
    'band', string(obj.ReviewShankBandDropDown.Value));

n = numel(units);
fig = figure('Name', "Units on their shanks: " + strjoin(R.unitLabel(units), ", "), ...
    'NumberTitle', 'off', 'Color', 'w');
scr = get(groot, 'ScreenSize');
if scr(3) > 400 && scr(4) > 400
    fig.Position(3:4) = [min(scr(3) - 80, 60 + 340 * n), min(scr(4) - 160, 780)];
    movegui(fig, 'center');
end
t = tiledlayout(fig, 1, n, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, sprintf("%s sort: %s", EphysDataset.sorterLabel(R.sorter), R.folder), ...
    'Interpreter', 'none', 'FontSize', 10);
notes = strings(0, 1);
hint = "";
for k = 1:n
    ax = nexttile(t);
    chans = unitShankChannels(R, units(k));
    C = struct([]);
    if ~isempty(chans)
        C = obj.reviewSpikeWaves(chans, units(k));
    end
    note = drawUnitOnShank(ax, R, units(k), chans, C, opts);
    if note.text ~= ""
        notes(end + 1) = note.text; %#ok<AGROW>
        if hint == ""; hint = note.hint; end
    end
end
msg = sprintf("Drew %d unit(s) on their shanks in a new figure.", n);
if ~isempty(notes)
    msg = msg + " " + strjoin(notes, " ");
end
obj.setStatus(msg, hint);
end


%% ---------------------------------------------------------------------------
function units = selectedUnits(obj, R)
%selectedUnits  Rows of R for the units table's selected rows, in the order shown.
%   Rows map to units by the cluster id in column 1, never by position; the
%   order is the table's display order (a header click sorts only the
%   display). With no row selected, the focused unit (ReviewSelectedUnit).
tbl = obj.ReviewUnitsTable;
T = tbl.Data;
rows = tbl.Selection;
units = zeros(0, 1);
if iscell(T) && ~isempty(rows)
    if tbl.SelectionType == "cell"
        rows = rows(:, 1);           % [row column] pairs
    else
        rows = rows(:);              % row indices
    end
    rows = unique(rows(rows >= 1 & rows <= size(T, 1)), 'stable');
    ids = cell2mat(T(rows, 1));
    D = tbl.DisplayData;
    if iscell(D) && size(D, 1) == size(T, 1)
        [~, at] = ismember(ids, cell2mat(D(:, 1)));
        [~, order] = sort(at);
        ids = ids(order);
    end
    [found, units] = ismember(ids, R.clusterID);
    units = unique(units(found), 'stable');
end
if isempty(units)
    u = obj.ReviewSelectedUnit;
    if u >= 1 && u <= numel(R.clusterID); units = u; end
end
units = units(:).';
end
