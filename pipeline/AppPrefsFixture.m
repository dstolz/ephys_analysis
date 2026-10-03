classdef AppPrefsFixture < matlab.unittest.fixtures.Fixture
    % AppPrefsFixture  Run a test with the apps' preferences in a temporary file.
    %   tc.applyFixture(AppPrefsFixture) makes every app read and write its
    %   preferences in a new, empty file (AppPrefs.useTemporary) for the
    %   rest of the test (or the class, from TestClassSetup); the user's
    %   MATLAB preferences are never touched. The file is deleted afterwards.
    %
    %   See also AppPrefs.

    properties (Access = private)
        Restore = []
    end

    methods
        function setup(fixture)
            fixture.Restore = AppPrefs.useTemporary();
            fixture.SetupDescription = "App preferences kept in a temporary file: " + AppPrefs.storeFile();
        end

        function teardown(fixture)
            delete(fixture.Restore);
            fixture.Restore = [];
            fixture.TeardownDescription = "App preferences store restored.";
        end
    end
end
