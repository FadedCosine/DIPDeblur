function iqm_configure(varargin)
    % IQM_CONFIGURE Configure Matlab search path and load various function handles.
    %   Need to be called every time Matlab starts up (for now).
    %% Parse arguments
    if nargin ~= 0
        do_test = logical(varargin{1});
    else
        do_test = false;
    end
    %% Add current folder to Matlab search path    
    %%% Turn off rmpath and mex compiler warning
    old_warning = warning('off');
    disp('Adding search path...');
    global iqm_path;
    [iqm_path, ~, ~] = fileparts(which(mfilename));
    rmpath(genpath(iqm_path));
    addpath(iqm_path);
    addpath(genpath(fullfile(iqm_path)));
    rmpath(fullfile(iqm_path, 'Utilities', 'libsvm-3.1'));
    savepath(); % just save them all...
    %% Compile SVM if necessary
    disp('Compiling LibSVM...');
    %%% SVM binaries to be used by some of the no-reference metrics.
    global iqm_svm_scale;
    global iqm_svm_predict;
    % global iqm_svm_train; % No training currently
    % .mex*64 will be automatically found since we added them to search path
    if ~ispc
        old_cd = cd(fullfile(iqm_path, 'Utilities', 'libsvm-3.1'));
        [status, output] = system('make');
        if status ~= 0
            error(output);
        end
        iqm_svm_scale = fullfile(cd, 'svm-scale');
        iqm_svm_predict = fullfile(cd, 'svm-predict');
        cd('matlab');
        make();
        cd(old_cd);
    else
        % svm-*.exe in Utilities/libsvm/windows/
        iqm_svm_scale = fullfile(iqm_path, 'Utilities', 'libsvm-3.1', 'windows', 'svm-scale.exe');
        iqm_svm_predict = fullfile(iqm_path, 'Utilities', 'libsvm-3.1', 'windows', 'svm-predict.exe');
    end
    %% Compile PyrTools to improve speed (and reduce warnings)
    disp('Compiling PyrTools...');
    old_cd = cd(fullfile(iqm_path, 'Utilities', 'matlabPyrTools', 'MEX'));
    compilePyrTools();
    delete ('../*.mex*');
    copyfile('*.mex*', '..'); % override those implementations in pure matlab
    cd(old_cd);
    %%% Restore warning
    warning(old_warning); 
    %% Initialize name-handle map
    names = ["MSE", "SNR", "PSNR", "WSNR", "SSIM", "MSSSIM", "VIF", "IFC", "NQM", "UIQI", ... <-FR
        "NIQE", "MDQE", "BLIINDS2", "BRISQUE", "DIIVINE", "SSEQ", "BIQI", "CORNIA"]; % <- NR
    global iqm_function_handles;
    iqm_function_handles = containers.Map;
    for name = names
        iqm_function_handles(char(name)) = eval(['@iqm_', lower(char(name))]);
    end
    %% Start parallel pool if none present
    if isempty(gcp('nocreate'))
        parpool(maxNumCompThreads);
    end
    %% Test metrics
    if do_test
        iqm_test();
    end
end

%% Metric bindings
%#ok<*DEFNU> %functions below are called through handles
% NOTE their arguments are preprocessed images with a dynamic range 0.0 ~ 1.0 (in double).

%%% Full-referenced ones

% These three are implemented trivially
function [MSE] = iqm_mse(img, img_ref)
    MSE = mean(mean2(((img - img_ref).*255).^2));
end

function [SNR] = iqm_snr(img, img_ref)
    [~, SNR] = psnr(img, img_ref, 1);
end

function [PSNR] = iqm_psnr(img, img_ref)
    [PSNR, ~] = psnr(img, img_ref, 1);
end

function [WSNR] = iqm_wsnr(img, img_ref)
%     global iqm_path;
%     module_name = 'NQM';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    WSNR = wsnr_new_modified(img_ref, img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [SSIM] = iqm_ssim(img, img_ref)
%     global iqm_path;
%     module_name = 'SSIM';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    SSIM = ssim_index(img_ref, img, [], [], 1.0);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [MSSSIM] = iqm_msssim(img, img_ref)
%     global iqm_path;
%     module_name = 'MSSSIM';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    MSSSIM = mssim_index(img_ref, img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [VIF] = iqm_vif(img, img_ref)
%     global iqm_path;
%     module_name = 'VIF';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    VIF = vifvec(img_ref, img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [IFC] = iqm_ifc(img, img_ref)
%     global iqm_path;
%     module_name = 'IFC';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    IFC = ifcvec(img_ref, img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [NQM] = iqm_nqm(img, img_ref)
%     global iqm_path;
%     module_name = 'NQM';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    % Viewing angle (in degrees) is determined based on the assumption that
    % the image is viewed at 3.5 picture heights away
    viewing_angle = 1/3.5 * 180 / pi;
    % Estimate the dimesion of the image with the geometric mean
    % of the horizonal and vertical dimensions
    dim = sqrt(numel(img_ref));
    NQM = nqm_modified(img_ref, img, viewing_angle, dim);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [UIQI] = iqm_uiqi(img, img_ref)
%     global iqm_path;
%     module_name = 'UIQI';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    UIQI = img_qi(img_ref, img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

%%% No-referenced ones

function [BLIINDS2] = iqm_bliinds2(img)
%     global iqm_path;
%     module_name = 'BLIINDS2';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    features = bliinds2_feature_extraction(img);
    BLIINDS2 = bliinds_prediction(features(:)');
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [NIQE] = iqm_niqe(img)
    global iqm_path;
%     module_name = 'NIQE';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    load(fullfile(iqm_path, 'NIQE', 'modelparameters.mat'), 'mu_prisparam', 'cov_prisparam');
    blocksizerow = 96;
    blocksizecol = 96;
    blockrowoverlap = 0;
    blockcoloverlap = 0;
    NIQE = computequality(img, blocksizerow, blocksizecol, blockrowoverlap, blockcoloverlap, ...
        mu_prisparam, cov_prisparam);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [MDQE] = iqm_mdqe(img_blurred, img_deblurred)
%     global iqm_path;
%     module_name = 'MDQE';
%     assert(size(img_blurred, 3) == 3);
%     assert(size(img_deblurred, 3) == 3);
%     assert(mean(mean2(img_blurred)) <= 1, sprintf('mean=%f\n', mean2(img_blurred)));
%     assert(mean(mean2(img_deblurred)) <= 1, sprintf('mean=%f\n', mean2(img_deblurred)));
%     addpath(genpath(fullfile(iqm_path, module_name)));
    MDQE = measure(img_deblurred, img_blurred);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [BRISQUE] = iqm_brisque(img)
%     global iqm_path;
%     module_name = 'BRISQUE';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    BRISQUE = brisquescore(img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [DIIVINE] = iqm_diivine(img)
%     global iqm_path;
%     module_name = 'DIIVINE';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    DIIVINE = divine(img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [SSEQ] = iqm_sseq(img)
%     global iqm_path;
%     module_name = 'SSEQ';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    SSEQ = sseq(img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [BIQI] = iqm_biqi(img)
%     global iqm_path;
%     module_name = 'BIQI';
%     addpath(genpath(fullfile(iqm_path, module_name)));
    BIQI = biqi(img);
%     rmpath(genpath(fullfile(iqm_path, module_name)));
end

function [CORNIA] = iqm_cornia(img)
    global iqm_path;
%     module_name = 'CORNIA';
%     old_cd = cd;
%     cd(fullfile(iqm_path, module_name));
    load(fullfile(iqm_path, 'CORNIA', 'CSIQ_codebook_BS7.mat'),'codebook0');
    load(fullfile(iqm_path, 'CORNIA', 'LIVE_soft_svm_model.mat'),'soft_model','soft_scale_param');
    load(fullfile(iqm_path, 'CORNIA', 'CSIQ_whitening_param.mat'),'M','P');
    CORNIA = cornia(img, codebook0, 'soft', soft_model, soft_scale_param, M, P, 10000);
%     cd(old_cd);
end

%{
function [] = iqm_(img)
    global iqm_path;
    module_name = '';
    addpath(genpath(fullfile(iqm_path, module_name)));
     = (img);
    rmpath(genpath(fullfile(iqm_path, module_name)));
end
%}
