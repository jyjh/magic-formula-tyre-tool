function [available, versionLatest] = checkUpdateAvailable(versionCurrent, repoSource)
%CHECKUPDATEAVAILABLE Checks if an update is available for the application.
%Compares the current semantic version against the latest GitHub release
%tag for the configured repository source.
%
%Throws an MException (caught by the caller) when the version strings are
%malformed or the release endpoint cannot be reached. Network failures are
%reported distinctly from parse failures so the caller can present them
%differently if desired.
arguments
    versionCurrent char
    repoSource char = checkUpdateAvailable.defaultRepoSource()
end
available = false;

versionValidPattern = ...
    digitsPattern() + '.' + digitsPattern() + '.' + digitsPattern();

versionCurrent = erase(versionCurrent, 'v');
if ~matches(versionCurrent, versionValidPattern)
    error('MagicFormulaTyreTool:InvalidVersion', ...
        'Current version ''%s'' is not a valid semantic version (X.Y.Z).', ...
        versionCurrent);
end

% repoSource is e.g. 'github.com/jyjh/magic-formula-tyre-tool'. Strip a
% leading scheme and trailing slashes so the API URL is well-formed.
repoSource = regexprep(repoSource, '^https?://', '');
repoSource = regexprep(repoSource, '/+$', '');
url = sprintf('https://api.github.com/repos/%s/releases/latest', repoSource);

try
    releaseInfo = webread(url);
catch ME
    error('MagicFormulaTyreTool:UpdateCheckFailed', ...
        'Could not reach the update endpoint (%s). Internet available?', ...
        ME.message);
end

versionLatest = releaseInfo.tag_name;
versionLatest = erase(versionLatest, 'v');
if ~matches(versionLatest, versionValidPattern)
    error('MagicFormulaTyreTool:InvalidVersion', ...
        'Latest version ''%s'' is not a valid semantic version (X.Y.Z).', ...
        versionLatest);
end

versionCurrentSplit = split(versionCurrent, '.');
versionLatestSplit = split(versionLatest, '.');

for i = 1:numel(versionCurrentSplit)
    v0 = str2double(versionCurrentSplit{i});
    v1 = str2double(versionLatestSplit{i});
    if v1 > v0
        available = true;
        return
    elseif v0 > v1
        % Current version is newer than latest release; no update available.
        return
    end
end
end

function source = defaultRepoSource()
%DEFAULTREPOSOURCE Read the repository source from about.json so the
%update check queries the fork the user actually built from, rather than a
%hard-coded upstream.
try
    about = jsondecode(fileread('about.json'));
    source = char(about.Source);
catch
    source = 'github.com/teasit/magic-formula-tyre-tool';
end
end
