this function removes line noise (50/60 Hz) from a (chans/trials x samples) matrix which is sampled at (fs) Hz, and returns the de-noised matrix. This m-file is an implementation and extension of the Spectrum Estimation technique presented in Mewett, Nazeran, and Reynolds. "Removing power line noise from recorded EMG," EMBS, IEEE 2001 (DOI: 10.1109/IEMBS.2001.1017205). The algorithm is:   
1. Pick a window length m such that m is a power of 2 and m samples the line frequency to within some tolerance.   
2. Pad the start and the end of the wave with a (50 Hz) sine wave fitted to the phase and amplitude of the first and last snippets of wave to minimize starting and ending transients.   
2. Using an m-point Hanning (or other) window and the discrete Fourier transform, calculate the averaged m-point spectrum S(w) of the signal in each window and channel/trial.   
3. Estimate the corrected value S'(w) at the frequency of the line noise w and harmonics by interpolating between S(w-dw) and S(w+dw) where dw is the frequency resolution.  
4. In the Fourier transform of the entire signal, replace the magnitude at S(w) with S'(w). The phase remains unchanged.  
5. Finally, take the inverse Fourier transform of this 'corrected' spectrum to give a signal with reduced interference.

The behaviour of the line noise removal algorithm can be controlled by an optional input string, 'opts'. The following options are defined:  
 NH = number of harmonics. (default: 1)  
 LF = line frequency. (default: 50 Hz)  
 TOL = error tolerence. (default: 1% tol)  
 HW = half-width of peak in samples. (default: 2)  
 M = Size of window. (For fs = 1 kHz, m = 1024). If M is set, TOL  
 has no effect.  
 WIN = {hanning,hamming}. Default: hanning.

Example:  
% Remove first 5 harmonics of 60 hz, using a 2048-point hanning window :  
LFP\_wave = removeLineNoise\_SpectrumEstimation(LFP\_wave, 3000, ...

If this file was useful to you, please cite Mewett, et. al.

Authors: Calvin Eiber & Alexander Pietersen  
 e-mail address: calvin.eiber@sydney.edu.au  
 Release: 1.0  
 Release date: 30 November 2015