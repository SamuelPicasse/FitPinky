import SwiftUI

struct CreateGroupNameView: View {
    var body: some View {
        NameInputView(navigationTitle: "Create Group") { name in
            CreateGroupGoalView(displayName: name)
        }
    }
}
