classdef VideoTools < handle
%GUI.VIDEOTOOLS Video controls for graphical user interfaces.
%   TOOLS = GUI.VIDEOTOOLS() creates video tools for viewing image
%   sequences in an app. The highest level object is this.Section
%   (toolpack.desktop.ToolSection), which can be added to a
%   toolpack.desktop.ToolTab.
%
%   addlisteners(TOOLS,APP) activates video listener functions in an APP,
%   which must be an object that includes the property 'ImageHandle'.
%
%   Example: Add video tools to an existing app (an object containing 
%   toolpack.desktop.___ components).
%
%       videotools = gui.VideoTools();
%       unpack(videotools,app);
%       addlisteners(videotools,app);
%
%   See also toolpack.desktop.ToolGroup, toolpack.desktop.ToolTab, 
%   toolpack.desktop.ToolSection.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Name = 'Video Tools';
        
        Section = toolpack.desktop.ToolSection.empty(0);
        
        Button = toolpack.component.TSButton.empty(0);
        ToggleButton = toolpack.component.TSButton.empty(0);
        Slider = toolpack.component.TSSlider.empty(0);
        
        NumFrames
        FrameLim
        FrameRate
        PreviousFrame
        
        Flag
    end
    properties (SetObservable=true)
        CurrentFrame
    end
    properties (Constant) %defaults
        DefaultCurrentFrame = 1;
        DefaultNumFrames = -1;
        DefaultFrameLim = [1 100];
        DefaultFrameRate = 20;
    end
    
    methods
        function this = VideoTools()
            % Create section
            this.Section = toolpack.desktop.ToolSection('video','Video Controls');
            
            % Set default properties
            this.CurrentFrame = this.DefaultCurrentFrame;
            this.NumFrames = this.DefaultNumFrames;
            this.FrameLim = this.DefaultFrameLim;
            this.FrameRate = this.DefaultFrameRate;
            
            % Create buttons for video controls
            icon = gui.Icon.PREV_16;
            button = toolpack.component.TSButton(icon);
            button.Name = 'prev';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Go to previous frame');
            add(this,'Button',button);
            
            icon = gui.Icon.PLAY_16;
            button = toolpack.component.TSButton(icon);
            button.Name = 'play';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Play');
            add(this,'Button',button);
            
            icon = gui.Icon.NEXT_16;
            button = toolpack.component.TSButton(icon);
            button.Name = 'next';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Go to next frame');
            add(this,'Button',button);
            
            icon = gui.Icon.SETTINGS_16;
            button = toolpack.component.TSButton(icon);
            button.Name = 'settings';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Modify video settings');
            add(this,'Button',button);
            
            % Create toggle button for looping video
            icon = gui.Icon.REFRESH_16;
            button = toolpack.component.TSToggleButton(icon);
            button.Name = 'loop';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            button.Peer.setToolTipText('Loop video');
            add(this,'ToggleButton',button);
            
            % Create slider for controlling current frame
            minimum = this.FrameLim(1);
            maximum = this.FrameLim(2);
            value = this.CurrentFrame;
            slider = toolpack.component.TSSlider(minimum,maximum,value);
            slider.Name = 'frame';
            slider.MinorTickSpacing = 1;
            slider.MajorTickSpacing = 10;
            add(this,'Slider',slider);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p,f:p,f:p,f:p','b:p:g,t:p:g'); %(columns,rows)
            panel.add(this.get('Button','prev'),'xy(1,1)');
            panel.add(this.get('Button','play'),'xy(2,1)');
            panel.add(this.get('Button','next'),'xy(3,1)');
            panel.add(this.get('ToggleButton','loop'),'xy(4,1)');
            panel.add(this.get('Button','settings'),'xy(5,1)');
            panel.add(this.get('Slider','frame'),'xywh(1,2,5,1)');
            
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
            addlistener(this.get('Button','prev'),'ActionPerformed',@(obj,evt) prev(this));
            addlistener(this.get('Button','play'),'ActionPerformed',@(obj,evt) play(this));
            addlistener(this.get('Button','play'),'ActionPerformed',@(obj,evt) flag(this));
            addlistener(this.get('Button','next'),'ActionPerformed',@(obj,evt) next(this));
            
            addlistener(this.get('Slider','frame'),'StateChanged',@(obj,evt) frame(this));
            addlistener(this.get('Button','settings'),'ActionPerformed',@(obj,evt) settingsdlg(this));
        end
        function setNumberOfFrames(this,n)
            % Public method that allows external objects to update the 
            % number of frames in a video.
            this.NumFrames = n;
            this.FrameLim = [1 n];
            this.get('Slider','frame').Maximum = n;
        end
        function disable(this)
        %DISABLE Set 'Enabled' property of all controls to false.
            [this.Button.Enabled] = deal(false);
            this.ToggleButton.Enabled = false;
            this.Slider.Enabled = false;
        end
        function enable(this)
        %ENABLE Set 'Enabled' property of all controls to true.
            [this.Button.Enabled] = deal(true);
            this.ToggleButton.Enabled = true;
            this.Slider.Enabled = true;
        end
        function obj = get(this,style,name)
        %GET Find instances of an object style based on its Name property.
        %   Example: Get the Button object named 'play'.
        %
        %       obj = get(this,'Button','play');
            
            obj = findobj(this.(style),'Name',name);
            
            if isempty(obj)
                error('There is no %s named %s.',style,name);
            elseif length(obj)>1
                warning('There are multiple %s named %s.',style,name);
            end
        end
        function unpack(this,app)
        %UNPACK Add tool properties to app properties.
            add(app,'Section',this.Section);
            add(app,'Button',this.Button);
            add(app,'ToggleButton',this.ToggleButton);
            add(app,'Slider',this.Slider);
        end
    end
    
    methods (Access=private) %listeners
        function prev(this)
        %PREV Go to previous frame.
            slider = this.get('Slider','frame');
            if this.get('ToggleButton','loop').Selected %loop
                minimum = slider.Minimum;
                maximum = slider.Maximum;
                slider.Value = mod(slider.Value-minimum-1,maximum-minimum+1)+minimum;
            else %don't loop
                slider.Value = max(slider.Value-1,slider.Minimum);
            end
        end
        function play(this)
        %PLAY Play/pause the video.
            % Set flag to notify play state
            this.Flag = true;
            
            % Get relevant objects and relevant properties
            button = this.get('Button','play');
            togglebutton = this.get('ToggleButton','loop');
            slider = this.get('Slider','frame');
            minimum = slider.Minimum;
            maximum = slider.Maximum;
            
            % Change play button icon and tooltiptext to pause
            button.Icon = gui.Icon.PAUSE_16;
            button.Peer.setToolTipText('Pause');
            
            try
                % Play video until user clicks pause button.
                while this.Flag
                    t = tic;
                    
                    % Move slider to next frame
                    if togglebutton.Selected %loop
                        slider.Value = mod(slider.Value-minimum+1,maximum-minimum+1)+minimum;
                    else %don't loop
                        slider.Value = min(slider.Value+1,maximum);
                        if isequal(slider.Value,maximum)
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
                button.Icon = gui.Icon.PLAY_16;
                button.Peer.setToolTipText('Play');
                
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
        %NEXT Go to next frame.
            slider = this.get('Slider','frame');
            if this.get('ToggleButton','loop').Selected %loop
                minimum = slider.Minimum;
                maximum = slider.Maximum;
                slider.Value = mod(slider.Value-minimum+1,maximum-minimum+1)+minimum;
            else %don't loop
                slider.Value = min(slider.Value+1,slider.Maximum);
            end
        end
        function settingsdlg(this)
        %SETTINGSDLG Open input dialog to modify video settings.
            prompt = {'Frame limits [min max]:','Frame rate (fps):'};
            dlgtitle = 'Settings';
            numlines = 1;
            default = {mat2str(this.FrameLim),mat2str(this.FrameRate)};
            answer = inputdlg(prompt,dlgtitle,numlines,default);
            
            if ~isempty(answer) %user clicked OK
                framelim = str2num(answer{1});
                framerate = str2double(answer{2});
                
                errstr = {};
                if ~gui.VideoTools.isvalidframelim(framelim)
                    errstr = cat(2,errstr,'Frame limits must be a 1-by-2 vector [min max] of positive integers.');
                end
                if ~gui.VideoTools.isvalidframerate(framerate)
                    errstr = cat(2,errstr,'Frame rate must be a positive, finite scalar.');
                end
                if ~isempty(errstr)
                    titlestr = 'Invalid Settings';
                    errdlg = errordlg(errstr,titlestr,'modal');
                    uiwait(errdlg);
                else
                    this.FrameLim = framelim;
                    this.FrameRate = framerate;
                end
            end
        end
        function flag(this)
        %FLAG Toggle flag, which controls when to pause the video.
            this.Flag = ~this.Flag;
        end
        function frame(this)
        %FRAME Update frame-related properties based on slider object.
            this.PreviousFrame = this.CurrentFrame;
            this.CurrentFrame = this.get('Slider','frame').Value;
        end
    end
    
    methods (Static)
        function tf = isvalidframelim(x)
        %ISVALIDFRAMELIM Check if frame limits are valid.
            tf = ~isempty(x) && numel(x)==2 && all(x>0) && ~any(isnan(x)) && ...
                all(isfinite(x)) && isequal(x,round(x)) && x(2)>x(1);
        end
        function tf = isvalidframerate(x)
        %ISVALIDFRAMERATE Check if frame rate is valid.
            tf = ~isempty(x) && ~isnan(x) && isfinite(x) && x>0;
        end
    end
end

