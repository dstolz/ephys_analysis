function d = latencyDialog(obj, kind)
%latencyDialog  A raster's first-spike latency marks, or a PSTH's latency box plot, in a modal window (the Options' buttons).
%   D = latencyDialog(OBJ, KIND) opens a modal window (WindowStyle
%   "modal", Tag latencyDialog; one at a time) on the panel selected in
%   the Figures tab (OBJ.SelectedFigure, OBJ.SelectedPanel) and returns it:
%     KIND "firstSpike"  "First-spike latency" (a raster panel's
%                        options.firstSpike, the First spike row's
%                        First-spike latency... button)
%     KIND "latencyBox"  "Latency box plot" (a PSTH panel's
%                        options.latencyBox, the Latency box row's Latency
%                        box plot... button)
%   Its rows: the on box (Enabled); Detect from / to (MinMs, MaxMs: the
%   latency window in ms from the aligned event, both ends included; to
%   blank = the window's end, maxSec Inf); then the look. A raster's:
%   Marker and Size, Color ("groups" = each trial group's color, or a color
%   name or #RRGGBB) and Filled. A box plot's: Color, Line (LineStyle,
%   LineWidth: the box's outline and whiskers), Box height (BoxHeight:
%   each box's lane, a share of the PSTH's height), Fill opacity
%   (FillAlpha) and Outliers (OutlierMarker, OutlierSize). The rows under
%   the on box are grayed while it is off.
%   OK gives the panel the settings (the window opened on it, by its
%   figure's and its own id) as one edit, named in the undo history
%   ("First-spike latency", "Latency box plot": commitFigureEdit), and
%   closes the window; a window that ends before it starts is refused,
%   said in the window's note, and the window stays. Cancel closes it,
%   changing nothing. The window's UserData holds its controls (above,
%   with Kind, FigureId, PanelId, Note, Ok, Cancel) for the tests.
%   Nothing opens, and the status line says why, without a panel of the
%   KIND's type selected.
%
%   See also buildFiguresTab, latencySummary, firstSpikeLatency, commitFigureEdit.
arguments
    obj (1,1) EphysAnalysisApp
    kind (1,1) string {mustBeMember(kind, ["firstSpike" "latencyBox"])}
end
delete(findall(groot, 'Type', 'figure', 'Tag', 'latencyDialog'));
d = [];
box = kind == "latencyBox";
type = "raster";
section = "FirstSpike";
name = "First-spike latency";
if box
    type = "psth";
    section = "LatencyBox";
    name = "Latency box plot";
end
k = obj.SelectedFigure;
j = obj.SelectedPanel;
if k < 1 || k > numel(obj.Config.Figures) || j < 1 || j > numel(obj.Config.Figures(k).panels) ...
        || obj.Config.Figures(k).panels(j).type ~= type
    obj.setStatus(name + ": select a " + type + " panel first.");
    return
end
fig = obj.Config.Figures(k);
p = fig.panels(j);
L = EphysAnalysisConfig.normalizeSection(section, p.options.(kind));
id = fig.id;
pid = p.id;
MK = PlotAesthetics.catalog().Marker;

pos = obj.Fig.Position;
nRows = 3 + 2 * box;   % the look's rows
d = uifigure('Name', name + ": " + pid, 'Position', [pos(1) + 160, pos(2) + 160, 460, 250 + 30 * nRows], ...
    'Tag', 'latencyDialog', 'WindowStyle', 'modal');
addlistener(obj.Fig, 'ObjectBeingDestroyed', @(~, ~) delete(d(isvalid(d))));   % it goes with the app
g = uigridlayout(d, [4 + nRows + 1, 1], 'RowHeight', [{'fit', 24, 24} repmat({24}, 1, nRows) {'fit', 36}], ...
    'Padding', [12 12 12 12], 'RowSpacing', 8);
if box
    what = "A box plot of each epoch's first-spike latency, one box per trial group (in each row of a stacked PSTH), " + ...
        "in a band above the traces: the box from the first to the third quartile, a line at the median, whiskers to " + ...
        "the furthest latencies within 1.5 IQR of the box, the others as outliers.";
else
    what = "A mark on each epoch's first spike in the window, on that epoch's row (wherever the raster's sort, " + ...
        "its groups or a block's band put it), over the ticks.";
end
l = uilabel(g, 'WordWrap', 'on', 'Text', what + " The latency is the spike's time from the aligned event, as the " + ...
    "raster draws it; an epoch with no spike in the window has none.");
l.Layout.Row = 1;
r = 2;
onText = "Mark each epoch's first spike";
if box; onText = "Draw the box plot of the first-spike latencies"; end
D.Enabled = uicheckbox(g, 'Text', onText, 'Value', L.enabled, 'ValueChangedFcn', @(~, ~) sync());
D.Enabled.Layout.Row = r;
r = r + 1;
wg = row("Detect from:", {70, 'fit', 70, 'fit', '1x'});
D.MinMs = uieditfield(wg, 'numeric', 'Value', 1000 * L.minSec, 'Tooltip', ...
    "The earliest latency, ms from the aligned event (included; negative: before it).");
uilabel(wg, 'Text', 'to');
D.MaxMs = uieditfield(wg, 'numeric', 'AllowEmpty', 'on', 'Placeholder', 'end', 'Tooltip', ...
    "The latest latency, ms from the event (included). Blank: the panel's window's end.");
if isfinite(L.maxSec); D.MaxMs.Value = 1000 * L.maxSec; else; D.MaxMs.Value = []; end
uilabel(wg, 'Text', 'ms');
colors = ["groups" "black" "red" "blue" "white" "gray" "#d62728" "#ff7f0e"];
colorTip = "groups: each trial group's color (as its ticks and traces); or a color name or #RRGGBB for all.";
if box
    cg = row("Color:", {'1x'});
    D.Color = uidropdown(cg, 'Editable', 'on', 'Items', unique([string(L.color) colors], 'stable'), 'Value', L.color, 'Tooltip', colorTip);
    lg = row("Line:", {'1x', 'fit', 70});
    D.LineStyle = uidropdown(lg, 'Items', ["solid" "dashed" "dotted" "dash-dot"], 'ItemsData', EphysAnalysisConfig.OverlayLineStyles, ...
        'Value', pick(L.lineStyle, EphysAnalysisConfig.OverlayLineStyles, "-"), 'Tooltip', "The box's outline and whiskers.");
    uilabel(lg, 'Text', 'width');
    D.LineWidth = uispinner(lg, 'Limits', [0.25 12], 'Step', 0.25, 'Value', min(12, max(0.25, L.lineWidth)), ...
        'Tooltip', "The box's line width, points (the median's is twice it).");
    hg = row("Box height:", {70, '1x'});
    D.BoxHeight = uispinner(hg, 'Limits', [0.02 0.5], 'Step', 0.02, 'Value', min(0.5, max(0.02, L.boxHeight)), ...
        'Tooltip', "Each box's lane, a share of the PSTH's height: the band above the traces grows by it per box.");
    uilabel(hg, 'Text', "of the PSTH's height");
    fg = row("Fill opacity:", {70, '1x'});
    D.FillAlpha = uieditfield(fg, 'numeric', 'Limits', [0 1], 'Value', min(1, max(0, L.fillAlpha)), ...
        'Tooltip', "The box's fill, 0 (an outline) to 1 (solid; the median is then drawn pale).");
    uilabel(fg, 'Text', '0 = an outline');
    og = row("Outliers:", {'1x', 'fit', 70});
    D.OutlierMarker = uidropdown(og, 'Items', MK.ChoiceLabels, 'ItemsData', MK.Choices, ...
        'Value', pick(L.outlierMarker, MK.Choices, "o"), 'Tooltip', "The marker of the latencies beyond the whiskers (none: not drawn).");
    uilabel(og, 'Text', 'size');
    D.OutlierSize = uispinner(og, 'Limits', [0.5 60], 'Step', 1, 'Value', min(60, max(0.5, L.outlierSize)), ...
        'Tooltip', "The outliers' marker size, points.");
else
    mg = row("Marker:", {'1x', 'fit', 70});
    D.Marker = uidropdown(mg, 'Items', MK.ChoiceLabels(2:end), 'ItemsData', MK.Choices(2:end), ...
        'Value', pick(L.marker, MK.Choices(2:end), "o"), 'Tooltip', "The mark drawn on each epoch's first spike.");
    uilabel(mg, 'Text', 'size');
    D.Size = uispinner(mg, 'Limits', [0.5 60], 'Step', 1, 'Value', min(60, max(0.5, L.size)), 'Tooltip', "The mark's size, points.");
    cg = row("Color:", {'1x'});
    D.Color = uidropdown(cg, 'Editable', 'on', 'Items', unique([string(L.color) colors], 'stable'), 'Value', L.color, 'Tooltip', colorTip);
    fg = row("", {'1x'});
    D.Filled = uicheckbox(fg, 'Text', 'Filled', 'Value', L.filled, 'Tooltip', ...
        "Filled: a solid mark. Unticked: its outline only, the tick showing through.");
end
D.Note = uilabel(g, 'WordWrap', 'on', 'FontColor', [0.35 0.35 0.35], 'Text', "");
D.Note.Layout.Row = r;
bg = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', 100, 100}, 'Padding', [0 0 0 0]);
bg.Layout.Row = r + 1;
uilabel(bg, 'Text', '');
D.Ok = uibutton(bg, 'Text', 'OK', 'ButtonPushedFcn', @(~, ~) apply(), 'Tooltip', "Give the panel these settings, and close the window.");
D.Cancel = uibutton(bg, 'Text', 'Cancel', 'ButtonPushedFcn', @(~, ~) delete(d), 'Tooltip', 'Close the window, changing nothing.');
styleButton(D.Cancel);
styleButton(D.Ok, 'confirm');
D.Kind = kind;
D.FigureId = id;
D.PanelId = pid;
d.UserData = D;
sync();

    function gg = row(label, widths)
        %row  The next row: its label and a grid for its controls (GG).
        rg = uigridlayout(g, [1 2], 'ColumnWidth', {100, '1x'}, 'Padding', [0 0 0 0]);
        rg.Layout.Row = r;
        r = r + 1;
        uilabel(rg, 'Text', label);
        gg = uigridlayout(rg, [1 numel(widths)], 'ColumnWidth', widths, 'Padding', [0 0 0 0]);
    end

    function sync()
        %sync  The rows under the on box grayed while it is off.
        on = matlab.lang.OnOffSwitchState(D.Enabled.Value);
        for f = string(fieldnames(D)).'
            c = D.(f);
            if ismember(f, ["Enabled" "Note" "Ok" "Cancel"]) || ~isa(c, 'matlab.graphics.Graphics') || ~isscalar(c) ...
                    || ~isprop(c, 'Enable')
                continue
            end
            c.Enable = on;
        end
    end

    function apply()
        %apply  The panel the window was opened on takes the settings, as one named edit; a window ending before it starts is refused.
        if ~isvalid(obj) || ~isvalid(obj.Fig); delete(d); return; end
        N = L;
        N.enabled = logical(D.Enabled.Value);
        N.minSec = D.MinMs.Value / 1000;
        N.maxSec = Inf;
        if ~isempty(D.MaxMs.Value); N.maxSec = D.MaxMs.Value / 1000; end
        if N.minSec > N.maxSec
            D.Note.Text = sprintf("The window ends (%g ms) before it starts (%g ms).", 1000 * N.maxSec, 1000 * N.minSec);
            D.Note.FontColor = [0.75 0.1 0.1];
            return
        end
        N.color = strtrim(string(D.Color.Value));
        if N.color == ""; N.color = "groups"; end
        if box
            N.lineStyle = string(D.LineStyle.Value);
            N.lineWidth = D.LineWidth.Value;
            N.boxHeight = D.BoxHeight.Value;
            N.fillAlpha = D.FillAlpha.Value;
            N.outlierMarker = string(D.OutlierMarker.Value);
            N.outlierSize = D.OutlierSize.Value;
        else
            N.marker = string(D.Marker.Value);
            N.size = D.Size.Value;
            N.filled = logical(D.Filled.Value);
        end
        cfg = obj.gatherConfig();
        fid = followedFigureId(obj, id);   % renamed since the window opened (an automatic id that followed an edit)
        q = cfg.figureIndex(fid);
        kp = [];
        if q >= 1 && ~isempty(cfg.Figures(q).panels); kp = find([cfg.Figures(q).panels.id] == pid, 1); end
        if isempty(kp)
            obj.setStatus(name + ": there is no panel " + pid + " in " + fid + " any more.");
            delete(d);
            return
        end
        cfg.Figures(q).panels(kp).options.(kind) = N;
        commitFigureEdit(obj, cfg, pid + ": " + lower(extractBefore(name, 2)) + extractAfter(name, 1) + " " + ...
            latencySummary(N, kind) + ".", Action=name);
        delete(d);
    end
end


function v = pick(v, allowed, default)
v = string(v);
if ~ismember(v, allowed); v = default; end
end
