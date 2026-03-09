function mLab = compute_mean_lab(rgb) % tar en rgb bild och räknar ut medelfärgen i CIELAB färg-rymden
    cform = makecform('srgb2lab');
    lab = applycform(rgb, cform);
    lab = double(lab);
    mLab = squeeze(mean(mean(lab,1),2)).';
end
