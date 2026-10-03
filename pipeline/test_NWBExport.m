classdef test_NWBExport < matlab.unittest.TestCase
    %test_NWBExport  EphysDataset.exportNWB: what is staged, the file pynwb writes, the errors.
    %   A six-channel recording on a laminar probe with an extract (LFP at
    %   1 kHz, MUA at 2 kHz, AUX, a bad channel, an artifact period, two
    %   digital lines), two sorted units and four trials, one unpaired.
    %   StageOnly checks every staged number against the inputs (no Python
    %   needed): the signals as stored, the electrodes on the probe, the
    %   units, the trial and pulse times moved to the continuous clock, the
    %   periods erased, the session start in its time zone. With a Python
    %   that has pynwb and nwbinspector (NWB_PYTHON, else MATLAB's pyenv)
    %   the file is written and read back with h5read, and DatasetOutputs
    %   finds it; without one that test is skipped.
    %
    %   Usage:  runtests("test_NWBExport")

    properties (SetAccess = private)
        Root = ""
        Data = struct()
    end

    methods (TestMethodSetup)
        function makeData(tc)
            tmp = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            tc.Root = string(tmp.Folder);
            tc.Data = fixture(tc.Root);
        end
    end

    methods (Test)
        function staged(tc)
            D = tc.Data;
            out = D.ds.exportNWB(Extract=D.S, Units=D.U, Behavior=D.B, ProbeFile=D.probe, StageOnly=true, ...
                Metadata=D.meta);
            tc.verifyEqual(out.file, "");
            tc.verifyTrue(isfolder(out.stage), 'StageOnly keeps the staging folder');
            st = readJsonFile(fullfile(out.stage, "stage.json"));
            A = readNPZ(fullfile(out.stage, "stage.npz"));
            tc.verifyEqual(string(st.format), "ephys_analysis-nwb-stage/1");
            % signals as stored, (channels, samples)
            tc.verifyEqual(readNPY(fullfile(out.stage, "LFP.npy")), D.S.Y.LFP.', 'the LFP as the extract holds it');
            tc.verifyEqual(readNPY(fullfile(out.stage, "MUA.npy")), D.S.Y.MUA.');
            tc.verifyEqual(readNPY(fullfile(out.stage, "AUX.npy")), D.S.Y.AUX.');
            tc.verifyEqual([A.LFP_rate A.MUA_rate A.AUX_rate], [1000 2000 500]);
            tc.verifyEqual([A.LFP_conversion A.MUA_conversion A.AUX_conversion], [1e-6 1e-6 1]);
            tc.verifyEqual(A.LFP_electrodes, int64(0:5).');
            % electrodes on the probe
            tc.verifyEqual(A.electrodes_recording_channel, int64(1:6).');
            tc.verifyEqual(A.electrodes_rel_y, (0:5).' * 50);
            tc.verifyEqual(A.electrodes_interpolated, [false; false; true; false; false; false]);
            tc.verifyEqual(string(st.electrodes.group), repmat("shank0", 6, 1));
            tc.verifyEqual(string(st.electrodes.location), repmat("CA1", 6, 1));
            % units
            tc.verifyEqual(A.units_spike_times, vertcat(D.U.times{:}));
            tc.verifyEqual(A.units_spike_index, int64([3; 5]));
            tc.verifyEqual(A.units_id, int64([3; 8]));
            tc.verifyEqual(A.units_electrode, int64([1; 4]), 'the peak channels'' rows, 0-based');
            tc.verifyEqual(A.units_resolution, 1 / 30000);
            tc.verifyEqual(A.units_isi_violations_ratio, [0.1; NaN]);
            % trials and pulses on the continuous clock
            on = D.B.trials.TrialOnset;
            keep = isfinite(on);
            tc.verifyEqual(A.trials_start_time, (round(on(keep) * 30000) - 1) / 30000);
            tc.verifyEqual(out.nTrials, 3);
            tc.verifyEqual(out.nTrialsLeftOut, 1);
            tc.verifyTrue(ismember("TrialEvents", out.trialColumnsLeftOut), 'a struct column is left out and listed');
            cols = st.trials.columns;
            if ~iscell(cols); cols = num2cell(cols); end
            names = string(cellfun(@(c) c.name, cols, 'UniformOutput', false));
            flag = cols{names == "PairingFlag"};
            tc.verifyEqual(string(flag.values), ["ok"; "ok"; "partial"]);
            tc.verifyEqual(A.event_1, (round(D.S.events.din0 * 30000) - 1) / 30000);
            tc.verifyFalse(isfield(A, 'event_2'), 'a line without a pulse makes no table');
            tc.verifyEqual(A.invalid_times, D.S.info.artifacts.intervals);
            % session and subject
            tc.verifyEqual(string(st.session.start_time), "2026-09-08T10:39:49.000-04:00");
            tc.verifyEqual(string(st.session.session_id), D.ds.Name);
            tc.verifyEqual(string(st.subject.subject_id), "S1");
            tc.verifyEqual(string(st.subject.species), "Mus musculus");
            notes = jsondecode(char(st.session.notes));
            tc.verifyEqual(string(notes.tool), "EphysDataset.exportNWB");
        end

        function writesAndReadsBack(tc)
            py = nwbPython();
            tc.assumeTrue(py ~= "", "no Python with pynwb and nwbinspector (set NWB_PYTHON)");
            D = tc.Data;
            out = D.ds.exportNWB(Extract=D.S, Units=D.U, Behavior=D.B, ProbeFile=D.probe, Metadata=D.meta, PythonExe=py);
            f = char(out.file);
            tc.verifyTrue(isfile(f));
            tc.verifyEmpty(dir(fullfile(D.ds.outputFolder(), '~*')), 'no staging folder or partial file is left');
            tc.verifyEqual(h5read(f, '/processing/ecephys/LFP/LFP/data').', D.S.Y.LFP, 'the LFP, sample for sample');
            tc.verifyEqual(h5readatt(f, '/processing/ecephys/LFP/LFP/data', 'conversion'), 1e-6);
            tc.verifyEqual(h5read(f, '/processing/ecephys/MUA/MUA/data').', D.S.Y.MUA);
            tc.verifyEqual(h5read(f, '/units/spike_times'), vertcat(D.U.times{:}));
            tc.verifyEqual(double(h5read(f, '/units/id')), [3; 8]);
            tc.verifyEqual(h5read(f, '/intervals/trials/start_time'), (round([3001; 9001; 21001] / 30000 * 30000) - 1) / 30000);
            tc.verifyEqual(h5read(f, '/general/extracellular_ephys/electrodes/rel_y'), (0:5).' * 50);
            tc.verifyEqual(h5read(f, '/intervals/invalid_times/start_time'), D.S.info.artifacts.intervals(:, 1));
            t = string(h5read(f, '/session_start_time'));
            tc.verifyTrue(startsWith(t, "2026-09-08T10:39:49") && endsWith(t, "-04:00"), "session start " + t);
            I = out.inspector;
            tc.verifyFalse(any(ismember(I.importance, ["ERROR" "PYNWB_VALIDATION"])), ...
                strjoin(I.check + ": " + I.message, newline));
            tc.verifyTrue(isfile(out.inspectorFile));
            o = D.ds.outputs();
            tc.verifyTrue(o.has("nwb"), 'DatasetOutputs finds <Name>.nwb');
            tc.verifyEqual(string(o.NWB.notes.dataset), D.ds.Name);
        end

        function errors(tc)
            D = tc.Data;
            tc.verifyError(@() D.ds.exportNWB(Extract=D.S, Units=false, ProbeFile=D.probe, Metadata=D.meta), ...
                'EphysDataset:exportNWB:NoPython');
            noStart = rmfield(D.meta, 'SessionStartTime');
            tc.verifyError(@() D.ds.exportNWB(Extract=D.S, Units=false, StageOnly=true, Metadata=noStart), ...
                'EphysDataset:exportNWB:NoStartTime');
            badZone = D.meta;
            badZone.TimeZone = "Mars/Olympus";
            tc.verifyError(@() D.ds.exportNWB(Extract=D.S, Units=false, StageOnly=true, Metadata=badZone), ...
                'EphysDataset:exportNWB:BadTimeZone');
            tc.verifyError(@() D.ds.exportNWB(Extract=D.S, Units=false, StageOnly=true, Metadata=D.meta, Behavior="nope.mat"), ...
                'EphysDataset:exportNWB:NoBehavior');
            if ~isfolder(D.ds.outputFolder()); mkdir(D.ds.outputFolder()); end
            f = fullfile(D.ds.outputFolder(), D.ds.Name + ".nwb");
            fid = fopen(f, 'w'); fclose(fid);
            tc.verifyError(@() D.ds.exportNWB(Extract=D.S, Units=false, StageOnly=true, Metadata=D.meta), ...
                'EphysDataset:exportNWB:Exists');
        end
    end
end


function D = fixture(root)
%fixture  A recording on a laminar probe, its extract, two units and four trials.
origFs = 30000;
nCh = 6;
rec = fullfile(root, "rec_A");
mkdir(rec);
fid = fopen(fullfile(rec, 'rec.bin'), 'w'); fwrite(fid, zeros(nCh, 100, 'int16'), 'int16'); fclose(fid);
BinaryReader.writeDescriptor(rec, struct('data_file', "rec.bin", 'dtype', "int16", 'n_chan', nCh, ...
    'fs', origFs, 'gain_to_uV', 0.195));
ds = EphysDataset(rec);
ds.OutputDir = fullfile(root, "out_A");
probe = fullfile(root, "laminar.json");
writeProbeMap(probe, struct('chanMap', 0:5, 'xc', zeros(1, 6), 'yc', (0:5) * 50, 'kcoords', zeros(1, 6), 'n_chan', 6));

X = (1:1000).' + 1000 * (1:nCh);
S = struct();
S.Y = struct('LFP', single(X), 'MUA', single(repmat((1:2000).', 1, nCh) * 0.5), ...
    'AUX', single(reshape(1:1500, 500, 3) / 1000));
S.info = struct('LFP', struct('Fs', 1000, 'reference', "none"), 'MUA', struct('Fs', 2000, 'reference', "none"), ...
    'AUX', struct('Fs', 500), 'labels', "c" + (1:nCh), 'origFs', origFs, ...
    'importOptions', struct('LFP_Fs', 1000, 'LFP_bpLoHi', [0 300], 'MUA_Fs', 2000, 'MUA_bpLoHi', [300 5000]), ...
    'badChannels', struct('columns', 3, 'channels', 3), ...
    'artifacts', struct('intervals', [0.2005 0.2105], 'fill', "line", 'nSamples', 300));
S.events = struct('din0', [3001 3100; 9001 9030] / origFs, 'Stim', zeros(0, 2));

U = struct();
U.unitId = [3; 8];
U.class = ["su"; "mua"];
U.group = ["good"; "mua"];
U.label = ["su003_S1_260908T1039"; "mua008_S1_260908T1039"];
U.channel = [2; 5];
U.channelName = ["c2"; "c5"];
U.shank = [0; 0];
U.x = [0; 0];
U.y = [50; 200];
U.amplitude = [12.5; 30];
U.contamPct = [1; 20];
U.times = {[0.01; 0.25; 0.5]; [0.1; 0.9]};
U.fs = origFs;
U.resultsDir = string(fullfile(root, "sort"));
U.groupSource = "phy";
U.isiViolationsRatio = [0.1; NaN];
U.presenceRatio = [0.95; 0.5];

T = table((1:4).', [3001; 9001; NaN; 21001] / origFs, [6001; 12001; NaN; 24001] / origFs, [10; 20; 30; 40], ...
    ["ok"; "ok"; "unpaired"; "partial"], 'VariableNames', {'TrialNumber', 'TrialOnset', 'TrialOffset', 'Depth', 'PairingFlag'});
T.TrialEvents = repmat(struct('Stim', zeros(0, 2)), 4, 1);
B = struct('trials', T, 'pairing', struct('Fs', origFs, 'status', "approved"), 'subject', "S1");

meta = struct('SessionStartTime', "2026-09-08 10:39:49", 'TimeZone', "America/New_York", 'Location', "CA1", ...
    'Species', "Mus musculus", 'Sex', "F", 'Age', "P90D", 'SubjectId', "S1", 'Experimenter', "Doe, Jane");
D = struct('ds', ds, 'probe', string(probe), 'S', S, 'U', U, 'B', B, 'meta', meta);
end


function py = nwbPython()
%nwbPython  A Python with pynwb and nwbinspector: NWB_PYTHON, else pyenv's ("" for none).
py = "";
cands = string(getenv('NWB_PYTHON'));
try
    pe = pyenv;
    cands(end+1) = string(pe.Executable);
catch
end
for c = cands(cands ~= "")
    if ~isfile(c); continue; end
    [st, ~] = system(sprintf('"%s" -c "import pynwb, nwbinspector"', c));
    if st == 0; py = c; return; end
end
end
