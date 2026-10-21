classdef test_TestSections < matlab.unittest.TestCase
    % test_TestSections  TestSections: which sections run, what they pull in, the timing lines, the file helpers.

    methods (Test)
        function everythingByDefault(tc)
            S = TestSections("suite");
            tc.verifyTrue(S.wants("1"));
            tc.verifyTrue(S.wants("5d.add"));
            out = evalc('tf = S.sec("1", "first");');
            tc.verifyTrue(tf);
            tc.verifyTrue(contains(out, sprintf('\n== 1. first ==\n')), 'the header as before');
            out = evalc('S.sec("2", "second");');
            tc.verifyTrue(~isempty(regexp(out, '\[suite 1: [\d.]+ s\]', 'once')), 'the previous section timed');
            out = evalc('S.done();');
            tc.verifyTrue(contains(out, '[suite 2:') && contains(out, 'sections: 2 run in'), 'done() closes the last and sums');
            tc.verifyEqual(S.Ran, ["1" "2"]);
        end

        function listedAndPrefixes(tc)
            S = TestSections("suite", ["5d" "6"]);
            tc.verifyTrue(S.wants("5d"));
            tc.verifyTrue(S.wants("5d.add"), '"5d" selects every 5d.*');
            tc.verifyFalse(S.wants("5"), 'a prefix without the dot does not count');
            tc.verifyFalse(S.wants("5e"));
            tc.verifyTrue(S.wants("6"));
            out = evalc('tf = S.sec("5e", "skipped one");');
            tc.verifyFalse(tf);
            tc.verifyTrue(contains(out, '-- 5e. skipped one: skipped --'));
            tc.verifyEqual(S.SkippedIds, "5e");
        end

        function needsFollowedTransitively(tc)
            needs = ["5d.psth" "5d.remove"; "5d.remove" "5d.layers"; "5d.layers" "5d.add"; "8" "7"];
            out = evalc('S = TestSections("suite", "5d.psth", Needs=needs);');
            tc.verifyEqual(sort(S.Wanted), sort(["5d.psth" "5d.remove" "5d.layers" "5d.add"]));
            tc.verifyTrue(contains(out, 'Sections: 5d.psth (+') && contains(out, 'needed)'));
            tc.verifyTrue(S.wants("5d.add") && ~S.wants("8") && ~S.wants("5d.keys"));
            S = TestSections("suite", "5d", Needs=needs);
            tc.verifyEqual(S.Wanted, "5d", 'a prefix already covers what its sections need');
            S = TestSections("suite", "8", Needs=needs);
            tc.verifyEqual(S.Wanted, ["8" "7"]);
        end

        function fileHelpers(tc)
            folder = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            f = fullfile(folder, 'test_Demo.m');
            txt = ["function test_Demo(opts)" "arguments" "    opts.Sections (1,:) string = string.empty(1, 0)" "end" ...
                "S = TestSections(mfilename, opts.Sections);" ...
                "if S.sec(""1"", ""one"")" "end" "if S.sec(""5d.add"", ""two"")" "end" "if S.wants(""5d.add"")" "end" "end"];
            fid = fopen(f, 'w'); fprintf(fid, '%s\n', txt); fclose(fid);
            tc.verifyTrue(TestSections.accepts(f));
            tc.verifyEqual(TestSections.list(f), ["1" "5d.add"]);
            tc.verifyEqual(TestSections.check(f, ["1" "5d" "5d.add" "nope" "5"]), ["nope" "5"]);
            g = fullfile(folder, 'test_Old.m');
            txt = ["function test_Old()" "fprintf('\n== 1. one ==\n');" "fprintf('\n== 2b. two ==\n');" "end"];
            fid = fopen(g, 'w'); fprintf(fid, '%s\n', txt); fclose(fid);
            tc.verifyFalse(TestSections.accepts(g));
            tc.verifyEqual(TestSections.list(g), ["1" "2b"], 'the headers of a suite not converted');
        end

        function excludedTags(tc)
            LegacySuiteTest.reset();
            tc.addTeardown(@() LegacySuiteTest.reset());
            tc.verifyFalse(LegacySuiteTest.isExcluded("Slow"));
            LegacySuiteTest.excluded(["Slow" "Benchmark"]);
            tc.verifyTrue(LegacySuiteTest.isExcluded("Slow") && LegacySuiteTest.isExcluded("Benchmark"));
            tc.verifyFalse(LegacySuiteTest.isExcluded("Other"));
            LegacySuiteTest.sections(struct('Suite', {'test_A'}, 'Sections', {["5i" "5j"]}));
            tc.verifyEqual(LegacySuiteTest.sectionsFor("test_A"), ["5i" "5j"]);
            tc.verifyEmpty(LegacySuiteTest.sectionsFor("test_B"));
            LegacySuiteTest.reset();
            tc.verifyEmpty(LegacySuiteTest.sectionsFor("test_A"));
            tc.verifyFalse(LegacySuiteTest.isExcluded("Slow"));
        end
    end
end
