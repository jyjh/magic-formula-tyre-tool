%BUILDTOOLBOX Package MagicFormulaTyreTool.mltbx from the repository root.
%Run by "buildtool package". The toolbox version comes from
%src/about.json; CI overrides it via the MFTT_TOOLBOX_VERSION
%environment variable so every push to main can publish a uniquely
%versioned build. The override is also written back into src/about.json
%so the packaged app reports the release version in its About dialog and
%update check.

aboutFile = fullfile(pwd, 'src', 'about.json');
versionOverride = strtrim(getenv('MFTT_TOOLBOX_VERSION'));
if ~isempty(versionOverride)
    about = jsondecode(fileread(aboutFile));
    about.Version = versionOverride;
    fileId = fopen(aboutFile, 'w');
    try
        fprintf(fileId, '%s\n', jsonencode(about, 'PrettyPrint', true));
        fclose(fileId);
    catch ME
        fclose(fileId);
        rethrow(ME)
    end
end

opts = matlab.addons.toolbox.ToolboxOptions(pwd, 'MagicFormulaTyreTool');
opts.ToolboxName = 'MagicFormulaTyreTool';
opts.ToolboxVersion = jsondecode(fileread(aboutFile)).Version;
opts.Summary = 'MATLAB GUI for Magic Formula Tyre Modeling';
opts.Description = 'https://github.com/jyjh/magic-formula-tyre-tool';
opts.ToolboxImageFile = fullfile(pwd, 'assets', 'img', 'App_Screenshot_Main.jpg');
opts.ToolboxGettingStartedGuide = fullfile(pwd, 'doc', 'GettingStarted.mlx');
opts.OutputFile = fullfile(pwd, 'MagicFormulaTyreTool.mltbx');
opts.SupportedPlatforms.Win64 = true;
opts.SupportedPlatforms.Maci64 = true;
opts.SupportedPlatforms.Glnxa64 = true;
opts.SupportedPlatforms.MatlabOnline = true;
%Package the runtime payload explicitly: src/ carries the app code and
%the pinned library submodule (vendored, because an installed toolbox
%cannot clone submodules), assets/ holds the icon files the UI resolves
%from the MATLAB path. Repo internals (.git, .github, resources/,
%+tests, build scripts) are deliberately not listed.
toolboxFiles = { ...
    fullfile(pwd, 'src'), ...
    fullfile(pwd, 'assets'), ...
    fullfile(pwd, 'doc'), ...
    fullfile(pwd, 'CHANGELOG.md'), ...
    fullfile(pwd, 'LICENSE'), ...
    fullfile(pwd, 'README.md') ...
};
% The bundled app installer is built locally with matlab.apputil.package
% and is not version-controlled, so skip it when absent; CI must be able
% to package from a clean checkout.
appInstaller = fullfile(pwd, 'MagicFormulaTyreTool.mlappinstall');
if isfile(appInstaller)
    toolboxFiles = [toolboxFiles, {appInstaller}];
end
opts.ToolboxFiles = toolboxFiles;
matlab.addons.toolbox.packageToolbox(opts);
