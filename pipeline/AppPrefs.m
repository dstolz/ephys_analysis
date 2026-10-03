classdef AppPrefs
    % AppPrefs  Where the apps keep their preferences: MATLAB's, or a file.
    %   The apps (EphysPreprocessingApp, EphysAnalysisApp, ChannelMapperApp)
    %   read and write their preferences only through these methods, which
    %   take the same arguments as MATLAB's own:
    %
    %     AppPrefs.ispref(group)              true when the group exists
    %     AppPrefs.ispref(group, name)        true when the preference exists
    %     v = AppPrefs.getpref(group, name)   its value (an error when missing)
    %     S = AppPrefs.getpref(group)         the whole group as a struct
    %     AppPrefs.setpref(group, name, v)
    %     AppPrefs.rmpref(group, name)        remove one preference
    %     AppPrefs.rmpref(group)              remove the group
    %
    %   By default they are MATLAB preferences (getpref / setpref), so an app
    %   remembers its settings across sessions as before. When the
    %   environment variable EPHYS_APP_PREFS_FILE names a file, every group
    %   lives in that .mat file instead (variable "prefs", one struct field
    %   per group), and MATLAB's preferences are neither read nor written.
    %
    %   Tests and screenshot runs use that, so they never touch the user's
    %   own preferences, and two MATLABs running them at once do not share a
    %   file:
    %
    %     restore = AppPrefs.useTemporary();   % a new, empty file in tempdir
    %     app = EphysPreprocessingApp;         % starts from no preferences
    %     ...
    %     clear restore                        % the file is deleted; the
    %                                          % previous store is back
    %
    %   Unlike MATLAB's getpref(group, name, default), getpref never adds a
    %   preference.
    %
    %   See also AppPrefsFixture, run_all_tests.

    properties (Constant)
        EnvVar = "EPHYS_APP_PREFS_FILE"   % names the file store; "" = MATLAB preferences
    end

    methods (Static)
        function tf = ispref(group, name)
            %ispref  True when GROUP (and NAME, when given) exists.
            arguments
                group (1,1) string
                name (1,1) string = missing
            end
            file = AppPrefs.storeFile();
            if file == ""
                if ismissing(name)
                    tf = ispref(char(group));
                else
                    tf = ispref(char(group), char(name));
                end
                return
            end
            S = AppPrefs.loadStore(file);
            g = char(group);
            tf = isfield(S, g);
            if tf && ~ismissing(name)
                tf = isfield(S.(g), char(name));
            end
        end

        function v = getpref(group, name)
            %getpref  The value of preference NAME of GROUP, or the whole group.
            %   An error (AppPrefs:NoPreference) when it does not exist; a
            %   group that does not exist gives struct().
            arguments
                group (1,1) string
                name (1,1) string = missing
            end
            file = AppPrefs.storeFile();
            if file == ""
                if ismissing(name)
                    if ispref(char(group)); v = getpref(char(group)); else; v = struct(); end
                else
                    v = getpref(char(group), char(name));
                end
                return
            end
            S = AppPrefs.loadStore(file);
            g = char(group);
            if ismissing(name)
                v = struct();
                if isfield(S, g); v = S.(g); end
                return
            end
            n = char(name);
            if ~isfield(S, g) || ~isfield(S.(g), n)
                error('AppPrefs:NoPreference', 'Preference "%s" of group "%s" does not exist.', n, g);
            end
            v = S.(g).(n);
        end

        function setpref(group, name, value)
            %setpref  Set preference NAME of GROUP to VALUE.
            arguments
                group (1,1) string
                name (1,1) string
                value
            end
            file = AppPrefs.storeFile();
            if file == ""
                setpref(char(group), char(name), value);
                return
            end
            S = AppPrefs.loadStore(file);
            g = char(group);
            if ~isfield(S, g); S.(g) = struct(); end
            S.(g).(char(name)) = value;
            AppPrefs.saveStore(file, S);
        end

        function rmpref(group, name)
            %rmpref  Remove preference NAME of GROUP, or the whole group.
            %   Nothing happens when it does not exist.
            arguments
                group (1,1) string
                name (1,1) string = missing
            end
            file = AppPrefs.storeFile();
            if file == ""
                if ismissing(name)
                    if ispref(char(group)); rmpref(char(group)); end
                elseif ispref(char(group), char(name))
                    rmpref(char(group), char(name));
                end
                return
            end
            S = AppPrefs.loadStore(file);
            g = char(group);
            if ~isfield(S, g); return; end
            if ismissing(name)
                S = rmfield(S, g);
            elseif isfield(S.(g), char(name))
                S.(g) = rmfield(S.(g), char(name));
            else
                return
            end
            AppPrefs.saveStore(file, S);
        end

        function file = storeFile()
            %storeFile  The file the preferences live in, "" for MATLAB's preferences.
            file = string(getenv(AppPrefs.EnvVar));
        end

        function useFile(file)
            %useFile  Keep every app's preferences in FILE from now on ("" = MATLAB's).
            arguments
                file (1,1) string
            end
            setenv(AppPrefs.EnvVar, char(file));
        end

        function restore = useTemporary()
            %useTemporary  Use a new, empty preference file until RESTORE is cleared.
            %   RESTORE is an onCleanup object: clearing or deleting it deletes
            %   the file and puts back the store that was in use before
            %   (MATLAB's preferences, or another file).
            previous = AppPrefs.storeFile();
            file = string(tempname) + "_app_prefs.mat";
            AppPrefs.useFile(file);
            restore = onCleanup(@() AppPrefs.endTemporary(file, previous));
        end
    end

    methods (Static, Hidden)
        function endTemporary(file, previous)
            %endTemporary  Delete the temporary file and restore the previous store.
            if isfile(file)
                delete(file);
            end
            AppPrefs.useFile(previous);
        end
    end

    methods (Static, Access = private)
        function S = loadStore(file)
            S = struct();
            if ~isfile(file); return; end
            L = load(file, 'prefs');
            if isfield(L, 'prefs') && isstruct(L.prefs) && isscalar(L.prefs)
                S = L.prefs;
            end
        end

        function saveStore(file, S)
            prefs = S; %#ok<NASGU> saved by name
            save(file, 'prefs');
        end
    end
end
