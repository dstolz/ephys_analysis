function saveTableSorts(obj)
%saveTableSorts  Save the sortable tables' sorts (TableSorts) as the TableSorts preference.
AppPrefs.setpref(obj.PrefGroup, 'TableSorts', TableSort.toPref(obj.TableSorts));
end
