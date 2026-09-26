function m = onOpenChannelMapper(obj)
%onOpenChannelMapper  Open the channel mapper (probe sites -> headstage channels).
%   Launches ChannelMapperApp with this app as its parent: it exports the
%   Kilosort4 probe .json into the probe folder (and refreshes the probe
%   list), takes recording rows from the project's datasets (starting with
%   the active one, when it has its channel numbers) and fetches
%   probeinterface geometry with this app's Python. Nothing is written
%   into the config.
%
%   M = obj.onOpenChannelMapper() also returns the mapper.
%
%   See also ChannelMapperApp, EphysPreprocessingApp.onDesignProbe.

d = obj.currentDataset();
m = ChannelMapperApp(obj, Dataset=d);
if nargout == 0
    clear m
end
end
