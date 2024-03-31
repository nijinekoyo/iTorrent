//
//  TorrentFilesDictionaryItemView.swift
//  iTorrent
//
//  Created by Daniil Vinogradov on 04/11/2023.
//

import MvvmFoundation
import SwiftUI

class TorrentFilesDictionaryItemViewCell<VM: DictionaryItemViewModelProtocol>: UICollectionViewListCell {
    var model: VM!
    var disposeBag = DisposeBag()

    @MainActor
    var viewModel = TorrentFiles2DictionaryItemView.Model()

    func prepare(with model: VM) {
        self.model = model

        accessories = [.disclosureIndicator()]
        updateModel(with: prepareData())
        reload()

        disposeBag = DisposeBag()
        disposeBag.bind {
            model.updatePublisher
                .throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true)
                .receive(on: DispatchQueue.global(qos: .userInitiated))
                .sink { [weak self] _ in
                    guard let self else { return }
                    let data = prepareData()
                    Task { self.updateModel(with: data) }
                }
        }
    }

    private typealias UpdateData = (files: [Int], filesNeeded: [Int], progress: Double?)
    private func prepareData() -> UpdateData {
        let files = model.node.files
        let filesNeeded = files.filter { model.getPriority(for: $0) != .dontDownload }
        let progress = model.progress

        return (files, filesNeeded, progress)
    }

    @MainActor
    private func updateModel(with data: UpdateData) {
        viewModel.name = model.name
        viewModel.filesNeeded = data.filesNeeded.count
        viewModel.files = data.files.count
        viewModel.progress = data.progress
    }

    func reload() {
        contentConfiguration = UIHostingConfiguration {
            TorrentFiles2DictionaryItemView(model: viewModel) { [unowned self] in
                model.setPriority(.defaultPriority)
            } deselectAll: { [unowned self] in
                model.setPriority(.dontDownload)
            }
        }
    }
}

extension TorrentFiles2DictionaryItemView {
    class Model: ObservableObject {
        @Published var name: String = ""
        @Published var filesNeeded: Int = 0
        @Published var files: Int = 0
        @Published var progress: Double? = nil

        init(name: String, filesNeeded: Int, files: Int, progress: Double?) {
            self.name = name
            self.filesNeeded = filesNeeded
            self.files = files
            self.progress = progress
        }

        init() {}
    }
}

struct TorrentFiles2DictionaryItemView: View {
    @ObservedObject var model: Model

    var selectAll: (() -> Void)?
    var deselectAll: (() -> Void)?

    var progressText: String {
        var progressText = String(localized: "\(model.filesNeeded) / \(model.files) items")
        if let progress = model.progress {
            let percent = "\(String(format: "%.2f", progress * 100))%"
            progressText += " (\(percent))"
        }
        return progressText
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(.folder)
                .resizable()
                .frame(width: 44, height: 44)
            ZStack(alignment: .bottom) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading) {
                        Text(model.name)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                            .font(.subheadline.weight(.semibold))

                        Text(progressText)
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                        if model.progress != nil {
                            ProgressView(value: 0)
                                .opacity(0)
                        }
                    }
                    Spacer()
                    Menu {
                        Button("files.deselectAll", systemImage: "xmark.circle", role: .destructive) {
                            deselectAll?()
                        }
                        Button("files.selectAll", systemImage: "checkmark.circle") {
                            selectAll?()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .resizable()
                            .frame(width: 22, height: 22)
                    }
                }
                if let progress = model.progress {
                    ProgressView(value: progress)
                }
            }
        }
        .frame(minHeight: 54)
    }
}

#Preview {
    TorrentFiles2DictionaryItemView(model: .init(name: "Dictionary", filesNeeded: 3, files: 12, progress: -1))
}
