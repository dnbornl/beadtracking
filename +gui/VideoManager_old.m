classdef VideoManager_old < handle
%GUI.VIDEOMANAGER Add video controls to a user interface.
%   GUI.VIDEOMANAGER(TAB) manages video playback controls in a specified
%   tab of a user interface.
%
%   THIS = GUI.VIDEOMANAGER(TAB) returns the object itself, which can be
%   stored, for example, as a property of the user interface object.
%
%   Requirements:
%   1) This class does not currently require any data from other classes
%   (e.g. a Parent class).

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Section
        Handles
        
        ContinuePlayingFlag
        StopPlayingFlag
        
        CurrentFrameLabel
        CurrentFrameText
        CurrentFrameUnits
        FrameRateLabel
        FrameRateText
        FrameRateUnits
        FoiLabel
        StartFrameText
        FoiLabel2
        EndFrameText
        PrevFrameButton
        PlayButton
        NextFrameButton
        FrameSlider
        
        PreviousFrame
        NumFrames
        FrameRate
    end
    properties (Access=private,Constant)
        PlayIcon      	= gui.Icon.PLAY_16;
        PauseIcon    	= gui.Icon.PAUSE_16;
        PrevFrameIcon 	= gui.Icon.PREV_16;
        NextFrameIcon 	= gui.Icon.NEXT_16;
        
        CurrentFrameTooltip    	= 'Index of the currently visible frame';
        FrameRateTooltip       	= 'Frame rate of video playback';
        StartFrameTooltip       = 'Modify starting frame';
        EndFrameTooltip     	= 'Modify ending frame';
        PlayTooltip             = 'Play';
        PauseTooltip            = 'Pause';
        PrevFrameTooltip        = 'Go to previous frame';
        NextFrameTooltip        = 'Go to next frame';
        FrameSliderTooltip      = 'Change frames';
        
        DefaultCurrentFrame         = 1;
        DefaultCurrentFrameUnits  	= '/ ?';
        DefaultFrameRate            = 20;
        DefaultFrameRateUnits       = 'fps';
        DefaultStartFrame           = 1;
        DefaultEndFrame             = NaN;
        DefaultFrameSlider       	= 1;
        DefaultFrameSliderMinimum 	= 1;
        DefaultFrameSliderMaximum 	= 100;
    end
    properties (SetObservable=true)
        CurrentFrame
    end
    
    %======================================================================
    %
    % Public methods
    % --------------------
    % These functions can be called by external objects/functions.
    %
    %======================================================================
    methods
        function this = VideoManager_old(app,tab)
            % Construct the toolstrip section in a specified tab.
            tab = get(app.ToolGroup,tab);
            this.Section = tab.addSection('VideoControls','Video Controls');
            
            % Set properties
            this.NumFrames      = -1;
            this.PreviousFrame  = 1;
            this.CurrentFrame   = 1;
            this.FrameRate      = this.DefaultFrameRate;
            
            % Create widgets and add listeners
            this.addwidgets();
            this.addtooltip();
            this.addlisteners();
            this.layout();
            
            % Update handles structure
            this.Handles = {...
                this.CurrentFrameLabel,...
                this.CurrentFrameText,...
                this.CurrentFrameUnits,...
                this.FrameRateLabel,...
                this.FrameRateText,...
                this.FrameRateUnits,...
                this.FoiLabel,...
                this.StartFrameText,...
                this.FoiLabel2,...
                this.EndFrameText,...
                this.PrevFrameButton,...
                this.PlayButton,...
                this.NextFrameButton,...
                this.FrameSlider};
        end
        function setNumberOfFrames(this,n)
            % Public method that allows external objects to update the 
            % number of frames in a video.
            this.NumFrames = n;
            this.updateControls();
        end
        function disable(this)
            % Disable all controls in the toolstrip section.
            for ii=1:length(this.Handles)
                this.Handles{ii}.Enabled = false;
            end
        end
        function enable(this)
            % Enable all controls in the toolstrip section.
            for ii=1:length(this.Handles)
                this.Handles{ii}.Enabled = true;
            end
        end
        function reset(this)
%             this.CurrentFrameText.Text = num2str(this.DefaultCurrentFrame);
%             this.CurrentFrameUnits.Text = this.DefaultCurrentFrameUnits;
%             this.FrameRateText.Text = num2str(this.DefaultFrameRate);
%             this.StartFrameText.Text = num2str(this.DefaultStartFrame);
%             this.EndFrameText.Text = num2str(this.DefaultEndFrame);
%             this.FrameSlider.Value = this.DefaultFrameSlider;
%             this.FrameSlider.Maximum = this.DefaultFrameSliderMaximum;
            
%             this.StartFrameText.Text = this.StartFrameTextDefault;
%             this.EndFrameText.Text = num2str(this.Backend.NumFrames);
%             this.FrameSlider.Minimum = this.FrameSliderMinimumDefault;
%             this.FrameSlider.Maximum = this.Backend.NumFrames;
%             this.FrameSlider.Value = this.FrameSliderDefault;
%             this.FrameRateText.Text = this.FrameRateTextDefault;
        end
    end
    
    %======================================================================
    %
    % Private methods
    % --------------------
    % These functions are only called within this class file.
    %
    %======================================================================
    methods (Access=private)
        function addlisteners(this)
            % Add callback functions for each interactive widget.
            addlistener(this.CurrentFrameText,'TextEdited',@this.updateCurrentFrame);
            addlistener(this.FrameRateText,'TextEdited',@this.updateFrameRate);
            addlistener(this.StartFrameText,'TextEdited',@this.updateStartFrame);
            addlistener(this.EndFrameText,'TextEdited',@this.updateEndFrame);
            addlistener(this.PrevFrameButton,'ActionPerformed',@this.gotoPrevFrame);
            addlistener(this.PlayButton,'ActionPerformed',@this.updatePlayButton);
            addlistener(this.PlayButton,'ActionPerformed',@this.updatePlayState);
            addlistener(this.NextFrameButton,'ActionPerformed',@this.gotoNextFrame);
            addlistener(this.FrameSlider,'StateChanged',@this.updateFrameSlider);
        end
        function addtooltip(this)
            % Display text when user hovers over a control.
            iptui.internal.utilities.setToolTipText(this.CurrentFrameText,this.CurrentFrameTooltip);
            iptui.internal.utilities.setToolTipText(this.FrameRateText,this.FrameRateTooltip);
            iptui.internal.utilities.setToolTipText(this.StartFrameText,this.StartFrameTooltip);
            iptui.internal.utilities.setToolTipText(this.EndFrameText,this.EndFrameTooltip);
            iptui.internal.utilities.setToolTipText(this.PrevFrameButton,this.PrevFrameTooltip);
            iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayTooltip);
            iptui.internal.utilities.setToolTipText(this.NextFrameButton,this.NextFrameTooltip);
            iptui.internal.utilities.setToolTipText(this.FrameSlider,this.FrameSliderTooltip);
        end
        function addwidgets(this)
            % Current frame
            this.CurrentFrameLabel = toolpack.component.TSLabel('Current frame');
            this.CurrentFrameText = toolpack.component.TSTextField(num2str(this.DefaultCurrentFrame),3);
            this.CurrentFrameUnits = toolpack.component.TSLabel(this.DefaultCurrentFrameUnits);
            
            % Frame rate
            this.FrameRateLabel = toolpack.component.TSLabel('Frame rate');
            this.FrameRateText = toolpack.component.TSTextField(num2str(this.DefaultFrameRate),3);
            this.FrameRateUnits = toolpack.component.TSLabel(this.DefaultFrameRateUnits);
            
            % Frames of interest (FOI)
            this.FoiLabel = toolpack.component.TSLabel('Frames of interest (FOI)');
            this.StartFrameText = toolpack.component.TSTextField(num2str(this.DefaultStartFrame),3);
            this.FoiLabel2 = toolpack.component.TSLabel('to');
            this.EndFrameText = toolpack.component.TSTextField(num2str(this.DefaultEndFrame),3);
            
            % Previous frame
            this.PrevFrameButton = toolpack.component.TSButton('',this.PrevFrameIcon);
            this.PrevFrameButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Play/pause video
            this.PlayButton = toolpack.component.TSButton('',this.PlayIcon);
            this.PlayButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Next frame
            this.NextFrameButton = toolpack.component.TSButton('',this.NextFrameIcon);
            this.NextFrameButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Frame slider control
            this.FrameSlider = toolpack.component.TSSlider(...
                this.DefaultFrameSliderMinimum,...
                this.DefaultFrameSliderMaximum,...
                this.DefaultFrameSlider);
            this.FrameSlider.MinorTickSpacing = 1;
        end
        function layout(this)
            % Pack widgets into subpanels
            subpanel1 = toolpack.component.TSPanel(...
                '3dlu,r:p,3dlu,l:p,2dlu,f:p,10dlu,f:p,9dlu,f:p,3dlu,f:p,3dlu,f:p,10dlu',...
                '3dlu,f:p,3dlu,f:p'); %(columns,rows)
            subpanel1.add(this.CurrentFrameLabel,   'xy(2,2)');
            subpanel1.add(this.CurrentFrameText,    'xy(4,2,''l,c'')');
            subpanel1.add(this.CurrentFrameUnits,   'xy(6,2)');
            subpanel1.add(this.FrameRateLabel,      'xy(2,4)');
            subpanel1.add(this.FrameRateText,       'xy(4,4,''l,c'')');
            subpanel1.add(this.FrameRateUnits,      'xy(6,4)');
            subpanel1.add(this.FoiLabel,            'xywh(8,2,8,1)');
            subpanel1.add(this.StartFrameText,      'xy(10,4,''l,c'')');
            subpanel1.add(this.FoiLabel2,           'xy(12,4)');
            subpanel1.add(this.EndFrameText,        'xy(14,4,''l,c'')');
            
            subpanel2 = toolpack.component.TSPanel('1dlu,f:p,f:p,f:p,1dlu,f:p','f:p:g'); %(columns,rows)
            subpanel2.add(this.PrevFrameButton, 'xy(2,1)');
            subpanel2.add(this.PlayButton,      'xy(3,1)');
            subpanel2.add(this.NextFrameButton, 'xy(4,1)');
            subpanel2.add(this.FrameSlider,     'xy(6,1)');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,2dlu,f:p:g'); %(columns,rows)
            panel.add(subpanel1,'xy(1,1)');
            panel.add(subpanel2,'xy(1,3)');
            
            % Add panel to section
            this.Section.add(panel);
        end
        function playvideo(this)
            % Play video until user clicks pause button.
            this.StopPlayingFlag = false;
            while ~this.StopPlayingFlag
                t = tic;
                
                % Set FrameSlider to next frame
                this.FrameSlider.Value = mod((this.FrameSlider.Value-this.FrameSlider.Minimum)+1,this.FrameSlider.Maximum-this.FrameSlider.Minimum+1)+this.FrameSlider.Minimum;
                
                % Flush event queue for listeners in view to process and
                % update graphics in response to changes
                drawnow;
                
                % Pause to hit target frame rate (may not be possible for high fps!)
                pause(1/this.FrameRate-toc(t));
            end
        end
        function pausevideo(this)
            this.StopPlayingFlag = true;
        end
        function updateControls(this)
            this.CurrentFrameUnits.Text = sprintf('/ %d',this.NumFrames);
            this.EndFrameText.Text = num2str(this.NumFrames);
            this.FrameSlider.Maximum = this.NumFrames;
        end
    end
    
    %======================================================================
    %
    % Listener methods
    % --------------------
    % These functions are called when specific actions are executed in the
    % VideoManager, such as clicking on a button or repositioning a slider.
    %
    %======================================================================
    methods (Access=private)
        function updateCurrentFrame(this,obj,~)
            % Callback for CurrentFrameText.
            % ------------------------------
            % Get potential new current frame
            ind = str2double(obj.Text);
            
            % Check if value is valid
            isok = isscalar(ind) ...
                && isfinite(ind) ...
                && ind==floor(ind) ...
                && ind>=this.FrameSlider.Minimum ...
                && ind<=this.FrameSlider.Maximum;
            
            if isok %then update FrameSlider object
                this.FrameSlider.Value = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Value);
            end
        end
        function updateFrameRate(this,obj,~)
            % Callback for FrameRateText.
            % ---------------------------
            % Get potential new frame rate
            fps = str2double(obj.Text);
            
            % Check if value is valid
            isok = isscalar(fps) ...
                && isfinite(fps) ...
                && fps>0;
            
            if isok %then update FrameRate property
                this.FrameRate = round(fps);
            else %reset to previous value
                obj.Text = num2str(this.FrameRate);
            end
        end
        function updateStartFrame(this,obj,~)
            % Callback for StartFrameText.
            % ----------------------------
            % Get potential new starting frame
            ind = str2double(obj.Text);
            
            % Check if value is valid
            isok = isscalar(ind) ...
                && isfinite(ind) ...
                && ind==floor(ind) ...
                && ind>0 ...
                && ind<=this.FrameSlider.Maximum;
            
            if  isok %then update FrameSlider minimum
                this.FrameSlider.Minimum = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Minimum);
            end
        end
        function updateEndFrame(this,obj,~)
            % Callback for EndFrameText.
            % --------------------------
            % Get potential new ending frame
            ind = str2double(obj.Text);
            
            % Check if value is valid
            isok = isscalar(ind) ...
                && isfinite(ind) ...
                && ind==floor(ind) ...
                && ind>=this.FrameSlider.Minimum ...
                && ind<=this.NumFrames;
            
            if isok %then update FrameSlider maximum
                this.FrameSlider.Maximum = ind;
            else %reset to previous value
                obj.Text = num2str(this.FrameSlider.Maximum);
            end
        end
        function gotoPrevFrame(this,~,~)
            % Callback for PrevFrameButton.
            % -----------------------------
            this.FrameSlider.Value = max(this.FrameSlider.Value-1,this.FrameSlider.Minimum);
        end
        function gotoNextFrame(this,~,~)
            % Callback for NextFrameButton.
            % -----------------------------
            this.FrameSlider.Value = min(this.FrameSlider.Value+1,this.FrameSlider.Maximum);
        end
        function updatePlayButton(this,~,~)
            % Play or pause the video
            % -----------------------
            % Set flag to notify play state
            this.ContinuePlayingFlag = true;

            % Change PlayButton icon and tooltiptext to pause
            this.PlayButton.Icon = this.PauseIcon;
            iptui.internal.utilities.setToolTipText(this.PlayButton,this.PauseTooltip);

            try
                this.playvideo();

                % Change PlayButton icon and tooltiptext to play
                this.PlayButton.Icon = this.PlayIcon;
                iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayTooltip);
            catch ME
                if strcmp(ME.identifier,'images:SegmentationBackend:emptyMask')
                    % Change PlayButton icon and tooltiptext to play
                    this.PlayButton.Icon = this.PlayIcon;
                    iptui.internal.utilities.setToolTipText(this.PlayButton,this.PlayTooltip);
                    
                elseif strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                    % Deleting the app while it is running will cause this
                    % to become an invalid handle. Do nothing, the app is
                    % already being destroyed.
                else
                    rethrow(ME)
                end
            end
        end
        function updatePlayState(this,~,~)
            % Update state of play button.
            % ----------------------------
            this.ContinuePlayingFlag = ~this.ContinuePlayingFlag;
            if ~this.ContinuePlayingFlag
                this.pausevideo();
            end
        end
        function updateFrameSlider(this,obj,~)
            % Callback for FrameSlider.
            % -------------------------
            this.CurrentFrameText.Text = num2str(obj.Value);
            this.PreviousFrame = this.CurrentFrame;
            this.CurrentFrame = obj.Value;
        end
    end
    
end

