function [img, format, errmsg] = HDRRead(imgfilename, continueOnError, flipit)
% [img, format, errmsg] = HDRRead(imgfilename [, continueOnError=0][, flipit=0])
% Read a high dynamic range image file and return it as Matlab double
% matrix, suitable for use with Screen('MakeTexture') and friends.
%
% 'imgfilename' - Filename of the HDR image file to load.
%
% Returns 'img' - A double precision matrix of size h x w x c where h is
% the height of the input image, w is the width and c is the number of
% color channels: 1 for luminance images, 2 for luminance images with alpha
% channel, 3 for true-color RGB images, 4 for RGB images with alpha
% channel. If 'imgfilename' is not a supported file type or some error happens,
% then 'img' will be returned as empty [] matrix.
%
% 'continueOnError' Optional flag. If set to 1, HDRRead won't abort on
% error, but simply return an empty img matrix. Useful for probing if a
% specific file type is supported. If set to 0 or omitted, then HDRRead will
% abort with an error on any problem or unsupported image file types.
%
% In case of failure, the returned 'errmsg' may contain a useful error message.
%
% 'flipit' Optional flag: If set to 1, the loaded image is flipped upside
% down.
%
% Returns a double() precision image matrix in 'img', and an id in 'format' which
% describes the format of the source image file:
%
% 'rgbe' == Radiance RGBE format: Color values are in units of radiance.
% 'openexr' == OpenEXR image format.
%
% HDRRead is a dispatcher for a collection of reading routines for
% different HDR image file formats. Currently supported are:
%
% * Radiance run length encoded RGBE format, read via read_rle_rgbe(), or hdrread()
%   if available. File extension is ".hdr". Returns a RGB image.
%
% * OpenEXR files, extension is ".exr". These are readable efficiently if
%   the MIT licensed exrread() command from the following 3rd package/webpage is
%   installed: https://github.com/skycaptain/openexr-matlab
%   That package uses the OpenEXR libraries for image reading, so those libraries
%   must be installed on your system as well.
%
%   If exrread() or the required OpenEXR libraries are missing, then Screen()'s
%   builtin Screen('ReadHDRImage') function is used, which uses the builtin
%   tinyexr open-source library from: https://github.com/syoyo/tinyexr
%   This method if fast and can handle the most common OpenEXR format encodings,
%   but may not be able to cope with some more unusual encodings. See the feature
%   table at tinyexr's GitHub page for features and limitations.
%
% The reader routines are contributed code or open source / free software /
% public domain code downloaded from various locations under different, but
% MIT compatible licenses. See the help for the respective loaders for
% copyright and author information.

% History:
% 14-Dec-2006   mk Written.
% 21-Jul-2020   mk Updated for use with Psychtoolbox new HDR support.

psychlasterror('reset');

if nargin < 1 || isempty(imgfilename) || ~ischar(imgfilename)
    error('Missing HDR image filename.');
end

if nargin < 2 || isempty(continueOnError)
    continueOnError = 0;
end

if nargin < 3 || isempty(flipit)
    flipit = 0;
end

% Format dispatcher:
dispatched = 0;
img = [];
format = [];

if exist(imgfilename, 'file') ~= 2
    errmsg = ['HDR file ' imgfilename ' does not exist.'];

    if continueOnError
        warning(errmsg);
        return;
    else
        error(errmsg);
    end
end

[~, ~, fext] = fileparts(imgfilename);

if strcmpi(fext, '.hdr')
    % Load a RLE encoded RGBE high dynamic range file:
    dispatched = 1;
    try
        % Does (potentially optimized) hdrread() function exist?
        if exist('hdrread', 'file')
            % Use it.
            inimg = double(hdrread(imgfilename));
        else
            % Use our own fallback:
            inimg = read_rle_rgbe(imgfilename);
        end
    catch
        if continueOnError
            warning(['HDR file ' imgfilename ' failed to load.']);
            msg = psychlasterror;
            disp(msg.message);
            errmsg = ['Unknown error. Maybe ' msg.message];
            return;
        else
            psychrethrow(psychlasterror);
        end
    end

    format = 'rgbe';
end

if strcmpi(fext, '.exr')
    % Load an OpenEXR high dynamic range file:
    dispatched = 1;
    try
        % Does (potentially optimized) exrread() function exist?
        if exist('exrread', 'file')
            % Use it.
            inimg = double(exrread(imgfilename));
        else
            % Use our own fallback:
            [inimg, format, err] = Screen('ReadHDRImage', imgfilename);
            if isempty(inimg)
                if continueOnError
                    warning(['HDR file ' imgfilename ' failed to load: ' err]);
                    msg = psychlasterror;
                    disp(msg.message);
                    errmsg = err;
                    return;
                else
                    psychrethrow(psychlasterror);
                end
            end
        end
    catch
        if continueOnError
            warning(['HDR file ' imgfilename ' failed to load.']);
            msg = psychlasterror;
            disp(msg.message);
            errmsg = ['Unknown error. Maybe ' msg.message];
            return;
        else
            psychrethrow(psychlasterror);
        end
    end

    format = 'openexr';
end

if dispatched == 0
    if ~continueOnError
        error(['Potential HDR file ' imgfilename ' is of unknown type, or no loader available for this type.']);
    else
        warning(['Potential HDR file ' imgfilename ' is of unknown type, or no loader available for this type']);
        errmsg = 'No loader available for this type.';

        return;
    end
end

if flipit
    img(:,:,1) = flipud(inimg(:,:,1));
    img(:,:,2) = flipud(inimg(:,:,2));
    img(:,:,3) = flipud(inimg(:,:,3));
else
    img = inimg;
end

errmsg = '';

% Done.
return;
