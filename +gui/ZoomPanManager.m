classdef ZoomPanManager < handle
%GUI.ZOOMPANMANAGER Add zoom and pan tools to an app.
%   GUI.ZOOMPANMANAGER(APP,TAB,HIMAGE) manages zoom and pan widgets for an
%   image handle (HIMAGE) in a TAB of an APP. TAB must be a string
%   corresponding to the name of the tab stored in APP.ToolGroup, and 
%   HIMAGE must be a string corresponding to the name of the property in
%   the APP where the image handle is stored.
%
%   THIS = GUI.ZOOMPANMANAGER(___) returns the zoom/pan manager object
%   itself, which can be stored, for example, as a property of the APP.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Buttons = toolpack.component.TSToggleButton.empty(0,3);
    end
    
    properties (Access=private,Constant) %button properties
        Name = {'zoomin','zoomout','pan'}; %also corresponds to the name of listener functions
        Text = {'Zoom in','Zoom out','Pan'};
        Icon = {'ZOOMIN_16','ZOOMOUT_16','PAN_16'};
        Tooltip = {'Zoom in','Zoom out','Pan'};
    end
    
    methods %constructor and other public functions
        function this = ZoomPanManager(app,tab,himage)
            % Create buttons for zooming and panning
            N = size(this.Buttons,2); %number of buttons
            for ii=1:N
                txt = this.Text{ii};
                icon = gui.Icon.(this.Icon{ii});
                name = this.Name{ii};
                tooltip = this.Tooltip{ii};
                
                this.Buttons(ii) = toolpack.component.TSToggleButton(txt,icon);
                this.Buttons(ii).Name = name;
                this.Buttons(ii).Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
                this.Buttons(ii).Peer.setToolTipText(tooltip);
                
                addlistener(this.Buttons(ii),'ItemStateChanged',@(obj,evt) this.(obj.Name)(app.(himage)));
            end
            
            % Create toolstrip panel and add buttons to panel
            panel = toolpack.component.TSPanel('f:p',repmat('f:p:g,',1,N)); %(columns,rows)
            for ii=1:N
                panel.add(this.Buttons(ii),sprintf('xy(1,%d)',ii));
            end
            
            % Add section to the specified tab and add panel to section
            tab = get(app.ToolGroup,tab);
            section = tab.addSection('ZoomPan','Zoom and Pan');
            section.add(panel);
        end
        function disable(this)
            % Disable all controls in the toolstrip section.
            [this.Buttons.Enabled] = deal(false);
        end
        function enable(this)
            % Enable all controls in the toolstrip section.
            [this.Buttons.Enabled] = deal(true);
        end
        function reset(this)
            % Reset all controls in the toolstrip section.
            [this.Buttons.Selected] = deal(false);
        end
        function h = button(this,name)
            % Get button object by name.
            h = findobj(this.Buttons,'Name',name);
        end
    end
    
    methods (Access=private) %listeners
        function zoomin(this,h)
            % Callback for zooming in.
            if this.button('zoomin').Selected
                this.button('zoomout').Selected = false;
                this.button('pan').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomin');
                warning(warnstate);
                glassplus = setptr('glassplus');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,glassplus{:}));
            else
                if ~(this.button('zoomout').Selected || this.button('pan').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
        function zoomout(this,h)
            % Callback for zooming out.
            if this.button('zoomout').Selected
                this.button('zoomin').Selected = false;
                this.button('pan').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','imzoomout');
                warning(warnstate);
                glassminus = setptr('glassminus');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,glassminus{:}));
            else
                if ~(this.button('zoomin').Selected || this.button('pan').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
        function pan(this,h)
            % Callback for panning.
            if this.button('pan').Selected
                this.button('zoomin').Selected = false;
                this.button('zoomout').Selected = false;
                warnstate = warning('off','images:imuitoolsgate:undocumentedFunction');
                h.ButtonDownFcn = imuitoolsgate('FunctionHandle','impan');
                warning(warnstate);
                handcursor = setptr('hand');
                iptSetPointerBehavior(h,@(hfig,~) set(hfig,handcursor{:}));
            else
                if ~(this.button('zoomin').Selected || this.button('zoomout').Selected)
                    if ~isempty(h)
                        h.ButtonDownFcn = '';
                    end
                    iptSetPointerBehavior(h,[]);
                end
            end
        end
    end
    
end

