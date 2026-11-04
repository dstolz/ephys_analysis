function s = observationShortLabel(obs)
%observationShortLabel  An observation's short label: "su12", "ch7", "dataset", "probe".
%   S = observationShortLabel(OBS) for one row of figureObservations (a
%   table row, or a struct with kind, label, unitId, channel, column and
%   meta; a figure result's F.observation): a sorted unit's label before
%   the recording suffix ("su12" of "su12_RAT1_260918T1015"), a detection's
%   whole label, else "u<unitId>"; a channel "ch<N>" (an AUX channel its
%   label); "probe" for a probe figure's page; "dataset" otherwise. The
%   files' {Unit} (figureOutputName) and the labels' {Unit}
%   (figureLabelVariables).
%
%   See also figureOutputName, figureLabelVariables, shortUnitLabels.
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
    case "probe"
        s = "probe";   % a probe figure's page: every tile of the dataset
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
