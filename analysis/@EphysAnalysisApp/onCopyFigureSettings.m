function onCopyFigureSettings(obj, opts)
%onCopyFigureSettings  Copy a figure's settings, one by one, onto other figures or into a design.
%   The figure list's "Copy settings..." button: a modal window
%   (private/copySettingsDialog) offers From (every figure; the one
%   selected first), a check box tree of its settings (figureSettingItems:
%   the parts Observations, Alignment, Arrangement and panels, Panel
%   settings per panel, Appearance, Remembered looks, Across sessions;
%   their groups; each setting with its value), and Copy to: the figures
%   ticked in a check box list (one or many), a design of yours or a new
%   design. The ticks start as left last time (CopyUnticked, CopyTargets).
%   Onto figures, Copy gives the figures ticked the settings ticked
%   (copyFigureSettings: Apply to figures' changeTargets / applyChanges,
%   a panel's settings to the panels that take them) as one step of the
%   undo history ("Copy settings from <id> to 3 figures"); each keeps its
%   id (an automatic one follows), title and enabled. Nothing is drawn
%   again but the figure shown, when it changed, as after any edit
%   (autoFigurePreview); the other figures changed are marked out of
%   date in the tree (their kept previews: figureViewKey). Into a design,
%   the figure's look (figureLookToDesign: the group colors, the heat
%   colors, the remembered looks ticked) is added to the design (a new
%   one starts from the design chosen now) and saved in your designs
%   folder (PlotDesign.save); the plots are drawn again only when it is
%   the design chosen. The status bar says what was copied.
%
%   For scripts and tests, From=ID (a figure id; default the selected
%   figure), To=IDS (figure ids; default the selected figure) or
%   Design=NAME (a design of yours, made when there is none of that name)
%   skip the window; Settings=KEYS (figureSettingItems' keys or the
%   parts' names; default every one) names what they copy.
arguments
    obj (1,1) EphysAnalysisApp
    opts.From (1,1) string = string(missing)
    opts.Settings string = string(missing)
    opts.To string = string(missing)
    opts.Design (1,1) string = string(missing)
end
k = obj.SelectedFigure;
cfg = obj.gatherConfig();
if k < 1 || k > numel(cfg.Figures)
    obj.setStatus("Copy settings: select a figure first.");
    return
end
script = ~ismissing(opts.From) || ~ismissing(opts.Design) || ~all(ismissing(opts.To));
if ~script
    mine = PlotDesign.list();
    mine = mine.Name(mine.Source == "mine");
    [pick, ok] = copySettingsDialog(obj.Fig, cfg.Figures, k, mine, ...
        struct('Unticked', obj.CopyUnticked, 'Targets', obj.CopyTargets));
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
    obj.CopyUnticked = pick.Unticked;
    obj.CopyTargets = pick.TargetIds;
    from = pick.From;
    keys = pick.Keys;
else
    from = k;
    if ~ismissing(opts.From); from = cfg.figureIndex(opts.From); end
    if from < 1
        obj.setStatus("Copy settings: there is no figure """ + opts.From + """ to copy from.");
        return
    end
    keys = opts.Settings;
    pick = struct('To', "figures", 'Targets', k, 'Design', "", 'New', false);
    if ~ismissing(opts.Design)
        pick.To = "design";
        pick.Design = opts.Design;
        pick.New = ~any(strcmpi(PlotDesign.list().Name, opts.Design));
    elseif ~all(ismissing(opts.To))
        pick.Targets = arrayfun(@(id) cfg.figureIndex(id), reshape(opts.To, 1, []));
        if any(pick.Targets < 1)
            obj.setStatus("Copy settings: there is no figure """ + opts.To(find(pick.Targets < 1, 1)) + """ to copy onto.");
            return
        end
    end
end
src = cfg.Figures(from);
if pick.To == "design"
    toDesign(obj, src, keys, pick.Design, pick.New);
    return
end
try
    [F, changed, copied] = copyFigureSettings(cfg.Figures, cfg.Defaults, from, pick.Targets, keys);
catch ME
    obj.setStatus("Copy settings: " + string(ME.message));
    return
end
if isempty(changed)
    if isempty(copied)
        obj.setStatus("Copy settings: nothing ticked to copy.");
    else
        obj.setStatus("Copy settings: the figures ticked have the " + numel(copied) + " settings of " + src.id + " already.");
    end
    return
end
panelsBefore = [string.empty(1, 0) cfg.Figures(k).panels.id];
cfg.Figures = F;   % (normalized, and an automatic id follows)
n = numel(changed);
label = "Copy settings from " + src.id + " to " + cfg.Figures(changed(1)).id;
if n > 1; label = sprintf("Copy settings from %s to %d figures", src.id, n); end
trackFigureIds(obj, cfg);   % an automatic id that follows the copy
recordFigureEdit(obj, cfg, label);
obj.Config = cfg;
if ~isempty(obj.Runner); obj.Runner.Config = cfg; end
for i = 1:numel(obj.CopyTargets)
    obj.CopyTargets(i) = followedFigureId(obj, obj.CopyTargets(i));   % a figure ticked whose automatic id followed the copy
end
if ~isequal([string.empty(1, 0) cfg.Figures(k).panels.id], panelsBefore)   % the figure shown has other panels now
    obj.SelectedPanel = min(1, numel(cfg.Figures(k).panels));
    obj.SelectedLayer = 1;
end
obj.refreshFigureList();
obj.applyFigureEditor();
obj.refreshFigureObservations();
obj.refreshEpochDiagram();
obj.setStatus(sprintf("Copied %d setting(s) from %s onto %s.", numel(copied), src.id, strjoin([cfg.Figures(changed).id], ", ")));
obj.updateTitle();
if ismember(k, changed)
    obj.autoFigurePreview();   % the figure shown follows as after any edit
else
    markFigureTree(obj);       % the others changed: their kept previews out of date
end
end


function toDesign(obj, fig, keys, name, isNew)
%toDesign  Add figure FIG's look settings KEYS to the design NAME (a new one from the design chosen now), save it.
try
    if isNew
        D = PlotDesign.current();
    else
        D = PlotDesign.load(name);
        if D.source ~= "mine"
            error('PlotDesign:BuiltIn', '"%s" is a built-in design: copy into one of yours, or a new one.', D.name);
        end
    end
    [D, copied] = figureLookToDesign(D, fig, keys);
    if isempty(copied)
        obj.setStatus("Copy settings: " + fig.id + " has no look a design holds among the settings ticked (group colors, heat colors, remembered looks).");
        return
    end
    D.description = string(D.description);
    if isNew; D.description = "Made from " + fig.id + "'s look."; end
    PlotDesign.save(D, name, Overwrite=true);
    name = PlotDesign.checkName(name);
    chosen = strcmpi(PlotDesign.currentName(), name);
    if chosen; PlotDesign.use(name); end   % the design drawn with: the plots follow
catch ME
    obj.setStatus("Copy settings: " + string(ME.message));
    return
end
msg = sprintf("Copied %d setting(s) of %s into design %s", numel(copied), fig.id, name);
if chosen
    msg = msg + ", the design chosen: the plots are drawn in it.";
else
    msg = msg + " (Design list: choose it to draw in it).";
end
obj.setStatus(msg);
end
