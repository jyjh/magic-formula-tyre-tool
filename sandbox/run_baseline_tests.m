% Establish baseline: run the full fitter test suite.
toolroot = 'D:\Documents\GitHub\magic-formula-tyre-tool';
addpath(genpath(fullfile(toolroot,'src','magic-formula-tyre-library','src')));
addpath(fullfile(toolroot,'src','magic-formula-tyre-library'));
warning('off','MATLAB:nearlySingularMatrix');
r1 = runtests('tests.FitterReliabilityTest');
r2 = runtests('tests.FitterTest');
allr = [r1; r2];
disp(table(allr));
fprintf('Passed %d / %d\n', sum([allr.Passed]), numel(allr));
if ~all([allr.Passed]); disp('SOME TESTS FAILED'); end
