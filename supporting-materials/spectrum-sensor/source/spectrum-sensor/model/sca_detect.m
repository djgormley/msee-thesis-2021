function sca_tuples = sca_detect(x, a_array, fc_array, Fs, beta)

% threshold
N = length(x);
sigma_4 = (sum(abs(x).^2)/N).^2;

threshold = beta*sigma_4;

% allocate memory for results
S = zeros(length(a_array),length(fc_array));
%h = [0.5, 0.5];
Ntaps = 4;
h = fir1(Ntaps,1/Ntaps);

%
% ESTIMATE
%
% search cycle freqs
% valid alpha range is [0 Fs/2]
for idx_a = 1:length(a_array)
  % search center freqs
  % valid alpha range is [-Fs/2 Fs/2]
  for idx_fc = 1:length(fc_array)
    % channelizer
    lo = exp(1j*2*pi*fc_array(idx_fc)/Fs*(1:N))';    
    channelized = filter(h,1,x.*lo);    

    % symbol rate estimation
    R = abs(channelized).^2;
    DFT = goertzel(R,round(a_array(idx_a)/Fs*N)+1)/N;
    S(idx_a,idx_fc) = abs(DFT).^2;
  end % fc
end % a

% plot S
figure(1)
waterfall(fc_array/1e6,a_array/1e6,S)
colormap([0 0 0])
view(225,15)
title('Estimate','interpreter','latex')
xlabel('$k$','interpreter','latex')
ylabel('$v$','interpreter','latex')
zlabel('$S_{x}^{v}[k]$','interpreter','latex')
set(gca,'TickLabelInterpreter','latex')

% plot threshold
hold on;
thresh_3d   = ones(length(a_array),length(fc_array))*threshold+S/Fs; % create 3D threshold
p           = waterfall(fc_array/1e6,a_array/1e6,thresh_3d);
p.EdgeColor = 'r';
legend('$S_{x}^{R_{s}}(f_{c})$','$\gamma$','interpreter', 'latex')
hold off

%
% DETECT
%
sca_tuples = [];
for idx_a = 1:length(a_array)
    [fc_candidate, idx_fc] = max(S(idx_a,:));
    if fc_candidate >= threshold
        sca_tuples = [sca_tuples; [idx_a, idx_fc, fc_candidate]];
    end
end