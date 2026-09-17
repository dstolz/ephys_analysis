function [values, report] = ks4ProbeDefaults(probe, opts)
%ks4ProbeDefaults  Good defaults for the probe-dependent Kilosort4 parameters.
%   [VALUES, REPORT] = EphysPipelineConfig.ks4ProbeDefaults(PROBE) derives the
%   parameters in EphysPipelineConfig.KS4ProbeParams from the layout of PROBE,
%   a Kilosort4 probe .json file or its decoded struct (xc, yc, optional
%   kcoords and chanMap). The rules follow Kilosort4's parameter guide
%   (https://kilosort.readthedocs.io/en/latest/parameters.html). VALUES has
%   one typed value per parameter (as in cfg.Sorting.KS4). Each rule starts
%   from the kilosortParamSpec default, so VALUES depends on the probe only.
%   Save them as the probe's parameter file with writeKS4Params; the app's
%   Optimize for probe loads that file (ks4ForProbe).
%
%     nblocks            0 (no drift correction) with 64 sites or fewer, rows
%                        50 um or more apart, or no two rows on any shank; 5
%                        for one shank spanning 2 mm or more (Neuropixels-like);
%                        otherwise 1 (rigid)
%     dmin               median spacing of the contact rows within a shank
%                        (blank = Kilosort's own estimate when no shank has two
%                        rows)
%     dminx              median lateral distance between contacts: to the
%                        nearest contact in the same row when at least half the
%                        contacts have one nearby (within 3x their nearest
%                        contact), else to the nearest contact in another
%                        column (the default when every shank is a single
%                        column, where dminx has no effect)
%     nearest_chans      the default, at most the number of sites
%     nearest_templates  the default, at most the number of sites when there
%                        are 64 or fewer
%     min_template_size  half the median distance to the nearest contact, not
%                        below the default
%     x_centers          one per shank, or one per 200 um of a wider shank
%
%   Shanks are the kcoords groups (one shank without kcoords), as Kilosort4
%   places templates per kcoords value. Coordinates less than 1 um apart
%   share a row or column. Distances are rounded to 0.01 um.
%
%   Options
%     ExcludeChannels  1-based channels to leave out; a site's channel is its
%                      chanMap value + 1 (as on the Probe tab)
%
%   REPORT struct
%     Probe     the probe file ("" when PROBE is a struct)
%     Summary   one line, e.g. "64 sites on 4 shanks: rows 10 um apart, ..."
%     Geometry  NumSites (after exclusions), NumExcluded, NumShanks,
%               RowPitchUm, LateralPitchUm, NearestSiteUm, WidthUm (widest
%               shank), SpanUm (tallest shank); NaN where there is no such
%               spacing
%     Reasons   struct: why each value was chosen (writeKS4Params' Reasons)
%     Notes     string column: groups of columns 100 um or more apart (at
%               least 3x the usual column gap) that share one kcoords value
%
%   Example: good defaults for a new probe map
%     [v, r] = EphysPipelineConfig.ks4ProbeDefaults(pf);
%     EphysPipelineConfig.writeKS4Params(pf, v, Description=r.Summary, Reasons=r.Reasons);
%
%   Errors: EphysPipelineConfig:BadProbe (not a probe, or no matching xc / yc),
%   EphysPipelineConfig:ProbeEmpty (every site excluded).
%
%   See also EphysPipelineConfig.writeKS4Params, EphysPipelineConfig.ks4ForProbe.

arguments
    probe
    opts.ExcludeChannels (1,:) double = double.empty(1, 0)
end

[p, file] = readProbe(probe);
g = geometry(p, opts.ExcludeChannels);
def = EphysPipelineConfig.defaults("Sorting").KS4;
n = g.NumSites;
values = struct();
reasons = struct();

if n <= 64
    choose('nblocks', 0, sprintf("%d sites, at most 64: drift estimates are unreliable, so no drift correction", n));
elseif isnan(g.RowPitchUm)
    choose('nblocks', 0, "no shank has two rows: no depth to correct drift along");
elseif g.RowPitchUm >= 50
    choose('nblocks', 0, "rows " + um(g.RowPitchUm) + " um apart, at least 50: drift estimates are unreliable, so no drift correction");
elseif g.NumShanks == 1 && g.SpanUm >= 2000
    choose('nblocks', 5, "one shank spanning " + um(g.SpanUm) + " um: non-rigid drift correction, as for Neuropixels");
else
    choose('nblocks', 1, "more than 64 closely spaced sites: rigid drift correction");
end

if isnan(g.RowPitchUm)
    choose('dmin', [], "no shank has two rows: Kilosort's own estimate");
else
    choose('dmin', g.RowPitchUm, "median spacing of the contact rows within a shank");
end

switch g.LateralRule
    case "row"
        choose('dminx', g.LateralPitchUm, "median lateral distance to the nearest contact in the same row");
    case "column"
        choose('dminx', g.LateralPitchUm, "median lateral distance to the nearest contact in another column");
    otherwise
        choose('dminx', def.dminx, "every shank is a single column, where dminx has no effect: default");
end

if n < def.nearest_chans
    choose('nearest_chans', n, sprintf("%d sites: at most the number of sites", n));
else
    choose('nearest_chans', def.nearest_chans, "default, no more than the number of sites");
end

if n <= 64 && n < def.nearest_templates
    choose('nearest_templates', n, sprintf("%d sites, at most 64: capped at the number of sites for numerical stability", n));
elseif n <= 64
    choose('nearest_templates', def.nearest_templates, "default, no more than the number of sites");
else
    choose('nearest_templates', def.nearest_templates, "default, more than 64 sites");
end

if ~isnan(g.NearestSiteUm) && round(g.NearestSiteUm / 2, 2) > def.min_template_size
    choose('min_template_size', round(g.NearestSiteUm / 2, 2), ...
        "nearest contacts " + um(g.NearestSiteUm) + " um apart: half that, wider than the default");
elseif isnan(g.NearestSiteUm)
    choose('min_template_size', def.min_template_size, "no shank has two contacts: default");
else
    choose('min_template_size', def.min_template_size, ...
        "nearest contacts " + um(g.NearestSiteUm) + " um apart: the default covers them");
end

nx = sum(max(1, round(g.ShankWidthUm / 200)));
if nx == g.NumShanks && g.NumShanks > 1
    choose('x_centers', nx, sprintf("one per shank, %d shanks", nx));
elseif nx == 1
    choose('x_centers', 1, "a single shank under 300 um wide: one center");
else
    choose('x_centers', nx, "one per 200 um of shank width, widest shank " + um(g.WidthUm) + " um");
end

notes = strings(0, 1);
if g.NumShanks == 1 && g.ShankGapUm > 0
    notes(end+1, 1) = "Groups of columns " + um(g.ShankGapUm) + " um apart share one kcoords value. " + ...
        "If this is a multi-shank probe, give each shank its own kcoords so Kilosort4 places templates per shank.";
end

summary = count(n, "site");
if g.NumExcluded > 0
    summary = summary + sprintf(" (%d excluded)", g.NumExcluded);
end
summary = summary + " on " + count(g.NumShanks, "shank");
spacing = strings(1, 0);
if ~isnan(g.RowPitchUm);     spacing(end+1) = "rows " + um(g.RowPitchUm) + " um apart"; end
if ~isnan(g.LateralPitchUm); spacing(end+1) = "lateral spacing " + um(g.LateralPitchUm) + " um"; end
if ~isnan(g.NearestSiteUm);  spacing(end+1) = "nearest contact " + um(g.NearestSiteUm) + " um"; end
if ~isempty(spacing)
    summary = summary + ": " + strjoin(spacing, ", ");
end

report = struct();
report.Probe = file;
report.Summary = summary;
report.Geometry = rmfield(g, ["LateralRule" "ShankWidthUm" "ShankGapUm"]);
report.Reasons = reasons;
report.Notes = notes;


    function choose(name, value, reason)
        values.(name) = value;
        reasons.(name) = string(reason);
    end
end


function s = um(v)
%um  A distance in um as short text.
s = string(round(v, 2));
end


function s = count(n, noun)
%count  "1 shank", "4 shanks".
s = n + " " + noun;
if n ~= 1
    s = s + "s";
end
end


function [p, file] = readProbe(probe)
%readProbe  Decoded probe struct from a .json file or a struct.
file = "";
if (ischar(probe) || isstring(probe)) && isscalar(string(probe))
    file = string(probe);
    p = readJsonFile(file);
elseif isstruct(probe) && isscalar(probe)
    p = probe;
else
    error('EphysPipelineConfig:BadProbe', 'PROBE must be a probe .json file or a decoded probe struct.');
end
if ~isstruct(p) || ~isscalar(p) || ~isfield(p, 'xc') || ~isfield(p, 'yc') ...
        || isempty(p.xc) || numel(p.xc) ~= numel(p.yc)
    what = "The probe struct";
    if file ~= ""; what = file; end
    error('EphysPipelineConfig:BadProbe', '%s has no matching xc / yc site coordinates.', what);
end
end


function g = geometry(p, exclude)
%geometry  Spacing summary of the sites Kilosort4 will sort.
tol = 1;   % um: closer coordinates share a row / column
xc = double(p.xc(:));
yc = double(p.yc(:));
n = numel(xc);
kc = zeros(n, 1);
if isfield(p, 'kcoords') && numel(p.kcoords) == n
    kc = double(p.kcoords(:));
end
ch = (1:n).';
if isfield(p, 'chanMap') && numel(p.chanMap) == n
    ch = double(p.chanMap(:)) + 1;
end
keep = ~ismember(ch, exclude);
if ~any(keep)
    error('EphysPipelineConfig:ProbeEmpty', 'Every probe site is excluded; nothing is left to sort.');
end
xc = xc(keep); yc = yc(keep); kc = kc(keep);
n = numel(xc);

shanks = unique(kc);
nS = numel(shanks);
width = zeros(nS, 1);
span = zeros(nS, 1);
rowGap = zeros(0, 1);
colGap = zeros(0, 1);
rowDx = NaN(n, 1);     % lateral distance to the nearest contact in the same row
colDx = NaN(n, 1);     % lateral distance to the nearest contact in another column
nearest = NaN(n, 1);   % distance to the nearest contact
for s = 1:nS
    in = find(kc == shanks(s));
    x = xc(in);
    y = yc(in);
    width(s) = max(x) - min(x);
    span(s) = max(y) - min(y);
    rowGap = [rowGap; diff(levels(y, tol))]; %#ok<AGROW>
    colGap = [colGap; diff(levels(x, tol))]; %#ok<AGROW>
    m = numel(in);
    if m < 2; continue; end
    dx = abs(x - x.');
    dy = abs(y - y.');
    d = hypot(dx, dy);
    d(1:m+1:end) = Inf;
    nearest(in) = min(d, [], 2);

    % Same-row neighbours count only nearby (within 3x the nearest contact),
    % so rows that line up across unlabelled shanks are not mistaken for pairs.
    r = dx;
    r(~(dy < tol & dx >= tol & d <= 3 * nearest(in))) = Inf;
    r = min(r, [], 2);
    r(isinf(r)) = NaN;
    rowDx(in) = r;

    c = d;
    c(dx < tol) = Inf;
    [cmin, j] = min(c, [], 2);
    c = dx(sub2ind([m m], (1:m).', j));
    c(isinf(cmin)) = NaN;
    colDx(in) = c;
end

g = struct();
g.NumSites = n;
g.NumExcluded = nnz(~keep);
g.NumShanks = nS;
g.RowPitchUm = round(median(rowGap), 2);
if nnz(~isnan(rowDx)) >= n / 2
    g.LateralPitchUm = round(median(rowDx, 'omitnan'), 2);
    g.LateralRule = "row";
elseif any(~isnan(colDx))
    g.LateralPitchUm = round(median(colDx, 'omitnan'), 2);
    g.LateralRule = "column";
else
    g.LateralPitchUm = NaN;
    g.LateralRule = "none";
end
g.NearestSiteUm = round(median(nearest, 'omitnan'), 2);
g.WidthUm = round(max(width), 2);
g.SpanUm = round(max(span), 2);
g.ShankWidthUm = width;
% A gap between columns that dwarfs the usual one suggests separate shanks.
g.ShankGapUm = 0;
if ~isempty(colGap) && max(colGap) >= 100 && max(colGap) >= 3 * median(colGap)
    g.ShankGapUm = round(max(colGap), 2);
end
end


function lev = levels(v, tol)
%levels  Distinct values of V, merging runs of values less than TOL apart.
s = sort(v(:));
if isempty(s)
    lev = s;
    return
end
grp = cumsum([true; diff(s) >= tol]);
lev = accumarray(grp, s, [], @mean);
end
