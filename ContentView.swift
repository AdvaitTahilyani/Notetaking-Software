import SwiftUI
import Foundation

struct ContentView: View {
    @StateObject var whisperState = WhisperState()
    @State private var isUploading = false
    @State private var message = ""
    @State private var showFileChooser = false
    @State private var transcriptPath: URL?
    @State private var documentPath: URL?

    var body: some View {
        VStack(spacing: 20) {
            Text("Voice Recorder Transcription App")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            Button(action: {
                self.showFileChooser = true
            }) {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    Text(isUploading ? "Processing..." : "Upload Recording")
                        .fontWeight(.medium)
                }
                .padding()
            }
            .background(isUploading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isUploading)
            .padding(.horizontal)

            .fileImporter(isPresented: $showFileChooser, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    uploadRecording(url: url)
                    self.isUploading = true
                    self.message = "Processing..."
                case .failure(let error):
                    self.message = "Error: \(error.localizedDescription)"
                    self.isUploading = false
                }
            }

            if isUploading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }

            if let transcriptPath = transcriptPath {
                Button("Open Transcript") {
                    NSWorkspace.shared.open(transcriptPath)
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            if let documentPath = documentPath {
                Button("Open Notes") {
                    NSWorkspace.shared.open(documentPath)
                }
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            Text(message)
                .foregroundColor(.secondary)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
        .edgesIgnoringSafeArea(.all)
    }

    func uploadRecording(url: URL) {
        let session = URLSession.shared
        var request = URLRequest(url: URL(string: "http://127.0.0.1:5000/upload")!)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(url.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(url.mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(try! Data(contentsOf: url))
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    self.message = "Network error: \(error?.localizedDescription ?? "No error description")"
                    self.isUploading = false
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let transcriptPathString = json["transcript_file_path"] as? String,
                       let docxPathString = json["docx_file_path"] as? String {
                        self.transcriptPath = URL(fileURLWithPath: transcriptPathString)
                        self.documentPath = URL(fileURLWithPath: docxPathString)
                        self.message = "Files are ready to be opened."
                    } else {
                        self.message = "Invalid server response"
                    }
                    self.isUploading = false
                } catch {
                    self.message = "JSON parsing error: \(error.localizedDescription)"
                    self.isUploading = false
                }
            }
        }
        task.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


