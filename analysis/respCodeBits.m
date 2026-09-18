function [bits, words] = respCodeBits()
%respCodeBits  Epsych2 response-code bit of each response word.
%   [BITS, WORDS] = respCodeBits() returns a struct mapping each response
%   word to its bit in the trials' RespCode (ResponseCode) bit mask, and the
%   words in order:
%
%     Hit 1, Miss 2, CR 4, FA 8, Reward 32, Punish 64, NoResponse 128,
%     Response 256
%
%   A trial "is" a word when bitand(RespCode, bit) > 0. trialSelection's
%   response list and the words in a filter expression use these.
%
%   See also trialSelection, selectTrials, makeSyntheticRecording.

words = ["Hit" "Miss" "CR" "FA" "Reward" "Punish" "NoResponse" "Response"];
values = [1 2 4 8 32 64 128 256];
bits = cell2struct(num2cell(values), cellstr(words), 2);
end
