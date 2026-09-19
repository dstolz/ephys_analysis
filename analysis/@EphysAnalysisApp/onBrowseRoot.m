function onBrowseRoot(obj, which)
%onBrowseRoot  Pick the project root ("root") or the output root ("output").
if which == "root"; field = obj.RootField; else; field = obj.OutputRootField; end
start = char(field.Value);
if isempty(start) || ~isfolder(start); start = pwd; end
d = uigetdir(start, "Choose the " + which + " folder");
figure(obj.Fig);
if isequal(d, 0); return; end
field.Value = d;
obj.onConfigChanged("source");
end
