//
//  HelpDrawerCoordinator.swift.
//  Planetary
//
//  Created by Matthew Lorentz on 7/14/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import UIKit
import SwiftUI
import Analytics

enum HelpCoordinator {
    
    static func helpController(
        for viewController: UIViewController,
        sourceBarButton: UIBarButtonItem
    ) -> UIViewController {
        
        let view = helpDrawer(for: viewController, dismissAction: { viewController.dismiss(animated: true) })
        let controller = UIHostingController(rootView: view)
        
        controller.modalPresentationStyle = .popover
        controller.modalTransitionStyle = .coverVertical
        if let hostPopover = controller.popoverPresentationController {
            hostPopover.barButtonItem = sourceBarButton
            let sheet = hostPopover.adaptiveSheetPresentationController
            sheet.detents = [.medium()]
            sheet.preferredCornerRadius = 15
        }
        
        Analytics.shared.trackDidShowScreen(screenName: "Home Help Drawer")
        
        return controller
    }
    
    static func helpBarButton(action: Selector) -> UIBarButtonItem {
        let image = UIImage(systemName: "questionmark.circle")
        let item = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: action
        )
        return item
    }
    
    private static func helpDrawer(
        for viewController: UIViewController,
        dismissAction: @escaping () -> Void
    ) -> HelpDrawer? {
        
        let inDrawer = viewController.traitCollection.horizontalSizeClass == .compact
        
        if viewController is HomeViewController {
            return HelpDrawer(
                tabName: Text.home.text,
                tabImageName: "tab-icon-home",
                helpTitle: Text.Help.Home.title.text,
                bodyText: Text.Help.Home.body.text,
                highlightedWord: Text.Help.Home.highlightedWord.text,
                inDrawer: inDrawer,
                dismissAction: dismissAction
            )
        } else if viewController is DiscoverViewController {
            return HelpDrawer(
                tabName: Text.explore.text,
                tabImageName: "tab-icon-everyone",
                helpTitle: Text.Help.Discover.title.text,
                bodyText: Text.Help.Discover.body.text,
                highlightedWord: Text.Help.Discover.highlightedWord.text,
                inDrawer: inDrawer,
                dismissAction: dismissAction
            )
        } else if viewController is NotificationsViewController {
            return HelpDrawer(
                tabName: Text.notifications.text,
                tabImageName: "tab-icon-notifications",
                helpTitle: Text.Help.Notifications.title.text,
                bodyText: Text.Help.Notifications.body.text,
                highlightedWord: nil,
                inDrawer: inDrawer,
                dismissAction: dismissAction
            )
        } else if viewController is ChannelsViewController {
            return HelpDrawer(
                tabName: Text.channels.text,
                tabImageName: "tab-icon-channels",
                helpTitle: Text.Help.Hashtags.title.text,
                bodyText: Text.Help.Hashtags.body.text,
                highlightedWord: Text.Help.Hashtags.highlightedWord.text,
                inDrawer: inDrawer,
                dismissAction: dismissAction
            )
        } else if viewController is DirectoryViewController {
            return HelpDrawer(
                tabName: Text.yourNetwork.text,
                tabImageName: "tab-icon-directory",
                helpTitle: Text.Help.YourNetwork.title.text,
                bodyText: Text.Help.YourNetwork.body.text,
                highlightedWord: nil,
                inDrawer: inDrawer,
                dismissAction: dismissAction
            )
        } else {
            return nil
        }
    }
}
