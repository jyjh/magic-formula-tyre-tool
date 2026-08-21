function plan = buildfile
%BUILDFILE Build plan for MATLAB build tool (buildtool).
%   buildtool           Run the default "test" task.
%   buildtool test      Run the app and library unit tests.
%   buildtool package   Build MagicFormulaTyreTool.mltbx (runs "test" first).

    plan = buildplan(localfunctions);
    plan("package").Dependencies = "test";
    plan.DefaultTasks = "test";

end

function testTask(task) %#ok<INUSD>
    %Run the app tests (+tests at the repository root) and the library
    %tests (+tests in the magic-formula-tyre-library submodule).
    root = fileparts(mfilename('fullpath'));

    %App code and the vendored library both live under src/. The app path
    %must stay flat (genpath would pull the submodule's +tests and doc
    %folders onto the path); the library needs genpath because it keeps
    %enums in src/enum.
    addpath(fullfile(root, 'src'));
    addpath(genpath(fullfile(root, 'src', 'magic-formula-tyre-library', 'src')));

    %Build the suites from folders, not fromPackage("tests"): the app and
    %the library both define a +tests package, and in development
    %sessions both are on the path (MATLAB project paths), which would
    %merge the two suites into one.
    appSuite = matlab.unittest.TestSuite.fromFolder( ...
        fullfile(root, '+tests'), IncludeSubfolders=true);
    appResults = run(appSuite);

    %FitterTest resolves its data fixtures with paths relative to the
    %library root, so the library suite must run with that folder as the
    %current folder.
    libRoot = fullfile(root, 'src', 'magic-formula-tyre-library');
    cwd = cd(libRoot);
    cleanup = onCleanup(@() cd(cwd));

    libSuite = matlab.unittest.TestSuite.fromFolder( ...
        fullfile(libRoot, '+tests'));
    libResults = run(libSuite);

    assertSuccess([appResults(:); libResults(:)]);

    clear cleanup
end

function packageTask(task) %#ok<INUSD>
    %Build MagicFormulaTyreTool.mltbx. buildToolbox.m is a script that
    %packages from the current folder; buildtool tasks run with the plan
    %folder as current folder.
    buildToolbox();
    if ~isfile('MagicFormulaTyreTool.mltbx')
        error('MagicFormulaTyreTool:packageFailed', ...
            'Toolbox packaging did not produce MagicFormulaTyreTool.mltbx.')
    end
end
