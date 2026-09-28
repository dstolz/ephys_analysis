function onFaceClick(obj, key, evt)
%onFaceClick  A click on a connector face: select the pin under it (and its site).
%   KEY is the face ("package:main", "headstage[1]:top"); EVT carries
%   IntersectionPoint, which the face's frame (drawFace) turns back into
%   the face's own (row, column). Right clicks are ignored.
try
    if string(obj.Fig.SelectionType) == "alt"
        return
    end
catch
end
k = find(strsOf(obj.FaceDraw, 'Key') == string(key), 1);
if isempty(k)
    return
end
d = obj.FaceDraw(k);
pt = evt.IntersectionPoint;
dx = round(pt(1) - d.Origin(1));
dy = round(pt(2) - d.Origin(2));
switch d.Mirror
    case "reference"
        c = d.Cols + 1 - dx; r = dy;
    case "rotated"
        c = dx; r = d.Rows + 1 - dy;
    otherwise
        c = dx; r = dy;
end
if r < 1 || r > d.Rows || c < 1 || c > d.Cols
    return
end
obj.select("cell", struct('face', string(key), 'cell', [r c]));
end
