function log(obj, fmt, varargin)
%log  Send one formatted line to LogFcn (nothing when LogFcn is []).
if isempty(obj.LogFcn); return; end
obj.LogFcn(string(sprintf(fmt, varargin{:})));
end
