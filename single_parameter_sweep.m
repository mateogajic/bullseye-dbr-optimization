clearvars
close all

%% Single-parameter extraction-efficiency sweep
% Post-processes RSoft spatial-monitor files for simulations in which one
% parameter is varied. Extraction efficiency is calculated by integrating
% the normal power density over a circular monitor aperture and applying
% the symmetry factor associated with the simulated domain.

%% Paths
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);
data_root = fullfile(repo_root, 'data');
results_root = fullfile(repo_root, 'results', 'single_parameter');

% Edit these values to match the RSoft simulation output.
simulation_folder = 'DBR_opt';
tag = 'lambda_v1';
monitor = 'm13';
frequency = 'f1';

work_dir = fullfile(data_root, simulation_folder, [tag '_work']);

%% Sweep configuration
% Active example: wavelength sweep from 0.5 to 2.5 micrometres.
sweep_values = 0.5:0.1:2.5;
sweep_label = 'Wavelength, \lambda (\mum)';
output_id = 'lambda_v1';

% Other examples:
% sweep_values = 0.1:0.1:0.7;       sweep_label = 'Numerical aperture';
% sweep_values = 1:30;              sweep_label = 'Number of DBR pairs';
% sweep_values = 0.4:0.05:1.4;      sweep_label = 'Spacer height (\mum)';

symmetry_factor = input(['Enter the symmetry factor (1: full structure, ' ...
    '2: half, 4: quarter, 8: octant): ']);
validateattributes(symmetry_factor, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

num_simulations = numel(sweep_values);
extraction_efficiency = nan(1, num_simulations);

%% Process monitor files
for index = 0:(num_simulations - 1)
    filename = sprintf('%s_%d_%s_%s_pow.dat', ...
        tag, index, monitor, frequency);
    file_path = fullfile(work_dir, filename);

    if ~isfile(file_path)
        warning('File not found: %s. The corresponding result is NaN.', filename);
        continue
    end

    try
        [power_density, x, y] = read_rsoft_spatial_monitor(file_path);
    catch exception
        warning('Could not process %s: %s. The result is NaN.', ...
            filename, exception.message);
        continue
    end

    [X, Y] = meshgrid(x, y);
    aperture_radius = max(abs([x(1), x(end), y(1), y(end)]));
    circular_mask = (X.^2 + Y.^2) <= aperture_radius^2;

    dx = abs(x(2) - x(1));
    dy = abs(y(2) - y(1));
    extraction_efficiency(index + 1) = symmetry_factor ...
        * sum(power_density(circular_mask), 'omitnan') * dx * dy;

    fprintf('[%d/%d] %s = %.6g, EE = %.2f %%\n', ...
        index + 1, num_simulations, sweep_label, sweep_values(index + 1), ...
        100 * extraction_efficiency(index + 1));
end

if all(isnan(extraction_efficiency))
    error(['No monitor file was processed. Check data_root, ' ...
        'simulation_folder, tag, monitor and frequency.']);
end

%% Results
[maximum_efficiency, optimum_index] = max( ...
    extraction_efficiency, [], 'omitnan');
minimum_efficiency = min(extraction_efficiency, [], 'omitnan');
mean_efficiency = mean(extraction_efficiency, 'omitnan');
optimum_value = sweep_values(optimum_index);

fprintf('\nMinimum EE: %.2f %%\n', 100 * minimum_efficiency);
fprintf('Maximum EE: %.2f %%\n', 100 * maximum_efficiency);
fprintf('Mean EE: %.2f %%\n', 100 * mean_efficiency);
fprintf('Optimum at %.6g (file index %d).\n', ...
    optimum_value, optimum_index - 1);

%% Plot
figure('Position', [100, 100, 900, 600]);
plot(sweep_values, 100 * extraction_efficiency, 'o-', ...
    'LineWidth', 2, 'MarkerSize', 8);
hold on
plot(optimum_value, 100 * maximum_efficiency, 'o', ...
    'MarkerSize', 9, ...
    'MarkerFaceColor', [0.9, 0.3, 0.2], ...
    'MarkerEdgeColor', [0.9, 0.3, 0.2]);
xline(optimum_value, '--', 'Color', [0.9, 0.3, 0.2], ...
    'LineWidth', 1.2);
text(optimum_value, 100 * maximum_efficiency, ...
    sprintf('  %.2f %%', 100 * maximum_efficiency), ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'bottom', ...
    'FontSize', 14, ...
    'Color', [0.9, 0.3, 0.2], ...
    'FontWeight', 'bold');
hold off

xlabel(sweep_label, 'FontSize', 20);
ylabel('Extraction efficiency (%)', 'FontSize', 20);
grid on
grid minor
box on

set(findall(gcf, '-property', 'FontName'), ...
    'FontName', 'Times New Roman');
axes_handle = gca;
axes_handle.FontSize = 18;
axes_handle.XLabel.FontSize = 20;
axes_handle.YLabel.FontSize = 20;

%% Export
if ~exist(results_root, 'dir')
    mkdir(results_root);
end

output_stub = sprintf('single_sweep_%s', output_id);
csv_path = fullfile(results_root, [output_stub '.csv']);
figure_path = fullfile(results_root, [output_stub '.fig']);
pdf_path = fullfile(results_root, [output_stub '.pdf']);

results_table = table(sweep_values(:), ...
    100 * extraction_efficiency(:), ...
    'VariableNames', {'SweepValue', 'ExtractionEfficiencyPercent'});
writetable(results_table, csv_path);
savefig(figure_path);
exportgraphics(gcf, pdf_path, 'ContentType', 'vector');

fprintf('\nSaved:\n  %s\n  %s\n  %s\n', ...
    csv_path, figure_path, pdf_path);

%% Local function: read an RSoft two-dimensional spatial monitor
function [power_density, x, y] = read_rsoft_spatial_monitor(file_path)
    file_id = fopen(file_path, 'r');
    if file_id == -1
        error('The file could not be opened.');
    end
    cleanup = onCleanup(@() fclose(file_id));

    first_line = fgetl(file_id); %#ok<NASGU>
    second_line = fgetl(file_id); %#ok<NASGU>
    x_metadata = sscanf(fgetl(file_id), '%f');
    y_metadata = sscanf(fgetl(file_id), '%f');

    if numel(x_metadata) < 3 || numel(y_metadata) < 3
        error('The spatial-monitor metadata are incomplete or malformed.');
    end

    nx = x_metadata(1);
    ny = y_metadata(1);
    if nx < 2 || ny < 2 || nx ~= fix(nx) || ny ~= fix(ny)
        error('The monitor dimensions must be integer values greater than one.');
    end

    x_min = x_metadata(2);
    x_max = x_metadata(3);
    y_min = y_metadata(2);
    y_max = y_metadata(3);

    raw_power = fscanf(file_id, '%f', [nx, ny]);
    if ~isequal(size(raw_power), [nx, ny])
        error('Incomplete grid: expected %d x %d values, read %d x %d.', ...
            nx, ny, size(raw_power, 1), size(raw_power, 2));
    end

    power_density = raw_power.';
    x = linspace(x_min, x_max, nx);
    y = linspace(y_min, y_max, ny);
end
