function [fig, unknown] = normalizeFigure(in, path)
%normalizeFigure  Coerce one figure entry to defaults("Figure").
%   [FIG, UNKNOWN] = EphysAnalysisConfig.normalizeFigure(IN, PATH) fills the
%   fields IN leaves out, coerces the rest (see normalizeSection) and drops
%   unknown fields (their paths, prefixed by PATH, in UNKNOWN):
%   - ref, window and selection are the string "default" (the config's
%     Defaults, see figureFor) or a struct, normalized as an EventRef /
%     EpochWindow / TrialSelection; an empty value means "default"
%   - observe and grid are coerced to their defaults
%     (grid.rowHeights and grid.colWidths stay vectors: [] = equal;
%     grid.rowGaps and grid.colGaps too: [] = rowGap / colGap each)
%   - panels is a list of panels (a struct array, a cell from jsondecode,
%     one struct or [] for none), each normalizePanel'd; a panel without
%     an id gets "<type>_<n>", and two panels with one id raise
%     EphysAnalysisConfig:DuplicatePanelId
%   - aesthetics is a list of rules, normalized by
%     PlotAesthetics.normalizeRules
%
%   See also EphysAnalysisConfig.normalizePanel, EphysAnalysisConfig.figureFor.

arguments
    in = struct()
    path (1,1) string = "Figure"
end

def = EphysAnalysisConfig.defaults("Figure");
sentinels = struct('ref', "EventRef", 'window', "EpochWindow", 'selection', "TrialSelection");
held = struct();
if isstruct(in) && ~isempty(in)
    if ~isscalar(in)
        error('EphysAnalysisConfig:BadValue', '%s must be a scalar struct.', path);
    end
    for f = ["ref" "window" "selection" "panels" "aesthetics"]
        if isfield(in, f)
            held.(f) = in.(f);
            in = rmfield(in, f);
        end
    end
end
[fig, unknown] = EphysAnalysisConfig.coerceStruct(def, in, path);

for f = string(fieldnames(sentinels)).'
    if ~isfield(held, f); continue; end
    v = held.(f);
    if isempty(v) || ((isstring(v) || ischar(v)) && lower(strtrim(string(v))) == "default")
        fig.(f) = "default";
    elseif isstruct(v)
        [fig.(f), u] = EphysAnalysisConfig.coerceStruct(EphysAnalysisConfig.defaults(sentinels.(f)), v, path + "." + f);
        unknown = [unknown, u]; %#ok<AGROW>
    else
        error('EphysAnalysisConfig:BadValue', '%s.%s must be "default" or a struct.', path, f);
    end
end

looks = [];
if isfield(held, 'aesthetics'); looks = held.aesthetics; end
try
    fig.aesthetics = PlotAesthetics.normalizeRules(looks, path + ".aesthetics");
catch ME
    error('EphysAnalysisConfig:BadValue', '%s', ME.message);
end

fig.panels = repmat(EphysAnalysisConfig.defaults("Panel"), 1, 0);
if isfield(held, 'panels') && ~isempty(held.panels)
    v = held.panels;
    if isstruct(v)
        v = num2cell(v);
    elseif ~iscell(v)
        error('EphysAnalysisConfig:BadValue', '%s.panels must be a list of structs.', path);
    end
    for k = 1:numel(v)
        if ~isstruct(v{k})
            error('EphysAnalysisConfig:BadValue', '%s.panels(%d) must be a struct.', path, k);
        end
        [p, u] = EphysAnalysisConfig.normalizePanel(v{k}, path + ".panels(" + k + ")");
        unknown = [unknown, u]; %#ok<AGROW>
        fig.panels(1, k) = p;
    end
end
if ~isempty(fig.panels)
    ids = [fig.panels.id];
    given = ids(ids ~= "");
    [~, first] = unique(given, 'stable');
    dup = given(setdiff(1:numel(given), first));
    if ~isempty(dup)
        error('EphysAnalysisConfig:DuplicatePanelId', '%s: panel id "%s" is used more than once.', path, dup(1));
    end
    for k = find(ids == "")
        fig.panels(k).id = EphysAnalysisConfig.freeId(fig.panels(k).type, [fig.panels.id]);
    end
end
end
