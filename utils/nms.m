function [x,y] = nms(x,y,minmax)
%NMS Non-maxima/minima suppression.
%   [X,Y] = NMS(X,Y,MINMAX)

% Copyright 2016 Matthew R. Eicholtz

%% Parse inputs
narginchk(2,3);
if nargin<3
    minmax = 'min';
end

%% Sort inputs
switch minmax
    case 'min'
        [y,order] = sort(y,'ascend');
    case 'max'
        [y,order] = sort(y,'descend');
    otherwise
        error('Unrecognized value for MINMAX: %s',minmax);
end
x = x(order,:);

%% Suppress weaker samples
X = []; %store local optima data
Y = []; %store local optima scores
while ~isempty(x) %if there are still bboxes, keep going
    X = [X; x(1,:)];
    Y = [Y; y(1)];
    
    % Compute the percent overlap of the highest-scoring 
    % bounding box with each of the remaining bounding boxes
    bboxes = [x(:,1)-x(:,3), x(:,2)-x(:,3), 2*x(:,3), 2*x(:,3)];
    areaAB = rectint(bboxes,bboxes(1,:)); %intersection area
    areaA = (2*x(:,3)).^2;
    areaB = (2*x(1,3)).^2;
    overlapAB = areaAB./areaB(:);
    overlapBA = areaAB./areaA(:);

    % Discard bounding boxes with overlap > threshold
    mask = overlapAB(:)>=0.5 | overlapBA(:)>=0.5;
    x(mask,:) = [];
    y(mask) = [];
end
x = X;
y = Y;

end

