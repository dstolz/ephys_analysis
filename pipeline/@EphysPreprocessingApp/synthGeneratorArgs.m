function [args, acq] = synthGeneratorArgs(obj)
%synthGeneratorArgs  The makeSyntheticRecording options the Synthetic tab describes.
%   [ARGS, ACQ] = app.synthGeneratorArgs() is the name-value list Preview
%   (with PreviewOnly) and Generate both pass, so the preview is what is
%   written, and the recording's start time ACQ (the dataset's; for the
%   built-in task two minutes ago, rounded to the second), which also names
%   the folder. A dataset source must be loaded (SynthSource).
mode = string(obj.SynthSourceDropDown.Value);
args = {'Subject', string(strtrim(obj.SynthSubjectField.Value)), 'Design', obj.gatherSynthDesign(), ...
    'Format', string(obj.SynthFormatDropDown.Value), 'Fs', obj.SynthFsField.Value, ...
    'NumChannels', obj.SynthChannelsField.Value, 'FileSeconds', obj.SynthFileSecondsField.Value, ...
    'Seed', obj.SynthSeedField.Value, 'SortedOutput', obj.SynthSortedCheckBox.Value, ...
    'Artifacts', obj.SynthArtifactsCheckBox.Value, 'WriteProbe', true};
acq = dateshift(datetime('now') - minutes(2), 'start', 'second');
if mode == "task"
    args = [args, {'NumTrials', obj.SynthTrialsSpinner.Value, 'Scenario', string(obj.SynthScenarioDropDown.Value)}];
else
    S = obj.SynthSource;
    if isempty(S)
        error('EphysPreprocessingApp:SynthNoSource', 'Load the source first.');
    end
    if ~isnat(S.acqTime); acq = S.acqTime; end
    args = [args, {'Session', S}];
    if obj.SynthMaxDurField.Value > 0
        args = [args, {'MaxDuration', obj.SynthMaxDurField.Value}];
    end
end
acq.Format = 'default';
args = [args, {'AcqTime', acq}];
end
