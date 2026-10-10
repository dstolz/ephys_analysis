function S = populationSummary(P, opts)
%populationSummary  populationAnalysis' units summed up by group: counts, fractions, rates, mean PSTH and tuning.
%   S = populationSummary(P, GroupBy=["subject" "class"]) groups the rows of
%   P.units by any of
%     subject      P.units.subject ("(none)" when unknown)
%     dataset      the dataset's name
%     class        su / mua / ... (det for detections)
%     shank        the probe map's shank
%     depth        probe y, in bins of DepthBinUm um ("y 200-300 um";
%                  "y unknown" without a site)
%     direction    excited / suppressed / none / untested
%     responsive, tuned   yes / no / untested
%     auroc        the auROC's call: increase / decrease / mixed / none /
%                  uncalled
%   (GroupBy [] = one group, "all"). Groups go in the order of their
%   values (numbers ascending, text alphabetically).
%
%   S fields
%     groups     table, one row per group: group (its label), one column
%                per GroupBy key, nUnits, nDatasets, meanRateHz /
%                medianRateHz (rateHz over the group's units), nTested
%                (units with an evoked p), nResponsive, fracResponsive (of
%                nTested), nExcited and nSuppressed (responsive units by
%                direction), nTuningTested, nTuned, fracTuned (of
%                nTuningTested), nAurocCalled (units the auROC called),
%                nAurocModulated (in any of their groups),
%                fracAurocModulated (of nAurocCalled), nAurocIncrease and
%                nAurocDecrease (P.units.aurocDirection), medianLatency
%                (psthLatency, s, of the responsive excited units) and,
%                when the units carry them, the medians of
%                isiViolationsRatio, presenceRatio, amplitudeCutoff and
%                snr. A fraction with no unit tested is NaN
%     auroc      how the auROC calls were made ([] without them): cutoff
%                (P.auroc.cutoff), groupBy and families (P.auroc.families:
%                the cutoff c pooled over each family's unit x group
%                curves)
%     unitGroup  [nUnits x 1] the group of each row of P.units
%     psth       t, mean / sem [nBins x nGroups] (over the group's units,
%                NaN ignored; sem NaN below 2 units), units
%     tuning     param, levels, mean / sem [nLevels x nGroups], normalize:
%                TuningNormalize "peak" (default) divides each unit's
%                curve by its highest level first (a unit whose highest
%                level is not above 0 is left out); "none" keeps spikes/s
%                psth and tuning also hold lo / hi, the error band of
%                each group's mean across its units (errorBounds:
%                ErrorType "sem" (default), "std" or "ci95", a bootstrap 95%
%                CI with ErrorResamples resamples of the units, default
%                1000), and errorType
%     params     GroupBy, DepthBinUm, TuningNormalize, ErrorType,
%                ErrorResamples
%
%   See also populationAnalysis, renderPopulation, writePopulation.

arguments
    P (1,1) struct
    opts.GroupBy (1,:) string = ["subject" "class"]
    opts.DepthBinUm (1,1) double {mustBePositive} = 100
    opts.TuningNormalize (1,1) string = "peak"
    opts.ErrorType (1,1) string {mustBeMember(opts.ErrorType, ["sem" "std" "ci95"])} = "sem"
    opts.ErrorResamples (1,1) double {mustBePositive, mustBeInteger} = 1000
end

keysAllowed = ["subject" "dataset" "class" "shank" "depth" "direction" "responsive" "tuned" "auroc"];
by = opts.GroupBy;
bad = setdiff(by, keysAllowed);
if ~isempty(bad)
    error('populationSummary:BadGroupBy', 'GroupBy is any of %s (got %s).', strjoin(keysAllowed, ", "), strjoin(bad, ", "));
end
if numel(unique(by)) < numel(by)
    error('populationSummary:BadGroupBy', 'GroupBy names a key twice.');
end
if ~ismember(opts.TuningNormalize, ["peak" "none"])
    error('populationSummary:BadOption', 'TuningNormalize is peak or none (got "%s").', opts.TuningNormalize);
end
U = P.units;
n = height(U);
has = @(c) ismember(c, string(U.Properties.VariableNames));
if any(by == "tuned") && ~has("tuned")
    error('populationSummary:BadGroupBy', 'GroupBy "tuned" needs the tuning test (populationAnalysis Param=).');
end

% --- the groups ------------------------------------------------------------------------------
vals = cell(1, numel(by));
labs = cell(1, numel(by));
for i = 1:numel(by)
    [vals{i}, labs{i}] = keyOf(U, by(i), opts.DepthBinUm);
end
if isempty(by)
    gi = ones(n, 1);
    nG = double(n > 0);
    label = repmat("all", nG, 1);
    keyCols = table();
else
    gi = findgroups(vals{:});
    nG = max([0; gi]);
    label = strings(nG, 1);
    keyCols = table();
    for i = 1:numel(by)
        col = strings(nG, 1);
        for g = 1:nG
            col(g) = labs{i}(find(gi == g, 1));
        end
        keyCols.(by(i)) = col;
    end
    for g = 1:nG
        label(g) = strjoin(keyCols{g, :}, ", ");
    end
end

% --- counts, fractions and rates ------------------------------------------------------------------
cols = ["nUnits" "nDatasets" "meanRateHz" "medianRateHz" "nTested" "nResponsive" "fracResponsive" ...
    "nExcited" "nSuppressed" "nTuningTested" "nTuned" "fracTuned" "nAurocCalled" "nAurocModulated" ...
    "fracAurocModulated" "nAurocIncrease" "nAurocDecrease" "medianLatency"];
qual = ["isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr"];
qual = qual(arrayfun(has, qual));
M = NaN(nG, numel(cols) + numel(qual));
hasTuning = has("pTuning");
for g = 1:nG
    r = gi == g;
    tested = r & isfinite(U.pEvoked);
    resp = tested & U.responsive;
    exc = resp & U.direction == "excited";
    row = [nnz(r), numel(unique(U.datasetKey(r))), mean(U.rateHz(r), 'omitnan'), median(U.rateHz(r), 'omitnan'), ...
        nnz(tested), nnz(resp), nnz(resp) / nnz(tested), nnz(exc), nnz(resp & U.direction == "suppressed")];
    if hasTuning
        tt = r & isfinite(U.pTuning);
        row = [row, nnz(tt), nnz(tt & U.tuned), nnz(tt & U.tuned) / nnz(tt)]; %#ok<AGROW>
    else
        row = [row, 0, 0, NaN]; %#ok<AGROW>
    end
    called = r & U.aurocDirection ~= "";
    row = [row, nnz(called), nnz(called & U.aurocModulated), nnz(called & U.aurocModulated) / nnz(called), ...
        nnz(called & U.aurocDirection == "increase"), nnz(called & U.aurocDirection == "decrease")]; %#ok<AGROW>
    row(end+1) = median(U.psthLatency(exc), 'omitnan'); %#ok<AGROW>
    for c = qual
        row(end+1) = median(U.(c)(r), 'omitnan'); %#ok<AGROW>
    end
    M(g, :) = row;
end
G = table(label, 'VariableNames', {'group'});
if width(keyCols) > 0; G = [G, keyCols]; end
G = [G, array2table(M, 'VariableNames', cellstr([cols, "median_" + qual]))];

% --- mean PSTH and tuning per group ---------------------------------------------------------------
X = P.psth.rate;
pm = NaN(size(X, 1), nG); ps = pm; plo = pm; phi = pm;
for g = 1:nG
    pm(:, g) = mean(X(:, gi == g), 2, 'omitnan');
    ps(:, g) = semOf(X(:, gi == g), 2);
    [plo(:, g), phi(:, g)] = errorBounds(X(:, gi == g), 2, opts.ErrorType, opts.ErrorResamples);
end
Tn = P.tuning.rate;
if opts.TuningNormalize == "peak" && ~isempty(Tn)
    top = max(Tn, [], 1);
    Tn = Tn ./ top;
    Tn(:, ~(top > 0)) = NaN;
end
tm = NaN(size(Tn, 1), nG); ts = tm; tlo = tm; thi = tm;
for g = 1:nG
    tm(:, g) = mean(Tn(:, gi == g), 2, 'omitnan');
    ts(:, g) = semOf(Tn(:, gi == g), 2);
    if ~isempty(Tn)
        [tlo(:, g), thi(:, g)] = errorBounds(Tn(:, gi == g), 2, opts.ErrorType, opts.ErrorResamples);
    end
end

S = struct();
S.groups = G;
S.auroc = [];
if ~isempty(P.auroc)
    S.auroc = struct('cutoff', P.auroc.cutoff, 'groupBy', P.auroc.groupBy, 'families', P.auroc.families);
end
S.unitGroup = gi;
S.psth = struct('t', P.psth.t, 'mean', pm, 'sem', ps, 'units', P.psth.units, 'lo', plo, 'hi', phi, ...
    'errorType', opts.ErrorType);
S.tuning = struct('param', P.tuning.param, 'levels', P.tuning.levels, 'mean', tm, 'sem', ts, ...
    'normalize', opts.TuningNormalize, 'lo', tlo, 'hi', thi, 'errorType', opts.ErrorType);
S.params = struct('GroupBy', by, 'DepthBinUm', opts.DepthBinUm, 'TuningNormalize', opts.TuningNormalize, ...
    'ErrorType', opts.ErrorType, 'ErrorResamples', opts.ErrorResamples);
end


function [v, lab] = keyOf(U, key, bin)
%keyOf  A grouping variable (sortable, no missing values) and its labels.
switch key
    case "subject"
        v = string(U.subject);
        v(v == "" | ismissing(v)) = "(none)";
        lab = v;
    case "dataset"
        v = string(U.dataset);
        lab = v;
    case "class"
        v = string(U.class);
        v(v == "" | ismissing(v)) = "(none)";
        lab = v;
    case "shank"
        v = double(U.shank);
        lab = "shank " + string(v);
        v(isnan(v)) = Inf;
        lab(isinf(v)) = "shank unknown";
    case "depth"
        lo = floor(double(U.y) / bin) * bin;
        lab = compose("y %g-%g um", lo, lo + bin);
        lo(isnan(lo)) = Inf;
        lab(isinf(lo)) = "y unknown";
        v = lo;
    case "direction"
        v = string(U.direction);
        v(v == "" | ismissing(v)) = "untested";
        lab = v;
    case "auroc"
        v = string(U.aurocDirection);
        v(v == "" | ismissing(v)) = "uncalled";
        lab = "auROC " + v;
    case {"responsive" "tuned"}
        p = U.pEvoked;
        if key == "tuned"; p = U.pTuning; end
        v = repmat("untested", height(U), 1);
        v(isfinite(p) & U.(key)) = "yes";
        v(isfinite(p) & ~U.(key)) = "no";
        lab = key + " " + v;
end
end
