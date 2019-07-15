classdef ZoomPanManager_old < handle
%GUI.ZOOMPANMANAGER Add zoom and pan tools to an app.
%   GUI.ZOOMPANMANAGER(APP,TAB) manages zoom and pan widgets in a specified
%   TAB of an APP.
%
%   THIS = GUI.ZOOMPANMANAGER(APP,TAB) returns the object itself, which can
%   be stored, for example, as a property of the APP.
%
%   Requirements:
%   1) The input APP must have a dependent property called ImageHandle that
%   returns an image handle on which to apply zooming/panning. The callback
%   functions zoomin(), zoomout(), and pan() all require this handle.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Section
        ZoominButton
        ZoomoutButton
        PanButton
    end
    properties (Access=private,Constant) %icons
        ZoominIcon	= gui.Icon.ZOOMIN_16;
        ZoomoutIcon	= gui.Icon.ZOOMOUT_16;
        PanIcon  	= gui.Icon.PAN_16;
    end
    properties (Dependent)
        Handles
    end
    
    methods
        function this = ZoomPanManager_old(app,tab)
            % Construct the toolstrip section in a specified tab.
            this.Section = tab.addSection('ZoomPan','Zoom and Pan');
            this.addbuttons();
            this.addtooltip();
            this.addlisteners(app);
            this.layout();
        end
        function disable(this)
            % Disable all controls in the toolstrip section.
            this.ZoominButton.Enabled = false;
            this.ZoomoutButton.Enabled = false;
            this.PanButton.Enabled = false;
        end
        function enable(this)
            % Enable all controls in the toolstrip section.
            this.ZoominButton.Enabled = true;
            this.ZoomoutButton.Enabled = true;
            this.PanButton.Enabled = true;
        end
        function reset(this)
            % Reset all controls in the toolstrip section.
            this.ZoominButton.Selected = false;
            this.ZoomoutButton.Selected = false;
            this.PanButton.Selected = false;
        end
    end
    
    methods (Access=private) %setup
        %******************************************************************
        % These functions are called from the constructor to setup the
        % design and layout of the Zoom and Pan toolstrip section.
        %******************************************************************
        function addbuttons(this)
            % Create buttons for zooming and panning.
            this.ZoominButton = toolpack.component.TSToggleButton('Zoom in',this.ZoominIcon);
            this.ZoominButton.Name = 'Zoom in';
            this.ZoominButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            this.ZoomoutButton = toolpack.component.TSToggleButton('Zoom out',this.ZoomoutIcon);
            this.ZoomoutButton.Name = 'Zoom out';
            this.ZoomoutButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            this.PanButton = toolpack.component.TSToggleButton('Pan',this.PanIcon);
            this.PanButton.Name = 'Pan';
            this.PanButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
        end
        function addlisteners(this,app)
            % Add callback functions for each interactive widget.
            addlistener(this.ZoominButton,'ItemStateChanged',@(obj,evt) zoomin(this,obj,evt,app));
            addlistener(this.ZoomoutButton,'ItemStateChanged',@(obj,evt) zoomout(this,obj,evt,app));
            addlistener(this.PanButton,'ItemStateChanged',@(obj,evt) pan(this,obj,evt,app));
        end
        function addtooltip(this)
            % Display text when user hovers over a control.
            this.ZoominButton.Peer.setToolTipText('Zoom in');
            this.ZoomoutButton.Peer.setToolTipText('Zoom out');
            this.PanButton.Peer.setToolTipText('Pan');
        end
        function layout(this)
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.ZoominButton,    'xy(1,1)');
            panel.add(this.ZoomoutButton,   'xy(1,2)');
            panel.add(this.PanButton,       'xy(1,3)');
            
            % Add panel to section
            this.Section.add(panel);
        end
    end
    
    methods (Access=private) %listeners
        %******************************************************************
        % These functions are called when specific user actions are 
        % executed, such as clicking a button.
        %******************************************************************
        function zoomin(this,obj,~,app)
            % Callback for ZoominButton.
            himage = app.ImageHandle;
            if obj.Selected
                this.ZoomoutButton.Selected = false;
                this.PanButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomin');
                warning(warnstate);
                glassplus = setptr('glassplus');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,glassplus{:}));
            else
                if ~(this.ZoomoutButton.Selected || this.PanButton.Selected)
                    if ~isempty(himage)
                        himage.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
        function zoomout(this,obj,~,app)
            % Callback for ZoomoutButton.
            himage = app.ImageHandle;
            if obj.Selected
                this.ZoominButton.Selected = false;
                this.PanButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomout');
                warning(warnstate);
                glassminus = setptr('glassminus');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,glassminus{:}));
            else
                if ~(this.ZoominButton.Selected || this.PanButton.Selected)
                    if ~isempty(himage)
                        himage.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
        function pan(this,obj,~,app)
            % Callback for PanButton.
            himage = app.ImageHandle;
            if obj.Selected
                this.ZoomoutButton.Selected = false;
                this.ZoominButton.Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                himage.ButtonDownFcn = imuitoolsgate('FunctionHandle','impan');
                warning(warnstate);
                handcursor = setptr('hand');
                iptSetPointerBehavior(himage,@(hfig,~) set(hfig,handcursor{:}));
            else
                if ~(this.ZoominButton.Selected || this.ZoomoutButton.Selected)
                    if ~isempty(himage)
                        himage.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(himage,[]);
                end
            end
        end
    end
    
    methods %set/get dependent properties
        function h = get.Handles(this)
            h = {...
                this.ZoominButton,...
                this.ZoomoutButton,...
                this.PanButton};
        end
    end
end

