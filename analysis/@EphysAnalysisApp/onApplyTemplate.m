function onApplyTemplate(obj, name, opts)
%onApplyTemplate  Copy a figure template's settings into figures picked in a window, or add it as a new figure.
%   The Figures tab's template row: Apply... applies the template picked
%   in the Template list (FigureTemplate) after a modal window
%   (private/applyTemplateDialog) that lists every figure of the config
%   with a check box (the figure shown ticked), the parts of a figure's
%   settings (figureSettingParts: Observations, Alignment, Arrangement and
%   panels, Panel settings, Appearance, Remembered looks, Across
%   sessions; all ticked) and "Also add it as a new figure" (ticked when
%   the config has no figure).
%   Into the figures ticked it copies the parts ticked as Copy settings
%   does (copyFigureSettings: the template's figure is the one copied from;
%   Arrangement and panels gives the grid with every panel as the
%   template has them, Panel settings each panel's to the panels that take
%   them), but the template's remembered looks replace a figure's own
%   rather than adding to them: the figure is to look as the template
%   does. Each figure keeps its id (an automatic one follows its new
%   panels), title and enabled. A new figure is the whole template, with
%   an automatic id, and is selected.
%   It is one step of the undo history ("Apply template Lab card to 3
%   figures"). The figure shown is drawn again when it changed (Auto), as
%   after any edit; the other figures changed are marked out of date in
%   the tree (amber), as Copy settings does. The copy is made once: a
%   template changed later reaches a figure only when it is applied again.
%   What reading the template reported (FigureTemplate's notes: a field
%   the code no longer knows, a newer version) is said on the status bar
%   and in the Log tab.
%
%   For scripts and tests, NAME names the template (default: the one
%   picked), and To=IDS (figure ids), New=true (as a new figure) and
%   Parts=PARTS (figureSettingParts' Part names; default every one) skip
%   the window.
arguments
    obj (1,1) EphysAnalysisApp
    name (1,1) string = string(missing)
    opts.To string = string(missing)
    opts.New = []
    opts.Parts string = string(missing)
end
if ismissing(name); name = string(obj.FigureTemplateDropDown.Value); end
if name == ""
    obj.setStatus("Apply template: you have no template yet: Save as... keeps the figure shown as one, Import... adds a file.");
    return
end
try
    t = FigureTemplate.load(name);
catch ME
    obj.setStatus("Apply template: " + string(ME.message));
    return
end
cfg = obj.gatherConfig();
k = obj.SelectedFigure;
allParts = reshape(figureSettingParts().Part, 1, []);
script = ~all(ismissing(opts.To)) || ~isempty(opts.New);
if ~script
    [pick, ok] = applyTemplateDialog(obj.Fig, t, cfg.Figures, k);
    if isvalid(obj.Fig); figure(obj.Fig); end
    if ~ok; return; end
    targets = pick.Targets;
    isNew = pick.New;
    parts = pick.Parts;
else
    targets = zeros(1, 0);
    if ~all(ismissing(opts.To))
        targets = arrayfun(@(id) cfg.figureIndex(id), reshape(opts.To, 1, []));
        if any(targets < 1)
            obj.setStatus("Apply template: there is no figure """ + opts.To(find(targets < 1, 1)) + """.");
            return
        end
    end
    isNew = ~isempty(opts.New) && logical(opts.New);
    parts = allParts;
    if ~all(ismissing(opts.Parts)); parts = reshape(opts.Parts, 1, []); end
    bad = setdiff(parts, allParts);
    if ~isempty(bad)
        obj.setStatus("Apply template: """ + bad(1) + """ is not a part of a figure's settings (" + strjoin(allParts, ", ") + ").");
        return
    end
end
targets = unique(targets, 'stable');
if isempty(targets) && ~isNew
    obj.setStatus("Apply template: no figure ticked.");
    return
end

tfig = FigureTemplate.figureOf(t);
F = cfg.Figures;
n = numel(F);
changed = zeros(1, 0);
if ~isempty(targets) && ~isempty(parts)
    try
        G = copyFigureSettings([F tfig], cfg.Defaults, n + 1, targets, parts);
    catch ME
        obj.setStatus("Apply template: " + string(ME.message));
        return
    end
    if ismember("looks", parts)   % the template's looks, not added to the figure's own: it looks as the template does
        for j = targets; G(j).aesthetics = tfig.aesthetics; end
    end
    G = G(1:n);
    changed = targets(arrayfun(@(j) ~isequaln(G(j), F(j)), targets));
    cfg.Figures = G;   % (normalized: an automatic id follows)
end
if isNew
    if ~isempty(changed); trackFigureIds(obj, cfg); end   % an automatic id that followed the copy (applyConfig looks at as many figures only)
    try
        cfg = cfg.addFigure(tfig);
    catch ME
        obj.setStatus("Apply template: " + string(ME.message));
        return
    end
end
if isempty(changed) && ~isNew
    obj.setStatus("Apply template: the figures ticked have the settings of " + t.name + " already.");
    return
end

label = "Apply template " + t.name;
what = strings(1, 0);
if isscalar(changed); what(end+1) = "to " + cfg.Figures(changed).id; elseif ~isempty(changed); what(end+1) = sprintf("to %d figures", numel(changed)); end
if isNew; what(end+1) = "as a new figure"; end
label = label + " " + strjoin(what, " and ");
if isNew
    saveFigureEditorState(obj);   % the editor as the figure left had it
    obj.SelectedFigure = numel(cfg.Figures);
    obj.SelectedPanel = 1;
    obj.SelectedLayer = 1;
elseif ismember(k, changed) && ~isequal([string.empty(1, 0) cfg.Figures(k).panels.id], [string.empty(1, 0) F(k).panels.id])
    obj.SelectedPanel = min(1, numel(cfg.Figures(k).panels));   % the figure shown has other panels now
    obj.SelectedLayer = 1;
end
obj.applyConfig(cfg, Action=label);   % one step of the undo history
msg = "Applied template " + t.name;
if ~isempty(changed); msg = msg + " to " + strjoin([string.empty(1, 0) obj.Config.Figures(changed).id], ", "); end
if isNew
    if ~isempty(changed); msg = msg + ", and"; end
    msg = msg + " as the new figure " + obj.Config.Figures(end).id;
end
msg = msg + ".";
if numel(parts) < numel(allParts) && ~isempty(changed)
    T = figureSettingParts();
    msg = msg + " Copied: " + strjoin(T.Label(ismember(T.Part, parts)).', ", ") + ".";
end
if ~isempty(t.notes)
    msg = msg + " Reading the template: " + strjoin(t.notes, "; ") + ".";
    obj.log("Template " + t.name + ": " + strjoin(t.notes, "; "));
end
obj.setStatus(msg);
if isNew || ismember(k, changed)
    obj.autoFigurePreview();   % the figure shown follows as after any edit
else
    markFigureTree(obj);       % the others changed: their kept previews out of date
end
end
