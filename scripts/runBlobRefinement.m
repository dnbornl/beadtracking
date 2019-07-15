%RUNBLOBREFINEMENT Refine detected blobs in image sequence.
%   This script prunes detected blobs found using IMBLOBS. It is part of a
%   series of scripts used to track microbeads in microscopy images of
%   mouse brain tissue.
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
%       'options'       Cell array of strings containing the desired
%                       refinement steps. Valid options include:
%
%               'roi'     	Remove detections outside region-of-interest.
%                           This requires that the mat-file for the 
%                           corresponding image sequence(s) contains a 
%                           structure called 'roi'.
%
%               'gaussian'	Remove stationary detections via peak-finding 
%                           on a heatmap constructed by summing normalized 
%                           Gaussian distributions centered at each 
%                           detection.
%
%               'cluster'	Remove stationary detections via agglomerative 
%                           clustering. In general, this is a much faster
%                           method than 'gaussian' and yields similar
%                           results, depending on how the corresponding
%                           threshold parameters are set.
%
%       'showresults'   Logical scalar indicating whether to show the
%                       refined detections for every frame as it is 
%                       processed.
%
%       'saveresults'   Logical scalar indicating whether to save the
%                       results to file. If true, the output for each image
%                       sequence, including relevant parameters, will be
%                       saved to file (<files{ii}>.mat) in a structure
%                       called 'refinement'. That file can then be loaded
%                       and processed in other scripts (e.g.
%                       RUNKALMANTRACKING).
%
%       ... (some parameters are not listed here, but described below)
%
%   See also IMBLOBS, RUNBLOBDETECTION, RUNKALMANTRACKING.

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

options = {'roi','gaussian','cluster'};

% Thresholds for 'gaussian' option
thold_gaussian = 0.25; % threshold for local maxima in Gaussian heatmap [0-1]
thold_dist = 3; % distance to stationary points (in pixels)
thold_ndist = 2; % distance to stationary points, normalized by blob radius

% Thresholds for 'cluster' option
cutoff = 1.0; % multiplier for largest radius of detection
clustersize = 0.25; % percentage of frames required to be considered a cluster

showresults = false;
saveresults = true;
%==========================================================================

for ii=fileind
    % Setup progress bar
    h = waitbar(0,'Processing...',...
        'Name',sprintf('%s: %s',mfilename,filenames{ii}),...
        'CreateCancelBtn','setappdata(gcbf,''stop'',1)');
    setappdata(h,'stop',0);
    
    % Extract relevant file information
    file = fullfile(pathname,[filenames{ii},'.tif']);
    info = imfinfo(file);
    N = length(info); %number of frames
    m = info(1).Height;
    n = info(1).Width;
    
    % Load detections from mat-file
    datafile = fullfile(pathname,[filenames{ii} '.mat']);
    load(datafile,'roi','detection');
    blobs = detection.blobs;
    scores = detection.scores;
    
    % Perform selected refinement tasks
    for jj=1:length(options)
        switch options{jj}
            case 'roi' %remove detections outside region-of-interest
                for kk=1:N
                    % Stop the code if user clicks 'cancel' button
                    if getappdata(h,'stop'); break; end
                    
                    % Update progress bar
                    waitbar(kk/N,h,sprintf('Removing detections outside ROI: %4d out of %d',kk,N));
                    
                    % Determine which detections are in the ROI
                    x = blobs{kk}(:,1);
                    y = blobs{kk}(:,2);
                    ind = sub2ind([m,n],y,x);
                    mask = roi.mask(ind);
                    
                    % Show results, if requested
                    if showresults
                        figure(sum(mfilename+0));
                        I = imread(file,'Index',kk,'Info',info);
                        imshow(I,[]);
                        viscircles(blobs{kk}(mask,1:2),blobs{kk}(mask,3),'Color','green');
                        viscircles(blobs{kk}(~mask,1:2),blobs{kk}(~mask,3),'Color','red');
                        pause(0.05);
                    end
                    blobs{kk} = blobs{kk}(mask,:);
                    scores{kk} = scores{kk}(mask);
                end
                
            case 'gaussian' %remove stationary detections via Gaussian heatmap
                hmap = 0;
                [x,y] = meshgrid(1:n,1:m);
                for kk=1:N
                    % Stop the code if user clicks 'cancel' button
                    if getappdata(h,'stop'); break; end
                    
                    % Update progress bar
                    waitbar(kk/N,h,sprintf('Constructing Gaussian heatmap: %4d out of %d',kk,N));
                    
                    for mm=1:size(blobs{kk})
                        mu = blobs{kk}(mm,1:2);
                        Sigma = 2*blobs{kk}(mm,3)*eye(2);
                        F = mvnpdf([x(:) y(:)],mu,Sigma);
                        F = F/max(F);
                        F = reshape(F,m,n);
                        hmap = hmap+F;
                    end
                end
                
                [xmax,imax,xmin,imin] = extrema2(hmap);
                [y,x] = ind2sub(size(hmap),imax);
                mask = xmax>(thold_gaussian*length(blobs));
                stationarypts = [x(mask) y(mask)];
                stationarypts = sortrows(stationarypts);
                
                for kk=1:N
                    % Stop the code if user clicks 'cancel' button
                    if getappdata(h,'stop'); break; end
                    
                    % Update progress bar
                    waitbar(kk/N,h,sprintf('Removing stationary detections: %4d out of %d',kk,N));
                    
                    % Remove stationary beads from detections
                    d = pdist2(blobs{kk}(:,1:2),stationarypts);
                    dn = bsxfun(@rdivide,d,blobs{kk}(:,3)); %normalized distance
                    stationaryblobs = any(dn<thold_ndist & d<thold_dist,2);
                    
                    % Show results, if requested
                    if showresults
                        figure(sum(mfilename+0));
                        
                        % Read current image
                        I = imread(file,'Index',kk,'Info',info);
                        imshow(I,[]);
                        
                        % Show which blobs are getting pruned
                        keep = blobs{kk}(~stationaryblobs,:);
                        remove = blobs{kk}(stationaryblobs,:);
                        if ~isempty(keep)
                            circles(keep(:,1),keep(:,2),keep(:,3),'EdgeColor','green');
                        end
                        if ~isempty(remove)
                            circles(remove(:,1),remove(:,2),remove(:,3),'EdgeColor','red');
                        end
                        pause(0.05);
                    end
                    
                    blobs{kk} = blobs{kk}(~stationaryblobs,:);
                    scores{kk} = scores{kk}(~stationaryblobs);
                end
                
            case 'cluster' %remove stationary detections via clustering
                % Collapse all detections into one array
                X = cell2mat(blobs);
                
                % Compute linkage matrix (cluster tree)
                Z = linkage(X,'complete','chebychev');
                
                % Assign cluster labels to each detection
                C = cluster(Z,'cutoff',cutoff*max(X(:,3)),'criterion','distance');
                
                % Compute stationary points by looking at cluster size
                A = accumarray(C,1);
                stationaryclusters = find(A>(clustersize*N));
                xm = accumarray(C,X(:,1),[],@mean);
                ym = accumarray(C,X(:,2),[],@mean);
                stationarypts = round([xm(stationaryclusters),ym(stationaryclusters)]);
                stationarypts = sortrows(stationarypts);
                mask = mat2cell(~ismember(C,stationaryclusters),cellfun('length',blobs));
                                
                % Show results, if requested
                if showresults
                    figure(sum(mfilename+0));
                    for kk=1:N
                        % Stop the code if user clicks 'cancel' button
                        if getappdata(h,'stop'); break; end
                        
                        % Update progress bar
                        waitbar(kk/N,h,sprintf('Removing stationary clusters: %4d out of %d',kk,N));
                        
                        % Read current image
                        I = imread(file,'Index',kk,'Info',info);
                        imshow(I,[]);
                        
                        % Show which blobs are getting pruned
                        keep = blobs{kk}(mask{kk},:);
                        remove = blobs{kk}(~mask{kk},:);
                        if ~isempty(keep)
                            circles(keep(:,1),keep(:,2),keep(:,3),'EdgeColor','green');
                        end
                        if ~isempty(remove)
                            circles(remove(:,1),remove(:,2),remove(:,3),'EdgeColor','red');
                        end
                        pause(0.05);
                    end
                end
                
                blobs = cellfun(@(x,y) x(y,:),blobs,mask,'uni',0);
                scores = cellfun(@(x,y) x(y),scores,mask,'uni',0);
                
            otherwise
                delete(h);
                error('Unrecognized refinement option. Check inputs.');
        end
    end
    
    % Save results to file, if requested
    if ~getappdata(h,'stop') && saveresults
        refinement = struct('blobs',{blobs},'scores',{scores},'options',{options});
        if ismember('roi',options)
            refinement.mask = roi.mask;
        end
        if ismember('gaussian',options)
            thold.gaussian = thold_gaussian;
            thold.ndist = thold_ndist;
            thold.dist = thold_dist;
            refinement.thold = thold;
            refinement.stationarypts = stationarypts;
        end
        if ismember('cluster',options)
            refinement.cutoff = cutoff;
            refinement.clustersize = clustersize;
        end
        
        if exist(datafile,'file')
            save(datafile,'refinement','-append');
        else
            save(datafile,'refinement');
        end
    end
    
    % Delete the progress bar
    try close(sum(mfilename+0)); end
    delete(h);
end

