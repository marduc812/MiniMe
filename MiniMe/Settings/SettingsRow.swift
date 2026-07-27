//
//  SettingsRow.swift
//  MiniMe
//

import SwiftUI

/// A settings form row: a tinted icon tile followed by the row's control.
/// Every tab uses this so rows line up identically across the app.
struct SettingsRow<Content: View>: View {
    let icon: String
    let tint: Color
    var alignment: VerticalAlignment = .center
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: alignment, spacing: 10) {
            SettingsRowIcon(systemName: icon, color: tint)
            content()
        }
    }
}
