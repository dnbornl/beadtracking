function y = randsample(n,k,replacement)
%RANDSAMPLE Random sample.
%   Y = RANDSAMPLE(N,K) returns K values sampled uniformly at random,
%   without replacement, from the integers 1 to N.
%
%   Y = RANDSAMPLE(N,K,REPLACEMENT) returns samples with REPLACEMENT if
%   true, or without REPLACEMENT if false (default).
%
%   Notes:
%   1) This function was created as a replacement for the built-in function
%   of the same name, which requires the Statistics and Machine Learning
%   Toolbox.

% Copyright 2019 Matthew R. Eicholtz

% Parse inputs
if ~exist('replacement','var')
    replacement = false;
end
if k>n && ~replacement
    error('Invalid inputs: k cannot be greater than n if sampling without replacement.')
end

% Create array of potential samples
if replacement
    choices = repmat(1:n,1,k);
else
    choices = 1:n;
end

% Use randperm to pick from the available choices
p = randperm(length(choices),k);
y = choices(p)';

end

