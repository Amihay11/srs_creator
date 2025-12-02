function srs_tester()
%SRS_TESTER Generate sample LTE SRS waveforms and visualize correlation.
%   This MATLAB version mirrors the Python srs_tester.py script. It builds
%   a small suite of UE configurations, generates SRS symbols, computes the
%   normalized cross-correlation matrix, highlights highly-correlated pairs,
%   and saves a heatmap to correlation_matrix.png.

addpath(fileparts(mfilename('fullpath')));

configs = build_configurations();
subframe = 4;
fprintf('Generating SRS for subframe %d\n\n', subframe);
for idx = 1:numel(configs)
    disp(configs{idx});
end

results = generate_signals(configs, subframe);
labels = arrayfun(@(i) sprintf('UE%d', i - 1), 1:numel(results), 'UniformOutput', false);
corr = correlation_matrix(results);
pairs = highlight_pairs(corr);

fprintf('\nCorrelation matrix (magnitude):\n');
disp(corr);

if isempty(pairs)
    fprintf('\nNo highly correlated pairs detected.\n');
else
    fprintf('\nHighly correlated pairs (>0.3):\n');
    for idx = 1:size(pairs, 1)
        fprintf('  %s vs %s: %.3f\n', labels{pairs(idx, 1)}, labels{pairs(idx, 2)}, pairs(idx, 3));
    end
end

if license('test', 'MAP_Toolbox') || license('test', 'MATLAB')
    plot_path = plot_correlation(corr, labels);
    fprintf('Correlation heatmap saved to %s\n', plot_path);
else
    fprintf('MATLAB graphics not available; skipping heatmap rendering.\n');
end
end

function configs = build_configurations()
    common = {'bandwidth_config', 2, 'subframe_config', 2, 'b_hop', 1, 'n_ul_rb', 50};
    entries = {
        0, true, false, 0, 0.0, 0;
        1, true, true, 1, pi/4, 1;
        12, false, true, 0, pi/2, 2;
        37, false, false, 1, 3*pi/4, 3;
    };
    configs = cell(1, size(entries, 1));
    for idx = 1:size(entries, 1)
        row = entries(idx, :);
        configs{idx} = lte_srs.create_config('cell_id', row{1}, ...
            'group_hopping_enabled', row{2}, ...
            'sequence_hopping_enabled', row{3}, ...
            'transmission_comb', row{4}, ...
            'cyclic_shift', row{5}, ...
            'srs_bandwidth', row{6}, ...
            common{:});
    end
end

function results = generate_signals(configs, subframe)
    results = cell(size(configs));
    for idx = 1:numel(configs)
        [sig, info] = lte_srs.generate_srs(configs{idx}, subframe);
        results{idx} = struct('signal', sig, 'info', info);
    end
end

function corr = correlation_matrix(results)
    n = numel(results);
    corr = zeros(n);
    for i = 1:n
        for j = 1:n
            corr(i, j) = lte_srs.normalized_cross_correlation(results{i}.signal, results{j}.signal);
        end
    end
end

function pairs = highlight_pairs(corr, threshold)
    if nargin < 2
        threshold = 0.3;
    end
    pairs = [];
    n = size(corr, 1);
    for i = 1:n
        for j = i+1:n
            if corr(i, j) > threshold
                pairs = [pairs; i, j, corr(i, j)]; %#ok<AGROW>
            end
        end
    end
end

function plot_path = plot_correlation(corr, labels)
    figure('Visible', 'off');
    imagesc(corr, [0 1]);
    colormap('viridis');
    colorbar;
    set(gca, 'XTick', 1:numel(labels), 'YTick', 1:numel(labels), ...
        'XTickLabel', labels, 'YTickLabel', labels, 'TickDir', 'out');
    xtickangle(45);
    title('Normalized SRS Cross-Correlation');
    axis square;
    plot_path = fullfile(fileparts(mfilename('fullpath')), 'correlation_matrix.png');
    saveas(gcf, plot_path);
    close(gcf);
end
