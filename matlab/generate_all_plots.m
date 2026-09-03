function generated_files = generate_all_plots(output_directory)
%GENERATE_ALL_PLOTS Rebuild every MATLAB-generated thesis figure.
%
% Figures are generated into a temporary staging directory.  The complete
% set and every image dimension are validated before any committed plot is
% replaced.  The manifest below is the single inventory of generators,
% random seeds, and expected output files.

arguments
    output_directory (1,1) string = ""
end

matlab_directory = string(fileparts(mfilename('fullpath')));
repository_directory = fileparts(matlab_directory);
if strlength(output_directory) == 0
    output_directory = fullfile(repository_directory,'images','plots');
end

manifest = figure_manifest();
staging_directory = string(tempname);
mkdir(staging_directory);
staging_cleanup = onCleanup(@() remove_staging_directory(staging_directory));

for generator_index = 1:numel(manifest)
    entry = manifest(generator_index);
    fprintf('Generating %s ...\n',entry.Name);
    if isnan(entry.Seed)
        reported_paths = entry.Generator(staging_directory);
    else
        stream = RandStream('mt19937ar','Seed',entry.Seed);
        reported_paths = entry.Generator(staging_directory,stream);
    end
    validate_generator_outputs(entry,reported_paths,staging_directory);
end

expected_names = sort([manifest.Outputs]);
staged_files = dir(fullfile(staging_directory,'*.png'));
staged_names = sort(string({staged_files.name}));
assert(isequal(staged_names,expected_names), ...
    'generate_all_plots:UnexpectedOutputSet', ...
    'The staged PNG set does not exactly match the figure manifest.');

if ~isfolder(output_directory)
    mkdir(output_directory);
end
generated_files = strings(size(expected_names));
for output_index = 1:numel(expected_names)
    source_path = fullfile(staging_directory,expected_names(output_index));
    destination_path = fullfile(output_directory,expected_names(output_index));
    [was_copied,message] = copyfile(source_path,destination_path,'f');
    assert(was_copied, ...
        'generate_all_plots:PromotionFailed', ...
        'Could not promote %s: %s',expected_names(output_index),message);
    generated_files(output_index) = destination_path;
end

remove_staging_directory(staging_directory);
fprintf('Generated and validated %d thesis plots in %s.\n', ...
    numel(generated_files),output_directory);
end

function manifest = figure_manifest()
manifest = struct( ...
    'Name',{},'Generator',{},'Seed',{},'Outputs',{});
manifest(end+1) = entry("Gaussian density", ...
    @thesis.figures.gaussian_pdf,NaN,"gaussian_pdf.png");
manifest(end+1) = entry("Gaussian sample path", ...
    @thesis.figures.random_signal_parameters,0,"X_mean_std.png");
manifest(end+1) = entry("Rectangular-pulse 2-QAM views", ...
    @thesis.figures.rectangular_qam,7, ...
    ["2qam_time.png","autocorrelogram.png","periodogram.png", ...
    "psd.png","cyclic_autocorrelogram.png","scf.png"]);
manifest(end+1) = entry("Rectangular-pulse energy density", ...
    @thesis.figures.energy_spectral_density,NaN,"esd.png");
manifest(end+1) = entry("M-QAM-SRRC comparison", ...
    @thesis.figures.qam_srrc,11,"qam_srrc.png");
manifest(end+1) = entry("Spectrum occupancy", ...
    @thesis.figures.spectrum_occupancy,NaN,"spectrum_sensing.png");
manifest(end+1) = entry("Binary decision regions", ...
    @thesis.figures.binary_detection,NaN,"error_probabilities.png");
manifest(end+1) = entry("SCF threshold detector", ...
    @thesis.figures.scf_detection,2021,"threshold_3d.png");
manifest(end+1) = entry("Streaming SCA detector", ...
    @thesis.figures.streaming_sca_detection,20210901,"qam_srrc_rs.png");
end

function value = entry(name,generator,seed,outputs)
value = struct('Name',name,'Generator',generator, ...
    'Seed',seed,'Outputs',outputs);
end

function validate_generator_outputs(entry,reported_paths,staging_directory)
reported_paths = string(reported_paths);
[~,reported_names,reported_extensions] = fileparts(reported_paths);
reported_names = sort(reported_names+reported_extensions);
expected_names = sort(entry.Outputs);
assert(isequal(reported_names,expected_names), ...
    'generate_all_plots:GeneratorOutputMismatch', ...
    '%s did not report exactly its manifest outputs.',entry.Name);

for output_name = entry.Outputs
    output_path = fullfile(staging_directory,output_name);
    assert(isfile(output_path), ...
        'generate_all_plots:MissingOutput', ...
        '%s did not produce %s.',entry.Name,output_name);
    metadata = imfinfo(output_path);
    assert(metadata.Width == 1600 && metadata.Height == 960, ...
        'generate_all_plots:IncorrectDimensions', ...
        '%s is %d-by-%d instead of 1600-by-960.', ...
        output_name,metadata.Width,metadata.Height);
end
end

function remove_staging_directory(staging_directory)
if isfolder(staging_directory)
    rmdir(staging_directory,'s');
end
end
