function labels = unitLabels(n, labels, meta)
%unitLabels  N labels: the ones given, else META.label, else "u1".."uN".
labels = reshape(string(labels), 1, []);
if numel(labels) == n; labels = labels(:); return; end
if istable(meta) && height(meta) == n && ismember("label", string(meta.Properties.VariableNames))
    labels = string(meta.label(:));
    return
end
labels = "u" + (1:n).';
end
