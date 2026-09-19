function buildLogTab(obj)
%buildLogTab  What the runner and the app reported, one line each.
g = uigridlayout(obj.TabLog, [1 1]);
g.Padding = [8 8 8 8];
obj.LogArea = uitextarea(g, "Editable", "off", "FontName", "Consolas", "Value", {''});
end
