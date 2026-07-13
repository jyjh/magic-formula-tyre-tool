classdef CouldNotImportTYDEX < MException 
    methods
        function obj = CouldNotImportTYDEX()
            errId = 'MagicFormulaTyreTool:CouldNotImportTYDEX';
            msgtext = 'Could not import measurements from selected file(s).';
            obj@MException(errId, msgtext)
        end
    end
end

