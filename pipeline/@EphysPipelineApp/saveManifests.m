function ok = saveManifests(obj, ds)
%saveManifests  Write the manifests of datasets DS after a per-dataset edit.
%   OK(k) is true when DS(k)'s manifest was written
%   (EphysDataset.writeManifest). One that cannot be read (not valid JSON,
%   an unknown schema) is never overwritten, and a dataset whose folder is
%   not there has none: the edit then holds only until the next scan, so an
%   alert names those datasets and why, and the status bar says so.
ok = true(1, numel(ds));
why = strings(0, 1);
for k = 1:numel(ds)
    lastwarn("");
    ok(k) = ds(k).writeManifest();
    if ~ok(k)
        msg = string(lastwarn());
        if msg == ""; msg = "its folder is not there: " + ds(k).Folder; end
        why(end+1, 1) = ds(k).Name + ": " + msg; %#ok<AGROW>
    end
end
if all(ok); return; end
obj.setStatus(sprintf("%d dataset manifest(s) not written: the change holds until the next scan.", nnz(~ok)), ...
    "Fix or delete the manifest file, then make the change again.");
uialert(obj.Fig, strjoin(["The change is not saved in these datasets' manifests, so it holds only until the next scan:"; ""; ...
    why; ""; "Fix or delete the manifest file, then make the change again."], newline), ...
    "Manifest not written", "Icon", "warning");
end
