classdef test_DatasetRuns < matlab.unittest.TestCase
    %test_DatasetRuns  DatasetRuns: the per-dataset run engine and cache.
    %   Pure: the sources are functions @(key) src over made-up structs.
    %   A dataset is computed once and then reported "cached"; a new id
    %   computes every one again, a new key only that one; Recompute and
    %   Name="" ignore the cache; skip-id errors are kept, other errors are
    %   not (a warning, and tried again); a cancel from ProgressFcn or
    %   CheckFcn keeps the finished datasets; ReleaseFcn runs only after a
    %   dataset computed; the default id is the function's text and what it
    %   captured (NeedId when that is a handle); idText's canonical cases;
    %   status, forget, value and a toStruct / fromStruct round trip
    %   through a -v7.3 file (an older version gives an empty cache). A
    %   Recompute that fails or is canceled partway leaves no old entry; an
    %   empty KEYS list forgets nothing. Stamps (StampFcn, status Stamps=):
    %   a changed stamp is "old" and computes only that dataset again, a
    %   kept skip is tried again, a dataset canceled after its stamp changed
    %   keeps no old value. outputsStamp over a hand-built output folder:
    %   what it holds, and that a file's size or time changes it.
    %
    %   Usage:  runtests("test_DatasetRuns")

    properties
        Calls = strings(0, 1)      % the keys the source was asked for, in order
        Released = strings(0, 1)   % the datasets ReleaseFcn was called for
        Checks = 0                 % CheckFcn calls
    end

    methods (TestClassSetup)
        function addPaths(tc) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(here);
            addpath(here);
            addpath(fullfile(repo, 'pipeline'));
        end
    end

    methods (TestMethodSetup)
        function resetCalls(tc)
            tc.Calls = strings(0, 1);
            tc.Released = strings(0, 1);
            tc.Checks = 0;
        end
    end

    methods
        function src = source(tc, key)
            %source  A made-up dataset source; records the call.
            tc.Calls(end+1, 1) = key;
            src = struct('name', key, 'n', strlength(key));
        end

        function noteRelease(tc, src)
            tc.Released(end+1, 1) = src.name;
        end

        function countCheck(tc, cancelAt)
            tc.Checks = tc.Checks + 1;
            cancelWhen(tc.Checks == cancelAt);
        end
    end

    methods (Test)
        function computesOnceThenCached(tc)
            runs = DatasetRuns();
            keys = ["a" "bb" "ccc"];
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n * 10, Name="len", Id="v1");
            tc.verifyEqual(v, {10; 20; 30});
            tc.verifyEqual(T.status, repmat("done", 3, 1));
            tc.verifyEqual(T.key, keys.');
            tc.verifyEqual(T.Properties.VariableNames, {'key', 'name', 'status', 'message', 'seconds'});
            tc.verifyEqual(tc.Calls, keys.');
            tc.Calls = strings(0, 1);
            [v2, T2] = runs.run(@(k) tc.source(k), keys, @(src) src.n * 10, Name="len", Id="v1");
            tc.verifyEqual(v2, v);
            tc.verifyEqual(T2.status, repmat("cached", 3, 1));
            tc.verifyEmpty(tc.Calls, 'A cached dataset needs no source.');
            tc.verifyEqual(runs.Last, T2);
        end

        function newIdRecomputesAll(tc)
            runs = DatasetRuns();
            keys = ["a" "bb"];
            runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="len", Id=struct('bin', 0.01));
            tc.Calls = strings(0, 1);
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n + 1, Name="len", Id=struct('bin', 0.02));
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyEqual(v, {2; 3});
            tc.verifyEqual(tc.Calls, keys.');
        end

        function newKeyComputesOnlyIt(tc)
            runs = DatasetRuns();
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="len", Id=1);
            tc.Calls = strings(0, 1);
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb" "ccc"], @(src) src.n, Name="len", Id=1);
            tc.verifyEqual(T.status, ["cached"; "cached"; "done"]);
            tc.verifyEqual(v, {1; 2; 3});
            tc.verifyEqual(tc.Calls, "ccc");
        end

        function recomputeAndNoName(tc)
            runs = DatasetRuns();
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="len", Id=1);
            tc.Calls = strings(0, 1);
            [~, T] = runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="len", Id=1, Recompute=true);
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyEqual(tc.Calls, ["a"; "bb"]);

            tc.Calls = strings(0, 1);
            runs2 = DatasetRuns();
            runs2.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="", Id=1);
            [~, T] = runs2.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="", Id=1);
            tc.verifyEqual(T.status, ["done"; "done"], 'Name "" keeps nothing.');
            tc.verifyEqual(numel(tc.Calls), 4);
            tc.verifyEmpty(runs2.Entries);
        end

        function skipIdsAreKept(tc)
            runs = DatasetRuns();
            fn = @(src) failFor(src, "bb", 'selectUnits:NoUnits');
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb"], fn, Name="x", Id=1, SkipIds="selectUnits:NoUnits");
            tc.verifyEqual(T.status, ["done"; "skipped"]);
            tc.verifyEqual(T.message(2), "no luck in bb");
            tc.verifyEmpty(v{2});
            tc.verifyEqual(runs.status("x", ["a" "bb" "zz"], 1), ["current"; "skipped"; ""]);
            tc.Calls = strings(0, 1);
            [~, T] = runs.run(@(k) tc.source(k), ["a" "bb"], fn, Name="x", Id=1, SkipIds="selectUnits:NoUnits");
            tc.verifyEqual(T.status, ["cached"; "skipped"]);
            tc.verifyEqual(T.message(2), "no luck in bb");
            tc.verifyEmpty(tc.Calls, 'A kept skip needs no source.');
        end

        function otherErrorsAreRetried(tc)
            runs = DatasetRuns();
            fn = @(src) failFor(src, "bb", 'some:Bug');
            T = tc.verifyWarning(@() runTable(runs, @(k) tc.source(k), ["a" "bb"], fn), 'DatasetRuns:DatasetFailed');
            tc.verifyEqual(T.status, ["done"; "error"]);
            tc.verifyEqual(runs.status("x", "bb", 1), "");
            tc.Calls = strings(0, 1);
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="x", Id=1);
            tc.verifyEqual(T.status, ["cached"; "done"]);
            tc.verifyEqual(v{2}, 2);
            tc.verifyEqual(tc.Calls, "bb");
        end

        function cancelFromProgress(tc)
            runs = DatasetRuns();
            progress = @(f, msg) cancelWhen(contains(msg, "bb"));
            tc.verifyError(@() runs.run(@(k) tc.source(k), ["a" "bb" "ccc"], @(src) src.n, Name="x", Id=1, ...
                ProgressFcn=progress), 'DatasetRuns:Canceled');
            tc.verifyEqual(runs.Last.status, ["done"; "canceled"; "canceled"]);
            tc.verifyEqual(runs.status("x", ["a" "bb" "ccc"], 1), ["current"; ""; ""]);
            tc.verifyEqual(runs.value("x", "a"), 1);
        end

        function cancelFromCheck(tc)
            runs = DatasetRuns();
            % run checks once before each dataset and fn once inside: the 4th call is fn's own, on "bb"
            fn = @(src, info, chk) checkedLength(src, chk);
            tc.verifyError(@() runs.run(@(k) tc.source(k), ["a" "bb" "ccc"], fn, Name="x", Id=1, ...
                CheckFcn=@() tc.countCheck(4)), 'DatasetRuns:Canceled');
            tc.verifyEqual(tc.Checks, 4);
            tc.verifyEqual(runs.Last.status, ["done"; "canceled"; "canceled"]);
            tc.verifyEqual(runs.status("x", ["a" "bb"], 1), ["current"; ""]);
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb" "ccc"], @(src) src.n, Name="x", Id=1);
            tc.verifyEqual(T.status, ["cached"; "done"; "done"]);
            tc.verifyEqual(v, {1; 2; 3});
        end

        function releaseOnlyAfterComputed(tc)
            runs = DatasetRuns();
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="x", Id=1, ReleaseFcn=@(src) tc.noteRelease(src));
            tc.verifyEqual(tc.Released, ["a"; "bb"]);
            tc.Released = strings(0, 1);
            runs.run(@(k) tc.source(k), ["a" "bb" "ccc"], @(src) src.n, Name="x", Id=1, ReleaseFcn=@(src) tc.noteRelease(src));
            tc.verifyEqual(tc.Released, "ccc", 'Cached datasets are not released.');
        end

        function infoAndNames(tc)
            runs = DatasetRuns();
            info = table(["a"; "bb"], ["Alpha"; "Beta"], ["S1"; "S2"], 'VariableNames', {'key', 'name', 'subject'});
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb"], @(src, row) row.subject + ":" + src.n, Info=info);
            tc.verifyEqual(v, {"S1:1"; "S2:2"});
            tc.verifyEqual(T.name, ["Alpha"; "Beta"]);
        end

        function defaultIdFromWorkspace(tc)
            runs = DatasetRuns();
            scale = 10;
            fn = @(src) src.n * scale;
            runs.run(@(k) tc.source(k), ["a" "bb"], fn, Name="x");
            tc.Calls = strings(0, 1);
            fn = @(src) src.n * scale;   % the same text and workspace
            [~, T] = runs.run(@(k) tc.source(k), ["a" "bb"], fn, Name="x");
            tc.verifyEqual(T.status, ["cached"; "cached"]);
            scale = 20;
            fn = @(src) src.n * scale;   % a captured value changed
            [v, T] = runs.run(@(k) tc.source(k), ["a" "bb"], fn, Name="x");
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyEqual(v, {20; 40});
            id = DatasetRuns.defaultId(fn);
            tc.verifyEqual(id.workspace.scale, 20);
            tc.verifyEqual(id.function, "@(src)src.n*scale");
        end

        function needIdForHandles(tc)
            runs = DatasetRuns();
            other = DatasetRuns();
            fn = @(src) numel(other.Entries) + src.n;
            tc.verifyError(@() DatasetRuns.defaultId(fn), 'DatasetRuns:NeedId');
            tc.verifyError(@() runs.run(@(k) tc.source(k), "a", fn, Name="x"), 'DatasetRuns:NeedId');
            g = @(x) x + 1;
            fn2 = @(src) g(src.n);
            tc.verifyError(@() DatasetRuns.defaultId(fn2), 'DatasetRuns:NeedId');
            [v, T] = runs.run(@(k) tc.source(k), "a", fn, Name="x", Id="by hand");
            tc.verifyEqual(v, {1});
            tc.verifyEqual(T.status, "done");
        end

        function idTextCanonical(tc)
            a = struct('w', [-Inf Inf], 'b', [1 2 3], 's', "x", 'n', NaN, 'e', []);
            b = struct('n', NaN, 'e', [], 's', 'x', 'b', [1; 2; 3], 'w', [-Inf; Inf]);   % other order, columns, char
            tc.verifyEqual(DatasetRuns.idText(a), DatasetRuns.idText(b));
            back = jsondecode(char(DatasetRuns.idText(a)));
            tc.verifyEqual(DatasetRuns.idText(back), DatasetRuns.idText(a), 'Stable across a JSON round trip.');
            tc.verifyTrue(contains(DatasetRuns.idText(a), '"-Inf"'));
            tc.verifyNotEqual(DatasetRuns.idText(struct('x', NaN)), DatasetRuns.idText(struct('x', Inf)));
            tc.verifyNotEqual(DatasetRuns.idText(1), DatasetRuns.idText(2));
            nested = struct('outer', struct('z', 1, 'a', {{[1 2], "t"}}));
            tc.verifyEqual(DatasetRuns.idText(jsondecode(char(DatasetRuns.idText(nested)))), DatasetRuns.idText(nested));
            tc.verifyClass(DatasetRuns.idText("v1"), 'string');
        end

        function statusAndForget(tc)
            runs = DatasetRuns();
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="x", Id=1);
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="y", Id=1);
            tc.verifyEqual(runs.status("x", ["a" "bb" "c"], 1), ["current"; "current"; ""]);
            tc.verifyEqual(runs.status("x", ["a" "bb"], 2), ["old"; "old"]);
            runs.forget("x", "a");
            tc.verifyEqual(runs.status("x", ["a" "bb"], 1), [""; "current"]);
            runs.forget("x");
            tc.verifyEqual(runs.status("x", ["a" "bb"], 1), [""; ""]);
            tc.verifyEqual(runs.status("y", ["a" "bb"], 1), ["current"; "current"]);
            runs.forget();
            tc.verifyEmpty(runs.Entries);
        end

        function roundTripV73(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            runs = DatasetRuns();
            part = struct('values', rand(3, 2, 2), 'rows', table(["u1"; "u2"], [1; 2], 'VariableNames', {'label', 'unitId'}));
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) part, Name="parts", Id=struct('t', [-Inf 1]));
            runs.run(@(k) tc.source(k), "c", @(src) failFor(src, "c", 'x:Skip'), Name="parts", ...
                Id=struct('t', [-Inf 1]), SkipIds="x:Skip");
            s = runs.toStruct();
            file = fullfile(tmp.Folder, 'runs.mat');
            save(file, 's', '-v7.3');
            L = load(file);
            back = DatasetRuns.fromStruct(L.s);
            tc.verifyEqual(back.status("parts", ["a" "bb" "c"], struct('t', [-Inf; 1])), ["current"; "current"; "skipped"]);
            tc.verifyEqual(back.value("parts", "bb"), part);
            [v, T] = back.run(@(k) tc.source(k), ["a" "bb" "c"], @(src) [], Name="parts", Id=struct('t', [-Inf 1]));
            tc.verifyEqual(T.status, ["cached"; "cached"; "skipped"]);
            tc.verifyEqual(v{1}, part);
            tc.verifyError(@() DatasetRuns.fromStruct(struct('schema', "other")), 'DatasetRuns:BadStruct');
            % an older version: a warning and an empty cache (no backward compatibility)
            old = struct('schema', "dataset-runs", 'version', 1, 'entries', struct('name', "x", 'key', "a"));
            back1 = tc.verifyWarning(@() DatasetRuns.fromStruct(old), 'DatasetRuns:OldVersion');
            tc.verifyEmpty(back1.Entries);
            tc.verifyEqual(s.version, DatasetRuns.Version);
        end

        % --- Recompute, forget, stamps -------------------------------------------------------
        function recomputeErrorLeavesNoStale(tc)
            runs = DatasetRuns();
            keys = ["a" "bb" "ccc"];
            runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1);
            fn = @(src) failFor(src, "bb", 'some:Bug');
            T = tc.verifyWarning(@() runTable(runs, @(k) tc.source(k), keys, fn, Recompute=true), ...
                'DatasetRuns:DatasetFailed');
            tc.verifyEqual(T.status, ["done"; "error"; "done"]);
            tc.verifyEqual(runs.status("x", keys, 1), ["current"; ""; "current"], 'The failed dataset keeps no old entry.');
            tc.Calls = strings(0, 1);
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1);
            tc.verifyEqual(T.status, ["cached"; "done"; "cached"], 'The next run tries it again.');
            tc.verifyEqual(v, {1; 2; 3});
            tc.verifyEqual(tc.Calls, "bb");
        end

        function recomputeCanceledLeavesNoStale(tc)
            runs = DatasetRuns();
            keys = ["a" "bb" "ccc"];
            runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1);
            progress = @(f, msg) cancelWhen(contains(msg, "bb"));
            tc.verifyError(@() runs.run(@(k) tc.source(k), keys, @(src) src.n * 10, Name="x", Id=1, ...
                Recompute=true, ProgressFcn=progress), 'DatasetRuns:Canceled');
            tc.verifyEqual(runs.Last.status, ["done"; "canceled"; "canceled"]);
            tc.verifyEqual(runs.status("x", keys, 1), ["current"; ""; ""], ...
                'The datasets a canceled Recompute did not reach keep no old entry.');
            tc.verifyEqual(runs.value("x", "a"), 10);
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n * 10, Name="x", Id=1);
            tc.verifyEqual(T.status, ["cached"; "done"; "done"]);
            tc.verifyEqual(v, {10; 20; 30});
            % a cancel inside FN, while recomputing: that dataset's old value goes too
            fn = @(src) failFor(src, "ccc", 'Test:Canceled');
            tc.verifyError(@() runs.run(@(k) tc.source(k), keys, fn, Name="x", Id=1, Recompute=true), ...
                'DatasetRuns:Canceled');
            tc.verifyEqual(runs.status("x", keys, 1), ["current"; "current"; ""]);
        end

        function forgetEmptyKeysKeepsAll(tc)
            runs = DatasetRuns();
            runs.run(@(k) tc.source(k), ["a" "bb"], @(src) src.n, Name="x", Id=1);
            runs.forget("x", []);
            runs.forget("x", strings(0, 1));
            runs.forget("x", {});
            tc.verifyEqual(runs.status("x", ["a" "bb"], 1), ["current"; "current"], 'Empty KEYS forget nothing.');
            runs.forget("x", "bb");
            tc.verifyEqual(runs.status("x", ["a" "bb"], 1), ["current"; ""]);
            empty = DatasetRuns();
            empty.forget("x", "a");   % nothing kept: no error
            tc.verifyEmpty(empty.Entries);
        end

        function stampChangeRecomputesOnlyIt(tc)
            runs = DatasetRuns();
            keys = ["a" "bb"];
            stamps = containers.Map({'a', 'bb'}, {'s1', 's2'});
            sf = @(k) string(stamps(char(k)));
            [~, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1, StampFcn=sf);
            tc.verifyEqual(T.status, ["done"; "done"]);
            tc.verifyEqual(runs.status("x", keys, 1, Stamps=["s1" "s2"]), ["current"; "current"]);
            tc.verifyEqual(runs.status("x", keys, 1, Stamps=["s1" "s2b"]), ["current"; "old"]);
            tc.verifyEqual(runs.status("x", keys, 1), ["current"; "current"], 'Without Stamps, stamps are not compared.');
            tc.verifyError(@() runs.status("x", keys, 1, Stamps="s1"), 'DatasetRuns:BadSource');
            stamps('bb') = 's2b';
            tc.Calls = strings(0, 1);
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n * 10, Name="x", Id=1, StampFcn=sf);
            tc.verifyEqual(T.status, ["cached"; "done"]);
            tc.verifyEqual(v, {1; 20});
            tc.verifyEqual(tc.Calls, "bb", 'Only the dataset whose outputs changed is computed.');
            tc.verifyEqual(runs.status("x", keys, 1, Stamps=["s1" "s2b"]), ["current"; "current"]);
            % without StampFcn the kept entries are used whatever their stamp
            [~, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1);
            tc.verifyEqual(T.status, ["cached"; "cached"]);
            % a stamp that changed, then a cancel on that dataset: its old value is gone
            stamps('a') = 's1b'; %#ok<NASGU> a containers.Map is a handle
            fn = @(src) failFor(src, "a", 'Test:Canceled');
            tc.verifyError(@() runs.run(@(k) tc.source(k), keys, fn, Name="x", Id=1, StampFcn=sf), 'DatasetRuns:Canceled');
            tc.verifyEqual(runs.status("x", keys, 1), [""; "current"]);
            % a StampFcn that fails: that dataset is an error, the others go on
            bad = @(k) failStamp(k, "bb");
            T = tc.verifyWarning(@() runTable(runs, @(k) tc.source(k), keys, @(src) src.n, StampFcn=bad), ...
                'DatasetRuns:DatasetFailed');
            tc.verifyEqual(T.status, ["done"; "error"]);
            tc.verifyTrue(startsWith(T.message(2), "outputs stamp"));
        end

        function skipRetriedWhenStampChanges(tc)
            runs = DatasetRuns();
            keys = ["a" "bb"];
            stamps = containers.Map({'a', 'bb'}, {'1', '1'});
            sf = @(k) string(stamps(char(k)));
            skip = @(src) failFor(src, "bb", 'selectUnits:NoUnits');
            [~, T] = runs.run(@(k) tc.source(k), keys, skip, Name="x", Id=1, SkipIds="selectUnits:NoUnits", StampFcn=sf);
            tc.verifyEqual(T.status, ["done"; "skipped"]);
            tc.Calls = strings(0, 1);
            [~, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1, StampFcn=sf);
            tc.verifyEqual(T.status, ["cached"; "skipped"], 'A kept skip holds while the stamp does.');
            tc.verifyEmpty(tc.Calls);
            stamps('bb') = '2'; %#ok<NASGU> a containers.Map is a handle; e.g. the dataset was sorted since
            tc.verifyEqual(runs.status("x", keys, 1, Stamps=["1" "2"]), ["current"; "old"]);
            [v, T] = runs.run(@(k) tc.source(k), keys, @(src) src.n, Name="x", Id=1, StampFcn=sf);
            tc.verifyEqual(T.status, ["cached"; "done"], 'The skip is tried again.');
            tc.verifyEqual(v{2}, 2);
            tc.verifyEqual(tc.Calls, "bb");
        end

        function outputsStampOfFiles(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            d = string(fullfile(tmp.Folder, "subj1_day1"));
            mkdir(d);
            writeText(fullfile(d, "subj1_day1_manifest.json"), "{}");
            writeText(fullfile(d, "params.py"), "dat_path = 'x.bin'");
            cg = fullfile(d, "cluster_group.tsv");
            writeText(cg, "cluster_id" + char(9) + "group" + newline + "0" + char(9) + "good" + newline);
            writeText(fullfile(d, "spike_clusters.npy"), "abc");
            writeText(fullfile(d, "pc_features.npy"), "large, not stamped");
            out = DatasetOutputs(d);
            [s0, sorted] = outputsStamp(out);
            tc.verifyClass(s0, 'string');
            tc.verifyTrue(sorted, 'The listing finds params.py: has("sorting").');
            tc.verifyEqual(sorted, out.has("sorting"));
            tc.verifyTrue(contains(s0, "manifest subj1_day1_manifest.json 2 "), s0);
            tc.verifyTrue(contains(s0, "sorting cluster_group.tsv "), s0);
            tc.verifyTrue(contains(s0, "sorting spike_clusters.npy 3 "), s0);
            tc.verifyTrue(contains(s0, "sorting params.py "), s0);
            tc.verifyFalse(contains(s0, "pc_features"), s0);
            tc.verifyFalse(contains(lower(s0), lower(string(tmp.Folder))), 'File names only, no folders.');
            tc.verifyEqual(outputsStamp(out), s0, 'The same files give the same stamp.');
            % phy curation: a size change of a sorting file (listed when the stamp is taken)
            fid = fopen(cg, 'a'); fprintf(fid, '1\tmua\n'); fclose(fid);
            s1 = outputsStamp(out);
            tc.verifyNotEqual(s1, s0);
            % a modification time alone
            jf = java.io.File(char(cg));
            jf.setLastModified(jf.lastModified() - 3600 * 1000);
            s2 = outputsStamp(out);
            tc.verifyNotEqual(s2, s1);
            % the manifest is a candidate: seen once the outputs are refreshed (scanned again)
            writeText(fullfile(d, "subj1_day1_manifest.json"), "{""tags"": ""ofc""}");
            tc.verifyEqual(outputsStamp(out), s2, 'Candidates are what refresh found: no I/O.');
            out.refresh();
            s3 = outputsStamp(out);
            tc.verifyNotEqual(s3, s2);
            % a folder without a sort
            e = string(fullfile(tmp.Folder, "subj2_day1"));
            mkdir(e);
            writeText(fullfile(e, "subj2_day1_manifest.json"), "{}");
            [s4, sorted4] = outputsStamp(DatasetOutputs(e));
            tc.verifyFalse(sorted4);
            tc.verifyFalse(contains(s4, "sorting "), s4);
        end
    end
end


function writeText(file, text)
fid = fopen(file, 'w');
fwrite(fid, char(text));
fclose(fid);
end


function s = failStamp(key, bad)
if key == bad
    error('some:Disk', 'cannot list %s', key);
end
s = "ok";
end


function T = runTable(runs, source, keys, fn, varargin)
[~, T] = runs.run(source, keys, fn, 'Name', "x", 'Id', 1, varargin{:});
end


function v = failFor(src, key, id)
if src.name == key
    error(id, 'no luck in %s', key);
end
v = src.n;
end


function cancelWhen(tf)
if tf
    error('Test:Canceled', 'Canceled by the test.');
end
end


function v = checkedLength(src, check)
check();
v = src.n;
end
