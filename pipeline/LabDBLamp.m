classdef LabDBLamp < handle
    % LabDBLamp  The lab database's state in an app's status bar; a click opens the Database window.
    %   lamp = LabDBLamp(grid, Row=1, Column=3, Parent=fig)
    %   puts a small button in cell (Row, Column) of the uigridlayout GRID.
    %   It shows LabDB's state and follows it (the StateChanged event):
    %
    %     Database: off          not set up or turned off here (grey)
    %     Database: connected    (green)
    %     Database: offline      the server is out of reach; the apps keep
    %                            working and what they record waits here (orange)
    %     Database: attention    something on this computer must be fixed (red)
    %
    %   The tooltip says why. Clicking opens LabDBPanel over PARENT.
    %
    %   See also LabDB, LabDBPanel.

    properties (SetAccess = private)
        Button = []
        Parent = []
    end

    properties (Access = private)
        Listener = []
    end

    methods
        function obj = LabDBLamp(grid, opts)
            arguments
                grid
                opts.Row (1,1) double = 1
                opts.Column (1,1) double = 1
                opts.Parent = []
            end
            obj.Parent = opts.Parent;
            obj.Button = uibutton(grid, "Text", "Database: off", "FontSize", 11, ...
                "Tag", "LabDBLamp", "ButtonPushedFcn", @(~, ~) obj.openPanel());
            obj.Button.Layout.Row = opts.Row;
            obj.Button.Layout.Column = opts.Column;
            obj.Listener = listener(LabDB.instance(), "StateChanged", @(~, ~) obj.refresh());
            addlistener(obj.Button, "ObjectBeingDestroyed", @(~, ~) obj.delete());
            obj.refresh();
        end

        function refresh(obj)
            %refresh  Show LabDB's current state.
            if isempty(obj.Button) || ~isvalid(obj.Button)
                return
            end
            st = LabDB.status();
            [label, color] = LabDBLamp.look(st.State);
            obj.Button.Text = "Database: " + label;
            obj.Button.FontColor = color;
            obj.Button.Tooltip = char(st.Message + " (click for the Database window)");
        end

        function delete(obj)
            if ~isempty(obj.Listener) && isvalid(obj.Listener)
                delete(obj.Listener);
            end
        end
    end

    methods (Static)
        function [label, color] = look(state)
            %look  The lamp's text and colour for STATE.
            switch state
                case "connected"
                    label = "connected"; color = [0.10 0.50 0.20];
                case "offline"
                    label = "offline";   color = [0.75 0.45 0.00];
                case "attention"
                    label = "attention"; color = [0.75 0.10 0.10];
                otherwise
                    label = "off";       color = [0.45 0.45 0.45];
            end
        end
    end

    methods (Access = private)
        function openPanel(obj)
            p = obj.Parent;
            if isempty(p) || ~isvalid(p)
                LabDBPanel.open();
            else
                LabDBPanel.open(Parent=p);
            end
        end
    end
end
