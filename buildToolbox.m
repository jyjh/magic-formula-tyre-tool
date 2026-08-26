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

% Build the app installer from the staged tree so that installing the
% toolbox registers MagicFormulaTyreTool in the APPS gallery (the
% toolbox packager emits metadata/applications.xml for every bundled
% .mlappinstall, and the installer registers those apps). The app keeps
% the GUID of the historical MagicFormulaTyreTool app so it upgrades
% in place on machines that have the File Exchange version.
toolboxVersion = jsondecode(fileread(aboutFile)).Version;
% The app packager derives the registered app name from the project
% file's base name, so it must be named after the app.
appProject = fullfile(staging, 'MagicFormulaTyreTool.prj');
writeAppPackagerProject(appProject, staging, toolboxVersion);
cleanupAppProject = onCleanup(@() delete(appProject));
type(appProject)
matlab.apputil.package(appProject);
% The packaging service writes the deliverable asynchronously and not
% always under the expected name, so poll the staging tree and
% normalize whatever appears.
appInstaller = '';
for i = 1:30
    candidates = dir(fullfile(staging, '**', '*.mlappinstall'));
    if ~isempty(candidates)
        [~, newest] = max([candidates.datenum]);
        appInstaller = fullfile(candidates(newest).folder, candidates(newest).name);
        break
    end
    pause(1)
end
if isempty(appInstaller)
    disp('Staging tree after app packaging (no mlappinstall produced):')
    disp(dir(fullfile(staging, '**', '*')))
    error('MagicFormulaTyreTool:appPackagingFailed', ...
        'App packaging did not produce an mlappinstall in %s.', staging)
end
clear cleanupAppProject
canonical = fullfile(staging, 'MagicFormulaTyreTool.mlappinstall');
if ~strcmp(appInstaller, canonical)
    movefile(appInstaller, canonical)
end

opts = matlab.addons.toolbox.ToolboxOptions(staging, identifier);
opts.ToolboxName = 'MagicFormulaTyreTool';
opts.ToolboxVersion = toolboxVersion;
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

function writeAppPackagerProject(projectFile, rootFolder, version)
%WRITEAPPPACKAGERPROJECT Emit an app-packaging project (.prj) for
%matlab.apputil.package. The format mirrors the project the App Designer
%packaging dialog writes; files are referenced relative to ${PROJECT_ROOT}
%so the project works from the staging folder on any machine.

about = jsondecode(fileread(fullfile(rootFolder, 'src', 'about.json')));
authors = strjoin(cellstr(about.Authors), ', ');
summary = 'MATLAB GUI for Magic Formula Tyre Modeling';
icon = fullfile(rootFolder, 'assets', 'icons', 'tyre_icon.png');
screenshot = fullfile(rootFolder, 'assets', 'img', 'App_Screenshot_Main.jpg');
mainFile = fullfile(rootFolder, 'src', 'MagicFormulaTyreTool.m');

appFiles = [ ...
    dir(fullfile(rootFolder, 'src', '**', '*.m')); ...
    dir(fullfile(rootFolder, 'src', 'about.json')) ...
];
appFiles = appFiles([appFiles.isdir] == 0);
appFiles = appFiles(~strcmp({appFiles.name}, 'MagicFormulaTyreTool.m'));

fileId = fopen(projectFile, 'w');
try
    fprintf(fileId, ['<deployment-project plugin="plugin.apptool" ' ...
        'plugin-version="1.0">\n']);
    fprintf(fileId, ['  <configuration file="%s" location="%s" ' ...
        'name="MagicFormulaTyreTool" target="target.mlapps" ' ...
        'target-name="Package App">\n'], projectFile, rootFolder);
    fprintf(fileId, '    <param.appname>MagicFormulaTyreTool</param.appname>\n')
    fprintf(fileId, '    <param.authnamewatermark>%s</param.authnamewatermark>\n', authors)
    fprintf(fileId, '    <param.email />\n')
    fprintf(fileId, '    <param.company />\n')
    fprintf(fileId, '    <param.icon>%s</param.icon>\n', toProjectPath(icon, rootFolder))
    fprintf(fileId, '    <param.icons>\n')
    for i = 1:3
        fprintf(fileId, '      <file>%s</file>\n', toProjectPath(icon, rootFolder))
    end
    fprintf(fileId, '    </param.icons>\n')
    fprintf(fileId, '    <param.summary>%s</param.summary>\n', summary)
    fprintf(fileId, '    <param.description>%s</param.description>\n', about.Source)
    fprintf(fileId, '    <param.screenshot>%s</param.screenshot>\n', ...
        toProjectPath(screenshot, rootFolder))
    fprintf(fileId, '    <param.version>%s</param.version>\n', version)
    fprintf(fileId, ['    <param.products.name>\n' ...
        '      <item>MATLAB</item>\n' ...
        '      <item>Optimization Toolbox</item>\n' ...
        '    </param.products.name>\n'])
    fprintf(fileId, ['    <param.products.id>\n' ...
        '      <item>1</item>\n' ...
        '      <item>6</item>\n' ...
        '    </param.products.id>\n'])
    fprintf(fileId, ['    <param.products.version>\n' ...
        '      <item>9.10</item>\n' ...
        '      <item>9.1</item>\n' ...
        '    </param.products.version>\n'])
    fprintf(fileId, '    <param.platforms />\n')
    fprintf(fileId, '    <param.output>%s</param.output>\n', toProjectPath(rootFolder, rootFolder))
    % Historical app identity of MagicFormulaTyreTool (matches the app
    % shipped via File Exchange); keep stable so installs upgrade in
    % place.
    fprintf(fileId, ['    <param.guid>25bcb2d7-69d2-4790-a114-9349ec5e2889' ...
        '</param.guid>\n'])
    fprintf(fileId, '    <unset>\n')
    fprintf(fileId, '      <param.email />\n')
    fprintf(fileId, '      <param.company />\n')
    fprintf(fileId, '      <param.platforms />\n')
    fprintf(fileId, '    </unset>\n')
    fprintf(fileId, '    <fileset.main>\n')
    fprintf(fileId, '      <file>%s</file>\n', toProjectPath(mainFile, rootFolder))
    fprintf(fileId, '    </fileset.main>\n')
    fprintf(fileId, '    <fileset.depfun>\n')
    for i = 1:numel(appFiles)
        relative = toProjectPath(appFiles(i).folder, rootFolder);
        fprintf(fileId, '      <file>%s\\%s</file>\n', relative, appFiles(i).name)
    end
    fprintf(fileId, '    </fileset.depfun>\n')
    fprintf(fileId, '    <fileset.resources>\n')
    fprintf(fileId, '      <file>%s</file>\n', ...
        toProjectPath(fullfile(rootFolder, 'assets', 'icons'), rootFolder))
    fprintf(fileId, '    </fileset.resources>\n')
    fprintf(fileId, '    <fileset.package />\n')
    fprintf(fileId, '    <build-deliverables>\n')
    fprintf(fileId, '      <file location="%s" name="MagicFormulaTyreTool.mlappinstall" optional="false">%s</file>\n', ...
        rootFolder, fullfile(rootFolder, 'MagicFormulaTyreTool.mlappinstall'))
    fprintf(fileId, '    </build-deliverables>\n')
    fprintf(fileId, '    <workflow />\n')
    fprintf(fileId, '    <matlab>\n')
    fprintf(fileId, '      <root>%s</root>\n', matlabroot)
    fprintf(fileId, '      <toolboxes />\n')
    fprintf(fileId, '    </matlab>\n')
    fprintf(fileId, '    <platform>\n')
    fprintf(fileId, '      <unix>%d</unix>\n', isunix)
    fprintf(fileId, '      <mac>%d</mac>\n', ismac)
    fprintf(fileId, '      <windows>%d</windows>\n', ispc)
    fprintf(fileId, '      <linux>%d</linux>\n', isunix && ~ismac)
    fprintf(fileId, '      <os64>true</os64>\n')
    fprintf(fileId, '      <arch>%s</arch>\n', computer('arch'))
    fprintf(fileId, '      <matlab>true</matlab>\n')
    fprintf(fileId, '    </platform>\n')
    fprintf(fileId, '  </configuration>\n')
    fprintf(fileId, '</deployment-project>\n')
    fclose(fileId);
catch ME
    fclose(fileId);
    rethrow(ME)
end
end

function projectPath = toProjectPath(absolutePath, rootFolder)
%TOPROJECTPATH Absolute path to a ${PROJECT_ROOT}\... project reference.
assert(startsWith(absolutePath, rootFolder), ...
    'Path "%s" is not inside the project root "%s".', absolutePath, rootFolder)
relativePortion = strrep(absolutePath(length(rootFolder)+1:end), '/', '\');
projectPath = ['${PROJECT_ROOT}' relativePortion];
end
