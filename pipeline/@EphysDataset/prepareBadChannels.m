function [tf, info] = prepareBadChannels(obj)
%prepareBadChannels  Settle the bad channels before any step reads the recording.
%   TF = ds.prepareBadChannels() does nothing unless
%   ArtifactConfig.ExcludeBadChannels is on and BadChannels was never set
%   (BadChannelsSource ""). Then it takes the channels the noise-floor rule
%   of the common reference finds (suggestReferenceExclude: a noise floor
%   outside ReferenceBadLow-ReferenceBadHigh times the median across the
%   channels, Ludwig et al. 2009), counting only ExcludeChannels as
%   already out, marks them "suggested" and writes the manifest so the
%   choice can be reviewed (Artifacts tab). TF is true when it did so, and
%   INFO is suggestReferenceExclude's (empty otherwise).
%
%   prepareReference calls it first, so every streaming entry point
%   (toBin, artifact detection, noise levels, spike detection) and
%   deriveSignals settle the bad channels before they read, whatever the
%   reference; the pipeline also calls it before it picks the channels of
%   the Signals and Spikes steps and of the sorter. A dataset whose
%   recording is not there (hasRecording false) is left as it is.
%
%   A suggestion that would leave fewer than MinReferenceChannels (5)
%   channels is not applied: it warns
%   (EphysDataset:prepareBadChannels:SuggestionNotApplied) and leaves none
%   out, still marked "suggested" so it is not worked out again on every
%   read. Set BadChannels by hand then.
%
%   See also EphysDataset.excludedChannels, EphysDataset.suggestReferenceExclude.

arguments
    obj (1,1) EphysDataset
end

tf = false;
info = [];
if ~EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig).ExcludeBadChannels ...
        || obj.BadChannelsSource ~= "" || ~obj.hasRecording()
    return
end
[bad, info] = obj.suggestReferenceExclude(Excluded=obj.ExcludeChannels);
nLeft = numel(setdiff(1:numel(info.sigma), [obj.ExcludeChannels, bad]));
if ~isempty(bad) && nLeft < EphysDataset.MinReferenceChannels
    warning('EphysDataset:prepareBadChannels:SuggestionNotApplied', ...
        ['The suggested bad channels (%s) would leave %d channel(s) of %s (fewer than %d), ' ...
         'so none is left out: %s. Set BadChannels by hand.'], ...
        char(EphysDataset.formatChannelList(bad)), nLeft, obj.Name, ...
        EphysDataset.MinReferenceChannels, info.summary);
    bad = double.empty(1, 0);
end
obj.BadChannels = bad;
obj.BadChannelsSource = "suggested";
fprintf('Bad channels of %s: %s.\n', obj.Name, info.summary);
obj.writeManifest();
tf = true;
end
