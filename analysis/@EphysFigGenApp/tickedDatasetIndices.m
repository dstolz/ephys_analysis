function idx = tickedDatasetIndices(obj)
%tickedDatasetIndices  The datasets ticked to run (indices into the runner's datasets).
idx = find(obj.Ticked);
end
