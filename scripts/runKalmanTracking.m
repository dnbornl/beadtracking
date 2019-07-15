%RUNKALMANTRACKING Track multiple objects in image sequence.
%   This script is the third in a series of scripts used to track
%   microbeads in microscopy images of mouse brain tissue.
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
%       'frames'        Either a scalar, vector, or the string 'all'
%                       indicating which frames to include in the
%                       visualization(s).
%
%       'showresults'   Logical scalar indicating whether to show the
%                       tracked bead trajectories after processing.
%
%       'saveresults'   Logical scalar indicating whether to save the
%                       results to file. If true, the output for each image
%                       sequence, including relevant parameters, will be
%                       saved to file (<files{ii}>.mat) in a structure
%                       called 'tracking'. That file can then be loaded
%                       and processed in other scripts (e.g.
%                       SHOWTRACKINGRESULTS).
%
%       ... (some parameters are not listed here, but are described below)
%
%   See also BTUI.UTILS.TRACK, RUNBLOBDETECTION, RUNBLOBREFINEMENT, SHOWTRACKINGRESULTS.

% Copyright 2016-2019 Matthew R. Eicholtz
cleanup;

% ================== MODIFY THESE PARAMETERS AS NEEDED ====================
pathname = fullfile(beadtracking.path,'data');

filenames = {...
    '1784 cont';
    '1861 hemi-1';
    '1861 hemi-2';
    '1925 cont-4'};

fileind = 4;

frames = 'all';

params.costOfNonAssignment = 5;
params.MotionModel = 'ConstantVelocity'; %'ConstantVelocity' or 'ConstantAcceleration'
params.InitialEstimateError = [5,2]; %[LocationVariance, VelocityVariance, (AccelerationVariance)]
params.MotionNoise = [5,2]; %[LocationVariance, VelocityVariance, (AccelerationVariance)]
params.MeasurementNoise = 0.1;

params.invisibleForTooLong = 5;
params.ageThreshold = 6;
params.visiblePercentage = 0.5;
params.minVisibleCount = 0;

params.minDuration = 6; %for post-processing tracks
params.minDistanceRatio = 0.4; %for post-processing tracks

dt = 0.050; %sec
micrometerperpixel = 3.2088;

showresults = true;
saveresults = true;
%==========================================================================

for ii=fileind
    % Setup progress bar
    h = waitbar(0,'Processing',...
        'Name',sprintf('%s: %s',mfilename,filenames{ii}),...
        'CreateCancelBtn','setappdata(gcbf,''stop'',1)');
    setappdata(h,'stop',0);
    
    % Extract relevant file information
    imgfile = fullfile(pathname,[filenames{ii},'.tif']);
    datafile = fullfile(pathname,[filenames{ii},'.mat']);
    
    load(datafile,'roi','detection','refinement');
    
    info = imfinfo(imgfile);
    if strcmp(frames,'all')
        frames = 1:length(info);
    end
    I = imframe(imgfile,frames,'class','uint8');
%     I = permute(I,[1 2 4 3]);
    [m,n,p,q] = size(I);
    
    if ~exist('roi','var')
        roi.mask = true(m,n);
    end
    if exist('refinement','var') && ~isempty(refinement)
        beads = refinement.blobs(frames);
    elseif exist('detection','var') && ~isempty(detection)
        beads = detection.blobs(frames);
    else
        error('No blobs have been detection yet. Try runBlobDetection.');
    end
    
    % Compute centroids and bounding boxes for each bead in ROI
    centroids = cell(size(beads));
    bboxes = cell(size(beads));
    for jj=1:length(frames)
        xi = beads{jj}(:,1);
        yi = beads{jj}(:,2);
        ri = beads{jj}(:,3);
        
        ind = sub2ind(size(roi.mask),yi,xi);
        mask = roi.mask(ind);
        xi = xi(mask);
        yi = yi(mask);
        ri = ri(mask);

        centroids{jj} = [xi, yi];
        bboxes{jj} = [xi-ri, yi-ri, 2*ri, 2*ri];
    end
    
    % Track beads
    tracks = kalmantracking(I,centroids,bboxes,...
        'costOfNonAssignment',params.costOfNonAssignment,...
        'MotionModel',params.MotionModel,...
        'InitialEstimateError',params.InitialEstimateError,...
        'MotionNoise',params.MotionNoise,...
        'MeasurementNoise',params.MeasurementNoise,...
        'invisibleForTooLong',params.invisibleForTooLong,...
        'ageThreshold',params.ageThreshold,...
        'visiblePercentage',params.visiblePercentage,...
        'minVisibleCount',params.minVisibleCount,...
        'maxNumPoints',Inf);
    tracks = tracks(:);

    % Process tracks
    xy = cell(length(tracks),1);
    t = cell(length(tracks),1);
    for jj=1:length(tracks)
        [xi,yi] = getpoints(tracks(jj).animatedline);
        if isempty(xi)
            xi = 0;
            yi = 0;
        end
        xy{jj} = [xi(:),yi(:)];
        t{jj} = tracks(jj).animatedtime(:);
    end

    r = regionprops(roi.mask,'BoundingBox');
    d = hypot(r.BoundingBox(3),r.BoundingBox(4));

    check1 = cellfun('length',xy) > params.minDuration;
    check2 = cellfun(@(x) sqrt(sum((max(x)-min(x)).^2)),xy)/d > params.minDistanceRatio;  

    d = cellfun(@(x) diff(x,1,1),xy,'uni',0);
    v = cellfun(@(x) hypot(x(:,1),x(:,2))*(micrometerperpixel/dt),d,'uni',0);
    vmax = cellfun(@max,v,'uni',0);
    for jj=1:length(vmax)
        if isempty(vmax{jj})
            vmax{jj} = 0;
        end
    end
    v = cat(1,v{:});
    vmax = cat(1,vmax{:});
    check3 = vmax <= mean(v)+2*std(v);

    validtracks = check1 & check2;%& check3;
    
    xy = xy(validtracks);
    t = t(validtracks);
    
    % Remove excess recordings (when track is still active but not detected)
%     excess = params.invisibleForTooLong;
%     for jj=1:length(xy)
%         xy{jj} = xy{jj}(1:end-excess+1,:);
%         t{jj} = t{jj}(1:end-excess+1);
%     end
    
    % Save results to file, if requested
    if ~getappdata(h,'stop') && saveresults
        tracking = struct('position',{xy},'time',{t},'params',params);
        if exist(datafile,'file')
            save(datafile,'tracking','-append');
        else
            save(datafile,'tracking');
        end
    end
    
    % Show results, if requested
    if showresults
        figure(sum(mfilename+0));
        imshow(I(:,:,:,1),[]);
        hold on;
        for jj=1:length(xy)
            plot(xy{jj}(:,1),xy{jj}(:,2),'Color',ind2rgb(jj,lines(length(xy))),'LineWidth',2);
        end
        hold off;
    end
    
    % Compute average speed
    V = []; %average mean speed
    for jj=1:length(xy)
        dx = diff(xy{jj});
        v = hypot(dx(:,1),dx(:,2)) *(micrometerperpixel/dt);
        V = [V; mean(v)];
    end
    fprintf('Average mean speed = %0.3f\n',mean(V));
    
    % Delete the progress bar
    delete(h);
end

