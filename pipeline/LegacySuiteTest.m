classdef LegacySuiteTest < matlab.unittest.TestCase
    % LegacySuiteTest  Each function-style test_*.m suite as one matlab.unittest test.
    %   The function-style suites (test_EphysDataset, test_EphysPipeline, ...)
    %   print PASS / FAIL lines and raise an error at the end when a check
    %   failed. Here each runs as one test, LegacySuiteTest/runSuite(Suite=<name>),
    %   so run_all_tests gives them what the TestCase suites have: JUnit
    %   output, code coverage and selection by name. Every failed check is
    %   also recorded on the test as a verification failure with the
    %   check's message (checkFailed, which each suite's check calls), so a
    %   report lists each failed check, not only the suite's final error.
    %
    %   runtests("LegacySuiteTest") runs them all; run_all_tests(NAMES)
    %   chooses. A suite run on its own (test_EphysDataset) behaves as
    %   before.
    %
    %   run_all_tests also hands over, for the run, the sections it was
    %   asked for per suite ("test_X:5i,5j", see TestSections; the suite is
    %   then called as test_X(Sections=...)) and the tags it excludes
    %   (ExcludeTag=): a suite's slow block asks
    %   LegacySuiteTest.isExcluded("Slow") and skips itself.
    %
    %   New suites are matlab.unittest.TestCase classes (test_BinaryReader
    %   is the pattern to follow); run_all_tests runs those directly.
    %
    %   See also run_all_tests, TestSections, findTestSuites.

    properties (TestParameter)
        Suite = findTestSuites(Kind="function", As="parameter")
    end

    methods (Test)
        function runSuite(testCase, Suite)
            LegacySuiteTest.current(testCase);
            restore = onCleanup(@() LegacySuiteTest.current([])); %#ok<NASGU>
            secs = LegacySuiteTest.sectionsFor(Suite);
            if isempty(secs)
                feval(Suite);
            else
                feval(Suite, "Sections", secs);
            end
        end
    end

    methods (Static)
        function out = sections(map)
            %sections  The sections run_all_tests chose, a struct array (Suite, Sections); sections(MAP) sets it.
            persistent chosen
            if isempty(chosen); chosen = struct('Suite', {}, 'Sections', {}); end
            if nargin; chosen = map; end
            out = chosen;
        end

        function secs = sectionsFor(suite)
            %sectionsFor  The sections chosen for SUITE (empty = every section).
            map = LegacySuiteTest.sections();
            secs = string.empty(1, 0);
            k = find(string({map.Suite}) == string(suite), 1);
            if ~isempty(k); secs = reshape(string(map(k).Sections), 1, []); end
        end

        function out = excluded(tags)
            %excluded  The tags run_all_tests excludes (ExcludeTag=); excluded(TAGS) sets them.
            persistent chosen
            if isempty(chosen); chosen = string.empty(1, 0); end
            if nargin; chosen = reshape(string(tags), 1, []); end
            out = chosen;
        end

        function tf = isExcluded(tag)
            %isExcluded  True when TAG is excluded: by run_all_tests' ExcludeTag, or, for a suite run on
            %   its own, by the environment variable EPHYS_TEST_EXCLUDE (tags separated by commas).
            tags = LegacySuiteTest.excluded();
            if isempty(tags)
                tags = strtrim(split(string(getenv('EPHYS_TEST_EXCLUDE')), ","));
            end
            tf = any(tags == string(tag));
        end

        function reset()
            %reset  Forget the sections and the excluded tags (the end of a run_all_tests run).
            LegacySuiteTest.sections(struct('Suite', {}, 'Sections', {}));
            LegacySuiteTest.excluded(string.empty(1, 0));
        end
    end

    methods (Static)
        function checkFailed(msg)
            %checkFailed  Record a failed check of a function-style suite on the running test.
            %   The suites' check() calls this after printing its FAIL line.
            %   Outside LegacySuiteTest (a suite run on its own) it does
            %   nothing.
            tc = LegacySuiteTest.current();
            if ~isempty(tc) && isvalid(tc)
                tc.verifyFail("check failed: " + string(msg));
            end
        end
    end

    methods (Static, Hidden)
        function tc = current(newTestCase)
            %current  The LegacySuiteTest running now ([] when none); current(TC) sets it.
            persistent active
            if nargin
                active = newTestCase;
            end
            tc = active;
        end
    end
end
