function tags = writeManifestTags(target, tags)
%writeManifestTags  Write a dataset's tags into its manifest, without the dataset.
%   TAGS = writeManifestTags(TARGET, TAGS) makes TAGS the dataset's tag set:
%   the top-level "tags" array of its <Name>_manifest.json. TAGS is
%   anything TagSet.require takes (a string array, a cellstr, {} or "" for
%   none). The set written comes back as TagSet keeps it: unique, sorted,
%   lowercase, {} when empty.
%
%   TARGET is one of
%     a file           the manifest itself
%     a folder         holding one dataset manifest (session_manifest.json,
%                      the Copy tab's, does not count)
%     an EphysDataset  its Tags are set and its manifest written
%                      (writeManifest), so the object and the file agree
%
%   For a file or a folder only the tags and the "updated" time change: the
%   new array is spliced into the file's text, as addToManifest splices its
%   custom block, so nothing else is decoded and encoded again and no
%   recording is needed (the outputs copied to another disk keep their
%   manifest beside them). It is how DatasetBrowser edits tags. An app or a
%   project holding the dataset reads the new tags back the next time it
%   writes the manifest (EphysDataset.writeManifest), unless it changed the
%   dataset's tags itself since it last read the file; a scan
%   (applyManifest) reads them too.
%
%   The manifest counts in outputsStamp, so a dataset's results in a
%   DatasetRuns folder are computed again after this, as after a tag edit
%   in the pipeline app.
%
%   Errors (nothing is written): TagSet:Invalid (a tag breaks the rules),
%   TagSet:TooMany (more than TagSet.MaxTags), writeManifestTags:BadInput,
%   :NotFound (no such file or folder), :NoManifest, :Ambiguous (a folder of
%   several manifests: name the file), :Unreadable (not JSON or an unknown
%   schema), :NotWritten (an EphysDataset whose manifest could not be
%   written; writeManifest warns why).
%
%   Example
%     writeManifestTags("S:\outputs\subjA_260101_120000", ["ofc" "cohort-3"]);
%     t = TagSet.add(outputTags(out), "pilot");
%     writeManifestTags(out.ManifestFile, t);
%
%   See also TagSet, outputTags, addToManifest, EphysDataset.writeManifest,
%   DatasetBrowser.setTags.

tags = TagSet.require(tags);
if isa(target, 'EphysDataset')
    if ~isscalar(target)
        error('writeManifestTags:BadInput', 'TARGET must be one EphysDataset, a folder or a manifest file.');
    end
    target.Tags = tags;
    if ~target.writeManifest()
        error('writeManifestTags:NotWritten', 'Could not write the manifest of %s.', target.Name);
    end
    return
end

file = manifestOf(target, 'writeManifestTags');
[~, why] = EphysDataset.readManifest(file);
if why ~= ""
    error('writeManifestTags:Unreadable', 'Cannot write the tags of %s: %s.', file, why);
end
txt = fileread(file);
txt = setJsonMember(txt, 'tags', tags, 'writeManifestTags');
txt = setJsonMember(txt, 'updated', string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), 'writeManifestTags');
try
    jsondecode(txt);
catch ME
    error('writeManifestTags:Unreadable', 'Cannot write the tags of %s: %s', file, ME.message);
end
writeJsonFile(file, txt, Text=true);
end
