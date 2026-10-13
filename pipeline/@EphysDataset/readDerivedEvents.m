function D = readDerivedEvents(obj, opts)
%readDerivedEvents  The derived events of this dataset's behavior file.
%   D = ds.readDerivedEvents() returns behavior.derivedEvents of
%   <outputFolder>/<Name>_behavior.mat (deriveEvents' D: name, line,
%   conditions, combine, inDataset, intervals, ... one element per derived
%   event), or an empty (1 x 0) D when there is no behavior file or it has
%   none. The behavior step computes them (behaviorStruct); the extract
%   (toMat, writeExtractEvents), the exports (every format) and the analysis
%   (loadAnalysisSource) take them from there.
%
%   Options
%     File       the behavior file ("" = the default), or a behaviorStruct
%
%   See also deriveEvents, EphysDataset.behaviorStruct,
%   EphysDataset.writeExtractEvents.

arguments
    obj (1,1) EphysDataset
    opts.File = ""
end

[~, D] = deriveEvents(struct(), table(), []);
b = opts.File;
if ~isstruct(b)
    f = string(b);
    if f == ""
        f = string(fullfile(obj.outputFolder(), obj.Name + "_behavior.mat"));
    end
    if ~isfile(f)
        return
    end
    w = whos('-file', f);
    if ~any(string({w.name}) == "behavior")
        return
    end
    L = load(f, 'behavior');
    b = L.behavior;
end
if isfield(b, 'derivedEvents') && isstruct(b.derivedEvents) && ~isempty(b.derivedEvents)
    D = reshape(b.derivedEvents, 1, []);
end
end
