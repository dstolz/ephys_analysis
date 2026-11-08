classdef test_writeManifestTags < matlab.unittest.TestCase
    %test_writeManifestTags  writeManifestTags: the tags written, the rest of the manifest kept, the refusals.
    %   A dataset in an empty temporary folder (no recording needed): the
    %   three kinds of target, only "tags" and "updated" changing (the text
    %   around them byte for byte, a custom block kept), the set made
    %   canonical, a dataset object reading the file's tags back when it
    %   writes its manifest, and each refusal leaving the file as it was.
    %
    %   Usage:  runtests("test_writeManifestTags")

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
        function writesToAFileFolderOrDataset(tc)
            tc.Ds.writeManifest();
            t = writeManifestTags(tc.Ds.manifestFile(), [" Pilot " "ofc"]);
            tc.verifyEqual(t, {'ofc', 'pilot'}, 'The set comes back trimmed, lowercase and sorted.');
            tc.verifyEqual(tc.fileTags(), {'ofc', 'pilot'});
            writeManifestTags(tc.Dir, "cohort-3");
            tc.verifyEqual(tc.fileTags(), {'cohort-3'});
            writeManifestTags(tc.Ds, {'a', 'b'});
            tc.verifyEqual(tc.Ds.Tags, {'a', 'b'}, 'A dataset''s Tags are set.');
            tc.verifyEqual(tc.fileTags(), {'a', 'b'});
            t = writeManifestTags(tc.Dir, {});
            tc.verifyEqual(t, {});
            tc.verifyEmpty(tc.fileTags());
        end

        function changesOnlyTheTagsAndTheTime(tc)
            tc.Ds.Tags = {'ofc'};
            tc.Ds.writeManifest();
            addToManifest(tc.Dir, surgeon="DS");
            f = tc.Ds.manifestFile();
            m0 = EphysDataset.readManifest(f);
            txt0 = string(fileread(f));
            writeManifestTags(f, ["ofc" "pilot"]);
            m = EphysDataset.readManifest(f);
            tc.verifyEqual(rmfield(m, {'tags', 'updated'}), rmfield(m0, {'tags', 'updated'}), ...
                'Every other field stays, the custom block too.');
            txt = string(fileread(f));
            tc.verifyEqual(withoutMembers(txt), withoutMembers(txt0), 'The text around tags and updated is as it was.');
            writeManifestTags(f, "ofc");
            tc.verifyTrue(contains(fileread(f), '"tags": ['), 'One tag is still written as a list.');
            tc.verifyEqual(tc.fileTags(), {'ofc'});
        end

        function addsTagsToAManifestWithout(tc)
            tc.Ds.writeManifest();
            f = tc.Ds.manifestFile();
            m = jsondecode(fileread(f));
            writeJsonFile(f, rmfield(m, 'tags'));
            writeManifestTags(f, "pilot");
            tc.verifyEqual(tc.fileTags(), {'pilot'});
        end

        function aDatasetReadsTheTagsBack(tc)
            tc.Ds.Tags = {'ofc'};
            tc.Ds.writeManifest();
            pause(1.1);   % "updated" has whole seconds: the dataset must see the file changed
            writeManifestTags(tc.Dir, ["ofc" "pilot"]);
            tc.Ds.writeManifest();   % another edit of the object's, unrelated to tags
            tc.verifyEqual(tc.Ds.Tags, {'ofc', 'pilot'}, 'writeManifest merges the tags written since.');
            tc.verifyEqual(tc.fileTags(), {'ofc', 'pilot'});
        end

        function refusalsWriteNothing(tc)
            tc.Ds.Tags = {'ofc'};
            tc.Ds.writeManifest();
            f = tc.Ds.manifestFile();
            txt0 = string(fileread(f));
            tc.verifyError(@() writeManifestTags(f, "bad tag!"), 'TagSet:Invalid');
            tc.verifyError(@() writeManifestTags(f, "t" + compose("%02d", 1:13)), 'TagSet:TooMany');
            tc.verifyError(@() writeManifestTags(fullfile(tc.Dir, "nope"), "a"), 'writeManifestTags:NotFound');
            tc.verifyError(@() writeManifestTags(42, "a"), 'writeManifestTags:BadInput');
            tc.verifyEqual(string(fileread(f)), txt0);
            empty = fullfile(tc.Dir, "empty");
            mkdir(empty);
            tc.verifyError(@() writeManifestTags(empty, "a"), 'writeManifestTags:NoManifest');
            copyfile(f, fullfile(tc.Dir, "other_manifest.json"));
            tc.verifyError(@() writeManifestTags(tc.Dir, "a"), 'writeManifestTags:Ambiguous');
            bad = fullfile(empty, "x_manifest.json");
            fid = fopen(bad, 'w'); fwrite(fid, 'not json'); fclose(fid);
            tc.verifyError(@() writeManifestTags(bad, "a"), 'writeManifestTags:Unreadable');
            tc.verifyEqual(string(fileread(bad)), "not json");
        end
    end

    methods
        function t = fileTags(tc)
            m = EphysDataset.readManifest(tc.Ds.manifestFile());
            t = TagSet.parse(m.tags);
        end
    end
end


function s = withoutMembers(txt)
%withoutMembers  TXT with the values of its top-level tags and updated members blanked out.
s = regexprep(txt, '("tags":\s*)\[[^\]]*\]', '$1[]');
s = regexprep(s, '("updated":\s*)"[^"]*"', '$1""');
end
