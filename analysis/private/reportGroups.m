function [G, rest] = reportGroups(D)
%reportGroups  A report section's figures grouped by observation, for Report.Order "unit".
%   [G, REST] = reportGroups(D) groups the pages of the entries of D (one
%   of a report's datasets: newAnalysisReport, addReportFigure) by the
%   observation each page shows (the entry's obsKeys): G has one element
%   per observation -- a unit, a channel, or the dataset -- in the order
%   the observations first appear (the first figure's in its probe order,
%   then what later figures add), with fields
%     key     the observation's key (addReportFigure's obsKeys)
%     label   its label (obsLabels: the picker's, without the trial group)
%     entry   the entries that drew it, in the figures' order
%     pages   {1 x numel(entry)}: each entry's pages of it (indices into its
%             images and pages; several for a figure per trial group)
%   REST lists the entries that hold no observation per page, in order:
%   those not drawn (skipped, error, canceled), and those added without
%   Observations= (e.g. a session figure); the reports show them whole,
%   after the groups.
%
%   See also writeHtmlReport, writePdfReport, addReportFigure.

G = struct('key', {}, 'label', {}, 'entry', {}, 'pages', {});
rest = zeros(1, 0);
for k = 1:numel(D.entries)
    e = D.entries(k);
    if e.status ~= "done" || ~isfield(e, 'obsKeys') || isempty(e.obsKeys)
        rest(end+1) = k; %#ok<AGROW>
        continue
    end
    [u, first, j] = unique(e.obsKeys, 'stable');
    for q = 1:numel(u)
        g = find(string({G.key}) == u(q), 1);
        if isempty(g)
            G(end+1) = struct('key', u(q), 'label', e.obsLabels(first(q)), 'entry', zeros(1, 0), 'pages', {cell(1, 0)}); %#ok<AGROW>
            g = numel(G);
        end
        G(g).entry(end+1) = k;
        G(g).pages{end+1} = reshape(find(j == q), 1, []);
    end
end
end
