%% CSD estimates for square-root-raised-cosine M-QAM waveforms

clear;
rng(11,'twister');

Nsymbols = 400;
Rs = 0.1;               % Symbol rate (MBd)
Fs = 1;                 % Sample rate (samples/us, numerically MHz)
fc = 0.05;              % Positive center frequency (MHz)
Nlags = 15;
Nfreqs = 128;
smoothing_length = 8;
alpha = 0:Rs:Fs/2;      % Cycle frequencies in MHz
Ncf = numel(alpha);

rolloff = 1;
span = 6;
SPS = Fs/Rs;
assert(abs(SPS-round(SPS)) < eps(Fs));
SPS = round(SPS);
h = rcosdesign(rolloff,span,SPS,'sqrt').';
f = (-Nfreqs/2:Nfreqs/2-1)*(Fs/Nfreqs);

[fig, colors] = thesis_figure();
layout = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
plot_colors = [colors.blue;colors.orange;colors.green;colors.purple];

for i = 1:4
    M = 2^i;

    d = randi([0 M-1],Nsymbols,1);
    syms_bb = qammod(d,M,'UnitAveragePower',true);
    syms_srrc = upfirdn(syms_bb,h,SPS);
    n = (0:numel(syms_srrc)-1)';
    syms_pb = syms_srrc.*exp(1j*2*pi*(fc/Fs)*n);
    syms_pb = syms_pb/sqrt(mean(abs(syms_pb).^2));
    assert(abs(mean(abs(syms_pb).^2)-1) < 1e-12);

    % Estimate the symmetric CAF without amplitude-normalizing away its
    % physical scale, then Fourier-transform along the lag dimension.
    Ra = zeros(Ncf,2*Nlags+1);
    for k = 1:Ncf
        half_shift = exp(-1j*pi*(alpha(k)/Fs)*n);
        Ra(k,:) = xcorr(syms_pb.*half_shift, ...
            syms_pb.*conj(half_shift),Nlags,'biased').';
    end
    % Embed lag zero, positive lags, and negative lags at their proper
    % circular indices before the longer DFT.  This preserves phase for
    % the complex frequency smoother that follows.
    Ra_padded = complex(zeros(Ncf,Nfreqs));
    Ra_padded(:,1:Nlags+1) = Ra(:,Nlags+1:end);
    Ra_padded(:,end-Nlags+1:end) = Ra(:,1:Nlags);
    CSD_raw = fftshift(fft(Ra_padded,[],2),2)/Fs;
    CSD = circular_movmean(CSD_raw,smoothing_length,2);

    [~,symbol_rate_index] = min(abs(alpha-Rs));
    [~,carrier_index] = max(abs(CSD(symbol_rate_index,:)));
    assert(abs(f(carrier_index)-fc) <= Fs/Nfreqs);

    ax = nexttile(layout);
    surface_handle = waterfall(ax,f,alpha,abs(CSD));
    set(surface_handle,'EdgeColor',plot_colors(i,:), ...
        'FaceColor','none','LineWidth',0.75);
    view(ax,225,20);
    title(ax,sprintf('%d-QAM-SRRC',M));
    xlabel(ax,'$f\ (\mathrm{MHz})$');
    ylabel(ax,'$\alpha\ (\mathrm{MHz})$');
    zlabel(ax,'$|\widehat{S}_{x}^{\alpha}(f)|$');
    xlim(ax,[f(1),f(end)]);
end

thesis_export(fig,'qam_srrc');
