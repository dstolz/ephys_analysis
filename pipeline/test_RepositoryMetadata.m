classdef test_RepositoryMetadata < matlab.unittest.TestCase
    %test_RepositoryMetadata  The release number agrees everywhere it is written.
    %   VERSION holds major.minor.patch; CITATION.cff's version is the same;
    %   CHANGELOG.md has an Unreleased section and a section for that
    %   number; ephysVersion reports it. Cutting a release means changing
    %   all of them (README.md, "Versions, license and citation").
    %
    %   Usage:  runtests("test_RepositoryMetadata")

    properties (SetAccess = private)
        Repo (1,1) string = ""
        Version (1,1) string = ""
    end

    methods (TestClassSetup)
        function readVersion(tc)
            tc.Repo = string(fileparts(fileparts(mfilename('fullpath'))));
            file = fullfile(tc.Repo, "VERSION");
            tc.assertTrue(isfile(file), "the repository has a VERSION file");
            tc.Version = strtrim(string(fileread(file)));
        end
    end

    methods (Test)
        function versionIsMajorMinorPatch(tc)
            tc.verifyTrue(~isempty(regexp(tc.Version, '^\d+\.\d+\.\d+$', 'once')), ...
                "VERSION holds major.minor.patch, not """ + tc.Version + """");
        end

        function citationHasTheVersion(tc)
            txt = string(fileread(fullfile(tc.Repo, "CITATION.cff")));
            v = regexp(txt, '(?m)^version:\s*"?([^"\s]+)"?\s*$', 'tokens', 'once');
            tc.assertNotEmpty(v, "CITATION.cff has a version line");
            tc.verifyEqual(string(v{1}), tc.Version, "CITATION.cff's version is VERSION's");
        end

        function changelogHasTheVersion(tc)
            txt = string(fileread(fullfile(tc.Repo, "CHANGELOG.md")));
            tc.verifyTrue(contains(txt, newline + "## [Unreleased]"), "CHANGELOG.md has an Unreleased section");
            tc.verifyTrue(contains(txt, newline + "## [" + tc.Version + "]"), ...
                "CHANGELOG.md has a section for " + tc.Version);
        end

        function ephysVersionReportsIt(tc)
            v = tc.verifyWarningFree(@() ephysVersion(), "ephysVersion reads VERSION without a warning");
            tc.verifyEqual(v.Version, tc.Version, "ephysVersion reports VERSION");
            tc.verifyTrue(startsWith(v.Text, v.Version), "its text starts with the version");
        end
    end
end
