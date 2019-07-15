%RUNBLOBDETECTION Detect blobs in image sequence.
%   This script is a wrapper for IMBLOBS, which detects blobs in an image
%   using Laplacian of Gaussian filters. It is part of a series of scripts
%   used to track microbeads in microscopy images of mouse brain tissue.
%
%   Before running the script, the user should modify the parameters listed
%   at the top, including:
%
%       'pathname'      String indicating the directory in which the image
%                       sequence is stored.
%
%       'filenames'     Cell array of filenames to look at in the given
%                       directory. This approach is used so that you can
%                       quickly switch between files without having to
%                       retype the (sometimes complicated) strings.
%                       ***IMPORTANT: Do not include the file extension 
%                       (.tif is assumed)!***
%
%       'fileind'       Scalar or vector of indices indicating which files 
%                       to run in the current execution of the code.
%
%       'polarity'      String indicating what type of objects to detect.
%                       Must be either 'bright' or 'dark'. This is a
%                       parameter name-value pair for IMBLOBS.
%
%       'radii'         Vector of real-valued numbers indicating the radii
%                       of blobs to detect. This is a parameter name-value
%                       pair for IMBLOBS.
%
%       'sens'          Numeric scalar indicating detection sensitivity.
%                       Higher values results in more (potentially false)
%                       detections. This is a parameter name-value pair for
%                       IMBLOBS.
%
%       'showresults'   Logical scalar indicating whether to show the
%                       detected blobs for every frame as it is processed.
%
%       'saveresults'   Logical scalar indicating whether to save the
%                       results to file. If true, the output for each image
%                       sequence, including relevant parameters, will be
%                       saved to file (<files{ii}>.mat) in a structure
%                       called 'detection'. That file can then be loaded
%                       and processed in other scripts (e.g.
%                       RUNBLOBREFINEMENT, RUNKALMANTRACKING).
%
%   See also IMBLOBS, RUNBLOBREFINEMENT, RUNKALMANTRACKING,
%   SHOWTRACKINGRESULTS.

% Copyright 2016-2019 Matthew R. Eicholtz
clear; %clc; close all;

% ================== MODIFY THESE PARAMETERS AS NEEDED ====================
pathname = fullfile(beadtracking.path,'data');

filenames = {...
    '1784 cont';
    '1861 hemi-1';
    '1861 hemi-2';
    '1925 cont-4'};

fileind = 4;

polarity = 'bright';
radii = [3 4];
sens = 0.494;

showresults = false;
saveresults = true;
%==========================================================================

for ii=fileind
    % Setup progress bar
    h = waitbar(0,'1',...
        'Name',sprintf('%s: %s',mfilename,filenames{ii}),...
        'CreateCancelBtn','setappdata(gcbf,''stop'',1)');
    setappdata(h,'stop',0);
    
    % Extract relevant file information
    file = fullfile(pathname,[filenames{ii},'.tif']);
    info = imfinfo(file);
    N = length(info); %number of frames
    
    % Initialize output
    blobs = cell(N,1);
    scores = cell(N,1);
    
    % Detect blobs for each image in the sequence
    for jj=1:N
        % Stop the code if user clicks 'cancel' button
        if getappdata(h,'stop'); break; end
        
        % Update progress bar
        waitbar(jj/N,h,sprintf('%4d out of %d',jj,N));
        
        % Read current image
        I = imread(file,'Index',jj,'Info',info);
        
        % Detect blobs in current image
        [blobs{jj},scores{jj}] = imblobs(I,...
            'Polarity',polarity,...
            'Radii',radii,...
            'Sensitivity',sens,...
            'Verbose',true);
        
        % Show detected blobs, if requested
        if showresults
            figure(sum(mfilename+0));
            imshow(I,[]);
            circles(blobs{jj}(:,1),blobs{jj}(:,2),blobs{jj}(:,3),'EdgeColor','green');
            pause(0.05);
        end
    end
    
    % Save results to file, if requested
    if ~getappdata(h,'stop') && saveresults
        detection = struct('blobs',{blobs},'scores',{scores},...
            'polarity',polarity,'radii',radii,'sensitivity',sens);
        savefile = fullfile(pathname,[filenames{ii},'.mat']);
        if exist(savefile,'file')
            save(savefile,'detection','-append');
        else
            save(savefile,'detection');
        end
    end
    
    % Delete the progress bar
    delete(h);
end

