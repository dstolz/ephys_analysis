classdef LabDBSecrets
    % LabDBSecrets  The lab database password, kept in the MATLAB vault, never in a file.
    %   The password of your database login is stored with MATLAB's own
    %   secret store (setSecret / getSecret, MATLAB R2024a or later), under a
    %   name that says which login and server it is for:
    %
    %     name = LabDBSecrets.secretName(s)   % "CarasLabDB:<user>@<server>:<port>/<db>"
    %     LabDBSecrets.prompt(s)              % MATLAB's own dialog asks for it (setSecret)
    %     tf = LabDBSecrets.has(s)
    %     pw = LabDBSecrets.get(s)            % LabDBSecrets:None when there is none
    %     LabDBSecrets.remove(s)
    %
    %   S is the LabDBSettings struct. The password is never written to the
    %   preferences, a config, a script, a manifest or the outbox, and the
    %   apps never see it typed: setSecret's dialog takes it.
    %
    %   Tests do not touch the vault: useFake() keeps secrets in memory until
    %   the object it returns is cleared.
    %
    %     restore = LabDBSecrets.useFake();
    %     LabDBSecrets.setFake(s, "pw")
    %
    %   See also LabDBSettings, LabDB, setSecret, getSecret.

    methods (Static)
        function name = secretName(s)
            %secretName  The vault name of the password for settings S.
            name = "CarasLabDB:" + s.Username + "@" + s.Server + ":" + string(s.Port) + ...
                "/" + s.DatabaseName;
        end

        function tf = available()
            %available  True when this MATLAB has the vault (R2024a or later), or a fake is in use.
            tf = LabDBSecrets.fake().Active || exist("getSecret", "file") > 0 ...
                || exist("getSecret", "builtin") > 0;
        end

        function tf = has(s)
            %has  True when a password for settings S is stored.
            name = LabDBSecrets.secretName(s);
            f = LabDBSecrets.fake();
            if f.Active
                tf = isKey(f.Map, char(name));
                return
            end
            tf = false;
            if ~LabDBSecrets.available(); return; end
            try
                tf = isSecret(char(name));
            catch
            end
        end

        function pw = get(s)
            %get  The stored password for settings S (LabDBSecrets:None when there is none).
            name = LabDBSecrets.secretName(s);
            f = LabDBSecrets.fake();
            if f.Active
                if ~isKey(f.Map, char(name))
                    error("LabDBSecrets:None", "No password is stored for %s.", name);
                end
                pw = string(f.Map(char(name)));
                return
            end
            if ~LabDBSecrets.available()
                error("LabDBSecrets:NoVault", ...
                    "This MATLAB has no secret vault (getSecret needs R2024a or later).");
            end
            if ~LabDBSecrets.has(s)
                error("LabDBSecrets:None", ...
                    "No password is stored for %s: set it in the Database window.", name);
            end
            pw = string(getSecret(char(name)));
        end

        function prompt(s)
            %prompt  Ask for the password with MATLAB's own dialog and store it (setSecret).
            name = LabDBSecrets.secretName(s);
            if LabDBSecrets.fake().Active
                error("LabDBSecrets:Fake", "The fake vault in use cannot prompt.");
            end
            if ~LabDBSecrets.available()
                error("LabDBSecrets:NoVault", ...
                    "This MATLAB has no secret vault (setSecret needs R2024a or later).");
            end
            setSecret(char(name), "Overwrite", true);
        end

        function remove(s)
            %remove  Remove the stored password for settings S, if there is one.
            name = LabDBSecrets.secretName(s);
            f = LabDBSecrets.fake();
            if f.Active
                if isKey(f.Map, char(name)); remove(f.Map, char(name)); end
                return
            end
            if LabDBSecrets.has(s)
                removeSecret(char(name));
            end
        end

        function restore = useFake()
            %useFake  Keep secrets in memory, not the vault, until RESTORE is cleared.
            f = LabDBSecrets.fake();
            was = f.Active;
            old = f.Map;
            f.Active = true;
            f.Map = containers.Map();
            restore = onCleanup(@() LabDBSecrets.endFake(was, old));
        end

        function setFake(s, password)
            %setFake  Store PASSWORD for settings S in the fake vault (tests only).
            f = LabDBSecrets.fake();
            if ~f.Active
                error("LabDBSecrets:NotFake", "setFake works only after useFake.");
            end
            f.Map(char(LabDBSecrets.secretName(s))) = char(password);
        end
    end

    methods (Static, Access = private)
        function f = fake()
            %fake  The in-memory vault of the tests (a handle kept for the session).
            persistent store
            if isempty(store)
                store = LabDBFakeVault();
            end
            f = store;
        end

        function endFake(was, old)
            f = LabDBSecrets.fake();
            f.Active = was;
            f.Map = old;
        end
    end
end
