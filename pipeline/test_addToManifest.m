classdef test_addToManifest < matlab.unittest.TestCase
    %test_addToManifest  addToManifest: what it adds, what it keeps, what it refuses.
    %   A dataset in an empty temporary folder (no recording needed): the
    %   three kinds of target, adding and replacing fields, the custom block
    %   surviving writeManifest, the manifest viewer's row, and each refusal
    %   leaving the file as it was.
    %
    %   Usage:  runtests("test_addToManifest")

    properties
        Dir
        Ds
    end

    methods (TestMethodSetup)
        function makeDataset(tc)
            tc.Dir = string(tempname);
            mkdir(tc.Dir);
            tc.addTeardown(@() rmdir(tc.Dir, 's'));
            tc.Ds = EphysDataset(tc.Dir, AutoMetadata=false, Name="subjA_260101_120000");
        end
    end

    methods (Test)
        function addsToAFolderFileOrDataset(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, a=1);
            addToManifest(tc.Ds.manifestFile(), b="two");
            c = addToManifest(tc.Ds, d=true);
            tc.verifyEqual(c.a, 1);
            tc.verifyEqual(string(c.b), "two");
            tc.verifyTrue(c.d);
            tc.verifyEqual(tc.custom(), struct('a', 1, 'b', 'two', 'd', true));
        end

        function datasetWithoutAManifestGetsOne(tc)
            tc.assertFalse(isfile(tc.Ds.manifestFile()));
            addToManifest(tc.Ds, surgeon="DS");
            m = readJsonFile(tc.Ds.manifestFile());
            tc.verifyEqual(m.name, 'subjA_260101_120000');
            tc.verifyEqual(m.custom.surgeon, 'DS');
        end

        function takesAStruct(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, struct('a', 1, 'nested', struct('b', "x")));
            tc.verifyEqual(tc.custom(), struct('a', 1, 'nested', struct('b', 'x')));
        end

        function takesAStructAndPairs(tc)
            tc.Ds.writeManifest();
            c = addToManifest(tc.Dir, struct('a', 1, 'b', 2), b=3, d="x");
            tc.verifyEqual(c.b, 3, 'A pair wins over the struct''s field.');
            tc.verifyEqual(tc.custom(), struct('a', 1, 'b', 3, 'd', 'x'));
            addToManifest(tc.Dir, struct(), e=4);
            tc.verifyEqual(tc.custom().e, 4);
        end

        function replacesANestedStructWhole(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, struct('nested', struct('a', 1, 'b', 2)));
            addToManifest(tc.Dir, struct('nested', struct('a', 3)));
            tc.verifyEqual(tc.custom().nested, struct('a', 3));
        end

        function addsToAnArrayOfDatasets(tc)
            several = [tc.Ds tc.moreDatasets(2)];
            tc.Ds.writeManifest();   % the others have none yet
            c = addToManifest(several, struct('a', 1), b=2);
            tc.verifyClass(c, 'cell');
            tc.verifySize(c, size(several));
            tc.verifyEqual(c{2}, struct('a', 1, 'b', 2));
            for k = 1:numel(several)
                tc.verifyEqual(readJsonFile(several(k).manifestFile()).custom, struct('a', 1, 'b', 2));
            end
            % one element is one dataset: its block, not a cell
            tc.verifyClass(addToManifest(several(1), d=3), 'struct');
        end

        function emptyArrayOfDatasetsDoesNothing(tc)
            c = addToManifest(tc.Ds([]), a=1);
            tc.verifyEmpty(c);
            tc.verifyFalse(isfile(tc.Ds.manifestFile()));
            tc.verifyError(@() addToManifest(tc.Ds([]), a=@sin), 'addToManifest:BadValue');
        end

        function aBadManifestInAnArrayStopsThemAll(tc)
            ds = tc.moreDatasets(1);
            tc.Ds.writeManifest();
            before = fileread(tc.Ds.manifestFile());
            f = ds.manifestFile();
            fid = fopen(f, 'w');
            fwrite(fid, '{not json', 'char');
            fclose(fid);
            tc.verifyError(@() addToManifest([tc.Ds ds], a=1), 'addToManifest:Unreadable');
            tc.verifyEqual(fileread(tc.Ds.manifestFile()), before);
        end

        function takesNameValueAsTextPairs(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, "a", 1, 'b', 2);
            tc.verifyEqual(tc.custom(), struct('a', 1, 'b', 2));
        end

        function replacesANameAndKeepsTheRest(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, a=1, b=2);
            addToManifest(tc.Dir, b=3);
            tc.verifyEqual(tc.custom(), struct('a', 1, 'b', 3));
        end

        function changesNothingElseButUpdated(tc)
            tc.Ds.Tags = {'pilot'};
            tc.Ds.ManualArtifacts = [1 2; 3 4];
            tc.Ds.writeManifest();
            m0 = readJsonFile(tc.Ds.manifestFile());
            m0.updated = 'old';
            writeJsonFile(tc.Ds.manifestFile(), m0);
            m0 = readJsonFile(tc.Ds.manifestFile());

            addToManifest(tc.Dir, a=1);
            m1 = readJsonFile(tc.Ds.manifestFile());
            tc.verifyNotEqual(m1.updated, 'old');
            tc.verifyEqual(rmfield(m1, {'updated', 'custom'}), rmfield(m0, 'updated'));
        end

        function survivesARewriteByTheDataset(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, a=1);
            tc.Ds.writeManifest();   % this object has never seen the block
            tc.verifyEqual(tc.custom(), struct('a', 1));

            d2 = EphysDataset(tc.Dir, AutoMetadata=false, Name=tc.Ds.Name);
            d2.applyManifest();
            d2.writeManifest();
            tc.verifyEqual(tc.custom(), struct('a', 1));
        end

        function datasetWithoutCustomWritesNoBlock(tc)
            tc.Ds.writeManifest();
            tc.Ds.writeManifest();
            tc.verifyFalse(isfield(readJsonFile(tc.Ds.manifestFile()), 'custom'));
        end

        function viewerShowsIt(tc)
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, surgeon="DS");
            T = ManifestViewerApp.summaryRows(readJsonFile(tc.Ds.manifestFile()));
            row = T(T.Section == "Other" & contains(T.Field, "surgeon"), :);
            tc.verifyEqual(height(row), 1);
            tc.verifyEqual(row.Value, "DS");
        end

        function ignoresTheCopyManifestInAFolder(tc)
            tc.Ds.writeManifest();
            writeJsonFile(fullfile(tc.Dir, "session_manifest.json"), struct('manifestVersion', 3));
            addToManifest(tc.Dir, a=1);
            tc.verifyEqual(tc.custom(), struct('a', 1));
        end

        function refusesBadInput(tc)
            tc.Ds.writeManifest();
            before = fileread(tc.Ds.manifestFile());
            tc.verifyError(@() addToManifest(tc.Dir), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, struct()), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, "a"), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, "not valid", 1), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, 5, 1), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(5, a=1), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(["x" "y"], a=1), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, a=@sin), 'addToManifest:BadValue');
            tc.verifyError(@() addToManifest(tc.Dir, struct('a', 1), "b"), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, struct('a', 1), struct('b', 2)), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, "a", 1, struct('b', 2)), 'addToManifest:BadInput');
            tc.verifyError(@() addToManifest(tc.Dir, struct('a', {1, 2})), 'addToManifest:BadInput');
            tc.verifyEqual(fileread(tc.Ds.manifestFile()), before);
        end

        function refusesATargetItCannotUse(tc)
            tc.verifyError(@() addToManifest(fullfile(tc.Dir, "nope"), a=1), 'addToManifest:NotFound');
            tc.verifyError(@() addToManifest(tc.Dir, a=1), 'addToManifest:NoManifest');
            tc.Ds.writeManifest();
            writeJsonFile(fullfile(tc.Dir, "other_manifest.json"), struct('schema', EphysDataset.ManifestSchema));
            tc.verifyError(@() addToManifest(tc.Dir, a=1), 'addToManifest:Ambiguous');
        end

        function leavesAnUnreadableManifestAlone(tc)
            f = tc.Ds.manifestFile();
            for txt = ["{not json", "{""schema"": ""intan-dataset-manifest/99""}", ...
                    "{""schema"": ""intan-dataset-manifest/2"", ""custom"": 5}"]
                fid = fopen(f, 'w');
                fwrite(fid, txt, 'char');
                fclose(fid);
                tc.verifyError(@() addToManifest(tc.Ds, a=1), 'addToManifest:Unreadable');
                tc.verifyEqual(string(fileread(f)), txt);
            end
        end
    end

    methods (Access = private)
        function ds = moreDatasets(tc, n)
            ds = EphysDataset.empty;
            for k = 1:n
                folder = string(tempname);
                mkdir(folder);
                tc.addTeardown(@() rmdir(folder, 's'));
                ds(k) = EphysDataset(folder, AutoMetadata=false, Name="subjB" + k + "_260101_120000");
            end
        end

        function c = custom(tc)
            m = readJsonFile(tc.Ds.manifestFile());
            c = m.custom;
        end
    end
end
