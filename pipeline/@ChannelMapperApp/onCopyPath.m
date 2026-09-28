function onCopyPath(obj)
%onCopyPath  Put the selected site's (or pin's) path on the clipboard.
txt = string(obj.PathLabel.Text);
if ~isfinite(obj.Selection.site) && obj.Selection.face == ""
    obj.setStatus('Select a site, a pin or a table row first.', true);
    return
end
try
    clipboard('copy', char(txt));
    obj.setStatus('Copied the path.', false);
catch ME
    obj.setStatus("The clipboard is not available here: " + ME.message, true);
end
end
