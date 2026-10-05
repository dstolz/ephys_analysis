function tf = isAuroc(R)
%isAuroc  True for a spikePSTH result whose curves are auROCs (BaselineMode "auroc": R.auroc set).
tf = isfield(R, 'auroc') && isstruct(R.auroc) && ~isempty(R.auroc);
end
