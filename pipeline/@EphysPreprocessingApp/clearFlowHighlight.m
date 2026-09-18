function clearFlowHighlight(obj)
%clearFlowHighlight  Put back the look of the controls a Diagram click marked.
%   The highlight onFlowNavigate applies lasts until the next tab change or
%   the next click in the Diagram, whichever comes first.
for k = 1:numel(obj.FlowHighlight)
    h = obj.FlowHighlight(k);
    if isempty(h.Control) || ~isvalid(h.Control); continue; end
    try
        set(h.Control, h.Saved);
    catch
    end
end
obj.FlowHighlight(:) = [];
end
