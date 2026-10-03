function onTableSortMenu(obj, menu, id)
%onTableSortMenu  Build sortable table ID's context menu as it opens.
%   One item, Clear sort (sortMenuItem), naming the sort it clears.
arguments
    obj (1,1) EphysPreprocessingApp
    menu
    id (1,1) string
end
delete(menu.Children);
sortMenuItem(obj, menu, id);
end
