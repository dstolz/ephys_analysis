classdef LabDB < handle
    % LabDB  The lab database (CarasLabDB) as the apps use it: optional, and never in the way.
    %   The toolbox records its work in the lab's database when it is set up
    %   (LabDBSettings) and reachable, and works exactly as before when it
    %   is not: nothing the apps or the pipeline do waits for the server or
    %   fails because of it. One LabDB object per MATLAB keeps the
    %   connection and what is known about the server:
    %
    %     b = LabDB.connect()        % the open backend, or [] (never an error)
    %     st = LabDB.status()        % State, Message, Since, NextTry
    %     LabDB.disconnect()
    %     d = LabDB.folder()         % this computer's database folder (cache, outbox)
    %
    %   State is one of
    %     "off"        not set up, or turned off, on this computer
    %     "connected"  the connection is open
    %     "offline"    the server did not answer; LabDB.connect tries again
    %                  after a pause that grows with each failure (5 s, 10 s,
    %                  ... up to 5 minutes; Force=true tries at once)
    %     "attention"  the server answered but something must be fixed here
    %                  (no password stored, the login refused, CarasLabDB or
    %                  the Database Toolbox missing): Message says what
    %
    %   Before opening a connection it checks that the server accepts one
    %   (a TCP probe bounded by ConnectTimeout, or MaxWait seconds when that
    %   is shorter: LabSync's ticks wait 2 s at most), so an unreachable
    %   server costs a few seconds once, not a hung window. Listen to the
    %   event StateChanged of LabDB.instance() to follow the state, and
    %   OutboxChanged to follow what waits to be sent (LabDBLamp).
    %   LabDB.lost(message) says a connection broke while it was used: it is
    %   closed, and the next try waits as after a failed one.
    %
    %   The folder is %LOCALAPPDATA%\ephys_analysis\labdb (tempdir without
    %   LOCALAPPDATA) or the one EPHYS_LABDB_DIR names; useTemporary() points
    %   it at a new folder until the object it returns is cleared, and
    %   useBackend(factory) makes LabDB use another backend (tests:
    %   LabDBFakeBackend) until the object it returns is cleared.
    %
    %   See also LabDBSettings, LabDBSecrets, LabDBBackend, LabDBLamp, LabDBPanel.

    events
        StateChanged
        OutboxChanged
    end

    properties (Constant)
        EnvVar = "EPHYS_LABDB_DIR"
        MaxPause = 300      % seconds between tries at most, while offline
    end

    properties (SetAccess = private)
        State (1,1) string = "off"
        Message (1,1) string = "The lab database is not set up on this computer."
        Since (1,1) datetime = NaT
        NextTry (1,1) datetime = NaT
        Failures (1,1) double = 0
        Backend = []
        Factory = []        % function handle making the backend ([] = LabDBCarasBackend)
    end

    methods (Static)
        function db = instance()
            %instance  The one LabDB object of this MATLAB.
            persistent single
            if isempty(single) || ~isvalid(single)
                single = LabDB();
            end
            db = single;
        end

        function b = connect(opts)
            %connect  The open backend, or [] when the database is off or out of reach.
            %   Never an error: why there is none is in status(). While
            %   offline, a new try waits for NextTry unless Force=true.
            %   MaxWait (seconds) bounds the wait for the server's answer.
            arguments
                opts.Force (1,1) logical = false
                opts.MaxWait (1,1) double {mustBePositive} = Inf
            end
            b = LabDB.instance().tryConnect(opts.Force, opts.MaxWait);
        end

        function lost(message)
            %lost  The connection broke while it was used: close it; the next try waits.
            db = LabDB.instance();
            db.closeBackend();
            db.failed("offline", "The lab database stopped answering: " + string(message) + ...
                ". The apps keep working; what they record is kept here and sent later.");
        end

        function outboxChanged()
            %outboxChanged  Tell the listeners (the lamps, the Database window) that the outbox changed.
            notify(LabDB.instance(), "OutboxChanged");
        end

        function st = status()
            %status  State, Message, Since and NextTry, as a struct.
            db = LabDB.instance();
            st = struct("State", db.State, "Message", db.Message, "Since", db.Since, ...
                "NextTry", db.NextTry);
        end

        function disconnect()
            %disconnect  Close the connection (the state goes back to what the settings say).
            db = LabDB.instance();
            db.closeBackend();
            db.settle();
        end

        function tf = enabled()
            %enabled  True when the database is set up and turned on for this computer.
            tf = LabDBSettings.isConfigured(LabDBSettings.load());
        end

        function d = folder()
            %folder  This computer's database folder (created when missing).
            d = string(getenv(LabDB.EnvVar));
            if d == ""
                base = string(getenv("LOCALAPPDATA"));
                if base == ""
                    base = string(tempdir);
                end
                d = string(fullfile(base, "ephys_analysis", "labdb"));
            end
            if ~isfolder(d)
                mkdir(d);
            end
        end

        function restore = useTemporary()
            %useTemporary  A new, empty database folder until RESTORE is cleared (deleted then).
            previous = string(getenv(LabDB.EnvVar));
            d = string(tempname);
            mkdir(d);
            setenv(LabDB.EnvVar, char(d));
            restore = onCleanup(@() LabDB.endTemporary(previous, d));
        end

        function restore = useBackend(factory)
            %useBackend  Make the backend with FACTORY (a function handle) until RESTORE is cleared.
            arguments
                factory (1,1) function_handle
            end
            db = LabDB.instance();
            previous = db.Factory;
            db.closeBackend();
            db.Factory = factory;
            db.Failures = 0;
            db.NextTry = NaT;
            db.settle();
            restore = onCleanup(@() LabDB.endBackend(previous));
        end
    end

    methods (Access = private)
        function obj = LabDB()
            obj.settle();
        end

        function b = tryConnect(obj, force, maxWait)
            b = [];
            s = LabDBSettings.load();
            if isfinite(maxWait)
                s.ConnectTimeout = max(2, min(s.ConnectTimeout, maxWait));   % libpq waits 2 s at least
            end
            if ~LabDBSettings.isConfigured(s)
                obj.closeBackend();
                obj.setState("off", LabDB.offMessage(s));
                return
            end
            if ~isempty(obj.Backend) && obj.Backend.isOpen()
                b = obj.Backend;
                if obj.State ~= "connected"
                    obj.setState("connected", "Connected to " + LabDB.where(s) + ".");
                end
                return
            end
            if ~force && obj.Failures > 0 && ~isnat(obj.NextTry) && ...
                    datetime("now", "TimeZone", "local") < obj.NextTry
                return
            end
            if isempty(obj.Backend)
                obj.Backend = obj.makeBackend();
            end
            [ok, why] = obj.Backend.probe(s);
            if ~ok
                obj.failed("offline", "The lab database is out of reach: " + why + ...
                    ". The apps keep working; what they record is kept here and sent later.");
                return
            end
            try
                pw = LabDBSecrets.get(s);
            catch ME
                obj.failed("attention", string(ME.message));
                return
            end
            try
                obj.Backend.open(s, pw);
            catch ME
                if endsWith(string(ME.identifier), ":Unreachable")
                    obj.failed("offline", "The lab database did not answer: " + ...
                        string(ME.message));
                else
                    obj.failed("attention", "The lab database refused the connection: " + ...
                        string(ME.message));
                end
                return
            end
            obj.Failures = 0;
            obj.NextTry = NaT;
            obj.setState("connected", "Connected to " + LabDB.where(s) + ".");
            b = obj.Backend;
        end

        function b = makeBackend(obj)
            if isempty(obj.Factory)
                b = LabDBCarasBackend();
            else
                b = obj.Factory();
            end
        end

        function failed(obj, state, message)
            obj.Failures = obj.Failures + 1;
            pause = min(LabDB.MaxPause, 5 * 2^(obj.Failures - 1));
            obj.NextTry = datetime("now", "TimeZone", "local") + seconds(pause);
            obj.setState(state, message);
        end

        function closeBackend(obj)
            if ~isempty(obj.Backend)
                try
                    obj.Backend.close();
                catch
                end
            end
            obj.Backend = [];
        end

        function settle(obj)
            %settle  The state the settings alone give (off, or offline until a try).
            s = LabDBSettings.load();
            if LabDBSettings.isConfigured(s)
                obj.setState("offline", "Not connected yet: the lab database is tried " + ...
                    "when there is something to send or look up.");
            else
                obj.setState("off", LabDB.offMessage(s));
            end
        end

        function setState(obj, state, message)
            changed = obj.State ~= state || obj.Message ~= message;
            obj.State = state;
            obj.Message = message;
            if changed
                obj.Since = datetime("now", "TimeZone", "local");
                notify(obj, "StateChanged");
            end
        end
    end

    methods (Static, Access = private)
        function m = offMessage(s)
            if ~s.Enabled
                m = "The lab database is turned off on this computer (File > Database...).";
            else
                m = "The lab database is not set up: name the server, the database and " + ...
                    "your login (File > Database...).";
            end
        end

        function w = where(s)
            w = s.DatabaseName + " on " + s.Server + ":" + string(s.Port) + " as " + s.Username;
        end

        function endTemporary(previous, d)
            setenv(LabDB.EnvVar, char(previous));
            if isfolder(d)
                try
                    rmdir(d, "s");
                catch
                end
            end
        end

        function endBackend(previous)
            db = LabDB.instance();
            db.closeBackend();
            db.Factory = previous;
            db.Failures = 0;
            db.NextTry = NaT;
            db.settle();
        end
    end
end
