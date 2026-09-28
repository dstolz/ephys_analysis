function onCopy(obj, format)
%onCopy  Put the result table on the clipboard (Copy table / Copy CSV / Copy MATLAB).
txt = obj.copyText(format);
if txt == ""
    obj.setStatus('Nothing to copy: choose a package and a headstage.', true);
    return
end
names = struct('tsv', 'as tab-separated text (paste into Excel)', 'csv', 'as CSV', ...
    'markdown', 'as a Markdown table', 'matlab', 'as MATLAB vectors');
try
    clipboard('copy', char(txt));
    obj.setStatus(sprintf('Copied %d sites %s.', height(obj.Result.Table), names.(char(format))), false);
catch ME
    obj.setStatus("The clipboard is not available here: " + ME.message, true);
end
end
