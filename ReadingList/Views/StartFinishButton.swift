import Foundation
import UIKit
import ReadingList_Foundation

class StartFinishButton: BorderedButton {
    enum ButtonState {
        case start
        case finish
        case none
    }

    var startColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemBlue
        } else {
            return UIColor(.buttonBlue)
        }
    }()

    var finishColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemGreen
        } else {
            return UIColor(.buttonGreen)
        }
    }()

    func setState(_ state: ButtonState) {
        switch state {
        case .start:
            isHidden = false
            setColor(startColor)
            setTitle("START", for: .normal)
        case .finish:
            isHidden = false
            setColor(finishColor)
            setTitle("FINISH", for: .normal)
        case .none:
            isHidden = true
        }
    }
}
