function result = runProbeTool(obj, varargin)
%runProbeTool  probe_tool.py through the parent app, or with the remembered Python.
%   From the pipeline app this is its runProbeTool (the Kilosort
%   tab's Python and conda env). Standalone it runs
%   EphysPipelineApp.runProbeToolWith with the Python the
%   pipeline app last used (its PythonExe preference), and errors
%   ChannelMapperApp:NoPython when there is none.
if ~isempty(obj.App) && isvalid(obj.App)
    result = obj.App.runProbeTool(varargin{:});
    return
end
py = "";
if AppPrefs.ispref('EphysPipelineApp', 'PythonExe')
    py = string(AppPrefs.getpref('EphysPipelineApp', 'PythonExe'));
end
if ~isscalar(py) || py == "" || ~isfile(py)
    error('ChannelMapperApp:NoPython', ['No Python with probeinterface is known. Set the Python exe once on the ' ...
        'pipeline app''s Kilosort tab, or open the mapper from its Probe tab.']);
end
result = EphysPipelineApp.runProbeToolWith(py, "", varargin{:});
end
