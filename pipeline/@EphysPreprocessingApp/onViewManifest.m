function onViewManifest(obj)
%onViewManifest  Open the active dataset's manifest in a ManifestViewerApp.
%   Dataset menu -> View manifest... The viewer is read-only; its Rewrite
%   button calls the dataset's writeManifest. It is given the config's
%   default probe, which a dataset without a probe of its own is used with
%   (EphysPipeline.probeFor). A dataset without a manifest on disk yet gets
%   one written first (a scan writes them, so this only happens when the
%   folder was not writable then). A manifest that cannot be read (not
%   JSON, an unknown schema) still opens: the viewer shows its text and
%   what is wrong with it.
%
%   See also ManifestViewerApp, EphysDataset.writeManifest.

d = obj.currentDataset();
if isempty(d)
    uialert(obj.Fig, "Scan a project and choose a dataset first.", "View manifest");
    return
end
if ~isfile(d.manifestFile())
    lastwarn("");
    if ~d.writeManifest()
        why = string(lastwarn());
        if why == ""; why = "its folder is not there: " + d.Folder; end
        uialert(obj.Fig, "No manifest for " + d.Name + ", and none could be written: " + why, ...
            "View manifest");
        return
    end
end
ManifestViewerApp(d, DefaultProbeFile=obj.Config.Probe.DefaultProbeFile);
obj.setStatus("Opened the manifest of " + d.Name + ".", "");
end
