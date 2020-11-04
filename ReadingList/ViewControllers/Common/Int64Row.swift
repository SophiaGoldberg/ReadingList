import Foundation
import Eureka
import UIKit

extension Int64: InputTypeInitiable {
    public init?(string stringValue: String) {
        self.init(stringValue, radix: 10)
    }
}

open class Int64Cell: _FieldCell<Int64>, CellType {

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

class _Int64Row: FieldRow<Int64Cell> { //swiftlint:disable:this type_name
    required init(tag: String?) {
        super.init(tag: tag)
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale.current
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 0
        formatter = numberFormatter
    }
}

final class Int64Row: _Int64Row, RowType {
    required init(tag: String?) {
        super.init(tag: tag)
    }
}
