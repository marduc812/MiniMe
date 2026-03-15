//
//  SettingsTabButton.swift
//  MiniMe
//

import SwiftUI

struct SettingsTabButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient
    let isSelected: Bool
    var badge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.secondary.opacity(0.12)))
                        .frame(width: 32, height: 32)
                        .shadow(color: isSelected ? .black.opacity(0.18) : .clear, radius: 4, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(width: 32, height: 32)
                    if badge {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 3, y: -3)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 80, height: 62)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
