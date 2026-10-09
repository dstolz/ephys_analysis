function setPlotsEnabled(obj, ks, how)
%setPlotsEnabled  Enable or disable plots KS (indices into Config.Plots): the plot tree's check boxes.
%   HOW: "on", "off", "toggle" (each plot of KS to the opposite of what it is)
%   or "only" (KS on, every other plot off). The editor's edits so far are in
%   the config first (gatherConfig); the tree, the editor's Enabled box (for
%   the plot in it) and the title follow. The preview is not redrawn: a
%   plot's being enabled changes the run, not what it draws.
arguments
    obj (1,1) EphysAnalysisApp
    ks (1,:) double
    how (1,1) string {mustBeMember(how, ["on" "off" "toggle" "only"])}
end
cfg = obj.gatherConfig();
n = numel(cfg.Plots);
if n == 0; return; end
ks = ks(ks >= 1 & ks <= n);
was = [cfg.Plots.enabled];
now = was;
switch how
    case "on"
        now(ks) = true;
    case "off"
        now(ks) = false;
    case "toggle"
        now(ks) = ~now(ks);
    case "only"
        now(:) = false;
        now(ks) = true;
end
for k = find(now ~= was)
    cfg.Plots(k).enabled = now(k);
end
obj.Config = cfg;
if ~isempty(obj.Runner)
    obj.Runner.Config = cfg;
end
k = obj.SelectedPlot;
if k >= 1 && k <= n
    obj.PlotEditor.enabled.Value = cfg.Plots(k).enabled;
    obj.ShownPlot = cfg.Plots(k);   % the box now agrees with the config: not an edit for the plots selected with it
end
obj.refreshPlotList();
obj.updateTitle();
obj.setStatus(sprintf("%d of %d plots enabled.", nnz(now), n));
end
