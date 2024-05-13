function [imbn] = rolling_ball(imod,pad,ball,thred)
% Background Normalize has three steps:
%   Denoise
%   Background normalize
%   Extend SNR ratio
%
% [imbn, imer] = bgnormalize(imod) returns
%   normalized and extended ratio image.

% Convert to double
if ~isfloat(imod(1))
    imod = double(imod);
end

% Denoise
impz = padarray(imod, [pad pad], 'symmetric');
imwf = wiener2(impz, [(pad+1) (pad+1)]);
% impz = padarray(imod, [5 5], 'symmetric');
% imwf = wiener2(impz, [6 6]);

% Background normalize
% Rolling ball structure with R = 50, H = 50
% se = strel('ball', 50, 50);

se = strel('ball', ball, ball);
temp=sort(imwf(:));
n1=uint32(length(temp)*thred);
threshold=temp(n1);
imwf(imwf <threshold) = threshold;

imop = imopen(imwf, se);

imwf = imwf((pad+1):end-pad, (pad+1):end-pad);
imop = imop((pad+1):end-pad, (pad+1):end-pad);

% imwf = imwf(6:end-5, 6:end-5);
% imop = imop(6:end-5, 6:end-5);
imbn = imwf - imop;     % imtophat(imwf, se)

