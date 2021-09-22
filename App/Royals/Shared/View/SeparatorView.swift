//
//  SeparatorView.swift
//  Royals
//
//  Created by Maria Luiza Amaral on 14/09/21.
//

import UIKit

class SeparatorView: UIView {
    // MARK: - Private attributes

    private var viewHeight: CGFloat = 1

    // REVIEW: Is this really necessary? viewHeight also
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: viewHeight)
    }

    // MARK: - Initialization

    init(viewHeight: CGFloat, color: UIColor) {
        self.viewHeight = viewHeight
        super.init(frame: .zero)
        setupView(color: color)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Assets.Colors.separatorGray.color
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView(color: UIColor) {
        backgroundColor = color
    }
}
