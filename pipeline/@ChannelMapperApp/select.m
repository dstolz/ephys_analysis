function select(obj, kind, key)
%select  Select a site, a result-table row or a connector pin, everywhere.
%   select("site", 18); select("row", 3) (a row of the table as shown);
%   select("cell", struct('face', "package:main", 'cell', [1 3])). A pin
%   that carries a site selects that site (a headstage pin selects the site
%   wired to it); a GND / REF / unused pin selects just that pin and the
%   pin it meets. select("none") clears it.
sel = struct('site', NaN, 'face', "", 'cell', [NaN NaN]);
R = obj.Result;
switch string(kind)
    case "site"
        if ~isempty(R) && any(R.Table.Site == key)
            sel.site = double(key);
        end
    case "row"
        if key >= 1 && key <= numel(obj.ResultOrder)
            sel.site = R.Table.Site(obj.ResultOrder(key));
        end
    case "cell"
        sel.face = string(key.face);
        sel.cell = double(key.cell);
        sel.site = siteAtCell(R, sel.face, sel.cell);
    case "none"
    otherwise
        error('ChannelMapperApp:BadSelection', 'select: kind is site, row, cell or none.');
end
obj.Selection = sel;
obj.applySelection();
end


function s = siteAtCell(R, face, rc)
%siteAtCell  The site a pin carries (package) or is wired to (headstage), NaN if none.
s = NaN;
if isempty(R)
    return
end
pkg = R.Chain.package;
if startsWith(face, "package:")
    f = find(strsOf(pkg.Faces, 'Id') == extractAfter(face, "package:"), 1);
    if isempty(f); return; end
    v = str2double(pkg.Faces(f).Cells(rc(1), rc(2)));
    if isfinite(v) && any(R.Table.Site == v)
        s = v;
    end
    return
end
tok = regexp(face, '^headstage\[(\d+)\]:(.+)$', 'tokens', 'once');
if isempty(tok); return; end
i = str2double(tok(1));
hf = find(strsOf(R.Chain.headstages(i).Entry.Faces, 'Id') == tok(2), 1);
for k = 1:numel(R.Path)
    p = R.Path(k);
    if isequal(p.HsIndex, i) && isequal(p.HsFace, hf) && isequal(p.HsCell, rc)
        s = p.Site;
        return
    end
end
end
