classdef OpticalFlowManager < handle
%GUI.OPTICALFLOWMANAGER Add optical flow tools to a GUI.
%   GUI.OPTICALFLOWMANAGER(APP) manages optical flow controls in a 
%   specified APP.
%
%   THIS = GUI.OPTICALFLOWMANAGER(APP) returns the object itself, which can
%   be stored, for example, as a property of the APP.
%
%   Requirements:
%   1) The input APP must have a dependent property called AxesHandle that
%   returns an axes handle on which to apply draw regions of interest.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Tab
        SettingsSection
        HornSchunckSection
        LucasKanadeSection
        
        % Settings
        MethodLabel
        MethodButton
        ColorLabel
        ColorButton
        LinewidthLabel
        LinewidthSlider
        DecimationLabel
        DecimationSlider
        ScaleLabel
        ScaleSlider
        
        % Horn-Schunck
        HSSmoothnessLabel
        HSSmoothnessSlider
        HSSmoothnessText
        HSMaxIterationLabel
        HSMaxIterationSlider
        HSMaxIterationText
        HSVelocityDifferenceLabel
        HSVelocityDifferenceSlider
        HSVelocityDifferenceText
    end
    properties (Access=private)
        HSContainer
        LKContainer
    end
    properties (SetObservable=true)
        OpticalFlow
        Method
        Color
        Linewidth
        Decimation
        Scale
        Flag = true;
    end
    properties (Dependent)
        Handles
        QuiverInput
    end
    
    properties (Access=private,Constant) %strings
        MethodLabelStr          = 'Method';
        MethodPopupOption1Title = 'Horn-Schunck';
        MethodPopupOption1Desc  = 'Global method for estimating optical flow that assumes brightness velocity varies smoothly almost everywhere in the image';
        MethodPopupOption2Title = 'Lucas-Kanade';
        MethodPopupOption2Desc  = 'Local method for estimating optical flow that assumes constant flow in the neighborhood of a pixel';
        MethodTooltip           = 'Choose optical flow method';
        
        ColorLabelStr     	= 'Color';
        ColorTooltip        = 'Change color of velocity vectors';
        LinewidthLabelStr  	= 'Line width';
        LinewidthTooltip    = 'Change thickness of velocity vectors';
        DecimationLabelStr 	= 'Decimation';
        DecimationTooltip   = 'Change spacing of velocity vectors';
        ScaleLabelStr     	= 'Scale';
        ScaleTooltip        = 'Change size of velocity vectors';
        
        HSSmoothnessLabelStr            = 'Smoothness';
        HSSmoothnessTooltip             = 'Expected smoothness of optical flow';
        HSMaxIterationLabelStr          = 'Iterations';
        HSMaxIterationTooltip           = 'Maximum number of iterations';
        HSVelocityDifferenceLabelStr	= 'Velocity difference';
        HSVelocityDifferenceTooltip     = 'Minimum absolute velocity difference';
        
    end
    properties (Constant) %defaults
        DefaultMethod       = 'Horn-Schunck';
        
        DefaultColor        = 'green';
        DefaultLinewidth    = 2;
        DefaultDecimation   = 2;
        DefaultScale        = 20;
        
        DefaultHSSmoothness         = 1;
        DefaultHSMaxIteration       = 10;
        DefaultHSVelocityDifference = 0;
    end
    
    %======================================================================
    %
    % Public methods
    % --------------------
    % These functions can be called by external objects/functions.
    %
    %======================================================================
    methods
        function this = OpticalFlowManager(app,toolgroup)
            % Set properties
            this.Method = this.DefaultMethod;
            this.Color = str2rgb(this.DefaultColor);
            this.Linewidth = this.DefaultLinewidth;
            this.Decimation = this.DefaultDecimation;
            this.Scale = this.DefaultScale;
            
            this.OpticalFlow = opticalFlow(0,0);
            this.HSContainer = opticalFlowHS();
            this.LKContainer = opticalFlowLK();
            
            % Add tab to toolgroup
            this.Tab = toolgroup.addTab('OpticalFlowTab','Optical Flow');
            
            % Add sections to tab
            this.SettingsSection      	= this.Tab.addSection('SettingsSection','Settings');
            this.HornSchunckSection   	= this.Tab.addSection('HornSchunckSection','Horn-Schunck');
            this.LucasKanadeSection   	= this.Tab.addSection('LucasKanadeSection','Lucas-Kanade');
            
            % Create widgets for each section and add listeners
            this.layoutSettingsSection();
            this.layoutHornSchunckSection();
            this.layoutLucasKanadeSection();
            this.addtooltip();
            this.addlisteners(app);
        end
        function reset(this)
        end
        function updateFlow(this,im1,im0)
            try
                im0 = imadjust(im0);
            end
            im1 = imadjust(im1);
            if nargin==3 && ~isempty(im0)
                switch lower(this.Method)
                    case 'horn-schunck'
                        estimateFlow(this.HSContainer,im0);
                    case 'lucas-kanade'
                        estimateFlow(this.LKContainer,im0);
                end
            end
            switch lower(this.Method)
                case 'horn-schunck'
                    this.OpticalFlow = estimateFlow(this.HSContainer,im1);
                case 'lucas-kanade'
                    this.OpticalFlow = estimateFlow(this.LKContainer,im1);
            end
        end
    end
    
    methods (Access=private)
        function addlisteners(this,app)
            addlistener(this.MethodButton.Popup,'ListItemSelected',@this.setmethod);
            addlistener(this.ColorButton,'ActionPerformed',@this.setcolor);
            addlistener(this.LinewidthSlider,'StateChanged',@this.setlinewidth);
            addlistener(this.DecimationSlider,'StateChanged',@this.setdecimation);
            addlistener(this.ScaleSlider,'StateChanged',@this.setscale);
            
            addlistener(this.HSSmoothnessSlider,'StateChanged',@this.updateslider);
            addlistener(this.HSSmoothnessText,'TextEdited',@this.updatetext);
            addlistener(this.HSMaxIterationSlider,'StateChanged',@this.updateslider);
            addlistener(this.HSMaxIterationText,'TextEdited',@this.updatetext);
            addlistener(this.HSVelocityDifferenceSlider,'StateChanged',@this.updateslider);
            addlistener(this.HSVelocityDifferenceText,'TextEdited',@this.updatetext);
        end
        function addtooltip(this)
            iptui.internal.utilities.setToolTipText(this.MethodButton,this.MethodTooltip);
            iptui.internal.utilities.setToolTipText(this.ColorButton,this.ColorTooltip);
            iptui.internal.utilities.setToolTipText(this.LinewidthSlider,this.LinewidthTooltip);
            iptui.internal.utilities.setToolTipText(this.DecimationSlider,this.DecimationTooltip);
            iptui.internal.utilities.setToolTipText(this.ScaleSlider,this.ScaleTooltip);
            
            iptui.internal.utilities.setToolTipText(this.HSSmoothnessSlider,this.HSSmoothnessTooltip);
            iptui.internal.utilities.setToolTipText(this.HSSmoothnessText,this.HSSmoothnessTooltip);
            iptui.internal.utilities.setToolTipText(this.HSMaxIterationSlider,this.HSMaxIterationTooltip);
            iptui.internal.utilities.setToolTipText(this.HSMaxIterationText,this.HSMaxIterationTooltip);
            iptui.internal.utilities.setToolTipText(this.HSVelocityDifferenceSlider,this.HSVelocityDifferenceTooltip);
            iptui.internal.utilities.setToolTipText(this.HSVelocityDifferenceText,this.HSVelocityDifferenceTooltip);
        end
        function status(this,str)
            % Update StatusBarText in parent app.
            iptui.internal.utilities.setStatusBarText(this.Tab.Parent.Name,str);
        end
    end
    
    %======================================================================
    %
    % Layout methods
    % ------------------
    % These functions generate the toolstrip layout design, which includes
    % creating widgets (panels, buttons, sliders,...), defining their
    % properties (position, icon,...), and adding listeners for events.
    % Each section in a toolstrip tab should have its own layout method.
    %
    %======================================================================
    methods (Access=private)
        function layoutSettingsSection(this)
            % Create button for choosing a method
            this.MethodLabel = toolpack.component.TSLabel(this.MethodLabelStr);
            this.MethodButton = toolpack.component.TSDropDownButton(this.DefaultMethod);
            this.MethodButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Add popup menu to method button
            items(1) = struct(...
                'Title',this.MethodPopupOption1Title,...
                'Description',this.MethodPopupOption1Desc,...
                'Icon',[],...
                'Header',false);
            items(2) = struct(...
                'Title',this.MethodPopupOption2Title,...
                'Description',this.MethodPopupOption2Desc,...
                'Icon',[],...
                'Header',false);
            this.MethodButton.Popup = toolpack.component.TSDropDownPopup(items,'single_line_description');
            
            % Create button to set color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            this.ColorLabel = toolpack.component.TSLabel(this.ColorLabelStr);
            this.ColorButton = toolpack.component.TSButton();
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            
            % Line width slider
            this.LinewidthLabel = toolpack.component.TSLabel(this.LinewidthLabelStr);
            this.LinewidthSlider = toolpack.component.TSSlider(5,100,this.DefaultLinewidth*10);
            this.LinewidthSlider.MinorTickSpacing = 5;
            
            % Create widgets for optical flow decimation
            this.DecimationLabel = toolpack.component.TSLabel(this.DecimationLabelStr);
            this.DecimationSlider = toolpack.component.TSSlider(1,20,this.DefaultDecimation);
            this.DecimationSlider.MinorTickSpacing = 1;
            
            % Create widgets for optical flow scale
            this.ScaleLabel = toolpack.component.TSLabel(this.ScaleLabelStr);
            this.ScaleSlider = toolpack.component.TSSlider(5,100,this.DefaultScale);
            this.ScaleSlider.MinorTickSpacing = 5;
            
            % Setup toolstrip panel
            subpanel1 = toolpack.component.TSPanel(...
                '3dlu,r:p,2dlu,52dlu,f:p,3dlu',...
                '4dlu,f:p,0dlu,f:p'); %(columns,rows)
            subpanel1.add(this.MethodLabel,     'xy(2,2)');
            subpanel1.add(this.MethodButton, 	'xywh(4,2,2,1)');
            subpanel1.add(this.ColorLabel,     	'xy(2,4)');
            subpanel1.add(this.ColorButton,     'xy(4,4,''l,c'')');
            
            subpanel2 = toolpack.component.TSPanel(...
                '3dlu,r:p,2dlu,40dlu,f:p,1dlu',...
                '3dlu,f:p,1dlu,f:p,1dlu,f:p');
            subpanel2.add(this.LinewidthLabel,  'xy(2,2)');
            subpanel2.add(this.LinewidthSlider, 'xywh(4,2,2,1)');
            subpanel2.add(this.DecimationLabel, 'xy(2,4)');
            subpanel2.add(this.DecimationSlider,'xywh(4,4,2,1)');
            subpanel2.add(this.ScaleLabel,      'xy(2,6)');
            subpanel2.add(this.ScaleSlider,  	'xywh(4,6,2,1)');
            
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel1,'xy(1,1)');
            panel.add(subpanel2,'xy(3,1)');
            
            % Add panel to section
            this.SettingsSection.add(panel);
        end
        function layoutHornSchunckSection(this)
            % Smoothness
            this.HSSmoothnessLabel = toolpack.component.TSLabel(this.HSSmoothnessLabelStr);
            this.HSSmoothnessSlider = toolpack.component.TSSlider(0.1,10,this.DefaultHSSmoothness);
            this.HSSmoothnessSlider.MinorTickSpacing = 0.1;
            this.HSSmoothnessSlider.Name = 'HSSmoothness';
            this.HSSmoothnessText = toolpack.component.TSTextField(num2str(this.DefaultHSSmoothness),3);
            this.HSSmoothnessText.Name = 'HSSmoothness';
            
            % MaxIteration
            this.HSMaxIterationLabel = toolpack.component.TSLabel(this.HSMaxIterationLabelStr);
            this.HSMaxIterationSlider = toolpack.component.TSSlider(1,1000,this.DefaultHSMaxIteration);
            this.HSMaxIterationSlider.MinorTickSpacing = 10;
            this.HSMaxIterationSlider.MajorTickSpacing = 100;
            this.HSMaxIterationSlider.Name = 'HSMaxIteration';
            this.HSMaxIterationText = toolpack.component.TSTextField(num2str(this.DefaultHSMaxIteration),3);
            this.HSMaxIterationText.Name = 'HSMaxIteration';
            
            % VelocityDifference
            this.HSVelocityDifferenceLabel = toolpack.component.TSLabel(this.HSVelocityDifferenceLabelStr);
            this.HSVelocityDifferenceSlider = toolpack.component.TSSlider(0,100,this.DefaultHSVelocityDifference);
            this.HSVelocityDifferenceSlider.MinorTickSpacing = 5;
            this.HSVelocityDifferenceSlider.Name = 'HSVelocityDifference';
            this.HSVelocityDifferenceText = toolpack.component.TSTextField(num2str(this.DefaultHSVelocityDifference),3);
            this.HSVelocityDifferenceText.Name = 'HSVelocityDifference';
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('3dlu,r:p,2dlu,40dlu,0dlu,f:p','2dlu,f:p,2dlu,f:p,2dlu,f:p'); %(columns,rows)
            panel.add(this.HSSmoothnessLabel,           'xy(2,2)');
            panel.add(this.HSSmoothnessSlider,          'xy(4,2)');
            panel.add(this.HSSmoothnessText,            'xy(6,2,''l,c'')');
            panel.add(this.HSMaxIterationLabel,         'xy(2,4)');
            panel.add(this.HSMaxIterationSlider,        'xy(4,4)');
            panel.add(this.HSMaxIterationText,       	'xy(6,4,''l,c'')');
            panel.add(this.HSVelocityDifferenceLabel,   'xy(2,6)');
            panel.add(this.HSVelocityDifferenceSlider,  'xy(4,6)');
            panel.add(this.HSVelocityDifferenceText,  	'xy(6,6,''l,c'')');
            
            % Add panel to section
            this.HornSchunckSection.add(panel);
        end
        function layoutLucasKanadeSection(this)
            %***NEED TO UPDATE (MRE)***
        end
    end
    
    %======================================================================
    %
    % Listener methods
    % --------------------
    % These functions are called when specific actions are executed on the
    % manager, such as clicking on a button or repositioning a slider.
    %
    %======================================================================
    methods (Access=private)
        %******************************************************************
        % Settings
        %******************************************************************
        function setmethod(this,obj,~)
            this.status('');
            switch obj.SelectedIndex
                case 1
                    this.Method = 'horn-schunck';
                    this.MethodButton.Text = this.MethodPopupOption1Title;
                    this.Flag = ~this.Flag;
                case 2
                    this.Method = 'lucas-kanade';
                    this.MethodButton.Text = this.MethodPopupOption2Title;
                    this.Flag = ~this.Flag;
            end
        end
        function setcolor(this,obj,~)
            % Retrieve current (or default) color
            if isempty(this.Color)
                clr = str2rgb(this.DefaultColor);
            else
                clr = this.Color;
            end
            
            % Query user to select new color
            clr = uisetcolor(clr,'Select Optical Flow Color');
            
            % Update icon (unless user canceled color dialog box)
            if ~isequal(clr,0)
                gui.setTSButtonIconFromImage(obj,makeicon(16,16,clr));
                this.Color = clr;
                this.Flag = ~this.Flag;
            end
        end
        function setlinewidth(this,obj,~)
            % Update line width of optical flow vectors.
            this.Linewidth = obj.Value/10;
            this.Flag = ~this.Flag;
        end
        function setdecimation(this,obj,~)
            % Update decimation of optical flow vectors.
            this.Decimation = obj.Value;
            this.Flag = ~this.Flag;
        end
        function setscale(this,obj,~)
            % Update scale of optical flow vectors.
            this.Scale = obj.Value;
            this.Flag = ~this.Flag;
        end
        
        %******************************************************************
        % Horn-Schunck
        %******************************************************************
        function updateslider(this,obj,~)
            fprintf('%s\tupdateslider\t%s\n',datestr(now),obj.Name);
            
            this.(strcat(obj.Name,'Text')).Text = num2str(obj.Value);
        end
        function updatetext(this,obj,~)
            % Update slider corresponding to edited textbox.
            fprintf('%s\tupdatetext\t%s\n',datestr(now),obj.Name);
            
            slider = this.(strcat(obj.Name,'Slider')); %link textbox to slider
            ind = str2double(obj.Text); %get potential new value
            if isscalar(ind) && isfinite(ind) %update slider object
                ind = max(ind,slider.Minimum);
                ind = min(ind,slider.Maximum);
                slider.Value = ind;
            end
            obj.Text = num2str(slider.Value);
        end
    end
    
    % Set/Get property methods.
    methods
        %******************************************************************
        % Set
        %******************************************************************
        
        %******************************************************************
        % Get
        %******************************************************************
        function h = get.Handles(this)
            h.Method = {};
            
            h.Settings = {...
                this.MethodLabel,...
                this.MethodButton,...
                this.ColorLabel,...
                this.ColorButton,...
                this.LinewidthLabel,...
                this.LinewidthSlider,...
                this.DecimationLabel,...
                this.DecimationSlider,...
                this.ScaleLabel,...
                this.ScaleSlider};
            h.HornSchunck = {...
                this.HSSmoothnessLabel,...
                this.HSSmoothnessSlider,...
                this.HSMaxIterationLabel,...
                this.HSMaxIterationSlider,...
                this.HSVelocityDifferenceLabel,...
                this.HSVelocityDifferenceSlider};
            h.LucasKanade = {...
                };
            h.All = [...
                h.Settings,...
                h.HornSchunck,...
                h.LucasKanade];
        end
        function X = get.QuiverInput(this)
            offset = 1; % this could be user input
            
            % Get velocity vectors
            Vx = this.OpticalFlow.Vx;
            Vy = this.OpticalFlow.Vy;
            
            % Only look at significant magnitudes
            mask = this.OpticalFlow.Magnitude>=0.2*max(this.OpticalFlow.Magnitude(:));
            Vx(~mask) = 0;
            Vy(~mask) = 0;
            
            % Decimate the signals
            [row,col] = size(Vx);
            if numel(Vx)>1
                rowind = offset:this.Decimation:(row-offset+1);
                colind = offset:this.Decimation:(col-offset+1);
            else
                rowind = 1:row;
                colind = 1:col;
            end 
            [x,y] = meshgrid(colind,rowind);
            ind = sub2ind([row,col],y(:),x(:));
            Vx = Vx(ind);
            Vy = Vy(ind);
            
            % Scale the signals
            u = Vx.*this.Scale;
            v = Vy.*this.Scale;
            
            % Only return positive flow
            thold = 0.01;
            mask = abs(u)>=thold*max(abs(u)) | abs(v)>=thold*max(abs(v));
%             fprintf('%d + %d = %d\n',sum(mask),sum(~mask),numel(mask));
%             X = [x(:),y(:),u(:),v(:)];
            X = [x(mask),y(mask),u(mask),v(mask)];
        end
    end
    
end

