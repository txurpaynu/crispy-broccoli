import SwiftUI

struct ChatView: View {
    @ObservedObject var store: CompanionStore
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                brainBanner

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if store.messages.isEmpty {
                                Text("Say hi to \(store.name)!")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 30)
                            }
                            ForEach(store.messages) { message in
                                MessageRow(message: message).id(message.id)
                            }
                            if store.isThinking {
                                HStack {
                                    Text("\(store.name) is thinking…")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: store.messages.count) { _, _ in
                        if let id = store.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } }
                    }
                    .onAppear { if let id = store.messages.last?.id { proxy.scrollTo(id, anchor: .bottom) } }
                }

                inputBar
            }
            .navigationTitle(store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { store.clearChat() }
                        .disabled(store.messages.isEmpty)
                }
            }
        }
    }

    private var brainBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: store.usingAppleIntelligence ? "sparkles" : "text.bubble")
            Text(store.usingAppleIntelligence ? "Apple Intelligence · on-device" : (store.fallbackReason ?? "Scripted replies"))
                .lineLimit(2)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message \(store.name)…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill").font(.title)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || store.isThinking)
            .tint(Color(red: 1.0, green: 0.12, blue: 0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func send() {
        store.send(draft)
        draft = ""
    }
}

private struct MessageRow: View {
    var message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(message.role == .user
                              ? Color(red: 1.0, green: 0.12, blue: 0.5)
                              : Color(.secondarySystemBackground))
                )
                .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            if message.role == .companion { Spacer(minLength: 40) }
        }
    }
}
