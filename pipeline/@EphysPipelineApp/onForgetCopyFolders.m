function onForgetCopyFolders(obj, field)
%onForgetCopyFolders  Ask which entries to remove from a Copy tab root or destination list.
%   The Forget... button beside each box: a list of the box's entries, the
%   one it shows selected at first. The entries picked go to
%   forgetCopyFolders. Nothing on disk is touched.
%
%   See also rememberCopyFolder, forgetCopyFolders.
items = string(field.Items);
if isempty(items)
    uialert(obj.Fig, "The list is empty. Folders are added to it as you type, pick or browse to them.", ...
        "Forget folders", "Icon", "info");
    return
end
pick = pickEntries(obj.Fig, items, string(field.Value));
figure(obj.Fig);   % restore focus after the modal window
if ~isempty(pick)
    obj.forgetCopyFolders(field, items(pick));
end
end


function pick = pickEntries(parent, items, shown)
%pickEntries  Modal list of ITEMS; the indices picked ([] = none).
pick = [];
p = parent.Position;
w = 560;
h = 140 + 22 * min(numel(items), 10);
d = uifigure("Name", "Forget folders", "WindowStyle", "modal", ...
    "Position", [p(1) + (p(3) - w) / 2, p(2) + (p(4) - h) / 2, w, h]);
g = uigridlayout(d, [3 3], "RowHeight", {'fit', '1x', 30}, "ColumnWidth", {'1x', 'fit', 'fit'});
l = uilabel(g, "WordWrap", "on", "Text", ...
    "Remove the selected entries from the list (Ctrl- or Shift-click to select several). " + ...
    "Only the list changes: no folder is touched.");
l.Layout.Row = 1; l.Layout.Column = [1 3];
lb = uilistbox(g, "Items", items, "ItemsData", 1:numel(items), "Multiselect", "on", ...
    "Value", find(items == shown, 1));
lb.Layout.Row = 2; lb.Layout.Column = [1 3];
b = uibutton(g, "Text", "Forget selected", "ButtonPushedFcn", @(~,~) finish(true));
b.Layout.Row = 3; b.Layout.Column = 2;
styleButton(b, "primary");
b = uibutton(g, "Text", "Cancel", "ButtonPushedFcn", @(~,~) finish(false));
b.Layout.Row = 3; b.Layout.Column = 3;
styleButton(b);
uiwait(d);

    function finish(forget)
        if forget
            pick = lb.Value;
        end
        delete(d);
    end
end
