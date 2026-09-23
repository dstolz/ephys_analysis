function onViewManifest(obj, idx)
%onViewManifest  Open datasets' manifests in ManifestViewerApp windows.
%   onViewManifest(obj) opens the active dataset's (Dataset menu -> View
%   manifest...); onViewManifest(obj, IDX) each of datasets IDX, a window
%   each, cascaded (the Tools panel). The viewer is read-only; its Rewrite
%   button calls the dataset's writeManifest. It is given the config's
%   default probe, which a dataset without a probe of its own is used with
%   (EphysPipeline.probeFor). A dataset without a manifest on disk yet gets
%   one written first (a scan writes them, so this only happens when the
%   folder was not writable then); one that cannot be written is named in
%   an alert. A manifest that cannot be read (not JSON, an unknown schema)
%   still opens: the viewer shows its text and what is wrong with it.
%
%   See also ManifestViewerApp, EphysDataset.writeManifest,
%   EphysPreprocessingApp.onOpenTool.
arguments
    obj (1,1) EphysPreprocessingApp
    idx (1,:) double = obj.SelectedDatasetIdx
end
if isempty(obj.Project) || isempty(idx) || any(idx < 1 | idx > obj.Project.NumDatasets)
    uialert(obj.Fig, "Scan a project and choose a dataset first.", "View manifest");
    return
end
opened = strings(1, 0);
failed = strings(0, 1);
for i = idx
    d = obj.Project.Datasets(i);
    if ~isfile(d.manifestFile())
        lastwarn("");
        if ~d.writeManifest()
            why = string(lastwarn());
            if why == ""; why = "its folder is not there: " + d.Folder; end
            failed(end + 1) = "No manifest for " + d.Name + ", and none could be written: " + why; %#ok<AGROW>
            continue
        end
    end
    v = ManifestViewerApp(d, DefaultProbeFile=obj.Config.Probe.DefaultProbeFile);
    step = 24 * mod(numel(opened), 6);   % each window down and right of the last
    v.Fig.Position(1:2) = v.Fig.Position(1:2) + [step, -step];
    opened(end + 1) = d.Name; %#ok<AGROW>
end
if isscalar(opened)
    obj.setStatus("Opened the manifest of " + opened + ".", "");
elseif ~isempty(opened)
    obj.setStatus(sprintf("Opened the manifests of %d datasets.", numel(opened)), "");
end
if ~isempty(failed)
    uialert(obj.Fig, strjoin(failed, newline), "View manifest");
end
end
