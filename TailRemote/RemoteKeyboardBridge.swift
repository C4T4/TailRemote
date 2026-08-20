import RoyalVNCKit
import SwiftUI
import UIKit

struct RemoteKeyboardBridge: UIViewRepresentable {
    @ObservedObject var session: VNCSession
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> RemoteKeyboardTextField {
        let field = RemoteKeyboardTextField()
        field.onText = session.sendText
        field.onBackspace = { session.pressKey(.delete) }
        field.onReturn = { session.pressKey(.return) }
        field.onDismiss = { isActive = false }
        return field
    }

    func updateUIView(_ field: RemoteKeyboardTextField, context: Context) {
        field.onText = session.sendText
        field.onBackspace = { session.pressKey(.delete) }
        field.onReturn = { session.pressKey(.return) }

        if isActive, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isActive, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }
}

@MainActor
final class RemoteKeyboardTextField: UITextField, UITextFieldDelegate {
    var onText: ((String) -> Void)?
    var onBackspace: (() -> Void)?
    var onReturn: (() -> Void)?
    var onDismiss: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        autocorrectionType = .no
        spellCheckingType = .no
        smartDashesType = .no
        smartQuotesType = .no
        smartInsertDeleteType = .no
        textContentType = .oneTimeCode
        returnKeyType = .default
        keyboardAppearance = .dark
        inputAssistantItem.leadingBarButtonGroups = []
        inputAssistantItem.trailingBarButtonGroups = []
        accessibilityLabel = "Remote keyboard input"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func deleteBackward() {
        onBackspace?()
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if string == "\n" {
            onReturn?()
        } else if !string.isEmpty {
            onText?(string)
        }
        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        onDismiss?()
    }
}

