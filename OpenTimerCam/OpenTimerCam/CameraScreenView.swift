import SwiftUI

struct CameraScreenView: View {
    @StateObject private var viewModel: CameraScreenViewModel

    init(corner: TimerOverlayCorner, timerDuration: TimeInterval) {
        _viewModel = StateObject(wrappedValue: CameraScreenViewModel(corner: corner, timerDuration: timerDuration))
    }

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.recorder.session)
                .ignoresSafeArea()

            timerOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: viewModel.corner.alignment)
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
    }

    private var timerOverlay: some View {
        Text(viewModel.timerManager.displayString)
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
                Button("Start Recording") {
                    viewModel.startRecording()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.recorder.isRecording)

                Button("Stop Recording") {
                    Task { await viewModel.stopRecording() }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!viewModel.recorder.isRecording)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }
}
