function dlg = pickChannels(obj, where)
%pickChannels  The Probe... window (ProbePickDialog) of a Channels row in the figure editor: shanks and channels picked on the active dataset's probe.
%   DLG = obj.pickChannels(WHERE) (the Probe... button beside a Channels
%   row: probeButton) opens it on the rows WHERE names:
%     "observe"  Observations: a figure of sorted units or detections, its
%                Shanks and On channels (observe.units.shanks, .channels);
%                a figure of a signal's channels, its Signal channels
%                (observe.channels), channels only
%     "layer"    the selected layer, while fixed: a spike layer's Shanks
%                and On channels (units.shanks, .channels), a signal
%                layer's Signal channels (channels), channels only
%     "probe"    Probe layout (a figure on the probe): the Shanks and
%                Channels laid out (probe.shanks, .channels)
%   on the figure's values, the probe of the active dataset drawn (its
%   probe map, src.probe; before a scan none: the fields still take
%   numbers typed). A pick of channels only has no Shanks field: a click on
%   a shank picks every channel of its sites. On OK the pick goes into the
%   rows (numbersText: "1:16 33:48") and the figure, as one edit named
%   after the Channels row (onConfigChanged "figure": undone with Undo; a
%   layer's spread to the other panels selected with it, as a typed edit
%   is). Cancel changes nothing. [] when the figure or layer has no such
%   rows now, or for AUX, which has no probe. With the window open
%   already, that one comes to the front and is returned; it is closed
%   when the editor shows another figure, panel or layer
%   (applyFigureEditor: closeProbePickDialog), so an OK cannot land there.
%   In a script, set the fields themselves:
%     cfg.Figures(k).observe.units.shanks = 2;
%     cfg.Figures(k).observe.channels = 17:32;
%
%   See also ProbePickDialog, ProbePicker, probeButton, closeProbePickDialog.
arguments
    obj (1,1) EphysFigGenApp
    where (1,1) string {mustBeMember(where, ["observe" "layer" "probe"])}
end
dlg = obj.ProbePickWindow;
if ~isempty(dlg) && isvalid(dlg) && dlg.isOpen()
    if dlg.Fig.Visible == "on"; figure(dlg.Fig); end
    return
end
dlg = [];
k = obj.SelectedFigure;
F = obj.Config.Figures;
if k < 1 || k > numel(F); return; end
fig = F(k);
T = struct('Where', where, 'FigureId', fig.id, 'PanelId', "", 'Layer', 0, 'Shanks', "", 'Channels', "");
spikeWord = @(data) ternary(data == "detected", "detection channels", "units");
switch where
    case "observe"
        o = fig.observe;
        switch EphysAnalysisConfig.observeKind(fig)
            case "unit"
                [T.Shanks, T.Channels] = deal("obsShanks", "obsUnitChannels");
                ch = o.units.channels; sh = o.units.shanks;
                names = ["observe.units.channels" "observe.units.shanks"];
                intro = "The " + spikeWord(o.data) + " observed (a figure each): those on the shanks and channels kept.";
            case "channel"
                if o.data == "AUX"; return; end
                T.Channels = "obsChannels";
                ch = o.channels; sh = [];
                names = ["observe.channels" ""];
                intro = "The " + o.data + " channels observed (a figure each).";
            otherwise
                return
        end
        title = "Observations";
    case "layer"
        j = obj.SelectedPanel;
        i = obj.SelectedLayer;
        if j < 1 || j > numel(fig.panels) || i < 1 || i > numel(fig.panels(j).layers); return; end
        p = fig.panels(j);
        L = p.layers(i);
        if L.binding ~= "fixed"; return; end
        if ismember(L.source, EphysAnalysisConfig.SpikeSources)
            [T.Shanks, T.Channels] = deal("layerShanks", "layerUnitChannels");
            ch = L.units.channels; sh = L.units.shanks;
            names = ["units.channels" "units.shanks"];
            intro = "The " + spikeWord(L.source) + " the layer draws: those on the shanks and channels kept.";
        elseif ismember(L.source, EphysAnalysisConfig.SignalSources) && L.source ~= "AUX"
            T.Channels = "layerChannels";
            ch = L.channels; sh = [];
            names = ["channels" ""];
            intro = "The " + L.source + " channels the layer draws.";
        else
            return
        end
        T.PanelId = p.id;
        T.Layer = i;
        title = "Panel " + p.id + ", layer " + layerLabel(L, p.type);
    case "probe"
        if ~fig.probe.enabled; return; end
        [T.Shanks, T.Channels] = deal("prbShanks", "prbChannels");
        ch = fig.probe.channels; sh = fig.probe.shanks;
        names = ["probe.channels" "probe.shanks"];
        intro = "The sites laid out, a tile at each.";
        title = "Probe layout";
end

% the active dataset's probe
probe = [];
dataset = "";
none = "";
if ~isempty(obj.Runner) && obj.ActiveIdx >= 1 && obj.ActiveIdx <= numel(obj.Runner.Keys)
    try
        src = obj.Runner.source(obj.ActiveIdx);
        dataset = string(src.name);
        if isfield(src, 'probe'); probe = src.probe; end
    catch ME
        none = "Cannot read the active dataset";
        obj.setStatus("Cannot read the active dataset for its probe: " + string(ME.message));
    end
end
dlg = ProbePickDialog(ch, sh, Probe=probe, Dataset=dataset, NoProbe=none, Shanks=T.Shanks ~= "", ...
    Title="Pick on the probe: " + fig.id + " > " + title, Intro=intro, ChannelsName=names(1), ShanksName=names(2), ...
    Parent=obj.Fig, Visible=obj.Fig.Visible == "on", OnDone=@(r) applyPick(obj, r));
obj.ProbePickWindow = dlg;
obj.ProbePickTarget = T;
end


function applyPick(obj, r)
%applyPick  The window closed: R (channels, shanks) into the rows it was opened on and the figure, or nothing ([]).
if ~isvalid(obj); return; end
obj.ProbePickWindow = [];
if isempty(r); return; end
T = obj.ProbePickTarget;
if ~probePickShown(obj, T); return; end   % the editor shows another figure, panel or layer now (closeProbePickDialog closes it first; this is the fallback)
E = obj.FigureEditor;
if T.Shanks ~= ""; E.(T.Shanks).Value = char(numbersText(r.shanks)); end
E.(T.Channels).Value = char(numbersText(r.channels));
obj.onConfigChanged("figure", figureEditLabel(obj, E.(T.Channels)));   % one step, named after the Channels row
end


function v = ternary(tf, a, b)
if tf; v = a; else; v = b; end
end
