import Reusable
import UIKit
import RxSwift
import RxCocoa
import PKHUD

class MigrateAccountViewController: UIViewController, StoryboardBased, ViewModelBased {
    var viewModel: MigrateAccountViewModel!
    let disposeBag = DisposeBag()

    @IBOutlet weak var migrateButton: DesignableButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var removeAccountButton: DesignableButton!
    @IBOutlet weak var displayNameLabel: UILabel!
    @IBOutlet weak var jamiIdLabel: UILabel!
    @IBOutlet weak var registeredNameLabel: UILabel!
    @IBOutlet weak var explanationLabel: UILabel!
    @IBOutlet weak var avatarImage: UIImageView!
    @IBOutlet weak var passwordContainer: UIStackView!
    @IBOutlet weak var passwordField: DesignableTextField!
    @IBOutlet weak var passwordExplanationLabel: UILabel!

    var keyboardDismissTapRecognizer: UITapGestureRecognizer!
    var isKeyboardOpened: Bool = false

    @IBOutlet weak var settingsTable: UITableView!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = true
        self.migrateButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.removeAccountButton.applyGradient(with: [UIColor.jamiButtonLight, UIColor.jamiButtonDark], gradient: .horizontal)
        self.bindViewToViewModel()
        self.applyL10n()

        // handle keyboard
        self.adaptToKeyboardState(for: self.scrollView, with: self.disposeBag)
        keyboardDismissTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    }

    func bindViewToViewModel() {
        self.viewModel.profileImage
            .bind(to: self.avatarImage.rx.image)
            .disposed(by: disposeBag)

        self.viewModel.profileName
            .bind(to: self.displayNameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.profileName
            .map({ (name) -> Bool in
                return name.isEmpty
            }).bind(to: self.displayNameLabel.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.jamiId
            .bind(to: self.jamiIdLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.jamiId
            .map({ (jamiId) -> Bool in
                return jamiId.isEmpty
            }).bind(to: self.jamiIdLabel.rx.isHidden)
            .disposed(by: disposeBag)

        self.viewModel.username
            .bind(to: self.registeredNameLabel.rx.text)
            .disposed(by: disposeBag)

        self.viewModel.username
            .map({ (name) -> Bool in
                return name.isEmpty
            }).bind(to: self.registeredNameLabel.rx.isHidden)
            .disposed(by: disposeBag)
       // passwordContainer.isHidden = !viewModel.accountHasPassword()

        if viewModel.accountHasPassword() {
            self.passwordField.rx.text.orEmpty
                .bind(to: self.viewModel.password)
                .disposed(by: self.disposeBag)

            self.passwordField.rx.text.map({!($0?.isEmpty ?? true)})
                .bind(to: self.migrateButton.rx.isEnabled)
                .disposed(by: self.disposeBag)
        }

        self.viewModel.migrationState.asObservable()
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self](action) in
                switch action {
                case .unknown:
                    break
                case .started:
                    self?.showLoadingView()
                case .success:
                    self?.stopLoadingView()
                case .error:
                    self?.showMigrationError()
                }
            }).disposed(by: self.disposeBag)

        // Bind View Actions to ViewModel
         self.migrateButton.rx.tap.subscribe(onNext: { [unowned self] in
             DispatchQueue.main.async {
                 self.showLoadingView()
             }
             DispatchQueue.global(qos: .background).async {
                 self.viewModel.migrateAccount()
             }
         }).disposed(by: self.disposeBag)

        self.removeAccountButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.viewModel.removeAccount()
        }).disposed(by: self.disposeBag)
    }

    func applyL10n() {
        self.navigationItem.title = L10n.MigrateAccount.title
        self.tabBarController?.navigationItem.title="Profile Settings"
        //self.title = L10n.MigrateAccount.title
        migrateButton.setTitle(L10n.MigrateAccount.migrateButton, for: .normal)
        removeAccountButton.setTitle(L10n.MigrateAccount.removeAccount, for: .normal)
        explanationLabel.text = L10n.MigrateAccount.explanation
        passwordField.placeholder = L10n.MigrateAccount.passwordPlaceholder
        passwordExplanationLabel.text = L10n.MigrateAccount.passwordExplanation
    }

    private func stopLoadingView() {
        HUD.hide(animated: false)
    }

    private func showLoadingView() {
        HUD.show(.labeledProgress(title: L10n.MigrateAccount.migrating,
                                  subtitle: nil))
    }

    private func showMigrationError() {
        HUD.hide(animated: true) { _ in
            let alert = UIAlertController(title: L10n.MigrateAccount.error,
                                          message: nil,
                                          preferredStyle: .alert)
            let action = UIAlertAction(title: "OK",
                                       style: .cancel)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }

    @objc func dismissKeyboard() {
        self.isKeyboardOpened = false
        self.becomeFirstResponder()
        view.removeGestureRecognizer(keyboardDismissTapRecognizer)
    }
}
