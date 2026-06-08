import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var statusMessage: String = ""
    @State private var isSaved: Bool = false

    var body: some View {
        Form {
            Section {
                Text("输入你的 DeepL API Key（在 deepl.com 免费注册获取）")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("DeepL API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _ in
                        isSaved = false
                        statusMessage = ""
                    }
            }

            Section {
                HStack {
                    Button("保存") {
                        saveKey()
                    }
                    .keyboardShortcut(.return)
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(isSaved ? .green : .red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loadKey()
        }
    }

    private func loadKey() {
        if let saved = try? KeychainStore.shared.read() {
            apiKey = saved
        }
    }

    private func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            statusMessage = "API Key 不能为空"
            isSaved = false
            return
        }

        do {
            try KeychainStore.shared.save(key: trimmed)
            statusMessage = "已保存"
            isSaved = true
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
            isSaved = false
        }
    }
}
