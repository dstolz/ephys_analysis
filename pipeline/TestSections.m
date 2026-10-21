classdef TestSections < handle
    % TestSections  Run some sections of a function-style test suite, and time every section.
    %   A function-style suite (test_EphysAnalysisApp, test_EphysPipelineApp,
    %   test_EphysAnalysisFigures) builds its fixture, then runs numbered
    %   sections of checks. With this class each section is guarded, so a
    %   change to one tab or one panel type is tested by its own section:
    %
    %     function test_X(opts)
    %     arguments
    %         opts.Sections (1,:) string = string.empty(1, 0)
    %     end
    %     ...fixture...
    %     S = TestSections(mfilename, opts.Sections, Needs=["5d.psth" "5d.remove"; "5d.remove" "5d.add"]);
    %     timing = onCleanup(@() S.done());
    %     if S.sec("1", "build, open the project, scan")
    %         ...checks...
    %     end
    %     if S.wants("5d.search")      % a continuation of a section: no header
    %         ...
    %     end
    %
    %   S.sec(ID, TITLE) prints the section header as before
    %   ("== 5d.add. a figure from a template ==", or "-- ... skipped --") and
    %   returns whether the section runs. It also prints the time the previous
    %   section took ("[test_X 5d.add: 12.3 s]"), and done() the slowest ones,
    %   so a slow section is seen in every run.
    %
    %   SECTIONS empty runs every section. Otherwise a section runs when its
    %   id is listed, or a listed id is a prefix of its id up to a dot ("5d"
    %   runs every "5d.*"; "5" does not run "5d"), or a section that runs
    %   declares it needs it (NEEDS: rows of [id, prerequisite id], followed
    %   transitively). What a section needs from an earlier one that it does
    %   not declare, it sets up itself (idempotent helpers), so that every
    %   section can run alone after the fixture.
    %
    %   run_all_tests chooses sections with "test_X:5i,5j" (or Sections=);
    %   a suite run directly takes test_X(Sections="5i").
    %   TestSections.list(FILE) lists a suite's section ids;
    %   TestSections.accepts(FILE) says whether it takes Sections.
    %
    %   See also run_all_tests, LegacySuiteTest.

    properties (SetAccess = private)
        Suite (1,1) string = ""          % the suite's name, for the timing lines
        Wanted (1,:) string = string.empty(1, 0)   % the sections asked for, with what they need; empty = every section
        Needs (:,2) string = strings(0, 2)         % rows: section id, the id it needs
        Ran (1,:) string = string.empty(1, 0)      % sections run so far, in order
        Seconds (1,:) double = zeros(1, 0)         % their times
        SkippedIds (1,:) string = string.empty(1, 0)
    end

    properties (Access = private)
        Current (1,1) string = ""
        Started = []
    end

    methods
        function obj = TestSections(suite, wanted, opts)
            arguments
                suite (1,1) string
                wanted (1,:) string = string.empty(1, 0)
                opts.Needs (:,2) string = strings(0, 2)
            end
            obj.Suite = suite;
            obj.Needs = opts.Needs;
            wanted = wanted(strtrim(wanted) ~= "");
            if isempty(wanted); return; end
            wanted = unique(strtrim(wanted), 'stable');
            added = string.empty(1, 0);
            grew = true;
            while grew
                grew = false;
                for r = 1:size(opts.Needs, 1)
                    id = opts.Needs(r, 1); pre = opts.Needs(r, 2);
                    if TestSections.listed(id, [wanted added]) && ~TestSections.listed(pre, [wanted added])
                        added(end + 1) = pre; %#ok<AGROW>
                        grew = true;
                    end
                end
            end
            obj.Wanted = [wanted added];
            if isempty(added)
                fprintf('Sections: %s\n', strjoin(wanted, ', '));
            else
                fprintf('Sections: %s (+%s needed)\n', strjoin(wanted, ', '), strjoin(added, ', '));
            end
        end

        function tf = sec(obj, id, title)
            %sec  Start section ID (header printed) when it runs; print the previous section's time.
            arguments
                obj
                id (1,1) string
                title (1,1) string = ""
            end
            obj.closeSection();
            tf = obj.wants(id);
            if tf
                fprintf('\n== %s. %s ==\n', id, title);
                obj.Current = id;
                obj.Started = tic;
            else
                fprintf('\n-- %s. %s: skipped --\n', id, title);
                obj.SkippedIds(end + 1) = id;
            end
        end

        function tf = wants(obj, id)
            %wants  True when section ID runs (no header, no timing: for a block that continues a section).
            tf = isempty(obj.Wanted) || TestSections.listed(string(id), obj.Wanted);
        end

        function done(obj)
            %done  Close the last section and print the sections' times, slowest first.
            obj.closeSection();
            if isempty(obj.Ran); return; end
            [s, order] = sort(obj.Seconds, 'descend');
            n = min(5, numel(order));
            parts = arrayfun(@(k) sprintf('%s %.1f s', obj.Ran(order(k)), s(k)), 1:n, 'UniformOutput', false);
            fprintf('  [%s sections: %d run in %.1f s, %d skipped; slowest %s]\n', obj.Suite, numel(obj.Ran), ...
                sum(obj.Seconds), numel(obj.SkippedIds), strjoin(parts, ', '));
        end
    end

    methods (Access = private)
        function closeSection(obj)
            if obj.Current == ""; return; end
            s = toc(obj.Started);
            fprintf('  [%s %s: %.1f s]\n', obj.Suite, obj.Current, s);
            obj.Ran(end + 1) = obj.Current;
            obj.Seconds(end + 1) = s;
            obj.Current = "";
        end
    end

    methods (Static)
        function tf = listed(id, ids)
            %listed  True when ID is one of IDS, or one of IDS is its prefix up to a dot.
            id = string(id); ids = reshape(string(ids), 1, []);
            tf = any(ids == id) || any(startsWith(id, ids + "."));
        end

        function ids = list(file)
            %list  The section ids of the suite FILE: its S.sec("id", ...) calls, or its "== id. title ==" headers.
            txt = fileread(file);
            t = regexp(txt, 'S\.sec\("([^"]+)"', 'tokens');
            if isempty(t)
                t = regexp(txt, 'fprintf\(''\\n== (\S+)\. ', 'tokens');
            end
            ids = string(cellfun(@(c) c{1}, t, 'UniformOutput', false));
            ids = unique(reshape(ids, 1, []), 'stable');
        end

        function tf = accepts(file)
            %accepts  True when the suite FILE takes Sections (an opts.Sections argument).
            txt = fileread(file);
            tf = ~isempty(regexp(txt, '^\s*opts\.Sections\s*\(', 'once', 'lineanchors'));
        end

        function valid = check(file, ids)
            %check  The ids of IDS that name no section of FILE (exact, or a prefix up to a dot).
            have = TestSections.list(file);
            ids = reshape(string(ids), 1, []);
            bad = false(size(ids));
            for k = 1:numel(ids)
                bad(k) = ~any(have == ids(k)) && ~any(startsWith(have, ids(k) + "."));
            end
            valid = ids(bad);
        end
    end
end
