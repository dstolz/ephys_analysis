function onReviewSortChanged(obj)
%onReviewSortChanged  Load the sort chosen in the Review tab's Sort dropdown.
%   Any of the active dataset's sorts (syncReviewDataset lists them), read
%   as Load reads a folder; the choice changes nothing the other steps read
%   (the Sorting tab's Use folder... does).
folder = string(obj.ReviewSortDropDown.Value);
if folder == ""; return; end
obj.ReviewFolderField.Value = char(folder);
obj.savePreferences();
try
    obj.loadReviewResults();
catch
    % loadReviewResults has already reported the failure in an alert.
end
end
