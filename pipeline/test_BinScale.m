classdef test_BinScale < matlab.unittest.TestCase
    %test_BinScale  The Kilosort4 .bin keeps the recording's own resolution.
    %   EphysDataset.binScale: ds.Scale when set; else 1 / the recording's
    %   microvolts per stored unit when one stored unit maps onto one unit of
    %   an int16 .bin (int16, Intan's uint16 less 32768, int8), so toBin
    %   writes the recording's own integers, unclipped; else 1/0.195 with the
    %   reason. toBin records where the scale came from (info.scaleSource,
    %   the sidecar's scale_source); a project leaves each dataset its own.
    %
    %   Usage:  runtests("test_BinScale")

    properties (Constant)
        Fs = 20000
        NChan = 3
        NSamples = 4000
    end

    properties (SetAccess = private)
        Root (1,1) string = ""
        Raw     % int16 [NChan x NSamples], reaching both ends of int16
    end

    methods (TestClassSetup)
        function makeRaw(tc)
            tc.Root = string(tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder);
            rng(11);
            r = int16(randi([-2000 2000], tc.NChan, tc.NSamples));
            r(1, 10) = intmax('int16'); r(2, 20) = intmin('int16');
            tc.Raw = r;
        end
    end

    methods (Test)
        function intanTraditionalIsNative(tc)
            folder = fullfile(tc.Root, "intan"); mkdir(folder);
            writeSyntheticRHD(fullfile(folder, 'rec.rhd'), uint16(32768 + randi([-300 300], 2, 256)), zeros(1, 256), 30000, 128);
            [s, src] = EphysDataset(folder).binScale();
            tc.verifyEqual(s, 1 / 0.195, "Intan: 1/0.195, its own resolution");
            tc.verifyTrue(startsWith(src, "native"), src);
        end

        function int16AtAnotherGainIsLossless(tc)
            ds = binaryDataset(tc, "int16_gain", tc.Raw, "int16", 2.5, 0);
            [s, src] = ds.binScale();
            tc.verifyEqual(s, 1 / 2.5, "1 / gain_to_uV");
            tc.verifyTrue(startsWith(src, "native"), src);
            info = ds.toBin();
            tc.verifyTrue(startsWith(info.scaleSource, "native"), "toBin says where the scale came from");
            tc.verifyEqual(info.nClipped, 0, "nothing clipped, both ends of int16 included");
            tc.verifyEqual(readBinFile(info.filename, tc.NChan), double(tc.Raw), ...
                "the .bin holds the recording's own integers");
            side = readJsonFile(info.metaFile);
            tc.verifyTrue(startsWith(string(side.scale_source), "native") && side.scale == 1 / 2.5, ...
                "the sidecar records the scale and where it came from");
        end

        function uint16NeedsIntansOffset(tc)
            ds = binaryDataset(tc, "u16_offset", uint16(double(tc.Raw) + 32768), "uint16", 0.195, 32768);
            [s, src] = ds.binScale();
            tc.verifyEqual(s, 1 / 0.195);
            tc.verifyTrue(startsWith(src, "native"), src);
            info = ds.toBin();
            tc.verifyEqual(readBinFile(info.filename, tc.NChan), double(tc.Raw), "uint16 less 32768, one-to-one");
            ds0 = binaryDataset(tc, "u16_nooffset", uint16(abs(double(tc.Raw))), "uint16", 0.5, 0);
            [s0, src0] = ds0.binScale();
            tc.verifyEqual(s0, EphysDataset.DefaultScale, "uint16 from 0 does not fit int16 one-to-one");
            tc.verifyTrue(startsWith(src0, "default") && contains(src0, "uint16"), src0);
        end

        function floatingPointUsesTheDefault(tc)
            ds = binaryDataset(tc, "float", single(double(tc.Raw) / 7), "float32", 1, 0);
            [s, src] = ds.binScale();
            tc.verifyEqual(s, EphysDataset.DefaultScale);
            tc.verifyTrue(startsWith(src, "default") && contains(src, "floating-point"), src);
            [~, srcF] = binaryDataset(tc, "int16_for_float", tc.Raw, "int16", 2.5, 0).binScale("float32");
            tc.verifyTrue(startsWith(srcF, "default") && contains(srcF, "float32"), "a float .bin keeps the default: " + srcF);
        end

        function aScaleThatIsSetWins(tc)
            ds = binaryDataset(tc, "set", tc.Raw, "int16", 2.5, 0);
            ds.Scale = 3;
            [s, src] = ds.binScale();
            tc.verifyEqual([s src], [3 "set: ds.Scale"]);
            info = ds.toBin(Scale=7);
            tc.verifyEqual([info.scale info.scaleSource], [7 "set: Scale="], "toBin's Scale= wins over everything");
        end

        function projectLeavesEachDatasetItsOwn(tc)
            proj = fullfile(tc.Root, "proj");
            binaryDataset(tc, fullfile("proj", "a"), tc.Raw, "int16", 2.5, 0);
            binaryDataset(tc, fullfile("proj", "b"), tc.Raw, "int16", 0.5, 0);
            P = EphysProject(proj);
            P.refresh();
            tc.verifyTrue(isnan(P.Scale) && all(isnan([P.Datasets.Scale])), "Scale stays NaN: from each recording");
            s = arrayfun(@(d) d.binScale(), P.Datasets);
            tc.verifyEqual(sort(s), sort([1 / 2.5, 1 / 0.5]), "each dataset its own resolution");
        end
    end
end


function ds = binaryDataset(tc, name, A, dtype, gain, offset)
%binaryDataset  A recording.json recording of A [nChan x nSamples] stored as DTYPE.
folder = fullfile(tc.Root, name);
mkdir(folder);
writeDat(fullfile(folder, 'rec.bin'), A, char(BinaryReader.precisionFor(dtype)));
BinaryReader.writeDescriptor(folder, struct('data_file', "rec.bin", 'dtype', dtype, ...
    'n_chan', size(A, 1), 'fs', tc.Fs, 'gain_to_uV', gain, 'offset', offset));
ds = EphysDataset(folder);
ds.OutputDir = fullfile(folder, "out");
end


function B = readBinFile(file, nChan)
%readBinFile  An int16 .bin as [nChan x nSamples] double.
fid = fopen(file, 'r', 'ieee-le');
closer = onCleanup(@() fclose(fid));
B = fread(fid, [nChan, Inf], 'int16=>double');
end
