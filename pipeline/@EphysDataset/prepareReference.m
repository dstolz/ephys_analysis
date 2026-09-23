function tf = prepareReference(obj)
%prepareReference  Settle the channels of the common reference before a read.
%   TF = ds.prepareReference() is called by every streaming entry point
%   (toBin, artifactIntervals, analyzeArtifacts, noiseLevels, detectSpikes)
%   and by deriveSignals
%   before it reads, so a reference is never taken over a channel list that
%   changes mid-run or is worked out again on every parallel worker. When
%   ArtifactConfig.Reference is "car" / "cmr" and ReferenceExclude was never
%   set (ReferenceExcludeSource ""), it takes suggestReferenceExclude's
%   channels, marks them "suggested" and writes the manifest so the choice
%   can be reviewed (Artifacts tab). TF is true when it did so.
%
%   A suggestion that would leave fewer than MinReferenceChannels (5)
%   channels in the reference is not applied: it warns
%   (EphysDataset:prepareReference:SuggestionNotApplied) and leaves no channel
%   out, still marked "suggested" so it is not worked out again on every
%   read. Review the noise floors and set ReferenceExclude by hand then.
%
%   A reference over fewer than MinReferenceChannels (5) channels warns: one
%   large unit can then dominate the average and appear on every channel
%   (Ludwig et al. 2009).
%
%   See also EphysDataset.suggestReferenceExclude, EphysDataset.applyReference.

tf = false;
acfg = EphysDataset.normalizeArtifactConfig(obj.ArtifactConfig);
if string(acfg.Reference) == "none"
    return
end
if obj.ReferenceExcludeSource == ""
    [bad, info] = obj.suggestReferenceExclude();
    nLeft = numel(setdiff(1:numel(info.sigma), [obj.ExcludeChannels, bad]));
    if ~isempty(bad) && nLeft < EphysDataset.MinReferenceChannels
        warning('EphysDataset:prepareReference:SuggestionNotApplied', ...
            ['The suggested channels (%s) would leave %d channel(s) in the common reference ' ...
             'of %s (fewer than %d), so none is left out: %s. Set ReferenceExclude by hand.'], ...
            char(EphysDataset.formatChannelList(bad)), nLeft, obj.Name, ...
            EphysDataset.MinReferenceChannels, info.summary);
        bad = double.empty(1, 0);
    end
    obj.ReferenceExclude = bad;
    obj.ReferenceExcludeSource = "suggested";
    fprintf('Common reference (%s) of %s: %s.\n', upper(acfg.Reference), obj.Name, info.summary);
    obj.writeManifest();
    tf = true;
end
n = numel(obj.referenceChannels());
if n == 0
    error('EphysDataset:applyReference:NoChannels', ...
        'Every channel of %s is left out of the common reference; include at least one.', obj.Name);
elseif n < EphysDataset.MinReferenceChannels
    warning('EphysDataset:prepareReference:FewChannels', ...
        ['The common reference of %s is taken over %d channel(s); with fewer than %d ' ...
         'one large unit can dominate it and appear on every channel.'], ...
        obj.Name, n, EphysDataset.MinReferenceChannels);
end
end
