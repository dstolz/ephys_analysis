classdef test_DataPathWarnings < matlab.unittest.TestCase
    %test_DataPathWarnings  Fallbacks that change a result say so.
    %   Where the pipeline falls back silently and the fallback changes an
    %   output or a step, it now warns, with an identifier:
    %     BinaryReader:BadAcqDate             an acq_date that does not parse
    %     EphysDataset:channelLayout:BadProbe a probe file that cannot be read
    %     EphysDataset:runKilosort:BinMetaUnknown
    %                                         a given .bin without a readable sidecar
    %     DatasetOutputs:Unreadable           a dataset's output that cannot be read
    %     EphysPipeline:probeFor:BadPattern   a name pattern that does not parse
    %     epsychSessionMeta:BadStartTime      a session start that does not convert
    %   Each test also checks the fallback itself is unchanged.
    %
    %   Usage:  runtests("test_DataPathWarnings")

    properties (SetAccess = private)
        Root (1,1) string = ""
    end

    methods (TestMethodSetup)
        function makeRoot(tc)
            tc.Root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
        end
    end

    methods (Test)
        function binaryAcqDateThatDoesNotParse(tc)
            folder = fullfile(tc.Root, "badacq");
            mkdir(folder);
            writeDat(fullfile(folder, 'rec.bin'), int16(zeros(2, 100)), 'int16');
            BinaryReader.writeDescriptor(folder, struct('data_file', "rec.bin", 'dtype', "int16", ...
                'n_chan', 2, 'fs', 1000, 'gain_to_uV', 0.195, 'acq_date', "18/09/2026 10:00"));
            r = BinaryReader(folder);
            tc.verifyWarning(@() r.discoverFiles(), 'BinaryReader:BadAcqDate');
            d = dir(fullfile(folder, 'rec.bin'));
            tc.verifyEqual(r.AcqDate, datetime(d.datenum, 'ConvertFrom', 'datenum'), ...
                "the data file's modified time is used, as before");
        end

        function probeFileThatCannotBeRead(tc)
            ds = binaryDataset(tc.Root, "probe_rec", 4);
            bad = fullfile(tc.Root, "broken_probe.json");
            writelines("{ this is not JSON", bad);
            L = tc.verifyWarning(@() ds.channelLayout(ProbeFile=bad), 'EphysDataset:channelLayout:BadProbe');
            tc.verifyFalse(L.hasProbe, "the channels are off the probe, as before");
            tc.verifyEqual(L.order, 1:4);
            tc.verifyWarningFree(@() ds.channelLayout(ProbeFile=fullfile(tc.Root, "absent.json")), ...
                "a probe file that is not there stays silent here (it is reported as missing elsewhere)");
        end

        function givenBinWithoutSidecar(tc)
            fs = 30000; spb = 128;
            rec = fullfile(tc.Root, "rec"); mkdir(rec);
            writeSyntheticRHD(fullfile(rec, 'rec.rhd'), uint16(32768 + randi([-200 200], 4, 4 * spb)), ...
                zeros(1, 4 * spb), fs, spb);
            probe = fullfile(tc.Root, "probe.json");
            writeProbeMap(probe, struct('chanMap', 0:3, 'xc', zeros(1, 4), 'yc', (0:3) * 20, ...
                'kcoords', zeros(1, 4), 'n_chan', 4));
            ds = EphysDataset(rec);
            ds.OutputDir = fullfile(tc.Root, "out");
            ds.ProbeFile = probe;
            ds.PythonExe = "C:\no\python.exe";
            binX = fullfile(tc.Root, "other.bin");
            ds.toBin(BinFile=binX);
            delete(fullfile(tc.Root, "other.json"));
            dry = tc.verifyWarning(@() ds.runKilosort(DryRun=true, BinFile=binX), ...
                'EphysDataset:runKilosort:BinMetaUnknown');
            tc.verifyFalse(isfield(readJsonFile(dry.settingsPath), 'bin_scale'), "no bin_scale, as before");
        end

        function unreadableOutputFile(tc)
            ds = binaryDataset(tc.Root, "outs_rec", 2);
            bad = fullfile(ds.outputFolder(), ds.Name + "_spikes.mat");
            writelines("not a MAT file", bad);
            out = tc.verifyWarning(@() DatasetOutputs(ds), 'DatasetOutputs:Unreadable');
            tc.verifyFalse(out.has("spikes"), "the unreadable file is left out, as before");
        end

        function namePatternThatDoesNotParse(tc)
            d = struct('Name', "A1_260101_120000", 'NamePattern', "{SubjectID}_{SubjectID}");
            [probe, rule] = tc.verifyWarning(@() EphysPipeline.probeRule(d, ["A1" "*"], ["a.json" "any.json"]), ...
                'EphysPipeline:probeFor:BadPattern');
            tc.verifyEqual([probe rule], ["any.json" "2"], 'only the "*" rule matches, as before');
        end

        function sessionStartThatDoesNotConvert(tc)
            f = fullfile(tc.Root, "SUBJ_260101T120000.mat");
            Data = struct('TrialID', {1, 2}); %#ok<NASGU> saved by name
            Info = struct('Subject', "SUBJ", 'StartTime', 'not a time'); %#ok<NASGU>
            save(f, 'Data', 'Info');
            m = tc.verifyWarning(@() epsychSessionMeta(f), 'epsychSessionMeta:BadStartTime');
            tc.verifyTrue(isnat(m.startTime) && m.subject == "SUBJ" && m.nTrials == 2, ...
                "the start is unknown and the rest is read, as before");
        end
    end
end


function ds = binaryDataset(root, name, nChan)
%binaryDataset  A small universal-format recording, as an EphysDataset.
folder = fullfile(root, name);
mkdir(folder);
writeDat(fullfile(folder, 'rec.bin'), int16(zeros(nChan, 300)), 'int16');
BinaryReader.writeDescriptor(folder, struct('data_file', "rec.bin", 'dtype', "int16", ...
    'n_chan', nChan, 'fs', 1000, 'gain_to_uV', 0.195));
ds = EphysDataset(folder);
end
