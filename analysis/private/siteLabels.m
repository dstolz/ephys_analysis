function labels = siteLabels(labels, meta, style)
%siteLabels  Unit or channel labels with their shank and / or depth appended.
%   LABELS = siteLabels(LABELS, META, STYLE) turns "u12" into "u12 (sh2,
%   640 µm)": the shank when STYLE.LabelShank, the probe y (µm) when
%   STYLE.LabelDepth. LABELS and META rows correspond. Labels are returned
%   unchanged for a part META lacks (no shank / y column, or a NaN y).
labels = string(labels(:));
n = numel(labels);
if ~istable(meta) || height(meta) ~= n || ~(style.LabelShank || style.LabelDepth); return; end
vars = string(meta.Properties.VariableNames);
parts = strings(n, 0);
if style.LabelShank && ismember("shank", vars)
    parts = [parts "sh" + compose("%g", double(meta.shank(:)))];
end
if style.LabelDepth && ismember("y", vars)
    y = double(meta.y(:));
    p = compose("%g µm", y);
    p(~isfinite(y)) = "";
    parts = [parts p];
end
if isempty(parts); return; end
suffix = join(parts, ", ", 2);
suffix = regexprep(suffix, '^,\s*|,\s*$', '');   % an empty depth leaves a dangling comma
has = suffix ~= "";
labels(has) = labels(has) + " (" + suffix(has) + ")";
end
