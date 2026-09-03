Fs     = 125.0e6;
HOrder = 40; % even value
NTaps  = HOrder + 1;
NBits  = 16; % adc res
NBanks = 2^7; % any radix-2 value up to NAddrs
Step   = (Fs/2)/NBanks;

%% create taps declaration
fid_taps = fopen('taps.txt', 'w');
for bank = 1:NBanks

    Rs = Step*bank;
    h  = fir1(HOrder,Rs/(Fs/2)-Step/Fs)';
    %figure; freqz(h)

    h_fx   = dec2hex(ceil(h*2^(NBits-1)-1),log2(NBits));

    coeffs = append(repmat(' ',4,1)', 'constant CoeffBank_', num2str(bank),' : CoeffArray(TAP_COUNT-1 downto 0) := (');
    for tap = 1:NTaps

        % newline every 10 for organization
        if tap ~= 1 && mod(tap,10) == 1
            coeffs = append(coeffs, newline, repmat(' ',64,1)');
        end

        coeffs = append(coeffs, '0x"', convertCharsToStrings(h_fx(tap,:)), '"');

        % last idx requires no comma
        if tap == NTaps
            coeffs = append(coeffs, ');');
        else
            coeffs = append(coeffs, ',');
        end
    end % i

    fprintf(fid_taps, '%s\n', coeffs);
end  % j
fclose(fid_taps);

%% create mux declaration
fid_mux = fopen('mux.txt', 'w');
for bank = 1:NBanks
    if bank == 1
        mux = append('  Coeffs <= ');
    else
        mux = append(repmat(' ',12,1)');
    end

    mux = append(mux, 'CoeffBank_', num2str(bank),' when SymbolRateFcw >= ', num2str(bank-1), '*BANK_STEP and SymbolRateFcw <= ', num2str(bank), '*BANK_STEP-1 else');

    fprintf(fid_mux, '%s\n', mux);
end  % j

mux = append(repmat(' ',12,1)', 'CoeffBank_', num2str(bank(end)), ';');
fprintf(fid_mux, '%s\n', mux);
fclose(fid_mux);