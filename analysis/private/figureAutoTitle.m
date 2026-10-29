function [txt, named] = figureAutoTitle(F, spec)
%figureAutoTitle  The figure's title: SPEC.title, else what it shows (autoTitle); an observation of one trial group adds its group. NAMED: it observes something with a label (not the dataset).
%   [TXT, NAMED] = figureAutoTitle(F, SPEC) for a figureCompute result,
%   a figure merged across sessions (nSessions) or a probe figure
%   (figureProbeCompute's PF: its observation names what the tiles are, its
%   epochs the first tile's; a field it lacks is taken from its first
%   computed tile).
%
%   See also renderFigure, renderProbeFigure.
if isfield(F, 'tiles'); F = probeFields(F); end
txt = spec.title;
obs = F.observation;
named = isstruct(obs) && isfield(obs, 'kind') && obs.kind ~= "dataset" && isfield(obs, 'label') && string(obs.label) ~= "";
grpTxt = "";   % one figure per trial group: the group drawn
if isstruct(obs) && isfield(obs, 'groupLabel'); grpTxt = string(obs.groupLabel); end
if txt == ""
    txt = autoTitle(F, spec, named, grpTxt);
elseif grpTxt ~= ""
    txt = txt + " · " + grpTxt;
end
end


function t = autoTitle(F, spec, named, grpTxt)
%autoTitle  "<id>: <observation> — <event> (<n> epochs)" (a trial group's observation names its group).
t = spec.id;
if t == ""; t = "Figure"; end
if named
    t = t + ": " + string(F.observation.label);
elseif grpTxt ~= ""
    t = t + ": " + grpTxt;
end
if istable(F.epochs) && isstruct(spec.ref)
    ev = eventRefLabel(spec.ref);
    w = spec.window;
    if isstruct(w) && isfield(w, 'mode') && w.mode == "between" && isfield(w, 'stop') && ~isempty(w.stop)
        ev = ev + " to " + eventRefLabel(w.stop);
    end
    if isfield(F, 'nSessions')   % merged across sessions (figureSessionCompute)
        t = t + " — " + ev + sprintf(" (%d session%s, %d epochs)", F.nSessions, plural(F.nSessions), height(F.epochs));
    else
        t = t + " — " + ev + sprintf(" (%d epochs)", height(F.epochs));
    end
elseif isfield(F, 'nSessions')
    t = t + sprintf(" (%d session%s)", F.nSessions, plural(F.nSessions));
end
end


function s = plural(n)
s = "";
if n ~= 1; s = "s"; end
end


function F = probeFields(F)
%probeFields  A probe figure's epochs and observation, from its first computed tile where it has none of its own.
first = [];
for i = 1:numel(F.tiles)
    if isstruct(F.tiles(i).F); first = F.tiles(i).F; break; end
end
for f = ["epochs" "observation"]
    if ~isfield(F, f) && ~isempty(first) && isfield(first, f); F.(f) = first.(f); end
end
if ~isfield(F, 'epochs'); F.epochs = []; end
if ~isfield(F, 'observation'); F.observation = struct('kind', "probe", 'label', ""); end
end
