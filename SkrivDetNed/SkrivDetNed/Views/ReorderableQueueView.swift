//
//  ReorderableQueueView.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ReorderableQueueView: View {
    @Binding var queue: [URL]
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel

    @State private var draggedItem: URL?
    @State private var dropTargetIndex: Int?
    @State private var isDragging = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Drop zone at the very beginning
                DropZoneView(
                    index: 0,
                    isTargeted: dropTargetIndex == 0,
                    draggedItem: draggedItem
                )
                .onDrop(of: [.url], isTargeted: Binding(
                    get: { dropTargetIndex == 0 },
                    set: { isTargeted in
                        print("🎯 Drop zone 0 targeted: \(isTargeted)")
                        withAnimation(.easeInOut(duration: 0.2)) {
                            dropTargetIndex = isTargeted ? 0 : nil
                        }
                    }
                )) { providers in
                    print("📍 Drop on zone 0")
                    return handleDrop(providers: providers, at: 0)
                }

                ForEach(Array(queue.enumerated()), id: \.element) { index, fileURL in
                    HStack(spacing: 0) {
                        // The card itself
                        PendingFileCard(fileURL: fileURL)
                            .environmentObject(transcriptionVM)
                            .scaleEffect(draggedItem == fileURL ? 0.8 : 1.0)
                            .opacity(draggedItem == fileURL ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: draggedItem)
                            .onDrag {
                                print("🎯 Started dragging: \(fileURL.lastPathComponent)")
                                self.draggedItem = fileURL
                                return NSItemProvider(object: fileURL as NSURL)
                            } preview: {
                                // Drag preview
                                VStack {
                                    Image(systemName: "doc.fill")
                                        .font(.largeTitle)
                                        .foregroundColor(.orange)
                                    Text(fileURL.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding()
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                            .onDrop(of: [.url], isTargeted: nil) { providers in
                                print("📍 Drop on card at index: \(index)")
                                // When dropping on a card, treat it as dropping after the card
                                return handleDrop(providers: providers, at: index + 1)
                            }

                        // Drop zone after each card
                        DropZoneView(
                            index: index + 1,
                            isTargeted: dropTargetIndex == index + 1,
                            draggedItem: draggedItem
                        )
                        .onDrop(of: [.url], isTargeted: Binding(
                            get: { dropTargetIndex == index + 1 },
                            set: { isTargeted in
                                print("🎯 Drop zone \(index + 1) targeted: \(isTargeted)")
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    dropTargetIndex = isTargeted ? index + 1 : nil
                                }
                            }
                        )) { providers in
                            print("📍 Drop on zone \(index + 1)")
                            return handleDrop(providers: providers, at: index + 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 100)
        .onDrop(of: [.url], isTargeted: nil) { _ in
            // Reset when drop ends
            withAnimation(.easeInOut(duration: 0.2)) {
                draggedItem = nil
                dropTargetIndex = nil
            }
            return false
        }
    }

    private func handleDrop(providers: [NSItemProvider], at targetIndex: Int) -> Bool {
        print("🎯 handleDrop called at index: \(targetIndex)")
        guard let provider = providers.first else {
            print("❌ No provider found")
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, error in
            if let error = error {
                print("❌ Error loading item: \(error)")
                return
            }

            guard let data = item as? Data,
                  let droppedURL = URL(dataRepresentation: data, relativeTo: nil) else {
                print("❌ Could not get URL from dropped item")
                return
            }

            print("✅ Dropped URL: \(droppedURL.lastPathComponent)")

            DispatchQueue.main.async {
                // Use transcriptionVM.pendingQueue directly instead of self.queue
                let currentQueue = self.transcriptionVM.pendingQueue

                // Find source index
                if let sourceIndex = currentQueue.firstIndex(of: droppedURL) {
                    print("📍 Source index: \(sourceIndex), Target index: \(targetIndex), Queue count: \(currentQueue.count)")

                    // Calculate if this is actually a meaningful move
                    var shouldMove = false

                    if targetIndex == 0 && sourceIndex != 0 {
                        // Moving to the beginning
                        shouldMove = true
                        print("➡️ Moving to beginning")
                    } else if targetIndex == currentQueue.count && sourceIndex != currentQueue.count - 1 {
                        // Moving to the end
                        shouldMove = true
                        print("➡️ Moving to end")
                    } else if sourceIndex < targetIndex - 1 || sourceIndex > targetIndex {
                        // Moving to a different position (not adjacent)
                        shouldMove = true
                        print("➡️ Moving to different position")
                    } else {
                        print("⏭️ No meaningful move needed")
                    }

                    if shouldMove {
                        // Remove from old position
                        var newQueue = currentQueue
                        newQueue.remove(at: sourceIndex)

                        // Adjust target index if needed
                        let adjustedIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex

                        // Insert at new position
                        newQueue.insert(droppedURL, at: min(adjustedIndex, newQueue.count))

                        print("🔄 Updating queue order: \(newQueue.map { $0.lastPathComponent })")

                        // Update the queue directly through transcriptionVM
                        self.transcriptionVM.updateQueueOrder(newQueue)
                    }
                } else {
                    print("❌ Could not find source index for: \(droppedURL.lastPathComponent)")
                    print("Current queue: \(currentQueue.map { $0.lastPathComponent })")
                }

                // Reset drag state
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.draggedItem = nil
                    self.dropTargetIndex = nil
                }
            }
        }
        return true
    }
}

// MARK: - Drop Zone View
struct DropZoneView: View {
    let index: Int
    let isTargeted: Bool
    let draggedItem: URL?

    var body: some View {
        Rectangle()
            .fill(Color.accentColor.opacity(isTargeted ? 0.3 : (draggedItem != nil ? 0.05 : 0)))
            .frame(width: isTargeted ? 30 : (draggedItem != nil ? 8 : 4), height: 80)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.accentColor, lineWidth: isTargeted ? 2 : (draggedItem != nil ? 0.5 : 0))
            )
            .animation(.easeInOut(duration: 0.2), value: isTargeted)
            .animation(.easeInOut(duration: 0.2), value: draggedItem != nil)
    }
}

// Preview
struct ReorderableQueueView_Previews: PreviewProvider {
    static var previews: some View {
        ReorderableQueueView(queue: .constant([
            URL(fileURLWithPath: "/test1.m4a"),
            URL(fileURLWithPath: "/test2.m4a"),
            URL(fileURLWithPath: "/test3.m4a")
        ]))
        .environmentObject(TranscriptionViewModel.shared)
    }
}