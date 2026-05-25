### A Pluto.jl notebook ###
# v0.19.0

using Markdown
using InteractiveUtils

# ╔═╡ 4d2d5e60-5f1a-11ec-8f20-1b9c3a7e5f8a
begin
    using DGSN_SignalProcessing
    using Plots
    using Statistics
    using Random
    using DSP
end

# ╔═╡ 7a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d
md"""
# DGSN Signal Exploration Notebook
Interactive exploration of signal processing capabilities.
"""

# ╔═╡ 8b2c3d4e-5f6a-7b8c-9d0e-1f2a3b4c5d6e
md"""
## 1. Generate Test Signal
Create a synthetic QPSK signal for analysis.
"""

# ╔═╡ 9c3d4e5f-6a7b-8c9d-0e1f-2a3b4c5d6e7f
begin
    fs = 10_000.0
    symbol_rate = 100.0
    carrier_freq = 1000.0
    num_symbols = 64

    symbols = rand(0:3, num_symbols)
    tx_signal = DGSN_SignalProcessing.dsp.modulation.modulate_psk(
        symbols, carrier_freq, fs, symbol_rate=symbol_rate, order=4
    )

    noise_power = 0.05
    noise = sqrt(noise_power) * randn(length(tx_signal))
    rx_signal = tx_signal .+ noise

    t = (0:length(rx_signal)-1) / fs
    md"Generated QPSK signal with SNR ≈ $(round(10 * log10(var(tx_signal) / noise_power), digits=1)) dB"
end

# ╔═╡ ad4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7f8a
begin
    time_plot = plot(t[1:500], real(rx_signal[1:500]),
                     label="Received Signal (Real)", xlabel="Time (s)", ylabel="Amplitude",
                     title="Time Domain", legend=:topright)
    time_plot
end

# ╔═╡ be5f6a7b-8c9d-0e1f-2a3b-4c5d6e7f8a9b
md"""
## 2. Spectrum Analysis
"""

# ╔═╡ cf6a7b8c-9d0e-1f2a-3b4c-5d6e7f8a9b0c
begin
    freqs, mag = DGSN_SignalProcessing.dsp.fft_analysis.compute_spectrum(
        rx_signal, fs, nfft=2048
    )

    spec_plot = plot(freqs, 20 * log10.(mag .+ eps()),
                     label="Power Spectrum", xlabel="Frequency (Hz)",
                     ylabel="Magnitude (dB)", title="Power Spectrum",
                     xlim=(0, fs/2), legend=:topright)
    spec_plot
end

# ╔═╡ d07a8b9c-0d1e-2f3a-4b5c-6d7e8f9a0b1c
md"""
## 3. Spectrogram (Waterfall)
"""

# ╔═╡ e18b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d
begin
    spec_freqs, spec_data = DGSN_SignalProcessing.dsp.fft_analysis.compute_spectrogram(
        rx_signal, fs, nfft=256, noverlap=128
    )

    specgram_plot = heatmap(
        1:size(spec_data, 2), spec_freqs,
        20 * log10.(spec_data .+ eps()),
        xlabel="Time Frame", ylabel="Frequency (Hz)",
        title="Spectrogram", color=:turbo
    )
    specgram_plot
end

# ╔═╡ f29c0d1e-2f3a-4b5c-6d7e-8f9a0b1c2d3e
md"""
## 4. Filtering Example
"""

# ╔═╡ a30d1e2f-3a4b-5c6d-7e8f-9a0b1c2d3e4f
begin
    filtered_signal = DGSN_SignalProcessing.dsp.filters.bandpass_filter(
        rx_signal, carrier_freq - 200, carrier_freq + 200, fs, order=128
    )

    filt_plot = plot(t[1:500], real(filtered_signal[1:500]),
                     label="Filtered Signal", xlabel="Time (s)",
                     ylabel="Amplitude", title="Bandpass Filtered Signal",
                     legend=:topright)
    filt_plot
end

# ╔═╡ b41e2f3a-4b5c-6d7e-8f9a-0b1c2d3e4f5a
md"""
## 5. Peak Detection
"""

# ╔═╡ c52f3a4b-5c6d-7e8f-9a0b-1c2d3e4f5a6b
begin
    fft_freqs, fft_mag = DGSN_SignalProcessing.dsp.fft_analysis.compute_spectrum(
        rx_signal, fs, nfft=4096
    )
    peaks = DGSN_SignalProcessing.dsp.fft_analysis.find_peaks(
        fft_mag, fft_freqs, min_height=maximum(fft_mag) * 0.1, n_peaks=5
    )

    peak_plot = plot(fft_freqs, 20 * log10.(fft_mag .+ eps()),
                     label="Spectrum", xlabel="Frequency (Hz)",
                     ylabel="Magnitude (dB)", title="Peak Detection",
                     legend=:topright, xlim=(0, fs/2))
    scatter!(peak_plot, [p[1] for p in peaks],
             20 * log10.([p[2] for p] .+ eps()),
             label="Peaks", markershape=:circle, color=:red)
    peak_plot
end

# ╔═╡ d63a4b5c-6d7e-8f9a-0b1c-2d3e4f5a6b7c
md"""
## 6. Modulation Classification
"""

# ╔═╡ e74b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d
begin
    scheme, scores = DGSN_SignalProcessing.dsp.modulation.classify_modulation(
        Complex{Float32}.(rx_signal), fs
    )

    score_names = [s[1] for s in scores]
    score_vals = [s[2] for s in scores]

    class_plot = bar(score_names[1:6], score_vals[1:6],
                     label="Modulation Scores", xlabel="Scheme",
                     ylabel="Score", title="Modulation Classification: $scheme",
                     legend=false)
    class_plot
end

# ╔═╡ f85c6d7e-8f9a-0b1c-2d3e-4f5a6b7c8d9e
md"""
## 7. Feature Extraction for ML
"""

# ╔═╡ a96d7e8f-9a0b-1c2d-3e4f-5a6b7c8d9e0f
begin
    extractor = DGSN_SignalProcessing.ml.classifier.FeatureExtractor(
        num_cumulants=6, num_spectral_features=8,
        num_statistical_features=10, num_wavelet_features=4
    )
    fv = DGSN_SignalProcessing.ml.classifier.extract_all_features(
        Complex{Float32}.(rx_signal), extractor
    )

    feat_plot = bar(1:length(fv.features), fv.features,
                    label="Feature Values", xlabel="Feature Index",
                    ylabel="Value", title="Extracted Features",
                    legend=false)
    feat_plot
end

# ╔═╡ b07e8f9a-0b1c-2d3e-4f5a-6b7c8d9e0f1a
md"""
## 8. Pulse Shaping with Raised Cosine
"""

# ╔═╡ c18f9a0b-1c2d-3e4f-5a6b-7c8d9e0f1a2b
begin
    pulse = DGSN_SignalProcessing.dsp.filters.design_pulse_shape(
        symbol_rate, fs, rolloff=0.35, span=8
    )

    pulse_plot = plot(pulse, label="Raised Cosine Pulse",
                      xlabel="Sample", ylabel="Amplitude",
                      title="Pulse Shaping Filter",
                      legend=:topright)
    pulse_plot
end

# ╔═╡ d29a0b1c-2d3e-4f5a-6b7c-8d9e0f1a2b3c
md"""
## 9. Signal Statistics
"""

# ╔═╡ e3a0b1c2-3d4e-5f6a-7b8c-9d0e1f2a3b4c
begin
    stats_md = md"""
    | Metric | Value |
    |--------|-------|
    | Length | $(length(rx_signal)) samples |
    | Sample Rate | $(fs) Hz |
    | Duration | $(length(rx_signal) / fs) s |
    | Mean Amplitude | $(round(mean(abs.(rx_signal)), digits=4)) |
    | Std Amplitude | $(round(std(abs.(rx_signal)), digits=4)) |
    | Max Amplitude | $(round(maximum(abs.(rx_signal)), digits=4)) |
    | SNR Estimate | $(round(DGSN_SignalProcessing.dsp.fft_analysis.compute_snr(var(tx_signal), noise_power), digits=1)) dB |
    | Crest Factor | $(round(maximum(abs.(rx_signal)) / (mean(abs.(rx_signal)) + eps()), digits=2)) |
    """
    stats_md
end

# ╔═╡ f4a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c
md"""
## 10. Pipeline Processing
"""

# ╔═╡ a5b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d
begin
    pipe_config = DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig(
        sample_rate=fs, center_freq=carrier_freq
    )
    result = DGSN_SignalProcessing.pipeline.signal_pipeline.run_processing_pipeline(
        Complex{Float32}.(rx_signal), pipe_config
    )

    pipeline_md = md"""
    Pipeline processing completed:
    - Success: $(result.success)
    - Processing time: $(round(result.processing_time_ms, digits=2)) ms
    - SNR estimate: $(round(result.snr_estimate, digits=1)) dB
    - Peaks found: $(length(result.peak_frequencies))
    """
    pipeline_md
end

# ╔═╡ b6c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e
md"""
## Summary
This notebook demonstrates the DGSN signal processing pipeline capabilities including modulation, filtering, spectral analysis, feature extraction, and ML classification.
"""

# ╔═╡ Cell order:
# ╠═7a1b2c3d-4e5f-6a7b-8c9d-0e1f2a3b4c5d
# ╠═4d2d5e60-5f1a-11ec-8f20-1b9c3a7e5f8a
# ╠═8b2c3d4e-5f6a-7b8c-9d0e-1f2a3b4c5d6e
# ╠═9c3d4e5f-6a7b-8c9d-0e1f-2a3b4c5d6e7f
# ╠═ad4e5f6a-7b8c-9d0e-1f2a-3b4c5d6e7f8a
# ╠═be5f6a7b-8c9d-0e1f-2a3b-4c5d6e7f8a9b
# ╠═cf6a7b8c-9d0e-1f2a-3b4c-5d6e7f8a9b0c
# ╠═d07a8b9c-0d1e-2f3a-4b5c-6d7e8f9a0b1c
# ╠═e18b9c0d-1e2f-3a4b-5c6d-7e8f9a0b1c2d
# ╠═f29c0d1e-2f3a-4b5c-6d7e-8f9a0b1c2d3e
# ╠═a30d1e2f-3a4b-5c6d-7e8f-9a0b1c2d3e4f
# ╠═b41e2f3a-4b5c-6d7e-8f9a-0b1c2d3e4f5a
# ╠═c52f3a4b-5c6d-7e8f-9a0b-1c2d3e4f5a6b
# ╠═d63a4b5c-6d7e-8f9a-0b1c-2d3e4f5a6b7c
# ╠═e74b5c6d-7e8f-9a0b-1c2d-3e4f5a6b7c8d
# ╠═f85c6d7e-8f9a-0b1c-2d3e-4f5a6b7c8d9e
# ╠═a96d7e8f-9a0b-1c2d-3e4f-5a6b7c8d9e0f
# ╠═b07e8f9a-0b1c-2d3e-4f5a-6b7c8d9e0f1a
# ╠═c18f9a0b-1c2d-3e4f-5a6b-7c8d9e0f1a2b
# ╠═d29a0b1c-2d3e-4f5a-6b7c-8d9e0f1a2b3c
# ╠═e3a0b1c2-3d4e-5f6a-7b8c-9d0e1f2a3b4c
# ╠═f4a1b2c3-4d5e-6f7a-8b9c-0d1e2f3a4b5c
# ╠═a5b2c3d4-5e6f-7a8b-9c0d-1e2f3a4b5c6d
# ╠═b6c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e
