function results = run_all_tests(names, opts)
%run_all_tests  Run the test suites of pipeline/ and analysis/ with matlab.unittest.
%   run_all_tests            runs every suite: each function-style test_*.m
%                            (as one test of LegacySuiteTest) and each
%                            matlab.unittest.TestCase class (test_CopySessions,
%                            test_BinaryReader, ...)
%   run_all_tests(NAMES)     runs only the named suites (string array)
%
%   Options
%     JUnit           file to write a JUnit XML report to, for a CI server
%                     ("" = none)
%     Coverage        folder to write an HTML code-coverage report of
%                     pipeline/ and analysis/ to ("" = none; slow)
%     CoverageXML     file to write the same coverage as Cobertura XML to
%                     ("" = none; not together with Coverage)
%     Tag             run only the TestCase tests with one of these tags
%                     (function-style suites have none)
%
%   Every app reads and writes its preferences in a temporary file for the
%   whole run (AppPrefs.useTemporary), so the run never touches your own
%   and two MATLABs can run tests at once. Each failed check of a
%   function-style suite is a failure of its own in the report
%   (LegacySuiteTest.checkFailed). The run raises an error at the end when
%   any test failed, so it can drive `matlab -batch` and CI:
%
%     matlab -batch "cd('C:\src\ephys_analysis\pipeline'); run_all_tests(JUnit='junit.xml')"
%
%   Tests that assume something this machine lacks (a toolbox, Windows,
%   Python) are skipped as Incomplete, not failed.
%
%   Returns a table, one row per suite: Suite, Passed, Seconds, Tests,
%   Failed, Skipped, Message.
%
%   See also LegacySuiteTest, findTestSuites, AppPrefs.

arguments
    names (1,:) string = string.empty(1, 0)
    opts.JUnit (1,1) string = ""
    opts.Coverage (1,1) string = ""
    opts.CoverageXML (1,1) string = ""
    opts.Tag (1,:) string = string.empty(1, 0)
end

import matlab.unittest.TestSuite
import matlab.unittest.TestRunner
import matlab.unittest.plugins.XMLPlugin
import matlab.unittest.plugins.CodeCoveragePlugin

here = fileparts(mfilename('fullpath'));
repo = fileparts(here);
ana = fullfile(repo, 'analysis');
addpath(here);
addpath(repo);
addpath(ana);

if opts.Coverage ~= "" && opts.CoverageXML ~= ""
    error('run_all_tests:TwoCoverageFormats', 'Give Coverage or CoverageXML, not both.');
end

restorePrefs = AppPrefs.useTemporary(); %#ok<NASGU> no suite reads or writes your preferences

functionSuites = findTestSuites(Kind="function");
classSuites = findTestSuites(Kind="class");
if ~isempty(names)
    unknown = setdiff(names, [functionSuites classSuites], 'stable');
    if ~isempty(unknown)
        error('run_all_tests:UnknownSuite', 'No test suite named %s. The suites are: %s.', ...
            strjoin(unknown, ', '), strjoin([functionSuites classSuites], ', '));
    end
    functionSuites = functionSuites(ismember(functionSuites, names));
    classSuites = classSuites(ismember(classSuites, names));
end

suite = matlab.unittest.Test.empty(1, 0);
group = strings(1, 0);
if ~isempty(functionSuites)
    legacy = TestSuite.fromFile(fullfile(here, 'LegacySuiteTest.m'));
    keep = false(1, numel(legacy));
    for k = 1:numel(legacy)
        keep(k) = ismember(string(legacy(k).Parameterization(1).Value), functionSuites);
    end
    legacy = legacy(keep);
    suite = [suite, reshape(legacy, 1, [])];
    for k = 1:numel(legacy)
        group(end + 1) = string(legacy(k).Parameterization(1).Value); %#ok<AGROW>
    end
end
for c = classSuites
    file = fullfile(here, c + ".m");
    if ~isfile(file); file = fullfile(ana, c + ".m"); end
    s = TestSuite.fromFile(file);
    suite = [suite, reshape(s, 1, [])]; %#ok<AGROW>
    group = [group, repmat(c, 1, numel(s))]; %#ok<AGROW>
end
if ~isempty(opts.Tag)
    keep = false(1, numel(suite));
    for k = 1:numel(suite)
        keep(k) = any(ismember(string(suite(k).Tags), opts.Tag));
    end
    suite = suite(keep);
    group = group(keep);
end
if isempty(suite)
    error('run_all_tests:NothingToRun', 'No test matches the suites and tags given.');
end

runner = TestRunner.withTextOutput;
if opts.JUnit ~= ""
    ensureFolder(opts.JUnit, true);
    runner.addPlugin(XMLPlugin.producingJUnitFormat(char(opts.JUnit)));
end
if opts.Coverage ~= "" || opts.CoverageXML ~= ""
    if opts.Coverage ~= ""
        ensureFolder(opts.Coverage, false);
        format = matlab.unittest.plugins.codecoverage.CoverageReport(char(opts.Coverage));
    else
        ensureFolder(opts.CoverageXML, true);
        format = matlab.unittest.plugins.codecoverage.CoberturaFormat(char(opts.CoverageXML));
    end
    runner.addPlugin(CodeCoveragePlugin.forFolder({here, ana}, 'IncludingSubfolders', true, 'Producing', format));
end

R = runner.run(suite);

suites = unique(group, 'stable');
n = numel(suites);
passed = false(n, 1); seconds = zeros(n, 1); nTests = zeros(n, 1);
nFailed = zeros(n, 1); nSkipped = zeros(n, 1); message = strings(n, 1);
for k = 1:n
    r = R(group == suites(k));
    nTests(k) = numel(r);
    nFailed(k) = nnz([r.Failed]);
    nSkipped(k) = nnz([r.Incomplete] & ~[r.Failed]);   % assumption failures: skipped, not failed
    seconds(k) = sum([r.Duration]);
    passed(k) = nFailed(k) == 0;
    if nFailed(k) > 0
        message(k) = sprintf('%d of %d test(s) failed', nFailed(k), nTests(k));
    end
end
results = table(suites(:), passed, seconds, nTests, nFailed, nSkipped, message, ...
    'VariableNames', {'Suite', 'Passed', 'Seconds', 'Tests', 'Failed', 'Skipped', 'Message'});

fprintf('\n######## Summary ########\n');
disp(results);
if opts.JUnit ~= ""; fprintf('JUnit report: %s\n', opts.JUnit); end
if opts.Coverage ~= ""; fprintf('Coverage report: %s\n', fullfile(opts.Coverage, 'index.html')); end
if opts.CoverageXML ~= ""; fprintf('Coverage (Cobertura): %s\n', opts.CoverageXML); end
if ~all(passed)
    error('run_all_tests:Failures', '%d of %d suites failed.', nnz(~passed), n);
end
end


function ensureFolder(target, isFile)
%ensureFolder  Create the folder TARGET is (or, for a file, lies in).
folder = target;
if isFile; folder = fileparts(target); end
if folder ~= "" && ~isfolder(folder); mkdir(folder); end
end
