function f = figureOutputName(pattern, name, spec, obs, i, n)
%figureOutputName  The file name (no extension) of one observation of an exported figure.
%   F = figureOutputName(PATTERN, NAME, SPEC, OBS, I, N) fills
%   Export.FilenamePattern (figureFileName) for observation I of the N a
%   figure (SPEC, figureFor) is drawn for on the dataset NAME: Name = NAME,
%   Plot = SPEC.id, Kind = "figure", Group = "all", Unit = the
%   observation's short label, Index = I and Date = today. OBS is one row
%   of figureObservations (a table row or a struct with kind, label,
%   unitId, channel and meta). Its short label:
%     a unit      a sorted unit's label before the recording suffix
%                 ("su12" of "su12_RAT1_260918T1015", shortUnitLabels); a
%                 detection's (class "det") whole label, its channel's
%                 name ("Shank_1"), so channels never share a name; else
%                 "u<unitId>"
%     a channel   "ch<N>", N its recording channel (an AUX channel: its
%                 label)
%     the dataset "dataset"
%   with every character outside [A-Za-z0-9_-.] replaced by "_". With N > 1
%   and a pattern that names neither {Unit} nor {Index}, "_<Unit>" is
%   appended, so the observations never overwrite each other. Figures and
%   plots share {Plot}: EphysAnalysisConfig.validate checks that a figure
%   id and a plot id never name the same files.
%
%   See also figureFileName, plotFileName, figureObservations,
%   EphysAnalysisRunner.runDataset.

arguments
    pattern (1,1) string
    name (1,1) string
    spec (1,1) struct
    obs
    i (1,1) double
    n (1,1) double
end

unit = regexprep(observationLabel(obs), '[^\w\-\.]', '_');
f = figureFileName(pattern, struct('Name', name, 'Plot', spec.id, 'Kind', "figure", 'Group', "all", ...
    'Unit', unit, 'Index', i));
if n > 1 && ~contains(pattern, ["{Unit}" "{Index}"])
    f = f + "_" + unit;
end
end


function s = observationLabel(obs)
%observationLabel  An observation's short label: "su12", "ch7", "dataset".
kind = string(valueOf(obs, 'kind', "unit"));
meta = valueOf(obs, 'meta', []);
switch kind
    case "unit"
        s = "";
        if istable(meta) && height(meta) >= 1 && ismember("label", string(meta.Properties.VariableNames))
            s = string(meta.label(1));
            cls = "";
            if ismember("class", string(meta.Properties.VariableNames)); cls = string(meta.class(1)); end
            if cls ~= "det" && cls ~= "" && startsWith(s, cls)
                % a sorted unit "<class><id>_<recording>": the part before the suffix every unit of the
                % recording shares; a detection's label is its channel's name ("Shank_1"), kept whole
                s = shortUnitLabels(s);
            end
        end
        if s == ""; s = "u" + valueOf(obs, 'unitId', NaN); end
    case "channel"
        ch = double(valueOf(obs, 'channel', NaN));
        if isfinite(ch)
            s = "ch" + ch;
        elseif istable(meta) && height(meta) >= 1 && ismember("label", string(meta.Properties.VariableNames))
            s = string(meta.label(1));   % an AUX channel has no recording channel
        else
            s = "ch" + valueOf(obs, 'column', NaN);
        end
    otherwise
        s = "dataset";
end
end


function v = valueOf(obs, field, default)
%valueOf  OBS.(FIELD) of a table row or a struct (a cell unwrapped), else DEFAULT.
v = default;
if istable(obs)
    if height(obs) >= 1 && ismember(field, string(obs.Properties.VariableNames)); v = obs.(field)(1); end
elseif isstruct(obs) && isfield(obs, field)
    v = obs.(field);
end
if iscell(v) && isscalar(v); v = v{1}; end
end
