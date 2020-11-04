import Foundation
import UIKit

@IBDesignable
public class ExpandableLabel: UIView {

    private let label = UILabel(frame: .zero)
    private let seeMore = UILabel(frame: .zero)
    private let gradientView = UIView(frame: .zero)
    private let gradient = CAGradientLayer()

    public override init(frame: CGRect) {
        super.init(frame: .zero)
        self.setup()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13.0, *) {
            if let previousTraitCollection = previousTraitCollection,
                previousTraitCollection.hasDifferentColorAppearance(comparedTo: traitCollection) {
                setupGradient()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    @IBInspectable public var text: String? {
        didSet {
            label.text = text
            showOrHideSeeMoreButton()
            invalidateIntrinsicContentSize()
        }
    }

    @IBInspectable public var color: UIColor = {
        if #available(iOS 13.0, *) {
            return .label
        } else {
            return .black
        }
    }() {
        didSet { label.textColor = color }
    }

    @IBInspectable public var gradientColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemBackground
        } else {
            return .white
        }
    }() {
        didSet {
            if seeMore.backgroundColor != gradientColor {
                seeMore.backgroundColor = gradientColor
                setupGradient()
            }
        }
    }

    public var buttonColor: UIColor = .systemBlue {
        didSet { seeMore.textColor = buttonColor }
    }

    func setupGradient() {
        let opaque = gradientColor.withAlphaComponent(1.0)
        let clear = gradientColor.withAlphaComponent(0.0)
        gradient.colors = [clear.cgColor, opaque.cgColor]
        gradient.locations = [0.0, 0.4]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 0)
    }

    @IBInspectable public var numberOfLines: Int = 4 {
        didSet {
            if !labelIsExpanded {
                label.numberOfLines = numberOfLines
            }
        }
    }

    public var font: UIFont {
        get { return label.font }
        set {
            if label.font != newValue {
                label.font = newValue
                seeMore.font = newValue
            }
        }
    }

    private var labelIsExpanded = false

    private func setup() {
        super.awakeFromNib()

        seeMore.text = "see more"
        seeMore.textColor = tintColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byClipping
        seeMore.translatesAutoresizingMaskIntoConstraints = false
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        addSubview(gradientView)
        addSubview(seeMore)

        label.pin(to: self, attributes: .leading, .trailing, .top, .bottom)
        seeMore.pin(to: self, attributes: .trailing, .bottom)
        gradientView.pin(to: seeMore, attributes: .top, .trailing, .bottom)
        gradientView.pin(to: seeMore, multiplier: 2.0, attributes: .width)

        gradientView.isOpaque = true
        gradientView.layer.insertSublayer(gradient, at: 0)

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(seeMoreTapped)))
    }

    func showOrHideSeeMoreButton() {
        if labelIsExpanded {
            gradientView.isHidden = true
            seeMore.isHidden = true
        } else {
            let isTruncated = label.isTruncated
            gradientView.isHidden = !isTruncated
            seeMore.isHidden = !isTruncated
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        showOrHideSeeMoreButton()
        gradientView.layoutIfNeeded()
        gradient.frame = gradientView.bounds
    }

    override public var intrinsicContentSize: CGSize {
        return label.intrinsicContentSize
    }

    @objc private func seeMoreTapped() {
        guard !labelIsExpanded else { return }

        label.numberOfLines = 0
        labelIsExpanded = true
        showOrHideSeeMoreButton()
    }
}
