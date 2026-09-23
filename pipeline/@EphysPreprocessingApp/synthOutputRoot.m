function root = synthOutputRoot(obj)
%synthOutputRoot  Where the Synthetic tab writes: the Folder box, else <project root>_synthetic.
%   Blank Folder with no project: "" (Generate then asks for a folder).
root = strtrim(string(obj.SynthOutputField.Value));
if root ~= ""; return; end
pr = strtrim(string(obj.RootPathField.Value));
if pr == ""; return; end
pr = regexprep(pr, '[\\/]+$', '');
[parent, leaf] = fileparts(pr);
if leaf == ""; return; end
root = fullfile(parent, leaf + "_synthetic");
end
