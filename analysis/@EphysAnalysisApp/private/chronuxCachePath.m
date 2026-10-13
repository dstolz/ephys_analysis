function f = chronuxCachePath(cache, key, name)
%chronuxCachePath  Where the local cache keeps a dataset's Chronux file: <cache>/<key>/<name>_chronux.mat.
%   KEY (the dataset's key: a root-relative folder, or an output folder)
%   becomes folders under CACHE, its drive colon and other characters a
%   file name cannot hold replaced by "_", so two datasets of one name
%   (mouse1/rec, mouse2/rec) keep files of their own. "" when CACHE is "".
f = "";
if cache == ""; return; end
k = regexprep(char(key), '[:*?"<>|]', '_');
k = regexprep(k, '^[\\/]+', '');
f = string(fullfile(cache, k, name + "_chronux.mat"));
end
