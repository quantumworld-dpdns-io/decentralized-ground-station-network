using Test
using DGSN_SignalProcessing

@testset "DSP Filters" begin
    @testset "FIR filter design" begin
        fs = 1000.0
        filt = DGSN_SignalProcessing.dsp.filters.fir_design(100.0, fs=fs, order=32, filter_type=:lowpass)
        @test filt isa DGSN_SignalProcessing.dsp.filters.FIRFilter
        @test length(filt.taps) == 33
        @test filt.order == 32
    end

    @testset "IIR filter design" begin
        fs = 1000.0
        filt = DGSN_SignalProcessing.dsp.filters.iir_design(100.0, fs=fs, order=4, design_method=:butter)
        @test filt isa DGSN_SignalProcessing.dsp.filters.IIRFilter
        @test filt.order == 4
    end

    @testset "Lowpass filter" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 50 .* t) + sin.(2π * 200 .* t)
        filtered = DGSN_SignalProcessing.dsp.filters.lowpass_filter(signal, 100.0, fs, order=64)
        @test length(filtered) == length(signal)
        @test maximum(abs.(filtered)) <= maximum(abs.(signal)) + 0.1
    end

    @testset "Highpass filter" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 50 .* t) + sin.(2π * 200 .* t)
        filtered = DGSN_SignalProcessing.dsp.filters.highpass_filter(signal, 100.0, fs, order=64)
        @test length(filtered) == length(signal)
    end

    @testset "Bandpass filter" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 50 .* t) + sin.(2π * 200 .* t)
        filtered = DGSN_SignalProcessing.dsp.filters.bandpass_filter(signal, 40.0, 60.0, fs, order=64)
        @test length(filtered) == length(signal)
    end

    @testset "Notch filter" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 50 .* t) + sin.(2π * 60 .* t)
        filtered = DGSN_SignalProcessing.dsp.filters.notch_filter(signal, 60.0, fs, q_factor=30.0)
        @test length(filtered) == length(signal)
    end

    @testset "Matched filter" begin
        template = [1.0, 0.0, -1.0, 0.0]
        signal = vcat(zeros(10), template, zeros(10))
        result = DGSN_SignalProcessing.dsp.filters.matched_filter(signal, template)
        @test length(result) == length(signal) + length(template) - 1
        @test maximum(abs.(result)) > 0
    end

    @testset "Adaptive filter" begin
        n = 200
        signal = randn(n)
        desired = signal .+ 0.1 * randn(n)
        output, error, w = DGSN_SignalProcessing.dsp.filters.adaptive_filter(signal, desired, mu=0.01, order=16)
        @test length(output) == n
        @test length(error) == n
    end

    @testset "Butterworth filter" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 50 .* t)
        filtered = DGSN_SignalProcessing.dsp.filters.butterworth_filter(signal, 100.0, fs, order=4)
        @test length(filtered) == length(signal)
    end

    @testset "Wiener filter" begin
        signal = randn(100)
        noise = randn(100) * 0.1
        noisy = signal .+ noise
        filtered = DGSN_SignalProcessing.dsp.filters.wiener_filter(noisy, noise)
        @test length(filtered) == length(signal)
    end

    @testset "Kalman filter" begin
        n = 100
        signal = cumsum(randn(n))
        filtered = DGSN_SignalProcessing.dsp.filters.kalman_filter(signal, 0.01)
        @test length(filtered) == n
    end
end

@testset "DSP FFT Analysis" begin
    @testset "Window functions" begin
        n = 256
        hamming = DGSN_SignalProcessing.dsp.fft_analysis.window_function(n, DGSN_SignalProcessing.dsp.fft_analysis.HammingWindow())
        @test length(hamming) == n
        @test all(hamming .>= 0)

        hann = DGSN_SignalProcessing.dsp.fft_analysis.window_function(n, DGSN_SignalProcessing.dsp.fft_analysis.HannWindow())
        @test length(hann) == n
    end

    @testset "Spectrum computation" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 100 .* t)
        freqs, mag = DGSN_SignalProcessing.dsp.fft_analysis.compute_spectrum(signal, fs, nfft=1024)
        @test length(freqs) == 513
        @test length(mag) == 513
        peak_idx = argmax(mag)
        @test abs(freqs[peak_idx] - 100) < 10
    end

    @testset "Spectrogram" begin
        fs = 1000.0
        t = 0:1/fs:2-1/fs
        signal = sin.(2π * 100 .* t)
        freqs, spec = DGSN_SignalProcessing.dsp.fft_analysis.compute_spectrogram(signal, fs, nfft=256, noverlap=128)
        @test length(freqs) > 0
        @test size(spec, 2) > 0
    end

    @testset "Find peaks" begin
        freqs = 1:100
        spectrum = abs.(sin.(0.1 .* freqs))
        peaks = DGSN_SignalProcessing.dsp.fft_analysis.find_peaks(spectrum, freqs, min_height=0.1, n_peaks=5)
        @test length(peaks) <= 5
    end

    @testset "STFT" begin
        fs = 1000.0
        t = 0:1/fs:1-1/fs
        signal = sin.(2π * 100 .* t)
        times, freqs, stft_mat = DGSN_SignalProcessing.dsp.fft_analysis.stft(signal, fs, nfft=512, window_length=128, noverlap=64)
        @test length(freqs) > 0
        @test size(stft_mat, 2) > 0
    end

    @testset "Cepstrum" begin
        signal = randn(256)
        cepstrum = DGSN_SignalProcessing.dsp.fft_analysis.compute_cepstrum(signal)
        @test length(cepstrum) == 256
    end

    @testset "Autocorrelation" begin
        signal = randn(100)
        lags, acf = DGSN_SignalProcessing.dsp.fft_analysis.compute_autocorrelation(signal, max_lag=20)
        @test length(lags) == 21
        @test acf[1] ≈ 1.0 atol=0.01
    end
end

@testset "DSP Modulation" begin
    @testset "PSK modulation" begin
        symbols = [0, 1, 2, 3]
        signal = DGSN_SignalProcessing.dsp.modulation.modulate_psk(symbols, 1000.0, 10000.0, symbol_rate=100.0, order=4)
        @test length(signal) > 0
    end

    @testset "QAM modulation" begin
        symbols = [1+im, -1+im, -1-im, 1-im]
        signal = DGSN_SignalProcessing.dsp.modulation.modulate_qam(symbols, 1000.0, 10000.0, symbol_rate=100.0)
        @test length(signal) > 0
    end

    @testset "ASK modulation" begin
        symbols = [0, 1, 0, 1]
        signal = DGSN_SignalProcessing.dsp.modulation.modulate_ask(symbols, 1000.0, 10000.0, symbol_rate=100.0)
        @test length(signal) > 0
    end

    @testset "FSK modulation" begin
        symbols = [0, 1, 0, 1]
        signal = DGSN_SignalProcessing.dsp.modulation.modulate_fsk(symbols, 1000.0, 10000.0, symbol_rate=100.0, freq_deviation=200.0)
        @test length(signal) > 0
    end

    @testset "Constellation generation" begin
        psk = DGSN_SignalProcessing.dsp.modulation.psk_constellation(4)
        @test length(psk) == 4
        @test all(abs.(psk) .≈ 1.0)

        qam = DGSN_SignalProcessing.dsp.modulation.qam_constellation(16)
        @test length(qam) == 16
    end
end

@testset "Doppler" begin
    @testset "Doppler estimation (FFT method)" begin
        fs = 10000.0
        t = 0:1/fs:0.1-1/fs
        signal = exp.(2π * im * 100 .* t) .+ 0.1 * randn(Complex{Float64}, length(t))
        est = DGSN_SignalProcessing.dsp.doppler.estimate_doppler_shift(signal, fs, method=:fft)
        @test est isa DGSN_SignalProcessing.dsp.doppler.DopplerEstimate
        @test est.confidence > 0
    end

    @testset "Doppler correction" begin
        fs = 10000.0
        t = 0:1/fs:0.1-1/fs
        signal = exp.(2π * im * 100 .* t)
        est = DGSN_SignalProcessing.dsp.doppler.DopplerEstimate(100.0, 0.0, 1.0, "test")
        corrected = DGSN_SignalProcessing.dsp.doppler.correct_doppler_shift(signal, fs, est)
        @test length(corrected) == length(signal)
    end
end

@testset "Synchronization" begin
    @testset "Preamble detection" begin
        preamble = [1+im, -1-im, 1+im, -1-im]
        signal = vcat(zeros(10), preamble, zeros(10))
        result = DGSN_SignalProcessing.dsp.synchronization.preamble_detection(signal, preamble, threshold=0.1)
        @test result.preamble_found == true
        @test result.frame_start >= 8 && result.frame_start <= 12
    end

    @testset "Frame sync" begin
        sync_word = [1, 0, 1, 0, 1, 0, 1, 0]
        signal = vcat(zeros(20), Float64.(sync_word), zeros(20))
        result = DGSN_SignalProcessing.dsp.synchronization.frame_sync(signal, sync_word, threshold=0.1)
        @test result.preamble_found == true
    end
end
