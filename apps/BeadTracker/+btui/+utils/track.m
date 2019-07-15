function tracks = track(app,I,centroids,bboxes,varargin)
%TRACK Track detected objects across frames in an image sequence.

% Copyright 2016-2019 Matthew R. Eicholtz

%% Default parameter values
default = struct(...
    'costOfNonAssignment',10,...
    'MotionModel','ConstantVelocity',... %'ConstantVelocity' or 'ConstantAcceleration'
    'InitialEstimateError',[0.01,1],... %[LocationVariance, VelocityVariance, (AccelerationVariance)]
    'MotionNoise',[4,8],... %[LocationVariance, VelocityVariance, (AccelerationVariance)]
    'MeasurementNoise',0.01,...
    'invisibleForTooLong',4,...
    'ageThreshold',8,...
    'visiblePercentage',0.6,...
    'minVisibleCount',0,...
    'maxNumPoints',5);

%% Parse inputs
params = parseinputs(default,varargin{:});

%% Initialize tracks
% Create an array of tracks, where each track is a structure representing a
% moving object in the video. The purpose of the structure is to maintain 
% the state of a tracked object. The state consists of information used for
% detection to track assignment, track termination, and display. 
%
% The structure contains the following fields:
%
%       'id'                Unique integer identifier for the track
%
%       'bbox'              Current bounding box (for display)
%
%       'kalmanFilter'      Kalman filter object used for tracking
%
%       'age'               Scalar number of frames since the track was 
%                           first detected
%
%       'totalVisibleCount'	Total number of frames in which the track
%                           was detected (visible)
%
%       'consecutiveInvisibleCount' Number of consecutive frames for which
%                                   the track was not detected (invisible).
%
%       'active'            Logical scalar indicating whether the track is
%                           still active or not.
%
% Noisy detections tend to result in short-lived tracks. For this reason,
% the example only displays an object after it was tracked for some number
% of frames. This happens when |totalVisibleCount| exceeds a specified 
% threshold.
%
% When no detections are associated with a track for several consecutive
% frames, the example assumes that the object has left the field of view 
% and deletes the track. This happens when 'consecutiveInvisibleCount'
% exceeds a specified threshold. A track may also get deleted as noise if 
% it was tracked for a short time, and marked invisible for most of the of 
% the frames.
tracks = struct(...
    'id',{}, ...
    'bbox',{}, ...
    'kalmanFilter',{}, ...
    'age',{}, ...
    'totalVisibleCount',{}, ...
    'consecutiveInvisibleCount',{},...
    'active',{},...
    'animatedline',{},...
    'animatedtime',{});

%% Iterate over frames
next = 1; %ID of the next track
% video = VideoWriter('C:\Users\mve\Documents\data\beadtracking\4\1925 cont-1Substack (50-400) short tracks.mp4','MPEG-4');
% video.FrameRate = 15;
% open(video);
for ii=1:size(I,4)
    fprintf('Frame %d of %d\n',ii,size(I,4));
    frame = I(:,:,:,ii);
    centroid = int32(centroids{ii});
    bbox = int32(bboxes{ii});
    
    % Predict New Locations of Existing Tracks
    % ----------------------------------------
    % Use the Kalman filter to predict the centroid of each track in the
    % current frame, and update its bounding box accordingly.
    tracks = predictNewLocationsOfTracks(tracks);
    
    % Assign Detections to Tracks
    % ---------------------------
    % Use the known centroids of detected objects and the predicted
    % locations of each track to assign specific detections to specific
    % tracks. Requires a costOfNonAssignment parameter.
    inactive = find(~[tracks(:).active]);
    [assignments, unassignedTracks, unassignedDetections] = detectionToTrackAssignment(centroid,tracks,params);
    unassignedDetections = cat(1,unassignedDetections,assignments(ismember(assignments(:,1),inactive),2));
    assignments(ismember(assignments(:,1),inactive),:) = []; %remove inactive
    if ~isempty(unassignedTracks)
        unassignedTracks(ismember(unassignedTracks(:,1),inactive),:) = []; %remove inactive
    end
    
    % Update Assigned Tracks
    % ----------------------
    % Call the CORRECT method of VISION.KALMANFILTER to correct the 
    % location estimate. Next, store the new bounding box and increase the 
    % age of the track and the total visible count by 1. Finally, set the 
    % invisible count to 0.
    for jj=1:size(assignments,1)
        m = assignments(jj,1); %track index
        n = assignments(jj,2); %detection index

        % Correct the estimate of the object's location using the new detection.
        correct(tracks(m).kalmanFilter,centroid(n,:));

        % Replace predicted bounding box with detected bounding box.
        tracks(m).bbox = bbox(n,:);

        % Update age and visibility
        tracks(m).age = tracks(m).age + 1;
        tracks(m).totalVisibleCount = tracks(m).totalVisibleCount + 1;
        tracks(m).consecutiveInvisibleCount = 0;
    end
    
    % Update Unassigned Tracks
    % ------------------------
    % Mark each unassigned track as invisible, and increase its age by 1.
    for jj=1:length(unassignedTracks)
        ind = unassignedTracks(jj);
        tracks(ind).age = tracks(ind).age + 1;
        tracks(ind).consecutiveInvisibleCount = tracks(ind).consecutiveInvisibleCount + 1;
    end
    
    % Make Lost Tracks Inactive
    % -------------------------
    % If a track has been invisible for too long (either consecutively or
    % on average for recent tracks), then mark the track as inactive.

    % Compute the fraction of the track's age for which it was visible.
    ages = [tracks(:).age];
    totalVisibleCounts = [tracks(:).totalVisibleCount];
    visibility = totalVisibleCounts./ages;
    invisibility = [tracks(:).consecutiveInvisibleCount];
    
    % Find the indices of 'lost' tracks.
    lost = find((ages < params.ageThreshold & visibility < params.visiblePercentage) | ...
        invisibility >= params.invisibleForTooLong);

    % Make lost tracks inactive
    for jj=1:length(lost)
        tracks(lost(jj)).active = false;
    end
%     tracks = tracks(~lostInds);
    
    % Create New Tracks
    % -----------------
    % Create a new track for each unassigned detection. In practice, you 
    % can use other cues to eliminate noisy detections, such as size, 
    % location, or appearance.
    for jj=1:length(unassignedDetections)
        kalmanFilter = configureKalmanFilter(...
            params.MotionModel, centroid(unassignedDetections(jj),:), params.InitialEstimateError, ...
            params.MotionNoise, params.MeasurementNoise);
        
        tracks(end+1) = struct(...
            'id',next,...
            'bbox',bbox(unassignedDetections(jj),:),...
            'kalmanFilter',kalmanFilter,...
            'age',1,...
            'totalVisibleCount',1,...
            'consecutiveInvisibleCount',0,...
            'active',true,...
            'animatedline',animatedline(...
                'Color',ind2rgb(next,lines(1000)),...
                'LineWidth',2,...
                'Marker','none',...
                'MaximumNumPoints',params.maxNumPoints,...
                'Parent',app.AxesHandle),...
            'animatedtime',[]);
        
        next = next+1; %increment id
    end
    
    % Show the frame with current tracks overlayed
    % --------------------------------------------
    app.VideoControlsSection.CurrentFrame = ii; % update the frame in the app
    
%     i1 = max(1,length(tracks)-10);
%     i2 = min(i1+10,length(tracks));
    
    if ~isempty(tracks)
        % Only show active reliable tracks
        validtracks = find([tracks(:).active] & [tracks(:).totalVisibleCount] > params.minVisibleCount);
        
        if length(validtracks)>100
            warning('Too many beads! Tracking stops if the number of beads exceeds 100.');
            break
        end
        
        if ~isempty(validtracks)
            % Get bounding boxes
            bb = cat(1,tracks(:).bbox);
            x = double(bb(:,1)+bb(:,3)/2);
            y = double(bb(:,2)+bb(:,4)/2);
            
            % Draw the objects on the frame
            for jj=1:length(tracks)
                if ismember(jj,validtracks)
                    addpoints(tracks(jj).animatedline,x(jj),y(jj));
                    tracks(jj).animatedtime(end+1) = ii;
                else
                    clearpoints(tracks(jj).animatedline);
                end
            end
        end
    end
    
%     show(tracks(validtracks),params);
%     set(gcf,'Name',sprintf('frame %d',ii));
%     keyboard
    pause(0.05)
%     writeVideo(video,getframe);
end
% close(video);

for ii=1:length(tracks)
    clearpoints(tracks(ii).animatedline);
end

end

%% Helper functions
function varargout = parseinputs(default,varargin)
%PARSEINPUTS Custom input parsing function.
    p = inputParser;
    
    p.addParameter('costOfNonAssignment',default.costOfNonAssignment,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','nonempty','nonsparse'}));
    p.addParameter('MotionModel',default.MotionModel,...
        @(x) ismember(x,{'ConstantVelocity','ConstantAcceleration'}));
    p.addParameter('InitialEstimateError',default.InitialEstimateError,...
        @(x) validateattributes(x,{'numeric'},{'size',[1 2],'real','finite','>',0,'nonempty','nonsparse'}));
    p.addParameter('MotionNoise',default.MotionNoise,...
        @(x) validateattributes(x,{'numeric'},{'size',[1 2],'real','finite','>',0,'nonempty','nonsparse'}));
    p.addParameter('MeasurementNoise',default.MeasurementNoise,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>',0,'nonempty','nonsparse'}));
    p.addParameter('invisibleForTooLong',default.invisibleForTooLong,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>',0,'nonempty','nonsparse'}));
    p.addParameter('ageThreshold',default.ageThreshold,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>',0,'nonempty','nonsparse'}));
    p.addParameter('visiblePercentage',default.visiblePercentage,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>=',0,'<=',1,'nonempty','nonsparse'}));
    p.addParameter('minVisibleCount',default.minVisibleCount,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>=',0,'nonempty','nonsparse'}));
    p.addParameter('maxNumPoints',default.maxNumPoints,...
        @(x) validateattributes(x,{'numeric'},{'scalar','real','finite','>',0,'nonempty','nonsparse'}));
    
    p.parse(varargin{:});
    
    varargout = {p.Results};
end
function tracks = predictNewLocationsOfTracks(tracks)
    for ii=1:length(tracks)
        % Make sure the track is still active
%         if ~tracks(ii).active; continue; end
        
        % Get current bounding box
        bb = tracks(ii).bbox;

        % Predict the current location of the track.
        predictedCentroid = predict(tracks(ii).kalmanFilter);
        
        % Shift the bounding box so that its center is at the predicted location.
        predictedCentroid = int32(predictedCentroid)-bb(3:4)/2;
        tracks(ii).bbox = [predictedCentroid, bb(3:4)];
    end
end
function [assignments, unassignedTracks, unassignedDetections] = detectionToTrackAssignment(centroids,tracks,params)
% Assign Detections to Tracks
% Assigning object detections in the current frame to existing tracks is
% done by minimizing cost. The cost is defined as the negative
% log-likelihood of a detection corresponding to a track.
%
% The algorithm involves two steps: 
%
% Step 1: Compute the cost of assigning every detection to each track using
% the |distance| method of the |vision.KalmanFilter| System object(TM). The 
% cost takes into account the Euclidean distance between the predicted
% centroid of the track and the centroid of the detection. It also includes
% the confidence of the prediction, which is maintained by the Kalman
% filter. The results are stored in an MxN matrix, where M is the number of
% tracks, and N is the number of detections.   
%
% Step 2: Solve the assignment problem represented by the cost matrix using
% the |assignDetectionsToTracks| function. The function takes the cost 
% matrix and the cost of not assigning any detections to a track.  
%
% The value for the cost of not assigning a detection to a track depends on
% the range of values returned by the |distance| method of the 
% |vision.KalmanFilter|. This value must be tuned experimentally. Setting 
% it too low increases the likelihood of creating a new track, and may
% result in track fragmentation. Setting it too high may result in a single 
% track corresponding to a series of separate moving objects.   
%
% The |assignDetectionsToTracks| function uses the Munkres' version of the
% Hungarian algorithm to compute an assignment which minimizes the total
% cost. It returns an M x 2 matrix containing the corresponding indices of
% assigned tracks and detections in its two columns. It also returns the
% indices of tracks and detections that remained unassigned.

    M = length(tracks);
    N = size(centroids,1);

    % Compute the cost of assigning each detection to each track.
    cost = zeros(M,N);
    for ii=1:M
        cost(ii,:) = distance(tracks(ii).kalmanFilter,centroids);
    end

    % Solve the assignment problem.
    [assignments, unassignedTracks, unassignedDetections] = ...
        assignDetectionsToTracks(cost,params.costOfNonAssignment);
end
function show(tracks,params)
%SHOW Draw a bounding box and label ID for each track on the video frame.
%     tracks = tracks(1:min(length(tracks),15));
    if ~isempty(tracks)
        % Only show active tracks.
        activeTracks = tracks([tracks(:).active]);
        
        % Noisy detections tend to result in short-lived tracks.
        % Only display tracks that have been visible for more than 
        % a minimum number of frames.
        reliableTrackInds = [activeTracks(:).totalVisibleCount] > params.minVisibleCount;
        reliableTracks = activeTracks(reliableTrackInds);

        % Display the objects. If an object has not been detected
        % in this frame, display its predicted bounding box.
        if ~isempty(reliableTracks)
            % Get bounding boxes.
            bboxes = cat(1,reliableTracks.bbox);

            % Get ids
            ids = int32([reliableTracks(:).id]);

            % Create labels for objects indicating the ones for which we
            % display the predicted rather than the actual location.
            labels = cellstr(int2str(ids'));
            predictedTrackInds = [reliableTracks(:).consecutiveInvisibleCount] > 0;
            isPredicted = cell(size(labels));
            isPredicted(predictedTrackInds) = {'P'};
            labels = strcat(labels,isPredicted);

            x = double(bboxes(:,1)+bboxes(:,3)/2);
            y = double(bboxes(:,2)+bboxes(:,4)/2);
            
            % Draw the objects on the frame.
            for ii=1:length(reliableTracks)
%                 rectangle('Position',bboxes(ii,:),'LineWidth',2,'EdgeColor',ind2rgb(ii,parula(length(tracks))));
                addpoints(reliableTracks(ii).animatedline,x(ii),y(ii));
%                 if reliableTracks(ii).consecutiveInvisibleCount>0
%                     reliableTracks(ii).animatedline.Marker = 'x';
%                 else
%                     reliableTracks(ii).animatedline.Marker = 's';
%                 end
            end
%             text(double(bboxes(:,1))-1,double(bboxes(:,2))-1,labels,'Color','w','FontSize',14);
%             frame = insertObjectAnnotation(frame,'rectangle',bboxes,labels);
        end
    end
%     imshow(frame);
end

