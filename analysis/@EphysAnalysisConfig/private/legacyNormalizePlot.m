function [p, unknown] = legacyNormalizePlot(in, path, section)
%legacyNormalizePlot  Read one entry of a version-1 config's Plots or SessionPlots, for its migration only.
%   [P, UNKNOWN] = legacyNormalizePlot(IN, PATH) coerces a version-1 plot
%   (a struct of jsondecode) to legacyPlotDefaults("Plot") as version 1's
%   normalizePlot did: missing fields take their defaults, the rest are
%   coerced (EphysAnalysisConfig.coerceStruct), unknown fields are dropped
%   and their paths (prefixed PATH, default "Plot") returned in UNKNOWN.
%   ref, window and selection are "default" (also an empty value) or a
%   normalized EventRef / EpochWindow / TrialSelection; rasterEvents a list
%   of EventMarks (the one struct of every mark of a plot saved before
%   2026-10-13 a mark per line and sequence: oldMarks); aesthetics
%   PlotAesthetics' rules.
%
%   [P, UNKNOWN] = legacyNormalizePlot(IN, PATH, "SessionPlot") reads one
%   entry of SessionPlots (legacyPlotDefaults("SessionPlot")): its data a
%   list of words, its aesthetics rules normalized.
%
%   Errors: EphysAnalysisConfig:BadValue (not a scalar struct, a value that
%   cannot be coerced). Nothing but legacyMigrate uses it.
%
%   See also legacyMigrate, legacyPlotDefaults, EphysAnalysisConfig.coerceStruct.

arguments
    in = struct()
    path (1,1) string = "Plot"
    section (1,1) string = "Plot"
end

if isstruct(in) && ~isempty(in) && ~isscalar(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
end
if ~isstruct(in)
    error('EphysAnalysisConfig:BadValue', '%s must be a struct.', path);
end
def = legacyPlotDefaults(section);
held = struct();
pulled = "aesthetics";
if section == "Plot"
    pulled = ["aesthetics" "ref" "window" "selection" "rasterEvents"];
else
    pulled = [pulled "data"];
end
for f = pulled
    if isfield(in, f)
        held.(f) = in.(f);
        in = rmfield(in, f);
    end
end
[p, unknown] = EphysAnalysisConfig.coerceStruct(def, in, path);

looks = [];
if isfield(held, 'aesthetics'); looks = held.aesthetics; end
try
    p.aesthetics = PlotAesthetics.normalizeRules(looks, path + ".aesthetics");
catch ME
    error('EphysAnalysisConfig:BadValue', '%s', ME.message);
end

if section == "SessionPlot"
    if isfield(held, 'data')
        v = held.data;
        if isempty(v); v = string.empty(1, 0); end
        p.data = reshape(string(v), 1, []);
    end
    return
end

sentinels = struct('ref', "EventRef", 'window', "EpochWindow", 'selection', "TrialSelection");
for f = ["ref" "window" "selection"]
    if ~isfield(held, f); continue; end
    v = held.(f);
    if isempty(v) || ((isstring(v) || ischar(v)) && lower(strtrim(string(v))) == "default")
        p.(f) = "default";
    elseif isstruct(v)
        [p.(f), u] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults(sentinels.(f)), v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    else
        error('EphysAnalysisConfig:BadValue', '%s.%s must be "default" or a struct.', path, f);
    end
end
if isfield(held, 'rasterEvents') && ~isempty(held.rasterEvents)
    v = held.rasterEvents;
    if isstruct(v)
        v = num2cell(v);
    elseif ~iscell(v)
        error('EphysAnalysisConfig:BadValue', '%s.rasterEvents must be a list of structs.', path);
    end
    mk = EphysAnalysisConfig.defaults("EventMark");
    v = oldMarks(v);
    for k = 1:numel(v)
        if ~isstruct(v{k})
            error('EphysAnalysisConfig:BadValue', '%s.rasterEvents(%d) must be a struct.', path, k);
        end
        [p.rasterEvents(1, k), u] = EphysAnalysisConfig.coerceStruct(mk, v{k}, path + ".rasterEvents(" + k + ")");
        unknown = [unknown, u]; %#ok<AGROW>
    end
end
end


function out = oldMarks(v)
%oldMarks  The raster marks V (a cell of structs) with those of before 2026-10-13 made EventMarks.
%   Until then rasterEvents was one struct for every mark: lines (the
%   lines whose events are marked), sequences (event references marked
%   too), edge, scope ("window": every event in the epoch's window;
%   "trial": only those in the epoch's own trial) and one look (marker,
%   size, color). Such a struct becomes a mark per line (that line, its
%   edge, which "all") and a mark per sequence, each with the scope
%   ("window" is "recording") and the look; one with no lines and no
%   sequences marked nothing and gives no mark. A mark of the list form
%   passes as it is.
out = {};
for k = 1:numel(v)
    m = v{k};
    if ~isstruct(m) || ~(isfield(m, 'lines') || isfield(m, 'sequences'))
        out{end+1} = m; %#ok<AGROW>
        continue
    end
    common = struct('which', "all", 'scope', "recording");
    if isfield(m, 'scope') && string(m.scope) == "trial"; common.scope = "trial"; end
    for f = ["marker" "size" "color"]
        if isfield(m, f) && ~isempty(m.(f)); common.(f) = m.(f); end
    end
    edge = "onset";
    if isfield(m, 'edge') && ~isempty(m.edge); edge = string(m.edge); end
    lines = string.empty(1, 0);
    if isfield(m, 'lines') && ~isempty(m.lines); lines = reshape(string(m.lines), 1, []); end
    for L = lines(strtrim(lines) ~= "")
        e = common;
        e.line = strtrim(L);
        e.edge = edge;
        out{end+1} = e; %#ok<AGROW>
    end
    s = {};
    if isfield(m, 'sequences') && ~isempty(m.sequences); s = m.sequences; end
    if isstruct(s); s = num2cell(s); end
    for j = 1:numel(s)
        e = s{j};
        if ~isstruct(e); out{end+1} = e; continue; end %#ok<AGROW> coerceStruct says what is wrong
        for f = string(fieldnames(common)).'
            e.(f) = common.(f);
        end
        out{end+1} = e; %#ok<AGROW>
    end
end
end
