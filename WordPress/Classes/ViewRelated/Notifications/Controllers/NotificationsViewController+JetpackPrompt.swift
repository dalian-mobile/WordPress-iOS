import Foundation

extension NotificationsViewController {

    func promptForJetpackCredentials() {
        guard let blog = blogService.lastUsedBlog() else {
            return
        }

        if let controller = jetpackLoginViewController {
            controller.blog = blog
            controller.updateMessage()
            configureControllerCompletion(controller, withBlog: blog)
        } else {
            let controller = JetpackLoginViewController(blog: blog)
            controller.presenter = .notifications
            addChildViewController(controller)
            tableView.addSubview(withFadeAnimation: controller.view)
            controller.view.center = tableView.center
            configureControllerCompletion(controller, withBlog: blog)
            jetpackLoginViewController = controller
        }
    }


    fileprivate func configureControllerCompletion(_ controller: JetpackLoginViewController, withBlog blog: Blog) {
        controller.completionBlock = { [weak self, weak controller] in
            self?.activityIndicator.stopAnimating()
            self?.blogService.syncBlog(blog, success: {
                self?.activityIndicator.stopAnimating()
                if blog.account != nil {
                    WPAppAnalytics.track(.signedInToJetpack, with: blog)
                    WPAppAnalytics.track(.performedJetpackSignInFromNotificationsScreen, with: blog)
                    controller?.view.removeFromSuperview()
                    controller?.removeFromParentViewController()
                    self?.jetpackLoginViewController = nil
                    self?.tableView.reloadData()
                } else {
                    controller?.updateMessage()
                }
            }, failure: { (error) in
                self?.activityIndicator.stopAnimating()
                DDLogError("Error syncing blog for Jetpack status from Notifications \(error)")
            })
        }
    }


    // MARK: - Private Computed Properties

    fileprivate var blogService: BlogService {
        return BlogService(managedObjectContext: managedObjectContext())
    }

}
