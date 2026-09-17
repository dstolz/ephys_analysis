classdef test_NasSessions < matlab.unittest.TestCase
    %test_NasSessions  Tests for findNasSessions and copyNasSessions.
    %   Builds fake NAS trees (ePsych files and Intan folders with small dummy
    %   files) in a temporary folder. Tests that copy need robocopy and are
    %   skipped off Windows.
    %
    %   Usage
    %     runtests("test_NasSessions")
    %     run_all_tests("test_NasSessions")

    properties
        Root      string   % temporary folder
        Epsych    string   % fake ePsych root
        Intan     string   % fake Intan root
        Dest      string   % local destination root (not created)
    end

    properties (Constant)
        Subj = "SUBJ-ID-1255"
    end

    methods (TestMethodSetup)
        function makeTree(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(f.Folder);
            tc.Epsych = fullfile(tc.Root, "nas", "epsych_files", "Data");
            tc.Intan = fullfile(tc.Root, "nas", "intan_files", "Data");
            tc.Dest = fullfile(tc.Root, "EPHYS");
            mkdir(tc.Epsych);
            mkdir(tc.Intan);
        end
    end

    methods (Test)
        % ---------------------------------------------------------------- pairing
        function singleSessionPaired(tc)
            e = tc.addEpsych(tc.Subj, "260916T110742");
            i = tc.addIntan(tc.Subj, "260916_110907");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(T.EpsychFile, e);
            tc.verifyEqual(T.IntanDir, i);
            tc.verifyEqual(T.DeltaT, -seconds(85));
            tc.verifyEqual(T.IntanTime, datetime(2026, 9, 16, 11, 9, 7));
            tc.verifyEqual(T.DestDir, string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907")));
        end

        function threeSessionsPairOneToOneGlobally(tc)
            % I2's nearest ePsych file (E1, 100 s) is even nearer to I1 (10 s):
            % first-come per Intan folder would give it to I2.
            tc.addIntan(tc.Subj, "260916_100000");   % I1
            tc.addIntan(tc.Subj, "260916_100130");   % I2
            tc.addIntan(tc.Subj, "260916_103000");   % I3
            e1 = tc.addEpsych(tc.Subj, "260916T095950");
            e2 = tc.addEpsych(tc.Subj, "260916T095800");
            e3 = tc.addEpsych(tc.Subj, "260916T102820");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 3);
            tc.verifyEqual(T.Status, repmat("paired", 3, 1));
            tc.verifyEqual(T.EpsychFile, [e1; e2; e3]);
            tc.verifyEqual(seconds(T.DeltaT), [-10; -210; -100]);
        end

        function unpairedOnEitherSide(tc)
            e = tc.addEpsych(tc.Subj, "260916T090000");   % aborted, no recording
            i = tc.addIntan(tc.Subj, "260916_140000");    % recording without behavior
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 2);
            tc.verifyEqual(T.Status, ["epsych_only"; "intan_only"]);
            tc.verifyEqual(T.EpsychFile(1), e);
            tc.verifyEqual(T.IntanDir(2), i);
            tc.verifyEqual(T.EpsychFile(2), "");
            tc.verifyEqual(T.DestDir(1), string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916T090000")));
        end

        function equidistantIsAmbiguousAndNeverCopied(tc)
            tc.addIntan(tc.Subj, "260916_120000");
            tc.addEpsych(tc.Subj, "260916T115900");
            tc.addEpsych(tc.Subj, "260916T120100");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 3);
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            tc.verifyTrue(all(T.Note ~= ""));
            tc.verifySubstring(char(T.Note(T.IntanDir ~= "")), 'T115900.mat');

            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, repmat("skipped", 3, 1));
            tc.verifyFalse(isfolder(tc.Dest));
        end

        function nearTieWithinMarginIsAmbiguous(tc)
            tc.addIntan(tc.Subj, "260916_120000");
            tc.addEpsych(tc.Subj, "260916T115840");   % -80 s
            tc.addEpsych(tc.Subj, "260916T115900");   % -60 s, 20 s nearer: within 30 s
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            T = tc.find(tc.Subj, "260916", AmbiguityMargin=seconds(10));
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "paired"]);
        end

        function clockSkewWithinMaxLag(tc)
            e = tc.addEpsych(tc.Subj, "260916T120040");   % 40 s after Intan
            tc.addIntan(tc.Subj, "260916_120000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(T.EpsychFile, e);
            tc.verifyEqual(T.DeltaT, seconds(40));

            T = tc.find(tc.Subj, "260916", MaxLagTime=seconds(30));
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "intan_only"]);
        end

        function leadBeyondMaxLeadIsNotPaired(tc)
            tc.addEpsych(tc.Subj, "260916T114900");       % 11 min before
            tc.addIntan(tc.Subj, "260916_120000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "intan_only"]);
        end

        function sessionCrossingMidnight(tc)
            e = tc.addEpsych(tc.Subj, "260916T235830");
            i = tc.addIntan(tc.Subj, "260917_000030");
            for spec = {"260916", "260917", datetime(2026, 9, 16), datetime(2026, 9, 17) + [0 1]}
                T = tc.find(tc.Subj, spec{1});
                tc.verifyEqual(height(T), 1);
                tc.verifyEqual(T.Status, "paired");
                tc.verifyEqual([T.EpsychFile, T.IntanDir], [e, i]);
                tc.verifyEqual(T.DeltaT, -seconds(120));
            end
            tc.verifyEmpty(tc.find(tc.Subj, "260918"));
        end

        function durationAndTrialsFromHeaders(tc)
            % Real headers give the recording duration and the trial count;
            % the dummy files of an unreadable session leave NaN.
            e = fullfile(tc.Epsych, tc.Subj, tc.Subj + "_260916T110742.mat");
            mkdir(fileparts(e));
            Data = repmat(struct('TrialID', 1, 'RespCode', 0), 1, 7); %#ok<NASGU>
            Info = struct('Subject', tc.Subj); %#ok<NASGU>
            save(e, 'Data', 'Info');
            [~, R] = tc.addSyntheticIntan("260916_110907");
            tc.addEpsych(tc.Subj, "260916T140000");       % dummy file, no recording

            % the synthetic recording is shorter than the default minimum
            T = tc.find(tc.Subj, "260916", MinIntanDuration=seconds(0));
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"]);
            tc.verifyEqual(seconds(T.IntanDuration(1)), R.duration, 'AbsTol', 1e-9);
            tc.verifyEqual(T.EpsychTrials(1), 7);
            tc.verifyTrue(isnan(T.IntanDuration(2)));
            tc.verifyTrue(isnan(T.EpsychTrials(2)));
        end

        function shortRecordingIsNotPaired(tc)
            % A recording shorter than MinIntanDuration (2 min by default)
            % is never a candidate, so it cannot make a set ambiguous; one
            % whose headers cannot be read (the dummy folder) pairs as usual.
            e = tc.addEpsych(tc.Subj, "260916T115900");
            short = tc.addSyntheticIntan("260916_120000");   % -60 s, well under 2 min
            other = tc.addIntan(tc.Subj, "260916_120010");   % -70 s, unreadable headers
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.IntanDir, [short; other]);
            tc.verifyEqual(T.Status, ["intan_only"; "paired"]);
            tc.verifyEqual(T.EpsychFile(2), e);
            tc.verifyLessThan(T.IntanDuration(1), minutes(2));
            tc.verifySubstring(char(T.Note(1)), 'shorter than the 00:02:00 minimum');
            tc.verifyTrue(isnan(T.IntanDuration(2)));

            T = tc.find(tc.Subj, "260916", MinIntanDuration=seconds(0));
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1), "without the minimum, 10 s apart is a tie");

            % the minimum itself is long enough
            rmdir(other, 's');
            d = T.IntanDuration(T.IntanDir == short);
            T = tc.find(tc.Subj, "260916", MinIntanDuration=d);
            tc.verifyEqual(T.Status, "paired");
            T = tc.find(tc.Subj, "260916", MinIntanDuration=d + milliseconds(1));
            tc.verifyEqual(T.Status, ["epsych_only"; "intan_only"]);
            tc.verifySubstring(char(T.Note(1)), 'no Intan recording of at least');
        end

        function similarSubjectIDsNeverMix(tc)
            own = tc.addEpsych("SUBJ-ID-125", "260916T110742");
            tc.addIntan("SUBJ-ID-125", "260916_110907");
            tc.addEpsych(tc.Subj, "260916T110742");
            tc.addIntan(tc.Subj, "260916_110907");
            % a longer ID's files filed in the shorter ID's folders
            misE = tc.addFile(fullfile(tc.Epsych, "SUBJ-ID-125", "SUBJ-ID-1255_260916T130000.mat"));
            misI = fullfile(tc.Intan, "SUBJ-ID-125", "SUBJ-ID-1255_260916_130100");
            mkdir(misI);

            [T, S] = tc.find("SUBJ-ID-125", "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.EpsychFile, own);
            tc.verifyEqual(T.Subject, "SUBJ-ID-125");
            tc.verifyTrue(all(ismember([misE; misI], S.Path)));

            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(height(T), 1);
            tc.verifyTrue(contains(T.IntanDir, "SUBJ-ID-1255" + filesep + "SUBJ-ID-1255_"));
        end

        function malformedNamesSkippedAndLogged(tc)
            tc.addEpsych(tc.Subj, "260916T110742");
            tc.addIntan(tc.Subj, "260916_110907");
            ed = fullfile(tc.Epsych, tc.Subj);
            nd = fullfile(tc.Intan, tc.Subj);
            bad = [ ...
                tc.addFile(fullfile(ed, tc.Subj + "_260916T1107.mat"))
                tc.addFile(fullfile(ed, tc.Subj + "_260916T110742 (1).mat"))
                tc.addFile(fullfile(ed, tc.Subj + "_261316T110742.mat"))     % month 13
                tc.addFile(fullfile(ed, "notes.txt"))
                string(fullfile(nd, tc.Subj + "_260916_110907_old"))
                string(fullfile(nd, tc.Subj + "_260931_110907"))             % 31 September
                tc.addFile(fullfile(nd, tc.Subj + "_260916_120000"))];       % a file, not a folder
            mkdir(bad(5)); mkdir(bad(6));

            logged = containers.Map('KeyType', 'double', 'ValueType', 'any');
            [T, S] = findNasSessions(tc.Subj, "260916", EpsychRoot=tc.Epsych, IntanRoot=tc.Intan, ...
                DestRoot=tc.Dest, LogFcn=@(m) appendLog(logged, m));
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(sort(S.Path), sort(bad));
            lines = string(logged.values);
            for b = bad.'
                tc.verifyTrue(any(startsWith(lines, "Skipped " + b)), "not logged: " + b);
            end
        end

        function missingRootErrors(tc)
            tc.verifyError(@() findNasSessions(tc.Subj, "260916", EpsychRoot=fullfile(tc.Root, "nope"), ...
                IntanRoot=tc.Intan, LogFcn=@(~) []), 'findNasSessions:RootNotFound');
            tc.verifyError(@() findNasSessions(tc.Subj, "261340", EpsychRoot=tc.Epsych, ...
                IntanRoot=tc.Intan, LogFcn=@(~) []), 'findNasSessions:BadDate');
        end

        % ---------------------------------------------------------------- stitching
        function stitchMergesRowsInChronologicalOrder(tc)
            [e1, i] = tc.addPair("260916T110742", "260916_110907");
            e2 = tc.addEpsych(tc.Subj, "260916T114000");   % restarted during the recording
            e3 = tc.addEpsych(tc.Subj, "260916T121500");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"; "epsych_only"]);

            [S, row, kept] = stitchNasSessions(T, [2 1]);   % any order, any status
            tc.verifyEqual([height(S), row], [2, 1]);
            tc.verifyEqual(kept, [true; false; true]);
            tc.verifyEqual(S.Status, ["stitched"; "epsych_only"]);
            tc.verifyEqual(S.IntanDir(1), i);
            tc.verifyEqual(S.StitchFiles{1}, [e1; e2]);
            tc.verifyEqual([S.EpsychFile(1), S.EpsychFile(2)], [e1, e3]);
            tc.verifyEqual(S.DeltaT(1), -seconds(85));
            tc.verifyEqual(S.DestDir(1), T.DestDir(1));
            tc.verifySubstring(char(S.Note(1)), 'T110742.mat (-85 s); SUBJ-ID-1255_260916T114000.mat (+1853 s)');
            tc.verifyTrue(isempty(T.StitchFiles{1}) && isempty(S.StitchFiles{2}));

            S = stitchNasSessions(S, logical([1 1]));       % a stitched row takes in more files
            tc.verifyEqual(height(S), 1);
            tc.verifyEqual(S.StitchFiles{1}, [e1; e2; e3]);
        end

        function stitchRefusesBadRows(tc)
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260916T140000", "260916_140130");
            tc.addEpsych(tc.Subj, "260916T114000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"; "paired"]);
            tc.verifyError(@() stitchNasSessions(T, 1), 'stitchNasSessions:BadRows');
            tc.verifyError(@() stitchNasSessions(T, [1 3]), 'stitchNasSessions:BadRows', "two Intan folders");
            tc.verifyError(@() stitchNasSessions(T, [1 4]), 'stitchNasSessions:BadRows', "no such row");
            T.EpsychFile(2) = "";
            tc.verifyError(@() stitchNasSessions(T, [1 2]), 'stitchNasSessions:BadRows', "one ePsych file");
        end

        % ---------------------------------------------------------------- copying
        function dryRunWritesNothing(tc)
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copyNasSessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);   % DryRun defaults to true
            tc.verifyEqual(R.CopyStatus, "planned");
            tc.verifyEqual(R.NumFiles, 5);   % 4 Intan files + the ePsych file
            tc.verifyFalse(isfolder(tc.Dest));
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before);
        end

        function copyVerifiesAndWritesManifest(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [e, i] = tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            dest = fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907");
            tc.verifyEqual(R.DestDir, string(dest));
            tc.verifyTrue(isfile(fullfile(dest, tc.Subj + "_260916T110742.mat")));   % original ePsych name
            tc.verifyTrue(isfile(fullfile(dest, "amplifier.dat")));
            tc.verifyTrue(isfile(fullfile(dest, "sub", "nested.bin")));
            tc.verifyTrue(isfolder(fullfile(dest, "empty_sub")));
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before);   % source untouched

            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.status), "copied");
            tc.verifyEqual(string(m.intan.sourceDir), i);
            tc.verifyEqual(string(m.epsych.sourceFile), e);
            tc.verifyEqual(m.deltaT_s, -85);
            tc.verifyEqual(string(m.pairingStatus), "paired");
            tc.verifyNotEmpty(m.copy.host);
            abc = m.intan.files(strcmp({m.intan.files.relativePath}, 'abc.txt'));
            tc.verifyEqual(string(abc.sha256Source), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            tc.verifyEqual(abc.sha256Destination, abc.sha256Source);
            tc.verifyEqual(numel(m.epsych.files), 1);
        end

        function destinationExists(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);

            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", R.Message);
            R = copyNasSessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", "dry run");

            amp = fullfile(R.DestDir, "amplifier.dat");
            tc.writeBytes(amp, uint8(1:10));
            info = dir(amp);
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IfExists="error", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            after = dir(amp);
            tc.verifyEqual([after.bytes, after.datenum], [info.bytes, info.datenum], "nothing overwritten");
        end

        function verificationFailureIsReported(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            truncate = @(f) tc.overwriteIf(f, "amplifier.dat", uint8(1:3));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, BeforeVerifyFcn=truncate, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'VERIFICATION FAILED');
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            tc.verifyTrue(isfile(fullfile(R.DestDir, "amplifier.dat")), "partial copy kept");
            [~, n, x] = fileparts(T.EpsychFile);
            tc.verifyFalse(isfile(fullfile(R.DestDir, n + x)), "the files after the bad one are not copied");
            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.status), "failed");
        end

        function checksumCatchesSameSizeCorruption(tc)
            % The same number of different bytes passes the size check and
            % fails the SHA-256 checksum of that file, which stops the session.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            src = dir(fullfile(T.IntanDir, "amplifier.dat"));
            corrupt = @(f) tc.overwriteIf(f, "amplifier.dat", zeros(1, src.bytes, 'uint8'));

            R = copyNasSessions(T, DestRoot=fullfile(tc.Root, "size_only"), DryRun=false, ...
                BeforeVerifyFcn=corrupt, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", "a size check cannot see it");

            shown = containers.Map('KeyType', 'double', 'ValueType', 'any');
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", BeforeVerifyFcn=corrupt, ...
                ProgressFcn=@(~, m) appendLog(shown, m), LogFcn=@(~) []);
            tc.verifyTrue(any(contains(string(shown.values), "SHA-256 checksum")), "each checksum is shown");
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'amplifier.dat SHA-256 differs');
            [~, n, x] = fileparts(T.EpsychFile);
            tc.verifyFalse(isfile(fullfile(R.DestDir, n + x)), "the files after the bad one are not copied");
            m = jsondecode(fileread(R.ManifestFile));
            amp = m.intan.files(strcmp({m.intan.files.relativePath}, 'amplifier.dat'));
            tc.verifyNotEmpty(amp.sha256Source);
            tc.verifyNotEqual(amp.sha256Destination, amp.sha256Source);
        end

        function oneFailureDoesNotStopTheBatch(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260916T140000", "260916_140130");
            T = tc.find(tc.Subj, "260916");
            rmdir(T.IntanDir(1), 's');   % NAS folder vanished after the search
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, ["failed"; "copied"]);
            tc.verifySubstring(char(R.Message(1)), 'not found');
        end

        function unpairedCopiedOnlyWhenIncluded(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            e = tc.addEpsych(tc.Subj, "260916T090000");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifyFalse(isfolder(tc.Dest));
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            [~, n, x] = fileparts(e);
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916T090000", n + x)));
        end

        function copyStitchedSession(tc)
            % The Intan files are copied; the two ePsych files become one
            % stitched session file, and nothing else ePsych is copied.
            [e1, i] = tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);             % replace the dummy with a real session
            e2 = tc.addSession("260916T114000", 2);
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.EpsychTrials, [3; 2]);
            S = stitchNasSessions(T, [1 2]);
            tc.verifyEqual(S.EpsychTrials, 5);

            R = copyNasSessions(S, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "planned");
            tc.verifyEqual(R.NumFiles, 5);   % 4 Intan files + the stitched file
            tc.verifySubstring(char(R.Message), 'stitch 2 ePsych files into SUBJ-ID-1255_260916T110742_stitched.mat');
            tc.verifyFalse(isfolder(tc.Dest));

            tc.assumeTrue(ispc, "robocopy needs Windows");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copyNasSessions(S, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before, "source untouched");
            out = fullfile(R.DestDir, tc.Subj + "_260916T110742_stitched.mat");
            [~, n1, x1] = fileparts(e1);
            [~, n2, x2] = fileparts(e2);
            tc.verifyTrue(isfile(out));
            tc.verifyFalse(isfile(fullfile(R.DestDir, n1 + x1)) || isfile(fullfile(R.DestDir, n2 + x2)), ...
                "the individual ePsych files are not copied");
            tc.verifyTrue(isfile(fullfile(R.DestDir, "sub", "nested.bin")));
            tc.verifyEqual(height(findEpsychSessions(R.DestDir)), 1, "one behavior file in the session folder");
            B = readEpsychSession(out);
            tc.verifyEqual(B.StitchPart, [1; 1; 1; 2; 2]);
            tc.verifyEqual(B.TrialIndex, (1:5).');

            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.pairingStatus), "stitched");
            tc.verifyEqual(string(m.intan.sourceDir), i);
            tc.verifyEqual(string(m.epsych.sourceFile), "");
            tc.verifyEqual(string(m.epsych.destFile), string(out));
            tc.verifyEqual(m.epsych.stitch.nTrials, 5);
            tc.verifyEqual(string({m.epsych.stitch.parts.source}).', [e1; e2]);
            tc.verifyEqual([m.epsych.stitch.parts.nTrials], [3 2]);
            tc.verifyEqual(strlength(string({m.epsych.stitch.parts.sha256Source})), [64 64]);
            tc.verifyEqual(strlength(string(m.epsych.stitch.sha256)), 64);

            R = copyNasSessions(S, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", R.Message);

            tc.addSession("260916T114000", 4);             % the source changed since
            R = copyNasSessions(S, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'other versions');
        end

        function unstitchableFilesFailInPreview(tc)
            % Two ambiguous ePsych files stitched by hand, but the second
            % starts before the first one's last trial: the dry run refuses it.
            tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);             % trials end 10, 20, 30 s after the start
            tc.addSession("260916T110750", 2);             % starts 8 s after it
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            S = stitchNasSessions(T, 1:3);
            tc.verifyEqual(S.Status, "stitched");
            R = copyNasSessions(S, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'cannot be stitched');
            tc.verifySubstring(char(R.Message), 'before the last trial');
            tc.verifyFalse(isfolder(tc.Dest));
        end

        function stitchedFileVerificationFailure(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);
            tc.addSession("260916T114000", 2);
            S = stitchNasSessions(tc.find(tc.Subj, "260916"), [1 2]);
            % a stitched file that lost a trial after it was written
            drop = @(f) tc.dropTrialIf(f, tc.Subj + "_260916T110742_stitched.mat");
            R = copyNasSessions(S, DestRoot=tc.Dest, DryRun=false, BeforeVerifyFcn=drop, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'holds 4 trials, its parts 5');
        end

        function appFindPreviewCopy(tc)
            % The NAS tab end to end: find, ambiguous rows refuse a tick,
            % dry run writes nothing, copy writes the ticked session.
            g = EphysPreprocessingApp.PrefGroup;
            saved = [];
            if ispref(g); saved = getpref(g); end
            tc.addTeardown(@() restorePrefs(g, saved));
            if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end

            tc.addPair("260916T110742", "260916_110907");
            tc.addIntan(tc.Subj, "260916_150000");        % ambiguous: two ePsych files 60 s either side
            tc.addEpsych(tc.Subj, "260916T145900");
            tc.addEpsych(tc.Subj, "260916T150100");
            tc.addEpsych(tc.Subj, "260916T170000");       % ePsych only

            app = EphysPreprocessingApp;
            tc.addTeardown(@() delete(app.Fig));
            tc.verifyEqual(app.Tabs.SelectedTab, app.TabProject);
            app.selectTab(app.TabNas);
            app.NasSubjectField.Value = char(tc.Subj);
            app.NasFromDatePicker.Value = datetime(2026, 9, 16);
            app.NasToDatePicker.Value = NaT;
            app.NasEpsychRootField.Value = char(tc.Epsych);
            app.NasIntanRootField.Value = char(tc.Intan);
            app.NasDestRootField.Value = char(tc.Dest);
            app.NasScanAfterCheckBox.Value = false;

            app.onNasFind();
            T = app.NasSessions;
            tc.verifyEqual(T.Status, ["paired"; "ambiguous"; "ambiguous"; "ambiguous"; "epsych_only"]);
            tc.verifyEqual(app.NasTicked, T.Status == "paired", "only paired rows ticked");
            tc.verifyEqual(height(app.NasTable.Data), 5);
            tc.verifyTrue(all(ismember(["Duration" "Trials"], string(app.NasTable.Data.Properties.VariableNames))));
            tc.verifyTrue(contains(string(app.NasLogArea.Value{end}), "1 paired"));

            amb = find(T.Status == "ambiguous", 1);
            app.onNasTableEdited(struct('Indices', [amb 1], 'NewData', true));
            tc.verifyFalse(app.NasTicked(amb), "an ambiguous row cannot be ticked");
            app.onNasTableEdited(struct('Indices', [5 1], 'NewData', true));
            tc.verifyTrue(app.NasTicked(5), "an unpaired row can be ticked by hand");
            app.onNasTableEdited(struct('Indices', [5 1], 'NewData', false));

            app.onNasCopy(true);
            tc.verifyEqual(app.NasCopyStatus(1), "planned");
            tc.verifyEqual(app.NasCopyStatus(2:end), strings(4, 1));
            tc.verifyFalse(isfolder(tc.Dest), "preview writes nothing");

            tc.assumeTrue(ispc, "robocopy needs Windows");
            app.onNasCopy(false);
            tc.verifyEqual(app.NasCopyStatus(1), "copied", app.NasMessage(1));
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907", "session_manifest.json")));
            tc.verifyEqual(app.NasTable.Data.Result(1), "copied");
            p = getpref(g, 'NasOptions');
            tc.verifyEqual(string(p.destRoot), tc.Dest, "the NAS settings are preferences");
            tc.verifyEqual(p.minDurationMin, 2);
        end

        function appStitchAndUnstitch(tc)
            % Select an Intan row and an ePsych-only row, Stitch, then Unstitch.
            g = EphysPreprocessingApp.PrefGroup;
            saved = [];
            if ispref(g); saved = getpref(g); end
            tc.addTeardown(@() restorePrefs(g, saved));
            if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end

            tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);
            tc.addSession("260916T114000", 2);
            tc.addEpsych(tc.Subj, "260916T170000");

            app = EphysPreprocessingApp;
            tc.addTeardown(@() delete(app.Fig));
            app.selectTab(app.TabNas);
            app.NasSubjectField.Value = char(tc.Subj);
            app.NasFromDatePicker.Value = datetime(2026, 9, 16);
            app.NasToDatePicker.Value = NaT;
            app.NasEpsychRootField.Value = char(tc.Epsych);
            app.NasIntanRootField.Value = char(tc.Intan);
            app.NasDestRootField.Value = char(tc.Dest);
            app.NasScanAfterCheckBox.Value = false;
            app.onNasFind();
            found = app.NasSessions;
            tc.verifyEqual(found.Status, ["paired"; "epsych_only"; "epsych_only"]);

            app.NasTable.Selection = [1 2];
            app.onNasStitch();
            tc.verifyEqual(app.NasSessions.Status, ["stitched"; "epsych_only"]);
            tc.verifyEqual(app.NasTicked, [true; false]);
            tc.verifyEqual(app.NasTable.Data.("ePsych file")(1), ...
                tc.Subj + "_260916T110742.mat + " + tc.Subj + "_260916T114000.mat");
            tc.verifyTrue(startsWith(app.NasSummaryLabel.Text, "0 paired, 1 stitched"));

            app.onNasCopy(true);
            tc.verifyEqual(app.NasCopyStatus(1), "planned", app.NasMessage(1));

            app.NasTable.Selection = 1;
            app.onNasUnstitch();
            tc.verifyEqual(app.NasSessions.Status, found.Status);
            tc.verifyEqual(app.NasSessions.EpsychFile, found.EpsychFile);
            tc.verifyEqual(app.NasTicked, [true; false; false]);
            tc.verifyEqual(app.NasCopyStatus, strings(3, 1));
        end

        function cancelStopsBeforeCopying(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copyNasSessions(T, DestRoot=tc.Dest, DryRun=false, CancelFcn=@() true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "cancelled");
            tc.verifyFalse(isfolder(R.DestDir));
        end
    end

    methods
        function [T, S] = find(tc, subj, spec, varargin)
            [T, S] = findNasSessions(subj, spec, 'EpsychRoot', tc.Epsych, 'IntanRoot', tc.Intan, ...
                'DestRoot', tc.Dest, 'LogFcn', @(~) [], varargin{:});
        end

        function f = addEpsych(tc, subj, stamp)
            f = tc.addFile(fullfile(tc.Epsych, subj, subj + "_" + stamp + ".mat"));
        end

        function d = addIntan(tc, subj, stamp)
            d = string(fullfile(tc.Intan, subj, subj + "_" + stamp));
            mkdir(d);
            tc.writeBytes(fullfile(d, "info.rhd"), uint8(1:100));
        end

        function [d, R] = addSyntheticIntan(tc, stamp)
            %addSyntheticIntan  An Intan folder with readable headers: a short synthetic recording.
            d = string(fullfile(tc.Intan, tc.Subj, tc.Subj + "_" + stamp));
            R = makeSyntheticRecording(d, Subject=tc.Subj, Format="one-file-per-signal", ...
                NumChannels=2, NumTrials=4, Fs=2000, SortedOutput=false, Artifacts=false, WriteManifest=false);
            delete(R.behaviorFile);
        end

        function [e, i] = addPair(tc, epsychStamp, intanStamp)
            %addPair  A session with a few Intan files, a subfolder and an empty subfolder.
            e = tc.addEpsych(tc.Subj, epsychStamp);
            i = tc.addIntan(tc.Subj, intanStamp);
            tc.writeBytes(fullfile(i, "amplifier.dat"), uint8(mod(0:300000, 256)));
            tc.writeBytes(fullfile(i, "abc.txt"), uint8('abc'));
            mkdir(fullfile(i, "sub"));
            tc.writeBytes(fullfile(i, "sub", "nested.bin"), uint8(7:77));
            mkdir(fullfile(i, "empty_sub"));
        end

        function f = addSession(tc, stamp, nTrials)
            %addSession  A real ePsych session file (Data + Info) starting at its name's time.
            f = string(fullfile(tc.Epsych, tc.Subj, tc.Subj + "_" + stamp + ".mat"));
            if ~isfolder(fileparts(f)); mkdir(fileparts(f)); end
            t0 = datetime(stamp, 'InputFormat', 'yyMMdd''T''HHmmss');
            Data = struct('TrialType', num2cell(mod(1:nTrials, 2)), 'TrialIndex', num2cell(1:nTrials), ...
                'computerTimestamp', num2cell(t0 + seconds(10 * (1:nTrials))));
            Info = struct('Subject', struct('Name', tc.Subj), 'StartTime', t0);
            save(f, 'Data', 'Info');
        end

        function dropTrialIf(~, f, name)
            %dropTrialIf  Remove the last trial of a just-written stitched file named NAME (a BeforeVerifyFcn).
            [~, n, x] = fileparts(f);
            if n + x ~= name; return; end
            L = load(f, 'Data', 'Info');
            Data = L.Data(1:end-1);
            Info = L.Info;
            save(f, 'Data', 'Info');
        end

        function f = addFile(tc, f)
            f = string(f);
            if ~isfolder(fileparts(f)); mkdir(fileparts(f)); end
            tc.writeBytes(f, uint8('dummy ePsych'));
        end

        function writeBytes(~, f, bytes)
            fid = fopen(f, 'w');
            fwrite(fid, bytes, 'uint8');
            fclose(fid);
        end

        function overwriteIf(tc, f, name, bytes)
            %overwriteIf  Replace a just-copied file named NAME (a BeforeVerifyFcn).
            [~, n, x] = fileparts(f);
            if n + x == name; tc.writeBytes(f, bytes); end
        end

        function L = listTree(~, root)
            D = dir(fullfile(root, '**', '*'));
            D = D(~ismember({D.name}, {'.', '..'}));
            L = sort(string(fullfile({D.folder}, {D.name})) + " " + string([D.bytes]) + " " + string([D.datenum]));
        end
    end
end


function restorePrefs(g, saved)
if ispref(g); rmpref(g); end
if isstruct(saved)
    for f = string(fieldnames(saved)).'
        setpref(g, char(f), saved.(f));
    end
end
end


function appendLog(map, msg)
map(map.Count + 1) = string(msg); %#ok<NASGU> containers.Map is a handle
end
