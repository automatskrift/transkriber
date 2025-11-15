//
//  SimpleReorderableQueueView.swift
//  SkrivDetNed
//
//  Created by Assistant on 12/11/2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct SimpleReorderableQueueView: View {
    @EnvironmentObject private var transcriptionVM: TranscriptionViewModel
    @State private var draggedItem: URL?

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 8) {
                ForEach(transcriptionVM.pendingQueue, id: \.self) { fileURL in
                    PendingFileCard(fileURL: fileURL)
                        .environmentObject(transcriptionVM)
                        .opacity(draggedItem == fileURL ? 0.5 : 1.0)
                        .onDrag {
                            print("DRAG: Started dragging \(fileURL.lastPathComponent)")
                            self.draggedItem = fileURL
                            let provider = NSItemProvider(object: fileURL as NSURL)
                            print("DRAG: Created NSItemProvider for \(fileURL.lastPathComponent)")
                            return provider
                        }
                        .onDrop(of: [.url], delegate: SimpleDropDelegate(
                            item: fileURL,
                            draggedItem: $draggedItem,
                            transcriptionVM: transcriptionVM
                        ))
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
        .onDrop(of: [.url], delegate: QueueDropDelegate(
            draggedItem: $draggedItem,
            transcriptionVM: transcriptionVM
        ))
    }
}

struct SimpleDropDelegate: DropDelegate {
    let item: URL
    @Binding var draggedItem: URL?
    let transcriptionVM: TranscriptionViewModel

    func dropEntered(info: DropInfo) {
        print("DRAG: dropEntered on \(item.lastPathComponent)")
        guard let draggedItem = draggedItem,
              draggedItem != item else {
            print("DRAG: No draggedItem or same item")
            return
        }

        guard let from = transcriptionVM.pendingQueue.firstIndex(of: draggedItem),
              let to = transcriptionVM.pendingQueue.firstIndex(of: item) else {
            print("DRAG: Could not find indices")
            return
        }

        print("DRAG: Moving from index \(from) to index \(to)")

        if from != to {
            withAnimation(.default) {
                var newQueue = transcriptionVM.pendingQueue
                newQueue.move(fromOffsets: IndexSet(integer: from),
                             toOffset: to > from ? to + 1 : to)
                transcriptionVM.updateQueueOrder(newQueue)
                print("DRAG: Queue updated")
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        print("DRAG: dropUpdated")
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        print("DRAG: performDrop called")
        self.draggedItem = nil
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        let isValid = info.hasItemsConforming(to: [.url])
        print("DRAG: validateDrop = \(isValid)")
        return isValid
    }
}

// Add a drop delegate for the whole queue area
struct QueueDropDelegate: DropDelegate {
    @Binding var draggedItem: URL?
    let transcriptionVM: TranscriptionViewModel

    func dropEntered(info: DropInfo) {
        print("DRAG: Entered queue area")
    }

    func performDrop(info: DropInfo) -> Bool {
        print("DRAG: Dropped in queue area")
        draggedItem = nil
        return true
    }

    func dropExited(info: DropInfo) {
        print("DRAG: Exited queue area")
    }
}

// Array extension for move
extension Array {
    mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let itemsToMove = source.map { self[$0] }

        // Remove items in reverse order to maintain correct indices
        for index in source.sorted(by: >) {
            self.remove(at: index)
        }

        // Calculate adjusted destination
        let adjustedDestination = destination - source.filter { $0 < destination }.count

        // Insert items at destination
        for (offset, item) in itemsToMove.enumerated() {
            self.insert(item, at: adjustedDestination + offset)
        }
    }
}