import Foundation
import Eureka
import UIKit

extension Int32: InputTypeInitiable {
    public init?(string stringValue: String) {
        self.init(stringValue, radix: 10)
    }
}

open class Int32Cell: _FieldCell<Int32>, CellType {

    required public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    open override func setup() {
        super.setup()
        textField.autocorrectionType = .default
        textField.autocapitalizationType = .none
        textField.keyboardType = .numberPad
    }
}

class _Int32Row: FieldRow<Int32Cell> { //swiftlint:disable:this type_name
    required init(tag: String?) {
        super.init(tag: tag)
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        formatter = numberFormatter
    }
}

final class Int32Row: _Int32Row, RowType {
    required init(tag: String?) {
        super.init(tag: tag)
    }
}
