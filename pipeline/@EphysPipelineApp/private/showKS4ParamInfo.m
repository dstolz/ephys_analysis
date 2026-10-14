function d = showKS4ParamInfo(obj, name)
%showKS4ParamInfo  Modal window: what the Kilosort4 parameter NAME is, does and how to tune it.
%   D = showKS4ParamInfo(OBJ, NAME) opens it over the app (Tag
%   "KS4ParamInfo") with the parameter's definition, function, impact,
%   tuning and defaults (this pipeline's and Kilosort4's) from ks4ParamHelp,
%   each under a bold header (an HTML label).
%   Clicking a parameter's name on the Sorting tab opens it
%   (buildSortingTab); Close or Esc closes it.
spec = EphysPipelineConfig.kilosortParamSpec();
s = spec(strcmp({spec.name}, name));
H = ks4ParamHelp();
h = H.(name);
switch s.kind
    case 'bool'
        mine = string(mat2str(logical(s.default)));
    otherwise
        mine = string(s.default);
        if mine == ""; mine = "blank (auto)"; end
end

p = obj.Fig.Position;
w = 520;
ht = 480;
d = uifigure("Name", "Kilosort4: " + name, "Tag", "KS4ParamInfo", "WindowStyle", "modal", ...
    "Position", [p(1) + (p(3) - w) / 2, p(2) + (p(4) - ht) / 2, w, ht], ...
    "KeyPressFcn", @(src, ev) closeOnEsc(src, ev));
g = uigridlayout(d, [3 2], "RowHeight", {'fit', '1x', 30}, "ColumnWidth", {'1x', 90});
t = uilabel(g, "Text", name + "   (" + s.group + ")", "FontWeight", "bold", "FontSize", 14);
t.Layout.Row = 1; t.Layout.Column = [1 2];
% The sections as HTML, so their headers can be bold; scrolls when long.
sections = ["DEFINITION" "FUNCTION" "IMPACT" "TUNING" "DEFAULT"
    esc(h.definition) esc(h.function) esc(h.impact) esc(h.tuning) ...
    "This pipeline: " + esc(mine) + "<br>Kilosort4 4.1.7: " + esc(h.ks4default)];
html = join("<p><b>" + sections(1, :) + "</b><br>" + sections(2, :) + "</p>", "<br>");   % the label drops <p> margins
box = uipanel(g, "BackgroundColor", [1 1 1]);
box.Layout.Row = 2; box.Layout.Column = [1 2];
bg = uigridlayout(box, [1 1], "RowHeight", {'fit'}, "Scrollable", "on", "BackgroundColor", [1 1 1]);
uilabel(bg, "Interpreter", "html", "WordWrap", "on", "VerticalAlignment", "top", "Text", html);
b = uibutton(g, "Text", "Close", "ButtonPushedFcn", @(~,~) delete(d));
b.Layout.Row = 3; b.Layout.Column = 2;
end


function s = esc(s)
%esc  S as HTML text.
s = replace(string(s), ["&" "<" ">"], ["&amp;" "&lt;" "&gt;"]);
end


function closeOnEsc(fig, ev)
%closeOnEsc  Esc closes the window.
if ev.Key == "escape"; delete(fig); end
end
