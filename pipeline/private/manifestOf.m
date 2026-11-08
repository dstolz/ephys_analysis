function file = manifestOf(target, who)
%manifestOf  The manifest file of an EphysDataset, a folder or a file path.
%   FILE = manifestOf(TARGET, WHO) for addToManifest and writeManifestTags:
%   an EphysDataset's own manifest file (one is written first when it has
%   none yet), the one dataset manifest in a folder (session_manifest.json,
%   the Copy tab's, does not count), or the file itself. WHO is the
%   caller's name, the prefix of the error ids: <WHO>:BadInput,
%   :NoManifest, :Ambiguous, :NotFound.
%
%   See also addToManifest, writeManifestTags.
if isa(target, 'EphysDataset') && isscalar(target)
    file = target.manifestFile();
    if ~isfile(file) && ~target.writeManifest()
        error([who ':NoManifest'], 'Could not write a manifest for %s.', target.Name);
    end
    return
end
if ~((ischar(target) && isrow(target)) || (isstring(target) && isscalar(target)))
    error([who ':BadInput'], 'TARGET must be one EphysDataset, a folder or a manifest file.');
end
target = string(target);
if isfile(target)
    file = target;
elseif isfolder(target)
    d = dir(fullfile(target, '*_manifest.json'));
    d = d(~strcmpi({d.name}, 'session_manifest.json'));
    if isempty(d)
        error([who ':NoManifest'], ...
            'No dataset manifest in %s. EphysDataset(folder).writeManifest() writes one.', target);
    elseif ~isscalar(d)
        error([who ':Ambiguous'], '%d dataset manifests in %s (%s): name the file.', ...
            numel(d), target, strjoin(string({d.name}), ", "));
    end
    file = string(fullfile(d.folder, d.name));
else
    error([who ':NotFound'], 'No such file or folder: %s', target);
end
end
