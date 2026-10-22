function onResetPanelOptions(obj)
%onResetPanelOptions  Edit > Reset panel options to defaults: the selected panel takes its type's default options.
%   The panel selected in the Figures tab gets panelTypes'
%   DefaultOptions of its type, every option (its layers, place, title,
%   axis sides, note and overlays stay), as one edit named "Reset panel
%   options" in the undo history (commitFigureEdit). The options remembered
%   for new panels of that type (obj.PanelOptions, rememberPanelOptions)
%   are forgotten too, so the next new panel of the type starts from the
%   defaults as well; the other types keep theirs (Edit > Forget remembered
%   panel options forgets them all: onForgetPanelOptions). The status bar
%   names the options that changed.
%
%   See also onForgetPanelOptions, onNewPanel, EphysAnalysisConfig.panelTypes.
k = obj.SelectedFigure;
if k < 1 || k > numel(obj.Config.Figures) || obj.SelectedPanel < 1 || obj.SelectedPanel > numel(obj.Config.Figures(k).panels)
    obj.setStatus("Reset panel options: select a panel in the Figures tab first.");
    return
end
j = obj.SelectedPanel;
cfg = obj.gatherConfig();
p = cfg.Figures(k).panels(j);
PT = EphysAnalysisConfig.panelTypes();
row = PT.Type == p.type;
if ~any(row); return; end
def = PT.DefaultOptions{row};
fields = string(fieldnames(def)).';
changed = fields(arrayfun(@(f) ~isfield(p.options, f) || ~isequaln(p.options.(f), def.(f)), fields));
forgot = isfield(obj.PanelOptions, p.type);
if isempty(changed)
    forget(obj, p.type);
    msg = p.id + " has its type's default options already.";
    if forgot; msg = msg + " The options remembered for new " + PT.Label(row) + " panels are forgotten."; end
    obj.setStatus(msg);
    return
end
cfg.Figures(k).panels(j).options = def;
commitFigureEdit(obj, cfg, p.id + ": the " + PT.Label(row) + " defaults again (" + strjoin(changed, ", ") + ...
    "); new " + PT.Label(row) + " panels start from them too.", Action="Reset panel options");
forget(obj, p.type);   % after the edit, which remembered the defaults just set
end


function forget(obj, type)
%forget  No options remembered for new panels of TYPE.
if isfield(obj.PanelOptions, type); obj.PanelOptions = rmfield(obj.PanelOptions, type); end
end
