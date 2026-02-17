function v = scielab_metric(origRGB, mosaicRGB)
% Returns mean S-CIELAB difference (lower is better).
% Uses the scielab() function provided in Lab 3. :contentReference[oaicite:1]{index=1}

    origRGB   = im2double(ensure_rgb_uint8(origRGB));
    mosaicRGB = im2double(ensure_rgb_uint8(mosaicRGB));

    % Ensure identical size
    if any(size(origRGB) ~= size(mosaicRGB))
        mosaicRGB = imresize(mosaicRGB, [size(origRGB,1) size(origRGB,2)]);
    end

    % Convert to XYZ (as Lab3 describes) :contentReference[oaicite:2]{index=2}
    origXYZ   = rgb2xyz(origRGB) * 100;
    mosaicXYZ = rgb2xyz(mosaicRGB) * 100;

    % Lab3 example white point for D65 :contentReference[oaicite:3]{index=3}
    whitePoint = [95.05 100 108.9];

    % Choose a reasonable viewing setup
    % If you don’t know, 30 is a common default used in demos.
    sampPerDeg = 30;

    diffImg = scielab(sampPerDeg, origXYZ, mosaicXYZ, whitePoint, 'xyz');

    v = mean(diffImg(:));
end
