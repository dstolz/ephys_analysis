function runExport(obj, opts)
%runExport  NWB 2 files per dataset, one per format (export<Format>).
%   The continuous signals come from the Signals step's extract file(s)
%   (exportExtractFiles: per-type files of signals Export.Signals leaves
%   out are not read), the sorted units from the sorting association (with
%   their quality metrics, Export.UnitQuality), events as configured. The
%   "nwb" format writes an NWB 2 file through Python (exportNWB:
%   Export.NWB's metadata and Python, else the Sorting step's; the probe of
%   probeFor; the trials of the behavior step's file). The inputs of the
%   analysis toolboxes (Chronux, FieldTrip, kCSD, ...) and event-organized
%   epochs are not written here: the DatasetBrowser's scripts make them.
%   One row per format and dataset (step "export:<format>"); progress goes
%   out as the "export" step, the formats sharing each dataset's part of it.
%
%   Options: Datasets (indices), DryRun (log only).

arguments
    obj (1,1) EphysPipeline
    opts.Datasets (1,:) double = []
    opts.DryRun (1,1) logical = false
end

c = obj.Config;
E = c.Export;
ds = obj.selected(opts.Datasets);
n = numel(ds);
nFmt = numel(E.Formats);

for k = 1:n
    d = ds(k);
    extract = obj.exportExtractFiles(d);   % with SeparateFiles, only those of Export.Signals (as plan)
    for j = 1:nFmt
        fmt = E.Formats(j);
        step = "export:" + fmt;
        if obj.CancelRequested
            obj.addResult(step, d.Name, "canceled", "not run");
            continue
        end
        t0 = tic;
        out = obj.outputPathFor(step, d);
        if isempty(extract) || ~all(isfile(extract))
            obj.addResult(step, d.Name, "skipped", "no extract file (" + strjoin(extract(~isfile(extract)), ", ") + ")", out, toc(t0));
            continue
        end
        if isfile(out) && ~E.Overwrite
            obj.addResult(step, d.Name, "skipped", "output exists (Overwrite is off)", out, toc(t0));
            continue
        end
        if E.IncludeUnits && d.sortingMissing()
            % never export without the hand-picked sort, or with another one
            obj.addResult(step, d.Name, "skipped", "the sorted-output folder is not there: " + d.SortingDir, out, toc(t0));
            continue
        end
        try
            o = EphysPipelineConfig.exportOptions(E, fmt);
            if opts.DryRun
                obj.log("[%s] %s: dry run -> %s", step, d.Name, out);
                obj.addResult(step, d.Name, "dry run", "would write from " + strjoin(extract, ", "), out, toc(t0));
                continue
            end
            obj.progress("export", d.Name, k, n, j - 1, nFmt, fmt + ": exporting");
            o.Extract = extract;
            o.Provenance = obj.provenance();
            o.ProbeFile = obj.probeFor(d);   % its own, a rule's or the default probe
            if o.PythonExe == ""; o.PythonExe = c.Sorting.PythonExe; o.CondaEnv = c.Sorting.CondaEnv; end
            % the trials of the behavior step's pairing
            o.Behavior = obj.outputPathFor("behavior", d);
            if ~isfile(o.Behavior); o.Behavior = ""; end
            args = namedargs2cell(o);
            switch fmt
                case "nwb"
                    r = d.exportNWB('File', out, args{:});
                otherwise
                    error('EphysPipeline:BadFormat', 'Unknown export format "%s".', fmt);
            end
            d.writeManifest();   % its processing block: how the file was made
            try
                obj.progress("export", d.Name, k, n, j, nFmt, fmt + ": done");
            catch
                % The file is complete; a cancel raised here must not report it
                % as "nothing written" (the next format records the cancel).
            end
            serious = nnz(ismember(r.inspector.importance, ["ERROR" "PYNWB_VALIDATION" "CRITICAL"]));
            msg = string(sprintf("%s; %d electrode(s), %d unit(s), %d trial(s), %d line(s); nwbinspector: %d finding(s), %d critical or above", ...
                strjoin(r.signals, "+"), r.nElectrodes, r.nUnits, r.nTrials, r.nEventLines, height(r.inspector), serious));
            obj.log("[%s] %s: wrote %s (%s)", step, d.Name, r.file, msg);
            obj.addResult(step, d.Name, "done", msg, r.file, toc(t0));
        catch ME
            if strcmp(ME.identifier, 'EphysPipeline:Canceled')
                obj.addResult(step, d.Name, "canceled", "canceled; nothing written", out, toc(t0));
                continue
            end
            obj.log("[%s] %s: ERROR %s", step, d.Name, ME.message);
            obj.addResult(step, d.Name, "error", string(ME.message), out, toc(t0));
        end
    end
end
if obj.CancelRequested
    error('EphysPipeline:Canceled', 'Canceled by user.');
end
end
