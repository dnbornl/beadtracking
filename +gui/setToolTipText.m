function setToolTipText(component,str)
%GUI.SETTOOLTIPTEXT Add tooltip string to toolpack component.
%   GUI.SETTOOLTIPTEXT(COMPONENT,STR) sets the tooltip of the input 
%   user interface component to STR. COMPONENT must be an instance of an
%   object inherited from the TOOLPACK.COMPONENT.COMPONENT base class. For
%   example classes that match this requirement, see the following link:
%   <matlabroot>\toolbox\shared\controllib\general\+toolpack\+component\
%
%   See also TOOLPACK.COMPONENT.COMPONENT, TSButton.

% Copyright 2014 The MathWorks Inc.
% Modified 2016-2019 Matthew R. Eicholtz

component.Peer.setToolTipText(str)

end

