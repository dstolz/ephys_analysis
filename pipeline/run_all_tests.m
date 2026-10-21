function results = run_all_tests(names, opts)
%run_all_tests  Run the test suites of pipeline/ and analysis/ with matlab.unittest.
%   run_all_tests            runs every suite: each function-style test_*.m
%                            (as one test of LegacySuiteTest) and each
%                            matlab.unittest.TestCase class (test_CopySessions,
%                            test_BinaryReader, ...)
%   run_all_tests(NAMES)     runs only the named suites (string array or
%                            cellstr). A function-style suite that takes
%                            sections (TestSections) can be cut down to some:
%                            "test_EphysAnalysisApp:5i,5j" runs its fixture
%                            and the sections 5i and 5j (with the ones they
%                            declare they need); "5d" also selects every
%                            "5d.*". Single quotes survive every shell:
%                            run_all_tests({'test_EphysAnalysisApp:5i'})
%
%   Options
%     Sections        sections to run in every named function-style suite
%                     that takes them (the "suite:ids" form chooses per suite)
%     JUnit           file to write a JUnit XML report to, for a CI server
%                     ("" = none)
%     Coverage        folder to write an HTML code-coverage report of
%                     pipeline/ and analysis/ to ("" = none; slow)
%     CoverageXML     file to write the same coverage as Cobertura XML to
%                     ("" = none; not together with Coverage)
%     Tag             run only the TestCase tests with one of these tags
%                     (function-style suites have none, so Tag alone runs
%                     no function-style suite)
%     ExcludeTag      leave out the TestCase tests with one of these tags
%                     ("Slow": tests that start other processes for a
%                     minute or more; "Benchmark") and the blocks of
%                     function-style suites that ask
%                     LegacySuiteTest.isExcluded(tag). CI passes none.
%     ResultsCSV      file to write the results table to ("" = none),
%                     written before the run's final error
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
%   Returns a table, one row per suite: Suite, Sections ("" = all), Passed,
%   Seconds, Tests, Failed, Skipped, Message.
%
%   See also LegacySuiteTest, TestSections, findTestSuites, AppPrefs.

arguments
    names (1,:) string = string.empty(1, 0)
    opts.Sections (1,:) string = string.empty(1, 0)
    opts.JUnit (1,1) string = ""
    opts.Coverage (1,1) string = ""
    opts.CoverageXML (1,1) string = ""
    opts.Tag (1,:) string = string.empty(1, 0)
    opts.ExcludeTag (1,:) string = string.empty(1, 0)
    opts.ResultsCSV (1,1) string = ""
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
[names, secMap] = splitSections(names);   % "suite:ids" -> the suite, and its sections
if ~isempty(names)
    unknown = setdiff(names, [functionSuites classSuites], 'stable');
    if ~isempty(unknown)
        error('run_all_tests:UnknownSuite', 'No test suite named %s. The suites are: %s.', ...
            strjoin(unknown, ', '), strjoin([functionSuites classSuites], ', '));
    end
    functionSuites = functionSuites(ismember(functionSuites, names));
    classSuites = classSuites(ismember(classSuites, names));
end
if ~isempty(opts.Sections)
    if isempty(names)
        error('run_all_tests:SectionsNeedNames', 'Sections= needs the suites named.');
    end
    for s = functionSuites
        if ~any(string({secMap.Suite}) == s)
            secMap(end + 1) = struct('Suite', char(s), 'Sections', opts.Sections); %#ok<AGROW>
        end
    end
end
for k = 1:numel(secMap)
    s = string(secMap(k).Suite);
    file = suiteFile(here, ana, s);
    if ~ismember(s, findTestSuites(Kind="function")) || ~TestSections.accepts(file)
        error('run_all_tests:NoSections', '%s takes no sections (see TestSections).', s);
    end
    bad = TestSections.check(file, secMap(k).Sections);
    if ~isempty(bad)
        error('run_all_tests:UnknownSection', '%s has no section %s. Its sections are: %s.', ...
            s, strjoin(bad, ', '), strjoin(TestSections.list(file), ', '));
    end
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
if ~isempty(opts.ExcludeTag)
    keep = true(1, numel(suite));
    for k = 1:numel(suite)
        keep(k) = ~any(ismember(string(suite(k).Tags), opts.ExcludeTag));
    end
    suite = suite(keep);
    group = group(keep);
end
if isempty(suite)
    error('run_all_tests:NothingToRun', 'No test matches the suites and tags given.');
end

% the function-style suites read their sections and the excluded tags from LegacySuiteTest
LegacySuiteTest.sections(secMap);
LegacySuiteTest.excluded(opts.ExcludeTag);
resetLegacy = onCleanup(@() LegacySuiteTest.reset()); %#ok<NASGU>

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
nFailed = zeros(n, 1); nSkipped = zeros(n, 1); message = strings(n, 1); sections = strings(n, 1);
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
    m = find(string({secMap.Suite}) == suites(k), 1);
    if ~isempty(m); sections(k) = strjoin(string(secMap(m).Sections), ","); end
end
results = table(suites(:), sections, passed, seconds, nTests, nFailed, nSkipped, message, ...
    'VariableNames', {'Suite', 'Sections', 'Passed', 'Seconds', 'Tests', 'Failed', 'Skipped', 'Message'});

fprintf('\n######## Summary ########\n');
disp(results);
if opts.JUnit ~= ""; fprintf('JUnit report: %s\n', opts.JUnit); end
if opts.Coverage ~= ""; fprintf('Coverage report: %s\n', fullfile(opts.Coverage, 'index.html')); end
if opts.CoverageXML ~= ""; fprintf('Coverage (Cobertura): %s\n', opts.CoverageXML); end
if opts.ResultsCSV ~= ""
    ensureFolder(opts.ResultsCSV, true);
    writetable(results, char(opts.ResultsCSV));
    fprintf('Results: %s\n', opts.ResultsCSV);
end
if ~all(passed)
    error('run_all_tests:Failures', '%d of %d suites failed.', nnz(~passed), n);
end
end


function [names, secMap] = splitSections(names)
%splitSections  "suite:id1,id2" entries of NAMES split into the suite and a map of its sections.
%   SECMAP is a struct array (Suite, Sections); a suite named twice is an error.
secMap = struct('Suite', {}, 'Sections', {});
for k = 1:numel(names)
    parts = split(names(k), ":");
    names(k) = strtrim(parts(1));
    if numel(parts) < 2; continue; end
    ids = strtrim(split(strjoin(parts(2:end), ":"), ","));
    ids = reshape(ids(ids ~= ""), 1, []);
    if isempty(ids)
        error('run_all_tests:EmptySections', '%s names no section after the colon.', names(k));
    end
    if any(string({secMap.Suite}) == names(k))
        error('run_all_tests:SuiteTwice', '%s is named twice; give its sections in one entry.', names(k));
    end
    secMap(end + 1) = struct('Suite', char(names(k)), 'Sections', ids); %#ok<AGROW>
end
names = unique(names, 'stable');
end


function file = suiteFile(here, ana, name)
%suiteFile  The file of suite NAME: in this folder, else in analysis/.
file = fullfile(here, name + ".m");
if ~isfile(file); file = fullfile(ana, name + ".m"); end
end


function ensureFolder(target, isFile)
%ensureFolder  Create the folder TARGET is (or, for a file, lies in).
folder = target;
if isFile; folder = fileparts(target); end
if folder ~= "" && ~isfolder(folder); mkdir(folder); end
end
