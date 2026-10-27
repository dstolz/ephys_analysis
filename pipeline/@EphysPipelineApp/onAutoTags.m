function onAutoTags(obj, action, evt)
%onAutoTags  The tags for new datasets, beside Scan: "Tag new datasets:", its field and Choose...
%   They are the config's Project.AutoTag (the checkbox) and
%   Project.NewDatasetTags (the field, comma-separated), so each project
%   keeps its own. A scan gives these tags to each dataset it finds for the
%   first time, one with no manifest yet (EphysProject.refresh, NewTags;
%   see onScan); datasets scanned before keep theirs.
%
%   obj.onAutoTags("field", EVT): the field was edited. The text is read
%   as TagSet reads it: an entry that is no tag, or more than
%   TagSet.MaxTags, is refused with an alert and the field keeps its last
%   value; otherwise the field shows the set (lowercase, sorted). The first
%   tag typed ticks the checkbox, and clearing the field unticks it.
%   obj.onAutoTags("check"): the checkbox was clicked; ticked while the
%   field is empty, it opens Choose....
%   obj.onAutoTags("choose"): Choose... opens the tag dialog (TagDialog,
%   single mode, kept in obj.TagDialog) on the field's tags, offering the
%   tags in use on the project's datasets. OK puts the set in the field and
%   ticks the checkbox (unticks it for none); Cancel changes nothing, but a
%   checkbox ticked with no tags is unticked again.
%
%   A change marks the config unsaved, and the status bar says what the
%   next scan will do.
%
%   See also onScan, onEditTags, TagDialog, TagSet.
switch action
    case "field"
        [tags, ~, why] = TagSet.fromText(evt.Value, TagSet.EntryDelimiter);
        [fits, msg] = TagSet.checkCount(tags);
        if ~isempty(why) || ~fits
            obj.AutoTagField.Value = evt.PreviousValue;
            uialert(obj.Fig, strjoin([why, msg(~fits)], newline), "Tags for new datasets");
            return
        end
        obj.AutoTagField.Value = char(TagSet.toText(tags, TagSet.DisplayDelimiter));
        if isempty(tags)
            obj.AutoTagCheckBox.Value = false;
        elseif isempty(TagSet.fromText(evt.PreviousValue, TagSet.EntryDelimiter))
            obj.AutoTagCheckBox.Value = true;
        end
    case "check"
        if obj.AutoTagCheckBox.Value && isempty(fieldTags(obj))
            openChooser(obj);   % ticked with nothing to give: pick the tags
            return
        end
    case "choose"
        openChooser(obj);
        return
end
obj.onConfigChanged();
obj.setStatus(autoTagStatus(obj));
end


function openChooser(obj)
%openChooser  The tag dialog over the field's tags; one tag dialog at a time.
dlg = obj.TagDialog;
if ~isempty(dlg) && isvalid(dlg) && isvalid(dlg.Fig)
    figure(dlg.Fig);
    return
end
vocab = {};
if ~isempty(obj.Project) && obj.Project.NumDatasets > 0
    vocab = TagSet.vocabulary(arrayfun(@(d) d.Tags, obj.Project.Datasets, 'UniformOutput', false));
end
obj.TagDialog = TagDialog({fieldTags(obj)}, vocab, Labels="new datasets", Parent=obj.Fig, ...
    OnDone=@(r) chosen(obj, r));
end


function chosen(obj, r)
%chosen  The dialog closed: R is [] (canceled, or no change) or its result.
if isempty(r)
    if obj.AutoTagCheckBox.Value && isempty(fieldTags(obj))
        obj.AutoTagCheckBox.Value = false;
    end
    return
end
tags = r.sets{1};
obj.AutoTagField.Value = char(TagSet.toText(tags, TagSet.DisplayDelimiter));
obj.AutoTagCheckBox.Value = ~isempty(tags);
obj.onConfigChanged();
obj.setStatus(autoTagStatus(obj));
end


function t = fieldTags(obj)
t = TagSet.fromText(obj.AutoTagField.Value, TagSet.EntryDelimiter);
end


function s = autoTagStatus(obj)
%autoTagStatus  What the next scan does with a dataset it finds for the first time.
tags = TagSet.toText(fieldTags(obj), TagSet.DisplayDelimiter);
if tags == ""
    s = "New datasets are not tagged.";
elseif obj.AutoTagCheckBox.Value
    s = "Each dataset a scan finds for the first time will be tagged " + tags + ".";
else
    s = "New datasets are not tagged: Tag new datasets is off.";
end
end
