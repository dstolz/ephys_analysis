classdef test_UnitQuality < matlab.unittest.TestCase
    %test_UnitQuality  Unit quality metrics: SpikeInterface's values, criteria, the dataset wrapper.
    %   unitQualityMetrics against the values SpikeInterface's own functions
    %   give (pipeline/testdata/unit_quality_golden.json, from
    %   tools/golden/unit_quality_golden.py): the same spike trains,
    %   amplitudes and positions are rebuilt here from the same integer
    %   generator, and their counts and sums are checked first, so a
    %   mismatch in the data is not mistaken for one in the metrics.
    %   unitQualityPass applies the criteria (strict thresholds, NaN rules,
    %   reasons). EphysDataset.unitQuality on a synthetic recording's sort:
    %   the fields added, the cache written, read back and made stale by
    %   phy rewriting spike_clusters.npy, SNR only with templates in uV;
    %   unitTable's columns.
    %
    %   Usage:  runtests("test_UnitQuality")

    properties (SetAccess = private)
        Golden = []
    end

    methods (TestClassSetup)
        function loadGolden(tc)
            here = fileparts(mfilename('fullpath'));
            tc.Golden = readJsonFile(fullfile(here, 'testdata', 'unit_quality_golden.json'));
        end
    end

    methods (Test)
        function matchesSpikeInterface(tc)
            G = tc.Golden;
            p = G.parameters;
            cases = G.cases;
            if iscell(cases); cases = [cases{:}]; end
            for c = 1:numel(cases)
                C = cases(c);
                [spikes, amps, ys, n] = goldenCase(C.seed, C.durationS, G.fs);
                tc.assertEqual(n, C.nSamples, C.name);
                U = C.units;
                if iscell(U); U = [U{:}]; end
                for u = 1:numel(U)
                    s = spikes{u};
                    tc.assertEqual([numel(s) double(s(1)) double(s(end))], [U(u).nSpikes U(u).firstSample U(u).lastSample], ...
                        sprintf("%s u%d: the same spike train as the generator", C.name, u - 1));
                    tc.assertEqual(sum(amps{u}), U(u).sumAmplitude, 'RelTol', 1e-12, sprintf("%s u%d amplitudes", C.name, u - 1));
                    tc.assertEqual(sum(ys{u}), U(u).sumY, 'RelTol', 1e-12, sprintf("%s u%d positions", C.name, u - 1));
                end
                Q = unitQualityMetrics(spikes, Fs=G.fs, NumSamples=n, Amplitudes=amps, PositionsY=ys, ...
                    IsiThresholdMs=p.isiThresholdMs, MinIsiMs=p.minIsiMs, PresenceBinS=p.presenceBinS, ...
                    AmplitudeBins=p.amplitudeBins, AmplitudeSmoothing=p.amplitudeSmoothing, ...
                    AmplitudeMinRatio=p.amplitudeMinRatio, DriftIntervalS=p.driftIntervalS, ...
                    DriftMinSpikes=p.driftMinSpikes, DriftMinBins=p.driftMinBins, ...
                    DriftMinValidFraction=p.driftMinValidFraction);
                for m = ["isiViolationsRatio" "isiViolationsCount" "presenceRatio" "amplitudeCutoff" ...
                         "driftPtp" "driftStd" "driftMad"]
                    want = arrayfun(@(x) orNaN(x.(m)), U(:));
                    tc.verifyEqual(Q.(m), want, 'AbsTol', 1e-9, sprintf("%s: %s as SpikeInterface", C.name, m));
                end
                tc.verifyEqual(Q.firingRate, cellfun(@numel, spikes) / (n / G.fs), 'RelTol', 1e-12);
            end
        end

        function snrIsPeakOverNoise(tc)
            Q = unitQualityMetrics({int64([10 20 30]), int64(5)}, Fs=1000, NumSamples=100, ...
                PeakAmplitudeUV=[-60 40], NoiseUV=[10 0]);
            tc.verifyEqual(Q.snr(1), 6, "|extremum| / noise");
            tc.verifyTrue(isnan(Q.snr(2)), "no noise level: NaN");
            Q = unitQualityMetrics({int64([10 20 30])}, Fs=1000, NumSamples=100);
            tc.verifyTrue(isnan(Q.snr) && isnan(Q.amplitudeCutoff) && isnan(Q.driftPtp), ...
                "without amplitudes, positions or a noise level those metrics are NaN");
        end

        function criteria(tc)
            Q = table([0.2; 0.6; 0.1; 0.5], [0.95; 0.95; 0.5; 0.95], [0.05; NaN; 0.01; 0.1], ...
                'VariableNames', {'isiViolationsRatio', 'presenceRatio', 'amplitudeCutoff'});
            [pass, why, unknown] = unitQualityPass(Q);
            tc.verifyEqual(pass, [true; false; false; false]);
            tc.verifyEqual(why(2), "isiViolationsRatio 0.6 >= 0.5");
            tc.verifyEqual(why(3), "presenceRatio 0.5 <= 0.9");
            tc.verifyEqual(why(4), "isiViolationsRatio 0.5 >= 0.5; amplitudeCutoff 0.1 >= 0.1", ...
                "the thresholds are strict, as the Allen Institute applies them");
            tc.verifyEqual(unknown(2), "amplitudeCutoff", "a NaN metric is unknown");
            c = unitQualityCriteria(); c.unknown = "fail"; c.isiViolationsRatioMax = NaN;
            tc.verifyEqual(unitQualityPass(Q, c), [true; false; false; false], ...
                "unknown fails when asked to; a NaN threshold is not applied");
            c = unitQualityCriteria(); c.snrMin = 5;
            [pass, ~, unknown] = unitQualityPass(Q, c);
            tc.verifyEqual(pass(1), true, "a metric missing from Q is unknown, which passes by default");
            tc.verifyEqual(unknown(1), "snr");
            tc.verifyError(@() unitQualityPass(Q, struct('nope', 1)), 'unitQualityPass:BadCriterion');
        end

        function datasetWrapperAndCache(tc)
            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            T = makeSyntheticRecording(fullfile(root, "Q1_260101_120000"), NumChannels=4, NumTrials=4, ...
                Format="one-file-per-signal", Seed=3);
            ds = EphysDataset(string(T.folder));
            [units, Q] = ds.unitQuality();
            nU = numel(units.unitId);
            for m = ["firingRate" "isiViolationsRatio" "presenceRatio" "amplitudeCutoff" "snr" "driftPtp"]
                tc.verifyEqual(size(units.(m)), [nU 1], m + " is a column field of the units");
            end
            tc.verifyEqual(Q.unitId, double(units.unitId(:)));
            tc.verifyEqual(units.quality.numSamples, T.nSamples, "the recording's length (no .bin)");
            real = units.class ~= "noise";
            tc.verifyEqual(units.isiViolationsRatio(real), zeros(nnz(real), 1), ...
                "the generator keeps 2 ms between a unit's spikes: no ISI violations");
            tc.verifyTrue(all(isnan(units.driftPtp)), "no spike_positions.npy: no drift");
            tc.verifyTrue(all(isnan(units.snr)) && contains(units.quality.snrNoise, "not in uV"), ...
                "whitened templates: no SNR, and the reason is recorded");
            cacheFile = fullfile(units.resultsDir, "quality_metrics.json");
            tc.verifyTrue(isfile(cacheFile) && units.quality.cache == "computed");
            again = ds.unitQuality();
            tc.verifyEqual(again.quality.cache, "read", "a second call reads the cache");
            tc.verifyEqual(again.isiViolationsRatio, units.isiViolationsRatio);
            % phy rewrites spike_clusters.npy on a merge or split: the cache is stale
            clu = readNPY(fullfile(units.resultsDir, "spike_clusters.npy"));
            pause(1.1);
            writeNPY(fullfile(units.resultsDir, "spike_clusters.npy"), clu);
            tc.verifyEqual(ds.readSortedUnits(Quality=true).quality.cache, "computed", ...
                "files newer than the cache: computed again");
            % templates in uV (identity whitening, bin_scale 1): SNR = |template peak| / noise
            writeNPY(fullfile(units.resultsDir, "whitening_mat_inv.npy"), single(eye(4)));
            writeJsonFile(fullfile(units.resultsDir, "settings.json"), struct('bin_scale', 1));
            uv = ds.readSortedUnits(Quality=true);
            tc.verifyEqual(uv.templateUnits, "uV");
            peak = cellfun(@(w) max(abs(w)), uv.templateWaveform(:));
            nl = ds.noiseLevels(Filter=true, FilterType="highpass", FilterCutoff=300, FilterOrder=3, ...
                ChannelOrder=uv.channel(real).', MaxChunks=16);
            tc.verifyEqual(uv.snr(real), peak(real) ./ nl.sigma(:), 'RelTol', 1e-12, ...
                "the template's peak over the noise of the 300 Hz high-passed recording on its channel");
            tc.verifyTrue(all(uv.snr(real) > 2), "large synthetic units: a clear SNR");
            U = unitTable(uv);
            tc.verifyEqual(U.snr, uv.snr, "unitTable carries the metrics");
            tc.verifyTrue(all(isnan(unitTable(ds.readSortedUnits()).snr)), "and NaN for units without them");
        end

        function qcReportAndExports(tc)
            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            T = makeSyntheticRecording(fullfile(root, "Q2_260101_120000"), NumChannels=4, NumTrials=4, ...
                Format="one-file-per-signal", Seed=5);
            ds = EphysDataset(string(T.folder));
            units = ds.readSortedUnits(Quality=true);
            file = writeUnitQualityReport(units);
            tc.verifyEqual(file, fullfile(units.resultsDir, "quality_report.html"));
            html = string(fileread(file));
            tc.verifyTrue(contains(html, "Meet the criteria") && contains(html, "<svg") ...
                && contains(html, units.label(1)), "summary, histograms and a row per unit");
            good = string(units.group(:)) == "good";
            rows = regexp(html, '<tr data-i="\d+"[^>]*><td class="t">(?:<a [^>]*>)?([^<]*)', 'tokens');
            rows = cellfun(@(c) string(c{1}), rows(:));
            tc.verifyEqual(sort(rows), sort(string(units.label(:))), "one row per unit");
            tc.verifyTrue(all(ismember(rows(1:nnz(good)), units.label(good))), "the good units first");
            tc.verifyTrue(contains(html, "<table class=""sortable""><thead>") && contains(html, "<script>") ...
                && contains(html, "data-v="""), "the units table sorts by a header click");
            tc.verifyEqual(count(html, "<figure class=""wf"""), nnz(good), "a waveform per good unit");
            tc.verifyTrue(contains(html, "templates are drawn") && count(html, "&middot; template") == nnz(good), ...
                "no sorted .bin: the templates, and the page says why");
            P = fileread(fullfile(units.resultsDir, 'params.py'));       % plant the sorted data (temp_wh.dat)
            nCh = str2double(regexp(P, 'n_channels_dat = (\d+)', 'tokens', 'once'));
            fsS = str2double(regexp(P, 'sample_rate = ([\d.eE+]+)', 'tokens', 'once'));
            nS = double(max(cellfun(@max, units.samples))) + round(0.01 * fsS);   % past every spike's window
            dat = fullfile(units.resultsDir, 'temp_wh.dat');
            fid = fopen(dat, 'w');
            fwrite(fid, repmat(int16(10 * (1:nCh).'), 1, nS), 'int16');
            fclose(fid);
            html = string(fileread(writeUnitQualityReport(units, "", WaveformSpikes=3)));
            tc.verifyTrue(~contains(html, "templates are drawn") && count(html, " 3 spikes &middot;") == nnz(good), ...
                "with the sorted data: the mean of WaveformSpikes of each good unit's spikes");
            html = string(fileread(writeUnitQualityReport(units, "", WaveformSpikes=0)));
            tc.verifyEqual(count(html, "&middot; template"), nnz(good), "WaveformSpikes 0: the templates");
            delete(dat);
            tc.verifyError(@() writeUnitQualityReport(ds.readSortedUnits(), fullfile(root, "x.html")), ...
                'writeUnitQualityReport:NoMetrics');
            ds.toMat(Overwrite=true);                        % the extract the exporters read (LFP)
            ds.exportChronux(File=fullfile(root, "q_chronux.mat"), Detected=false);
            M = load(fullfile(root, "q_chronux.mat"));
            tc.verifyTrue(isfield(M.units, 'presenceRatio') && isfield(M.units, 'quality') ...
                && ~isfield(M.units.quality, 'cache'), ...
                "exports carry the quality metrics (and not whether they came from the cache)");
        end

        function sweepComparesSorts(tc)
            root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            T = makeSyntheticRecording(fullfile(root, "Q3_260101_120000"), NumChannels=4, NumTrials=4, ...
                Format="one-file-per-signal", Seed=6, WriteProbe=true);
            ds = EphysDataset(string(T.folder));
            a = string(T.sortedDir);
            b = fullfile(root, "other_sort");
            copyfile(a, b);
            fid = fopen(fullfile(b, "cluster_group.tsv"), 'w');          % every cluster called mua in B
            fprintf(fid, 'cluster_id\tgroup\n');
            fprintf(fid, '%d\tmua\n', unique(readNPY(fullfile(b, "spike_clusters.npy"))));
            fclose(fid);
            R = sortSweep(ds, [a; b], ReportFile=fullfile(root, "sweep.html"));
            tc.verifyEqual(height(R.summary), 2);
            tc.verifyEqual(R.summary.units(1), R.summary.units(2), "the same clusters in both");
            tc.verifyEqual(R.summary.su(2), 0, "B calls none of them su");
            tc.verifyEqual(R.summary.su(1), nnz(string({T.units.label}) == "good"), ...
                "A's su are the units the generator labeled good");
            tc.verifyEqual(sort(unique(R.units.variant)), sort(R.summary.name));
            tc.verifyTrue(isfile(fullfile(a, "quality_report.html")) && isfile(fullfile(b, "quality_report.html")) ...
                && isfile(fullfile(root, "sweep.html")), "a QC page per sort and the comparison page");
            % variants: a dry run writes each one's settings, in a folder of its own
            v = struct('name', {"loose", "strict"}, 'settings', {struct('Th_universal', 8), struct('Th_universal', 11)});
            D = sortSweep(ds, v, DryRun=true, PythonExe="python", ProbeFile=T.probeFile);
            tc.verifyEqual(D.summary.name, ["loose"; "strict"]);
            for k = 1:2
                s = readJsonFile(fullfile(D.summary.folder(k), "dryrun", "settings.json"));
                tc.verifyEqual(s.Th_universal, v(k).settings.Th_universal, "each variant's own setting");
            end
            tc.verifyFalse(isfolder(fullfile(ds.outputFolder(), "kilosort4", "dryrun")), ...
                "the dataset's own sort folder is not touched");
            tc.verifyError(@() sortSweep(ds, struct('name', {"a b"}, 'settings', {struct()}), DryRun=true), ...
                'sortSweep:BadName');
        end
    end
end


function [spikes, amps, ys, n] = goldenCase(seed, T, FS)
%goldenCase  tools/golden/unit_quality_golden.py's make_case, step for step.
g = seed;
n = round(T * FS);
trains = cell(5, 1);
t = zeros(4000, 1);
for i = 1:4000; [x, g] = lehmer(g); t(i) = T * x; end
if T >= 180
    t = t(t < 60 | t > 120);
end
d = zeros(40, 1);
for k = 1:40
    [x, g] = lehmer(g);
    i = floor(x * numel(t));
    [x, g] = lehmer(g);
    d(k) = t(i + 1) + 0.0002 + 0.0012 * x;
end
trains{1} = [t; d];
trains{2} = zeros(600, 1);
for i = 1:600; [x, g] = lehmer(g); trains{2}(i) = T * x; end
trains{3} = zeros(2700, 1);
for i = 1:2700; [x, g] = lehmer(g); trains{3}(i) = min(30, T) * x; end
trains{4} = zeros(250, 1);
for i = 1:250; [x, g] = lehmer(g); trains{4}(i) = T * x; end
lo = max(T - 15, 0);
trains{5} = zeros(300, 1);
for i = 1:300; [x, g] = lehmer(g); trains{5}(i) = lo + (T - lo) * x; end
spikes = cell(5, 1); amps = cell(5, 1); ys = cell(5, 1);
for k = 1:5
    s = unique(min(floor(trains{k} * FS), n - 1));
    a = zeros(numel(s), 1);
    y = zeros(numel(s), 1);
    for j = 1:numel(s)
        if k == 1
            [z, g] = irwin(g); a(j) = 10 + 2 * z;
            while ~(a(j) > 8.5)
                [z, g] = irwin(g); a(j) = 10 + 2 * z;
            end
        elseif k == 3
            [z, g] = irwin(g); a(j) = -(12 + 1.5 * z);
        else
            [z, g] = irwin(g); a(j) = 9 + 1.5 * z;
        end
    end
    for j = 1:numel(s)
        dr = 0;
        if k == 1; dr = 20 * (s(j) / n); end
        [z, g] = irwin(g);
        y(j) = 100 + dr + 2 * z;
    end
    spikes{k} = int64(s); amps{k} = a; ys{k} = y;
end
end


function [u, x] = lehmer(x)
%lehmer  x <- 16807 x mod (2^31 - 1), exact in doubles; u = x / (2^31 - 1).
x = mod(16807 * x, 2147483647);
u = x / 2147483647;
end


function [z, x] = irwin(x)
%irwin  Twelve uniforms summed left to right, less 6.
s = 0;
for k = 1:12
    [u, x] = lehmer(x);
    s = s + u;
end
z = s - 6;
end


function v = orNaN(v)
%orNaN  A golden value: null (no value) is NaN.
if isempty(v); v = NaN; end
v = double(v);
end
