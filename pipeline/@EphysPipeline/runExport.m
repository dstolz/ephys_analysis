function runExport(obj, opts)
%runExport  Analysis-toolbox and epoch files per dataset, one per format
%   (export<Format>).
%   The continuous signals come from the Signals step's extract file(s), the
%   sorted units from the sorting association, detected spikes from the
%   Spikes step's file (Export.IncludeDetected), events as configured. The
%   "epochs" format organizes the same data by event, one epoch per digital
%   pulse or paired trial (Export.Epoch* settings); the behavior columns of a
%   paired session ride along with its trials table. Behavior data is not
%   exported here (see the behavior step). A dataset's inputs are read once
%   and handed to every format: the extract files of the Export.Signals
%   signals (per-type files of other signals are not read), the sorted units
%   and the spikes file. One row per
%   format and dataset (step "export:<format>"); progress goes out as the
%   "export" step, the formats sharing each dataset's part of it.
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
    spikesFile = obj.outputPathFor("spikes", d);
    in = [];                       % read by the dataset's first format that runs
    for j = 1:nFmt
        fmt = E.Formats(j);
        step = "export:" + fmt;
        if obj.CancelRequested
            obj.addResult(step, d.Name, "cancelled", "not run");
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
            if E.IncludeDetected
                if isfile(spikesFile); o.Detected = spikesFile; else; o.Detected = false; end
            end
            if opts.DryRun
                obj.log("[%s] %s: dry run -> %s", step, d.Name, out);
                obj.addResult(step, d.Name, "dry run", "would write from " + strjoin(extract, ", "), out, toc(t0));
                continue
            end
            if isempty(in)
                obj.progress("export", d.Name, k, n, j - 1, nFmt, fmt + ": reading the inputs");
                in = exportInputs(d, extract, o);
            end
            obj.progress("export", d.Name, k, n, j - 1, nFmt, fmt + ": exporting");
            o.Extract  = in.Extract;
            o.Units    = in.Units;
            o.Detected = in.Detected;
            o.Sources  = in.Sources;
            args = namedargs2cell(o);
            switch fmt
                case "chronux"
                    r = d.exportChronux('File', out, args{:});
                case "fieldtrip"
                    r = d.exportFieldTrip('File', out, args{:});
                case "epochs"
                    r = d.exportEpochs('File', out, args{:});
                otherwise
                    error('EphysPipeline:BadFormat', 'Unknown export format "%s".', fmt);
            end
            try
                obj.progress("export", d.Name, k, n, j, nFmt, fmt + ": done");
            catch
                % The file is complete; a cancel raised here must not report it
                % as "nothing written" (the next format records the cancel).
            end
            msg = sprintf("%s; %d unit(s)", strjoin(r.signals, "+"), r.nUnits);
            if fmt == "epochs"
                msg = string(msg) + sprintf("; %d epoch(s) of %s [%g %g] s", r.nEpochs, r.eventName, r.window(1), r.window(2));
            end
            obj.log("[%s] %s: wrote %s (%s)", step, d.Name, r.file, msg);
            obj.addResult(step, d.Name, "done", msg, r.file, toc(t0));
        catch ME
            if strcmp(ME.identifier, 'EphysPipeline:Cancelled')
                obj.addResult(step, d.Name, "cancelled", "cancelled; nothing written", out, toc(t0));
                continue
            end
            obj.log("[%s] %s: ERROR %s", step, d.Name, ME.message);
            obj.addResult(step, d.Name, "error", string(ME.message), out, toc(t0));
        end
    end
end
if obj.CancelRequested
    error('EphysPipeline:Cancelled', 'Cancelled by user.');
end
end


function in = exportInputs(d, files, o)
%exportInputs  Dataset D's export inputs, read once for all of its formats.
%   Loads the extract FILES (one combined file, or per-type files that each
%   add their own signal), the sorted units when o.Units asks for them ([] =
%   the dataset's own, when it has any) and the detected spikes of the spikes
%   file o.Detected. Sources names what was read, as each exporter records it
%   when it reads the files itself.
S = load(files(1));
for f = files(2:end)
    T = load(f);
    for sig = ["LFP" "MUA" "SPIKE" "AUX"]
        if isfield(T.info, sig)
            S.Y.(sig) = T.Y.(sig);
            S.info.(sig) = T.info.(sig);
        end
    end
end
src = struct('extractFile', strjoin(files, "; "), 'spikesFile', "", 'sortingDir', "");
units = false;
if isempty(o.Units) && d.hasKilosortResults()
    units = d.readSortedUnits(Groups=o.Groups);
    src.sortingDir = string(d.sortingResultsDir());
end
detected = false;
if isstring(o.Detected)
    M = load(o.Detected, 'detected');
    if isfield(M, 'detected') && ~isempty(M.detected)
        detected = M.detected;
        src.spikesFile = o.Detected;
    end
end
in = struct('Extract', S, 'Units', units, 'Detected', detected, 'Sources', src);
end
