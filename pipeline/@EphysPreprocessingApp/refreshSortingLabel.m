function refreshSortingLabel(obj)
%refreshSortingLabel  Describe the active dataset's sorted-output association.
if isempty(obj.SortResultsLabel) || ~isvalid(obj.SortResultsLabel); return; end
d = obj.currentDataset();
if isempty(d)
    obj.SortResultsLabel.Text = "Scan a project first.";
    return
end
s = d.sortingStruct();
if s.results_dir == ""
    txt = sprintf("%s: no sorted output yet (auto: %s).", d.Name, d.kilosortDir());
else
    cur = "uncurated (cluster_KSLabel.tsv)";
    if s.curated; cur = "phy-curated (cluster_group.tsv)"; end
    nU = "?";
    if isfinite(s.num_units); nU = string(s.num_units); end
    txt = sprintf("%s: %s association -> %s\n%s cluster(s), %s", d.Name, s.source, s.results_dir, nU, cur);
end
obj.SortResultsLabel.Text = txt;
end
