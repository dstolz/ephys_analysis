function refreshSortingLabel(obj)
%refreshSortingLabel  Describe the active dataset's sorted-output association
%   and what phy did there (refreshPhyStatus).
if isempty(obj.SortResultsLabel) || ~isvalid(obj.SortResultsLabel); return; end
d = obj.currentDataset();
if isempty(d)
    obj.SortResultsLabel.Text = "Scan a project first.";
    refreshPhyStatus(obj, "");
    stylePhyButton(obj.SortPhyButton, "");
    return
end
s = d.sortingStruct();
if s.results_dir == ""
    txt = sprintf("%s: no sorted output yet (auto: %s).", d.Name, d.sortRunDir());
elseif ~s.exists
    txt = sprintf("%s: manual association -> %s\nThat folder is not there now: no other sort stands in for it.", ...
        d.Name, s.results_dir);
else
    cur = "uncurated (cluster_KSLabel.tsv)";
    if isfile(fullfile(s.results_dir, 'cluster_SILabel.tsv'))
        cur = "uncurated (cluster_SILabel.tsv: good / mua by the good-unit criteria)";
    end
    if s.curated; cur = "phy-curated (cluster_group.tsv)"; end
    nU = "?";
    if isfinite(s.num_units); nU = string(s.num_units); end
    txt = sprintf("%s: %s association -> %s\n%s cluster(s), %s", d.Name, s.source, s.results_dir, nU, cur);
end
obj.SortResultsLabel.Text = txt;
dir0 = "";
if s.exists; dir0 = s.results_dir; end
refreshPhyStatus(obj, dir0);
stylePhyButton(obj.SortPhyButton, dir0);   % green "Open in phy (curated)" once curated
end


function refreshPhyStatus(obj, dir0)
%refreshPhyStatus  The phy row: a lamp (grey none, amber opened or saved
%   unchanged, green modified) and what phy changed in sorted-output DIR0
%   ("" = no sort to look at).
if isempty(obj.SortPhyLamp) || ~isvalid(obj.SortPhyLamp); return; end
grey = [0.75 0.75 0.75]; amber = [0.95 0.65 0.1]; green = [0.2 0.7 0.3];
if dir0 == ""
    obj.SortPhyLamp.Color = grey;
    obj.SortPhyLabel.Text = "phy: no sorted output to look at.";
    return
end
p = EphysDataset.phyStatus(dir0);
switch p.state
    case "none"
        obj.SortPhyLamp.Color = grey;
        obj.SortPhyLabel.Text = "Not opened in phy.";
        return
    case "opened"
        obj.SortPhyLamp.Color = amber;
        obj.SortPhyLabel.Text = "Opened in phy, nothing saved: the sorter's clusters and labels as they were.";
        return
end
when = string(datetime(p.saved, 'Format', 'yyyy-MM-dd HH:mm'));
if ~p.modified
    obj.SortPhyLamp.Color = amber;
    obj.SortPhyLabel.Text = "Saved in phy " + when + " with no change: no cluster labelled, merged or split.";
    return
end
obj.SortPhyLamp.Color = green;
parts = strings(1, 0);
if ~isempty(p.counts)
    parts(end+1) = "labelled " + strjoin(string(p.counts) + " " + p.labels, ", ");
end
if p.created > 0
    parts(end+1) = sprintf("%d cluster(s) from merges / splits", p.created);
end
if isfinite(p.clusters)
    parts(end+1) = sprintf("%d cluster(s) now", p.clusters);
end
obj.SortPhyLabel.Text = "Modified in phy (saved " + when + "): " + strjoin(parts, "; ") + ".";
end
