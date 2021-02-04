import Foundation
import UIKit
import ReadingList_Foundation

class StartFinishButton: BorderedButton {
    enum ButtonState {
        case start
        case finish
        case none
    }

    var startColor = UIColor.systemBlue
    var finishColor = UIColor.systemGreen

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
