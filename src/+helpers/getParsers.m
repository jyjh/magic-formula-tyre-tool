function [names, handles] = getParsers()
metaPackageObj = meta.package.fromName('tydex.parsers');
metaClassObj = metaPackageObj.ClassList;
isAbstract = [metaClassObj.Abstract];
isHidden = [metaClassObj.Hidden];
metaClassObj(isAbstract|isHidden) = [];
namesFull = {metaClassObj.Name};
% The package also contains helper/value classes used by parsers. Only
% expose concrete subclasses implementing the tydex.Parser run interface.
isParser = cellfun(@(name) any(strcmp( ...
    superclasses(name),'tydex.Parser')),namesFull);
metaClassObj = metaClassObj(isParser);
namesFull = {metaClassObj.Name};
namesSplit = cellfun(@(x)strsplit(x,'.'), namesFull, 'UniformOutput', 0);
names = cellfun(@(x)x{end},  namesSplit, 'UniformOutput', 0);
handles = cellfun(@str2func, namesFull, 'UniformOutput', 0);
end
