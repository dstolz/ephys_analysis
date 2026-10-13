function [events, info, changed] = mergeDerivedEvents(events, info, D)
%mergeDerivedEvents  An extract's events with the derived events marked InDataset.
%   [EVENTS, INFO, CHANGED] = mergeDerivedEvents(EVENTS, INFO, D) takes out
%   of EVENTS the derived lines INFO.derivedEvents lists (those an earlier
%   write added), adds every element of D (deriveEvents' D) with inDataset
%   set, and sets INFO.derivedEvents to the definitions of those lines
%   (name, line, conditions, combine, expression, description; 1 x 0 when
%   none). A derived name that is a recorded line of EVENTS is an error
%   (EphysDataset:DerivedEvents:Clash). CHANGED says whether EVENTS or
%   INFO.derivedEvents differ from what was given. Shared by toMat and
%   writeExtractEvents.

if ~isstruct(events) || isempty(events); events = struct(); end
before = events;
oldDefs = [];
if isfield(info, 'derivedEvents'); oldDefs = info.derivedEvents; end
if isstruct(oldDefs) && isfield(oldDefs, 'name')
    for nm = reshape(string({oldDefs.name}), 1, [])
        if isfield(events, nm); events = rmfield(events, nm); end
    end
end
defs = repmat(struct('name', "", 'line', "", 'conditions', string.empty(1, 0), 'combine', "all", ...
    'expression', "", 'description', ""), 1, 0);
for k = 1:numel(D)
    if ~D(k).inDataset; continue; end
    nm = string(D(k).name);
    if isfield(events, nm)
        error('EphysDataset:DerivedEvents:Clash', ...
            'The derived event "%s" has the name of a recorded line of the extract.', nm);
    end
    events.(nm) = D(k).intervals;
    defs(end+1) = struct('name', nm, 'line', string(D(k).line), ...
        'conditions', reshape(string(D(k).conditions), 1, []), 'combine', string(D(k).combine), ...
        'expression', string(D(k).expression), 'description', string(D(k).description)); %#ok<AGROW>
end
changed = ~isequaln(events, before) || (~(isempty(oldDefs) && isempty(defs)) && ~isequaln(oldDefs, defs));
info.derivedEvents = defs;
end
