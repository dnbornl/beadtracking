classdef RoiManager < handle
%GUI.ROIMANAGER Add region-of-interest tools to a GUI.
%   GUI.ROIMANAGER(APP) manages region-of-interest controls in a specified
%   APP.
%
%   THIS = GUI.ROIMANAGER(APP) returns the object itself, which can be
%   stored, for example, as a property of the APP.
%
%   Requirements:
%   1) The input APP must have a dependent property called AxesHandle that
%   returns an axes handle on which to apply draw regions of interest.

% Copyright 2016-2019 Matthew R. Eicholtz

    properties
        DataPath
        
        Tab
        FileSection
        SettingsSection
        DrawSection
        ResponseSection
        
        % File
        LoadButton
        SaveButton
        ResetButton

        % Settings
        ColorLabel
        ColorButton
        OpacityLabel
        OpacitySlider
        ThicknessLabel
        ThicknessSlider
        ShowPerimeterButton
        ShowAreaButton

        % Draw
        DrawRectangleButton
        DrawPolygonButton
        DrawFreehandButton

        % Response
        OKButton
        CancelButton
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
        Handles
    end
    properties (Access=private,Constant)
        % File
        LoadIcon            = gui.Icon.IMPORT_24;
        LoadPopupIcon       = gui.Icon.IMPORT_16;
        SaveIcon            = gui.Icon.SAVE_24;
        SavePopupIcon       = gui.Icon.SAVE_16;
        ResetIcon           = gui.Icon.UNDO_24;
        
        % Settings
        ShowPerimeterIcon 	= gui.Icon.SHOWPERIMETER_24;
        ShowAreaIcon        = gui.Icon.SHOWAREA_24;
        
        % Draw
        DrawRectangleIcon   = gui.Icon.RECTANGLE_16;
        DrawPolygonIcon     = gui.Icon.POLYGON_16;
        DrawFreehandIcon    = gui.Icon.FREEHAND_16;
        
        % Response
        OKIcon              = gui.Icon.CONFIRM_24;
        CancelIcon          = gui.Icon.CLOSE_24;
    end %icons
    properties (Access=private,Constant)
        % File
        LoadStr               	= 'Load';
        LoadTooltip             = 'Load ROI mask from workspace or file';
        NumLoadOptions          = 4;
        LoadPopupOption1      	= 'Load ROI From File';
        LoadPopupOption2      	= 'Load ROI From File (Mask Only)';
        LoadPopupOption3      	= 'Load ROI From File (Settings Only)';
        LoadPopupOption4      	= 'Load ROI From Workspace (Mask Only)';
        InvalidMaskDlgMessage  	= 'ROI mask must be a 2-D logical image of the same size as the input image. Please choose a valid mask.';
        InvalidMaskDlgTitle   	= 'Invalid ROI Mask';
        SaveStr               	= 'Save';
        SaveTooltip             = 'Save region-of-interest settings';
        NumSaveOptions          = 4;
        SavePopupOption1      	= 'Save ROI';
        SavePopupOption2      	= 'Save ROI (Mask Only)';
        SavePopupOption3      	= 'Save ROI (Settings Only)';
        SavePopupOption4      	= 'Save ROI (Mask as Image)';
        ResetStr              	= 'Reset';
        ResetTooltip            = 'Revert to default region-of-interest';
        
        % Settings
        ColorLabelStr          	= 'Color';
        ColorTooltip         	= 'Change region-of-interest color';
        OpacityLabelStr         = 'Opacity';
        OpacityTooltip          = 'Adjust region-of-interest opacity';
        ThicknessLabelStr   	= 'Thickness';
        ThicknessTooltip        = 'Adjust region-of-interest boundary thickness';
        ShowPerimeterStr       	= sprintf('Show\nPerim');
        ShowPerimeterTooltip   	= 'View ROI perimeter';
        ShowAreaStr             = sprintf('Show\nArea');
        ShowAreaTooltip         = 'View ROI area';
    
        % Draw
        DrawRectangleStr        	= 'Draw Rectangle';
        DrawRectangleTooltip        = 'Initialize region of interest by drawing a rectangle';
        DrawRectangleStatus         = 'Draw one or more rectangles on the image. Click OK or Cancel when finished.';
        DrawPolygonStr          	= 'Draw Polygon';
        DrawPolygonTooltip          = 'Initialize region of interest by drawing a polygon';
        DrawPolygonStatus           = 'Draw one or more polygons on the image. Click OK or Cancel when finished.';
        DrawFreehandStr         	= 'Draw Freehand';
        DrawFreehandTooltip         = 'Initialize region of interest by drawing a freehand contour';
        DrawFreehandStatus      	= 'Draw one or more freehand contours on the image. Click OK or Cancel when finished.';
        
        % Response
        OKStr           = 'OK';
        OKTooltip       = '';
        CancelStr     	= 'Cancel';
        CancelTooltip  	= '';
    end %strings
    properties (Constant)
        DefaultColor        = [0 0.45 0.74];
        DefaultOpacity      = 70;
        DefaultThickness	= 2;
    end %defaults
    
    methods
        function this = RoiManager(app,toolgroup)
            % Set properties
            this.DataPath = app.DataPath;
            this.Color = this.DefaultColor;
            
            % Add tab to toolgroup
            this.Tab = toolgroup.addTab('RoiTab','ROI');
            
            % Add sections to tab
            this.FileSection        = this.Tab.addSection('FileSection','File');
            this.SettingsSection   	= this.Tab.addSection('SettingsSection','Settings');
            this.DrawSection        = this.Tab.addSection('DrawSection','Draw');
            this.ResponseSection   	= this.Tab.addSection('ResponseSection','Response');
            
            % Create widgets for each section
            this.layoutFileSection();
            this.layoutSettingsSection();
            this.layoutDrawSection();
            this.layoutResponseSection();
            
            % Add tooltip and listeners
            this.addtooltip();
            this.addlisteners(app);
        end
        function reset(this)
            % Restore default settings
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            this.Color = this.DefaultColor;
            this.OpacitySlider.Value = this.DefaultOpacity;
            this.ThicknessSlider.Value = this.DefaultThickness;
            
            this.ShowPerimeterButton.Selected = true;
%             this.ShowAreaButton.Selected = false; %the ShowPerimeterButton callback will take care of this automatically
        end
    end
    
    methods (Access=private)
        function addtooltip(this)
            setToolTipText(this.LoadButton.Peer,            this.LoadTooltip);
            setToolTipText(this.SaveButton.Peer,            this.SaveTooltip);
            setToolTipText(this.ResetButton.Peer,           this.ResetTooltip);
            
            setToolTipText(this.ColorButton.Peer,           this.ColorTooltip);
            setToolTipText(this.OpacitySlider.Peer,         this.OpacityTooltip);
            setToolTipText(this.ThicknessSlider.Peer,       this.ThicknessTooltip);
            setToolTipText(this.ShowPerimeterButton.Peer,   this.ShowPerimeterTooltip);
            setToolTipText(this.ShowAreaButton.Peer,        this.ShowAreaTooltip);
            
            setToolTipText(this.DrawRectangleButton.Peer,   this.DrawRectangleTooltip);
            setToolTipText(this.DrawPolygonButton.Peer,     this.DrawPolygonTooltip);
            setToolTipText(this.DrawFreehandButton.Peer,    this.DrawFreehandTooltip);
            
            setToolTipText(this.OKButton.Peer,              this.OKTooltip);
            setToolTipText(this.CancelButton.Peer,          this.CancelTooltip);
        end
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
                    % look in the default directory for demos.
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
                    errdlg = errordlg(this.InvalidMaskDlgMessage,this.InvalidMaskDlgTitle,'modal');
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
            % demos.
            if ~isempty(this.DataPath) && exist(this.DataPath,'dir')
                cd(this.DataPath);
            else
                cd(fullfile(beadtracking.path,'resources','demos'));
            end
            
            switch option
                case 1 % save ROI (mask + settings) to user-specified file
                    roi = struct(...
                        'mask',this.Mask,...
                        'color',this.Color,...
                        'opacity',this.Opacity,...
                        'thickness',this.Thickness,...
                        'showarea',this.ShowAreaButton.Selected);
                    
                    [filename,pathname] = uiputfile(...
                        {'*.mat','MAT-Files'; '*.*','All Files'},...
                        'Save ROI to File (Mask and Settings)');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    if ~isempty(filename) && ~isequal(filename,0)
                        if exist(fullfile(pathname,filename),'file')
                            save(fullfile(pathname,filename),'roi','-append');
                        else
                            save(fullfile(pathname,filename),'roi');
                        end
                    end
                    
                case 2 % save ROI (mask only) to user-specified file
                    roi = struct(...
                        'mask',this.Mask);
                    
                    [filename,pathname] = uiputfile(...
                        {'*.mat','MAT-Files'; '*.*','All Files'},...
                        'Save ROI to File (Mask Only)');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    if ~isempty(filename) && ~isequal(filename,0)
                        if exist(fullfile(pathname,filename),'file')
                            save(fullfile(pathname,filename),'roi','-append');
                        else
                            save(fullfile(pathname,filename),'roi');
                        end
                    end
                    
                case 3 % save ROI (settings only) to user-specified file
                    roi = struct(...
                        'color',this.Color,...
                        'opacity',this.Opacity,...
                        'thickness',this.Thickness,...
                        'showarea',this.ShowAreaButton.Selected);
                    
                    [filename,pathname] = uiputfile(...
                        {'*.mat','MAT-Files'; '*.*','All Files'},...
                        'Save ROI to File (Settings Only)');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    if ~isempty(filename) && ~isequal(filename,0)
                        if exist(fullfile(pathname,filename),'file')
                            save(fullfile(pathname,filename),'roi','-append');
                        else
                            save(fullfile(pathname,filename),'roi');
                        end
                    end
                    
                case 4 % save ROI mask as an image at the user-specified location 
                    [filename,pathname] = uiputfile(...
                        {'*.png','Portable Network Graphics file'; '*.*','All Files'},...
                        'Save ROI to File (Image)');
                    
                    cd(cwd); %go back to 'current working directory'
                    
                    if ~isempty(filename) && ~isequal(filename,0)
                        imwrite(this.Mask,fullfile(pathname,filename),'png');
                    end
                    
                otherwise
                    cd(cwd); %go back to 'current working directory'
                    error('Unrecognized value for WHICHVARS: %s',option);
            end
            app.state('idle');
        end
        function deleteDrawTools(this)
            % Delete existing imrect/impoly/imfreehand tools.
            if isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer);
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
            
            if isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer);
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
        %******************************************************************
        % These functions generate the toolstrip layout design, which 
        % includes creating widgets (panels, buttons, sliders,...), 
        % defining their properties (position, icon,...), and adding 
        % listeners for events. Each section in a toolstrip tab should have
        % its own layout method.
        %******************************************************************
        function layoutFileSection(this)
            % LoadButton
            this.LoadButton = toolpack.component.TSSplitButton(this.LoadStr,this.LoadIcon);
            this.LoadButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            for ii=1:this.NumLoadOptions
                loadoptions(ii) = struct(...
                    'Title',this.(sprintf('LoadPopupOption%d',ii)),...
                    'Description','',...
                    'Icon',this.LoadPopupIcon,...
                    'Help',[],...
                    'Header',false); %#ok<AGROW>
            end
            this.LoadButton.Popup = toolpack.component.TSDropDownPopup(loadoptions,'icon_text');
            
            % SaveButton
            this.SaveButton = toolpack.component.TSSplitButton(this.SaveStr,this.SaveIcon);
            this.SaveButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            for ii=1:this.NumSaveOptions
                saveoptions(ii) = struct(...
                    'Title',this.(sprintf('SavePopupOption%d',ii)),...
                    'Description','',...
                    'Icon',this.SavePopupIcon,...
                    'Help',[],...
                    'Header',false); %#ok<AGROW>
            end
            this.SaveButton.Popup = toolpack.component.TSDropDownPopup(saveoptions,'icon_text');
            
            % ResetButton
            this.ResetButton = toolpack.component.TSButton(this.ResetStr,this.ResetIcon);
            this.ResetButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,2dlu,f:p,2dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(this.LoadButton,'xy(1,1)');
            panel.add(this.SaveButton,'xy(3,1)');
            panel.add(this.ResetButton,'xy(5,1)');
            
            % Add panel to section
            this.FileSection.add(panel);
        end
        function layoutSettingsSection(this)
            % Create button to set object color
            % Note: there is no MCOS interface to set the icon of a TSButton directly from a uint8 buffer.
            this.ColorLabel = toolpack.component.TSLabel(this.ColorLabelStr);
            this.ColorButton = toolpack.component.TSButton();
            gui.setTSButtonIconFromImage(this.ColorButton,makeicon(16,16,this.DefaultColor));
            
            % Opacity slider
            this.OpacityLabel = toolpack.component.TSLabel(this.OpacityLabelStr);
            this.OpacitySlider = toolpack.component.TSSlider(0,100,this.DefaultOpacity);
            this.OpacitySlider.MinorTickSpacing = 0.1;

            % Thickness slider
            this.ThicknessLabel = toolpack.component.TSLabel(this.ThicknessLabelStr);
            this.ThicknessSlider = toolpack.component.TSSlider(0,10,this.DefaultThickness);
            this.ThicknessSlider.MinorTickSpacing = 1;
            
            % Show perimeter
            this.ShowPerimeterButton = toolpack.component.TSToggleButton(this.ShowPerimeterStr,this.ShowPerimeterIcon,true);
            this.ShowPerimeterButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Show area
            this.ShowAreaButton = toolpack.component.TSToggleButton(this.ShowAreaStr,this.ShowAreaIcon);
            this.ShowAreaButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Create subpanel to hold foreground color and opacity controls.
            subpanel = toolpack.component.TSPanel('3dlu,r:p,40dlu,f:p,f:p','3dlu,f:p,f:p,f:p,3dlu');
            subpanel.add(this.ColorLabel,'xy(2,2)');
            subpanel.add(this.ColorButton,'xy(3,2,''l,c'')');
            subpanel.add(this.OpacityLabel,'xy(2,3)');
            subpanel.add(this.OpacitySlider,'xywh(3,3,2,1)');
            subpanel.add(this.ThicknessLabel,'xy(2,4)');
            subpanel.add(this.ThicknessSlider,'xywh(3,4,2,1)');

            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,3dlu,f:p,1dlu,f:p','f:p:g'); %(columns,rows)
            panel.add(subpanel,'xy(1,1)');
            panel.add(this.ShowPerimeterButton,'xy(3,1)');
            panel.add(this.ShowAreaButton,'xy(5,1)');
            
            % Add panel to section
            this.SettingsSection.add(panel);
        end
        function layoutDrawSection(this)
            % Create buttons for drawing tools
            this.DrawRectangleButton = toolpack.component.TSButton(this.DrawRectangleStr,this.DrawRectangleIcon);
            this.DrawRectangleButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            this.DrawPolygonButton = toolpack.component.TSButton(this.DrawPolygonStr,this.DrawPolygonIcon);
            this.DrawPolygonButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            this.DrawFreehandButton = toolpack.component.TSButton(this.DrawFreehandStr,this.DrawFreehandIcon);
            this.DrawFreehandButton.Orientation = toolpack.component.ButtonOrientation.HORIZONTAL;
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p','f:p:g,f:p:g,f:p:g'); %(columns,rows)
            panel.add(this.DrawRectangleButton,	'xy(1,1)');
            panel.add(this.DrawPolygonButton,   'xy(1,2)');
            panel.add(this.DrawFreehandButton,	'xy(1,3)');
            
            % Add panel to section
            this.DrawSection.add(panel);
        end
        function layoutResponseSection(this)
            % Create OK and Cancel buttons
            this.OKButton = toolpack.component.TSButton(this.OKStr,this.OKIcon);
            this.OKButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            this.CancelButton = toolpack.component.TSButton(this.CancelStr,this.CancelIcon);
            this.CancelButton.Orientation = toolpack.component.ButtonOrientation.VERTICAL;
            
            % Setup toolstrip panel
            panel = toolpack.component.TSPanel('f:p,f:p','f:p:g'); %(columns,rows)
            panel.add(this.OKButton,	 'xy(1,1)');
            panel.add(this.CancelButton, 'xy(2,1)');
            
            % Add panel to section
            this.ResponseSection.add(panel);
        end
    end
    
    methods (Access=private) %listener methods
        %******************************************************************
        % These functions are called when specific actions are executed in 
        % the app, such as clicking a button or repositioning a slider.
        %******************************************************************
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
            % Draw one or more rectangles on the image.
            % -----------------------------------------
            % Reset drawing tools
            this.deleteDrawTools();
            
            % Instantiate the impoly container
            if ~(isa(this.RectangleContainer,'gui.ImrectModeContainer') && isvalid(this.RectangleContainer))
                this.RectangleContainer = gui.ImrectModeContainer(app.AxesHandle);
                addlistener(this.RectangleContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            app.state('wait for response');

            % Start letting user draw freehand contours
            this.RectangleContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawRectangleStatus);
        end
        function listenerDrawPolygonButton(this,~,~,app)
            % Draw one or more polygons on the image.
            % ---------------------------------------
            % Reset ROI and drawing tools
            this.deleteDrawTools();

            % Instantiate the impoly container
            if ~(isa(this.PolygonContainer,'gui.ImpolyModeContainer') && isvalid(this.PolygonContainer))
                this.PolygonContainer = gui.ImpolyModeContainer(app.AxesHandle);
                addlistener(this.PolygonContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            app.state('wait for response');

            % Start letting user draw freehand contours
            this.PolygonContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawPolygonStatus);
        end
        function listenerDrawFreehandButton(this,~,~,app)
            % Draw one or more contours on the image.
            % ---------------------------------------
            % Reset ROI and drawing tools
            this.deleteDrawTools();

            % Instantiate the imfreehand container
            if ~(isa(this.FreehandContainer,'gui.ImfreehandModeContainer') && isvalid(this.FreehandContainer))
                this.FreehandContainer = gui.ImfreehandModeContainer(app.AxesHandle);
                addlistener(this.FreehandContainer,'hROI','PostSet',@this.listenerDrawObjectContainer);
            end

            % Update toolstrip controls
            app.state('wait for response');

            % Start letting user draw freehand contours
            this.FreehandContainer.enableInteractivePlacement();

            % Update status bar text
            this.status(this.DrawFreehandStatus);
        end
        function listenerDrawObjectContainer(this,~,evt)
        % Set color and opacity of ROI when an impoly object is added.
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
            this.deleteDrawTools();
            
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
            
            if this.ShowPerimeterButton.Selected
                mask = bwperim(imdilate(this.Mask,se));
            elseif this.ShowAreaButton.Selected
                mask = this.Mask;
            else
                error('Either ShowPerimeterButton or ShowAreaButton should be selected. What happened?');
            end
            mask = imdilate(mask,se);
            
            A = ones(size(mask));
            A(mask) = 1-this.Opacity;
        end
        function h = get.Handles(this)
            h.File = {...
                this.LoadButton,...
                this.SaveButton,...
                this.ResetButton};
            h.Settings = {...
                this.ColorLabel,...
                this.ColorButton,...
                this.OpacityLabel,...
                this.OpacitySlider,...
                this.ThicknessLabel,...
                this.ThicknessSlider,...
                this.ShowPerimeterButton,...
                this.ShowAreaButton};
            h.Draw = {...
                this.DrawRectangleButton,...
                this.DrawPolygonButton,...
                this.DrawFreehandButton};
            h.Response = {...
                this.OKButton,...
                this.CancelButton};
            h.All = [...
                h.File,...
                h.Settings,...
                h.Draw,...
                h.Response];
        end
        function opacity = get.Opacity(this)
            opacity = this.OpacitySlider.Value/this.OpacitySlider.Maximum;
        end
        function thickness = get.Thickness(this)
            thickness = this.ThicknessSlider.Value;
        end
    end
    
end

