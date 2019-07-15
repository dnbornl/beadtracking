function manageToolInstances(action,handleName,handleInstance)
%GUI.MANAGETOOLINSTANCES Track multiple instances of an app.
%   GUI.MANAGETOOLINSTANCES(ACTION,HANDLENAME,HANDLEINSTANCE) executes an
%   action on specific handles provided by the user. There are three valid
%   actions:
%
%       'add'       Add a handle of a created app to the tracked list.
%
%                   Usage: manageToolInstances('add','gui.internal.someTool',h)
%
%       'remove'    Remove a handle from the tracked list.
%
%                   Usage: manageToolInstances('remove','gui.internal.someTool',h)
%
%       'deleteAll' Call the destructor on all tracked instances of an app.
%
%                   Usage: manageToolInstance('deleteAll','gui.internal.someTool',h)

% Copyright 2014 The MathWorks, Inc.
% Modified 2017-2019 Matthew R. Eicholtz

mlock();
% munlock('face.internal.manageToolInstances')

% Parse inputs
validateattributes(action,{'char'},{'nonempty','vector'});
validateattributes(handleName,{'char'},{'nonempty','vector'});
if nargin==3; assert(isa(handleInstance,'handle')); end

% Get array of tools
persistent toolArrayMap
if isempty(toolArrayMap)
    toolArrayMap = containers.Map();
end

switch action
    case 'add'
        if isKey(toolArrayMap,handleName)
            toolArray = toolArrayMap(handleName);
            if(isempty(toolArray))
                toolArray = handleInstance;
            else
                toolArray(end+1) = handleInstance;
            end
            toolArrayMap(handleName) = toolArray;
        else
            toolArrayMap(handleName) = handleInstance;
        end
        
    case 'remove'
        if isKey(toolArrayMap,handleName)
            toolArray = toolArrayMap(handleName);
            for hInd=1:length(toolArray)
                if isequal(handleInstance, toolArray(hInd))
                    toolArray(hInd) = [];
                    break;
                end
            end
            toolArrayMap(handleName) = toolArray;
        end
        
    case 'deleteAll'
        if isKey(toolArrayMap, handleName)
            toolArray = toolArrayMap(handleName);
            for hInd=length(toolArray):-1:1
                delete(toolArray(hInd));
            end
            remove(toolArrayMap,handleName);
        end
        
    otherwise
        assert(false,'Unknown action requested');
end

end

