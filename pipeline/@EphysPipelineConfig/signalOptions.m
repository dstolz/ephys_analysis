function s = signalOptions(cfg, opts)
%signalOptions  Signals section -> EphysDataset.deriveSignals / toMat options.
%   S = EphysPipelineConfig.signalOptions(cfg.Signals) returns the struct
%   passed to toMat as SignalOptions. Only the options relevant to the ticked
%   signals are set; everything else stays at deriveSignals' defaults.
%
%   KeepChannels, BadList and the manifest exclusions are recording channels
%   (1-based, in header order); ChannelRemap indexes the kept channels.
%   deriveSignals takes bad channels as columns of the kept data, so the bad
%   list and the "interpolate" exclusions are mapped to the column(s) holding
%   each channel; a channel that is not kept has no column and is left out.
%
%   Options
%     ExcludeChannels  the dataset's manifest exclusions (1-based), applied
%                      per Signals.ExcludeHandling:
%                        "none"        ignored (default)
%                        "drop"        removed from the kept channels
%                        "interpolate" added to the bad channels
%     NumChannels      the recording's channel count (needed by "drop" when
%                      no explicit keep list is given)
%
%   Error identifiers (EphysPipelineConfig:Signals*): NoSignals, BadList,
%   AutoBadNeedsLFP, BadThreshold, LFPNyquist, LFPNotch, Band, IndexList,
%   FreqList, BadSuffix, ExcludeHandling.
%
%   See also EphysDataset.deriveSignals, EphysDataset.toMat.

arguments
    cfg (1,1) struct
    opts.ExcludeChannels (1,:) double = []
    opts.NumChannels (1,1) double = NaN
end

cfg = EphysPipelineConfig.normalizeSection("Signals", cfg);
types = ["LFP" "MUA" "SPIKE" "AUX"];
sel = [cfg.LFP cfg.MUA cfg.SPIKE cfg.AUX];
if ~any(sel)
    error('EphysPipelineConfig:SignalsNoSignals', ...
        'Tick at least one signal to compute (LFP, MUA, SPIKE or AUX).');
end
EphysPipelineConfig.validateSuffix(cfg.Suffix);

s = struct();
s.dataTypeOut = types(sel);
s.labelField  = string(cfg.LabelField);
if ~isempty(cfg.LineNames)
    s.lineNames = cfg.LineNames;
end
if ~isempty(cfg.InvertedLines)
    s.invertedLines = cfg.InvertedLines;
end

keep = EphysPipelineConfig.parseOrderedList(cfg.KeepChannels, "Keep amp channels");
excl = opts.ExcludeChannels(:).';
switch cfg.ExcludeHandling
    case "none"
    case "drop"
        if ~isempty(excl)
            if isempty(keep)
                if isnan(opts.NumChannels)
                    error('EphysPipelineConfig:SignalsExcludeHandling', ...
                        'ExcludeHandling="drop" needs the channel count (NumChannels) when no keep list is given.');
                end
                keep = 1:opts.NumChannels;
            end
            keep = keep(~ismember(keep, excl));
            if isempty(keep)
                error('EphysPipelineConfig:SignalsExcludeHandling', ...
                    'Dropping the excluded channels leaves no channel to convert.');
            end
        end
    case "interpolate"
        % handled below with the bad-channel list
    otherwise
        error('EphysPipelineConfig:SignalsExcludeHandling', ...
            'Unknown ExcludeHandling "%s".', cfg.ExcludeHandling);
end
if ~isempty(keep)
    s.keepAmpChannels = keep;
end

switch string(cfg.BadMode)
    case "manual"
        bad = EphysPipelineConfig.parseOrderedList(cfg.BadList, "Bad channel list");
        if isempty(bad)
            error('EphysPipelineConfig:SignalsBadList', ...
                'Bad channels is set to "Manual list" but the list is empty.');
        end
        s.badChannels = keptColumns(bad, keep);
    case "auto"
        if ~cfg.LFP
            error('EphysPipelineConfig:SignalsAutoBadNeedsLFP', ...
                'Automatic bad-channel detection is computed from the LFP; tick LFP.');
        end
        if ~(cfg.BadThreshold > 0)
            error('EphysPipelineConfig:SignalsBadThreshold', ...
                'The |z(RMS)| threshold must be greater than 0.');
        end
        s.badChannels = -abs(cfg.BadThreshold);   % negative = auto
    otherwise
        % "none"
end
if cfg.ExcludeHandling == "interpolate" && ~isempty(excl)
    if isfield(s, 'badChannels') && all(s.badChannels > 0)
        s.badChannels = union(s.badChannels, keptColumns(excl, keep));
    elseif ~isfield(s, 'badChannels')
        s.badChannels = keptColumns(excl, keep);
    else
        error('EphysPipelineConfig:SignalsExcludeHandling', ...
            'ExcludeHandling="interpolate" cannot be combined with automatic bad-channel detection.');
    end
end
if isfield(s, 'badChannels') && isempty(s.badChannels)
    s = rmfield(s, 'badChannels');   % none of the bad channels is kept
end

remap = EphysPipelineConfig.parseOrderedList(cfg.ChannelRemap, "Channel remap");
if ~isempty(remap)
    s.channelRemap = remap;
end

if cfg.LFP
    s.LFP_Fs = cfg.LFP_Fs;
    nyq = cfg.LFP_Fs / 2;
    lohi = [0 Inf];
    if cfg.LFP_HighpassOn; lohi(1) = cfg.LFP_HighpassHz; end
    if cfg.LFP_LowpassOn;  lohi(2) = cfg.LFP_LowpassHz;  end
    if cfg.LFP_HighpassOn || cfg.LFP_LowpassOn
        checkBand(lohi, "LFP high-pass / low-pass");
        if lohi(1) >= nyq || (isfinite(lohi(2)) && lohi(2) >= nyq)
            error('EphysPipelineConfig:SignalsLFPNyquist', ...
                'LFP filter cut-offs must be below LFP_Fs / 2 (%g Hz).', nyq);
        end
        s.LFP_bpLoHi = lohi;
    end
    if cfg.LFP_NotchOn
        f0 = EphysPipelineConfig.parseFreqList(cfg.LFP_NotchHz, "LFP notch");
        if isempty(f0)
            error('EphysPipelineConfig:SignalsLFPNotch', ...
                'LFP notch is ticked but no frequency is given.');
        end
        bw = cfg.LFP_NotchBW;
        bad = f0(f0 - bw/2 <= 0 | f0 + bw/2 >= nyq);
        if ~isempty(bad)
            error('EphysPipelineConfig:SignalsLFPNotch', ...
                ['LFP notch %s Hz with width %g Hz does not fit inside ' ...
                 '(0, LFP_Fs / 2 = %g Hz).'], mat2str(bad), bw, nyq);
        end
        s.LFP_NotchHz = f0;
        s.LFP_NotchBW = bw;
    end
end
if cfg.MUA
    checkBand(cfg.MUA_bpLoHi, "MUA bandpass");
    s.MUA_Fs            = cfg.MUA_Fs;
    s.MUA_IntegrationHz = cfg.MUA_IntegrationHz;
    s.MUA_bpLoHi        = cfg.MUA_bpLoHi;
end
if cfg.SPIKE
    checkBand(cfg.SPIKE_bpLoHi, "SPIKE bandpass");
    if cfg.SPIKE_KeepOriginal
        s.SPIKE_Fs = Inf;
    else
        s.SPIKE_Fs = cfg.SPIKE_Fs;
    end
    s.SPIKE_bpLoHi = cfg.SPIKE_bpLoHi;
end
end


function checkBand(lohi, what)
if ~(lohi(1) < lohi(2))
    error('EphysPipelineConfig:SignalsBand', ...
        '%s: low edge (%g Hz) must be below the high edge (%g Hz).', what, lohi(1), lohi(2));
end
end


function cols = keptColumns(ch, keep)
%keptColumns  Columns of the kept data holding recording channels CH.
%   Without a keep list column c is channel c; otherwise every column whose
%   kept channel is in CH (a channel kept twice has two), ascending.
if isempty(keep)
    cols = unique(ch(:).');
else
    cols = find(ismember(keep, ch));
end
end
