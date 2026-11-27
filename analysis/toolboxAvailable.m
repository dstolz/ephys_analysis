function tf = toolboxAvailable(name, feature)
%toolboxAvailable  Whether a MathWorks toolbox is installed and licensed.
%   TF = toolboxAvailable(NAME, FEATURE) is true when ver(NAME) finds the
%   toolbox (NAME as ver names it: "images", "parallel", "stats") and
%   license('test', FEATURE) says it is licensed (FEATURE as license names
%   it: "Image_Toolbox", "Distrib_Computing_Toolbox",
%   "Statistics_Toolbox"). Both are needed: license('test') reports a
%   license the user holds, whether or not the toolbox is installed here,
%   so a function of it can still be missing. The answer is kept for the
%   session (ver reads every toolbox's folder: it is slow).
%
%   Example: toolboxAvailable("images", "Image_Toolbox")
arguments
    name (1,1) string
    feature (1,1) string
end
persistent seen
if isempty(seen); seen = containers.Map('KeyType', 'char', 'ValueType', 'logical'); end
key = char(name + "|" + feature);
if ~isKey(seen, key)
    seen(key) = ~isempty(ver(char(name))) && license('test', char(feature));
end
tf = seen(key);
end
