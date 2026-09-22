function makePhyFixture(dir0, fs, opts)
%makePhyFixture  Write a small Kilosort4/phy results folder (test fixture).
%   makePhyFixture(dir0, fs, ChannelMap=[0 1 2 3], NChan=4, SettingsJson=true,
%                  ClusterIds=[0 1 2], Shanks=zeros(1,NChan), Positions=[])
%   Three clusters: 0 (good, spikes at 300/600/30000), 1 (mua, 900/1500),
%   2 (noise, 45000). cluster_group.tsv labels them good/mua/noise while
%   cluster_KSLabel.tsv says mua/good/good (so curation must win). Templates
%   [3 x 8 x NChan] put cluster 0's peak on sorted channel 2, cluster 1's on
%   the last channel, cluster 2's on channel 1; amplitudes give cluster 0 a
%   median of 1.5 and cluster 1 a median of 2. SettingsJson=true adds a
%   settings.json, as a runKilosort run folder has.
%   ClusterIds renames the three clusters in spike_clusters.npy and both .tsv
%   files (spike_templates.npy keeps 0..2). Shanks writes channel_shanks.npy;
%   Positions ([NChan x 2], um) writes channel_positions.npy (none when empty).
%
%   See also EphysDataset.readPhyUnits, writeNPY.
arguments
    dir0 (1,1) string
    fs (1,1) double
    opts.ChannelMap (1,:) double = [0 1 2 3]
    opts.NChan (1,1) double = 4
    opts.SettingsJson (1,1) logical = true
    opts.ClusterIds (1,3) double = [0 1 2]
    opts.Shanks (1,:) double = []
    opts.Positions (:,2) double = zeros(0, 2)
end
if ~isfolder(dir0); mkdir(dir0); end
nC = opts.NChan;
samples   = int64([300; 600; 900; 1500; 30000; 45000]);
templates = int32([0; 0; 1; 1; 0; 2]);
clusters  = int32(opts.ClusterIds(double(templates) + 1)).';
amps      = [1; 1.5; 2; 2; 3; 1];
writeNPY(fullfile(dir0, 'spike_times.npy'), samples);
writeNPY(fullfile(dir0, 'spike_clusters.npy'), clusters);
writeNPY(fullfile(dir0, 'spike_templates.npy'), templates);
writeNPY(fullfile(dir0, 'amplitudes.npy'), amps);
T = zeros(3, 8, nC);
T(1, 3, 2)  = -50;  T(1, 5, 2)  = 20;
T(2, 3, nC) = -80;  T(2, 6, nC) = 30;
T(3, 4, 1)  = -10;
writeNPY(fullfile(dir0, 'templates.npy'), single(T));
writeNPY(fullfile(dir0, 'channel_map.npy'), int32(opts.ChannelMap(:)));
shanks = opts.Shanks;
if isempty(shanks); shanks = zeros(1, nC); end
writeNPY(fullfile(dir0, 'channel_shanks.npy'), int32(shanks(:)));
if ~isempty(opts.Positions)
    writeNPY(fullfile(dir0, 'channel_positions.npy'), double(opts.Positions));
end
fid = fopen(fullfile(dir0, 'params.py'), 'w');
fprintf(fid, 'dat_path = "x.bin"\nn_channels_dat = %d\ndtype = "int16"\nsample_rate = %g.\n', nC, fs);
fclose(fid);
fid = fopen(fullfile(dir0, 'cluster_group.tsv'), 'w');
fprintf(fid, 'cluster_id\tgroup\n%d\tgood\n%d\tmua\n%d\tnoise\n', opts.ClusterIds);
fclose(fid);
fid = fopen(fullfile(dir0, 'cluster_KSLabel.tsv'), 'w');
fprintf(fid, 'cluster_id\tKSLabel\n%d\tmua\n%d\tgood\n%d\tgood\n', opts.ClusterIds);
fclose(fid);
if opts.SettingsJson
    writeJsonFile(fullfile(dir0, 'settings.json'), struct('n_chan_bin', nC, 'fs', fs));
end
end
