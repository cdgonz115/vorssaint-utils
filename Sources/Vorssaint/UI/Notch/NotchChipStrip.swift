//
//  NotchChipStrip.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/26/26.
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A row of chips that scrolls sideways, keeping the chosen one in view. The
/// island's editors use it for their documents: the scratchpad's pads and the
/// clipboard's pinned items. What a chip looks like and does is the caller's;
/// this only lays them out and follows the selection.
struct NotchChipStrip<Item: Identifiable, Chip: View>: View where Item.ID: Hashable {
    let items: [Item]
    let selectedID: Item.ID?
    @ViewBuilder let chip: (Item) -> Chip

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(items) { item in chip(item).id(item.id) }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard let selectedID else { return }
                proxy.scrollTo(selectedID, anchor: .center)
            }
            .onChange(of: selectedID) { _, selected in
                guard let selected else { return }
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(selected, anchor: .center) }
            }
        }
    }
}
