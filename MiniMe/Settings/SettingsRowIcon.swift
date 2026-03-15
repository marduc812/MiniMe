//
//  SettingsRowIcon.swift
//  MiniMe
//

import SwiftUI

struct SettingsRowIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 26, height: 26)
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
