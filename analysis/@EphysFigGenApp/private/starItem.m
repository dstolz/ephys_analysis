function ok = starItem(obj, idx, level, id, tf)
%starItem  Star (TF true) or unstar a dataset, channel or unit of dataset IDX, write it at once and show it everywhere.
%   LEVEL "dataset" | "channel" | "unit" and ID as DatasetFavorites.star.
%   The status bar says what changed and where it is kept. When the file
%   cannot be written (an output folder on a read-only share, a folder not
%   there, a favorites file that cannot be read) nothing changes and the
%   status bar and the Log say why; OK is false. Either way the toggles,
%   the table and the lists show the stars as they are (refreshFavorites).
%
%   See also DatasetFavorites, onStarToggled, onDatasetsTableEdited.
ok = false;
if isempty(obj.Runner) || idx < 1 || idx > numel(obj.Favorites); return; end
fav = obj.Favorites(idx);
what = obj.Runner.Names(idx);
if level ~= "dataset"; what = what + " · " + level + " " + id; end
try
    fav.star(level, id, tf);
    ok = true;
catch ME
    msg = sprintf("%s not %s: %s", what, ternary(tf, "starred", "unstarred"), ME.message);
    obj.log(msg);
    obj.refreshFavorites();
    obj.setStatus(msg);
    return
end
[~, f, e] = fileparts(fav.File);
obj.setStatus(sprintf("%s %s (kept in %s%s).", ternary(tf, "Starred", "Unstarred"), what, f, e));
obj.refreshFavorites();
end


function s = ternary(c, a, b)
if c; s = a; else; s = b; end
end
