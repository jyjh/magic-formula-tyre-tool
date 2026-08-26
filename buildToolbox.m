function buildToolbox()
%BUILDTOOLBOX Package MagicFormulaTyreTool.mltbx from the repository root.
%Run by "buildtool package". The toolbox is assembled in a temporary
%staging folder holding only the runtime payload, so that repository
%internals (.git, .github, build scripts, project metadata, tests) and
%the vendored library submodule's repository files stay out of the
%package and the installed MATLAB paths reference only real folders.
%
%The toolbox version comes from src/about.json; CI overrides it via the
%MFTT_TOOLBOX_VERSION environment variable so every push to main can
%publish a uniquely versioned build. The override is written into the
%staged about.json (the working copy stays clean) so the packaged app
%reports the release version in its About dialog and update check.

root = pwd;

% Stable add-on identity. The .mltbx schema types the identifier as a
% GUID, and the add-on framework (including the newer MPM-based
% installer) expects one; free-form strings install unreliably or fail.
% Never change it after the first release: it is the upgrade identity of
% every installed copy.
identifier = '4e372abb-192d-45f6-81de-3a1fb3e92f30';

staging = fullfile(tempdir, sprintf('mftt-staging-%s', char(java.util.UUID.randomUUID)));
mkdir(staging)
cleanup = onCleanup(@() rmdir(staging, 's'));

% App code, including about.json (the app reads it from the MATLAB path)
% and the vendored library submodule. An installed toolbox cannot clone
% submodules, so the library is copied in like any other source file.
% The initial copy brings the library's full working copy (its .git,
% workflows, scratch folders); it is removed again below and replaced
% by the runtime-only copy.
copyfile(fullfile(root, 'src'), fullfile(staging, 'src'))
rmdir(fullfile(staging, 'src', 'magic-formula-tyre-library'), 's')

% Library runtime payload: model code plus the doc data referenced by
% the Getting Started guide. Repository plumbing (tests, project
% metadata, sandbox scratch, packaging scripts) is not carried over.
libRoot = fullfile(root, 'src', 'magic-formula-tyre-library');
libStaging = fullfile(staging, 'src', 'magic-formula-tyre-library');
copyfile(fullfile(libRoot, 'src'), fullfile(libStaging, 'src'))
copyfile(fullfile(libRoot, 'doc'), fullfile(libStaging, 'doc'))
for file = ["README.md", "LICENSE", "CHANGELOG.md"]
    copyfile(fullfile(libRoot, file), libStaging)
end

% UI assets: the app resolves icon files from assets/ on the MATLAB
% path. assets/img only holds the toolbox screenshot used below and the
% README animations, which are not shipped.
mkdir(fullfile(staging, 'assets'))
copyfile(fullfile(root, 'assets', 'icons'), fullfile(staging, 'assets', 'icons'))
screenshot = fullfile(staging, 'assets', 'img', 'App_Screenshot_Main.jpg');
mkdir(fileparts(screenshot))
copyfile(fullfile(root, 'assets', 'img', 'App_Screenshot_Main.jpg'), screenshot)

copyfile(fullfile(root, 'doc'), fullfile(staging, 'doc'))
for file = ["README.md", "LICENSE", "CHANGELOG.md"]
    copyfile(fullfile(root, file), staging)
end

aboutFile = fullfile(staging, 'src', 'about.json');
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

% The bundled app installer is built locally with matlab.apputil.package
% and is not version-controlled, so skip it when absent; CI must be able
% to package from a clean checkout.
appInstaller = fullfile(root, 'MagicFormulaTyreTool.mlappinstall');
if isfile(appInstaller)
    copyfile(appInstaller, staging)
end

opts = matlab.addons.toolbox.ToolboxOptions(staging, identifier);
opts.ToolboxName = 'MagicFormulaTyreTool';
opts.ToolboxVersion = jsondecode(fileread(aboutFile)).Version;
opts.Summary = 'MATLAB GUI for Magic Formula Tyre Modeling';
opts.Description = 'https://github.com/jyjh/magic-formula-tyre-tool';
opts.ToolboxImageFile = screenshot;
opts.ToolboxGettingStartedGuide = fullfile(staging, 'doc', 'GettingStarted.mlx');
opts.OutputFile = fullfile(root, 'MagicFormulaTyreTool.mltbx');
opts.SupportedPlatforms.Win64 = true;
opts.SupportedPlatforms.Maci64 = true;
opts.SupportedPlatforms.Glnxa64 = true;
opts.SupportedPlatforms.MatlabOnline = true;
matlab.addons.toolbox.packageToolbox(opts);

clear cleanup
end
