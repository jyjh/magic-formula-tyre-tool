addpath(genpath('d:\Documents\GitHub\magic-formula-tyre-tool\src\magic-formula-tyre-library\src'));
parser = tydex.parsers.FSAETTC_SI_ISO_Mat();
file1 = 'D:\Downloads\RunData_Cornering_Matlab_SI_Round9\B2356run31.mat';
file2 = 'D:\Downloads\RunData_Cornering_Matlab_SI_Round9\B2356run32.mat';
file3 = 'D:\Downloads\RunData_DriveBrake_Matlab_SI_Round9\B2356run72.mat';
file4 = 'D:\Downloads\RunData_DriveBrake_Matlab_SI_Round9\B2356run73.mat';

disp('Parsing data...');
m1 = parser.run(file1);
m2 = parser.run(file2);
m3 = parser.run(file3);
m4 = parser.run(file4);
m = [m1, m2, m3, m4];
m = m.downsample(10, 0);

disp('Setting up fitter...');
f = magicformula.v61.Fitter();
f.Measurements = m;
f.FitModes = [
    magicformula.FitMode.Fx0
    magicformula.FitMode.Fy0
    magicformula.FitMode.Fx
    magicformula.FitMode.Fy
    magicformula.FitMode.Mz0
    magicformula.FitMode.Mz
    magicformula.FitMode.Mx
];

p = magicformula.v61.Parameters();
p.FNOMIN.Value = m(1).ModelParameters(1).Value;
p.NOMPRES.Value = m(1).ModelParameters(2).Value;
p.UNLOADED_RADIUS.Value = 0.22;
f.Parameters = p;

f.Options.Display = 'final';

try
    disp('Running fit...');
    f.run();
    disp('Fit completed!');
    
    % Evaluate cost manually to see if it's bad
    % But wait, cost is internal to fitter. We can just see if it warns or fails.
catch ME
    disp(getReport(ME));
end
