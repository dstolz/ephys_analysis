function out = findTestSuites(opts)
%findTestSuites  The test suites of pipeline/ and analysis/.
%   NAMES = findTestSuites() lists every test_*.m in this folder and in the
%   repository's analysis folder, in folder then file-name order, as a
%   string row vector.
%
%   Options
%     Kind  "all" (default) | "function" (the function-style suites, which
%           print PASS / FAIL lines and run as LegacySuiteTest) | "class"
%           (the matlab.unittest.TestCase classes)
%     As    "names" (default) | "parameter": a scalar struct with one field
%           per suite holding its name, the form of a TestParameter
%           (LegacySuiteTest's Suite)
%
%   See also run_all_tests, LegacySuiteTest.

arguments
    opts.Kind (1,1) string {mustBeMember(opts.Kind, ["all" "function" "class"])} = "all"
    opts.As (1,1) string {mustBeMember(opts.As, ["names" "parameter"])} = "names"
end

here = fileparts(mfilename('fullpath'));
ana = fullfile(fileparts(here), 'analysis');
d = [dir(fullfile(here, 'test_*.m')); dir(fullfile(ana, 'test_*.m'))];
names = string(erase({d.name}, '.m'));
isClass = false(size(names));
for k = 1:numel(d)
    txt = fileread(fullfile(d(k).folder, d(k).name));
    isClass(k) = ~isempty(regexp(txt, '^\s*classdef\s[^\n]*matlab\.unittest\.TestCase', 'once', 'lineanchors'));
end
switch opts.Kind
    case "function"; names = names(~isClass);
    case "class";    names = names(isClass);
end

out = reshape(names, 1, []);
if opts.As == "parameter"
    out = cell2struct(cellstr(names(:)), cellstr(names(:)), 1);
end
end
