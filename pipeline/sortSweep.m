function R = sortSweep(ds, variants, opts)
%sortSweep  Sort one dataset with several Kilosort4 settings, and compare the sorts' unit quality.
%   R = sortSweep(DS, VARIANTS) sorts dataset DS once per variant, each into
%   a results folder of its own, <outputFolder>/kilosort4_sweep/<name>, one
%   after the other and to the end (runKilosort, Wait=true): the first
%   writes the .bin, the others sort that same .bin (BinFile), so every
%   variant sorts identical data. The dataset's own sort (kilosort4/) is not
%   touched. VARIANTS is a struct array with fields
%     name      a label, also the folder name (letters, digits, - and _)
%     settings  runKilosort ExtraSettings: the Kilosort4 parameters this
%               variant sets, e.g. struct('Th_universal', 8)
%   R = sortSweep(DS, FOLDERS) compares sorts that exist (a string array of
%   results folders, named after their folders) without sorting.
%
%   Each sort's units (all clusters, noise included) then get their quality
%   metrics (EphysDataset.unitQuality) and are judged by the criteria
%   (unitQualityPass); each sort folder gets its QC page
%   (writeUnitQualityReport, quality_report.html).
%
%   R fields
%     summary   table, one row per variant: name, folder, status, units,
%               su, mua, noise (by class), meeting (the units meeting the
%               criteria), suMeeting, muaMeeting, and the medians over the
%               units that are not noise of firingRate, isiViolationsRatio,
%               presenceRatio, amplitudeCutoff and snr
%     units     every sort's unitTable, with columns variant and qualityPass,
%               qualityFails
%     runs      runKilosort's result per variant ([] when comparing folders)
%     criteria  the criteria applied
%
%   Options
%     Criteria    unitQualityPass criteria (default unitQualityCriteria())
%     DryRun      false: true writes each variant's settings.json and
%                 run_ks4.py (runKilosort DryRun, into <folder>/dryrun) and
%                 sorts and compares nothing
%     ReportFile  "": an HTML page comparing the variants (the summary, and
%                 a link to each sort's QC page)
%     ProbeFile, PythonExe, CondaEnv, Device, ArtifactIntervals
%                 passed to runKilosort
%
%   See also EphysDataset.runKilosort, EphysDataset.unitQuality,
%   unitQualityPass, writeUnitQualityReport.

arguments
    ds (1,1) EphysDataset
    variants
    opts.Criteria (1,1) struct = unitQualityCriteria()
    opts.DryRun (1,1) logical = false
    opts.ReportFile (1,1) string = ""
    opts.ProbeFile (1,1) string = ""
    opts.PythonExe (1,1) string = ""
    opts.CondaEnv (1,1) string = ""
    opts.Device (1,1) string = ""
    opts.ArtifactIntervals double = NaN
end

runs = [];
if isstring(variants) || ischar(variants) || iscellstr(variants)
    folders = string(variants(:));
    names = strings(numel(folders), 1);
    for k = 1:numel(folders)
        [~, names(k)] = fileparts(EphysDataset.resolvePhyDir(folders(k)));
        if names(k) == ""; names(k) = "sort" + k; end
    end
    status = repmat("existing", numel(folders), 1);
elseif isstruct(variants) && all(isfield(variants, {'name', 'settings'}))
    names = string({variants.name}).';
    if any(cellfun(@isempty, regexp(cellstr(names), '^[\w\-]+$', 'once')))
        error('sortSweep:BadName', 'Variant names must be non-empty and use letters, digits, - and _ only.');
    end
    if numel(unique(names)) < numel(names)
        error('sortSweep:BadName', 'Variant names must differ (each names its own folder).');
    end
    root = fullfile(ds.outputFolder(), "kilosort4_sweep");
    folders = arrayfun(@(n) string(fullfile(root, n)), names);
    runArgs = {'ProbeFile', opts.ProbeFile, 'PythonExe', opts.PythonExe, 'CondaEnv', opts.CondaEnv, ...
        'Device', opts.Device, 'DryRun', opts.DryRun, 'Wait', true};
    if ~(isscalar(opts.ArtifactIntervals) && isnan(opts.ArtifactIntervals))
        runArgs = [runArgs, {'ArtifactIntervals', opts.ArtifactIntervals}];
    end
    status = strings(numel(names), 1);
    binFile = "";
    for k = 1:numel(names)
        args = [runArgs, {'ResultsDir', folders(k), 'ExtraSettings', variants(k).settings}];
        if binFile ~= ""
            args = [args, {'BinFile', binFile}]; %#ok<AGROW>   the same data for every variant
        end
        res = ds.runKilosort(args{:});
        if isempty(runs); runs = res; else; runs(k) = res; end %#ok<AGROW>
        status(k) = string(res.status);
        if k == 1 && ~opts.DryRun; binFile = string(res.binFile); end
    end
else
    error('sortSweep:BadVariants', ...
        'VARIANTS must be a struct array with name and settings, or a list of results folders.');
end

summary = table(names, string(folders), status, 'VariableNames', {'name', 'folder', 'status'});
R = struct('summary', summary, 'units', table(), 'runs', runs, 'criteria', opts.Criteria);
if opts.DryRun
    return
end

cols = ["units" "su" "mua" "noise" "meeting" "suMeeting" "muaMeeting" ...
        "firingRate" "isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr"];
M = nan(numel(names), numel(cols));
tables = cell(numel(names), 1);
for k = 1:numel(names)
    [U, info] = ds.readSortedUnits(ResultsDir=folders(k), IncludeNoise=true);
    U = ds.unitQuality(U, info);
    [pass, why] = unitQualityPass(U, opts.Criteria);
    writeUnitQualityReport(U, "", Criteria=opts.Criteria, Title="Unit quality: " + names(k));
    cls = string(U.class(:));
    real = cls ~= "noise";
    M(k, :) = [numel(cls), nnz(cls == "su"), nnz(cls == "mua"), nnz(cls == "noise"), nnz(pass), ...
        nnz(pass & cls == "su"), nnz(pass & cls == "mua"), ...
        median(U.firingRate(real), 'omitnan'), median(U.isiViolationsRatio(real), 'omitnan'), ...
        median(U.presenceRatio(real), 'omitnan'), median(U.amplitudeCutoff(real), 'omitnan'), ...
        median(U.snr(real), 'omitnan')];
    T = unitTable(U, Times=false);
    T = addvars(T, repmat(names(k), height(T), 1), 'Before', 1, 'NewVariableNames', 'variant');
    T.qualityPass = pass;
    T.qualityFails = why;
    tables{k} = T;
end
R.summary = [summary, array2table(M, 'VariableNames', cols)];
R.units = vertcat(tables{:});
if opts.ReportFile ~= ""
    writeSweepReport(R, opts.ReportFile);
end
end


function writeSweepReport(R, file)
%writeSweepReport  One HTML page: the summary table and a link to each sort's QC page.
S = R.summary;
esc = @(s) replace(string(s), ["&" "<" ">" """"], ["&amp;" "&lt;" "&gt;" "&quot;"]);
L = strings(0, 1);
L(end+1) = "<!doctype html><html lang=""en""><head><meta charset=""utf-8""><title>Sort sweep</title>";
L(end+1) = "<style>body{font:14px system-ui,sans-serif;margin:16px}table{border-collapse:collapse}" + ...
    "th,td{border-bottom:1px solid #e3e6ec;padding:3px 8px;text-align:right}th{background:#f3f5f8}" + ...
    "td.t,th.t{text-align:left}</style></head><body><h1>Sort sweep</h1>";
head = "<tr><th class=""t"">Variant</th><th class=""t"">Status</th>";
for c = string(S.Properties.VariableNames(4:end))
    head = head + "<th>" + c + "</th>";
end
L(end+1) = "<table>" + head + "<th class=""t"">QC page</th></tr>";
for k = 1:height(S)
    r = "<tr><td class=""t"">" + esc(S.name(k)) + "</td><td class=""t"">" + esc(S.status(k)) + "</td>";
    for c = string(S.Properties.VariableNames(4:end))
        v = S.(c)(k);
        if isnan(v); t = "&mdash;"; elseif v == round(v); t = sprintf("%d", v); else; t = sprintf("%.3g", v); end
        r = r + "<td>" + t + "</td>";
    end
    page = fullfile(S.folder(k), "quality_report.html");
    r = r + "<td class=""t""><a href=""" + esc(fileUrl(page)) + """>quality_report.html</a></td></tr>";
    L(end+1) = r; %#ok<AGROW>
end
L(end+1) = "</table><p>Criteria: " + esc(jsonencode(R.criteria)) + "</p></body></html>";
d = fileparts(file);
if strlength(d) > 0 && ~isfolder(d); mkdir(d); end
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('sortSweep:CannotWrite', 'Cannot open %s for writing.', file);
end
closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
fwrite(fid, char(strjoin(L, newline) + newline), 'char');
end


function u = fileUrl(p)
%fileUrl  A file: URL of path P (forward slashes).
p = replace(string(p), "\", "/");
if ~startsWith(p, "/"); p = "/" + p; end
u = "file://" + p;
end
