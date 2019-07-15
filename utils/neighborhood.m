function varargout = neighborhood(varargin)
%NEIGHBORHOOD Find neighbors in label matrix.
%   A = NEIGHBORHOOD(L) returns an adjacency matrix containing the
%   neighbors found in the input label matrix. The output is symmetric.
%
%   A = NEIGHBORHOOD(L,CONN) specifies the desired connectivity for
%   neighbors and may have the following scalar values:
%
%       4             two-dimensional four-connected neighborhood
%       8             two-dimensional eight-connected neighborhood
%       6             three-dimensional six-connected neighborhood
%       18            three-dimensional 18-connected neighborhood
%       26            three-dimensional 26-connected neighborhood
%
%   [A,AI,AJ] = NEIGHBORHOOD(___) also returns vectors of indices for
%   neighboring pairs. In other words, AI(K) is a neighbor of AJ(K). Index
%   pairs are sorted in ascending order, first on AI, then on AJ.
%
%   Notes:
%   1. The default connectivity is 4 for 2D input and 6 for 3D input.

% Copyright 2016 Matthew R. Eicholtz

[L,conn] = parseinputs(varargin{:});

n = cell(conn,1);
for ii=1:conn
    n{ii} = zeros(size(L));
end

switch conn
    case 4
        % [ - 1 - ]
        % [ 4 0 2 ]
        % [ - 3 - ]
        n{1}(2:end,:)   = L(1:end-1,:);
        n{2}(:,1:end-1) = L(:,2:end);
        n{3}(1:end-1,:) = L(2:end,:);
        n{4}(:,2:end)   = L(:,1:end-1);
        
    case 8
        % [ 1 2 3 ]
        % [ 4 0 5 ]
        % [ 6 7 8 ]
        n{1}(2:end,2:end) = L(1:end-1,1:end-1);
        n{2}(2:end,:) = L(1:end-1,:);
        n{3}(2:end,1:end-1) = L(1:end-1,2:end);
        n{4}(:,2:end) = L(:,1:end-1);
        n{5}(:,1:end-1) = L(:,2:end);
        n{6}(1:end-1,2:end) = L(2:end,1:end-1);
        n{7}(1:end-1,:) = L(2:end,:);
        n{8}(1:end-1,1:end-1) = L(2:end,2:end);
        
    case 6
        % [ - - - ]
        % [ - 5 - ]
        % [ - - - ]
        %
        % [ - 1 - ]
        % [ 4 0 2 ]
        % [ - 3 - ]
        %
        % [ - - - ]
        % [ - 6 - ]
        % [ - - - ]
        n{1}(2:end,:,:) = L(1:end-1,:,:);
        n{2}(:,1:end-1,:) = L(:,2:end,:);
        n{3}(1:end-1,:,:) = L(2:end,:,:);
        n{4}(:,2:end,:) = L(:,1:end-1,:);
        n{5}(:,:,2:end) = L(:,:,1:end-1);
        n{6}(:,:,1:end-1) = L(:,:,2:end);
        
    case 18
        % [  - 10  - ]
        % [ 13  9 11 ]
        % [  - 12  - ]
        %
        % [ 1 2 3 ]
        % [ 4 0 5 ]
        % [ 6 7 8 ]
        %
        % [  - 15  - ]
        % [ 18 14 16 ]
        % [  - 17  - ]
        n{1}(2:end,2:end,:) = L(1:end-1,1:end-1,:);
        n{2}(2:end,:,:) = L(1:end-1,:,:);
        n{3}(2:end,1:end-1,:) = L(1:end-1,2:end,:);
        n{4}(:,2:end,:) = L(:,1:end-1,:);
        n{5}(:,1:end-1,:) = L(:,2:end,:);
        n{6}(1:end-1,2:end,:) = L(2:end,1:end-1,:);
        n{7}(1:end-1,:,:) = L(2:end,:,:);
        n{8}(1:end-1,1:end-1,:) = L(2:end,2:end,:);
        
        n{9}(:,:,2:end) = L(:,:,1:end-1);
        n{10}(2:end,:,2:end) = L(1:end-1,:,1:end-1);
        n{11}(:,1:end-1,2:end) = L(:,2:end,1:end-1);
        n{12}(1:end-1,:,2:end) = L(2:end,:,1:end-1);
        n{13}(:,2:end,2:end) = L(:,1:end-1,1:end-1);
        
        n{14}(:,:,1:end-1) = L(:,:,2:end);
        n{15}(2:end,:,1:end-1) = L(1:end-1,:,2:end);
        n{16}(:,1:end-1,1:end-1) = L(:,2:end,2:end);
        n{17}(1:end-1,:,1:end-1) = L(2:end,:,2:end);
        n{18}(:,2:end,1:end-1) = L(:,1:end-1,2:end);
        
    case 26
        % [ 1 2 3 ]
        % [ 4 5 6 ]
        % [ 7 8 9 ]
        %
        % [ 10 11 12 ]
        % [ 13  0 14 ]
        % [ 15 16 17 ]
        %
        % [ 18 19 20 ]
        % [ 21 22 23 ]
        % [ 24 25 26 ]
        n{1}(2:end,2:end,2:end) = L(1:end-1,1:end-1,1:end-1);
        n{2}(2:end,:,2:end) = L(1:end-1,:,1:end-1);
        n{3}(2:end,1:end-1,2:end) = L(1:end-1,2:end,1:end-1);
        n{4}(:,2:end,2:end) = L(:,1:end-1,1:end-1);
        n{5}(:,:,2:end) = L(:,:,1:end-1);
        n{6}(:,1:end-1,2:end) = L(:,2:end,1:end-1);
        n{7}(1:end-1,2:end,2:end) = L(2:end,1:end-1,1:end-1);
        n{8}(1:end-1,:,2:end) = L(2:end,:,1:end-1);
        n{9}(1:end-1,1:end-1,2:end) = L(2:end,2:end,1:end-1);
        
        n{10}(2:end,2:end,:) = L(1:end-1,1:end-1,:);
        n{11}(2:end,:,:) = L(1:end-1,:,:);
        n{12}(2:end,1:end-1,:) = L(1:end-1,2:end,:);
        n{13}(:,2:end,:) = L(:,1:end-1,:);
        n{14}(:,1:end-1,:) = L(:,2:end,:);
        n{15}(1:end-1,2:end,:) = L(2:end,1:end-1,:);
        n{16}(1:end-1,:,:) = L(2:end,:,:);
        n{17}(1:end-1,1:end-1,:) = L(2:end,2:end,:);
        
        n{18}(2:end,2:end,1:end-1) = L(1:end-1,1:end-1,2:end);
        n{19}(2:end,:,1:end-1) = L(1:end-1,:,2:end);
        n{20}(2:end,1:end-1,1:end-1) = L(1:end-1,2:end,2:end);
        n{21}(:,2:end,1:end-1) = L(:,1:end-1,2:end);
        n{22}(:,:,1:end-1) = L(:,:,2:end);
        n{23}(:,1:end-1,1:end-1) = L(:,2:end,2:end);
        n{24}(1:end-1,2:end,1:end-1) = L(2:end,1:end-1,2:end);
        n{25}(1:end-1,:,1:end-1) = L(2:end,:,1:end-1);
        n{26}(1:end-1,1:end-1,1:end-1) = L(2:end,2:end,2:end);
end

subs = [];
for ii=1:conn
    subs = [subs; L(:), n{ii}(:)];
end
subs(any(subs==0,2),:) = []; %remove zeros
subs(diff(subs,1,2)==0,:) = []; %remove self as neighbor

A = accumarray(subs,1);
A = A+A';
A = A>0;

[ai,aj] = find(A);
a = sortrows([ai,aj]);

varargout = {A,a(:,1),a(:,2)};

end

%% Helper functions
function varargout = parseinputs(varargin)
%PARSEINPUTS Custom input parsing function.
    p = inputParser;
    
    p.addRequired('L',@(x) validateattributes(x,{'numeric'},{'nonempty','nonsparse','integer','positive'}));
    p.addOptional('conn',[],@(x) validateattributes(x,{'numeric'},{'scalar','integer','positive'}));
    
    p.parse(varargin{:});
    
    conn = p.Results.conn;
    L = p.Results.L;
    
    if isempty(conn)
        if ismatrix(L)
            conn = 4;
        else
            conn = 6;
        end
    end
    
    if ~ismember(conn,[4 8 6 18 26])
        error('The value of ''conn'' is invalid. Expected input to be 4, 8, 6, 18, or 26.');
    elseif ismatrix(L) && ~ismember(conn,[4 8])
        error('The value of ''conn'' is invalid. Expected input to be 4 or 8 for 2D label matrix.');
    elseif ~ismatrix(L) && ~ismember(conn,[6 18 26])
        error('The value of ''conn'' is invalid. Expected input to be 6, 18, or 26 for 3D label matrix.');
    end
    
    varargout = {L,conn};
end

