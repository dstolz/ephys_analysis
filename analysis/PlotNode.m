classdef (Abstract) PlotNode < handle
    %PlotNode  One object of the command line's tree of an analysis app's figures: the syntax they share.
    %   EphysFigGenApp's Plots (a PlotConsole) is the root of a tree of
    %   objects, each a PlotNode: the console, a figure (PlotFigureNode), a
    %   panel of it (PlotPanelNode) and a part drawn in them (PlotPartNode:
    %   the PSTH line, an x label, the axes). This class gives them one
    %   syntax, so a whole path can be written, read and assigned in one
    %   line:
    %
    %     p = app.Plots;
    %     p.Figure("unit_card").Panel("psth_1").rateFill.FaceColor           % read
    %     p.Figure("unit_card").Panel("psth_1").rateFill.FaceColor = "red";  % assign
    %     p.Figure("unit_card").Panel("psth_1").Settings.options.yLim = [0 50];
    %
    %   A node holds no figure, only where it is: its console and the ids
    %   of its figure and panel, the role and group of its part. What it
    %   names is looked up each time it is used, so a node kept in a
    %   variable follows the app (an edit in the window, an Undo, a figure
    %   renamed), and says so when what it names is gone.
    %
    %   How a path is read (subsref, subsasgn), one step at a time:
    %     .Name(args)   a method of the node (dotMethods: Figure, Panel,
    %                   Part, apply, set, ...), called with the arguments
    %     .Name         a property of the node (dotProperties: Id, Parts,
    %                   Settings, Immediate, ...)
    %     .name         anything else is the node's own (dotOther): a part
    %                   of a figure or panel by its role (.rateFill, .xlabel;
    %                   .rateFill("Go") one group of it), a property of a part
    %                   (.FaceColor)
    %     (args)        on the node itself (parenGet): a part's group
    %   and whatever follows is read on the result. An assignment walks
    %   the same steps to its last one and assigns there (assign): a
    %   property that can be set, a setting under Settings, a part's
    %   property. Every method called with a dot returns one value (a
    %   node, a table), so a path never ends in nothing.
    %
    %   See also PlotConsole, PlotFigureNode, PlotPanelNode, PlotPartNode, EphysFigGenApp.

    properties (SetAccess = protected, Hidden)
        Console = []                    % the PlotConsole at the root (the console: itself)
        FigureId (1,1) string = ""      % the node's figure: its id when the node was made (followed through its renames: PlotConsole.figureAt)
        PanelId (1,1) string = ""       % its panel's id ("" = the whole figure)
        RoleName (1,1) string = ""      % a part's role (PlotAesthetics.roles)
        GroupName (1,1) string = ""     % a part's group ("" = every group)
    end

    methods
        function varargout = subsref(obj, S)
            %subsref  obj.Name, obj.Name(args), obj(args): the node's own step first, then what follows on its result.
            if ~isscalar(obj)
                [varargout{1:max(nargout, 1)}] = builtin('subsref', obj, S);   % an array of nodes: MATLAB's own indexing
                return
            end
            [v, used] = step(obj, S);
            rest = S(used+1:end);
            if isempty(rest)
                varargout{1} = v;
            else
                [varargout{1:max(nargout, 1)}] = subsref(v, rest);
            end
        end

        function obj = subsasgn(obj, S, value)
            %subsasgn  obj.Path = VALUE: the path's steps to its last one, which is assigned (assign).
            if ~isscalar(obj)
                obj = builtin('subsasgn', obj, S, value);
                return
            end
            switch S(1).type
                case '.'
                    name = string(S(1).subs);
                    if assign(obj, name, S(2:end), value); return; end
                    [child, used] = step(obj, S);   % a figure, a panel, a part
                case '()'
                    child = parenGet(obj, S(1).subs);
                    used = 1;
                otherwise
                    error('PlotConsole:BadSyntax', 'Braces are not used here: write node.Name or node.Name(...).');
            end
            rest = S(used+1:end);
            if isempty(rest) || ~isa(child, 'PlotNode')
                error('PlotConsole:ReadOnly', '%s cannot be assigned: assign one of its properties (node.Name = value).', pathText(S(1:used)));
            end
            subsasgn(child, rest, value);
        end

        function n = numArgumentsFromSubscript(~, ~, ~)
            %numArgumentsFromSubscript  A path gives one value, and takes one.
            n = 1;
        end
    end

    methods (Access = protected)
        function obj = PlotNode(console, figureId, panelId, role, group)
            %PlotNode  A node of CONSOLE's tree at figure FIGUREID, panel PANELID, part ROLE, group GROUP ("" each: not that deep).
            if nargin < 1; return; end
            obj.Console = console;
            if nargin > 1; obj.FigureId = figureId; end
            if nargin > 2; obj.PanelId = panelId; end
            if nargin > 3; obj.RoleName = role; end
            if nargin > 4; obj.GroupName = group; end
        end

        function names = dotMethods(~)
            %dotMethods  The methods called with a dot (each returns one value).
            names = strings(1, 0);
        end

        function names = dotProperties(~)
            %dotProperties  The properties read with a dot.
            names = strings(1, 0);
        end

        function names = dotSettable(~)
            %dotSettable  Of dotProperties, those assigned with a dot.
            names = strings(1, 0);
        end

        function [v, usedArgs] = dotOther(obj, name, args, called) %#ok<INUSD,STOUT>
            %dotOther  obj.NAME for a name that is no method or property: the node's own (a part, a part's property).
            %   ARGS are the arguments of a call that follows (CALLED);
            %   USEDARGS says whether they were read.
            error('PlotConsole:NoSuchName', '%s has no "%s".', nodeWord(obj), name);
        end

        function v = parenGet(obj, args) %#ok<INUSD,STOUT>
            %parenGet  obj(ARGS): the node's own (a part's group).
            error('PlotConsole:BadSyntax', '%s takes no index: write its name and a dot (node.Name).', nodeWord(obj));
        end

        function done = assign(obj, name, rest, value)
            %assign  obj.NAME<REST> = VALUE when NAME is the node's to assign; false when NAME is a step on the way (a figure, a panel, a part).
            %   Here: a settable property, alone (REST empty). A property
            %   or method that cannot be assigned is an error
            %   (PlotConsole:ReadOnly). The node classes add their own: a
            %   setting under Settings, a part's property.
            done = false;
            if ~isempty(rest) && ~ismember(name, dotProperties(obj)); return; end   % a step on the way
            if isempty(rest) && ismember(name, dotSettable(obj))
                obj = builtin('subsasgn', obj, substruct('.', char(name)), value); %#ok<NASGU> (a handle: set in place; MATLAB's subsasgn must be called with an output)
                done = true;
            elseif ismember(name, [dotProperties(obj) dotMethods(obj)]) || isprop(obj, name)
                error('PlotConsole:ReadOnly', '%s of %s is read only.', name, nodeWord(obj));
            end
        end

        function s = nodeWord(obj)
            %nodeWord  What the node is, for a message: "the console", "figure unit_card", "panel psth_1", "the PSTH".
            s = "this object";
            if isa(obj, 'PlotConsole'); s = "the console"; end
        end
    end

    methods (Access = private)
        function [v, used] = step(obj, S)
            %step  What the first subscript of S gives on this node; USED subscripts were read (a call's arguments with its name).
            used = 1;
            if ~strcmp(S(1).type, '.')
                if ~strcmp(S(1).type, '()')
                    error('PlotConsole:BadSyntax', 'Braces are not used here: write node.Name or node.Name(...).');
                end
                v = parenGet(obj, S(1).subs);
                return
            end
            name = string(S(1).subs);
            S(1).subs = char(name);   % (a name given as a string, obj.(name))
            called = numel(S) > 1 && strcmp(S(2).type, '()');
            args = {};
            if called; args = S(2).subs; end
            if ismember(name, dotMethods(obj))
                v = feval(char(name), obj, args{:});
                used = 1 + called;
            elseif ismember(name, dotProperties(obj))
                v = builtin('subsref', obj, S(1));
            elseif name == "delete"
                delete(obj);
                v = [];
                used = 1 + called;
            elseif isprop(obj, name) || ismethod(obj, name)   % a handle's own (isvalid, addlistener) and the hidden properties
                v = builtin('subsref', obj, S(1:used + called));
                used = 1 + called;
            else
                [v, usedArgs] = dotOther(obj, name, args, called);
                used = 1 + (called && usedArgs);
            end
        end
    end
end


function s = pathText(S)
%pathText  Subscripts as they were typed, for a message: ".Figure(...)".
s = "";
for k = 1:numel(S)
    if strcmp(S(k).type, '.')
        s = s + "." + string(S(k).subs);
    else
        s = s + "(...)";
    end
end
end
