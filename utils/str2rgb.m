function rgb = str2rgb(str)
%STR2RGB Convert ColorSpec string to RGB triplet.
%   RGB = STR2RGB(STR) returns the RGB triplet corresponding to the input
%   color string, which can be in either long or short form.
%
%   Example:
%   1) Retrieve the RGB triplet for the color 'cyan':
%
%       rgb = str2rgb('cyan'); %should return [0 1 1]
%
%   Notes:
%   1) Valid colors include black, blue, cyan, green, magenta, red, white, 
%   and yellow.
%
%   2) See the associated Cody problem on the MathWorks website:
%   http://www.mathworks.com/matlabcentral/cody/problems/42612-convert-colorspec-string-to-rgb-triplet
%   The solution used here was originally submitted by Peng Liu (Solution 734423).

% Copyright 2016 Matthew R. Eicholtz

rgb = dec2bin(rem(find(strcmpi(strsplit('k b g c r m y w black blue green cyan red magenta yellow white'),str))-1,8),3)-'0';
    
end

