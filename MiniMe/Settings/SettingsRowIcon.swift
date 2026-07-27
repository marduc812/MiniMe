//
//  SettingsRowIcon.swift
//  MiniMe
//

import SwiftUI

struct SettingsRowIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(color)
            Image(systemName: systemName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
