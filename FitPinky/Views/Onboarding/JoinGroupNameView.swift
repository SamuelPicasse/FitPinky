import SwiftUI

struct JoinGroupNameView: View {
    let code: String

    var body: some View {
        NameInputView(navigationTitle: "Join Group") { name in
            JoinGroupGoalView(code: code, displayName: name)
        }
    }
}
