function [first, words] = blockLayout(hdr)
%blockLayout  Where each signal sits in a data block of a traditional *.rhd file.
%   [FIRST, WORDS] = IntanReader.blockLayout(HDR) takes parseIntanHeader's
%   struct and returns, for the signals in the order a block holds them
%   (timestamps, amplifier, aux, supply, temp, adc, digIn, digOut), the
%   number of 16-bit words each takes in a block (WORDS) and the words before
%   it (FIRST). A block holds one 32-bit timestamp per sample (2 words); the
%   amplifier samples channel by channel (spb words each); the aux samples
%   channel by channel (spb/4 each); one supply-voltage word and one
%   temperature word per channel; the ADC samples channel by channel; spb
%   digital-input words (when the file has input lines) and spb
%   digital-output words (when it has output lines). So the digital-input
%   words of block b start at byte
%   HDR.headerBytes + b*HDR.bytesPerBlock + 2*FIRST(7).
%
%   See also IntanReader.sliceDataBlocks, IntanReader.readDigitalEvents.

spb = hdr.numSamplesPerDataBlock;
words = [2 * spb, ...                                   % timestamps (2 words each)
         spb * hdr.numAmplifierChannels, ...
         spb / 4 * hdr.numAuxInputChannels, ...
         hdr.numSupplyVoltageChannels, ...
         hdr.numTempSensorChannels, ...
         spb * hdr.numBoardADCChannels, ...
         spb * (hdr.numBoardDigInChannels > 0), ...
         spb * (hdr.numBoardDigOutChannels > 0)];
first = cumsum([0 words(1:end-1)]);                     % words before each signal in a block
end
