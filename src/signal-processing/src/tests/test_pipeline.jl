using Test
using DGSN_SignalProcessing

@testset "Pipeline" begin
    @testset "Pipeline configuration" begin
        config = DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig()
        @test config isa DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig
        @test config.sample_rate ≈ 2.5e6
        @test config.center_freq ≈ 2.4e9
        @test length(config.stages) > 0
    end

    @testset "Pipeline run" begin
        config = DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig(
            sample_rate=1e6,
            center_freq=100e6,
        )
        samples = randn(Complex{Float32}, 4096) * 0.1
        result = DGSN_SignalProcessing.pipeline.signal_pipeline.run_processing_pipeline(samples, config)
        @test result isa DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineResult
        @test result.success == true
        @test result.processing_time_ms > 0
    end

    @testset "Pipeline with filtering" begin
        config = DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig(
            sample_rate=1e6,
            center_freq=100e6,
        )
        filter_stage = DGSN_SignalProcessing.pipeline.signal_pipeline.FilterStage(true, :bandpass, [10000.0, 100000.0], 64)
        config.stages = [filter_stage]

        samples = randn(Complex{Float32}, 2048) * 0.1
        result = DGSN_SignalProcessing.pipeline.signal_pipeline.run_processing_pipeline(samples, config)
        @test result.success == true
    end

    @testset "Empty signal handling" begin
        config = DGSN_SignalProcessing.pipeline.signal_pipeline.PipelineConfig()
        samples = Complex{Float32}[]
        result = DGSN_SignalProcessing.pipeline.signal_pipeline.run_processing_pipeline(samples, config)
        @test result.success == false
        @test result.error_code == DGSN_SignalProcessing.pipeline.signal_pipeline.INVALID_INPUT
    end

    @testset "IQ correction" begin
        n = 2048
        samples = randn(Complex{Float32}, n) * 0.1
        samples .+= 0.05
        corrected = DGSN_SignalProcessing.pipeline.signal_pipeline.run_iq_correction(
            samples,
            DGSN_SignalProcessing.pipeline.signal_pipeline.IQCorrectionStage(true, true, false),
        )
        @test length(corrected) == n
        @test abs(mean(real(corrected))) < 0.01
    end

    @testset "Downconversion" begin
        fs = 10000.0
        t = 0:1/fs:0.1-1/fs
        samples = exp.(2π * im * 1000 .* t)
        stage = DGSN_SignalProcessing.pipeline.signal_pipeline.DownconvertStage(true, 1000.0, fs)
        downconverted = DGSN_SignalProcessing.pipeline.signal_pipeline.run_downconversion(samples, fs, stage)
        @test length(downconverted) == length(samples)
    end

    @testset "Configure pipeline" begin
        config = DGSN_SignalProcessing.pipeline.signal_pipeline.configure_pipeline(
            sample_rate=2.0e6,
            center_freq=150e6,
            enable_debug=true,
        )
        @test config.sample_rate ≈ 2.0e6
        @test config.center_freq ≈ 150e6
        @test config.enable_debug == true
    end
end

@testset "Streaming" begin
    @testset "Stream config creation" begin
        config = DGSN_SignalProcessing.pipeline.streaming.StreamConfig(
            buffer_size=32768,
            enable_processing=true,
        )
        @test config isa DGSN_SignalProcessing.pipeline.streaming.StreamConfig
        @test config.buffer_size == 32768
        @test config.enable_processing == true
    end

    @testset "Stream result initialization" begin
        result = DGSN_SignalProcessing.pipeline.streaming.StreamResult()
        @test result isa DGSN_SignalProcessing.pipeline.streaming.StreamResult
        @test result.active == false
        @test result.total_samples == 0
    end
end

@testset "Batch Processing" begin
    @testset "Batch config creation" begin
        config = DGSN_SignalProcessing.pipeline.batch.BatchConfig(
            input_files=["test1.iq", "test2.iq"],
            output_dir="/tmp/results",
            parallel=false,
        )
        @test config isa DGSN_SignalProcessing.pipeline.batch.BatchConfig
        @test length(config.input_files) == 2
    end

    @testset "Batch file info" begin
        info = DGSN_SignalProcessing.pipeline.batch.BatchFileInfo("test.iq", ".iq", 1024, 1.0, 1e6, 2.4e9)
        @test info.path == "test.iq"
        @test info.size_bytes == 1024
    end
end

@testset "ML Classifier" begin
    @testset "Feature extraction" begin
        signal = randn(Complex{Float32}, 1024) * 0.1
        extractor = DGSN_SignalProcessing.ml.classifier.FeatureExtractor()
        fv = DGSN_SignalProcessing.ml.classifier.extract_all_features(signal, extractor)
        @test fv isa DGSN_SignalProcessing.ml.classifier.FeatureVector
        @test length(fv.features) > 0
        @test length(fv.names) > 0
    end

    @testset "Classifier initialization" begin
        clf = DGSN_SignalProcessing.ml.classifier.SignalClassifier()
        @test clf isa DGSN_SignalProcessing.ml.classifier.SignalClassifier
        @test clf.trained == false
    end

    @testset "Train/test split" begin
        signals = [randn(Complex{Float32}, 256) for _ in 1:20]
        labels = rand(1:5, 20)
        train_sig, train_lbl, test_sig, test_lbl = DGSN_SignalProcessing.ml.classifier.train_test_split(
            signals, labels, test_ratio=0.3, shuffle=false,
        )
        @test length(train_sig) + length(test_sig) == 20
        @test length(train_lbl) + length(test_lbl) == 20
    end
end

@testset "ML Anomaly" begin
    @testset "Isolation Forest" begin
        forest = DGSN_SignalProcessing.ml.anomaly.IsolationForest(num_trees=10, sample_size=50)
        @test forest isa DGSN_SignalProcessing.ml.anomaly.IsolationForest
        @test forest.num_trees == 10
    end

    @testset "Autoencoder initialization" begin
        ae = DGSN_SignalProcessing.ml.anomaly.AutoencoderAnomaly(input_dim=8, hidden_dim=6, latent_dim=3)
        @test ae isa DGSN_SignalProcessing.ml.anomaly.AutoencoderAnomaly
        @test ae.trained == false
    end

    @testset "One-class SVM initialization" begin
        svm = DGSN_SignalProcessing.ml.anomaly.OneClassSVM(nu=0.1, gamma=0.1)
        @test svm isa DGSN_SignalProcessing.ml.anomaly.OneClassSVM
        @test svm.trained == false
    end
end

@testset "ML Fingerprinting" begin
    @testset "Fingerprint extraction" begin
        signal = randn(Complex{Float32}, 1024) * 0.1
        fp = DGSN_SignalProcessing.ml.fingerprinting.extract_fingerprint(signal, num_features=16)
        @test length(fp) > 0
        @test fp[1] isa DGSN_SignalProcessing.ml.fingerprinting.FingerprintFeature
    end

    @testset "RF Database" begin
        db = DGSN_SignalProcessing.ml.fingerprinting.RFDatabase(num_features=16)
        @test db isa DGSN_SignalProcessing.ml.fingerprinting.RFDatabase
        @test length(db.profiles) == 0
    end

    @testset "Profile creation" begin
        signal = randn(Complex{Float32}, 256) * 0.1
        fp = DGSN_SignalProcessing.ml.fingerprinting.extract_fingerprint(signal, num_features=8)
        profile = DGSN_SignalProcessing.ml.fingerprinting.RFProfile("transmitter_1", fp)
        @test profile.transmitter_id == "transmitter_1"
        @test length(profile.fingerprints) == length(fp)
    end

    @testset "Transmitter identification" begin
        db = DGSN_SignalProcessing.ml.fingerprinting.RFDatabase(num_features=8)
        signal1 = randn(Complex{Float32}, 256) * 0.1
        signal2 = randn(Complex{Float32}, 256) * 0.1
        fp1 = DGSN_SignalProcessing.ml.fingerprinting.extract_fingerprint(signal1, num_features=8)
        fp2 = DGSN_SignalProcessing.ml.fingerprinting.extract_fingerprint(signal2, num_features=8)
        profile = DGSN_SignalProcessing.ml.fingerprinting.RFProfile("tx1", fp1)
        DGSN_SignalProcessing.ml.fingerprinting.add_to_database(db, profile)
        id, conf = DGSN_SignalProcessing.ml.fingerprinting.identify_transmitter(db, fp2)
        @test id == "tx1" || id == "unknown"
    end
end
