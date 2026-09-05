clearvars
close all

%% Double-parameter extraction-efficiency sweep
% Post-processes RSoft spatial-monitor files for simulations in which two
% parameters are varied simultaneously. The script generates an extraction-
% efficiency map and identifies the joint optimum.

%% Paths
script_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(script_dir);
data_root = fullfile(repo_root, 'data');
results_root = fullfile(repo_root, 'results', 'double_parameter');

% Edit these values to match the RSoft simulation output.
simulation_folder = '2dscan_DcxP_v1f_work';
tag = '2dscan_DcxP_v1f';
monitor = 'm13';
frequency = 'f1';

work_dir = fullfile(data_root, simulation_folder);

%% Sweep configuration
% Parameter 1 corresponds to the first file index; parameter 2 corresponds
% to the second. Their order must match the RSoft MOST sweep definition.
parameter_1 = 0.95:0.04:1.35;
parameter_1_label = 'Period (\mum)';
parameter_1_tag = 'P';

parameter_2 = 0.4:0.03:0.7;
parameter_2_label = 'Central-disk diameter (\mum)';
parameter_2_tag = 'D_C';

% Example for a period--fill-factor sweep:
% parameter_1 = 0.95:0.04:1.35;
% parameter_1_label = 'Period (\mum)';
% parameter_1_tag = 'P';
% parameter_2 = 0.3:0.05:0.7;
% parameter_2_label = 'Fill factor';
% parameter_2_tag = 'FF';

symmetry_factor = input(['Enter the symmetry factor (1: full structure, ' ...
    '2: half, 4: quarter, 8: octant): ']);
validateattributes(symmetry_factor, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'});

num_parameter_1 = numel(parameter_1);
num_parameter_2 = numel(parameter_2);
efficiency_map = nan(num_parameter_2, num_parameter_1);
successful_files = 0;
failed_files = 0;

fprintf('Parameter 1 (%s): %d points\n', ...
    parameter_1_tag, num_parameter_1);
fprintf('Parameter 2 (%s): %d points\n', ...
    parameter_2_tag, num_parameter_2);
fprintf('Total combinations: %d\n\n', ...
    num_parameter_1 * num_parameter_2);

%% Process monitor files
for index_1 = 1:num_parameter_1
    for index_2 = 1:num_parameter_2
        filename = sprintf('%s_%d_%d_%s_%s_pow.dat', ...
            tag, index_1 - 1, index_2 - 1, monitor, frequency);
        file_path = fullfile(work_dir, filename);

        if ~isfile(file_path)
            warning('File not found: %s. The corresponding result is NaN.', ...
                filename);
            failed_files = failed_files + 1;
            continue
        end

        try
            [power_density, x, y] = read_rsoft_spatial_monitor(file_path);
        catch exception
            warning('Could not process %s: %s. The result is NaN.', ...
                filename, exception.message);
            failed_files = failed_files + 1;
            continue
        end

        [X, Y] = meshgrid(x, y);
        aperture_radius = max(abs([x(1), x(end), y(1), y(end)]));
        circular_mask = (X.^2 + Y.^2) <= aperture_radius^2;

        dx = abs(x(2) - x(1));
        dy = abs(y(2) - y(1));
        efficiency_map(index_2, index_1) = symmetry_factor ...
            * sum(power_density(circular_mask), 'omitnan') * dx * dy;

        successful_files = successful_files + 1;
        fprintf('[%s = %.6g, %s = %.6g] EE = %.2f %%\n', ...
            parameter_1_tag, parameter_1(index_1), ...
            parameter_2_tag, parameter_2(index_2), ...
            100 * efficiency_map(index_2, index_1));
    end
end

fprintf('\nProcessed files: %d; missing or invalid files: %d\n', ...
    successful_files, failed_files);
if successful_files == 0
    error(['No monitor file was processed. Check data_root, ' ...
        'simulation_folder, tag, monitor and frequency.']);
end

%% Results
[maximum_efficiency, linear_index] = max( ...
    efficiency_map(:), [], 'omitnan');
[row_index, column_index] = ind2sub(size(efficiency_map), linear_index);
optimum_parameter_1 = parameter_1(column_index);
optimum_parameter_2 = parameter_2(row_index);
minimum_efficiency = min(efficiency_map(:), [], 'omitnan');
mean_efficiency = mean(efficiency_map(:), 'omitnan');

fprintf('\nMinimum EE: %.2f %%\n', 100 * minimum_efficiency);
fprintf('Maximum EE: %.2f %%\n', 100 * maximum_efficiency);
fprintf('Mean EE: %.2f %%\n', 100 * mean_efficiency);
fprintf('Optimum at %s = %.6g and %s = %.6g.\n', ...
    parameter_1_tag, optimum_parameter_1, ...
    parameter_2_tag, optimum_parameter_2);

%% Plot
[parameter_grid_1, parameter_grid_2] = meshgrid( ...
    parameter_1, parameter_2);

figure('Position', [100, 100, 700, 480]);
contourf(parameter_grid_1, parameter_grid_2, ...
    100 * efficiency_map, 20, 'LineColor', 'none');
hold on
plot(optimum_parameter_1, optimum_parameter_2, 'o', ...
    'MarkerSize', 9, ...
    'MarkerFaceColor', 'w', ...
    'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.2);
hold off

colormap(autumn);
colour_bar = colorbar;
colour_bar.Label.String = 'Extraction efficiency (%)';
xlabel(parameter_1_label);
ylabel(parameter_2_label);
title(sprintf('EE_{max} = %.2f %% at (%.4g, %.4g)', ...
    100 * maximum_efficiency, optimum_parameter_1, optimum_parameter_2));
axis tight
box on

set(findall(gcf, '-property', 'FontName'), ...
    'FontName', 'Times New Roman');
axes_handle = gca;
axes_handle.FontSize = 14;
axes_handle.XLabel.FontSize = 16;
axes_handle.YLabel.FontSize = 16;

%% Export
if ~exist(results_root, 'dir')
    mkdir(results_root);
end

output_stub = sprintf('double_sweep_%s_vs_%s', ...
    parameter_1_tag, parameter_2_tag);
csv_path = fullfile(results_root, [output_stub '.csv']);
figure_path = fullfile(results_root, [output_stub '.fig']);
pdf_path = fullfile(results_root, [output_stub '.pdf']);

column_names = cell(1, num_parameter_1);
for index = 1:num_parameter_1
    column_names{index} = matlab.lang.makeValidName( ...
        sprintf('%s_%.4f', parameter_1_tag, parameter_1(index)));
end

row_names = cell(num_parameter_2, 1);
for index = 1:num_parameter_2
    row_names{index} = matlab.lang.makeValidName( ...
        sprintf('%s_%.4f', parameter_2_tag, parameter_2(index)));
end

results_table = array2table(100 * efficiency_map, ...
    'VariableNames', column_names, 'RowNames', row_names);
writetable(results_table, csv_path, 'WriteRowNames', true);
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
