classdef VideoManager < handle
%GUI.VIDEOMANAGER Add video controls to an app.
%   GUI.VIDEOMANAGER(TAB) manages video playback controls in a specified
%   tab of a user interface. TAB must be a tool tab component, i.e. a
%   toolpack.desktop.ToolTab object.
%
%   THIS = GUI.VIDEOMANAGER(TAB) returns the video manager object itself,
%   which can be stored, for example, as a property of the user interface
%   object.
%
%   Requirements:
%   1) This class does not currently require any data from other classes
%   (e.g. a Parent class).
%
%   See also TOOLPACK.DESKTOP.TOOLTAB.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Buttons = toolpack.component.TSButton.empty(0,4);
        ToggleButton = toolpack.component.TSButton.empty(0,1);
        Slider = toolpack.component.TSSlider.empty(0,1);
        
        NumFrames
        FrameLim
        FrameRate
        PreviousFrame
        
        Flag
    end
    properties (Access=private,Constant) %widget properties
        ButtonName = {'prev','play','next','settings'}; %also corresponds to the name of listener functions
        ButtonText = {'','','',''};
        ButtonIcon = {'PREV_16','PLAY_16','NEXT_16','SETTINGS_16'};
        ButtonTooltip = {'Go to previous frame','Play','Go to next frame','Modify video settings'};
    end
    properties (SetObservable=true)
        CurrentFrame
    end
    
    methods
        function this = VideoManager(tab)
            % Set default properties
            this.NumFrames      = -1;
            this.CurrentFrame   = 1;
            this.FrameLim       = [1 100];
            this.FrameRate      = 20;
            
            % Create buttons
            N = size(this.Buttons,2); %number of buttons
            for ii=1:N
                txt = this.ButtonText{ii};
                icon = gui.Icon.(this.ButtonIcon{ii});
                name = this.ButtonName{ii};
                tooltip = this.ButtonTooltip{ii};
                
                this.Buttons(ii) = toolpack.component.TSButton(txt,icon);
                this.Buttons(ii).Name = name;
                this.Buttons(ii).Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
                this.Buttons(ii).Peer.setToolTipText(tooltip);
                
                addlistener(this.Buttons(ii),'ActionPerformed',@(obj,evt) this.(obj.Name));
            end
            addlistener(this.button('play'),'ActionPerformed',@(obj,evt) this.flag);
            
            % Create toggle button for looping video
            this.ToggleButton = toolpack.component.TSToggleButton(gui.Icon.REFRESH_16);
            this.ToggleButton.Name = 'loop';
            this.ToggleButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            this.ToggleButton.Peer.setToolTipText('Loop video');
            
            % Create slider for controlling current frame
            this.Slider = toolpack.component.TSSlider(this.FrameLim(1),this.FrameLim(2),this.CurrentFrame);
            this.Slider.MinorTickSpacing = 1;
            this.Slider.MajorTickSpacing = 10;
            addlistener(this.Slider,'StateChanged',@this.updateSlider);
            
            % Create toolstrip panel and add widgets to panel
            panel = toolpack.component.TSPanel('f:p,f:p,f:p,f:p,f:p','b:p:g,t:p:g'); %(columns,rows)
            panel.add(this.Buttons(1),'xy(1,1)');
            panel.add(this.Buttons(2),'xy(2,1)');
            panel.add(this.Buttons(3),'xy(3,1)');
            panel.add(this.ToggleButton,'xy(4,1)');
            panel.add(this.Buttons(4),'xy(5,1)');
            panel.add(this.Slider,'xywh(1,2,5,1)');
            
            % Add section to the specified tab and add panel to section
%             tab = get(app.ToolGroup,tab);
            section = tab.addSection('VideoControls','Video Controls');
            section.add(panel);
        end
        function setNumberOfFrames(this,n)
            % Public method that allows external objects to update the 
            % number of frames in a video.
            this.NumFrames = n;
            this.FrameLim = [1 n];
            this.Slider.Maximum = n;
        end
        function disable(this)
            % Disable all controls in the toolstrip section.
            [this.Buttons.Enabled] = deal(false);
            this.ToggleButton.Enabled = false;
            this.Slider.Enabled = false;
        end
        function enable(this)
            % Enable all controls in the toolstrip section.
            [this.Buttons.Enabled] = deal(true);
            this.ToggleButton.Enabled = true;
            this.Slider.Enabled = true;
        end
        function reset(this)
            % Does nothing right now. Edit if needed.
        end
        function h = button(this,name)
            % Get button object by name.
            h = findobj(this.Buttons,'Name',name);
        end
    end
    
    methods (Access=private) %listeners
        function prev(this)
            % Go to previous frame
            if this.ToggleButton.Selected %loop
                a = this.Slider.Minimum;
                b = this.Slider.Maximum;
                c = this.Slider.Value;
                this.Slider.Value = mod(c-a-1,b-a+1)+a;
            else %don't loop
                this.Slider.Value = max(this.Slider.Value-1,this.Slider.Minimum);
            end
        end
        function play(this)
            % Play or pause the video
            % -----------------------
            % Set flag to notify play state
            this.Flag = true;
            
            % Change play button icon and tooltiptext to pause
            this.button('play').Icon = gui.Icon.PAUSE_16;
            this.button('play').Peer.setToolTipText('Pause');
            
            try
                % Play video until user clicks pause button.
                while this.Flag
                    t = tic;

                    % Move slider to next frame
                    if this.ToggleButton.Selected %loop
                        a = this.Slider.Minimum;
                        b = this.Slider.Maximum;
                        c = this.Slider.Value;
                        this.Slider.Value = mod(c-a+1,b-a+1)+a;
                    else %don't loop
                        b = this.Slider.Maximum;
                        c = this.Slider.Value;
                        this.Slider.Value = min(c+1,b);
                        if isequal(this.Slider.Value,b)
                            this.Flag = false;
                        end
                    end
                    
                    % Flush event queue for listeners in view to process and
                    % update graphics in response to changes
                    drawnow;

                    % Pause to hit target frame rate (may not be possible for high fps!)
                    pause(1/this.FrameRate-toc(t));
                end
                
                % Change play button icon and tooltiptext back to play
                this.button('play').Icon = gui.Icon.PLAY_16;
                this.button('play').Peer.setToolTipText('Play');
            catch ME
                if strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
                    % Deleting the app while it is running will cause this
                    % to become an invalid handle. Do nothing, the app is
                    % already being destroyed.
                else
                    rethrow(ME)
                end
            end
        end
        function next(this)
            % Go to next frame
            if this.ToggleButton.Selected %loop
                a = this.Slider.Minimum;
                b = this.Slider.Maximum;
                c = this.Slider.Value;
                this.Slider.Value = mod(c-a+1,b-a+1)+a;
            else %don't loop
                this.Slider.Value = min(this.Slider.Value+1,this.Slider.Maximum);
            end
        end
        function loop(this)
        end
        function settings(this)
        end
        function flag(this)
            % Toggle flag, which controls whether to pause the video or not
            this.Flag = ~this.Flag;
        end
        function updateSlider(this,obj,~)
            this.PreviousFrame = this.CurrentFrame;
            this.CurrentFrame = obj.Value;
        end
    end
    
end

