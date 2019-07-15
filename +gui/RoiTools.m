classdef RoiTools < handle
%GUI.ROITOOLS Region-of-interest tools for graphical user interfaces.
%   TOOLS = GUI.ROITOOLS() creates region of interest tools that can be
%   added to an app. The highest level object is this.Tab
%   (toolpack.desktop.ToolTab), which can be added to a
%   toolpack.desktop.ToolGroup.
%
%   See also toolpack.desktop.ToolGroup, toolpack.desktop.ToolTab, 
%   toolpack.desktop.ToolSection.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        Name = 'Region-of-interest Tools';
        DataPath
        
        Tab = toolpack.desktop.ToolTab.empty(0);
        Section = toolpack.desktop.ToolSection.empty(0);
        
        Button = toolpack.component.TSButton.empty(0);
        SplitButton = toolpack.component.TSSplitButton.empty(0);
        ToggleButton = toolpack.component.TSToggleButton.empty(0);
        Label = toolpack.component.TSLabel.empty(0);
        Slider = toolpack.component.TSSlider.empty(0);
    end
    properties (Access=private)
        RectangleContainer
        PolygonContainer
        FreehandContainer
    end
    properties (SetObservable=true)
        Color
        Flag = true;
        Mask
    end
    properties (Dependent)
        AlphaData
        Opacity
        Thickness
    end
    properties (Constant) %defaults
        DefaultColor = [0 0.45 0.74];
        DefaultOpacity = 70;
        DefaultThickness = 2;
    end
    
    methods
        function this = RoiTools()
            % Create tab
            this.Tab = toolpack.desktop.ToolTab('RoiTab','ROI');
            
            % Set properties
            this.Color = this.DefaultColor;
            % NOTE: Opacity and Thickness are dependent on the value of
            % the corresponding slider, so they do not need to be set here.
            
            % Create sections
            add(this,'Section',toolpack.desktop.ToolSection('FileSection','File'));
            add(this,'Section',toolpack.desktop.ToolSection('SettingsSection','Settings'));
            add(this,'Section',toolpack.desktop.ToolSection('DrawSection','Draw'));
            add(this,'Section',toolpack.desktop.ToolSection('ResponseSection','Response'));
            
            % Create widgets for each section
            layoutFileSection(this);
            layoutSettingsSection(this);
            layoutDrawSection(this);
            layoutResponseSection(this);
            
            % Add sections to tab
            for ii=1:length(this.Section)
                add(this.Tab,this.Section(ii));
            end
        end
        function add(this,style,obj)
        %ADD Append an object (OBJ) to the property denoted by STYLE.
        %	Example: Add a button to the ROI tools.
        %   
        %       button = toolpack.component.TSSplitButton('sample button');
        %       add(this,'Button',button);
        
            this.(style) = cat(2,this.(style),obj);
        end
        function addlisteners(this,app)
            addlistener(this.LoadButton,'ActionPerformed',@(obj,evt) listenerLoadButton(this,obj,evt,app));
            addlistener(this.LoadButton.Popup,'ListItemSelected',@(obj,evt) listenerLoadButtonPopup(this,obj,evt,app));
            addlistener(this.SaveButton,'ActionPerformed',@(obj,evt) listenerSaveButton(this,obj,evt,app));
            addlistener(this.SaveButton.Popup,'ListItemSelected',@(obj,evt) listenerSaveButtonPopup(this,obj,evt,app));
            addlistener(this.ResetButton,'ActionPerformed',@(obj,evt) listenerResetButton(this,obj,evt,app));
            
            addlistener(this.ColorButton,'ActionPerformed',@this.listenerColorButton);
            addlistener(this.OpacitySlider,'StateChanged',@this.flagApp);
            addlistener(this.ThicknessSlider,'StateChanged',@this.flagApp);
            addlistener(this.ShowPerimeterButton,'ItemStateChanged',@this.showperim);
            addlistener(this.ShowAreaButton,'ItemStateChanged',@this.showarea);
            
            addlistener(this.DrawRectangleButton,'ActionPerformed',@(obj,evt) listenerDrawRectangleButton(this,obj,evt,app));
            addlistener(this.DrawPolygonButton,'ActionPerformed',@(obj,evt) listenerDrawPolygonButton(this,obj,evt,app));
            addlistener(this.DrawFreehandButton,'ActionPerformed',@(obj,evt) listenerDrawFreehandButton(this,obj,evt,app));
            
            addlistener(this.OKButton,'ActionPerformed',@(obj,evt) listenerOKButton(this,obj,evt,app));
            addlistener(this.CancelButton,'ActionPerformed',@(obj,evt) listenerCancelButton(this,obj,evt,app));
        end
        function obj = get(this,style,name)
        %GET Find instances of an object style based on its Name property.
        %   Example: Get the Slider object named 'Opacity'.
        %
        %       obj = get(this,'Slider','Opacity');
        
            obj = findobj(this.(style),'Name',name);
            
            if isempty(obj)
                error('There is no %s named %s.',style,name);
            elseif length(obj)>1
                warning('There are multiple %s named %s.',style,name);
            end
        end
        function reset(this)
        %RESET Restore default settings.
            % Reset ROI color via button icon and color property
            gui.setTSButtonIconFromImage(get(this,'Button','Color'),makeicon(16,16,this.DefaultColor));
            this.Color = this.DefaultColor;
            
            % Reset ROI opacity via slider value
            slider = get(this,'Slider','Opacity');
            slider.Value = this.DefaultOpacity;
            
            % Reset ROI thickness via slider value
            slider = get(this,'Slider','Thickness');
            slider.Value = this.DefaultThickness;
            
            % Reset ShowPerimeter and ShowArea buttons
            button = get(this,'ToggleButton','ShowPerimeter');
            button.Selected = true; %the ShowPerimeter button callback will take care of the ShowArea button automatically
        end
    end
    
    methods (Access=private)
        function roiload(this,option,app)
            % Load an ROI mask.
            app.state('selecting roi data to load');
            
            switch option
                case 1 %query user to select ROI from file (mask and settings)
                    
                    cwd = pwd; %get current working directory
                    
                    % Change to directory where data is stored. If the 
                    % user did not specify DataPath or if the value of 
                    % DataPath is invalid for the current machine, then
                    % look in the default directory for NEURO demos.
                    if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                        cd(this.DataPath);
                    else
                        cd(fullfile(beadtracking.path,'resources','demos'));
                    end
                    
                    [filename,pathname] = uigetfile(...
                        {'*.mat','MAT-Files'; '*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
                        'Load ROI Mask From File');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    % If the user selected a file, load the ROI data.
                    % Otherwise, return an empty array.
                    if ~isempty(filename) && ~isequal(filename,0)
                        [~,~,ext] = fileparts(filename);
                        switch lower(ext(2:end))
                            case 'mat'
                                data = load(fullfile(pathname,filename));
                                roi = getfieldifexists(data,'roi');
                                mask = getfieldifexists(roi,'mask');
                                clr = getfieldifexists(roi,'color');
                                opacity = getfieldifexists(roi,'opacity');
                                thickness = getfieldifexists(roi,'thickness');
                                showarea = getfieldifexists(roi,'showarea');
                                
                            case {'jpg','jpeg','tif','tiff','png','gif'}
                                mask = imread(fullfile(pathname,filename));
                            otherwise
                                error('Unrecognized file type: %s', lower(ext(2:end)));
                        end
                    else
                        mask = [];
                    end
                    
                case 2 %query user to select ROI from file (mask only)
                    
                    cwd = pwd; %get current working directory
                    
                    % Change to directory where data is stored. If the 
                    % user did not specify DataPath or if the value of 
                    % DataPath is invalid for the current machine, then
                    % look in the default directory for NEURO demos.
                    if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                        cd(this.DataPath);
                    else
                        cd(fullfile(beadtracking.path,'resources','demos'));
                    end
                    
                    [filename,pathname] = uigetfile(...
                        {'*.mat','MAT-Files'; '*.jpg;*.tif;*.png;*.gif','All Image Files'; '*.*','All Files'},...
                        'Load ROI Mask From File');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    % If the user selected a file, load the ROI data.
                    % Otherwise, return an empty array.
                    if ~isempty(filename) && ~isequal(filename,0)
                        [~,~,ext] = fileparts(filename);
                        switch lower(ext(2:end))
                            case 'mat'
                                data = load(fullfile(pathname,filename));
                                roi = getfieldifexists(data,'roi');
                                mask = getfieldifexists(roi,'mask');
                                
                            case {'jpg','jpeg','tif','tiff','png','gif'}
                                mask = imread(fullfile(pathname,filename));
                            otherwise
                                error('Unrecognized file type: %s', lower(ext(2:end)));
                        end
                    else
                        mask = [];
                    end
                    
                case 3 %query user to select ROI from file (settings only)
                    
                    cwd = pwd; %get current working directory
                    
                    % Change to directory where data is stored. If the 
                    % user did not specify DataPath or if the value of 
                    % DataPath is invalid for the current machine, then
                    % look in the default directory for NEURO demos.
                    if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                        cd(this.DataPath);
                    else
                        cd(fullfile(beadtracking.path,'resources','demos'));
                    end
                    
                    [filename,pathname] = uigetfile(...
                        {'*.mat','MAT-Files'},...
                        'Load ROI Mask From File');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    % If the user selected a file, load the ROI data.
                    % Otherwise, return an empty array.
                    if ~isempty(filename) && ~isequal(filename,0)
                        [~,~,ext] = fileparts(filename);
                        switch lower(ext(2:end))
                            case 'mat'
                                data = load(fullfile(pathname,filename));
                                roi = getfieldifexists(data,'roi');
                                mask = [];
                                clr = getfieldifexists(roi,'color');
                                opacity = getfieldifexists(roi,'opacity');
                                thickness = getfieldifexists(roi,'thickness');
                                showarea = getfieldifexists(roi,'showarea');
                                
                            otherwise
                                error('Unrecognized file type: %s', lower(ext(2:end)));
                        end
                    else
                        mask = [];
                    end
                    
                case 4 %query user to select ROI data from workspace
                    mask = importdlg();
            end
            
            % Update mask (if loaded)
            if ~isempty(mask)
                [m,n,~,~] = size(app.Backend.ImageSequence);
                isvalidtype = islogical(mask) && ismatrix(mask) && isequal(size(mask,1),m) && isequal(size(mask,2),n);
                if ~isvalidtype
                    errorstring = 'ROI mask must be a 2-D logical image of the same size as the input image. Please choose a valid mask.';
                    dlgname = 'Invalid ROI Mask';
                    errdlg = errordlg(errorstring,dlgname,'modal');
                    % We need the error dialog to be blocking, otherwise
                    % listenerROILoadButton() is invoked before the dialog finishes
                    % setting itself up and becomes modal.
                    uiwait(errdlg);
                    % Drawnow is necessary so that imgetfile dialog will
                    % enforce modality in next call to imgetfile that
                    % arises from recursion.
                    drawnow;
                    roiload(this,option,app);
                    return;
                else                        
                    this.Mask = mask;
                    app.state('roi loaded');
                end
            else
                app.state('idle');
            end
            this.status('');
            
            % Update settings (if loaded)
            if exist('clr','var') && ~isempty(clr)
                gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,clr));
                this.Color = clr;
            end
            if exist('opacity','var') && ~isempty(opacity)
                this.OpacitySlider.Value = opacity*100;
            end
            if exist('thickness','var') && ~isempty(thickness)
                this.ThicknessSlider.Value = thickness;
            end
            if exist('showarea','var') && ~isempty(showarea)
                if showarea
                    this.ShowAreaButton.Selected = true;
                else
                    this.ShowPerimeterButton.Selected = true;
                end
            end
        end
        function roisave(this,option,app)
            % Save ROI data.
            app.state('saving roi data to file');
            
            cwd = pwd; %get current working directory
            
            % Change to directory where data is stored. If the user did not
            % specify DataPath or if the value of DataPath is invalid for 
            % the current machine, then look in the default directory for 
            % NEURO demos.
            if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                cd(this.DataPath);
            else
                cd(fullfile(beadtracking.path,'resources','demos'));
            end
            
            switch option
                case 1
%                     mask = this.Mask;
%                     clr = this.Color;
%                     opacity = this.Opacity/100;
%                     thickness = this.Thickness;
%                     showarea = this.ShowAreaButton.Selected;
%                     uisave({'mask','clr','opacity','thickness','showarea'});
                    
                    roi = struct(...
                        'mask',this.Mask,...
                        'color',this.Color,...
                        'opacity',this.Opacity/100,...
                        'thickness',this.Thickness,...
                        'showarea',this.ShowAreaButton.Selected);
                    
                    [filename,pathname] = uiputfile(...
                        {'*.mat','MAT-Files'; '*.*','All Files'},...
                        'Save ROI to File (Mask and Settings)');
                    if exist(fullfile(pathname,filename),'file')
                        save(fullfile(pathname,filename),'roi','-append');
                    else
                        save(fullfile(pathname,filename),'roi');
                    end
                    
                case 2
                    mask = this.Mask;
                    uisave({'mask'});
                    
                case 3
%                     clr = this.Color;
%                     opacity = this.Opacity/100;
%                     thickness = this.Thickness;
%                     showarea = this.ShowAreaButton.Selected;
%                     uisave({'clr','opacity','thickness','showarea'});
                    
                    roi = struct(...
                        'color',this.Color,...
                        'opacity',this.Opacity/100,...
                        'thickness',this.Thickness,...
                        'showarea',this.ShowAreaButton.Selected);
                    
                    [filename,pathname] = uiputfile(...
                        {'*.mat','MAT-Files'; '*.*','All Files'},...
                        'Save ROI to File (Mask and Settings)');
                    if exist(fullfile(pathname,filename),'file')
                        save(fullfile(pathname,filename),'roi','-append');
                    else
                        save(fullfile(pathname,filename),'roi');
                    end
                    
                case 4
                    
                otherwise
                    cd(cwd); %go back to 'current working directory'
                    error('Unrecognized value for WHICHVARS: %s',option);
            end
            
            cd(cwd); %go back to 'current working directory'
            app.state('idle');
            
        end
        function deleteDrawTools(this)
            % Delete existing imrect/impoly/imfreehand tools.
            if isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer)
                % Diasble ability to place new imrect objects
                disableInteractivePlacement(this.RectangleContainer);
                
                % Look for and delete current imrect objects
                rectangles = this.RectangleContainer.hROI;
                rectangles = rectangles(isvalid(rectangles));
                for ii=1:numel(rectangles)
                    delete(rectangles(ii));
                end
                
                % Delete imrect container
                delete(this.RectangleContainer);
            end
            
            if isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer)
                % Diasble ability to place new impoly objects
                disableInteractivePlacement(this.PolygonContainer);
                
                % Look for and delete current impoly objects
                polygons = this.PolygonContainer.hROI;
                polygons = polygons(isvalid(polygons));
                for ii=1:numel(polygons)
                    delete(polygons(ii));
                end
                
                % Delete impoly container
                delete(this.PolygonContainer);
            end
            
            if isa(this.FreehandContainer,'gui.ImfreehandModeContainer') && isvalid(this.FreehandContainer)
                % Diasble ability to place new imfreehand objects
                disableInteractivePlacement(this.FreehandContainer);
                
                % Look for and delete current imfreehand objects
                freehands = this.FreehandContainer.hROI;
                freehands = freehands(isvalid(freehands));
                for ii=1:numel(freehands)
                    delete(freehands(ii));
                end
                
                % Delete imfreehand container
                delete(this.FreehandContainer);
            end
        end
        function status(this,str)
            % Update StatusBarText in parent app.
            iptui.internal.utilities.setStatusBarText(this.Tab.Parent.Name,str);
        end
    end
    
    methods (Access=private) %layout methods
        function layoutFileSection(this)
            % Make widgets
            makeLoadButton(this);
            makeSaveButton(this);
            makeResetButton(this);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,2dlu,f:p,2dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(this.SplitButton(1),'xy(1,1)');
            panel.add(this.SplitButton(2),'xy(3,1)');
            panel.add(this.Button(1),'xy(5,1)');
            
            % Add panel to section
            this.Section(1).add(panel);
        end
        function layoutSettingsSection(this)
            % Make widgets
            makeColorLabel(this);
            makeColorButton(this);
            makeOpacityLabel(this);
            makeOpacitySlider(this);
            makeThicknessLabel(this);
            makeThicknessSlider(this);
            makeShowPerimeterButton(this);
            makeShowAreaButton(this);
            
            % Create subpanel to hold foreground color and opacity controls.
            subpanel = toolpack.component.TSPanel('3dlu,r:p,40dlu,f:p,f:p','3dlu,f:p,f:p,f:p,3dlu');
            subpanel.add(this.Label(1),'xy(2,2)');
            subpanel.add(this.Button(2),'xy(3,2,''l,c'')');
            subpanel.add(this.Label(2),'xy(2,3)');
            subpanel.add(this.Slider(1),'xywh(3,3,2,1)');
            subpanel.add(this.Label(3),'xy(2,4)');
            subpanel.add(this.Slider(2),'xywh(3,4,2,1)');
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p,1dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel,'xy(1,1)');
            panel.add(this.ToggleButton(1),'xy(3,1)');
            panel.add(this.ToggleButton(2),'xy(5,1)');
            
            % Add panel to section
            this.Section(2).add(panel);
        end
        function layoutDrawSection(this)
            % Make widgets
            makeDrawRectangleButton(this);
            makeDrawPolygonButton(this);
            makeDrawFreehandButton(this);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.Button(3),'xy(1,1)');
            panel.add(this.Button(4),'xy(1,2)');
            panel.add(this.Button(5),'xy(1,3)');
            
            % Add panel to section
            this.Section(3).add(panel);
        end
        function layoutResponseSection(this)
            % Make widgets
            makeOkButton(this);
            makeCancelButton(this);
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p','f:p:g'); %(columns,rows)
            panel.add(this.Button(6),'xy(1,1)');
            panel.add(this.Button(7),'xy(2,1)');
            
            % Add panel to section
            this.Section(4).add(panel);
        end
    end
    
    methods (Access=private) %make methods
        function makeLoadButton(this)
            str = 'Load';
            icon = gui.Icon.IMPORT_24;
            button = toolpack.component.TSSplitButton(str,icon);
            button.Name = 'Load';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'Load ROI mask from workspace or file');
            items(1) = struct(...
                'Title','Load ROI From File',...
                'Description','',...
                'Icon',gui.Icon.IMPORT_16,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title','Load ROI From File (Mask Only)',...
                'Description','',...
                'Icon',gui.Icon.IMPORT_16,...
                'Help',[],...
                'Header',false);
            items(3) = struct(...
                'Title','Load ROI From File (Settings Only)',...
                'Description','',...
                'Icon',gui.Icon.IMPORT_16,...
                'Help',[],...
                'Header',false);
            items(4) = struct(...
                'Title','Load ROI From Workspace (Mask Only)',...
                'Description','',...
                'Icon',gui.Icon.IMPORT_16,...
                'Help',[],...
                'Header',false);
            style = 'icon_text';
            button.Popup = toolpack.component.TSDropDownPopup(items,style);
            add(this,'SplitButton',button);
        end
        function makeSaveButton(this)
            str = 'Save';
            icon = gui.Icon.SAVE_24;
            button = toolpack.component.TSSplitButton(str,icon);
            button.Name = 'Save';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'Save region-of-interest settings');
            items(1) = struct(...
                'Title','Save ROI',...
                'Description','',...
                'Icon',gui.Icon.SAVE_16,...
                'Help',[],...
                'Header',false);
            items(2) = struct(...
                'Title','Save ROI (Mask Only)',...
                'Description','',...
                'Icon',gui.Icon.SAVE_16,...
                'Help',[],...
                'Header',false);
            items(3) = struct(...
                'Title','Save ROI (Settings Only)',...
                'Description','',...
                'Icon',gui.Icon.SAVE_16,...
                'Help',[],...
                'Header',false);
            items(4) = struct(...
                'Title','Save ROI (Mask as Image)',...
                'Description','',...
                'Icon',gui.Icon.SAVE_16,...
                'Help',[],...
                'Header',false);
            style = 'icon_text';
            button.Popup = toolpack.component.TSDropDownPopup(items,style);
            add(this,'SplitButton',button);
        end
        function makeResetButton(this)
            str = 'Reset';
            icon = gui.Icon.UNDO_24;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'Reset';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'Revert to default region-of-interest');
            add(this,'Button',button);
        end
        function makeColorLabel(this)
            label = toolpack.component.TSLabel('Color');
            label.Name = 'Color';
            add(this,'Label',label);
        end
        function makeColorButton(this)
            % Create button to set object color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            button = toolpack.component.TSButton();
            button.Name = 'Color';
            gui.setTSButtonIconFromImage(button,makeicon(16,16,this.DefaultColor));
            setToolTipText(button.Peer,'Change region-of-interest color');
            add(this,'Button',button);
        end
        function makeOpacityLabel(this)
            label = toolpack.component.TSLabel('Opacity');
            label.Name = 'Opacity';
            add(this,'Label',label);
        end
        function makeOpacitySlider(this)
            slider = toolpack.component.TSSlider(0,100,this.DefaultOpacity);
            slider.Name = 'Opacity';
            slider.MinorTickSpacing = 0.1;
            setToolTipText(slider.Peer,'Adjust region-of-interest opacity');
            add(this,'Slider',slider);
        end
        function makeThicknessLabel(this)
            label = toolpack.component.TSLabel('Thickness');
            label.Name = 'Thickness';
            add(this,'Label',label);
        end
        function makeThicknessSlider(this)
            slider = toolpack.component.TSSlider(0,10,this.DefaultThickness);
            slider.Name = 'Thickness';
            slider.MinorTickSpacing = 1;
            setToolTipText(slider.Peer,'Adjust region-of-interest boundary thickness');
            add(this,'Slider',slider);
        end
        function makeShowPerimeterButton(this)
            str = sprintf('Show\nPerim');
            icon = gui.Icon.SHOWPERIMETER_24;
            button = toolpack.component.TSToggleButton(str,icon,true);
            button.Name = 'ShowPerimeter';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'View ROI perimeter');
            add(this,'ToggleButton',button);
        end
        function makeShowAreaButton(this)
            str = sprintf('Show\nArea');
            icon = gui.Icon.SHOWAREA_24;
            button = toolpack.component.TSToggleButton(str,icon);
            button.Name = 'ShowArea';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'View ROI area');
            add(this,'ToggleButton',button);
        end
        function makeDrawRectangleButton(this)
            str = 'Draw Rectangle';
            icon = gui.Icon.RECTANGLE_16;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'DrawRectangle';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            setToolTipText(button.Peer,'Initialize region of interest by drawing a rectangle');
            add(this,'Button',button);
        end
        function makeDrawPolygonButton(this)
            str = 'Draw Polygon';
            icon = gui.Icon.POLYGON_16;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'DrawPolygon';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            setToolTipText(button.Peer,'Initialize region of interest by drawing a polygon');
            add(this,'Button',button);
        end
        function makeDrawFreehandButton(this)
            str = 'Draw Freehand';
            icon = gui.Icon.FREEHAND_16;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'DrawFreehand';
            button.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            setToolTipText(button.Peer,'Initialize region of interest by drawing a freehand contour');
            add(this,'Button',button);
        end
        function makeOkButton(this)
            str = 'OK';
            icon = gui.Icon.CONFIRM_24;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'OK';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'');
            add(this,'Button',button);
        end
        function makeCancelButton(this)
            str = 'Cancel';
            icon = gui.Icon.CLOSE_24;
            button = toolpack.component.TSButton(str,icon);
            button.Name = 'Cancel';
            button.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            setToolTipText(button.Peer,'');
            add(this,'Button',button);
        end
    end
    methods (Access=private) %listener methods
        %******************************************************************
        % File
        %******************************************************************
        function listenerLoadButton(this,~,~,app)
            % Load ROI from file.
            roiload(this,1,app);
        end
        function listenerLoadButtonPopup(this,obj,~,app)
            % Load ROI based on popup menu selection.
            roiload(this,obj.SelectedIndex,app);
        end
        function listenerSaveButton(this,~,~,app)
            % Save ROI mask and settings.
            roisave(this,1,app);
        end
        function listenerSaveButtonPopup(this,obj,~,app)
            % Save ROI based on popup menu selection.
            roisave(this,obj.SelectedIndex,app);
        end
        function listenerResetButton(this,~,~,app)
            % Revert to default mask.
            this.status('Restoring default region-of-interest settings...');
            this.Mask = true(app.Backend.ImageSize);
            this.reset();
            this.status('');
        end
        
        %******************************************************************
        % Settings
        %******************************************************************
        function flagApp(this,~,~)
            % Notify app that ROI properties have been modified.
            this.Flag = ~this.Flag;
        end
        function listenerColorButton(this,obj,~)
            % Change ROI color by changing axes color.
            % ----------------------------------------
            % Retrieve current (or default) color
            if isempty(this.Color)
                clr = str2rgb(this.DefaultColor);
            else
                clr = this.Color;
            end

            % Query user to select new color
            newclr = uisetcolor(clr,'Select ROI Color');
            
            % Update icon (unless user canceled color dialog box)
            if ~isequal(newclr,0) && ~isequal(newclr,clr)
                gui.setTSButtonIconFromImage(obj,makeicon(16,16,newclr));
                this.Color = newclr;
                this.Flag = ~this.Flag;
            end
        end
        function showperim(this,obj,~)
            % Callback for ShowPerimeterButton.
            if obj.Selected
                this.ShowAreaButton.Selected = false;
                this.Flag = ~this.Flag;
            else
                if ~this.ShowAreaButton.Selected
                    obj.Selected = true;
                end
            end
        end
        function showarea(this,obj,~)
            % Callback for ShowAreaButton.
            if obj.Selected
                this.ShowPerimeterButton.Selected = false;
                this.Flag = ~this.Flag;
            else
                if ~this.ShowPerimeterButton.Selected
                    obj.Selected = true;
                end
            end
        end
        
        %******************************************************************
        % Draw
        %******************************************************************
        function listenerDrawRectangleButton(this,~,~,app)
        %listenerDrawRectangleButton Draw one or more rectangles on the image.
            % Reset drawing tools
            deleteDrawTools(this);
            
            % Instantiate the impoly container
            if ~(isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer))
                this.RectangleContainer = gui.ImrectModeContainer(app.AxesHandle);
                addlistener(this.RectangleContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end
            
            % Update toolstrip controls
            app.state('wait for response');
            
            % Start letting user draw freehand contours
            enableInteractivePlacement(this.RectangleContainer);
            
            % Update status bar text
            this.status('Draw one or more rectangles on the image. Click OK or Cancel when finished.');
        end
        function listenerDrawPolygonButton(this,~,~,app)
        %listenerDrawPolygonButton Draw one or more polygons on the image.
            % Reset ROI and drawing tools
            deleteDrawTools(this);
            
            % Instantiate the impoly container
            if ~(isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer))
                this.PolygonContainer = gui.ImpolyModeContainer(app.AxesHandle);
                addlistener(this.PolygonContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end
            
            % Update toolstrip controls
            app.state('wait for response');
            
            % Start letting user draw freehand contours
            enableInteractivePlacement(this.PolygonContainer);
            
            % Update status bar text
            this.status('Draw one or more polygons on the image. Click OK or Cancel when finished.');
        end
        function listenerDrawFreehandButton(this,~,~,app)
        %listenerDrawFreehandButton Draw one or more freehand contours on the image.
            % Reset ROI and drawing tools
            deleteDrawTools(this);
            
            % Instantiate the imfreehand container
            if ~(isa(this.FreehandContainer,'gui.ImfreehandModeContainer') && isvalid(this.FreehandContainer))
                this.FreehandContainer = gui.ImfreehandModeContainer(app.AxesHandle);
                addlistener(this.FreehandContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end
            
            % Update toolstrip controls
            app.state('wait for response');
            
            % Start letting user draw freehand contours
            enableInteractivePlacement(this.FreehandContainer);
            
            % Update status bar text
            this.status('Draw one or more freehand contours on the image. Click OK or Cancel when finished.');
        end
        function listenerDrawObjectContainer(this,~,evt)
        %listenerDrawObjectContainer Set color and opacity of ROI when an impoly object is added.
            src = evt.AffectedObject;
            if ~isempty(src.hROI) && isvalid(src.hROI(end))
                roi = src.hROI(end);
                hpatch = findobj(roi,'type','patch');
                if ~isempty(hpatch)
                    hpatch.FaceColor = this.Color;
                    hpatch.FaceAlpha = this.Opacity;
                end
            end
        end
        
        %******************************************************************
        % Response
        %******************************************************************
        function listenerOKButton(this,~,~,app)
            % Accept the current ROI.
            mask = false(size(this.Mask));
            
            % Check if rectangles were used
            if isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer)
                rectangles = this.RectangleContainer.hROI;
                rectangles = rectangles(isvalid(rectangles));
                for ii=1:numel(rectangles)
                    mask = mask|createMask(rectangles(ii));
                end
            end
            
            % Check if polygons were used
            if isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer)
                polygons = this.PolygonContainer.hROI;
                polygons = polygons(isvalid(polygons));
                for ii=1:numel(polygons)
                    mask = mask|createMask(polygons(ii));
                end
            end
            
            % Check if freehand contours were used
            if isa(this.FreehandContainer,'gui.ImfreehandModeContainer') && isvalid(this.FreehandContainer)
                freehands = this.FreehandContainer.hROI;
                freehands = freehands(isvalid(freehands));
                for ii=1:numel(freehands)
                    mask = mask|createMask(freehands(ii));
                end
            end
            
            % Delete existing drawing tools
            deleteDrawTools(this);
            
            this.Mask = mask;
            this.Flag = ~this.Flag;
            this.status('');
            app.state('idle');
        end
        function listenerCancelButton(this,~,~,app)
            % Reject the current ROI.
            this.status('');
            this.deleteDrawTools();
            app.state('idle');
        end
    end
    
    methods %set/get dependent property methods
        function set.Mask(this,mask)
            validateattributes(mask,{'logical'},{'2d'});
            this.Mask = mask;
        end
        function A = get.AlphaData(this)
            se = strel('disk',this.Thickness,8);
            
            ShowPerimeterButton = get(this,'ToggleButton','ShowPerimeter');
            ShowAreaButton = get(this,'ToggleButton','ShowArea');
            if ShowPerimeterButton.Selected
                mask = bwperim(imdilate(this.Mask,se));
            elseif ShowAreaButton.Selected
                mask = this.Mask;
            else
                error('Either ShowPerimeterButton or ShowAreaButton should be selected. What happened?');
            end
            mask = imdilate(mask,se);
            
            A = ones(size(mask));
            A(mask) = 1-this.Opacity;
        end
        function opacity = get.Opacity(this)
            slider = get(this,'Slider','Opacity');
            opacity = slider.Value/slider.Maximum;
        end
        function thickness = get.Thickness(this)
            slider = get(this,'Slider','Thickness');
            thickness = slider.Value;
        end
    end
end

