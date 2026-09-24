function offerItems(dd, items, v)
%offerItems  List ITEMS in the drop-down DD and show V (added when not among them).
%   offerItems(DD, ITEMS) keeps DD's value. A value the list lacks stays
%   listed, so what the config holds is always what the box shows (Validate
%   reports it).
if nargin < 3; v = string(dd.Value); end
items = reshape(string(items), 1, []);
v = string(v);
if ~ismember(v, items); items = [items v]; end
dd.Items = items;
dd.Value = char(v);
end
