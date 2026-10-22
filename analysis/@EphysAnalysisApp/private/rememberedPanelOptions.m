function o = rememberedPanelOptions(obj, type, params)
%rememberedPanelOptions  The options remembered for panel type TYPE that a new panel may take: a partial options struct.
%   O = rememberedPanelOptions(OBJ, TYPE, PARAMS) reads
%   obj.PanelOptions.(TYPE) (rememberPanelOptions) and keeps what still
%   fits the type: an option the type has (panelTypes' DefaultOptions),
%   of the same class as its default (a struct option field by field,
%   filled out from the default), so preferences written by older code
%   cannot break a panel. A rasterSort, param or seriesParam naming a
%   trial parameter is kept only when PARAMS (the active dataset's trial
%   parameters) has it ("" and a rasterSort of "stop" always). O is empty
%   (struct()) for a type with nothing remembered. onNewPanel merges it
%   over the type's defaults, under what the New panel window or the
%   caller gives.
%
%   See also rememberPanelOptions, EphysAnalysisApp.onNewPanel.
arguments
    obj (1,1) EphysAnalysisApp
    type (1,1) string
    params (1,:) string = string.empty(1, 0)
end
o = struct();
if ~isfield(obj.PanelOptions, type); return; end
PT = EphysAnalysisConfig.panelTypes();
row = PT.Type == type;
if ~any(row); return; end
o = fit(obj.PanelOptions.(type), PT.DefaultOptions{row});
for f = ["rasterSort" "param" "seriesParam"]   % a trial parameter of one dataset
    if ~isfield(o, f); continue; end
    v = string(o.(f));
    if ~(isscalar(v) && (v == "" || (f == "rasterSort" && v == "stop") || ismember(v, params)))
        o = rmfield(o, f);
    end
end
end


function o = fit(m, def)
%fit  The fields of M that DEF has, of DEF's class; a struct field filled out from DEF's.
o = struct();
if ~isstruct(m) || ~isscalar(m); return; end
for f = string(fieldnames(m)).'
    if ~isfield(def, f); continue; end
    v = m.(f);
    d = def.(f);
    if isstruct(d) && isscalar(d)
        if ~isstruct(v) || ~isscalar(v); continue; end
        part = fit(v, d);
        for g = string(fieldnames(part)).'
            d.(g) = part.(g);
        end
        o.(f) = d;
    elseif (isnumeric(d) && isnumeric(v)) || (islogical(d) && islogical(v)) || (isstring(d) && isstring(v) && isscalar(v))
        o.(f) = v;
    end
end
end
