import SwiftUI

struct CameraScreenView: View {
    @StateObject private var viewModel: CameraScreenViewModel
    let onBackToSetup: () -> Void

    @State private var shouldConfirmLeaving = false

    init(corner: TimerOverlayCorner, countdownDuration: TimeInterval, onBackToSetup: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: CameraScreenViewModel(corner: corner, countdownDuration: countdownDuration)
        )
        self.onBackToSetup = onBackToSetup
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraPreviewView(session: viewModel.recorder.session)
                .ignoresSafeArea()

            timerOverlay
                .padding(16)

            controls
        }
        .task {
            await viewModel.setup()
        }
        .alert("Permissions Needed", isPresented: Binding(get: { viewModel.permissionDeniedMessage != nil }, set: { if !$0 { viewModel.permissionDeniedMessage = nil } })) {
            Button("OK") { viewModel.permissionDeniedMessage = nil }
        } message: {
            Text(viewModel.permissionDeniedMessage ?? "")
        }
        .alert("Leave timer setup?", isPresented: $shouldConfirmLeaving) {
            Button("Stay", role: .cancel) { }
            Button("Leave", role: .destructive) {
                onBackToSetup()
            }
        } message: {
            Text("Are you sure you want to leave this page?")
        }
        .alert("End recording?", isPresented: $viewModel.shouldConfirmStopRecording) {
            Button("Cancel", role: .cancel) { }
            Button("Stop Recording", role: .destructive) {
                Task { await viewModel.stopRecording() }
            }
        } message: {
            Text("Are you sure you want to end the recording?")
        }
        .confirmationDialog(
            "Save recording?",
            isPresented: $viewModel.shouldPresentSaveDialog,
            titleVisibility: .visible
        ) {
            Button("Save") {
                Task { await viewModel.savePendingRecording() }
            }

            Button("Discard", role: .destructive) {
                viewModel.discardPendingRecording()
            }

            Button("Cancel", role: .cancel) { }
        }
    }

    private var timerOverlay: some View {
        Text(viewModel.timerDisplayString)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var controls: some View {
        VStack {
            Spacer()

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .font(.footnote)
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                Button("Back") {
                    shouldConfirmLeaving = true
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.recorder.isRecording)

                Button("Start Recording") {
                    viewModel.startRecording()
                }
                .buttonStyle(.borderedProminent)
                .tint(canStartRecording ? .red : .gray)
                .disabled(!canStartRecording)

                Button("Start Timer") {
                    viewModel.startTimer()
                }
                .buttonStyle(.borderedProminent)
                .tint(canStartTimer ? .orange : .gray)
                .disabled(!canStartTimer)

                Button("Stop Recording") {
                    viewModel.requestStopRecordingConfirmation()
                }
                .buttonStyle(.borderedProminent)
                .tint(canStopRecording ? .red : .gray)
                .disabled(!canStopRecording)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }

    private var canStartRecording: Bool {
        !viewModel.recorder.isRecording && viewModel.pendingExportURL == nil
    }

    private var canStartTimer: Bool {
        viewModel.recorder.isRecording && !viewModel.timerManager.isRunning && !viewModel.timerManager.isInPrestartCountdown
    }

    private var canStopRecording: Bool {
        viewModel.recorder.isRecording && viewModel.pendingExportURL == nil
    }
}
