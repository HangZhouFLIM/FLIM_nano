%% Contact vs Non-contact Membrane Intensity (uses CSV columns: Xcoord, Ycoord, Int)
% Requirements: Image Processing Toolbox, Statistics Toolbox
% Instructions:
% 1) Select CSV (must contain columns Xcoord, Ycoord, Int)
% 2) Select one binary/labeled mask image (same biological field; any size)
% 3) Click once inside the cell of interest
% 4) Click inside neighbor cell(s) (one click per neighbor). Press Enter when done.
%    - If you press Enter immediately (no neighbor clicks), the script will treat all other objects as neighbors.

clc; clear; close all;

%% ------------- Parameters (tweak if needed) ----------------
membrane_width_px = 3;      % thickness of membrane band in pixels
contact_dilation_px = 3;    % dilation radius to define contact (pixels)
min_region_area = 20;       % remove small objects (in pixels)
nbins_unwrap = 90;          % number of bins for unwrapped membrane plot
%% -----------------------------------------------------------------

%% --------------- 1) Select CSV -----------------------------------
[fn_csv, fp_csv] = uigetfile('*.csv', 'Select CSV file with columns Xcoord, Ycoord, Int');
if isequal(fn_csv,0), error('No CSV selected.'); end
T = readtable(fullfile(fp_csv, fn_csv));

% require the exact column names
requiredCols = {'Xcoord','Ycoord','Int'};
if all(ismember(requiredCols, T.Properties.VariableNames))
    x = T.Xcoord;
    y = T.Ycoord;
    inten = T.Int;
else
    error('CSV must contain columns named exactly: Xcoord, Ycoord, Int. Found: %s', strjoin(T.Properties.VariableNames,','));
end

% basic sanity
if any(~isfinite(x) | ~isfinite(y) | ~isfinite(inten))
    bad = ~isfinite(x) | ~isfinite(y) | ~isfinite(inten);
    x(bad) = []; y(bad) = []; inten(bad) = [];
    warning('Removed %d rows with non-finite values.', nnz(bad));
end
if numel(x) < 5
    warning('Very few CSV points after cleanup (%d).', numel(x));
end

%% --------------- 2) Select the single mask image -----------------
[fn_mask, fp_mask] = uigetfile({'*.tif;*.tiff;*.png;*.jpg;*.bmp'}, 'Select single binary / labeled mask image (contains cells)');
if isequal(fn_mask,0), error('No mask selected.'); end
mask_img_raw = imread(fullfile(fp_mask, fn_mask));

% If mask is RGB, convert to grayscale first
if ndims(mask_img_raw) == 3
    mask_img = rgb2gray(mask_img_raw);
else
    mask_img = mask_img_raw;
end

% Convert to labeled image 'labels' (integer labels per object)
if islogical(mask_img) || numel(unique(mask_img))==2
    binmask = mask_img > 0;
    labels = bwlabel(binmask);
else
    % assume labeled/uint image with integers for regions (0 = background)
    labels = double(mask_img);
    % compact labels to 1..N ignoring background 0
    unique_vals = unique(labels(:));
    unique_vals(unique_vals==0) = [];
    if isempty(unique_vals)
        error('Mask image appears empty.');
    end
    newlabels = zeros(size(labels));
    for i = 1:numel(unique_vals)
        newlabels(labels == unique_vals(i)) = i;
    end
    labels = newlabels;
end

% cleanup small objects
labels = bwlabel(labels > 0);
props = regionprops(labels,'Area');
areas = [props.Area];
smalllabs = find(areas < min_region_area);
for s = smalllabs, labels(labels==s) = 0; end
labels = bwlabel(labels > 0);  % relabel after removal

% rotate mask 90 degrees counterclockwise to align with CSV coordinates
labels = rot90(labels);

H = size(labels,1);
W = size(labels,2);

%% --------------- 3) Rasterize CSV onto the MASK grid --------------
% We normalize the CSV coordinates to [1..W] and [1..H] and then bin them.
xmin = min(x); xmax = max(x);
ymin = min(y); ymax = max(y);

% guard against zero-range coordinates
if xmax == xmin
    warning('All Xcoord are identical; placing everything at center X.');
    xs = repmat(round(W/2), size(x));
else
    xs = (x - xmin) / (xmax - xmin) * (W - 1) + 1;  % 1..W
end
if ymax == ymin
    warning('All Ycoord are identical; placing everything at center Y.');
    ys = repmat(round(H/2), size(y));
else
    ys = (y - ymin) / (ymax - ymin) * (H - 1) + 1;  % 1..H
end

% round to pixel indices and clamp
xs = round(xs); ys = round(ys);
xs = max(1, min(W, xs));
ys = max(1, min(H, ys));

% If multiple CSV points map to the same pixel, average their intensities
lin = sub2ind([H W], ys, xs);
sumImg = accumarray(lin, inten, [H*W, 1], @sum, 0);
cntImg = accumarray(lin, 1,     [H*W, 1], @sum, 0);
img = zeros(H, W);
img(:) = sumImg;
img_cnt = zeros(H, W);
img_cnt(:) = cntImg;
% avoid divide-by-zero; keep zeros where no data
nz = img_cnt > 0;
img(nz) = img(nz) ./ img_cnt(nz);

% At this point, size(img) == size(labels) by construction.

%% ------------- 4) Let user pick the cell of interest --------------
figure('Name','Select cell: click once inside the cell of interest','Color','w');
rgb = label2rgb(labels,'jet','k','shuffle');
imshow(rgb);
title({'Click ONCE inside the cell of interest (single click).','Then press Enter in the figure.'});
drawnow;
[xc, yc] = ginput(1);
if isempty(xc)
    error('No click registered. Please run again and click inside a cell.');
end
col = round(xc); row = round(yc);
if row < 1 || row > size(labels,1) || col < 1 || col > size(labels,2)
    error('Click was outside image bounds.');
end
cell_label = labels(row, col);
if cell_label == 0
    error('Clicked background. Please click inside a labeled object.');
end
fprintf('Selected cell label: %d\n', cell_label);

%% ------------- 5) Let user pick neighbor(s) (multiple clicks) -----
title({'Now click inside neighbor cell(s). Click each neighbor once.', ...
       'When finished press Enter (no click) to accept all.'});
drawnow;
[xn, yn] = ginput;  % until Enter pressed
neighbor_labels = [];
if isempty(xn)
    % no clicks: use all other labels as neighbors
    alllabs = unique(labels);
    alllabs(alllabs==0) = [];
    neighbor_labels = setdiff(alllabs, cell_label);
    fprintf('No neighbor clicks: using all other labels as neighbors (%d neighbors).\n', numel(neighbor_labels));
else
    for k = 1:numel(xn)
        c = round(xn(k)); r = round(yn(k));
        if r < 1 || r > size(labels,1) || c < 1 || c > size(labels,2)
            continue;
        end
        lab_at = labels(r,c);
        if lab_at ~= 0 && lab_at ~= cell_label
            neighbor_labels(end+1) = lab_at; %#ok<SAGROW>
        end
    end
    neighbor_labels = unique(neighbor_labels);
    if isempty(neighbor_labels)
        alllabs = unique(labels); alllabs(alllabs==0) = [];
        neighbor_labels = setdiff(alllabs, cell_label);
        fprintf('No valid neighbor clicks found. Defaulting to all other labels (%d neighbors).\n', numel(neighbor_labels));
    else
        fprintf('Selected neighbor labels: %s\n', mat2str(neighbor_labels));
    end
end

% masks
cell_mask = (labels == cell_label);
neighbor_mask = ismember(labels, neighbor_labels);

%% -------------- 6) Compute membrane band and contact pixels -------
if membrane_width_px <= 1
    eroded_cell = imerode(cell_mask, strel('disk',1));
    membrane_band = cell_mask & ~eroded_cell;
else
    eroded_w = imerode(cell_mask, strel('disk', membrane_width_px));
    membrane_band = cell_mask & ~eroded_w;
end

% dilate neighbor mask then overlap with membrane
dil_neigh = imdilate(neighbor_mask, strel('disk', contact_dilation_px));
contact_pixels = membrane_band & dil_neigh;
noncontact_pixels = membrane_band & ~dil_neigh;

% counts and extraction
n_mem = nnz(membrane_band);
n_contact = nnz(contact_pixels);
n_noncontact = nnz(noncontact_pixels);
fprintf('Membrane pixels: %d, Contact: %d, Non-contact: %d\n', n_mem, n_contact, n_noncontact);

contact_ints = img(contact_pixels);
noncontact_ints = img(noncontact_pixels);

%% ---------------- 7) Plots: histogram, boxplot, unwrap ------------
figure('Color','w','Position',[100 100 1400 520]);

% Histogram overlay
subplot(1,3,1);
hold on;
if isempty(contact_ints), contact_ints = NaN; end
if isempty(noncontact_ints), noncontact_ints = NaN; end
histogram(contact_ints,50,'FaceAlpha',0.5,'DisplayStyle','bar','EdgeColor','none');
histogram(noncontact_ints,50,'FaceAlpha',0.5,'DisplayStyle','bar','EdgeColor','none');
legend({'Contact','Non-contact'}); xlabel('Intensity'); ylabel('Count');
title('Intensity histogram (membrane pixels)'); hold off;

% Boxplot
subplot(1,3,2);
group = [repmat(1,numel(contact_ints),1); repmat(2,numel(noncontact_ints),1)];
vals = [contact_ints(:); noncontact_ints(:)];
boxplot(vals, group, 'Labels', {'Contact','Non-contact'});
ylabel('Intensity'); title('Boxplot');

% Unwrapped membrane vs angle
subplot(1,3,3);
[ry, rx] = find(membrane_band);
if isempty(ry)
    warning('No membrane pixels found for unwrapped plot.');
else
    rpixels = sub2ind(size(img), ry, rx);
    vals_mem = img(rpixels);
    rp = regionprops(cell_mask, 'Centroid');
    cent = rp.Centroid; % [x y]
    angles = atan2(double(ry) - cent(2), double(rx) - cent(1)); % radians
    edges = linspace(-pi, pi, nbins_unwrap+1);
    bin_centers = 0.5*(edges(1:end-1)+edges(2:end));
    mean_by_bin = nan(nbins_unwrap,1);
    contact_frac = nan(nbins_unwrap,1);
    for b = 1:nbins_unwrap
        sel = angles >= edges(b) & angles < edges(b+1);
        if any(sel)
            mean_by_bin(b) = mean(vals_mem(sel));
            coords_idx = find(sel);
            ys_bin = ry(coords_idx); xs_bin = rx(coords_idx);
            contact_flags = arrayfun(@(r,c) contact_pixels(r,c), ys_bin, xs_bin);
            contact_frac(b) = mean(contact_flags);
        end
    end
    plot(bin_centers, mean_by_bin, '-o'); xlabel('Angle (rad)'); ylabel('Mean intensity');
    title('Membrane mean intensity vs angle (unwrapped)');
    % shade bins where contact fraction high
    hold on;
    thr = 0.2;
    ymin = nanmin(mean_by_bin); ymax = nanmax(mean_by_bin);
    for b = 1:nbins_unwrap
        if ~isnan(contact_frac(b)) && contact_frac(b) > thr
            x1 = edges(b); x2 = edges(b+1);
            patch([x1 x2 x2 x1],[ymin ymin ymax ymax], [0.8 0.8 0.8], 'FaceAlpha', 0.12, 'EdgeColor','none');
        end
    end
    hold off;
end

%% --------------- 8) Stats (pixel-level) ---------------------------
if numel(contact_ints) >= 5 && numel(noncontact_ints) >= 5
    try
        [~,p_t] = ttest2(contact_ints, noncontact_ints);
    catch
        p_t = NaN;
    end
    try
        p_r = ranksum(contact_ints, noncontact_ints); % nonparametric
    catch
        p_r = NaN;
    end
    fprintf('Pixel-level tests: t-test p=%.4g, ranksum p=%.4g\n', p_t, p_r);
else
    fprintf('Too few pixels for pixel-level tests (need >=5 in each group).\n');
end

%% --------------- 9) Overlay for sanity ---------------------------
figure('Name','Membrane & contact overlay','Color','w');
imshow(mat2gray(img)); hold on;
hMem = imshow(membrane_band); set(hMem, 'AlphaData', double(membrane_band)*0.35);
hCont = imshow(contact_pixels); set(hCont, 'AlphaData', double(contact_pixels)*0.6);
title('Grayscale intensity with membrane (transparent) and contact (brighter overlay)');
