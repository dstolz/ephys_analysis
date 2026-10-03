classdef test_AppPrefs < matlab.unittest.TestCase
    %test_AppPrefs  The apps' preference store (AppPrefs, AppPrefsFixture).
    %   In a file store, set / get / ispref / rmpref behave as MATLAB's
    %   functions do, a group can be read whole, and nothing reaches MATLAB's
    %   own preferences; useTemporary starts empty, nests, and puts the
    %   previous store back; AppPrefsFixture does the same for a test.
    %
    %   Usage:  runtests("test_AppPrefs")

    properties (SetAccess = private)
        Group (1,1) string = ""   % a group name no MATLAB preference uses
    end

    methods (TestMethodSetup)
        function chooseGroup(tc)
            tc.Group = "AppPrefsTest_" + string(datetime('now', 'Format', 'HHmmssSSS')) + "_" + string(randi(1e9));
        end
    end

    methods (Test)
        function fileStoreRoundTrip(tc)
            restore = AppPrefs.useTemporary(); %#ok<NASGU>
            g = tc.Group;
            tc.verifyFalse(AppPrefs.ispref(g), "a new store has no groups");
            AppPrefs.setpref(g, "Folder", 'C:\data');
            AppPrefs.setpref(g, "Recent", {'a.json', 'b.json'});
            AppPrefs.setpref(g, "Options", struct('scale', 2, 'on', true));
            tc.verifyTrue(AppPrefs.ispref(g) && AppPrefs.ispref(g, "Folder") && ~AppPrefs.ispref(g, "Nope"), ...
                "ispref finds the group and its preferences");
            tc.verifyEqual(AppPrefs.getpref(g, "Folder"), 'C:\data', "a char value comes back as set");
            tc.verifyEqual(AppPrefs.getpref(g, "Recent"), {'a.json', 'b.json'}, "a cell value comes back as set");
            tc.verifyEqual(AppPrefs.getpref(g, "Options"), struct('scale', 2, 'on', true), "a struct comes back as set");
            S = AppPrefs.getpref(g);
            tc.verifyEqual(sort(string(fieldnames(S))), ["Folder"; "Options"; "Recent"], "getpref(group) gives the whole group");
            tc.verifyError(@() AppPrefs.getpref(g, "Nope"), 'AppPrefs:NoPreference', "a missing preference is an error");
            AppPrefs.rmpref(g, "Folder");
            tc.verifyFalse(AppPrefs.ispref(g, "Folder"), "rmpref removes one preference");
            AppPrefs.rmpref(g, "Folder");   % already gone: nothing happens
            AppPrefs.rmpref(g);
            tc.verifyFalse(AppPrefs.ispref(g), "rmpref(group) removes the group");
            tc.verifyFalse(ispref(char(g)), "nothing reached MATLAB's own preferences");
        end

        function temporaryStoresNestAndRestore(tc)
            before = AppPrefs.storeFile();
            outer = AppPrefs.useTemporary();
            outerFile = AppPrefs.storeFile();
            AppPrefs.setpref(tc.Group, "Level", 1);
            inner = AppPrefs.useTemporary();
            innerFile = AppPrefs.storeFile();
            tc.verifyNotEqual(innerFile, outerFile, "each temporary store has its own file");
            tc.verifyFalse(AppPrefs.ispref(tc.Group), "a new temporary store starts empty");
            AppPrefs.setpref(tc.Group, "Level", 2);
            clear inner
            tc.verifyEqual(AppPrefs.storeFile(), outerFile, "clearing the inner store puts the outer one back");
            tc.verifyEqual(AppPrefs.getpref(tc.Group, "Level"), 1, "the outer store kept its value");
            tc.verifyFalse(isfile(innerFile), "the inner store's file is deleted");
            clear outer
            tc.verifyEqual(AppPrefs.storeFile(), before, "clearing the outer store puts back the one in use before");
            tc.verifyFalse(isfile(outerFile), "the outer store's file is deleted");
        end

        function fixtureUsesATemporaryStore(tc)
            before = AppPrefs.storeFile();
            fx = tc.applyFixture(AppPrefsFixture);
            tc.verifyNotEqual(AppPrefs.storeFile(), before, "the fixture switches to a file of its own");
            tc.verifyTrue(startsWith(fx.SetupDescription, "App preferences kept in a temporary file"), ...
                "the fixture says where the preferences are");
            AppPrefs.setpref(tc.Group, "X", 1);
            tc.verifyFalse(ispref(char(tc.Group)), "nothing reached MATLAB's own preferences");
        end
    end
end
