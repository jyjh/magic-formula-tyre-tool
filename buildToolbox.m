opts = matlab.addons.toolbox.ToolboxOptions(pwd, 'MagicFormulaTyreTool');
opts.ToolboxName = 'MagicFormulaTyreTool';
opts.ToolboxVersion = jsondecode(fileread(fullfile(pwd, 'src', 'about.json'))).Version;
opts.Summary = 'MATLAB GUI for Magic Formula Tyre Modeling';
opts.Description = 'https://github.com/teasit/magic-formula-tyre-tool';
opts.ToolboxImageFile = fullfile(pwd, 'assets', 'img', 'App_Screenshot_Main.jpg');
opts.ToolboxGettingStartedGuide = fullfile(pwd, 'doc', 'GettingStarted.mlx');
opts.OutputFile = fullfile(pwd, 'MagicFormulaTyreTool.mltbx');
opts.SupportedPlatforms.Win64 = true;
opts.SupportedPlatforms.Maci64 = true;
opts.SupportedPlatforms.Glnxa64 = true;
opts.SupportedPlatforms.MatlabOnline = true;
opts.ToolboxFiles = { ...
    fullfile(pwd, 'CHANGELOG.md'), ...
    fullfile(pwd, 'doc'), ...
    fullfile(pwd, 'LICENSE'), ...
    fullfile(pwd, 'MagicFormulaTyreTool.mlappinstall'), ...
    fullfile(pwd, 'README.md') ...
};
matlab.addons.toolbox.packageToolbox(opts);
