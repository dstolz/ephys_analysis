classdef test_LabDB < matlab.unittest.TestCase
    %test_LabDB  The lab database layer: settings, password vault, storage roots, connection, window, lamp.
    %   Everything runs against LabDBFakeBackend, in a temporary preference
    %   store, a fake password vault and a temporary database folder: no
    %   server, no Database Toolbox, nothing of the user's touched.
    %
    %   Covered: LabDBSettings (defaults, round trip, a wrong field refused,
    %   a stored value of the wrong kind falls back to its default);
    %   LabDBSecrets (the fake vault); LabRoots (locate: longest root, under
    %   none, the root itself, a marker naming another root refused;
    %   resolve; markers); LabDB (off until set up, connected, offline with
    %   a growing pause and Force, no password or a refusal is "attention",
    %   StateChanged, the temporary folder); LabDBPanel (save, test the
    %   connection and keep the person id, map and register a root);
    %   LabDBLamp (follows the state).
    %
    %   Usage:  runtests("test_LabDB")

    properties (Access = private)
        Fake
        Restore = {}
    end

    methods (TestMethodSetup)
        function isolate(tc)
            tc.Restore = {AppPrefs.useTemporary(), LabDBSecrets.useFake(), LabDB.useTemporary()};
            tc.Fake = LabDBFakeBackend();
            fake = tc.Fake;
            tc.Restore{end+1} = LabDB.useBackend(@() fake);
            tc.addTeardown(@() tc.clearRestore());
        end
    end

    methods (Access = private)
        function clearRestore(tc)
            % the backend first (it settles from the preferences), then the stores
            for k = numel(tc.Restore):-1:1
                tc.Restore{k} = [];
            end
        end

        function s = configure(tc, password)
            %configure  Settings for the fake server, saved, with PASSWORD in the fake vault.
            if nargin < 2
                password = tc.Fake.Password;
            end
            s = LabDBSettings.defaults();
            s.Enabled = true;
            s.Server = "labdb.test";
            s.Username = "jdoe";
            LabDBSettings.save(s);
            s = LabDBSettings.load();
            if password ~= ""
                LabDBSecrets.setFake(s, password);
            end
        end
    end

    methods (Test)
        function settingsRoundTrip(tc)
            s = LabDBSettings.load();
            tc.verifyEqual(s, LabDBSettings.defaults(), "nothing saved: the defaults");
            tc.verifyFalse(LabDBSettings.isConfigured(s));
            s.Enabled = true;
            s.Server = "  labdb.example.edu ";
            s.Username = "jdoe";
            s.Roots = struct("Name", "nas-main", "Path", tempdir);
            s.ConnectTimeout = 0.5;
            LabDBSettings.save(s);
            t = LabDBSettings.load();
            tc.verifyEqual(t.Server, "labdb.example.edu", "trimmed");
            tc.verifyEqual(t.ConnectTimeout, 2, "libpq's smallest connect timeout");
            tc.verifyEqual(t.Roots.Name, "nas-main");
            tc.verifyTrue(LabDBSettings.isConfigured(t));

            bad = t;
            bad.Port = 70000;
            tc.verifyError(@() LabDBSettings.save(bad), "LabDBSettings:Invalid");
            bad = t;
            bad.LabTimeZone = "Mars/Olympus";
            tc.verifyError(@() LabDBSettings.save(bad), "LabDBSettings:Invalid");
            bad = t;
            bad.Roots = struct("Name", {"a", "a"}, "Path", {tempdir, tempdir});
            tc.verifyError(@() LabDBSettings.save(bad), "LabDBSettings:Invalid", "a root listed twice");
            bad = t;
            bad.PersonId = "not-a-uuid";
            tc.verifyError(@() LabDBSettings.save(bad), "LabDBSettings:Invalid");

            stored = AppPrefs.getpref(LabDBSettings.Group, LabDBSettings.Name);
            stored.Port = "five";       % written by something else
            AppPrefs.setpref(LabDBSettings.Group, LabDBSettings.Name, stored);
            tc.verifyEqual(LabDBSettings.load().Port, 5432, "a stored value of the wrong kind: the default");
            tc.verifyEqual(LabDBSettings.load().Server, "labdb.example.edu", "the other fields kept");
        end

        function fakeVault(tc)
            s = tc.configure("");
            tc.verifyFalse(LabDBSecrets.has(s));
            tc.verifyError(@() LabDBSecrets.get(s), "LabDBSecrets:None");
            LabDBSecrets.setFake(s, "secret");
            tc.verifyTrue(LabDBSecrets.has(s));
            tc.verifyEqual(LabDBSecrets.get(s), "secret");
            tc.verifyEqual(LabDBSecrets.secretName(s), "CarasLabDB:jdoe@labdb.test:5432/lab");
            LabDBSecrets.remove(s);
            tc.verifyFalse(LabDBSecrets.has(s));
        end

        function rootsLocateAndResolve(tc)
            top = string(tempname);
            mkdir(fullfile(top, "nas", "G-1", "s1"));
            mkdir(fullfile(top, "nas", "inner"));
            tc.addTeardown(@() rmdir(top, "s"));
            s = LabDBSettings.defaults();
            s.Roots = struct("Name", {"nas", "inner"}, ...
                "Path", {fullfile(top, "nas"), fullfile(top, "nas", "inner")});
            file = string(fullfile(top, "nas", "G-1", "s1", "a.mat"));
            [root, rel, why] = LabRoots.locate(file, s);
            tc.verifyEqual([root, rel, why], ["nas", "G-1/s1/a.mat", ""]);
            [root, rel] = LabRoots.locate(string(fullfile(top, "nas", "inner", "b.mat")), s);
            tc.verifyEqual([root, rel], ["inner", "b.mat"], "the longest root wins");
            [root, ~, why] = LabRoots.locate(string(fullfile(tempdir, "elsewhere.mat")), s);
            tc.verifyEqual(root, "");
            tc.verifySubstring(why, "none of the mapped");
            [root, ~, why] = LabRoots.locate(string(fullfile(top, "nas")), s);
            tc.verifyEqual(root, "");
            tc.verifySubstring(why, "root folder itself");
            tc.verifyEqual(LabRoots.resolve("nas", "G-1/s1/a.mat", s), file);
            tc.verifyEqual(LabRoots.resolve("other", "a.mat", s), "");

            % A marker naming another root: refused.
            LabRoots.writeMarker(fullfile(top, "nas"), "nas-old", 7);
            [root, ~, why] = LabRoots.locate(file, s);
            tc.verifyEqual(root, "");
            tc.verifySubstring(why, "nas-old");
            LabRoots.writeMarker(fullfile(top, "nas"), "nas", 7);
            tc.verifyEqual(LabRoots.locate(file, s), "nas", "its own marker: accepted");
        end

        function offUntilSetUp(tc)
            tc.verifyEmpty(LabDB.connect());
            tc.verifyEqual(LabDB.status().State, "off");
            tc.verifyEmpty(tc.Fake.Calls, "nothing is tried while the database is off");
            s = tc.configure();
            s.Enabled = false;
            LabDBSettings.save(s);
            tc.verifyEmpty(LabDB.connect());
            tc.verifySubstring(LabDB.status().Message, "turned off");
        end

        function connectsAndReportsState(tc)
            tc.configure();
            before = LabDB.status().Since;
            b = LabDB.connect();
            tc.verifyNotEmpty(b);
            st = LabDB.status();
            tc.verifyEqual(st.State, "connected");
            tc.verifyFalse(isnat(st.Since), "the change of state is stamped (and StateChanged sent)");
            if ~isnat(before)
                tc.verifyGreaterThanOrEqual(st.Since, before);
            end
            tc.verifyEqual(tc.Fake.Calls(1:2), ["probe"; "open"], "probed before opening");
            tc.verifyEqual(b.person().PersonId, tc.Fake.PersonId);
            n = tc.Fake.Opens;
            LabDB.connect();
            tc.verifyEqual(tc.Fake.Opens, n, "an open connection is reused");
            LabDB.disconnect();
            tc.verifyNotEqual(LabDB.status().State, "connected");
        end

        function offlineWaitsBeforeTryingAgain(tc)
            tc.configure();
            tc.Fake.Reachable = false;
            t0 = tic;
            tc.verifyEmpty(LabDB.connect());
            tc.verifyLessThan(toc(t0), 2, "an unreachable server costs no wait here");
            st = LabDB.status();
            tc.verifyEqual(st.State, "offline");
            tc.verifySubstring(st.Message, "keep working");
            tc.verifyGreaterThan(st.NextTry, datetime("now", "TimeZone", "local"));
            probes = nnz(tc.Fake.Calls == "probe");
            tc.verifyEmpty(LabDB.connect());
            tc.verifyEqual(nnz(tc.Fake.Calls == "probe"), probes, "no new try before NextTry");
            tc.Fake.Reachable = true;
            tc.verifyNotEmpty(LabDB.connect(Force=true), "Force tries at once");
            tc.verifyEqual(LabDB.status().State, "connected");
        end

        function attentionWhenSomethingHereIsWrong(tc)
            tc.configure("");
            tc.verifyEmpty(LabDB.connect(Force=true));
            tc.verifyEqual(LabDB.status().State, "attention");
            tc.verifySubstring(LabDB.status().Message, "No password");
            LabDBSecrets.setFake(LabDBSettings.load(), "wrong");
            tc.verifyEmpty(LabDB.connect(Force=true));
            tc.verifyEqual(LabDB.status().State, "attention");
            tc.verifySubstring(LabDB.status().Message, "refused");
        end

        function folderIsTemporary(tc)
            d = LabDB.folder();
            tc.verifyTrue(isfolder(d));
            tc.verifyEqual(d, string(getenv(LabDB.EnvVar)), "useTemporary's folder");
        end

        function panelSavesTestsAndMapsRoots(tc)
            s = tc.configure();
            p = LabDBPanel.open(Visible=false);
            tc.addTeardown(@() p.close());
            p.Ctl.Server.Value = 'labdb.other';
            tc.verifyTrue(p.save());
            tc.verifyEqual(LabDBSettings.load().Server, "labdb.other");
            p.Ctl.Server.Value = char(s.Server);
            p.testConnection();
            tc.verifyEqual(LabDB.status().State, "connected");
            tc.verifyEqual(LabDBSettings.load().PersonId, tc.Fake.PersonId, "the person id is kept");
            tc.verifySubstring(string(p.Ctl.Message.Text), tc.Fake.PersonId);

            folder = string(tempname);
            mkdir(folder);
            tc.addTeardown(@() rmdir(folder, "s"));
            LabRoots.writeMarker(folder, "someone-else", 3);
            p.addRoot("ws-test-d", folder);
            tc.verifyEmpty(p.Roots, "a folder marked as another root is refused");
            delete(fullfile(folder, LabRoots.MarkerFile));
            p.addRoot("ws-test-d", folder);
            tc.verifyEqual(p.Roots.Name, "ws-test-d");
            p.registerRoot("ws-test-d");
            tc.verifyTrue(any(tc.Fake.Roots.name == "ws-test-d"), "registered in the database");
            tc.verifyTrue(isfile(fullfile(folder, LabRoots.MarkerFile)), "and its folder marked");
            m = jsondecode(fileread(fullfile(folder, LabRoots.MarkerFile)));
            tc.verifyEqual(string(m.name), "ws-test-d");
            tc.verifyTrue(p.save());
            tc.verifyEqual(LabDBSettings.load().Roots.Name, "ws-test-d");
        end

        function lampFollowsTheState(tc)
            f = uifigure("Visible", "off");
            tc.addTeardown(@() delete(f));
            g = uigridlayout(f, [1 2]);
            lamp = LabDBLamp(g, Row=1, Column=2, Parent=f);
            tc.verifyEqual(string(lamp.Button.Text), "Database: off");
            tc.configure();
            LabDB.connect(Force=true);
            tc.verifyEqual(string(lamp.Button.Text), "Database: connected");
            tc.Fake.Reachable = false;
            LabDB.disconnect();
            LabDB.connect(Force=true);
            tc.verifyEqual(string(lamp.Button.Text), "Database: offline");
            tc.verifySubstring(string(lamp.Button.Tooltip), "out of reach");
        end
    end
end
