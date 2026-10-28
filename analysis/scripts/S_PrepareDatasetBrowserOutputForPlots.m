%% Prepare DatasetBrowser output for plots
% A post-processing script of the DatasetBrowser: the browser runs it in the
% base workspace after Compute ("Run it after each Compute") or on "Run now",
% with itself there as B. Run by hand, it uses the B already in the workspace
% (B = DatasetBrowser.open(root)). It leaves R, units_, data_, groupLabels_,
% groupTexts_, cmap, ... in the workspace for the plots.

if ~exist('B', 'var') || ~isa(B, 'DatasetBrowser')
    error('B is not a DatasetBrowser: run this from the browser (Post-processing script), or set B = DatasetBrowser.open(root) first.');
end
R = B.Result;
if isempty(R), error('No result yet: press Compute in the browser.'); end
if ~B.ResultCurrent
    warning('The result is out of date: the settings or the ticks changed after the last Compute.');
end
fprintf('%d units x %d bins x %d groups from %d datasets (%s)\n', size(R.data, 1), size(R.data, 2), ...
    size(R.data, 3), numel(R.keys), R.valueUnits);
missed = ~ismember(R.datasets.status, ["done" "cached"]);
if any(missed), disp(R.datasets(missed, ["key" "status" "message"])), end




% R.settings.data is "units" | "detected" (spikes: a row per unit, with a class) or "LFP" | "MUA" | "SPIKE" | "AUX" (signals: a row per channel, no class)
isSpikes = R.rowKind == "unit";
unitClasses = "su";   % spikes: the unit classes kept ("su", "mua", ... for "units"; detection channels are all "det")
if R.settings.data == "detected", unitClasses = "det"; end

if isSpikes
    ind = ismember(R.rows.class, unitClasses);
    idKey = "unitId";
    rowsTxt = strjoin(unitClasses, '/') + " " + R.labels.rows;   % "su units", "det detected channels"
else
    ind = true(height(R.rows), 1);   % a signal's channels were chosen in the browser (Signals panel)
    idKey = "channel";
    rowsTxt = R.labels.rows;   % "LFP channels", "MUA channels", "AUX magnitudes"
end
units_ = R.rows(ind, :);   % a row per unit or channel; the plots call both "units"
data_ = R.data(ind, :, :);

% sort by session (then subject and unit id or channel, to keep ties in a fixed order), and the groups by Depth
[units_, i] = sortrows(units_, ["Session" "Subject" idKey]);
data_ = data_(i, :, :);
[groupLabels_, j] = sort(R.groupLabels, 'descend');
data_ = data_(:, :, j);
groupTexts_ = R.labels.groups(j);   % "Depth 3", ... in groupLabels_' order

uSessions = unique(units_.Session);
nS = numel(uSessions);
[nU, nB, nG] = size(data_);
cmap = turbo(nG);   % a color per depth group

unitsTxt = sprintf('%d %s', height(units_), rowsTxt);   % "12 su units", "64 LFP channels"

% Summary of R
fprintf('R: %s\n', R.labels.description);
fprintf('created %s\n',string(R.created));
fprintf('data   %s  (rows x time x groups), units: %s\n', mat2str(size(R.data)), R.valueUnits);
fprintf('rows   %d %ss from %d datasets (%d subjects)\n', height(R.rows), R.rowKind, ...
    numel(unique(R.rows.Dataset)), numel(unique(R.rows.Subject)));
fprintf('t      %.3g to %.3g s, %d points\n', R.t(1), R.t(end), numel(R.t));
fprintf('groups %s\n', strjoin(string(R.groupLabels), ', '));
fprintf('NaN    %.1f%% of values\n', 100*mean(isnan(R.data), 'all'));
fprintf('range  %.3g to %.3g (median %.3g)\n', min(R.data, [], 'all'), max(R.data, [], 'all'), median(R.data, 'all', 'omitnan'));
fprintf('normalized: %s\n', R.normalization.method);
disp(groupcounts(R.datasets, 'status'))
disp(R.settings)
