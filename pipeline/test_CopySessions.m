classdef test_CopySessions < matlab.unittest.TestCase
    %test_CopySessions  Tests for findCopySessions, copySessions and CopySchedule.
    %   Builds fake source trees (ePsych files, Intan folders with small dummy
    %   files and synthetic Open Ephys sessions under a second recording root)
    %   in a temporary folder. Tests that copy need robocopy and are
    %   skipped off Windows. scheduleRunsAsAWindowsTask and appSchedulesACopy
    %   create a Windows task under \ephys_analysis_test and remove it again;
    %   the first has Windows start MATLAB for a scheduled run (about a minute).
    %
    %   Usage
    %     runtests("test_CopySessions")
    %     run_all_tests("test_CopySessions")

    properties
        Root      string   % temporary folder
        Epsych    string   % fake ePsych root
        Intan     string   % fake Intan root (the first recording root)
        OpenEphys string   % fake Open Ephys root (created by addSyntheticOpenEphys)
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
            tc.OpenEphys = fullfile(tc.Root, "nas", "openephys_files", "Data");
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
            tc.verifyEqual(T.RecordingDir, i);
            tc.verifyEqual(T.DeltaT, -seconds(85));
            tc.verifyEqual(T.RecordingTime, datetime(2026, 9, 16, 11, 9, 7));
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
            tc.verifyEqual(T.Status, ["epsych_only"; "recording_only"]);
            tc.verifyEqual(T.EpsychFile(1), e);
            tc.verifyEqual(T.RecordingDir(2), i);
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
            tc.verifySubstring(char(T.Note(T.RecordingDir ~= "")), 'T115900.mat');

            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
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
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "recording_only"]);
        end

        function leadBeyondMaxLeadIsNotPaired(tc)
            tc.addEpsych(tc.Subj, "260916T114900");       % 11 min before
            tc.addIntan(tc.Subj, "260916_120000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(sort(T.Status), ["epsych_only"; "recording_only"]);
        end

        function sessionCrossingMidnight(tc)
            e = tc.addEpsych(tc.Subj, "260916T235830");
            i = tc.addIntan(tc.Subj, "260917_000030");
            for spec = {"260916", "260917", datetime(2026, 9, 16), datetime(2026, 9, 17) + [0 1]}
                T = tc.find(tc.Subj, spec{1});
                tc.verifyEqual(height(T), 1);
                tc.verifyEqual(T.Status, "paired");
                tc.verifyEqual([T.EpsychFile, T.RecordingDir], [e, i]);
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
            T = tc.find(tc.Subj, "260916", MinRecordingDuration=seconds(0));
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"]);
            tc.verifyEqual(seconds(T.RecordingDuration(1)), R.duration, 'AbsTol', 1e-9);
            tc.verifyEqual(T.EpsychTrials(1), 7);
            tc.verifyTrue(isnan(T.RecordingDuration(2)));
            tc.verifyTrue(isnan(T.EpsychTrials(2)));
        end

        function shortRecordingIsNotPaired(tc)
            % A recording shorter than MinRecordingDuration (2 min by default)
            % is never a candidate, so it cannot make a set ambiguous; one
            % whose headers cannot be read (the dummy folder) pairs as usual.
            e = tc.addEpsych(tc.Subj, "260916T115900");
            short = tc.addSyntheticIntan("260916_120000");   % -60 s, well under 2 min
            other = tc.addIntan(tc.Subj, "260916_120010");   % -70 s, unreadable headers
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.RecordingDir, [short; other]);
            tc.verifyEqual(T.Status, ["recording_only"; "paired"]);
            tc.verifyEqual(T.EpsychFile(2), e);
            tc.verifyLessThan(T.RecordingDuration(1), minutes(2));
            tc.verifySubstring(char(T.Note(1)), 'shorter than the 00:02:00 minimum');
            tc.verifyTrue(isnan(T.RecordingDuration(2)));

            T = tc.find(tc.Subj, "260916", MinRecordingDuration=seconds(0));
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1), "without the minimum, 10 s apart is a tie");

            % the minimum itself is long enough
            rmdir(other, 's');
            d = T.RecordingDuration(T.RecordingDir == short);
            T = tc.find(tc.Subj, "260916", MinRecordingDuration=d);
            tc.verifyEqual(T.Status, "paired");
            T = tc.find(tc.Subj, "260916", MinRecordingDuration=d + milliseconds(1));
            tc.verifyEqual(T.Status, ["epsych_only"; "recording_only"]);
            tc.verifySubstring(char(T.Note(1)), 'no recording of at least');
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
            tc.verifyTrue(contains(T.RecordingDir, "SUBJ-ID-1255" + filesep + "SUBJ-ID-1255_"));
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
            [T, S] = findCopySessions(tc.Subj, "260916", EpsychRoot=tc.Epsych, RecordingRoots=tc.Intan, ...
                DestRoot=tc.Dest, LogFcn=@(m) appendLog(logged, m));
            tc.verifyEqual(height(T), 1);
            tc.verifyEqual(T.Status, "paired");
            tc.verifyEqual(sort(S.Path), sort(bad));
            lines = string(logged.values);
            for b = bad.'
                tc.verifyTrue(any(startsWith(lines, "Skipped " + b)), "not logged: " + b);
            end
        end

        function openEphysSessionsPairAcrossRoots(tc)
            % An Open Ephys GUI session (named <subject>_yyyy-MM-dd_HH-mm-ss
            % with appended text) under a second root pairs like an Intan
            % folder; its duration and format come from its headers.
            [o, R] = tc.addSyntheticOpenEphys("2026-09-16_11-09-07_active");
            eO = tc.addEpsych(tc.Subj, "260916T110742");
            i = tc.addIntan(tc.Subj, "260916_140000");
            eI = tc.addEpsych(tc.Subj, "260916T135900");
            T = tc.find(tc.Subj, "260916", RecordingRoots=[tc.Intan tc.OpenEphys], MinRecordingDuration=seconds(0));
            tc.verifyEqual(T.Status, ["paired"; "paired"]);
            tc.verifyEqual([T.RecordingDir, T.EpsychFile], [o, eO; i, eI]);
            tc.verifyEqual(T.Reader, ["openephys"; "intan"]);
            tc.verifyEqual(T.RecordingTime(1), datetime(2026, 9, 16, 11, 9, 7));
            tc.verifyEqual(T.DeltaT(1), -seconds(85));
            tc.verifyEqual(seconds(T.RecordingDuration(1)), R.duration, 'AbsTol', 1e-9);
            tc.verifyTrue(isnan(T.RecordingDuration(2)));   % dummy Intan headers
            tc.verifyEqual(T.DestDir(1), string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_2026-09-16_11-09-07_active")));

            % one root only: the other root's sessions are not listed
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, ["epsych_only"; "paired"]);

            % only the name patterns asked for are matched
            [T, S] = tc.find(tc.Subj, "260916", RecordingRoots=tc.OpenEphys, ...
                NamePatterns=EphysDataset.DefaultNamePattern, MinRecordingDuration=seconds(0));
            tc.verifyEqual(T.Status, ["epsych_only"; "epsych_only"]);
            tc.verifyEqual(S.Path, o);
            tc.verifySubstring(char(S.Reason), 'does not match');
        end

        function openEphysBadNamesSkipped(tc)
            d = fullfile(tc.OpenEphys, tc.Subj);
            bad = string(fullfile(d, [tc.Subj + "_2026-09-31_11-09-07"; ...    % 31 September
                "SUBJ-ID-12555_2026-09-16_11-09-07"; tc.Subj + "_2026-09-16_11-09"]));
            for b = bad.'
                mkdir(b);
            end
            [T, S] = tc.find(tc.Subj, "260916", RecordingRoots=tc.OpenEphys);
            tc.verifyEmpty(T);
            tc.verifyEqual(sort(S.Path), sort(bad));
            tc.verifyEqual(S.Reason(S.Path == bad(1)), "the name holds an invalid date or time");
        end

        function missingRootErrors(tc)
            tc.verifyError(@() findCopySessions(tc.Subj, "260916", EpsychRoot=fullfile(tc.Root, "nope"), ...
                RecordingRoots=tc.Intan, LogFcn=@(~) []), 'findCopySessions:RootNotFound');
            tc.verifyError(@() findCopySessions(tc.Subj, "261340", EpsychRoot=tc.Epsych, ...
                RecordingRoots=tc.Intan, LogFcn=@(~) []), 'findCopySessions:BadDate');
            tc.verifyError(@() findCopySessions(tc.Subj, "260916", EpsychRoot=tc.Epsych, ...
                RecordingRoots=[tc.Intan fullfile(tc.Root, "nope")], LogFcn=@(~) []), 'findCopySessions:RootNotFound');
            tc.verifyError(@() findCopySessions(tc.Subj, "260916", EpsychRoot=tc.Epsych, RecordingRoots=tc.Intan, ...
                NamePatterns="{SubjectID}_{Date:yyMMdd}", LogFcn=@(~) []), 'findCopySessions:BadPattern');
        end

        % ---------------------------------------------------------------- stitching
        function stitchMergesRowsInChronologicalOrder(tc)
            [e1, i] = tc.addPair("260916T110742", "260916_110907");
            e2 = tc.addEpsych(tc.Subj, "260916T114000");   % restarted during the recording
            e3 = tc.addEpsych(tc.Subj, "260916T121500");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"; "epsych_only"]);

            [S, row, kept] = stitchCopySessions(T, [2 1]);   % any order, any status
            tc.verifyEqual([height(S), row], [2, 1]);
            tc.verifyEqual(kept, [true; false; true]);
            tc.verifyEqual(S.Status, ["stitched"; "epsych_only"]);
            tc.verifyEqual(S.RecordingDir(1), i);
            tc.verifyEqual(S.StitchFiles{1}, [e1; e2]);
            tc.verifyEqual([S.EpsychFile(1), S.EpsychFile(2)], [e1, e3]);
            tc.verifyEqual(S.DeltaT(1), -seconds(85));
            tc.verifyEqual(S.DestDir(1), T.DestDir(1));
            tc.verifySubstring(char(S.Note(1)), 'T110742.mat (-85 s); SUBJ-ID-1255_260916T114000.mat (+1853 s)');
            tc.verifyTrue(isempty(T.StitchFiles{1}) && isempty(S.StitchFiles{2}));

            S = stitchCopySessions(S, logical([1 1]));       % a stitched row takes in more files
            tc.verifyEqual(height(S), 1);
            tc.verifyEqual(S.StitchFiles{1}, [e1; e2; e3]);
        end

        function stitchRefusesBadRows(tc)
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260916T140000", "260916_140130");
            tc.addEpsych(tc.Subj, "260916T114000");
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, ["paired"; "epsych_only"; "paired"]);
            tc.verifyError(@() stitchCopySessions(T, 1), 'stitchCopySessions:BadRows');
            tc.verifyError(@() stitchCopySessions(T, [1 3]), 'stitchCopySessions:BadRows', "two recording folders");
            tc.verifyError(@() stitchCopySessions(T, [1 4]), 'stitchCopySessions:BadRows', "no such row");
            T.EpsychFile(2) = "";
            tc.verifyError(@() stitchCopySessions(T, [1 2]), 'stitchCopySessions:BadRows', "one ePsych file");
        end

        % ---------------------------------------------------------------- copying
        function dryRunWritesNothing(tc)
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);   % DryRun defaults to true
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
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            dest = fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907");
            tc.verifyEqual(R.DestDir, string(dest));
            tc.verifyTrue(isfile(fullfile(dest, tc.Subj + "_260916T110742.mat")));   % original ePsych name
            tc.verifyTrue(isfile(fullfile(dest, "amplifier.dat")));
            tc.verifyTrue(isfile(fullfile(dest, "sub", "nested.bin")));
            tc.verifyTrue(isfolder(fullfile(dest, "empty_sub")));
            tc.verifyEqual(tc.listTree(fullfile(tc.Root, "nas")), before);   % source untouched

            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(m.manifestVersion, 3);
            tc.verifyEqual(string(m.copy.status), "copied");
            tc.verifyEqual(string(m.recording.sourceDir), i);
            tc.verifyEqual(string(m.recording.reader), "intan");
            tc.verifyEqual(string(m.epsych.sourceFile), e);
            tc.verifyEqual(m.deltaT_s, -85);
            tc.verifyEqual(string(m.pairingStatus), "paired");
            tc.verifyNotEmpty(m.copy.host);
            abc = m.recording.files(strcmp({m.recording.files.relativePath}, 'abc.txt'));
            tc.verifyEqual(string(abc.sha256Source), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
            tc.verifyEqual(abc.sha256Destination, abc.sha256Source);
            tc.verifyEqual(numel(m.epsych.files), 1);
        end

        function copiesAnOpenEphysSession(tc)
            % The whole session folder is copied (Record Node and all); the
            % copy reads as the source does, and the manifest lists its files
            % below the session folder.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            [o, R0] = tc.addSyntheticOpenEphys("2026-09-16_11-09-07");
            e = tc.addEpsych(tc.Subj, "260916T110742");
            T = tc.find(tc.Subj, "260916", RecordingRoots=tc.OpenEphys, MinRecordingDuration=seconds(0));
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            dest = string(fullfile(tc.Dest, tc.Subj, tc.Subj + "_2026-09-16_11-09-07"));
            tc.verifyEqual(R.DestDir, dest);
            [~, en, ex] = fileparts(e);
            tc.verifyTrue(isfile(fullfile(dest, en + ex)));

            src = EphysReader.forFolder(o);
            cpy = EphysReader.forFolder(dest);
            tc.verifyEqual(string(class(cpy)), "OpenEphysReader");
            src.refreshMetadata(); cpy.refreshMetadata();
            tc.verifyEqual(cpy.Files, src.Files);
            tc.verifyEqual(cpy.Duration, R0.duration, 'AbsTol', 1e-9);

            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.recording.reader), "openephys");
            tc.verifyEqual(string(m.recording.sourceDir), o);
            rel = replace(string({m.recording.files.relativePath}), "\", "/");
            tc.verifyTrue(any(startsWith(rel, "Record Node 101/")));
            tc.verifyTrue(all(ismember(replace(src.Files, "\", "/"), rel)));
        end

        function destinationExists(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);

            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", R.Message);
            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", "dry run");

            amp = fullfile(R.DestDir, "amplifier.dat");
            tc.writeBytes(amp, uint8(1:10));
            info = dir(amp);
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, IfExists="skip", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, IfExists="error", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            after = dir(amp);
            tc.verifyEqual([after.bytes, after.datenum], [info.bytes, info.datenum], ...
                "skip and error never touch the destination");
        end

        function resumeCompletesAPartialCopy(tc)
            % A copy that stopped part way is finished, not started again and
            % not refused: the short file is completed, the missing one copied
            % and the ones already there left alone.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            dest = R.DestDir;
            full = dir(fullfile(dest, "amplifier.dat"));

            tc.writeBytes(fullfile(dest, "amplifier.dat"), uint8(1:7));   % interrupted mid-file
            delete(fullfile(dest, "sub", "nested.bin"));                  % never reached

            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);        % dry run first
            tc.verifyEqual(R.CopyStatus, "planned");
            tc.verifySubstring(char(R.Message), 'would complete a partial copy');
            tc.verifySubstring(char(R.Message), '3 of 5 file');

            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            tc.verifySubstring(char(R.Message), '3 of them were already there');
            done = dir(fullfile(dest, "amplifier.dat"));
            tc.verifyEqual(done.bytes, full.bytes, "the partial file was completed");
            tc.verifyTrue(isfile(fullfile(dest, "sub", "nested.bin")), "the missing file was copied");
            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.ifExists), "resume");
            tc.verifyEqual(m.copy.filesAlreadyPresent, 3);
        end

        function backgroundCopyReturnsAtOnce(tc)
            % Background=true launches the engine and hands control straight
            % back; polling the job reports it through to "copied".
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            t0 = tic;
            [R, job] = copySessions(T, DestRoot=tc.Dest, DryRun=false, Background=true, LogFcn=@(~) []);
            tc.verifyLessThan(toc(t0), 5, "the call must not wait for the copy");
            tc.verifyEqual(R.CopyStatus, "copying");
            tc.verifyFalse(job.Done);
            tc.verifyTrue(startsWith(job.Dir, tc.jobsFolder()), "batches in flight keep their job folder there");

            % While the batch is in flight, no other copy writes its session.
            R2 = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R2.CopyStatus, "skipped");
            tc.verifySubstring(char(R2.Message), 'another copy');

            polls = 0;
            while ~job.Done
                pause(0.05);
                [R, job] = copySessions(job);
                polls = polls + 1;
                tc.assertLessThan(polls, 1200, "the background copy never finished");
            end
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            tc.verifyTrue(isfile(fullfile(R.DestDir, "amplifier.dat")));
            tc.verifyTrue(isfile(R.ManifestFile));
            tc.verifyFalse(isfolder(job.Dir), "a finished batch removes its job folder");
            tc.verifyError(@() copySessions(job, DestRoot=tc.Dest), 'copySessions:JobTakesNoOptions');
        end

        function progressIsReportedAndNeverGoesBackwards(tc)
            % Every ProgressFcn call carries the fraction, a message and the
            % info a caller needs to show more than a percentage; the fraction
            % only ever grows, through the copy and the checksum pass alike.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            seen = containers.Map('KeyType', 'double', 'ValueType', 'any');
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", ...
                ProgressFcn=@(fr, m, info) appendProgress(seen, fr, info), LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);

            v = values(seen);            % numeric keys: values come back in call order
            calls = [v{:}];
            tc.verifyNotEmpty(calls);
            fracs = [calls.frac];
            tc.verifyGreaterThanOrEqual(min(diff(fracs)), 0, "the percentage never steps back");
            tc.verifyEqual(fracs(end), 1);

            info = [calls.info];
            tc.verifyEqual(sort(unique(string(fieldnames(info)))).', ...
                sort(["Bytes" "Phase" "Session" "SessionBytes" "Sessions"]));
            tc.verifyEqual(info(end).Phase, "done");
            tc.verifyTrue(any([info.Phase] == "copying") && any([info.Phase] == "verifying"), ...
                "both phases report themselves");
            tc.verifyTrue(all(arrayfun(@(i) i.Sessions(2) == 1, info)), "one session in the batch");
            tc.verifyEqual(info(end).Bytes, [R.TotalBytes R.TotalBytes], "the batch ends on its own size");
        end

        function verificationFailureIsReported(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            truncate = @(f) tc.overwriteIf(f, "amplifier.dat", uint8(1:3));
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, BeforeVerifyFcn=truncate, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'VERIFICATION FAILED');
            tc.verifySubstring(char(R.Message), 'amplifier.dat');
            tc.verifyTrue(isfile(fullfile(R.DestDir, "amplifier.dat")), "the copy is kept");
            [~, n, x] = fileparts(T.EpsychFile);
            tc.verifyTrue(isfile(fullfile(R.DestDir, n + x)), ...
                "a session is copied whole before it is verified, so the other files are there");
            m = jsondecode(fileread(R.ManifestFile));
            tc.verifyEqual(string(m.copy.status), "failed");
        end

        function checksumCatchesSameSizeCorruption(tc)
            % The same number of different bytes passes the size check and
            % fails the SHA-256 checksum of that file, which stops the session.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            src = dir(fullfile(T.RecordingDir, "amplifier.dat"));
            corrupt = @(f) tc.overwriteIf(f, "amplifier.dat", zeros(1, src.bytes, 'uint8'));

            R = copySessions(T, DestRoot=fullfile(tc.Root, "size_only"), DryRun=false, ...
                BeforeVerifyFcn=corrupt, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", "a size check cannot see it");

            shown = containers.Map('KeyType', 'double', 'ValueType', 'any');
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, Verify="hash", BeforeVerifyFcn=corrupt, ...
                ProgressFcn=@(~, m, ~) appendLog(shown, m), LogFcn=@(~) []);
            tc.verifyTrue(any(contains(string(shown.values), "SHA-256 checksum")), "each checksum is shown");
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'amplifier.dat SHA-256 differs');
            m = jsondecode(fileread(R.ManifestFile));
            amp = m.recording.files(strcmp({m.recording.files.relativePath}, 'amplifier.dat'));
            tc.verifyNotEmpty(amp.sha256Source);
            tc.verifyNotEqual(amp.sha256Destination, amp.sha256Source);
        end

        function oneFailureDoesNotStopTheBatch(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260916T140000", "260916_140130");
            T = tc.find(tc.Subj, "260916");
            rmdir(T.RecordingDir(1), 's');   % Source folder vanished after the search
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, ["failed"; "copied"]);
            tc.verifySubstring(char(R.Message(1)), 'not found');
        end

        function unpairedCopiedOnlyWhenIncluded(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            e = tc.addEpsych(tc.Subj, "260916T090000");
            T = tc.find(tc.Subj, "260916");
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifyFalse(isfolder(tc.Dest));
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, IncludeUnpaired=true, LogFcn=@(~) []);
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
            S = stitchCopySessions(T, [1 2]);
            tc.verifyEqual(S.EpsychTrials, 5);

            R = copySessions(S, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "planned");
            tc.verifyEqual(R.NumFiles, 5);   % 4 Intan files + the stitched file
            tc.verifySubstring(char(R.Message), 'stitch 2 ePsych files into SUBJ-ID-1255_260916T110742_stitched.mat');
            tc.verifyFalse(isfolder(tc.Dest));

            tc.assumeTrue(ispc, "robocopy needs Windows");
            before = tc.listTree(fullfile(tc.Root, "nas"));
            R = copySessions(S, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
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
            tc.verifyEqual(string(m.recording.sourceDir), i);
            tc.verifyEqual(string(m.epsych.sourceFile), "");
            tc.verifyEqual(string(m.epsych.destFile), string(out));
            tc.verifyEqual(m.epsych.stitch.nTrials, 5);
            tc.verifyEqual(string({m.epsych.stitch.parts.source}).', [e1; e2]);
            tc.verifyEqual([m.epsych.stitch.parts.nTrials], [3 2]);
            tc.verifyEqual(strlength(string({m.epsych.stitch.parts.sha256Source})), [64 64]);
            tc.verifyEqual(strlength(string(m.epsych.stitch.sha256)), 64);

            R = copySessions(S, DestRoot=tc.Dest, DryRun=false, Verify="hash", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "already_present", R.Message);

            tc.addSession("260916T114000", 4);             % the source changed since
            R = copySessions(S, DestRoot=tc.Dest, DryRun=false, IfExists="skip", LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'other versions');

            % resume rebuilds it from what the sources now hold
            S2 = stitchCopySessions(tc.find(tc.Subj, "260916"), [1 2]);
            R = copySessions(S2, DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            tc.verifyEqual(height(readEpsychSession(out)), 7, "3 + 4 trials after the source changed");
        end

        function unstitchableFilesFailInPreview(tc)
            % Two ambiguous ePsych files stitched by hand, but the second
            % starts before the first one's last trial: the dry run refuses it.
            tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);             % trials end 10, 20, 30 s after the start
            tc.addSession("260916T110750", 2);             % starts 8 s after it
            T = tc.find(tc.Subj, "260916");
            tc.verifyEqual(T.Status, repmat("ambiguous", 3, 1));
            S = stitchCopySessions(T, 1:3);
            tc.verifyEqual(S.Status, "stitched");
            R = copySessions(S, DestRoot=tc.Dest, LogFcn=@(~) []);
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
            S = stitchCopySessions(tc.find(tc.Subj, "260916"), [1 2]);
            % a stitched file that lost a trial after it was written
            drop = @(f) tc.dropTrialIf(f, tc.Subj + "_260916T110742_stitched.mat");
            R = copySessions(S, DestRoot=tc.Dest, DryRun=false, BeforeVerifyFcn=drop, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "failed");
            tc.verifySubstring(char(R.Message), 'holds 4 trials, its parts 5');
        end

        function appFindPreviewCopy(tc)
            % The Copy tab end to end: find, ambiguous rows refuse a tick,
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
            app.selectTab(app.TabCopy);
            app.CopySubjectField.Value = char(tc.Subj);
            app.CopyFromDatePicker.Value = datetime(2026, 9, 16);
            app.CopyToDatePicker.Value = NaT;
            app.CopyEpsychRootField.Value = char(tc.Epsych);
            app.CopyRecordingRootsField.Value = char(tc.Intan);
            app.CopyDestRootField.Value = char(tc.Dest);
            app.CopyScanAfterCheckBox.Value = false;

            app.onCopyFind();
            T = app.CopySessions;
            tc.verifyEqual(T.Status, ["paired"; "ambiguous"; "ambiguous"; "ambiguous"; "epsych_only"]);
            tc.verifyEqual(app.CopyTicked, T.Status == "paired", "only paired rows ticked");
            tc.verifyEqual(height(app.CopyTable.Data), 5);
            tc.verifyTrue(all(ismember(["Duration" "Trials"], string(app.CopyTable.Data.Properties.VariableNames))));
            tc.verifyTrue(contains(string(app.CopyLogArea.Value{end}), "1 paired"));

            amb = find(T.Status == "ambiguous", 1);
            app.onCopyTableEdited(struct('Indices', [amb 1], 'NewData', true));
            tc.verifyFalse(app.CopyTicked(amb), "an ambiguous row cannot be ticked");
            app.onCopyTableEdited(struct('Indices', [5 1], 'NewData', true));
            tc.verifyTrue(app.CopyTicked(5), "an unpaired row can be ticked by hand");
            app.onCopyTableEdited(struct('Indices', [5 1], 'NewData', false));

            app.onCopyRun(true);
            tc.verifyEqual(app.CopyStatus(1), "planned");
            tc.verifyEqual(app.CopyStatus(2:end), strings(4, 1));
            tc.verifyFalse(isfolder(tc.Dest), "preview writes nothing");

            tc.assumeTrue(ispc, "robocopy needs Windows");
            app.onCopyRun(false);
            tc.verifyNotEmpty(app.CopyJob, "the copy runs in the background");
            tc.verifyEqual(app.CopyStatus(1), "copying");
            tc.verifyEqual(string(app.CopyRunButton.Text), "Cancel copy");
            tc.verifyEqual(string(app.CopyFindButton.Enable), "off");
            tc.waitForCopy(app);
            tc.verifyEqual(string(app.CopyRunButton.Text), "Copy selected");
            tc.verifyEqual(string(app.CopyFindButton.Enable), "on");
            tc.verifyEqual(app.CopyStatus(1), "copied", app.CopyMessage(1));
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_110907", "session_manifest.json")));
            tc.verifyEqual(app.CopyTable.Data.Result(1), "copied");
            p = getpref(g, 'CopyOptions');
            tc.verifyEqual(string(p.destRoot), tc.Dest, "the Copy tab settings are preferences");
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
            app.selectTab(app.TabCopy);
            app.CopySubjectField.Value = char(tc.Subj);
            app.CopyFromDatePicker.Value = datetime(2026, 9, 16);
            app.CopyToDatePicker.Value = NaT;
            app.CopyEpsychRootField.Value = char(tc.Epsych);
            app.CopyRecordingRootsField.Value = char(tc.Intan);
            app.CopyDestRootField.Value = char(tc.Dest);
            app.CopyScanAfterCheckBox.Value = false;
            app.onCopyFind();
            found = app.CopySessions;
            tc.verifyEqual(found.Status, ["paired"; "epsych_only"; "epsych_only"]);

            app.CopyTable.Selection = [1 2];
            app.onCopyStitch();
            tc.verifyEqual(app.CopySessions.Status, ["stitched"; "epsych_only"]);
            tc.verifyEqual(app.CopyTicked, [true; false]);
            tc.verifyEqual(app.CopyTable.Data.("ePsych file")(1), ...
                tc.Subj + "_260916T110742.mat + " + tc.Subj + "_260916T114000.mat");
            tc.verifyTrue(startsWith(app.CopySummaryLabel.Text, "0 paired, 1 stitched"));

            app.onCopyRun(true);
            tc.verifyEqual(app.CopyStatus(1), "planned", app.CopyMessage(1));

            app.CopyTable.Selection = 1;
            app.onCopyUnstitch();
            tc.verifyEqual(app.CopySessions.Status, found.Status);
            tc.verifyEqual(app.CopySessions.EpsychFile, found.EpsychFile);
            tc.verifyEqual(app.CopyTicked, [true; false; false]);
            tc.verifyEqual(app.CopyStatus, strings(3, 1));
        end

        function cancelStopsBeforeCopying(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            R = copySessions(T, DestRoot=tc.Dest, DryRun=false, CancelFcn=@() true, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "cancelled");
            tc.verifySubstring(char(R.Message), 'before the copy started');
            tc.verifyFalse(isfolder(R.DestDir), "nothing is created for a cancelled batch");
        end

        % ---------------------------------------------------------------- still changing, in flight
        function quietTimeLeavesAChangingSessionForLater(tc)
            % A session whose source changed within MinQuietTime may still be
            % being recorded or synced: it is left for a later copy. A folder
            % counts as well as a file, since removing a file changes it.
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            quiet = @() copySessions(T, DestRoot=tc.Dest, MinQuietTime=minutes(15), LogFcn=@(~) []);
            R = quiet();
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'still being written');

            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "planned", "no quiet time by default");
            tc.age(fullfile(tc.Root, "nas"), hours(1));
            R = quiet();
            tc.verifyEqual(R.CopyStatus, "planned", R.Message);

            delete(fullfile(T.RecordingDir, "sub", "nested.bin"));   % only a folder changes
            R = quiet();
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.age(fullfile(tc.Root, "nas"), hours(1));
            tc.addEpsych(tc.Subj, "260916T110742");              % the ePsych file rewritten
            R = quiet();
            tc.verifyEqual(R.CopyStatus, "skipped");
        end

        function aSessionAnotherCopyIsWritingIsLeftAlone(tc)
            % A batch in another MATLAB (or a scheduled copy) writing the same
            % session folder: this one leaves it alone until that batch is over.
            tc.addPair("260916T110742", "260916_110907");
            T = tc.find(tc.Subj, "260916");
            job = tc.fakeBatch(T.DestDir);
            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "skipped");
            tc.verifySubstring(char(R.Message), 'another copy (started 2026-09-18 10:00)');

            tc.age(job, minutes(5));   % its heartbeat stopped: that batch is gone
            R = copySessions(T, DestRoot=tc.Dest, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "planned", R.Message);
        end

        % ---------------------------------------------------------------- scheduled copy
        function scheduledCopyTakesTheNewPairedSessions(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addPair("260915T090000", "260915_090130");      % yesterday
            tc.addPair("260910T090000", "260910_090130");      % before the days searched
            tc.addIntan(tc.Subj, "260916_150000");             % ambiguous: two ePsych files 60 s either side
            tc.addEpsych(tc.Subj, "260916T145900");
            tc.addEpsych(tc.Subj, "260916T150100");
            tc.addEpsych(tc.Subj, "260916T170000");            % ePsych only
            mkdir(tc.Dest);
            s = tc.schedule(LookBackDays=2);
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16, 13, 0, 0), LogFcn=@(~) []);
            tc.verifyEmpty(out.Errors);
            tc.verifyEqual(out.Days, datetime(2026, 9, [15 16]));
            S = out.Sessions;
            tc.verifyEqual(S.Session(S.Status == "copied"), tc.Subj + ["_260915_090130"; "_260916_110907"]);
            tc.verifyEqual(nnz(S.Status == "ambiguous"), 3);
            tc.verifyEqual(S.Status(S.Session == tc.Subj + "_260916T170000"), "unpaired");
            tc.verifyTrue(all(S.Message ~= ""));
            tc.verifyFalse(isfolder(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260910_090130")), ...
                "a day before the ones searched");
            tc.verifyFalse(isfolder(fullfile(tc.Dest, tc.Subj, tc.Subj + "_260916_150000")), "never an ambiguous one");

            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(CopySchedule.countText(out.Sessions.Status), "2 already present, 3 ambiguous, 1 unpaired.");
        end

        function scheduledCopyWaitsForAQuietSource(tc)
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            mkdir(tc.Dest);
            s = tc.schedule(QuietMin=15);
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(out.Sessions.Status, "skipped");
            tc.verifySubstring(char(out.Sessions.Message), 'still being written');
            tc.age(fullfile(tc.Root, "nas"), hours(1));
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(out.Sessions.Status, "copied", out.Sessions.Message);
        end

        function scheduledCopyLeavesSessionsToStitchToAPerson(tc)
            % A paired recording with another ePsych file that starts during
            % it: ePsych was restarted, and the files are stitched by hand.
            [i, R] = tc.addSyntheticIntan("260916_110907");
            tc.addEpsych(tc.Subj, "260916T110742");            % 85 s before: paired
            later = datetime(2026, 9, 16, 11, 9, 7) + seconds(floor(R.duration / 2));
            tc.assertGreaterThan(later, datetime(2026, 9, 16, 11, 9, 7), "the recording is long enough to start a file in");
            tc.addEpsych(tc.Subj, string(later, 'yyMMdd''T''HHmmss'));
            mkdir(tc.Dest);
            s = tc.schedule(MinDurationMin=0, MaxLagMin=0);
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(out.Sessions.Status, ["needs_stitching"; "needs_stitching"]);
            [~, name] = fileparts(i);
            tc.verifySubstring(char(out.Sessions.Message(1)), char(name + " has more than one ePsych file"));
            tc.verifyFalse(isfolder(fullfile(tc.Dest, tc.Subj)), "nothing is copied");
        end

        function scheduledCopyKeepsAHandStitchedCopy(tc)
            % Copying the paired row would put a second behavior file next
            % to the stitched one; the session is left as it was copied.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            tc.addPair("260916T110742", "260916_110907");
            tc.addSession("260916T110742", 3);
            tc.addSession("260916T114000", 2);
            T = tc.find(tc.Subj, "260916");
            R = copySessions(stitchCopySessions(T, [1 2]), DestRoot=tc.Dest, DryRun=false, LogFcn=@(~) []);
            tc.verifyEqual(R.CopyStatus, "copied", R.Message);
            out = CopySchedule.copyNew(tc.schedule(), Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(out.Sessions.Status, ["stitched_by_hand"; "unpaired"]);
            [~, n, x] = fileparts(T.EpsychFile(1));
            tc.verifyFalse(isfile(fullfile(R.DestDir, n + x)), "still one behavior file in the session folder");
        end

        function scheduledCopyReportsWhatStopsIt(tc)
            tc.addPair("260916T110742", "260916_110907");
            s = tc.schedule();                                % the destination is not there
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifyEqual(height(out.Sessions), 0);
            tc.verifySubstring(char(out.Errors), 'does not exist (is its disk connected?)');
            tc.verifyFalse(isfolder(tc.Dest), "a missing destination is not created");

            mkdir(tc.Dest);
            s.EpsychRoot = fullfile(tc.Root, "not_mounted");
            out = CopySchedule.copyNew(s, Today=datetime(2026, 9, 16), LogFcn=@(~) []);
            tc.verifySubstring(char(out.Errors), char(tc.Subj + ": Folder not found"));
        end

        function runTaskKeepsALogAndASummary(tc)
            % What the Windows task runs: the settings from a file, every line
            % appended to a log, last_run.json, and MATLAB's exit code.
            tc.assumeTrue(ispc, "robocopy needs Windows");
            stamp = string(datetime('today'), 'yyMMdd');
            tc.addPair(stamp + "T090000", stamp + "_090130");
            mkdir(tc.Dest);
            folder = fullfile(tc.Root, "schedule");
            mkdir(folder);
            file = fullfile(folder, "schedule.json");
            writeJsonFile(file, tc.schedule(LookBackDays=1));

            tc.verifyEqual(CopySchedule.runTask(file), 0);
            L = jsondecode(fileread(fullfile(folder, "last_run.json")));
            tc.verifyEqual(string(L.State), "done");
            tc.verifyEqual(string(L.Sessions.Status), "copied");
            log = fileread(fullfile(folder, "copy_schedule.log"));
            tc.verifySubstring(log, 'Scheduled copy started: ' + tc.Subj);
            tc.verifySubstring(log, 'Scheduled copy done: 1 copied.');
            tc.verifyTrue(isfolder(fullfile(tc.Dest, tc.Subj, tc.Subj + "_" + stamp + "_090130")));

            rmdir(tc.Dest, 's');                              % its disk is not connected
            tc.verifyEqual(CopySchedule.runTask(file), 1);
            L = jsondecode(fileread(fullfile(folder, "last_run.json")));
            tc.verifyEqual(string(L.State), "failed");
            tc.verifySubstring(fileread(fullfile(folder, "copy_schedule.log")), 'Scheduled copy failed: the destination');
        end

        function scheduleSettingsAreChecked(tc)
            s = CopySchedule.normalize(struct('Subjects', 'A-1, B-2;C-3  A-1', 'EveryMin', "30"));
            tc.verifyEqual(s.Subjects, ["A-1", "B-2", "C-3"]);
            tc.verifyEqual(s.EveryMin, 30);
            tc.verifyEqual([s.RunWhen, s.Verify, s.IfExists], ["signed_in", "size", "resume"]);
            tc.verifyEqual(string(fieldnames(s)), string(fieldnames(CopySchedule.defaults())));
            bad = {struct('Subjects', ""), struct('Subjects', "A", 'EveryMin', 2), ...
                struct('Subjects', "A", 'LookBackDays', 1.5), struct('Subjects', "A/B"), ...
                struct('Subjects', "A", 'RunWhen', "sometimes"), struct('Subjects', "A", 'DestRoot', "")};
            for k = 1:numel(bad)
                tc.verifyError(@() CopySchedule.normalize(bad{k}), 'CopySchedule:BadSettings');
            end
        end

        function taskDefinitionRunsMatlabInTheBackground(tc)
            file = fullfile(tc.Root, "sched", "schedule.json");
            xml = string(CopySchedule.taskXml(tc.schedule(EveryMin=30), "\ephys_analysis_test\t", file));
            for part = ["<Interval>PT30M</Interval>", "<MultipleInstancesPolicy>IgnoreNew<", ...
                    "<DisallowStartIfOnBatteries>false<", "<StopIfGoingOnBatteries>false<", ...
                    "<StartWhenAvailable>true<", "<LogonType>InteractiveToken<", ...
                    "<Command>" + fullfile(matlabroot, "bin", "win64", "MATLAB.exe") + "<", ...
                    "-sd """ + fileparts(file) + """ -batch", "exit(CopySchedule.runTask('" + file + "'))"]
                tc.verifySubstring(xml, part);
            end
            start = datetime(regexp(xml, '<StartBoundary>([^<]+)<', 'tokens', 'once'), ...
                'InputFormat', "yyyy-MM-dd'T'HH:mm:ss");
            tc.verifyTrue(start > datetime('now') && start <= datetime('now') + minutes(30));
            tc.verifyEqual(mod(minutes(timeofday(start)), 30), 0, "runs are on the clock");

            xml = string(CopySchedule.taskXml(tc.schedule(RunWhen="always"), "\ephys_analysis_test\t", file));
            tc.verifySubstring(xml, "<LogonType>Password</LogonType>");
            f = fullfile(tc.Root, "task.xml");                 % well formed
            fid = fopen(f, 'w');
            fwrite(fid, replace(xml, "UTF-16", "UTF-8"), 'char');
            fclose(fid);
            doc = xmlread(f);
            tc.verifyEqual(doc.getElementsByTagName('Exec').getLength(), 1);
        end

        function uncPathOnlyForNetworkDrives(tc)
            tc.verifyEqual(CopySchedule.uncPath(tc.Root), tc.Root);
            tc.verifyEqual(CopySchedule.uncPath("\\server\share\x"), "\\server\share\x");
            tc.assumeTrue(ispc, "drive letters are Windows");
            net = actxserver('WScript.Network');
            drives = net.EnumNetworkDrives;
            letter = "";
            for k = 0:2:drives.Count - 1
                if drives.Item(k) ~= ""
                    letter = string(drives.Item(k));
                    remote = string(drives.Item(k + 1));
                    break
                end
            end
            tc.assumeNotEqual(letter, "", "no network drive is mapped here");
            tc.verifyEqual(CopySchedule.uncPath(letter + "/a/b"), strip(remote, "right", "\") + "\a\b");
        end

        function scheduleRunsAsAWindowsTask(tc)
            % End to end: save creates the task, Run now has Windows start
            % MATLAB in the background, the run copies today's session and
            % reports, and remove takes the task away again.
            tc.assumeTrue(ispc, "Task Scheduler needs Windows");
            stamp = string(datetime('today'), 'yyMMdd');
            tc.addPair(stamp + "T090000", stamp + "_090130");
            mkdir(tc.Dest);
            sch = tc.testSchedule("task");
            s = sch.save(tc.schedule(LookBackDays=1, EveryMin=720));
            st = sch.status();
            tc.verifyTrue(st.Scheduled && st.Enabled && ~st.Running);
            tc.verifyEqual([st.RunWhen, st.Problem], ["signed_in", ""]);
            tc.verifyEqual(st.EveryMin, 720);
            tc.verifyTrue(st.NextRun > datetime('now') && st.NextRun <= datetime('now') + hours(12));
            tc.verifyEqual(s.Code, string(fileparts(which('CopySchedule'))));
            tc.verifyTrue(isfile(fullfile(sch.Folder, "startup.m")));
            tc.verifyEqual(sch.read(), s);

            sch.startNow();
            t0 = tic;
            while toc(t0) < 300
                pause(2);
                st = sch.status();
                if ~st.Running && ~isempty(st.LastRun) && st.LastRun.State ~= "running"; break; end
            end
            tc.assertFalse(st.Running, "the scheduled run did not finish in 5 min");
            tc.verifyEqual(st.LastResult, 0, "MATLAB's exit code reaches Task Scheduler");
            tc.assertNotEmpty(st.LastRun, "the run wrote no last_run.json; see " + fullfile(sch.Folder, "matlab.log"));
            tc.verifyEqual(st.LastRun.State, "done");
            tc.verifyEqual(st.LastRun.Sessions.Status, "copied");
            tc.verifyTrue(isfile(fullfile(tc.Dest, tc.Subj, tc.Subj + "_" + stamp + "_090130", "session_manifest.json")));

            sch.remove();
            st = sch.status();
            tc.verifyFalse(st.Scheduled);
            tc.verifyEmpty(st.Settings);
            tc.verifyNotEmpty(st.LastRun, "the last run's summary is kept");
        end

        function appSchedulesACopy(tc)
            % The Copy tab's Scheduled copy panel: Save with the tab's roots
            % and the Subject ID, the status line, Remove.
            tc.assumeTrue(ispc, "Task Scheduler needs Windows");
            g = EphysPreprocessingApp.PrefGroup;
            saved = [];
            if ispref(g); saved = getpref(g); end
            tc.addTeardown(@() restorePrefs(g, saved));
            if ispref(g, 'LastConfigFile'); setpref(g, 'LastConfigFile', ''); end

            app = EphysPreprocessingApp;
            tc.addTeardown(@() delete(app.Fig));
            sch = tc.testSchedule("app");
            app.CopyScheduler = sch;
            app.refreshCopySchedule(Fill=true);
            tc.verifySubstring(app.CopyScheduleStatusLabel.Text, 'Not scheduled.');
            tc.verifyEqual(string(app.CopyScheduleRunNowButton.Enable), "off");

            app.selectTab(app.TabCopy);
            app.CopySubjectField.Value = char(tc.Subj);
            app.CopyEpsychRootField.Value = char(tc.Epsych);
            app.CopyRecordingRootsField.Value = char(tc.Intan);
            app.CopyDestRootField.Value = char(tc.Dest);
            app.CopyScheduleSubjectsField.Value = '';          % blank: the Subject ID above
            app.CopyScheduleEveryField.Value = 30;
            app.CopyScheduleDaysField.Value = 2;
            app.onCopyScheduleSave();
            s = sch.read();
            tc.assertNotEmpty(s, "the schedule was not saved");
            tc.verifyEqual([s.Subjects, s.DestRoot, s.EpsychRoot], [tc.Subj, tc.Dest, tc.Epsych]);
            tc.verifyEqual([s.EveryMin, s.LookBackDays, s.QuietMin], [30, 2, 15]);
            tc.verifyEqual(string(app.CopyScheduleSubjectsField.Value), tc.Subj, "the panel shows what is saved");
            txt = string(app.CopyScheduleStatusLabel.Text);
            tc.verifySubstring(txt, "Every 30 min, while you are signed in: " + tc.Subj + " to " + tc.Dest);
            tc.verifySubstring(txt, "Next run");
            tc.verifySubstring(txt, "Not run yet.");
            tc.verifyEqual(string(app.CopyScheduleRunNowButton.Enable), "on");
            tc.verifySubstring(string(app.CopyLogArea.Value{end}), "Scheduled copy saved");

            app.onCopyScheduleRemove();
            st = sch.status();
            tc.verifyFalse(st.Scheduled);
            tc.verifySubstring(app.CopyScheduleStatusLabel.Text, 'Not scheduled.');
        end
    end

    methods
        function s = schedule(tc, varargin)
            %schedule  Scheduled-copy settings for this tree; name-value pairs override.
            %   QuietMin is 0: the tree has just been written.
            s = CopySchedule.defaults();
            s.Subjects = tc.Subj;
            s.EpsychRoot = tc.Epsych;
            s.RecordingRoots = tc.Intan;
            s.DestRoot = tc.Dest;
            s.QuietMin = 0;
            for k = 1:2:numel(varargin)
                s.(varargin{k}) = varargin{k + 1};
            end
        end

        function sch = testSchedule(tc, label)
            %testSchedule  A schedule of its own for a test, removed when the test ends.
            sch = CopySchedule(Folder=fullfile(tc.Root, "schedule_" + label), ...
                TaskName="\ephys_analysis_test\Copy sessions " + label + " " + feature('getpid'));
            tc.addTeardown(@() sch.remove());
        end

        function d = jobsFolder(~)
            %jobsFolder  Where copySessions keeps the job folders of batches in flight.
            base = string(getenv('LOCALAPPDATA'));
            if base == ""; base = string(tempdir); end
            d = fullfile(base, "ephys_analysis", "copy_jobs");
        end

        function folder = fakeBatch(tc, dest)
            %fakeBatch  The job folder of a batch writing DEST, as another MATLAB keeps it.
            [~, name] = fileparts(tempname);
            folder = fullfile(tc.jobsFolder(), "test_" + name);
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, 's'));
            spec = struct('version', 1, 'started', "2026-09-18 10:00", 'pid', 1, ...
                'sessions', {{struct('index', 1, 'dest', dest)}});
            writeJsonFile(fullfile(folder, "copy_job.json"), spec);
            tc.writeBytes(fullfile(folder, "copy_heartbeat"), uint8('1'));
        end

        function age(tc, root, dt)
            %age  Set the modification time of ROOT and everything in it DT back.
            ms = posixtime(datetime('now', 'TimeZone', 'local') - dt) * 1000;
            D = dir(fullfile(root, '**', '*'));
            D = D(~strcmp({D.name}, '..'));
            for k = 1:numel(D)
                p = fullfile(D(k).folder, D(k).name);
                if strcmp(D(k).name, '.'); p = D(k).folder; end   % the folder itself
                tc.assertTrue(java.io.File(p).setLastModified(ms), "cannot set the time of " + p);
            end
        end

        function waitForCopy(tc, app, timeout)
            %waitForCopy  Pump the event queue until the app's copy timer is done.
            if nargin < 3; timeout = 120; end
            t0 = tic;
            while ~isempty(app.CopyJob) && toc(t0) < timeout
                pause(0.05);
                drawnow;
            end
            tc.assertEmpty(app.CopyJob, "the background copy did not finish in time");
        end

        function [T, S] = find(tc, subj, spec, varargin)
            [T, S] = findCopySessions(subj, spec, 'EpsychRoot', tc.Epsych, 'RecordingRoots', tc.Intan, ...
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

        function [d, R] = addSyntheticOpenEphys(tc, name)
            %addSyntheticOpenEphys  An Open Ephys GUI session (Binary format) <Subj>_<name> under tc.OpenEphys.
            d = string(fullfile(tc.OpenEphys, tc.Subj, tc.Subj + "_" + name));
            R = makeSyntheticRecording(d, Subject=tc.Subj, Format="openephys-binary", ...
                NumChannels=2, NumTrials=4, Fs=2000, SortedOutput=false, Artifacts=false, WriteManifest=false);
            delete(R.behaviorFile);
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


function appendProgress(map, frac, info)
%appendProgress  Keep every ProgressFcn call, in order (a Map: the handle is shared).
map(map.Count + 1) = struct('frac', frac, 'info', info);
end


function appendLog(map, msg)
map(map.Count + 1) = string(msg); %#ok<NASGU> containers.Map is a handle
end
