classdef ImrectModeContainer < handle
%GUI.IMRECTMODECONTAINER Container of imrect objects.
%
%   Notes:
%   1) Copied and modified from iptui.internal.ImfreehandModeContainer. 
%   Also similar to iptui.internal.ImpolyModeContainer.
%
%   2) Each time an interactive placement gesture of imrect is completed, 
%   an additional instance of imrect is added to the property hROI. The 
%   client enables the ability to add to the container by calling
%   enableInteractivePlacement. When the client wants to stop interactive
%   placement, the client calls disableInteractivePlacement.

%   Copyright 2016-2019 Matthew R. Eicholtz
    
    properties (Access = private)
        MouseMotionCb
        ButtonUpCb
        rectSymbolAPI
        position
        hFig
        hParent
        hGroup
        
        OriginalPointerBehavior
        hTransparentOverlay
    end
    
    properties (SetAccess = private, SetObservable = true)
        hROI  % Handles to imfreehand ROIs
    end
    
    methods
       
        function obj = ImrectModeContainer(hParent)
            obj.hFig = ancestor(hParent,'figure');
            obj.hParent = hParent;
            obj.hROI = imrect.empty();
        end
        
        function disableInteractivePlacement(obj)
            iptSetPointerBehavior(obj.hTransparentOverlay, obj.OriginalPointerBehavior);
            delete(obj.hTransparentOverlay);
        end
        
        function enableInteractivePlacement(obj)
            % Create a transparent layer that sits on top of the HG stack
            % that grabs button down. This prevents interaction with other
            % HG objects that have button down behavior as we are placing
            % freehand instances.
            obj.hTransparentOverlay = axes('Parent',get(obj.hParent,'Parent'),...
                'Units',get(obj.hParent,'Units'),'Position',get(obj.hParent,'Position'),...
                'Visible','off','HitTest','on','ButtonDownFcn',@(hobj,evt) obj.beginDraw());
           
            iptPointerManager(obj.hFig);
            obj.OriginalPointerBehavior = iptGetPointerBehavior(obj.hTransparentOverlay);
            iptSetPointerBehavior(obj.hTransparentOverlay,@(~,~) set(obj.hFig,'Pointer','crosshair'));
            
            obj.hTransparentOverlay.PickableParts = 'all';
            uistack(obj.hTransparentOverlay,'top');
        end
        
        function beginDraw(obj)
            obj.MouseMotionCb = iptaddcallback(obj.hFig,'WindowButtonMotionFcn',@(~,~)  obj.rectDraw());
            obj.ButtonUpCb = iptaddcallback(obj.hFig,'WindowButtonUpFcn',@(~,~) obj.stopDraw());
            
            warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
            freehandSymbol = imuitoolsgate('FunctionHandle','freehandSymbol');
            
            obj.hGroup = hggroup('Parent',obj.hParent);
            obj.rectSymbolAPI = freehandSymbol();
            warning(warnstate);
            
            obj.rectSymbolAPI.initialize(obj.hGroup);
            obj.rectSymbolAPI.setVisible(true);
            colorChoices = iptui.getColorChoices();
            obj.rectSymbolAPI.setColor(colorChoices(1).Color);
            
            xy = obj.hParent.CurrentPoint;
            x = xy(1,1);
            y = xy(1,2);
            
            obj.position = [x y];
            
            obj.rectSymbolAPI.updateView(obj.position);
             
        end
        
        function rectDraw(obj)
            
            xy = obj.hParent.CurrentPoint;
            x1 = xy(1,1);
            y1 = xy(1,2);
            
            x0 = obj.position(1,1);
            y0 = obj.position(1,2);
            
            obj.position = [
                x0, y0;
                x1, y0;
                x1, y1;
                x0, y1;
                x0, y0];
            obj.rectSymbolAPI.updateView(obj.position);
                         
        end
        
        function stopDraw(obj)
            
           rectDraw(obj); 
           obj.rectSymbolAPI.setClosed(true);
           
           delete(obj.hGroup);
           obj.hROI(end+1) = imrect(obj.hParent,[min(obj.position), max(obj.position)-min(obj.position)]);

           iptremovecallback(obj.hFig,'WindowButtonMotionFcn',obj.MouseMotionCb);
           iptremovecallback(obj.hFig,'WindowButtonUpFcn',obj.ButtonUpCb);
           
        end
            
    end
        
end