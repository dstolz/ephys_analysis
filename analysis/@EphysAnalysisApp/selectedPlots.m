function ks = selectedPlots(obj)
%selectedPlots  The plots selected: the one in the editor (previewed) first, then the others as picked.
%   Indices into Config.Plots; empty with no plot in the editor. An edit in
%   the editor goes to every one of them (gatherConfig).
n = numel(obj.Config.Plots);
k = obj.SelectedPlot;
if k < 1 || k > n
    ks = zeros(1, 0);
    return
end
also = obj.AlsoSelected;
ks = [k unique(also(also >= 1 & also <= n & also ~= k), 'stable')];
end
