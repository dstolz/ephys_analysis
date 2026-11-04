function [ok, why] = ensureManifest(d)
%ensureManifest  Make sure dataset D has its manifest on disk; write it when it has none.
%   [OK, WHY] = ensureManifest(D): OK is true when D.manifestFile() is there,
%   already or after D.writeManifest(). A scan writes every manifest, so a
%   missing one means the folder was not writable then. When OK is false,
%   WHY says why the write failed, ready for an alert.
%
%   See also EphysPipelineApp.onViewManifest, EphysPipelineApp.onCopyManifests.
why = "";
ok = isfile(d.manifestFile());
if ok; return; end
lastwarn("");
ok = d.writeManifest();
if ~ok
    why = string(lastwarn());
    if why == ""; why = "its folder is not there: " + d.Folder; end
end
end
