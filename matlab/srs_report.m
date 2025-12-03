function output_pdf = srs_report(output_pdf)
%SRS_REPORT Generate a PDF report demonstrating LTE SRS creation.
%   OUTPUT_PDF = SRS_REPORT(OUTPUT_PDF) builds several UE configurations,
%   generates their SRS symbols, visualizes the frequency-domain mapping and
%   time-domain characteristics, computes cross-correlation, and assembles a
%   PDF report using MATLAB Report Generator. If OUTPUT_PDF is omitted, the
%   report is saved alongside this script as srs_report.pdf.

addpath(fileparts(mfilename('fullpath')));

if nargin < 1 || isempty(output_pdf)
    output_pdf = fullfile(fileparts(mfilename('fullpath')), 'srs_report.pdf');
end

import mlreportgen.report.*;
import mlreportgen.dom.*;

r = Report(output_pdf, 'pdf');
try
    add(r, TitlePage('Title', 'LTE SRS Validation Report', ...
        'Author', 'srs\_creator MATLAB tools'));
    add(r, TableOfContents);

    configs = build_configurations();
    subframe = 4;
    results = generate_signals(configs, subframe);

    add(r, configuration_section(configs, subframe));
    add(r, sequence_section(configs, results));
    add(r, correlation_section(results));
    add(r, hopping_section(results));
    add(r, SummaryChapter('Title', 'Summary', ...
        'Content', Paragraph('All requested SRS sequences were generated and visualized. Hopping-enabled UEs show expected spectral spreading in the provided spectrograms.')));

    close(r);
catch err
    close(r);
    rethrow(err);
end

fprintf('SRS report written to %s\n', r.OutputPath);
end

function sec = configuration_section(configs, subframe)
    sec = Chapter('Title', sprintf('Test Configurations (Subframe %d)', subframe));
    desc = Paragraph(['This section lists the UE configurations exercised in the report, ' ...
        'covering different cyclic shifts, transmission combs, and hopping modes.']);
    sec.add(desc);

    header = {'UE', 'Cell ID', 'Group Hop', 'Seq Hop', 'Comb', 'Cyclic Shift (rad)', 'SRS BW', 'N_{UL}^{RB}'};
    body = cell(numel(configs)+1, numel(header));
    body(1, :) = header;
    for idx = 1:numel(configs)
        cfg = configs{idx};
        body(idx+1, :) = {sprintf('UE%d', idx-1), cfg.cell_id, logical2str(cfg.group_hopping_enabled), ...
            logical2str(cfg.sequence_hopping_enabled), cfg.transmission_comb, cfg.cyclic_shift, cfg.srs_bandwidth, cfg.n_ul_rb};
    end
    t = Table(body);
    t.Style = [t.Style {Border('solid', 'black', '1px'), RowSep('solid', 'black', '1px'), ColSep('solid', 'black', '1px')}];
    t.Width = '100%';
    sec.add(t);
end

function sec = sequence_section(configs, results)
    sec = Chapter('Title', 'SRS Sequence Validation');
    intro = Paragraph(['Each UE''s SRS is generated and compared against the expected ' ...
        'frequency-domain occupancy. The following plots show the allocated subcarriers ' ...
        'and the constellation of the mapped Zadoff–Chu sequence.']);
    sec.add(intro);

    for idx = 1:numel(configs)
        cfg = configs{idx};
        res = results{idx};
        fig_path = plot_sequence(cfg, res);
        fig = mlreportgen.report.Figure();
        fig.Snapshot = fig_path;
        fig.Caption = sprintf('UE%d – Cell %d, comb %d, \n\alpha=%.2f, root u=%d', ...
            idx-1, cfg.cell_id, cfg.transmission_comb, res.info.alpha, res.info.root_index);
        sec.add(fig);
    end
end

function sec = correlation_section(results)
    labels = arrayfun(@(i) sprintf('UE%d', i-1), 1:numel(results), 'UniformOutput', false);
    corr = correlation_matrix(results);
    pairs = highlight_pairs(corr);

    sec = Chapter('Title', 'Cross-Correlation Verification');
    explanation = Paragraph(['Normalized cross-correlation between all generated SRS signals. ' ...
        'Low off-diagonal magnitudes indicate good orthogonality.']);
    sec.add(explanation);

    if isempty(pairs)
        sec.add(Paragraph('No highly correlated pairs detected above the 0.3 threshold.'));
    else
        list = UnorderedList;
        for idx = 1:size(pairs, 1)
            list.append(Item(sprintf('%s vs %s: %.3f', labels{pairs(idx,1)}, labels{pairs(idx,2)}, pairs(idx,3))));
        end
        sec.add(Paragraph('Highly correlated pairs (>0.3):'));
        sec.add(list);
    end

    fig_path = plot_correlation(corr, labels);
    fig = mlreportgen.report.Figure();
    fig.Snapshot = fig_path;
    fig.Caption = 'Normalized SRS cross-correlation magnitude';
    sec.add(fig);
end

function sec = hopping_section(results)
    hopping_results = results(cellfun(@(r) r.info.hopping.group_hopping || r.info.hopping.sequence_hopping, results));
    if isempty(hopping_results)
        sec = Chapter('Title', 'Hopping Spectrograms');
        sec.add(Paragraph('No hopping-enabled UEs were present in this scenario.'));
        return;
    end

    sec = Chapter('Title', 'Hopping SRS Spectrograms');
    sec.add(Paragraph(['Spectrograms illustrate the spectral spreading introduced by ' ...
        'group or sequence hopping.']));

    for idx = 1:numel(hopping_results)
        res = hopping_results{idx};
        fig_path = plot_spectrogram(res);
        fig = mlreportgen.report.Figure();
        fig.Snapshot = fig_path;
        fig.Caption = sprintf('UE%d hopping spectrogram (root u=%d)', idx-1, res.info.root_index);
        sec.add(fig);
    end
end

function results = generate_signals(configs, subframe)
    results = cell(size(configs));
    for idx = 1:numel(configs)
        [sig, info] = lte_srs.generate_srs(configs{idx}, subframe);
        N_zc = lte_srs.zc_length(configs{idx});
        base_seq = lte_srs.generate_zadoff_chu(info.root_index, N_zc);
        m_sc = lte_srs.bandwidth_in_subcarriers(configs{idx});
        shifted_seq = lte_srs.apply_cyclic_shift(base_seq(1:m_sc), info.alpha);
        [freq_grid, k0] = lte_srs.map_to_frequency_grid(shifted_seq, configs{idx}, info.n_fft);
        results{idx} = struct('signal', sig, 'info', info, 'freq_grid', freq_grid, 'k0', k0);
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

function path = plot_correlation(corr, labels)
    figure('Visible', 'off');
    imagesc(corr, [0 1]);
    colormap('turbo');
    colorbar;
    set(gca, 'XTick', 1:numel(labels), 'YTick', 1:numel(labels), ...
        'XTickLabel', labels, 'YTickLabel', labels, 'TickDir', 'out');
    xtickangle(45);
    title('Normalized SRS Cross-Correlation');
    axis square;
    path = fullfile(fileparts(mfilename('fullpath')), 'correlation_matrix.png');
    saveas(gcf, path);
    close(gcf);
end

function path = plot_sequence(cfg, res)
    figure('Visible', 'off');
    subplot(2,1,1);
    stem(res.k0:res.k0+numel(res.freq_grid)-1, abs(res.freq_grid), 'filled');
    xlabel('Subcarrier Index'); ylabel('|SRS|');
    title(sprintf('UE Cell %d – Frequency Occupancy', cfg.cell_id));
    grid on;

    subplot(2,1,2);
    plot(real(res.freq_grid), imag(res.freq_grid), '.');
    xlabel('In-Phase'); ylabel('Quadrature');
    title('Mapped Zadoff–Chu Constellation');
    axis equal; grid on;

    path = fullfile(fileparts(mfilename('fullpath')), sprintf('srs_sequence_ue%d.png', cfg.cell_id));
    saveas(gcf, path);
    close(gcf);
end

function path = plot_spectrogram(res)
    figure('Visible', 'off');
    window = max(16, floor(numel(res.signal)/8));
    overlap = floor(window/2);
    nfft = max(64, 2^nextpow2(window));
    spectrogram(res.signal, window, overlap, nfft, 1, 'yaxis');
    title(sprintf('Spectrogram – root u=%d, comb=%d', res.info.root_index, res.info.comb));
    path = fullfile(fileparts(mfilename('fullpath')), sprintf('srs_spectrogram_u%d.png', res.info.root_index));
    saveas(gcf, path);
    close(gcf);
end

function txt = logical2str(value)
    if value
        txt = 'Yes';
    else
        txt = 'No';
    end
end
