function results = run_all_tests(names)
%run_all_tests  Run every function-style test suite in this folder.
%   run_all_tests            runs all test_*.m suites found next to this file
%   run_all_tests(names)     runs only the named suites (string array)
%
%   Each suite prints PASS/FAIL lines and raises an error when any check
%   fails. A test_*.m that is a matlab.unittest.TestCase class (e.g.
%   test_NasSessions) is run with runtests and fails when any test fails.
%   This runner catches per-suite errors, prints a summary, and errors
%   at the end when any suite failed, so it can drive `matlab -batch` and CI:
%
%     matlab -batch "cd('C:\src\ephys_analysis\pipeline'); run_all_tests"
%
%   Returns a table (Suite, Passed, Seconds, Message).

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fileparts(here));

if nargin < 1 || isempty(names)
    d = dir(fullfile(here, 'test_*.m'));
    names = string(erase({d.name}, '.m'));
end
names = string(names(:)).';

n = numel(names);
passed  = false(n, 1);
seconds = zeros(n, 1);
message = strings(n, 1);

for k = 1:n
    fprintf('\n######## %s ########\n', names(k));
    t0 = tic;
    try
        mc = meta.class.fromName(char(names(k)));
        if ~isempty(mc) && any(strcmp({mc.SuperclassList.Name}, 'matlab.unittest.TestCase'))
            % matlab.unittest class suite: feval would only construct it.
            r = runtests(char(names(k)));
            disp(table(r));
            if any([r.Failed])   % assumption-skipped tests are Incomplete, not failures
                error('run_all_tests:ClassSuite', '%d of %d tests failed.', nnz([r.Failed]), numel(r));
            end
        else
            feval(char(names(k)));
        end
        passed(k) = true;
    catch err
        message(k) = string(err.message);
        fprintf(2, '  SUITE FAILED: %s\n', err.message);
    end
    seconds(k) = toc(t0);
end

results = table(names.', passed, seconds, message, ...
    'VariableNames', {'Suite', 'Passed', 'Seconds', 'Message'});

fprintf('\n######## Summary ########\n');
disp(results);
if ~all(passed)
    error('run_all_tests:Failures', '%d of %d suites failed.', nnz(~passed), n);
end
end
