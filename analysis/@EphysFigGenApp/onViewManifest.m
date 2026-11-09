function v = onViewManifest(obj, idx)
%onViewManifest  Open a dataset's manifest in the manifest viewer (the Data table's right-click View manifest...).
%   V = obj.onViewManifest() opens the active dataset's (the first
%   selected row's when there is no active one); obj.onViewManifest(IDX)
%   dataset IDX's (an index into Runner.Outputs). The viewer
%   (ManifestViewerApp) is read-only: how the dataset was processed, its
%   variables and their history (Variables tab). A dataset without a
%   manifest on disk is named in the status bar and V is empty.
%
%   See also ManifestViewerApp, onEditVariables.
v = [];
r = obj.Runner;
if isempty(r) || isempty(r.Keys); return; end
if nargin < 2
    idx = obj.ActiveIdx;
    T = obj.DatasetsTable.Data;
    sel = obj.DatasetsTable.Selection;
    if idx < 1 && ~isempty(sel) && istable(T) && ismember('Idx', T.Properties.VariableNames) && sel(1, 1) <= height(T)
        idx = T.Idx(sel(1, 1));
    end
end
if idx < 1 || idx > numel(r.Outputs)
    AppDialog.alert(obj.Fig, "Click a dataset in the Data table first.", "View manifest");
    return
end
file = string(r.Outputs(idx).ManifestFile);
if isempty(file) || file(1) == "" || ~isfile(file(1))
    obj.setStatus("No manifest on disk for " + r.Names(idx) + ".");
    return
end
v = ManifestViewerApp(file(1));
if obj.Fig.Visible == "off"; v.Fig.Visible = "off"; end
end
