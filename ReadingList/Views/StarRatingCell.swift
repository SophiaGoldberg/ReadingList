import Foundation
import UIKit
import Eureka
import Cosmos

public class StarRatingCell: Cell<Double>, CellType {

    @IBOutlet weak var leftLabel: UILabel! //swiftlint:disable:this private_outlet
    @IBOutlet private weak var cosmosView: CosmosView!

    public override func setup() {
        super.setup()
        height = { 50 }
        cosmosView.rating = row.value ?? 0
        cosmosView.didFinishTouchingCosmos = { rating in
            self.row.value = rating == 0 ? nil : rating
        }
        selectionStyle = .none
    }
}

public final class StarRatingRow: Row<StarRatingCell>, RowType {
    required public init(tag: String?) {
        super.init(tag: tag)
        cellProvider = CellProvider<StarRatingCell>(nibName: "StarRatingCell")
    }
}
