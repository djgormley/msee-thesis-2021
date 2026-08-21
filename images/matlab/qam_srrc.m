clear

% Initialize Parameters
Nbits  = 400;
Rs     = 0.1;
Ts     = 1/Rs;
Fs     = 1.0;
fc     = 0.05;
Nlags  = 15;
Nfreqs = 128;
alpha  = (0:Rs:Fs/2)/Fs;
Ncf    = length(alpha);

Rolloff = 1.0;
span    = 6;
SPS     = Fs/Rs;
h       = rcosdesign(Rolloff,span,SPS)';

Nsyms = Nbits*SPS+length(h)-SPS;
n     = (0:Nsyms-1)';
lo    = exp(-1j*2*pi*fc/Fs*n);
%% 
% M-QAM

Ni = 4;
for i = 1:Ni
    M = 2^i;
    
    % generate mod syms
    d = randi([0 M-1],Nbits,1);
    syms_bb = qammod(d,M);
    syms_srrc = upfirdn(syms_bb,h,SPS);
    syms_pb = syms_srrc.*lo;

    % normalize such that the peak tx power is mag 1
    norm_factor = modnorm(syms_pb,'peakpow',1);
    syms_pb     = syms_pb*norm_factor;
    
    % calc scf
    Sa = zeros(Ncf,Nfreqs);
    Saf = (-Nfreqs/2:Nfreqs/2-1)'*(Fs/Nfreqs);
    
    for k = 1:Ncf
        % Symmetric half-alpha shifts (Optimized)
        kernel_A = exp(-1j * pi * alpha(k) / Fs * n);
        Ra = xcorr(syms_pb .* kernel_A, syms_pb .* conj(kernel_A), Nlags, 'normalized');    
        
        % Calculate complex spectrum (abs removed)
        Sa(k,:) = fftshift(fft(Ra, Nfreqs));
    end

    subplot(Ni-2,2,i)
    % Take absolute magnitude here for visualization
    waterfall(Saf,alpha,abs(Sa));
    colormap([0 0 0])
    view(225,15)
    title([num2str(M) '-QAM-SRRC'],'interpreter','latex')
    xlabel('$f \: (MHz)$','interpreter','latex')
    ylabel('$\alpha \: (MHz)$','interpreter','latex')
    zlabel('$S_{x}^{\alpha}(f)$','interpreter','latex')
    set(gca,'TickLabelInterpreter','latex')
end
print('../plots/qam_srrc', '-dpng')