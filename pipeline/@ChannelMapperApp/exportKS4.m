function [probeFile, sidecar] = exportKS4(obj, file, opts)
%exportKS4  Write the Kilosort4 probe .json and its .chanmap.json sidecar (no dialogs).
%   [PROBEFILE, SIDECAR] = APP.exportKS4(FILE) writes the resolved chain
%   through ChannelMap.exportKS4: sites that reach no recorded channel are
%   left out and named in the notes unless DropUnmapped=false. The
%   sidecar's mapping is named after the file. A parent app lists the new
%   probe (refreshProbeList). Options DropUnmapped, NChan, Notes as
%   ChannelMap.exportKS4.
arguments
    obj
    file (1,1) string
    opts.DropUnmapped (1,1) logical = true
    opts.NChan (1,1) double = NaN
    opts.Notes (1,1) string = ""
end
R = obj.Result;
if isempty(R)
    error('ChannelMapperApp:NoChain', 'Choose a package and a headstage first.');
end
[~, stem] = fileparts(file);
mapping = ChannelMap.mappingStruct(R, Name=stem, Notes=opts.Notes);
[probeFile, sidecar] = ChannelMap.exportKS4(R, file, DropUnmapped=opts.DropUnmapped, NChan=opts.NChan, ...
    Notes=opts.Notes, Mapping=mapping);
if ~isempty(obj.App) && isvalid(obj.App)
    try
        obj.App.refreshProbeList();
        row = find(obj.App.ProbePaths == string(probeFile), 1);
        if ~isempty(row)
            obj.App.selectProbeRow(row);
        end
    catch
        % the file is written; the parent's list refreshes next time
    end
end
nOut = nnz(isnan(R.Table.RecordingRow0) | isnan(R.Table.X));
msg = string(sprintf('Wrote %s (%d sites) and its %s.', probeFile, height(R.Table) - nOut, ChannelMap.SidecarSuffix));
if nOut > 0
    msg = msg + sprintf(' %d site(s) left out: they reach no recorded channel.', nOut);
end
obj.setStatus(msg, false);
end
