toolroot = 'D:\Documents\GitHub\magic-formula-tyre-tool';
addpath(genpath(fullfile(toolroot,'src','magic-formula-tyre-library','src')));
addpath(fullfile(toolroot,'src','magic-formula-tyre-library'));
warning('off','MATLAB:nearlySingularMatrix');

% Replicate FitterTest TestClassSetup to see the real error.
try
    parser = tydex.parsers.FSAETTC_SI_ISO_Mat();
    f1 = fullfile(toolroot,'src','magic-formula-tyre-library','doc','examples','fsae-ttc-data','fsaettc_obscured_testbench_cornering.mat');
    m1 = parser.run(f1);
    fprintf('cornering parsed OK: %d measurements\n', numel(m1));
catch ME
    disp(getReport(ME,'extended'));
end
