function applySelection(obj)
%applySelection  Show obj.Selection in the table, on the probe, on the faces and as a path.
%   The selected site's package pin and headstage pin turn amber (only the
%   patches' FaceVertexCData rows change; nothing is redrawn), the ring
%   moves onto the site, its table row is selected and scrolled to, and
%   the path label reads ChannelMap.pathText. A pin without a site lights
%   that pin and the one it meets. Syncing is set meanwhile, so setting
%   the table's selection does not select again.
if obj.Syncing
    return
end
obj.Syncing = true;
c = onCleanup(@() resetFlag(obj, 'Syncing'));
amber = obj.Colors.selected;
for k = 1:numel(obj.FaceDraw)
    if isvalid(obj.FaceDraw(k).Patch)
        obj.FaceDraw(k).Patch.FaceVertexCData = obj.FaceDraw(k).Base;
    end
end
R = obj.Result;
sel = obj.Selection;
light = struct('key', {}, 'cell', {});
row = [];
xy = [NaN NaN];
if isempty(R)
    txt = "";
elseif isfinite(sel.site)
    k = find(R.Table.Site == sel.site, 1);
    p = R.Path(k);
    pkg = R.Chain.package;
    if isfinite(p.PkgFace)
        light(end + 1) = struct('key', "package:" + pkg.Faces(p.PkgFace).Id, 'cell', p.PkgCell);
    end
    if isfinite(p.HsIndex)
        light(end + 1) = struct('key', sprintf("headstage[%d]:%s", p.HsIndex, ...
            R.Chain.headstages(p.HsIndex).Entry.Faces(p.HsFace).Id), 'cell', p.HsCell);
    end
    row = find(obj.ResultOrder == k, 1);
    xy = [R.Table.X(k) R.Table.Y(k)];
    txt = ChannelMap.pathText(R, sel.site);
elseif sel.face ~= ""
    light(end + 1) = struct('key', sel.face, 'cell', sel.cell);
    [other, txt] = mateOf(R, sel.face, sel.cell);
    if ~isempty(other)
        light(end + 1) = other;
    end
else
    txt = "Click a site, a pin or a table row to see its path.";
end

for q = 1:numel(light)
    k = find(strsOf(obj.FaceDraw, 'Key') == light(q).key, 1);
    if isempty(k) || ~isvalid(obj.FaceDraw(k).Patch); continue; end
    d = obj.FaceDraw(k);
    idx = sub2ind([d.Rows d.Cols], light(q).cell(1), light(q).cell(2));
    d.Patch.FaceVertexCData(idx, :) = amber;
end
if ~isempty(obj.SelMarker) && isvalid(obj.SelMarker)
    obj.SelMarker.XData = xy(1);
    obj.SelMarker.YData = xy(2);
end
try
    if isempty(row)
        obj.ResultTable.Selection = [];
    else
        obj.ResultTable.Selection = row;
        scroll(obj.ResultTable, 'row', row);
    end
catch
end
obj.PathLabel.Text = char(txt);
end


function [other, txt] = mateOf(R, face, rc)
%mateOf  The pin a pin meets, and a line saying so.
other = struct('key', {}, 'cell', {});
chain = R.Chain;
pkg = chain.package;
[cells, name] = faceCells(chain, face);
if isempty(cells)
    txt = "";
    return
end
here = name + " " + ChannelMap.pinName(cells, rc(1), rc(2)) + " is " + cells(rc(1), rc(2));
txt = here + "; it is not mated.";
for m = 1:numel(R.Mates)
    mi = R.Mates(m);
    if ~isfinite(mi.HsIndex) || isempty(mi.Map) || width(mi.Map) == 0; continue; end
    upKey = "package:" + pkg.Faces(mi.PkgFace).Id;
    dnKey = sprintf("headstage[%d]:%s", mi.HsIndex, chain.headstages(mi.HsIndex).Entry.Faces(mi.HsFace).Id);
    M = mi.Map;
    if face == upKey
        j = find(M.UpRow == rc(1) & M.UpCol == rc(2), 1);
        other(1).key = dnKey;
        other(1).cell = [M.DownRow(j) M.DownCol(j)];
        [oc, on] = faceCells(chain, dnKey);
        txt = here + "; it meets " + on + " " + ChannelMap.pinName(oc, M.DownRow(j), M.DownCol(j)) + ...
            " (" + M.DownValue(j) + ", " + mi.Orientation + ").";
        return
    elseif face == dnKey
        j = find(M.DownRow == rc(1) & M.DownCol == rc(2), 1);
        other(1).key = upKey;
        other(1).cell = [M.UpRow(j) M.UpCol(j)];
        [oc, on] = faceCells(chain, upKey);
        txt = here + "; it meets " + on + " " + ChannelMap.pinName(oc, M.UpRow(j), M.UpCol(j)) + ...
            " (" + M.UpValue(j) + ", " + mi.Orientation + ").";
        return
    end
end
end


function [cells, name] = faceCells(chain, key)
%faceCells  A drawn face's cells and a name for it ("H32 main", "RHD2132-32ch #2 main").
cells = strings(0, 0);
name = "";
if startsWith(key, "package:")
    f = find(strsOf(chain.package.Faces, 'Id') == extractAfter(key, "package:"), 1);
    if isempty(f); return; end
    cells = chain.package.Faces(f).Cells;
    name = chain.package.Name + " " + chain.package.Faces(f).Id;
    return
end
tok = regexp(key, '^headstage\[(\d+)\]:(.+)$', 'tokens', 'once');
if isempty(tok); return; end
i = str2double(tok(1));
e = chain.headstages(i).Entry;
f = find(strsOf(e.Faces, 'Id') == tok(2), 1);
if isempty(f); return; end
cells = e.Faces(f).Cells;
name = e.Name;
if numel(chain.headstages) > 1
    name = name + " #" + i;
end
name = name + " " + e.Faces(f).Id;
end
