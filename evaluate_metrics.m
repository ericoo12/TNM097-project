function M = evaluate_metrics(origRGB, mosaicRGB)
% Returns a struct with fields: PSNR, SSIM, S_CIELAB, MSE, DeltaEab

    origRGB   = ensure_rgb_uint8(origRGB);
    mosaicRGB = ensure_rgb_uint8(mosaicRGB);

    % Ensure same size
    if any(size(origRGB) ~= size(mosaicRGB))
        origRGB = imresize(origRGB, [size(mosaicRGB,1), size(mosaicRGB,2)]);
    end

    % PSNR + SSIM
    M.PSNR = psnr(mosaicRGB, origRGB);
    M.SSIM = ssim(mosaicRGB, origRGB);

    % S-CIELAB (Lab3 scielab; expects XYZ in 0..100, D65 whitepoint)
    origXYZ   = rgb2xyz(im2double(origRGB)) * 100;
    mosaicXYZ = rgb2xyz(im2double(mosaicRGB)) * 100;

    whitePoint = [95.05 100 108.9];  % D65
    sampPerDeg = 30;                 % fixed viewing setup for comparisons

    evalc("diffImg = scielab(sampPerDeg, origXYZ, mosaicXYZ, whitePoint, 'xyz');");
    M.S_CIELAB = mean(diffImg(:));

    % MSE
    diff = im2double(mosaicRGB) - im2double(origRGB);
    M.MSE = mean(diff(:).^2);

    % Mean ΔE*ab (plain CIELAB, non-spatial)
    lab1 = rgb2lab(im2double(origRGB));
    lab2 = rgb2lab(im2double(mosaicRGB));
    dE = sqrt(sum((lab1 - lab2).^2, 3));
    M.DeltaEab = mean(dE(:));
end
