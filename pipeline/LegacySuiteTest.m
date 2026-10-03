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
    %   New suites are matlab.unittest.TestCase classes (test_BinaryReader
    %   is the pattern to follow); run_all_tests runs those directly.
    %
    %   See also run_all_tests, findTestSuites.

    properties (TestParameter)
        Suite = findTestSuites(Kind="function", As="parameter")
    end

    methods (Test)
        function runSuite(testCase, Suite)
            LegacySuiteTest.current(testCase);
            restore = onCleanup(@() LegacySuiteTest.current([])); %#ok<NASGU>
            feval(Suite);
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
