# EphysDataset

`EphysDataset` ([source](../pipeline/@EphysDataset/EphysDataset.m)) is a `handle`
class that represents **one recording**: one folder of data recorded
contiguously. It is the core of the pipeline. The project, pipeline, tracker
and GUI classes all act on recordings through it.

The dataset knows nothing about any acquisition system. Reading goes through a
`Reader` ([`EphysReader`](#acquisition-readers)): `IntanReader` for Intan RHD
recordings, `OpenEphysReader` for Open Ephys GUI sessions (Binary, Open Ephys
and NWB formats), `BinaryReader` for the universal `recording.json` format, or
a reader you register. Everything above that layer (artifacts, spike
detection, derived signals, sorting, manifests, exports) works on the same
in-memory schema.

An `EphysDataset` can:

- find the reader that claims the folder and inventory its files;
- parse header metadata cheaply (no amplifier data read);
- read amplifier data, digital-input events and (optionally) board ADC / aux
  input into memory;
- stream the recording one bounded chunk at a time (for `.bin` writing, artifact
  screening and plotting) so peak memory does not scale with recording length;
- filter, screen for artifacts, and blank artifacts;
- detect spikes by voltage thresholding, with waveforms;
- write a Kilosort4 `.bin` file (streaming or in-memory);
- launch Kilosort4, either directly on a `.bin` (`runKilosort`) or through
  SpikeInterface on the raw recording (`runSpikeInterface`, the path the GUI uses);
- keep track of the sorted output (Kilosort4 / phy) that belongs to it and read
  the sorted units through one loader (`readSortedUnits`);
- derive LFP / MUA / spike-band signals and save them to `.mat` (the
  `intan2matlab` processing);
- detect and/or collect spikes into a `.mat` (`spikesToMat`);
- export Chronux- and FieldTrip-shaped files (`exportChronux`, `exportFieldTrip`);
- hold an associated Epsych2 behavior session (`BehaviorFile`, `readBehavior`);
- keep a JSON manifest of its state in the recording folder.

The source recording files are **never modified**. Every write goes to a new
file: `.bin`, JSON sidecar, manifest, Kilosort4 run folder, or `.mat`.

---

## Acquisition readers

`EphysReader` ([source](../pipeline/@EphysReader/EphysReader.m)) is the abstract
contract between an acquisition system and the pipeline. A reader knows one
on-disk format and answers five questions:

| Method | Returns |
| --- | --- |
| `discoverFiles()` | which files in `Folder` make up the recording (`Files`, `NumFiles`, `RecordingFormat`) |
| `refreshMetadata()` | header-only metadata: `Fs`, `NumChannels`, `ChannelNames`, `NativeNames`, `ChannelNumbers`, `DigInNames`, `DigInNativeNames`, `Duration`, `AcqDate`, `PerFile` |
| `streamPlan(Files=, MaxChunkSamples=)` | how to read the recording one bounded chunk at a time (`kind`, `name`, `file`, `sampleOffset`, `nSamples`) |
| `readChunkUV(chunk)` | one chunk as `[nSamples x nChan]` double **microvolts** |
| `readData(...)` | the whole recording as the universal data struct below |

Optional: `readWindowUV(sampleOffset, nSamp)` with `supportsRandomAccess()`
true (bounded random access, used to carry context across chunks),
`readDigitalEvents(ProgressFcn=)` (the digital lines without the amplifier
data; the default reads the recording keeping one channel), and
`siRecordingSpec()` (how `run_si_ks4.py` should load the recording). Static:
`claims(folder)`, `findRecordingFolders(root, recursive, options)`.

**Registry.** `EphysReader.forFolder(folder, Options=)` asks each class in
`EphysReader.readerClasses()` whether it claims the folder and builds the
first that does as `Reader(folder, options)`;
`EphysReader.register("MyReader")` adds a class;
`EphysReader.findAllRecordingFolders(root, recursive, Options=)` is what
`EphysProject.discover` and `DatasetTracker` use.

**Reader options.** `options` is the pipeline config's
[`Acquisition` section](EphysPipeline.md#acquisition); each reader reads its
own sub-struct (`options.OpenEphys`) and ignores the rest. Intan and binary
recordings need none.

| Reader | `RecordingFormat` | Claims a folder with |
| --- | --- | --- |
| [`IntanReader`](../pipeline/@IntanReader/IntanReader.m) | `"traditional"`, `"one-file-per-signal"`, `"one-file-per-channel"` | `*.rhd` (see [layouts](#supported-recording-layouts)) |
| [`BinaryReader`](../pipeline/@BinaryReader/BinaryReader.m) | `"binary"` | `recording.json` next to a flat channel-major binary ([format](file-formats.md#universal-recording-format-recordingjson)). Any other system can be brought in by converting to this; `BinaryReader.writeDescriptor(folder, spec)` writes the descriptor |
| [`OpenEphysReader`](../pipeline/@OpenEphysReader/OpenEphysReader.m) | `"openephys-binary"`, `"openephys-legacy"`, `"openephys-nwb"` | a `Record Node <id>` folder with data in one of the Open Ephys GUI's record engines, or an `openephys-part.json` part folder (see [Open Ephys sessions](#open-ephys-sessions)) |

**Universal data struct** (what `readData` returns for every reader):
`amplifier` `[nSamples x nChan]` microvolts (double or single); `Fs`; `t`
(`(row-1)/Fs`); `channelNames`; `nativeNames`; `channelOrder`; `events`
(one field per digital-input line, `[k x 2]` `[t_on t_off]` seconds with
`t = row/Fs`); `digInNames`; `digInNativeNames`; `boardADC`; `aux`; `auxFs`;
`files`; `fileSampleCounts`; `units` (`"microvolts"`); `source`. A reader
keys `events` by each line's **native** name (`DIGITAL_IN_04`, `TTL4`);
[`EphysDataset.readData`](#reading-data) renames them (see
[Digital-line names](#digital-line-names)).

**Channel numbers.** `ChannelNumbers` holds the 0-based hardware number of each
amplifier channel: the value a probe `chanMap` refers to. Intan: the trailing
digits of the native name (`A-012` is 12); Open Ephys: `CH13` is 12 (else the
trailing digits); `recording.json`: its `channel_numbers`, else `0..n-1`. They
are unique: when the names do not give distinct numbers (a two-port Intan
recording with `A-000` and `B-000`), every channel is numbered by its position
`0..n-1` and `EphysReader:ChannelNumbersNotUnique` warns. `run_si_ks4.py` names
the SpikeInterface channels by these numbers, so a probe maps by number and a
channel missing from the recording (disabled at acquisition) drops its site.

The dataset's `readData`, `streamPlan`, `readChunkUV`, `readWindowUV`,
`supportsRandomAccess`, `refreshMetadata`, `discoverFiles` and `detectFormat`
delegate to the reader; `ds.Reader` exposes it. The manifest records
`reader` (`"intan"`, `"binary"` or `"openephys"`).

---

## Supported recording layouts

`EphysDataset.detectFormat(folder)` asks the registry for the reader that claims
the folder and returns its format. `IntanReader` checks for these files, **in
this order**; the first match wins.

| `RecordingFormat` | Detected when the folder contains | Amplifier data on disk |
| --- | --- | --- |
| `"one-file-per-signal"` | `amplifier.dat` | `info.rhd` header + `amplifier.dat`, int16, `[nChan x nSamp]` with channel varying fastest |
| `"one-file-per-channel"` | any `amp-*.dat` | `info.rhd` header + one int16 file per channel, `amp-<native name>.dat` |
| `"traditional"` | any `*.rhd` | one or more `*.rhd` files with embedded data blocks |
| `"binary"` (`BinaryReader`) | `recording.json` | one flat channel-major file, any of int16 / uint16 / int32 / single / double, with `gain_to_uV` and `offset` from the descriptor |
| `"unknown"` | none of the above | none |

For the two split layouts, `Files` is set to `"info.rhd"`, `NumFiles` is `1`,
and the sample count comes from the `.dat` file size (see `splitLayout`).

### Scaling to microvolts

| Layout | Conversion used |
| --- | --- |
| traditional | `read_Intan_RHD2000_file_modified` output: µV = 0.195 × (uint16 − 32768) |
| split (`*.dat`) | µV = 0.195 × int16 (no 32768 offset) |

Split-layout auxiliary signals (`readSplitAll`, one-file-per-signal only):

| Signal | File | Conversion |
| --- | --- | --- |
| board ADC | `analogin.dat` (uint16) | board mode 1: 152.59e-6 × (raw − 32768) V; mode 13: 312.5e-6 × (raw − 32768) V; otherwise 50.354e-6 × raw V |
| aux input | `auxiliary.dat` (uint16) | 37.4e-6 × raw V, at `Fs/4` |
| digital in | `digitalin.dat` (uint16, packed bits) | bit `native_order` of each enabled line |

For one-file-per-channel recordings, digital inputs are read from
`board-DIN-<native_order, 2 digits>.dat` when **all** those files exist.
Otherwise there are no events. Board ADC and aux are **not** read for that layout
(returned as `[]`).

### Open Ephys sessions

`OpenEphysReader` reads a session folder written by the
[Open Ephys GUI](https://open-ephys.github.io/gui-docs/) (0.6 and later, and
the older Open Ephys format of GUI 0.4 / 0.5) in each of its record engines:

| `RecordingFormat` | GUI record engine | Inside `Record Node <id>/` |
| --- | --- | --- |
| `"openephys-binary"` | Binary (the GUI default) | `experiment<E>/recording<R>/structure.oebin`, `continuous/<stream>/continuous.dat` (int16, channels interleaved) + `sample_numbers.npy`, `events/<stream>/TTL/states.npy` + `sample_numbers.npy` + `full_words.npy`, `sync_messages.txt` |
| `"openephys-legacy"` | Open Ephys format | one `<proc>_<stream>_<channel>[_<E>].continuous` per channel (1024-byte text header, then 2070-byte records of 1024 big-endian int16), `<proc>_<stream>[_<E>].events` (GUI 0.4 / 0.5: `<proc>_<channel>.continuous` and `all_channels.events`), `messages[_<E>].events` |
| `"openephys-nwb"` | NWB 2 (plugin) | `experiment<E>.nwb`: the stream's `ElectricalSeries` under `/acquisition`, its `.TTL` series and `sync_messages` |

The **session folder** is the folder the GUI creates for each recording
session: named from the prepend text, the start time and the append text
(`SUBJ01_2026-09-17_10-30-00`, or `SUBJ-ID-1219_2026-07-07_16-35-39_active`),
holding one `Record Node <id>` folder per Record Node. It is the dataset; the
Record Node, experiment and recording folders never are. A folder holding the
node's files directly (GUI 0.4, or a Record Node folder copied on its own) is
read too. [`OpenEphysReader.DefaultNamePattern`](../pipeline/@OpenEphysReader/OpenEphysReader.m),
`"{SubjectID}_{Date:yyyy-MM-dd}_{Time:HH-mm-ss}*"`, matches these names.

**Several recordings.** The GUI starts a new *recording* each time recording
is stopped and restarted, and a new *experiment* each time acquisition is.
`Acquisition.OpenEphys.Recordings` decides what a dataset is:

| Mode | A session with several recordings is |
| --- | --- |
| `"concatenate"` (default) | one dataset: its recordings in (experiment, recording) order, joined end to end. `OpenEphysReader:Concatenated` warns at each boundary with the wall-clock time that is not in the data |
| `"separate"` | one dataset per recording, each in a **part folder** inside the session folder (`openephys-part.json`, created by the scan; see [file-formats](file-formats.md#open-ephys-part-folders)), named from the session folder with its GUI timestamp replaced by the recording's own start (`SUBJ01_2026-09-17_10-47-12`); without a timestamp, or for two recordings starting in the same second, `<name>_exp<E>_rec<R>`. A session with one recording stays one dataset |
| `"single"` | refused: `refreshMetadata` throws `OpenEphysReader:MultipleRecordings` naming the recordings (a scan reports it per dataset) |

A part folder's `Files` start with `..` (the session's files). Two parts
started in the same minute share a unit-label identity, which
`EphysProject.unitIdentities` reports as a collision; use `"concatenate"` for
those. In `"separate"` mode the session's Epsych2 file is in the session
folder, not the part folder, so the behavior step finds it through
`Behavior.SearchDirs` by start time.

**Record node and stream.** `Acquisition.OpenEphys.RecordNode` picks a Record
Node by id; blank reads the only one, or the lowest id with a warning
(`OpenEphysReader:SeveralNodes`). `Acquisition.OpenEphys.Stream` picks a
continuous stream by name (`Rhythm Data`) or folder name; blank reads the
stream with the most headstage channels (`OpenEphysReader:SeveralStreams`
when more than one has any).

**Channels.** The stream's headstage channels (`CH1..`) are the amplifier
channels, in microvolts (int16 × `bit_volts`, 0.195 for Intan headstages);
AUX channels are the accelerometer inputs and ADC channels the board ADC,
both in volts. The GUI's channel type decides (Binary `type`, NWB
`channel_type`); otherwise the name (`AUX`, `ADC`). NWB files carry no channel
names: channels are named `CH<n>` from their electrode index within the
stream, `AUX<k>` and `ADC<k>`, and their bit volts are the file's float32
`channel_conversion` (× 1e6, to 7 significant digits). The Acquisition Board
updates its AUX inputs every 4 samples and holds the value: when every AUX
channel holds each value for 4 samples (tested on the first 10 s) `readData`
returns them at `Fs/4`, as the Intan layouts do. Open Ephys stores AUX as
(raw − 32768) × 37.4 µV, so its accelerometer volts are 1.2255 V below what
Intan RHX writes for the same signal.

**Digital lines.** TTL lines are `TTL1..TTLn` (native = custom), up to the
highest line with an edge (or set in a TTL word); name them with
`Signals.LineNames` (`TTL4=InTrial`). A rising edge at sample *s* opens an
interval at *s*'s row and a falling edge closes it on the row before. A line
already high when a recording starts begins at its first row when the format
records that: Binary always (`initial_state` in `structure.oebin`); NWB when
the recording has any TTL edge (its TTL words); the Open Ephys format only
when the line's first edge in that recording is falling. A line high at the
start of a recording that never changes during it is therefore invisible in
the Open Ephys format. Intervals are split at recording boundaries
(`OpenEphysReader:LineAcrossBoundary` warns).

**Samples.** A recording's rows are its stored samples. When the GUI dropped
samples, `sample_numbers` (Binary), the record headers (Open Ephys format) or
`sync` (NWB) jump; the reader finds each jump by binary search on the sample
numbers, warns (`OpenEphysReader:Gaps`) and does not zero-fill, and TTL edges
land on the stored rows (an edge inside a gap moves to the next stored row).
The GUI fills the last 1024-sample record of each recording in the Open Ephys
format with zeros; those samples are part of the data.

**Start time (`AcqDate`)** is the first recording's start, from the GUI's
Software Time message (`sync_messages.txt`, `messages.events`, NWB
`sync_messages`: milliseconds since 1970 UTC, converted to local time); else
the `.continuous` header's `date_created` or the NWB `session_start_time`
(plus the recording's offset in its experiment); else the modification time
of `structure.oebin`. `PerFile` has one entry per recording (`name`
`"exp1/rec2"`, `experiment`, `recording`, `numAmplifierSamples`,
`recordTime`, `datenum`, `numGaps`).

---

## Construction

```matlab
ds = EphysDataset(folder)                        % discover files + parse headers
ds = EphysDataset(folder, AutoMetadata=false)    % discover files only (cheap)
ds = EphysDataset(folder, ProbeFile=..., PythonExe=..., OutputDir=...)
ds = EphysDataset()                              % empty object (arrays/preallocation)
```

| Option | Default | Meaning |
| --- | --- | --- |
| `AutoMetadata` | `true` | call `refreshMetadata` after file discovery |
| `Name` | folder leaf name | dataset name; used for output file names |
| `ProbeFile` | `""` | Kilosort4 probe `.json` |
| `PythonExe` | `""` | Python executable used to launch Kilosort4 / SpikeInterface |
| `CondaEnv` | `""` | when set, commands are run via `conda run -n <env>` |
| `Scale` | `1/0.195` | multiplier applied before casting when writing `.bin` |
| `Dtype` | `"int16"` | `.bin` sample class |
| `OutputDir` | `""` | output folder; `""` means the recording folder |
| `Manifest` | `[]` | optional `Manifest` object ([vendor/tools/Manifest.m](../vendor/tools/Manifest.m)) that receives provenance entries |
| `ReaderOptions` | `struct()` | reader options (the config's `Acquisition` section) |

The constructor errors (`EphysDataset:NoFolder`) if the folder does not exist.

---

## Properties

### Identity (public)

| Property | Type | Meaning |
| --- | --- | --- |
| `Folder` | string | recording folder |
| `Files` | string row | traditional: every `*.rhd`, sorted by file `datenum` (chronological); split: `"info.rhd"`; binary: the descriptor and the data file; Open Ephys: the data and event files of the selected recordings, relative to `Folder` (`..\Record Node 101\...` for a part folder) |
| `Name` | string | dataset name (defaults to the folder leaf). Its `SubjectID`, `Date` and `Time` tokens label the sorted units; see [Unit labels](#unit-labels) |
| `Reader` | `EphysReader` | the acquisition reader (created by the constructor from the registry) |

### Metadata (read-only, filled by `refreshMetadata`)

| Property | Meaning |
| --- | --- |
| `RecordingFormat` | layout, see the table above (`"binary"` for the universal format) |
| `Fs` | amplifier sample rate (Hz) |
| `NumChannels` | amplifier channel count (from the first file) |
| `ChannelNames` / `NativeNames` | amplifier custom / native (hardware) names: Intan `custom_channel_name` / `native_channel_name`; Open Ephys `CH1..` for both |
| `ChannelNumbers` | 0-based hardware numbers, what probe `chanMap` values refer to (see [channel numbers](#acquisition-readers)) |
| `DigInNames` / `DigInNativeNames` | digital-line custom / native names (Open Ephys: `TTL1..` for both) |
| `Duration` | total duration (s) = sum of per-file `recordTime` |
| `AcqDate` | recording start: earliest file `datenum` (traditional), the amplifier `.dat` `datenum` (split), the descriptor's `acq_date` (binary), the Software Time message (Open Ephys) |
| `NumFiles` | number of `*.rhd` files (1 for split layouts; Open Ephys: recordings) |
| `PerFile` | struct array, one element per file: `name`, `bytesPerBlock`, `numDataBlocks`, `numAmplifierSamples`, `recordTime`, `numAmplifierChannels`, `numBoardDigIn`, `headerBytes`, `datenum`, `partialBlock`, `dataPresent` (Open Ephys: one per recording, plus `experiment`, `recording`, `numGaps`) |

### Configuration (public)

| Property | Default | Meaning |
| --- | --- | --- |
| `ProbeFile` | `""` | Kilosort4 probe `.json`. Validated, never generated by this class |
| `ExcludeChannels` | `[]` | 1-based channels to drop from sorting (see [Channel exclusions](#channel-exclusions)) |
| `PythonExe`, `CondaEnv` | `""` | Python launch configuration |
| `Scale` | `1/0.195` | `.bin` scale factor |
| `Dtype` | `"int16"` | one of `int16`, `uint16`, `int32`, `single`, `float32` |
| `OutputDir` | `""` | output folder (`""` = `Folder`) |
| `Manifest` | empty | optional provenance `Manifest` object |
| `ManualArtifacts` | `zeros(0,2)` | manual artifact periods, `[tStart tEnd]` seconds, recording-relative. Saved to and restored from the dataset manifest |
| `ArtifactConfig` | `defaultArtifactConfig()` | automatic artifact-detector settings |
| `SIConfig` | `defaultSIConfig()` | SpikeInterface preprocessing settings for `runSpikeInterface` |
| `SortingDir` | `""` | an explicit sorted-output folder (the one holding `params.py`). `""` = auto-discover under `kilosortDir()`; see [Sorted output](#sorted-output) |
| `BehaviorFile` | `""` | the associated Epsych2 session `.mat`; see [Behavior](#behavior-epsych2) |
| `TrialConfig` | `defaultTrialConfig()` | trial pairing and line naming: `TrialLine` (`"InTrial"`), `InvertedLines` (see [polarity](EphysPipeline.md#digital-line-polarity)), `SignalFs` (struct of derived-signal rates), `LabelField` (`"custom"` / `"native"`) and `LineNames` (`"native=name"` entries); see [Digital-line names](#digital-line-names) |
| `ReaderOptions` | `struct()` | the config's `Acquisition` section, passed to the reader. Setting a different value drops the reader, so the next access rebuilds it (call `refreshMetadata` for fresh metadata) |
| `NamePattern` | `EphysDataset.DefaultNamePattern` = `"{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"` | [`parseNameTokens`](../pipeline/parseNameTokens.m) pattern that splits `Name` into the tokens labelling sorted units. Pushed from `EphysProject.NamePattern` / the config's `Project.NamePattern` |
| `DatasetKey` | `""` | folder relative to the project root, saved with every unit (`""` = the absolute folder). Pushed by `EphysProject` and the pipeline |
| `TrialPairing` | `struct([])` | the recorded pairing (manifest `behavior.pairing`): `status` (`"unreviewed"` / `"approved"`), `auto_approved` (approved by `autoApproveTrialPairing`, not by a review), `cut_trials` and `cut_intervals` (`[start end]` counts dropped before the in-order pairing), `fingerprint`, `trial_line`, `summary`, `updated` |

### Dependent

| Property | Value |
| --- | --- |
| `BinFile` | `fullfile(outputFolder(), Name + ".bin")` |
| `NumSamples` | `sum([PerFile.numAmplifierSamples])`, or `NaN` before metadata is parsed |

---

## Typical use

```matlab
ds = EphysDataset("D:\rec\subj1_day1");
ds.PerFile                                   % per-file header summary

% --- Kilosort4 via SpikeInterface (what the GUI does) ---
ds.ProbeFile = "C:\src\ephys_analysis\pipeline\probes\H64LP_4x16lin_probemap.json";
ds.PythonExe = "C:\Users\me\miniconda3\envs\kilosort\python.exe";
ds.ExcludeChannels = [5 17];
res = ds.runSpikeInterface(DryRun=true);     % write si_config.json + script only
res = ds.runSpikeInterface();                % run and wait

% --- Legacy path: write a .bin, then run Kilosort4 on it ---
info = ds.toBin();
res  = ds.runKilosort();

% --- Derived signals (intan2matlab processing) ---
[Y, ev, info] = ds.deriveSignals(dataTypeOut=["LFP" "MUA"]);
out = ds.toMat(File="D:\out\subj1.mat", SignalOptions=struct('dataTypeOut', "LFP"));

% --- Sorted units, spikes file, exports ---
U   = ds.readSortedUnits(Groups=["good" "mua"]);   % the associated Kilosort4 / phy output
out = ds.spikesToMat(Source="both");                % <Name>_spikes.mat: detected + units
out = ds.exportChronux();                           % <Name>_chronux.mat
out = ds.exportFieldTrip();                         % <Name>_fieldtrip.mat
```

For many datasets with one set of settings, use [`EphysPipeline`](EphysPipeline.md).

---

## Methods

### Discovery and metadata

**`discoverFiles()`** asks the reader to inventory the folder and fills
`Files`, `NumFiles`, `RecordingFormat` and (from file dates) `AcqDate`. The
constructor calls it, and so does `refreshMetadata`.

**`refreshMetadata()`** re-runs `discoverFiles`, then (for `IntanReader`):

- **traditional**: parses every `*.rhd` header with the private static
  `parseIntanHeader` (header only, no amplifier matrix allocated). Channel names,
  `Fs` and `NumChannels` come from the first file. Two checks apply to later files:
  - A different amplifier channel count raises
    `EphysDataset:refreshMetadata:ChannelMismatch`, because a flat `.bin`
    cannot represent a mid-recording channel change.
  - A truncated trailing data block warns
    (`EphysDataset:refreshMetadata:PartialBlock`), and only whole blocks are
    counted.
- **split layouts**: parses `info.rhd` and derives the sample count from the
  `.dat` size (`splitLayout`). `PerFile` gets a single entry named `"info.rhd"`.

With no files it warns (`EphysDataset:refreshMetadata:NoFiles`) and returns.

For `BinaryReader`, everything comes from `recording.json` and the data file
size.

**`L = splitLayout()`** (`IntanReader`, split layouts only) returns and caches a struct
describing the split recording. Fields: `format`, `folder`, `headerFile`, `Fs`,
`nChan`, `nSamp`, `boardMode`, `ampCustom`, `ampNative`, `digInNames`,
`digInNative`, `digInOrders`, `numADC`, `numAux`, `ampFile` / `ampFiles`,
`timeFile`, `digInFile` / `digInFiles`, `adcFile`, `auxFile`, `ampDatenum`.
`nSamp` is computed as follows:

- one-file-per-signal: `floor(bytes(amplifier.dat) / (2·nChan))`
- one-file-per-channel: `floor(bytes(first amp-*.dat) / 2)`, so only the
  **first** channel file is used for sizing

**`parseIntanHeader(ffn)`** (`IntanReader`, static) is a header-only extraction of the
RHD2000 reader. It returns sample rate, channel counts by type, amplifier and
digital-input names and `native_order`, bytes per data block, samples per block
(60 for file version 1, 128 otherwise), whole-block count, `partialBlock`,
`dataPresent`, board mode and file version. It errors on a wrong magic number or
an unknown channel type.

### Reading data

**`data = readData(Name=Value)`** reads the whole recording into memory as the
[universal data struct](#acquisition-readers). For traditional Intan
recordings, each file is read with `read_Intan_RHD2000_file_modified` and
concatenated in time; split layouts go through `IntanReader.readSplitAll`;
binary recordings through `BinaryReader.readData`; Open Ephys sessions through
`OpenEphysReader.readData` (one read per recording). All return the same
struct, whose digital lines are then named (see
[Digital-line names](#digital-line-names)).

| Option | Default | Meaning |
| --- | --- | --- |
| `Files` | all | subset/order of `*.rhd` files (ignored for split layouts) |
| `KeepChannels` | all | 1-based amplifier channels to keep |
| `IncludeADC`, `IncludeAux` | `false` | also return board ADC / aux input |
| `Concatenate` | `true` | concatenate files in time (`false` returns per-file cells) |
| `ProgressFcn` | none | called as `ProgressFcn(i, nFiles, fileName)` before each file |
| `Precision` | `"double"` | `"single"` casts each file as read (about half the peak memory) |
| `LabelField` | `TrialConfig.LabelField` | `"custom"` or `"native"`: each digital line's default name |
| `LineNames` | `TrialConfig.LineNames` | `"native=name"` entries naming lines (`"TTL4=InTrial"`) |

Output fields: `amplifier` `[nSamples x nChan]` µV; `Fs`; `t` = `(0:n-1)'/Fs`;
`channelNames`; `nativeNames`; `channelOrder`; `events` (one field per dig-in
line, `[k x 2]` `[t_on t_off]` seconds); `digInNames`; `digInNativeNames`;
`boardADC`; `aux`; `auxFs`; `files`; `fileSampleCounts`; `units` (`"microvolts"`);
`source`.

Behavior worth knowing:

- A traditional file with no amplifier data is skipped with a warning
  (`EphysDataset:readData:NoData`).
- The digital-input line count is fixed by the **first** file. Extra lines in
  later files are ignored (the same policy as the original `intan2matlab`).
- Events are contiguous high runs of each line, found with `bwlabel` when the
  Image Processing Toolbox is present or an equivalent `diff` fallback otherwise.
  Onset and offset times are reported as **(1-based sample index) / Fs**. See
  [Time conventions](README.md#time-and-indexing-conventions).
- With `Concatenate=false`, `events` is empty and `t` is `[]`.

#### Digital-line names

Readers key `events` by each line's native name. `readData` and
`digitalEvents` then name every line through
[`EphysDataset.relabelEvents`](../pipeline/@EphysDataset/relabelEvents.m):
its `LineNames` entry when there is one (`"native=name"`, the native name
matched without case), else its custom name (`LabelField = "custom"`) or its
native name (`"native"`). Intan lines have both (`DIGITAL-IN-04` named
`InTrial` in RHX); Open Ephys lines have only `TTL1..`, so name them with
`LineNames = ["TTL4=InTrial" ...]`. `digInNames` holds the final names,
`TrialConfig.TrialLine` and `InvertedLines` refer to them, and two lines ending
with the same name throw `EphysDataset:relabelEvents:Duplicate`.
`EphysDataset.parseLineNames(list)` checks and splits a list
(`EphysDataset:LineNames`).

**`plan = streamPlan(Files=..., MaxChunkSamples=...)`** returns the list of
chunks to stream. Each element has `kind` (`"rhd"`, `"split"` or `"window"`),
`name`, `file`, `sampleOffset` and `nSamples`.

- traditional: one chunk per `*.rhd` file.
- split, binary and Open Ephys: fixed-size sample windows over the recording
  (an Open Ephys window may span a recording boundary). The default chunk size
  is `max(round(Fs), floor(2.5e8 / (nChan·8)))` samples, about 250 MB of
  double but never less than about 1 s.

**`X = readChunkUV(chunk)`** reads one `streamPlan` element and returns
`[nSamp x nChan]` double µV with **all** channels in header order. An empty
result means the chunk held no amplifier data.

**`X = readWindowUV(sampleOffset, nSamp)`** reads a sample window directly from
the data file(s) when the reader supports random access
(`supportsRandomAccess()`: split Intan layouts, binary recordings and Open
Ephys sessions). It
returns `[nSamp x nChan]` double µV. A short final window returns only the rows
present. For one-file-per-channel, the result is trimmed to the shortest
channel read.

`toBin`, `analyzeArtifacts`, `artifactIntervals`, `detectSpikes` and the GUI's
Visualize tab all use `streamPlan` + `readChunkUV`, so they behave the same
across layouts and readers and hold one chunk in memory at a time.

### Filtering

**`Y = filterContinuous(X, Type=..., Cutoff=..., Order=..., Fs=...)`** applies a
zero-phase Butterworth filter (`butter` + `filtfilt`) column-wise to
`[nSamples x nChan]` data. The result is double.

| Option | Default |
| --- | --- |
| `Type` | `"highpass"` (or `"lowpass"`, `"bandpass"`) |
| `Cutoff` | `300` (scalar for high/low-pass, `[lo hi]` for bandpass) |
| `Order` | `4` |
| `Fs` | `ds.Fs` |

Every cutoff must be below Nyquist. Requires the Signal Processing Toolbox.

### Artifact detection and blanking

**`[mask, intervals, stats] = detectArtifacts(X, Name=Value)`** flags samples
of an in-memory `[nSamples x nChan]` block.

| Method | A sample is flagged on a channel when… |
| --- | --- |
| `"rms"` (default) | the running RMS (window `RmsWindowMs`, default about 1 ms) is more than `Threshold` robust SDs (1.4826 × MAD of the RMS) above that channel's median RMS |
| `"mad"` | \|x − median\| / (1.4826 × MAD) > `Threshold` |
| `"microvolts"` | \|x\| > `Threshold` µV |
| `"commonmode"` | \|mean across channels\| > `Threshold` µV (applies to all channels at once) |

A sample is flagged overall when at least `min(MinChannels, nChan)` channels
exceed at once (ignored for `commonmode`). Flagged runs separated by at most
`MergeGapMs` of clean signal are then stitched together, and finally each run is
padded by `PadMs` on both sides.

- Default `Threshold` when not given: rms 9, mad 8, microvolts/commonmode 1500.
- `stats` fields: `method`, `threshold`, `rmsWindowMs` (actual window after
  rounding), `minChannels`, `mergeGapMs`, `padMs`, `fraction`, `numIntervals`,
  and `channelExceedCounts` (per channel, before the `MinChannels` combination).
- `intervals` are `[k x 2]` seconds computed as (1-based index)/Fs.

**`Y = blankArtifacts(X, mask, Fill=...)`** replaces flagged rows on every
channel. `Fill` is `"zero"` (default), `"hold"` (repeat the last clean sample;
0 if the run starts at row 1) or `"nan"`.

**`summary = analyzeArtifacts(Name=Value)`** streams the whole recording, runs
`detectArtifacts` on each chunk with `ArtifactConfig` (per-call options
override), and accumulates statistics **without writing anything**. The GUI's
Artifacts tab uses it for its preview. Options: `Files`, `ChannelOrder`, the
detection parameters, `Filter` / `FilterType` / `FilterCutoff` / `FilterOrder`
(detect on a filtered view; default from `ArtifactConfig`), `MaxChunkSamples`,
`UseParallel` / `MaxWorkers` (run the chunks on a process pool; identical
result; the rules are those of [`detectSpikes`](#whole-recording-mode)) and
`ProgressFcn`. Output fields:
`method`, `threshold`, `rmsWindowMs`, `mergeGapMs`, `minChannels`, `padMs`,
`fs`, `nSamples`, `durationSec`, `nChan`, `channelNames`, `channelCounts`,
`channelPct`, `nBlanked`, `fraction`, `pctDuration`, `nIntervals` (summed per
chunk), `files`.

Detection runs **per chunk**. The robust baseline (median/MAD) is computed within
each chunk, and runs are not stitched across chunk boundaries.

**`iv = artifactIntervals(Name=Value)`** returns the merged `[k x 2]` list of
periods (seconds) that `runSpikeInterface` passes to SpikeInterface
`silence_periods`:

- all `ManualArtifacts` (always included), plus
- automatic intervals from the same chunked detector, when
  `ArtifactConfig.Enabled` is true (or `IncludeAuto=true`). Each chunk's intervals
  are shifted by the running sample offset.

Overlapping or touching periods are merged. Periods with `tEnd <= tStart` are
**dropped**, which includes an automatic detection only one sample long. The
filter fields of `ArtifactConfig` apply here too, so the preview
(`analyzeArtifacts`) and a run detect on the same signal. `UseParallel`,
`MaxWorkers` and `MaxChunkSamples` work as for `analyzeArtifacts`, and the
intervals are the same in either mode.

#### Manual periods

- `addArtifact(t0, t1)` appends `[t0 t1]` (seconds, recording-relative),
  clamps negatives to 0, ignores zero-width periods, then sorts and merges
  overlaps.
- `mask = manualArtifactMask(nSamp, sampleOffset, Fs, iv)` returns the per-block
  logical mask `toBin` uses, for the intervals `iv` (default `ManualArtifacts`). It covers samples `ceil(t0·Fs) … floor(t1·Fs)` as
  0-based absolute indices.

#### Default artifact configuration

`EphysDataset.defaultArtifactConfig()`:

| Field | Default | Meaning |
| --- | --- | --- |
| `Enabled` | `false` | `toBin` blanks, and `artifactIntervals` includes auto detections, only when true |
| `Method` | `"rms"` | detector method |
| `Threshold` | `9` | robust SDs (µV for microvolts/commonmode) |
| `RmsWindowMs` | `NaN` | running-RMS window, ms; `NaN` = about 1 ms |
| `MergeGapMs` | `0` | stitch gaps up to this length |
| `MinChannels` | `2` | channels that must exceed simultaneously |
| `PadMs` | `0` | expand each run by this much on both sides |
| `Filter` | `false` | detect on a filtered view of each chunk |
| `FilterType`, `FilterCutoff`, `FilterOrder` | `"highpass"`, `300`, `4` | the filter used when `Filter` is on |

`normalizeArtifactConfig(cfg)` fills missing fields from these defaults and
drops unknown fields. `EphysDataset.resolveFilterOptions(cfg, opts)` merges
per-call filter options over the config's.

### Spike detection

**`[ts, wf, info] = detectSpikes(Name=Value)`** detects spikes over the **whole
recording**, streaming it one chunk at a time (see *Whole-recording mode*
below). **`[ts, wf, info] = detectSpikes(X, Name=Value)`** detects in an
in-memory `[nSamples x nChan]` microvolt block instead. Both run the same
detector — **simple voltage thresholding**, each channel independently — with
the same options; `X`, and the files on disk, are never modified.

- `ts` is a `{1 x nChan}` cell array of spike times in **seconds** — always a
  cell array, one column vector per channel, also for a single channel.
- `wf{c}` is `[nSpikes x nWin]` microvolts around each spike, rows in the same
  order as `ts{c}`. **Waveforms are extracted only when a second output is
  requested or `Waveforms=true`** — timestamps only is the default.
- `info` reports the parameters actually used plus the per-channel thresholds,
  noise estimates, sample indices, amplitudes and counts (see below).

The pipeline is: band-pass filter → per-channel threshold → threshold crossings
→ align each crossing to its extremum → enforce the minimum detection period →
optional amplitude ceiling → optional waveform extraction.

| Option | Default | Meaning |
| --- | --- | --- |
| `Filter` | `true` | band-pass first (through `filterContinuous`) |
| `Band` | `[500 5000]` | band-pass edges in Hz; the upper edge must be below Nyquist |
| `FilterOrder` | `4` | Butterworth order |
| `Polarity` | `"negative"` | cross when `x < -thr`; `"positive"` uses `x > thr`, `"both"` uses \|x\| > thr |
| `ThresholdMethod` | `"mad"` | see the table below |
| `Threshold` | method-dependent | the number that goes with the method |
| `Align` | `"trough"` | `"peak"`, `"extremum"` (largest \|x\|) or `"none"` (the crossing sample) |
| `AlignWindowMs` | `1` | extremum search window, starting at the crossing |
| `MinPeriodMs` | `1` | minimum detection period (dead time after a kept event) |
| `MaxAmplitudeUV` | `Inf` | reject events whose amplitude exceeds this in absolute value |
| `Waveforms` | `false` | force waveform extraction even with one output |
| `WindowMs` | `[-0.5 1.5]` | waveform window relative to the aligned sample, `before <= after` |
| `WaveformSource` | `"filtered"` | or `"raw"` — which trace the snippets are cut from |
| `EdgeHandling` | `"nan"` | a window past the start/end of `X` is NaN-padded; `"drop"` removes the event from **both** `wf` and `ts` |
| `Fs` | `ds.Fs` | sample rate (Hz); block form only — in whole-recording mode the rate comes from the file headers (`EphysDataset:detectSpikes:FsNotAllowed`) |
| `TimeOffset` | `0` | seconds added to every timestamp (for detecting on one chunk of a longer recording) |

Thresholds are computed **per channel on the filtered trace** and are always
applied as a positive magnitude — `Polarity`, not the sign of `Threshold`, sets
the direction.

| `ThresholdMethod` | Threshold value | `Threshold` default |
| --- | --- | --- |
| `"mad"` | `Threshold` × robust SD, median(\|x − median(x)\|)/0.6745 | `4` |
| `"std"` | `Threshold` × `std(x)` | `4` |
| `"rms"` | `Threshold` × `sqrt(mean(x²))` | `4` |
| `"percentile"` | the `Threshold`-th percentile of \|x\|, in (0 100] | `99.9` |
| `"absolute"` | `Threshold` microvolts | none — **required** |

`"mad"` is the default because large spikes inflate `std` (and `rms`) and so
raise the threshold they should be measured against.

**Alignment.** For each crossing, the extremum is taken over the run of
above-threshold samples, extended to at least `AlignWindowMs` from the crossing.
That sample becomes both the timestamp and the waveform center. Two crossings
that align to one extremum collapse into a single event (the minimum detection
period is floored at one sample, so exact duplicates are always removed). The
minimum detection period is then applied greedily, keeping the **earlier** of
two events closer than `MinPeriodMs`.

**Timestamps** are `t = (row − 1)/Fs + TimeOffset`: the convention used by
`readData`'s `t` vector and by Kilosort/phy sample indices, and one sample
earlier than the `t = row/Fs` convention of `detectArtifacts` intervals and
digital-input events. `info.index` holds the 1-based rows of `X`.

#### Whole-recording mode

`ds.detectSpikes()` — `X` omitted (or `[]`) — detects over the whole recording
without holding it all in memory. The recording is streamed in the same units
`toBin` and `analyzeArtifacts` use (`streamPlan` / `readChunkUV`: one `*.rhd`
file per chunk for the traditional format, bounded sample windows for the split
and binary formats), so every layout and reader works. `info.index` then holds **recording-global**
1-based sample indices and `ts` recording-relative seconds.

**Chunk boundaries are not detection boundaries.** Each chunk is detected
together with `EdgePadMs` of real data carried over from the previous chunk, and
the last `EdgePadMs` of each chunk is held back and reported with the next one.
Every returned event therefore has at least that much genuine signal on both
sides for filter settling, extremum search and its waveform window — only the
first and last samples of the recording can truncate one — the reported regions
tile the recording exactly, so nothing is detected twice, and `MinPeriodMs` is
re-applied across the joins.

**Thresholds are still estimated per chunk** (`info.thresholdScope` is
`"chunk"`): a chunk's noise estimate uses only that chunk's samples, exactly as
it does for a block, so the threshold tracks the noise from chunk to chunk and
`info.threshold` / `info.noise` / `info.degenerate` are `[nChunks x nChan]`. Use
`ThresholdMethod="absolute"` for one fixed threshold in microvolts across the
whole recording.

| Option (whole-recording mode only) | Default | Meaning |
| --- | --- | --- |
| `Files` | all | subset/order of `*.rhd` files (traditional format only); timestamps stay relative to the first sample read |
| `ChannelOrder` | all | 1-based reorder/subset of amplifier channels, applied to every chunk (as in `toBin`) |
| `MaxChunkSamples` | `streamPlan` default | cap on samples per chunk for the split and binary formats |
| `UseParallel` | `false` | detect the chunks on a process pool (Parallel Computing Toolbox): the open one, else one sized to the worker cap. Identical result; falls back to serial with `EphysDataset:detectSpikes:SerialFallback` when the toolbox, the pool or a chunk's sample count is missing, when a thread pool is open, or when memory allows fewer than two workers |
| `MaxWorkers` | `NaN` (automatic) | cap on chunks in flight at once; always limited by free memory (about six copies of one chunk per worker), so a 12-worker pool typically runs 4-5 chunks at a time |
| `EdgePadMs` | `10` | context carried across chunk boundaries; always at least the waveform window, the alignment window and the minimum detection period |
| `ProgressFcn` | none | `ProgressFcn(i, nChunks, chunkName)`: before each chunk (serial), or on the client as each chunk finishes (parallel; `i` = chunks done). Throwing from it aborts the run and cancels the outstanding chunks |

Passing any of these with a data block raises
`EphysDataset:detectSpikes:BlockOption`. One chunk plus its padding is held at a
time, but the timestamps — and the waveforms, when asked for — accumulate for
the whole recording.

**Noise and threshold estimates use the whole block**, so detect on windows long
enough to characterize the noise (a second or more) and expect chunk-to-chunk
variation if you stream. Non-finite samples (for example NaN from
`blankArtifacts(Fill="nan")`) are excluded from the estimates and never cross
threshold. A channel whose threshold works out non-positive or non-finite (flat
or empty signal) gets `Inf` instead, so nothing is detected there rather than
everything; it is flagged in `info.degenerate` and warned about
(`EphysDataset:detectSpikes:DegenerateThreshold`).

`info` fields: `fs`, `nSamples`, `nChan`, `durationSec`, `channelNames` (when
`ChannelNames` matches the column count), `filterApplied`, `band`,
`filterOrder`, `polarity`, `thresholdMethod`, `thresholdInput`, `threshold`
`[1 x nChan]`, `noise` `[1 x nChan]` (NaN for `percentile` / `absolute`),
`degenerate`, `align`, `alignWindowMs`, `alignWindowSamples`, `minPeriodMs`,
`minPeriodSamples`, `windowMs`, `windowSamples`, `waveformTimeMs` `[1 x nWin]`,
`waveformSource`, `waveformsExtracted`, `edgeHandling`, `count` `[1 x nChan]`,
`rate` `[1 x nChan]` (Hz over `durationSec`), `index` `{1 x nChan}`,
`amplitude` `{1 x nChan}` (signed filtered microvolts at each aligned sample),
`rejectedIndex` / `droppedEdgeIndex` `{1 x nChan}` (the rows cut by
`MaxAmplitudeUV` and by `EdgeHandling="drop"`), `nEdgeWindows`,
`nRejectedAmplitude`, `maxAmplitudeUV`, `timeOffset`. The millisecond fields
report the values **after** rounding to samples.

Whole-recording mode drops `rejectedIndex` / `droppedEdgeIndex` (they are
chunk-local) and adds `source` (`"recording"`), `thresholdScope` (`"chunk"`),
`edgePadMs` / `edgePadSamples`, `chunks` (a struct array of `name`,
`sampleOffset`, `nSamples` for the chunks read) and `files`.

```matlab
ts = ds.detectSpikes();                                  % whole recording
ts = P.Datasets(4).detectSpikes();                       % straight off a project
[ts, wf, info] = ds.detectSpikes(ThresholdMethod="absolute", ...
    Threshold=60, ChannelOrder=1:16);

d  = ds.readData();                                      % or one in-memory block
ts = ds.detectSpikes(d.amplifier);                       % timestamps only
[ts, wf, info] = ds.detectSpikes(d.amplifier, ...        % + waveforms
    Band=[300 6000], Threshold=4.5, MinPeriodMs=1.5);
plot(info.waveformTimeMs, wf{1}(1:50,:).');
```

Any microvolt matrix works, with or without a real recording folder:

```matlab
ts = EphysDataset().detectSpikes(X, Fs=30000);
```

This is a threshold detector, not a sorter: it does not cluster, and a spike
seen on several channels is detected once per channel.

### Writing a Kilosort4 `.bin`

**`info = toBin(Name=Value)`** streams the recording to `BinFile` (or `BinFile=`
override). The file has no header, is little-endian, and has the channel index
varying fastest. It holds one chunk in memory at a time. Per chunk, in order:

1. read µV (`readChunkUV`);
2. check the channel count (error `EphysDataset:toBin:ChannelMismatch` if it
   changes);
3. reorder/subset (`ChannelOrder`);
4. filter, if `Filter=true` (default **off**; Kilosort4 filters internally);
5. auto-detect and zero artifacts, if `Blank=true` **or**
   `ArtifactConfig.Enabled`, and no `ArtifactIntervals` list is given;
6. zero `ArtifactIntervals` when given, else `ManualArtifacts` (mapped with the
   running sample offset);
7. compute `scale × x + Offset`, count out-of-range samples, cast, write.

| Option | Default |
| --- | --- |
| `Files`, `ChannelOrder` | all |
| `Scale` / `Dtype` | `ds.Scale` / `ds.Dtype` |
| `Offset` | `0` |
| `Filter`, `FilterType`, `FilterCutoff`, `FilterOrder` | off, `"highpass"`, `300`, `4` |
| `FilterEdgeMode` | `"independent"` (each chunk filtered on its own). `"overlap"` prepends the previous chunk's last `OverlapSamples` raw samples before filtering |
| `Blank`, `ArtifactMethod`, `ArtifactThreshold`, `ArtifactRmsWindowMs`, `ArtifactMergeGapMs`, `ArtifactMinChannels`, `ArtifactPadMs` | fall back to `ArtifactConfig` |
| `ArtifactIntervals` | `NaN`: `ManualArtifacts` plus detection as above. A `[k x 2]` list of seconds replaces both, and `[]` zeroes nothing. `runKilosort` passes its intervals here |
| `WriteMeta` | `true` (writes a `<name>.json` sidecar next to the `.bin`) |
| `BinFile` | `ds.BinFile` |

With the default scale `1/0.195`, µV are converted back to native int16 ADC
units. For integer dtypes, values outside the class range are **clipped** by the
cast. Clipping is counted (`info.nClipped`) and reported by a warning
(`EphysDataset:toBin:Clipping`).

`info` fields: `filename`, `dtype`, `nChan`, `nSamples`, `fs`, `scale`,
`offset`, `byteOrder`, `nClipped`, `nManualArtifacts`, `nManualBlanked`,
`nAutoBlanked`, `autoArtifact` (settings used + `nBlanked`, `fraction`,
`pctDuration`, `nIntervals`, `channelCounts`), `nBytes`, `metaFile`. The sidecar
schema is in [file-formats.md](file-formats.md#bin-json-sidecar).

**`info = matrixToBin(X, Name=Value)`** writes an in-memory
`[nSamples x nChan]` µV matrix by delegating to
[`matrix2kilosort`](../matrix2kilosort.m), using the dataset's
`Scale`/`Dtype`/`Fs`. Options: `BinFile`, `Scale`, `Offset`, `Dtype`, `Fs`,
`ChannelOrder`, `ChannelsAreRows`, `WriteMeta`. The code comments state that,
for the same data and options, it produces a file byte-identical to `toBin`;
`test_EphysDataset` section 4 checks this.

### Running Kilosort4

There are two engines, picked by the config's `Sorting.Engine` (the Sorting
tab's **Engine** drop-down):

- **`runSpikeInterface`** (`"spikeinterface"`, the default) reads the raw
  recording with SpikeInterface, applies its preprocessing and runs Kilosort4.
- **`runKilosort`** (`"kilosort"`) writes the recording to a `.bin` and runs
  Kilosort4 natively on it, with no SpikeInterface. It is also what
  `EphysProject.runKilosortAll` calls.

Both take the same `ExtraSettings`, `ArtifactIntervals`, `DryRun` and `Wait`
options. Both refuse to run when the artifact intervals cover more than
`EphysDataset.MaxSilencedFraction` (half) of the recording, because Kilosort4
would then find no spikes and fail inside its template SVD. `runKilosort`
checks this in MATLAB before writing the `.bin`. `runSpikeInterface` checks it
in `run_si_ks4.py`, which logs the covered share first.

Both launch Python through `system()` (not MATLAB's `pyenv`) as either
`"<PythonExe>" "<script>" "<config>"` or
`conda run -n <CondaEnv> "<PythonExe>" "<script>" "<config>"`. Both:

- copy the checked-in driver script into the run folder;
- call `BeforeLaunchFcn` (when given) once every file is written, just before
  launching: it returns when the run may start, and an error from it stops the
  launch. `EphysPipeline.runSorting` waits there for a free slot
  ([Background Kilosort4 runs](EphysPipeline.md#background-kilosort4-runs));
- delete any stale `ks4_status.json` and `ks4_exit.txt` before launching;
- support blocking (`Wait=true`, default) or detached background (`Wait=false`)
  execution.

In blocking mode, output is captured and written to `ks4_run.log` after the
process exits. In background mode, output is redirected to `ks4_run.log` with
`PYTHONUNBUFFERED=1`, and `result.status` is the **launcher's** status, not
Kilosort4's exit code. Either way the Python script writes `ks4_status.json`
(`state` `"done"` or `"error"`) when it finishes. A background run also
leaves an empty `ks4_exit.txt` (`EphysDataset.SortExitMarker`) next to it
once the process has exited, for any reason. `[state, message] =
EphysDataset.sortRunState(statusFile)` reads both. It returns `"running"`
until the status file is complete. It returns `"done"` / `"error"` from the
status, and `"error"` when the process exited without writing a status (a
missing Python or conda env, a crash).

#### `result = runSpikeInterface(Name=Value)`

This path writes no `.bin`. It writes `si_config.json` and a copy of
[`run_si_ks4.py`](../pipeline/@EphysDataset/run_si_ks4.py) into `kilosortDir()`
(`<outputFolder>/kilosort4`) and runs it. The script reads the raw recording with
SpikeInterface, attaches the probe, applies the `SIConfig` preprocessing plus
artifact silencing, and runs Kilosort4 via `run_sorter` into `<kilosort4>/si`.
Kilosort4's phy files end up in `<kilosort4>/si/sorter_output`. The pipeline is
described step by step in [python-drivers.md](python-drivers.md#run_si_ks4py).

| Option | Default |
| --- | --- |
| `PythonExe`, `CondaEnv`, `ProbeFile` | dataset properties |
| `ExcludeChannels` | `ds.ExcludeChannels` |
| `ResultsDir` | `kilosortDir()` |
| `Fs`, `NChan` | `ds.Fs`, `ds.NumChannels` |
| `SIConfig` | `ds.SIConfig` |
| `ExtraSettings` | `struct()`: Kilosort4 settings passed to `run_sorter` |
| `ArtifactIntervals` | `NaN`: computed by `artifactIntervals()`. `[]` silences nothing |
| `Files` | `ds.Files` |
| `DryRun` | `false`: write config + script and build the command without launching |
| `Wait` | `true` |
| `BeforeLaunchFcn` | `[]`: called just before launching (see above) |

- If `SIConfig.CommonReference` is on and `ExtraSettings` has no `do_CAR`,
  `do_CAR=false` is added so Kilosort4 does not re-reference.
- Computing `ArtifactIntervals` with `ArtifactConfig.Enabled` scans the **whole
  recording in MATLAB** before Python is launched, even for a background run.
- `result` fields: `status`, `command`, `stdoutLog`, `scriptPath`,
  `settingsPath` (the `si_config.json`), `resultsDir` and `runDir` (both the
  `kilosort4` folder), `sorterDir`, `probeFile`, `excludeChannels`, `dryRun`,
  `wait`, `statusFile`, `background`.

#### Default SpikeInterface configuration

`EphysDataset.defaultSIConfig()` (the fields map to `si_config.json`
`preprocessing`):

| Field | Default | Meaning |
| --- | --- | --- |
| `Filter` | `false` | `bandpass_filter` before sorting (off: Kilosort4 high-passes internally) |
| `FilterFreqMin` / `FilterFreqMax` | `300` / `6000` Hz | band edges |
| `CommonReference` | `false` | global `common_reference` |
| `ReferenceOperator` | `"median"` | or `"average"` |
| `DetectBadChannels` | `true` | run `detect_bad_channels` |
| `BadChannelMethod` | `"coherence+psd"` | also `"std"`, `"mad"`, `"neighborhood_r2"` |
| `BadChannelAction` | `"remove"` | or `"interpolate"` |

`normalizeSIConfig(cfg)` fills missing fields and drops unknown ones.

#### `result = runKilosort(Name=Value)` (native `.bin` engine)

Unless `DryRun=true` or `BinFile` names an existing `.bin`, it first writes the
recording to `ds.BinFile` with `toBin(ArtifactIntervals=iv)`, zeroing the
artifact intervals (`ArtifactIntervals`, else `artifactIntervals()`). It then
writes `settings.json` and a copy of
[`run_ks4.py`](../pipeline/@EphysDataset/run_ks4.py) into `ResultsDir` (default
`kilosortDir()`) and calls `kilosort.run_kilosort`. The phy output lands
directly in that folder.

- A run into `kilosortDir()` first deletes a SpikeInterface run's `si/`
  subfolder there. Otherwise `kilosortResultsDir` would keep finding the older
  run.
- No SpikeInterface preprocessing applies: `SIConfig`'s filter, bad-channel
  detection and common reference are ignored. Kilosort4 still high-passes and
  references (`do_CAR`) itself.
- The probe's `chanMap` indexes `.bin` rows directly. `runSpikeInterface`
  instead matches probe sites to channels by their native number. So for a
  recording with a channel disabled at acquisition, the probe must already
  account for the gap.
- `run_ks4.py` passes `run_kilosort` arguments found in the settings
  (`do_CAR`, `invert_sign`, `bad_channels`, ...) as arguments, and drops and
  logs any other key Kilosort4 does not recognize.

- `n_chan_bin` and `fs` resolve in this order: options, then the `.bin` JSON
  sidecar, then `NumChannels`/`Fs`.
- `data_dtype` in `settings.json` is `ds.Dtype`. If you wrote the `.bin` with a
  `Dtype=` override, pass a matching dataset `Dtype`.
- The probe channel count is compared with `n_chan_bin`. A mismatch only warns
  (`EphysDataset:runKilosort:ProbeChannelMismatch`).
- Options: `PythonExe`, `CondaEnv`, `ProbeFile`, `ExcludeChannels`, `BinFile`
  (an existing `.bin` to sort as is), `ResultsDir`, `NChanBin`, `Fs`,
  `ExtraSettings` (merged into `settings.json`), `ArtifactIntervals` (`NaN` =
  `artifactIntervals()`, `[]` = none), `DryRun`, `Wait`, `BeforeLaunchFcn`
  (called once the `.bin` and `settings.json` are written, just before
  launching).
- `result` fields: `status`, `command`, `stdoutLog`, `scriptPath`,
  `settingsPath`, `resultsDir` and `runDir` (the same folder), `binFile`, `probeFile`, `excludeChannels`,
  `nExcludedChannels`, `dryRun`, `wait`, `statusFile`, `background`.

#### Channel exclusions

`ExcludeChannels` holds 1-based indices of the recording's amplifier channels
(the `.bin` row order). How they are applied depends on the engine:

- **`runKilosort`** writes `<probe>_excluded.json` into the results folder with
  every probe site whose `chanMap + 1` is in the list removed from `chanMap`,
  `xc`, `yc` and `kcoords`. `n_chan` is unchanged, the channels stay in the
  `.bin`, and the original probe file is not modified.
- **`runSpikeInterface`** passes them as 0-based positions (`exclude_channels`)
  to `run_si_ks4.py`. The script **unions** them with the automatically detected
  bad channels and applies `SIConfig.BadChannelAction` to all of them. So with
  `"interpolate"`, manually excluded channels are interpolated, not removed. If
  the union covers every channel, nothing is removed and a warning is logged.

#### Sorted output

- `kilosortDir()` returns `<outputFolder>/kilosort4`, where both engines write
  their bookkeeping.
- `kilosortResultsDir()` returns the first of these that contains `params.py`:
  `<kilosort4>/si/sorter_output`, `<kilosort4>/sorter_output`, `<kilosort4>`.
  If none does, it returns `kilosortDir()`.
- `sortingResultsDir()` is the folder **associated** with the dataset:
  `SortingDir` when set (a folder you chose, anywhere; the GUI's **Use
  folder...**), else `kilosortResultsDir()`. The manifest records it as
  `sorting` with `source` `"manual"` / `"auto"`, and a manual folder is
  restored on the next scan as long as its `params.py` still exists.
- `hasPhyOutput()` is true when that folder has `params.py`;
  `hasKilosortResults()` when it has `spike_clusters.npy`.
- `EphysDataset.resolvePhyDir(folder)` (static) accepts a dataset folder, a
  `kilosort4` folder or the results folder itself and returns the one holding
  `params.py`.

#### Reading sorted units

**`units = EphysDataset.readPhyUnits(resultsDir, Name=Value)`** (static) is the
one reader of phy-format sorter output; **`units = ds.readSortedUnits(...)`**
wraps it with the dataset's defaults (`sortingResultsDir()`, `Fs` as the
fallback rate, the probe file and channel numbers for the channel mapping,
the native channel names, and `unitIdentity()` for the labels). The Review tab,
`ChronuxDataset.spikes`, `spikesToMat` and both exporters all read through it,
so they agree on labels, times, channels and notes.

| Option | Default | Meaning |
| --- | --- | --- |
| `Groups` | `[]` (all) | keep only clusters with these labels, e.g. `["good" "mua"]` (errors when no label table exists) |
| `IncludeNoise` | `false` | keep clusters labelled `noise` |
| `Templates` | `true` | read `templates.npy` for the peak channel and waveform |
| `FullTemplates` | `false` | also return every unit's `[nS x nChan]` template |
| `ChannelMap` | worked out from the run | `[1 x nChanSorted]` 1-based recording channel of each sorted channel |
| `ChannelNumbers`, `ProbeFile` | dataset's (`0..n_chan-1` without) | map SpikeInterface runs back to recording channels: the probe's `chanMap` values are matched to channel numbers, as `run_si_ks4.py` does |
| `ChannelNames` | dataset's native names | fill the `channelName` column |
| `FsFallback` | `NaN` (error) | rate to use, with a warning, when `params.py` has no `sample_rate`; never a silent 30 kHz |
| `Identity` | `struct([])` | `subject`, `recordingStart`, `labelSuffix`, `datasetKey` of the recording (`readSortedUnits` passes `unitIdentity()`); empty = labels without the recording |

`units` is one scalar struct with column-aligned fields, one row per unit:

| Field | Meaning |
| --- | --- |
| `unitId` | cluster id in `spike_clusters.npy` |
| `label` | `<class><id>_<subject>_<yyMMdd>T<HHmm>`, e.g. `su042_1255_260908T1039` (the id has at least 3 digits); just `<class><id>` without an `Identity` |
| `class` | `su` (phy `good`), `mua`, `noise`, `uns` (`unsorted` or blank), `other` (any other phy label; warning `EphysDataset:readPhyUnits:OtherGroup`) |
| `group` | the phy / Kilosort label as written (`good` / `mua` / `noise` / `unsorted` / other) |
| `notes` | text from `cluster_notes.tsv` next to the sort (`""` when none); see [Unit notes](#unit-notes) |
| `subject`, `recordingStart`, `datasetKey` | the recording the unit came from (`""` / `NaT` / `""` without an `Identity`) |
| `channel`, `channelName`, `channelNumber` | 1-based peak **recording** channel, its native name (`"A-012"`, `"CH13"`; `""` without `ChannelNames`) and its hardware number (the probe `chanMap` value; `NaN` without `ChannelNumbers`) |
| `ksChannel` | peak channel among the sorted channels |
| `shank` | from `channel_shanks.npy` (0 when absent) |
| `peakX`, `peakY` | site position of the peak channel (probe units, µm) from `channel_positions.npy` |
| `x`, `y` | template centre: site positions weighted by the template's peak-to-peak amplitude, over the channels on the peak channel's shank with at least 25% of the peak amplitude (`NaN` without templates or positions) |
| `nSpikes`, `samples`, `times` | spike count, 0-based int64 samples, `samples / fs` (recording-relative) |
| `amplitude`, `contamPct` | `cluster_Amplitude.tsv` (else median `amplitudes.npy`), `cluster_ContamPct.tsv` |
| `templateWaveform`, `templateFull`, `templateTimeMs` | peak-channel template (unwhitened when possible, scaled by the median amplitude), every channel's template (`FullTemplates`), time axis |

Plus per-run scalars `fs`, `resultsDir`, `engine`,
`groupSource` (`"phy"` when `cluster_group.tsv` exists, else `"kilosort"` from
`cluster_KSLabel.tsv`, else `"none"`), `curated`, `labelFile`, `durationSec`,
`nChannelsSorted`, `channelMap`, `channelMapSource` (`"manual"`, `"probe"`,
`"channel_map.npy"` or `"identity"`), `readAt`. A second output carries the
per-spike arrays for plotting. Error identifiers:
`EphysDataset:readPhyUnits:NoResultsDir` / `NoOutput` / `NoSampleRate` /
`Mismatch` / `NoClusterLabels` / `NoGroupMatch` / `BadIdentity`.

Raw waveforms at the sorted spike times are not extracted; `templateWaveform`
is the template. [`unitTable`](../pipeline/unitTable.m) turns one or more
`units` structs or saved files into a table (see
[Unit labels](EphysPipeline.md#unit-labels)).

#### Unit labels

A unit label names the recording as well as the cluster, so a unit taken out of
its file still leads back to its recording:

```text
su042_1255_260908T1039
|  |   |    |      `-- recording start, to the minute (yyMMdd T HHmm)
|  |   |    `--------- date
|  |   `-------------- subject
|  `------------------ cluster id, at least 3 digits
`--------------------- class: su | mua | noise | uns | other
```

- **`id = EphysDataset.nameIdentity(name, pattern)`** (static, never throws)
  parses the name with [`parseNameTokens`](../pipeline/parseNameTokens.m). It
  returns `subject`, `recordingStart` (datetime, to the second), `labelSuffix`
  (`"<subject>_<yyMMdd>T<HHmm>"`), `ok`, `reason` (`""`, `"pattern"`,
  `"nomatch"`, `"subject"` or `"datetime"`) and `message`.
- The pattern needs a `SubjectID` token and `Date` + `Time` tokens whose
  datetime formats give year, month, day, hour (`H`) and minute. Two-digit
  years are 2000-2099. The subject may not contain `_` or white space.
- A lab-wide subject prefix is written as literal text so it stays out of the
  label: `"SUBJ-ID-{SubjectID}_{Date:yyMMdd}_{Time:HHmmss}"` gives
  `SUBJ-ID-1255_260908_103949` the subject `1255`.
- **`id = ds.unitIdentity()`** applies `NamePattern` to `Name` and adds
  `datasetKey`. When the name cannot label units it throws
  `EphysDataset:unitIdentity:Pattern` / `NoMatch` / `Subject` / `DateTime`;
  `readSortedUnits` calls it before reading any sorter output, so units are
  never written without their recording.
- The recording time comes from the name (Intan RHX names files from the
  recording start), not from `AcqDate`, which is a file time.
- Two recordings of one subject that start in the same minute would share
  labels. `EphysProject.unitIdentities` reports them as `collision`, and the
  pipeline's `plan()` stops the steps that would write those units.

#### Unit notes

Per-unit notes live next to the sort in `cluster_notes.tsv`, phy's format for a
custom cluster label (a header `cluster_id<TAB>notes`, then one row per
cluster). Type them in phy (label a cluster with the field `notes`) or in the
Notes column of the app's Review tab; every read picks them up as
`units.notes`.

- **`file = EphysDataset.writeUnitNotes(resultsDir, unitIds, notes)`** sets the
  notes of those clusters, keeps the other rows, turns tabs and line breaks
  into spaces and removes the row of an empty note.
- **`[ids, notes, file] = EphysDataset.readUnitNotes(resultsDir)`** reads them
  (empty outputs when there is no file).

### Derived signals (the `intan2matlab` processing)

**`[Y, ev, info] = deriveSignals(Name=Value)`** reads the whole recording through
`readData` (single precision; any layout) and derives the requested signals.
`intan2matlab` is a thin wrapper around it. The full option list, processing
order and outputs are documented in [intan2matlab.md](intan2matlab.md).

**`out = toMat(Name=Value)`** runs `deriveSignals` and saves `Y`, `events`,
`info` and a `conversion` provenance struct to one MAT-file, or
with `SeparateFiles=true` to one MAT-file per signal type,
`<File without .mat>_<TYPE>.mat` (names from `EphysDataset.signalFiles`). Each
per-type file has the same variables, with `Y` / `info` holding only its signal.

| Option | Default |
| --- | --- |
| `File` | `<outputFolder>/<Name>_extract.mat` (the base name when `SeparateFiles`) |
| `SeparateFiles` | `false`: one file; `true`: one file per signal type |
| `SignalOptions` | `struct()`: `deriveSignals` options |
| `MatVersion` | `"-v7.3"` (or `"-v7"`) |
| `Overwrite` | `false`: error `EphysDataset:toMat:Exists` if any output file exists |
| `ProgressFcn` | none: `ProgressFcn(nDone, nTotal, message)`, with the save counted as one extra step |

`out` fields: `file` and `bytes` (one per file written), `seconds`, `matVersion`, `recordingFormat`,
`origFs`, `signals` (name, nSamples, nChannels, class, Fs), `events` (name,
count), `badChannels`.

**`EphysDataset.saveAtomically(file, S, matVersion)`** (static) is the writer
behind `toMat`, `spikesToMat`, `behaviorToMat` and both exporters: the struct's fields are
saved to `~<name>.partial.mat`, and the file is renamed to the target only
after `save()` finishes **without any warning** and every variable is confirmed
present with `whos -file`. Otherwise the partial file is deleted and an error is
raised (`EphysDataset:toMat:SaveWarning` / `SaveIncomplete`), so a failed or
cancelled run leaves no complete-looking file.

### Spikes file

**`out = spikesToMat(Name=Value)`** writes `<outputFolder>/<Name>_spikes.mat`
with spike events from up to two sources
([schema](file-formats.md#spikes-mat-ephysdatasetspikestomat-the-spikes-step)):

| Option | Default | Meaning |
| --- | --- | --- |
| `Source` | `"detect"` | `"detect"` (threshold detection over the whole recording, one entry per channel), `"sorted"` (the associated units via `readSortedUnits`) or `"both"` |
| `DetectOptions` | `struct()` | `detectSpikes` options (`Filter`, `Band`, `ThresholdMethod`, `Threshold`, `Waveforms`, `WindowMs`, `MaxChunkSamples`, `UseParallel`, `MaxWorkers`, ...) |
| `Channels` | `[]` (all) | 1-based recording channels to detect on, in order |
| `RejectArtifacts` | `true` | drop detected events inside the artifact periods (`ArtifactIntervals`, else `artifactIntervals()`) |
| `ArtifactIntervals` | computed | `[k x 2]` seconds |
| `Groups`, `IncludeNoise`, `Templates` | `["good" "mua"]`, `false`, `true` | sorted-unit options |
| `File`, `MatVersion`, `Overwrite`, `ProgressFcn` | as `toMat` | |

Variables: `detected` (`ts`, `wf`, `info`, `channels`, `channelNames`,
`detection` with the options, the intervals applied and `nRejectedArtifact`
per channel), `units`, `conversion`. Sources not requested are
`[]`; the file is rewritten as a whole. `out`: `file`, `bytes`, `seconds`,
`source`, `nChannels`, `nDetected`, `nRejectedArtifact`, `nUnits`, `matVersion`.

### Exports

**`out = exportChronux(Name=Value)`** writes `<outputFolder>/<Name>_chronux.mat`
([schema](file-formats.md#chronux-export-ephysdatasetexportchronux-the-export-step)):
the derived signals as `LFP` / `MUA` / `SPIKE` structs (`data`, `params`, `t`,
`labels`, `info`, built by [`ChronuxDataset.continuous`](ChronuxDataset.md)),
the sorted units as `sp` (the `mtspectrumpt` input form) and detected spikes
as `spDetected`, plus `units`, `detected`, `events` and `export`.
No Chronux function is called.

**`out = exportFieldTrip(Name=Value)`** writes
`<outputFolder>/<Name>_fieldtrip.mat` with FieldTrip raw / spike / event
structures built by [`FieldTripExport`](FieldTripExport.md). FieldTrip is
never required; with `Validate=true` (default) the structures are checked with
`ft_datatype_raw` / `ft_datatype_spike` when FieldTrip is on the path.

**`E = eventEpochs(Name=Value)`** and **`out = exportEpochs(Name=Value)`** are
the event-organized pair — see
[Event-organized (epoched) data](#event-organized-epoched-data) below.

The Chronux and FieldTrip exporters take the same options:

| Option | Default | Meaning |
| --- | --- | --- |
| `File` | `<Name>_chronux.mat` / `<Name>_fieldtrip.mat` | target |
| `Extract` | `<outputFolder>/<Name>_extract.mat`, else the `<Name>_extract_<TYPE>.mat` files present | other extract file(s) (several are merged), or a `toMat`-shaped struct (`Y`, `events`, `info`) |
| `Signals` | all present | subset of `["LFP" "MUA" "SPIKE"]` |
| `Units` | the associated sorted units | a units struct, or `false` |
| `Groups` | `["good" "mua"]` | phy labels kept when reading units |
| `Detected` | `<Name>_spikes.mat` when present | a spikes file, a `detected` struct, or `false` |
| `Events` | `true` | include the digital-input events |
| `Overwrite`, `MatVersion` | `false`, `"-v7.3"` | |

The two toolboxes are independent: neither export is built from the other,
and nothing analysis-related is run.

#### Event-organized (epoched) data

**`E = eventEpochs(Name=Value)`** cuts the same data into one epoch per event
and returns it as one struct, aligned trial by trial;
**`out = exportEpochs(Name=Value)`** saves that struct as
`<outputFolder>/<Name>_epochs.mat`
([schema](file-formats.md#epoch-export-ephysdatasetexportepochs-the-export-step)),
and the app's **Epochs to workspace** button puts it in the base workspace
without writing a file. It selects and re-packages: the epochs are cut by
[`ChronuxDataset.trials`](ChronuxDataset.md#data-params-t-info--cxtrialsonsets-twin-namevalue)
(continuous) and
[`ChronuxDataset.spikeTrials`](ChronuxDataset.md#data-params-t-info--cxspiketrialsonsets-twin-namevalue)
(spike times), so the sample alignment and the half-open spike window are
exactly the documented ones, and no epoch is dropped by default — a window
that runs past the recording is padded with `NaN` and flagged.

| Field of `E` | Contents |
| --- | --- |
| `event` | `source` (`"line"` / `"behavior"` / `"times"`), `name`, `window`, `onsetRule`, `nEpochs`, `onsets` / `offsets` / `durations`, `recordingRange` (+ its source), `lines`, what the selection dropped, and `pairingStatus` for the behavior source |
| `trials` | table, one row per epoch: `EpochIndex`, `EpochOnset`, `EpochOffset`, `EpochDuration`, `EpochComplete`, plus `EventIndex` (row in the line's event list) or `BehaviorRow` and every behavior trial column |
| `signals` | one struct per signal: `data` `[nTime x nEpochs x nChan]`, `t` (seconds relative to the onset), `fs`, `labels`, `units`, `nIncomplete`, `nNonFinite`, `info` (`keptTrials` names the epochs the data holds) |
| `units` | `1 x nUnits`: `id`, `label`, `class`, `group`, `channel`, `channelName`, `times` (`1 x nEpochs` cell), `counts` |
| `detected` | the same per detected channel (`channel`, `channelName`, `times`, `counts`), or `[]` |
| `spikes`, `behavior`, `meta` | how the spike times are stamped; the session and pairing the events came from; provenance |

| Option | Default | Meaning |
| --- | --- | --- |
| `EventSource` | `"line"` | `"line"` (a digital-input line), `"behavior"` (the paired Epsych2 trials, whose columns ride along), `"times"` (`Times=`, epoched in the order given) |
| `EventLine` | `""` | the line; blank uses `TrialConfig.TrialLine` when the extract has it, else the only line |
| `Behavior` | `<Name>_behavior.mat`, else the associated session with its recorded pairing | a behavior file or a `behaviorStruct`; a pairing that is not approved warns (`EphysDataset:eventEpochs:PairingNotApproved`) |
| `Window` | `[-0.2 0.5]` | `[tPre tPost]` seconds around the onset |
| `OnsetRule` | `"event"` | `"event"` / `"sample"`, as in `ChronuxDataset.trials` |
| `Incomplete` | `"nan"` | window past the recording: pad with `NaN`, `"drop"` or `"error"` |
| `NonFinite` | `"keep"` | epoch with `NaN`/`Inf` samples (blanked artifacts): keep, `"drop"` or `"error"` |
| `SpikeTimeBase` | `"onset"` | `"onset"` (0 at the event), `"window"` (0 at the window start), `"absolute"` |
| `Class` | `"double"` | `"single"` / `"asis"` for the epoched samples |
| `MinDurationSec`, `MaxDurationSec` | `0`, `Inf` | pulse-length filter for the `"line"` source |
| `Extract`, `Signals`, `Units`, `Groups`, `Detected`, `Events` | as above | |
| `File`, `Overwrite`, `MatVersion` (`exportEpochs`) | `<Name>_epochs.mat`, `false`, `"-v7.3"` | |

With `Incomplete="drop"` or `NonFinite="drop"` a signal holds fewer epochs than
the trials table has rows, and its `info.keptTrials` names the rows it kept;
the spike epochs always cover every row.

This is the data itself, organized by event, for an analysis of your own. For
quick-look figures from the same alignment — PSTHs, evoked potentials, tuning,
with trial filtering and grouping — use
[`analysis`](EphysAnalysis.md#event-reference-window-selection), whose
`epochTable` indexes signals with the same event rule (`round(t*Fs)`).

```matlab
E = ds.eventEpochs(EventSource="behavior", Window=[-0.2 0.5]);
lfp = E.signals.LFP.data(:, E.trials.EpochComplete, 1);   % [nTime x nEpochs]
hit = E.trials.ResponseCode == 1;                         % a session column
raster = E.units(3).times(hit);                           % spike times per trial
```

### Behavior (Epsych2)

- `BehaviorFile` is the associated session `.mat` (set by the GUI, by
  `EphysPipeline.checkBehavior`, by a scan, or by hand); it is recorded in the
  manifest (`behavior`: `file`, `subject`, `start_time`, `n_trials`) and
  restored on the next scan if the file still exists.
- `tf = associateFolderBehavior()` sets `BehaviorFile` when none is associated
  (or its file is gone) and the recording folder holds exactly one Epsych2
  session file at its top level (`findEpsychSessions(Folder, Recursive=false)`).
  That is where the app's Copy tab puts a session's ePsych file, or its
  stitched file. With none or several it changes nothing. `EphysProject.refresh`
  calls it after `applyManifest`, so a scan associates copied sessions without
  any `Behavior.SearchDirs`. The behavior, signals, spikes and export outputs
  do not hold `Data` and `Info`, so they are never taken for a session.
- `[trials, info, meta] = readBehavior()` is
  [`readEpsychSession(BehaviorFile)`](EphysPipeline.md#epsych2-sessions).
- `behaviorStruct()` returns `struct(trials, info, meta, file, subject,
  startTime, nTrials)` or `[]`.
- `out = behaviorToMat(File=, MatVersion=, Overwrite=)` saves that struct once,
  as the `behavior` variable of `<outputFolder>/<Name>_behavior.mat` (plus
  `conversion`). It is the only output that carries behavior data: the extract,
  spikes, Chronux and FieldTrip files do not. Errors
  `EphysDataset:behaviorToMat:NoFile` without an associated session and
  `:Exists` when the file exists and `Overwrite` is off. `out`: `file`,
  `bytes`, `seconds`, `behaviorFile`, `nTrials`, `paired`. With `Pairing=P`
  the trials table carries the pairing columns and `behavior.pairing` the summary.
- `E = digitalEvents(LabelField=, LineNames=, Relabel=true, Cache=true, Refresh=false, ProgressFcn=)`
  returns the dig-in `events` (high runs), `Fs`, `nSamples`, `digInNames`
  (the final line names), `digInNativeNames` and `digInDefaultNames` (the
  names without `LineNames`) through `EphysReader.readDigitalEvents`. The
  reader's native-keyed result is cached as `<outputFolder>/<Name>_events.mat`
  (keyed by the reader, the files and the sample count) and the lines are
  named after loading, so renaming a line never re-reads the recording.
  `Relabel=false` returns the native-keyed events.
- `P = pairTrials(Cuts="recorded"|"none"|struct('trials', [s e], 'intervals', [s e]), Events=, Warn=, ProgressFcn=)`
  pairs the session's trials, in order, with `TrialConfig.TrialLine`
  ([`pairEpsychTrials`](EphysPipeline.md#pairing-trials-with-the-trial-line)).
  It reuses the cuts of `TrialPairing` while the fingerprint still matches.
  It adds `status`, `autoApproved`, `recorded`, `stale` and `fingerprint` to
  the result.
- `setTrialPairing(P, "unreviewed"|"approved", Auto=false)` records the cuts
  in the manifest (`Auto=true` marks an approval as automatic);
  `setTrialPairing([])` clears it.
- `[P, tf] = autoApproveTrialPairing(P)` approves and records `P` (marked
  automatic) when it is not approved yet, cuts nothing, and the session has
  as many trials as the trial line has intervals; anything else is left for
  review. `tf` says whether it did. The behavior step and the app call it
  when `Behavior.AutoApprove` is on.

### Processed files (`DatasetOutputs`)

`out = ds.outputs(Name=Value)` returns a [`DatasetOutputs`](DatasetOutputs.md)
that finds this dataset's extract, spikes, behavior, Chronux and FieldTrip
files, sorted units and manifest, and loads each one when its property is read
(`FT = out.FieldTrip`).

### Dataset manifest

The manifest is a JSON state file at `<Folder>/<Name>_manifest.json`, i.e. in the
**recording folder**, not `OutputDir`. Its schema (`intan-dataset-manifest/2`)
is in [file-formats.md](file-formats.md#dataset-manifest).

- `manifestFile()` returns the path.
- `manifestStruct()` builds the snapshot: metadata, reader, probe, exclusions,
  manual artifact periods, `.bin` state, the latest Kilosort4 run from
  `tracker()`, the sorted-output association (`sortingStruct()`), the behavior
  association (`behaviorManifest()`), and the SpikeInterface config.
- `writeManifest()` writes it atomically (`writeJsonFile`). Failures only warn
  (`EphysDataset:writeManifest:Failed`).
- `applyManifest()` restores `ProbeFile` (if the file still exists),
  `ExcludeChannels`, `ManualArtifacts`, a manual `SortingDir` (if its
  `params.py` still exists) and `BehaviorFile` (if the file exists). Header
  metadata is always re-parsed. `ArtifactConfig` and `SIConfig` are not stored
  here; they belong to the [pipeline config](EphysPipeline.md). Schema `/1`
  manifests (probe + exclusions only) are still read.

### Other helpers

| Method | Returns |
| --- | --- |
| `outputFolder()` | `OutputDir`, or `Folder` when `OutputDir` is `""` |
| `tracker()` | a [`DatasetTracker`](DatasetTracker.md) of `outputFolder()` (an empty tracker if the folder does not exist yet) |
| `EphysDataset.detectFormat(folder, ReaderOptions=)` | layout string (static; asks the reader registry) |
| `EphysDataset.relabelEvents(E, labelField, lineNames)` | events named as [above](#digital-line-names) (static) |
| `EphysDataset.parseLineNames(list)` | `[natives, names]` of `"native=name"` entries (static) |
| `EphysDataset.resolveFilterOptions(cfg, opts)` | filter options merged over an `ArtifactConfig` (static) |
| `EphysDataset.parseChannelList(s)` | sorted, unique, positive integer row vector from `"1,3,5-8"`, `"1 3 5:8"` or a numeric vector. Hyphens become colons and the text goes through `str2num` |
| `EphysDataset.formatChannelList(ch)` | compact `"1,3,5-8"` string |

---

## Main error identifiers

| Identifier | Raised when |
| --- | --- |
| `EphysDataset:NoFolder` | constructor folder missing |
| `EphysDataset:refreshMetadata:ChannelMismatch`, `EphysDataset:toBin:ChannelMismatch` | amplifier channel count changes between files |
| `EphysDataset:splitLayout:NoHeader` / `NoAmplifier` / `NoChannels` | split recording incomplete |
| `EphysDataset:readData:NoFiles`, `EphysDataset:toBin:NoFiles` | no recording files |
| `EphysDataset:LineNames`, `EphysDataset:relabelEvents:Duplicate` | a malformed `LineNames` entry, or two lines with the same final name |
| `OpenEphysReader:MultipleRecordings` | `"single"` mode and a session with several recordings |
| `OpenEphysReader:NoNode` / `NoStream` / `NoRecording` | the configured Record Node or stream (or a part folder's recording) is not in the session |
| `EphysDataset:readData:BadKeepChannels`, `EphysDataset:toBin:BadChannelOrder` | channel index out of range |
| `EphysDataset:filterContinuous:CutoffAboveNyquist` | cutoff ≥ Fs/2 |
| `EphysDataset:detectSpikes:BandAboveNyquist` | spike-detection band upper edge ≥ Fs/2 |
| `EphysDataset:detectSpikes:NoThreshold` / `BadThreshold` / `BadPercentile` | `Threshold` missing or out of range for the chosen `ThresholdMethod` |
| `EphysDataset:detectSpikes:RowVector` / `BadWindow` / `BadBand` | `X` passed as a row vector, or a reversed `WindowMs` / `Band` |
| `EphysDataset:detectSpikes:NoData` / `NoFiles` / `NoAmplifierData` | `detectSpikes()` with no data block on a dataset with no folder, no Intan files, or no amplifier data |
| `EphysDataset:detectSpikes:BlockOption` / `FsNotAllowed` | a whole-recording option passed with a data block, or `Fs` passed without one |
| `EphysDataset:detectSpikes:BadChannelOrder` / `ChannelMismatch` | `ChannelOrder` out of range, or the channel count changes between chunks |
| `EphysDataset:runKilosort:NoPython` / `NoProbe` / `ProbeMissing` / `BinMissing` | run prerequisites missing |
| `EphysDataset:runKilosort:MostlySilenced` | the artifact intervals cover more than `MaxSilencedFraction` of the recording |
| `EphysDataset:BadArtifactIntervals` | an `ArtifactIntervals` option that is not `[k x 2]` |
| `EphysDataset:runSpikeInterface:NoPython` / `NoProbe` / `ProbeMissing` | run prerequisites missing |
| `EphysDataset:toMat:Exists` / `SaveWarning` / `SaveIncomplete` | `.mat` output refused or discarded (also used by `saveAtomically`) |
| `EphysDataset:spikesToMat:Exists`, `EphysDataset:exportChronux:Exists`, `EphysDataset:exportFieldTrip:Exists` | target file exists and `Overwrite` is off |
| `EphysDataset:readPhyUnits:NoResultsDir` / `NoOutput` / `NoSampleRate` / `Mismatch` / `NoClusterLabels` / `NoGroupMatch` | sorted output missing or inconsistent |
| `EphysDataset:readPhyUnits:BadIdentity` | an `Identity` struct without `subject`, `recordingStart`, `labelSuffix` and `datasetKey` |
| `EphysDataset:unitIdentity:Pattern` / `NoMatch` / `Subject` / `DateTime` | the dataset name cannot label sorted units (see [Unit labels](#unit-labels)) |
| `EphysDataset:writeUnitNotes:Size` / `NoResultsDir` / `Write` | notes and ids do not pair up, or the notes file cannot be written |

## Tests

[`test_EphysDataset.m`](../pipeline/test_EphysDataset.m) builds synthetic `*.rhd`,
split-layout, binary, phy and Epsych2 fixtures in a temp folder (the fixture
builders in [`pipeline/private`](../pipeline/private) are shared by every suite) and
deletes them afterwards. It covers:

| Section (as printed by the test) | Covers |
| --- | --- |
| 1-2 | `refreshMetadata` + header-only parse |
| 3 | `readData` (concatenation + events) |
| 4 | `toBin` streaming vs `matrix2kilosort` byte identity |
| 5 | `.bin` → microvolts round-trip |
| 6 | `filterContinuous` + `detectArtifacts` |
| 7 | `EphysProject` discovery |
| 8 | `runKilosort(DryRun=true)` |
| 9 | `DatasetTracker` integration |
| 10 | split layouts (metadata, `readData`, byte-correct `toBin`) |
| 11 | `artifactIntervals` (manual merge + automatic streaming; parallel == serial, `MaxWorkers=1` fall-back) |
| 12 | `runSpikeInterface(DryRun=true)` |
| 13 | `detectSpikes` (injected troughs: alignment, thresholds, polarity, minimum period, waveforms, edges, guards) |
| 14 | `detectSpikes` over a whole recording (streamed in 6 chunks: identical to the single-block result, boundary-straddling waveforms, `ChannelOrder`, `ProgressFcn`, guards, `UseParallel` / `MaxWorkers`, worker errors, cancel, parallel `artifactIntervals` / `analyzeArtifacts` over split chunks) |
| 15 | `writeJsonFile` / `readJsonFile`, manifest v2 round trip (manual periods, sorting, behavior), v1 manifests, `sortingResultsDir` precedence, `EphysProject` keys and `refresh`, including `associateFolderBehavior` (one file associated, two left alone, an existing association kept) |
| 16 | the `ArtifactConfig` pre-detection filter (preview and `artifactIntervals` agree; single-chunk `UseParallel` is silent) |
| 17 | `readPhyUnits` / `readSortedUnits` (times = samples/fs, phy labels beat Kilosort labels, groups, channel mapping, `FsFallback`) |
| 18 | `spikesToMat` (detected + sorted, artifact rejection, waveforms, unit labels and identity saved, no behavior variable, no partial file left) |
| 19 | the reader registry, `BinaryReader` (same microvolts through `readData`, `streamPlan` / `readChunkUV` and `readWindowUV`), discovery of both kinds, `siRecordingSpec` |

[`test_OpenEphysReader.m`](../pipeline/test_OpenEphysReader.m) writes Open
Ephys sessions in every record engine (and the GUI 0.5 file names) with the
synthetic writers and covers metadata, exact samples across recordings and
gaps, TTL intervals per format, AUX and ADC, discovery, record node / stream
selection, the three recording modes, line naming and the events cache, a
synthetic Open Ephys project through `EphysPipeline`, and (with the kilosort
environment) `run_si_ks4.py` loading the same samples.
| 20 | `exportChronux` / `exportFieldTrip`, `readBehavior` / `behaviorStruct` / `behaviorToMat` |

[`test_UnitLabels.m`](../pipeline/test_UnitLabels.m) covers unit labels:
`parseNameTokens` formats, `nameIdentity`, class and id padding, identity
columns, peak site and template centre, notes, `readSortedUnits` identity
errors, `EphysProject` pattern push and collisions, and `unitTable`.

It needs no real recording data and no Kilosort4 install. Run every suite with
[`run_all_tests.m`](../pipeline/run_all_tests.m).
