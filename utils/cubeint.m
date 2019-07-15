function V = cubeint(A,B)
%CUBEINT Cube intersection volume.
%   V = CUBEINT(A,B) returns the volume of intersection of the cubes
%   specified by 3D position vectors A and B.
%
%   If A and B each specify one cube, the output is a scalar.
%
%   A and B can also be matrices, where each row is a 3D position vector.
%   The output is then a matrix giving the intersection of all cubes 
%   specified by A with all the cubes specified by B.  That is, if A is
%   M-by-6 and B is N-by-6, then V is an M-by-N matrix where V(P,Q) is the
%   intersection volume of the cubes specified by the Pth row of A and the 
%   Qth row of B.
%
%   Note: A 3D position vector is a six-element vector [X,Y,Z,WID,HEI,DEP],
%   where the point defined by (X,Y,Z) specifies one corner of the cube, 
%   and (WID,HEI,DEP) defines the cube size along the x-, y-, and z-axes,
%   respectively.
%
%   See also RECTINT.

% Copyright 2016 Matthew R. Eicholtz

% Get the number of cubes in each input argument
M = size(A,1);
N = size(B,1);

% Extract two corners of the cubes
Ax0 = A(:,1);
Ay0 = A(:,2);
Az0 = A(:,3);
Ax1 = Ax0+A(:,4);
Ay1 = Ay0+A(:,5);
Az1 = Az0+A(:,6);

Bx0 = B(:,1)';
By0 = B(:,2)';
Bz0 = B(:,3)';
Bx1 = Bx0+B(:,4)';
By1 = By0+B(:,5)';
Bz1 = Bz0+B(:,6)';

% Setup variables for pairwise computation of intersection volume
Ax0 = repmat(Ax0,1,N);
Ay0 = repmat(Ay0,1,N);
Az0 = repmat(Az0,1,N);
Ax1 = repmat(Ax1,1,N);
Ay1 = repmat(Ay1,1,N);
Az1 = repmat(Az1,1,N);

Bx0 = repmat(Bx0,M,1);
By0 = repmat(By0,M,1);
Bz0 = repmat(Bz0,M,1);
Bx1 = repmat(Bx1,M,1);
By1 = repmat(By1,M,1);
Bz1 = repmat(Bz1,M,1);

% Compute the intersection volume(s)
V = (max(0,min(Ax1,Bx1) - max(Ax0,Bx0))) .* ...
    (max(0,min(Ay1,By1) - max(Ay0,By0))) .* ...
    (max(0,min(Az1,Bz1) - max(Az0,Bz0)));

end

