function out = testbench_LiveCrossover
% TESTBENCH_LIVECROSSOVER Exercise audio plugin class
% to check for violations of plugin constraints and other errors.
%
% OUT = TESTBENCH_LIVECROSSOVER Return the output data from the
% plugin. This is useful to verify that plugin numeric behavior has not
% changed, when you are changing your plugin in ways that should not
% affect that behavior (eg, refactoring code).
%
% You can test whether your MATLAB plugin code is ready for code
% generation by creating and running a mex function from this testbench:
%
%   codegen testbench_LiveCrossover    % Create the mex function
%   testbench_LiveCrossover_mex        % Run the mex function
%
% You can use this testbench as a template and edit it to meet your
% testing needs. Rename the file to ensure your work is not
% accidentally overwritten and lost by another run of
% validateAudioPlugin.
%
% Automatically generated by validateAudioPlugin 27-Feb-2024 18:58:47 UTC-06:00

% Set basic test parameters
sampleRates = [44100, 48000, 96000, 192000, 32000];
frameSizes = [ 2.^(1:13) 2.^(2:13)-1 2.^(1:13)+1];
totalFrameSize = sum(frameSizes);

% Create output buffer if requested
if nargout > 0
    nout = 2;
    obuf = zeros(totalFrameSize*numel(sampleRates), nout);
    optr = 1;
end

% Instantiate the plugin
plugin = LiveCrossover;
setup(plugin, zeros(2, 2));

% Test at each sample rate
for sampleRate = sampleRates
    paramState = initParamState(plugin);
    
    % Tell plugin the current sample rate
    setSampleRate(plugin, sampleRate);
    reset(plugin);
    checkForTampering(plugin, paramState, sampleRate, 'Resetting plugin');
    
    % Create input data: logarithmically swept sine waves, with a
    % different initial phase for each channel
    phaseOffsets = (0:1)/1 * 0.5 * pi;
    ibuf = logchirp(20, 20e3, sampleRate, totalFrameSize, phaseOffsets);
    iptr = 1;
    
    % Process data using different frame sizes
    for i = 1:numel(frameSizes)
        samplesPerFrame = frameSizes(i);
        
        val = fromNormalizedLowCutoff(mod(floor((i-1)./1),3)/2);
        plugin.LowCutoff = val;
        paramState.LowCutoff = val;
        checkForTampering(plugin, paramState, sampleRate, ...
            'Setting parameter ''LowCutoff''');
        
        val = fromNormalizedHighCutoff(mod(floor((i-1)./3),3)/2);
        plugin.HighCutoff = val;
        paramState.HighCutoff = val;
        checkForTampering(plugin, paramState, sampleRate, ...
            'Setting parameter ''HighCutoff''');
        
        val = fromNormalizedLowSlope(mod(floor((i-1)./9),3)/2);
        plugin.LowSlope = val;
        paramState.LowSlope = val;
        checkForTampering(plugin, paramState, sampleRate, ...
            'Setting parameter ''LowSlope''');
        
        val = fromNormalizedHighSlope(mod(floor((i-1)./27),3)/2);
        plugin.HighSlope = val;
        paramState.HighSlope = val;
        checkForTampering(plugin, paramState, sampleRate, ...
            'Setting parameter ''HighSlope''');
        
        % Get a frame of input data
        in = ibuf(iptr:iptr+samplesPerFrame-1, :);
        iptr = iptr + samplesPerFrame;
        
        % Run the plugin
        o1 = step(plugin, in(1:samplesPerFrame,1:2));
        
        % Save the output data if requested
        if nargout > 0
            obuf(optr:optr+samplesPerFrame-1, :) = o1;
            optr = optr + samplesPerFrame;
        end
        
        % Verify class and size of outputs
        if ~isa(o1, 'double')
            error('ValidateAudioPlugin:OutputNotDouble', ...
                ['Output 1 is of class %s, ' ...
                'but should have been double.'], ...
                class(o1));
        end
        if size(o1,1) ~= samplesPerFrame
            error('ValidateAudioPlugin:BadOutputFrameSize', ...
                ['Output 1 produced a frame size of %d, ' ...
                'but should have matched the input frame size of %d.'], ...
                size(o1,1), samplesPerFrame);
        end
        if size(o1,2) ~= 2
            error('ValidateAudioPlugin:BadOutputWidth', ...
                ['Width of output 1 was %d, ' ...
                'but should have been 2 (OutputChannels(1)).'], ...
                size(o1,2));
        end
        checkForTampering(plugin, paramState, sampleRate, 'Running plugin');
    end
end

% Return output data if requested
if nargout > 0
    out = obuf;
end
end

function checkForTampering(plugin, paramState, sampleRate, cause)
% Verify parameters were not tampered with
if ~isequal(paramState.LowCutoff, plugin.LowCutoff)
    error('ValidateAudioPlugin:ParamChanged', ...
        '%s changed parameter ''LowCutoff'' from %g to %g.', ...
        cause, paramState.LowCutoff, plugin.LowCutoff);
end
if ~isequal(paramState.HighCutoff, plugin.HighCutoff)
    error('ValidateAudioPlugin:ParamChanged', ...
        '%s changed parameter ''HighCutoff'' from %g to %g.', ...
        cause, paramState.HighCutoff, plugin.HighCutoff);
end
if ~isequal(paramState.LowSlope, plugin.LowSlope)
    error('ValidateAudioPlugin:ParamChanged', ...
        '%s changed parameter ''LowSlope'' from %g to %g.', ...
        cause, paramState.LowSlope, plugin.LowSlope);
end
if ~isequal(paramState.HighSlope, plugin.HighSlope)
    error('ValidateAudioPlugin:ParamChanged', ...
        '%s changed parameter ''HighSlope'' from %g to %g.', ...
        cause, paramState.HighSlope, plugin.HighSlope);
end
% Verify sample rate was not tampered with
if ~isequal(getSampleRate(plugin), sampleRate)
    error('ValidateAudioPlugin:SampleRateChanged', ...
        '%s changed sample rate from %g to %g.', ...
        cause, sampleRate, getSampleRate(plugin));
end
end

function y = logchirp(f0, f1, Fs, nsamples, initialPhase)
% logarithmically swept sine from f0 to f1 over nsamples, at Fs
y = zeros(nsamples,numel(initialPhase));
instPhi = logInstantaneousPhase(f0, f1, Fs, nsamples);
for i = 1:numel(initialPhase)
    y(:,i) = sin(instPhi + initialPhase(i));
end
end

function phi = logInstantaneousPhase(f0, f1, Fs, n)
final = n-1;
t = (0:final)/final;
t1 = final/Fs;
phi = 2*pi * t1/log(f1/f0) * (f0 * (f1/f0).^(t') - f0);
end

function paramState = initParamState(plugin)
paramState.LowCutoff = plugin.LowCutoff;
paramState.HighCutoff = plugin.HighCutoff;
paramState.LowSlope = plugin.LowSlope;
paramState.HighSlope = plugin.HighSlope;
end

function val = fromNormalizedLowCutoff(normval)
val = 20 * (20000/20).^normval;
end

function val = fromNormalizedHighCutoff(normval)
val = 20 * (20000/20).^normval;
end

function val = fromNormalizedLowSlope(normval)
val = 0 + (48-0)*normval;
end

function val = fromNormalizedHighSlope(normval)
val = 0 + (48-0)*normval;
end
