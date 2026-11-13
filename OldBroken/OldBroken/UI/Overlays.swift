import SwiftUI

struct NarrationView: View {
    let line: NarrationLine
    var body: some View {
        Text(line.text)
            .font(.system(size: 16, weight: .regular, design: .serif))
            .italic()
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
            .shadow(radius: 4)
    }
}

struct BannerView: View {
    let banner: Banner
    var body: some View {
        VStack(spacing: 2) {
            Text(banner.title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .kerning(2)
                .foregroundStyle(.white.opacity(0.6))
            Text(banner.detail)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(.black.opacity(0.7), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15)))
        .padding(.top, 10)
    }
}

struct ChapterCardView: View {
    let chapter: ChapterDef
    let done: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(chapter.number)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(.white.opacity(0.6))
                Text(chapter.title)
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .foregroundStyle(.white)
            }
            .opacity(shown ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 1.2)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { done() }
        }
        .onTapGesture { done() }
    }
}

/// Close-up reading view for notes, files and objects.
struct InspectView: View {
    let doc: DocumentDef
    let close: () -> Void

    var paperColor: Color {
        switch doc.kind {
        case "note": return Color(red: 0.93, green: 0.90, blue: 0.80)
        case "phone": return Color(red: 0.08, green: 0.09, blue: 0.11)
        default: return Color(red: 0.95, green: 0.95, blue: 0.93)
        }
    }

    var inkColor: Color { doc.kind == "phone" ? .white : Color(red: 0.12, green: 0.12, blue: 0.14) }

    var font: Font {
        switch doc.kind {
        case "note": return .custom("Noteworthy-Bold", size: 16)
        case "file": return .system(size: 13, design: .monospaced)
        default: return .system(size: 14)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture(perform: close)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(doc.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(inkColor.opacity(0.6))
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(inkColor.opacity(0.5))
                    }
                }
                ScrollView {
                    Text(doc.body)
                        .font(font)
                        .foregroundStyle(inkColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(20)
            .frame(maxWidth: 460, maxHeight: 320)
            .background(paperColor, in: RoundedRectangle(cornerRadius: doc.kind == "phone" ? 22 : 3))
            .rotationEffect(.degrees(doc.kind == "note" ? -1.5 : 0))
            .shadow(color: .black.opacity(0.6), radius: 20)
        }
    }
}
