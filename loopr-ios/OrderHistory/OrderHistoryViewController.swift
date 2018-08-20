//
//  OrderHistoryViewController.swift
//  loopr-ios
//
//  Created by xiaoruby on 3/9/18.
//  Copyright © 2018 Loopring. All rights reserved.
//

import UIKit
import NotificationBannerSwift

class OrderHistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var historyTableView: UITableView!

    // Data source
    var orders: [Order] = []
    
    var type: OrderHistorySwipeType
    let refreshControl = UIRefreshControl()
    
    var viewAppear: Bool = false
    var isLaunching: Bool = true
    
    var didSelectRowClosure: ((Market) -> Void)?
    var didSelectBlankClosure: (() -> Void)?
    
    var searchText: String = ""
    var isSearching: Bool = false
    var filteredOrders = [Order]()
    
    var canHideKeyboard = true

    var previousOrderCount: Int = 0
    var pageIndex: UInt = 1
    var hasMoreData: Bool = true

    convenience init(type: OrderHistorySwipeType) {
        self.init(nibName: nil, bundle: nil)
        self.type = type
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        type = .open
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        view.theme_backgroundColor = GlobalPicker.backgroundColor
        historyTableView.theme_backgroundColor = GlobalPicker.backgroundColor
        setBackButton()
        historyTableView.dataSource = self
        historyTableView.delegate = self
        historyTableView.tableFooterView = UIView()
        historyTableView.separatorStyle = .none

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 10))
        historyTableView.tableHeaderView = headerView
        historyTableView.refreshControl = refreshControl
        refreshControl.theme_tintColor = GlobalPicker.textColor
        refreshControl.addTarget(self, action: #selector(refreshData(_:)), for: .valueChanged)

        getOrderHistoryFromRelay()
    }

    @objc private func refreshData(_ sender: Any) {
        pageIndex = 1
        hasMoreData = true
        getOrderHistoryFromRelay()
    }
    
    func getOrderHistoryFromRelay() {
        OrderDataManager.shared.getOrdersFromServer(pageIndex: pageIndex, completionHandler: { _ in
            DispatchQueue.main.async {
                if self.isLaunching {
                    self.isLaunching = false
                }
                self.orders = OrderDataManager.shared.getOrders(type: self.type)
                if self.previousOrderCount != self.orders.count {
                    self.hasMoreData = true
                } else {
                    self.hasMoreData = false
                }
                self.previousOrderCount = self.orders.count
                self.historyTableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        })
    }
    
    func reloadAfterSwipeViewUpdated(isSearching: Bool, searchText: String) {
        orders = OrderDataManager.shared.getOrders(type: self.type)
        self.isSearching = isSearching
        self.searchText = searchText.trim()
        if isSearching {
            filterContentForSearchText(self.searchText)
        } else {
            historyTableView.reloadData()
            // marketTableView.reloadSections(IndexSet(integersIn: 0...0), with: .fade)
        }
    }
    
    func searchTextDidUpdate(searchText: String) {
        self.searchText = searchText.trim()
        if self.searchText != "" {
            isSearching = true
            filterContentForSearchText(self.searchText)
        } else {
            isSearching = false
            historyTableView.reloadSections(IndexSet(integersIn: 0...0), with: .fade)
        }
    }
    
    // MARK: - Private instance methods
    
    func filterContentForSearchText(_ searchText: String) {
        let newFilteredOrders = OrderDataManager.shared.getOrders(type: self.type).filter { (order) -> Bool in
            return order.originalOrder.market.lowercased().contains(searchText.lowercased())
        }
        filteredOrders = newFilteredOrders
        if historyTableView.contentOffset.y == 0 {
            historyTableView.reloadSections(IndexSet(integersIn: 0...0), with: .fade)
        } else {
            canHideKeyboard = false
            _ = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
                self.canHideKeyboard = true
            }
            
            historyTableView.reloadData()
            // tableView.setContentOffset(.zero, animated: false)
            let topIndex = IndexPath(row: 0, section: 0)
            historyTableView.scrollToRow(at: topIndex, at: .top, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if canHideKeyboard {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    func isTableEmpty() -> Bool {
        return orders.count == 0 && !isLaunching
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return filteredOrders.count
        } else {
            return isTableEmpty() ? 1 : orders.count
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isTableEmpty() {
            return OrderNoDataTableViewCell.getHeight()
        } else {
            return OrderTableViewCell.getHeight()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isTableEmpty() {
            var cell = tableView.dequeueReusableCell(withIdentifier: OrderNoDataTableViewCell.getCellIdentifier()) as? OrderNoDataTableViewCell
            if cell == nil {
                let nib = Bundle.main.loadNibNamed("OrderNoDataTableViewCell", owner: self, options: nil)
                cell = nib![0] as? OrderNoDataTableViewCell
            }
            cell?.noDataLabel.text = LocalizedString("No_Data_Tip", comment: "")
            cell?.noDataImageView.image = #imageLiteral(resourceName: "No-data-order")
            return cell!
        } else {
            var cell = tableView.dequeueReusableCell(withIdentifier: OrderTableViewCell.getCellIdentifier()) as? OrderTableViewCell
            if cell == nil {
                let nib = Bundle.main.loadNibNamed("OrderTableViewCell", owner: self, options: nil)
                cell = nib![0] as? OrderTableViewCell
            }
            let order: Order
            if isSearching {
                order = filteredOrders[indexPath.row]
            } else {
                order = orders[indexPath.row]
            }
            cell?.order = order
            cell?.pressedCancelButtonClosure = {
                let title = LocalizedString("You are going to cancel the order.", comment: "")
                let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: LocalizedString("Confirm", comment: ""), style: .default, handler: { _ in
                    SendCurrentAppWalletDataManager.shared._cancelOrder(order: order.originalOrder, completion: { (txHash, error) in
                        self.getOrderHistoryFromRelay()
                        self.completion(txHash, error)
                    })
                }))
                alert.addAction(UIAlertAction(title: LocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
                }))
                self.present(alert, animated: true, completion: nil)
            }
            cell?.update()
            
            // Pagination
            if hasMoreData && indexPath.row == orders.count - 1 {
                pageIndex += 1
                getOrderHistoryFromRelay()
            }

            return cell!
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let order: Order
        if isSearching {
            order = filteredOrders[indexPath.row]
        } else {
            order = orders[indexPath.row]
        }
        
        let viewController = OrderDetailViewController()
        viewController.order = order
        viewController.hidesBottomBarWhenPushed = true
        self.navigationController?.view.endEditing(true)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension OrderHistoryViewController {
    
    func completion(_ txHash: String?, _ error: Error?) {
        var title: String = ""
        guard error == nil && txHash != nil else {
            DispatchQueue.main.async {
                title = NSLocalizedString("Order cancelled Failed, Please try again.", comment: "")
                let banner = NotificationBanner.generate(title: title, style: .danger)
                banner.duration = 5
                banner.show()
            }
            return
        }
        DispatchQueue.main.async {
            print(txHash!)
            title = NSLocalizedString("Order cancelled Successful.", comment: "")
            let banner = NotificationBanner.generate(title: title, style: .success)
            banner.duration = 2
            banner.show()
        }
    }
}
