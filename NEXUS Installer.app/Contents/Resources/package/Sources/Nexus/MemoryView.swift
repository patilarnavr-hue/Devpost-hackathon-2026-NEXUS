// NEXUS Memory View — display long-term memory entries

import SwiftUI

struct MemoryView: View {
    @EnvironmentObject var engine: NexusEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Memory")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(20)

            if engine.memories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("No memories stored")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    Text("Memories are created as NEXUS completes workflows")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.memories) { memory in
                            MemoryRow(memory: memory)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Color.black)
    }
}

struct MemoryRow: View {
    let memory: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(memory.type.capitalized)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.accent.opacity(0.15))
                    .cornerRadius(4)

                Spacer()

                Text("\(Int(memory.confidence * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray)
            }

            Text(memory.content)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(3)

            HStack {
                Text(memory.source)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Spacer()
                Text(memory.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}
