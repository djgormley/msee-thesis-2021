%% SCF estimates for square-root-raised-cosine M-QAM waveforms

clear;
rng(11,'twister');

Nsymbols = 4000;
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
modulation_orders = 2.^(1:4);
expected_symbol_variances = [1,2,6,10];
symbol_variances = zeros(size(modulation_orders));
scf_peaks = zeros(size(modulation_orders));
axes_handles = gobjects(size(modulation_orders));

for i = 1:numel(modulation_orders)
    M = modulation_orders(i);

    % Use every constellation point equally often so that the finite record
    % has the exact symbol variance of a minimum-distance-two constellation.
    d = repmat((0:M-1).',Nsymbols/M,1);
    d = d(randperm(Nsymbols));
    syms_bb = qammod(d,M,'UnitAveragePower',false);
    reference_constellation = qammod((0:M-1).',M, ...
        'UnitAveragePower',false);
    symbol_variances(i) = mean(abs(reference_constellation).^2);
    assert(abs(symbol_variances(i)-expected_symbol_variances(i)) < ...
        100*eps(expected_symbol_variances(i)));
    assert(abs(mean(abs(syms_bb).^2)-symbol_variances(i)) < ...
        100*eps(symbol_variances(i)));

    syms_srrc = upfirdn(syms_bb,h,SPS);
    n = (0:numel(syms_srrc)-1)';
    syms_pb = syms_srrc.*exp(1j*2*pi*(fc/Fs)*n);

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
    SCF_raw = fftshift(fft(Ra_padded,[],2),2)/Fs;
    SCF = circular_movmean(SCF_raw,smoothing_length,2);
    scf_peaks(i) = max(abs(SCF),[],'all');

    [~,symbol_rate_index] = min(abs(alpha-Rs));
    [~,carrier_index] = max(abs(SCF(symbol_rate_index,:)));
    assert(abs(f(carrier_index)-fc) <= Fs/Nfreqs);

    ax = nexttile(layout);
    axes_handles(i) = ax;
    surface_handle = waterfall(ax,f,alpha,abs(SCF));
    set(surface_handle,'EdgeColor',plot_colors(i,:), ...
        'FaceColor','none','LineWidth',0.75);
    view(ax,225,20);
    title(ax,sprintf('%d-QAM-SRRC',M));
    xlabel(ax,'$f\ (\mathrm{MHz})$');
    ylabel(ax,'$\alpha\ (\mathrm{MHz})$');
    zlabel(ax,'$|\widehat{S}_{x}^{\alpha}(f)|$');
    xlim(ax,[f(1),f(end)]);
end

% Use one vertical scale so that the sigma_a^2 amplitude dependence remains
% visible instead of being hidden by independent subplot autoscaling.
shared_zmax = 1.05*max(scf_peaks);
for i = 1:numel(axes_handles)
    zlim(axes_handles(i),[0,shared_zmax]);
end

normalized_peaks = scf_peaks./symbol_variances;
assert(max(abs(normalized_peaks/mean(normalized_peaks)-1)) < 0.08, ...
    'The SCF shapes do not exhibit the expected symbol-variance scaling.');
fprintf('Symbol variances:');
fprintf(' %.6f',symbol_variances);
fprintf('\nSCF peaks:');
fprintf(' %.6f',scf_peaks);
fprintf('\nSCF peak / symbol variance:');
fprintf(' %.6f',normalized_peaks);
fprintf('\n');

thesis_export(fig,'qam_srrc');
