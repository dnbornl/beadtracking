classdef ZoomPanTools < handle
%GUI.ZOOMPANTOOLS Zoom and pan tools for graphical user interfaces.
%   TOOLS = GUI.ZOOMPANTOOLS() creates tools for zooming and panning that
%   can be added to an app. The highest level objet is this.Section
%   (toolpack.desktop.ToolSection), which can be added to a
%   toolpack.desktop.ToolTab.
%
%   addlisteners(TOOLS,APP) activates zoom/pan listener functions in an
%   APP, which must be an object that includes the property 'ImageHandle'.
%
%   Example: Add zoom/pan tools to an existing app (an object containing 
%   toolpack.desktop.___ components).
%
%       zoompantools = gui.ZoomPanTools();
%       unpack(zoompantools,app);
%       addlisteners(zoompantools,app);
%
%   See also toolpack.desktop.ToolGroup, toolpack.desktop.ToolTab, 
%   toolpack.desktop.ToolSection.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Name = 'Zoom and Pan Tools';
        
        Section = toolpack.desktop.ToolSection.empty(0);
        
        ToggleButton = toolpack.component.TSToggleButton.empty(0);
    end
    
    methods
        function this = ZoomPanTools()
            % Create section
            this.Section = toolpack.desktop.ToolSection('zoompan','Zoom and Pan');
            
            % Create buttons for zooming and panning
            txt = 'Zoom in';
            icon = gui.Icon.ZOOMIN_16;
            button = toolpack.component.TSToggleButton(txt,icon);
            button.Name = 'zoomin';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Zoom in');
            add(this,'ToggleButton',button);
            
            txt = 'Zoom out';
            icon = gui.Icon.ZOOMOUT_16;
            button = toolpack.component.TSToggleButton(txt,icon);
            button.Name = 'zoomout';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Zoom out');
            add(this,'ToggleButton',button);
            
            txt = 'Pan';
            icon = gui.Icon.PAN_16;
            button = toolpack.component.TSToggleButton(txt,icon);
            button.Name = 'pan';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Pan');
            add(this,'ToggleButton',button);
            
            % Setup toolstrip panel
            N = length(this.ToggleButton);
            panel = toolpack.component.TSPanel('f:p',repmat('f:p:g,',1,N)); %(columns,rows)
            for ii=1:N
                panel.add(this.ToggleButton(ii),sprintf('xy(1,%d)',ii));
            end
            
            % Add panel to section
            add(this.Section,panel);
        end
        function add(this,style,obj)
        %ADD Append an object (OBJ) to the property denoted by STYLE.
        %	Example: Add a button to the ROI tools.
        %   
        %       button = toolpack.component.TSToggleButton('sample button');
        %       add(this,'ToggleButton',button);
        
            this.(style) = cat(2,this.(style),obj);
        end
        function addlisteners(this,app)
        %ADDLISTENERS Add listener functions for specific events.
            addlistener(this.get('ToggleButton','zoomin'),'ItemStateChanged',@(obj,evt) zoomin(this,app.ImageHandle));
            addlistener(this.get('ToggleButton','zoomout'),'ItemStateChanged',@(obj,evt) zoomout(this,app.ImageHandle));
            addlistener(this.get('ToggleButton','pan'),'ItemStateChanged',@(obj,evt) pan(this,app.ImageHandle));
        end
        function disable(this)
        %DISABLE Set 'Enabled' property of all controls to false.
            [this.ToggleButton.Enabled] = deal(false);
        end
        function enable(this)
        %ENABLE Set 'Enabled' property of all controls to true.
            [this.ToggleButton.Enabled] = deal(true);
        end
        function obj = get(this,style,name)
        %GET Find instances of an object style based on its Name property.
        %   Example: Get the ToggleButton object named 'zoomin'.
        %
        %       obj = get(this,'ToggleButton','zoomin');
            
            obj = findobj(this.(style),'Name',name);
            
            if isempty(obj)
                error('There is no %s named %s.',style,name);
            elseif length(obj)>1
                warning('There are multiple %s named %s.',style,name);
            end
        end
        function reset(this)
        %RESET Return to default setup (all controls are unselected).
            [this.ToggleButton.Selected] = deal(false);
        end
        function unpack(this,app)
        %UNPACK Add tool properties to app properties.
            add(app,'Section',this.Section);
            add(app,'ToggleButton',this.ToggleButton);
        end
    end
    
    methods (Access=private) %listeners
        function zoomin(this,h)
        %ZOOMIN Listener function when zoomin ToggleButton is pressed.
            if this.get('ToggleButton','zoomin').Selected
                this.get('ToggleButton','zoomout').Selected = false;
                this.get('ToggleButton','pan').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomin');
                warning(warnstate);
                glassplus = setptr('glassplus');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,glassplus{:}));
            else
                if ~(this.get('ToggleButton','zoomout').Selected || this.get('ToggleButton','pan').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
        function zoomout(this,h)
        %ZOOMOUT Listener function when zoomout ToggleButton is pressed.
            if this.get('ToggleButton','zoomout').Selected
                this.get('ToggleButton','zoomin').Selected = false;
                this.get('ToggleButton','pan').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomout');
                warning(warnstate);
                glassminus = setptr('glassminus');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,glassminus{:}));
            else
                if ~(this.get('ToggleButton','zoomin').Selected || this.get('ToggleButton','pan').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
        function pan(this,h)
        %PAN Listener function when pan ToggleButton is pressed.
            if this.get('ToggleButton','pan').Selected
                this.get('ToggleButton','zoomin').Selected = false;
                this.get('ToggleButton','zoomout').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','impan');
                warning(warnstate);
                handcursor = setptr('hand');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,handcursor{:}));
            else
                if ~(this.get('ToggleButton','zoomin').Selected || this.get('ToggleButton','zoomout').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
    end
end

