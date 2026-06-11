import SwiftUI
import SwiftData
import WhetstoneCore

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding || profiles.isEmpty {
                OnboardingView(onComplete: { profession, customContext in
                    let profile = UserProfile(profession: profession, customContext: customContext)
                    modelContext.insert(profile)
                    do {
                        try modelContext.save()
                        // Only advance past onboarding once the profile is durably
                        // persisted — otherwise the user lands in an app with no profile.
                        hasCompletedOnboarding = true
                    } catch {
                        Log.persistence.error("onboarding profile save failed: \(error.localizedDescription, privacy: .public)")
                    }
                })
            } else {
                WorkspaceView()
            }
        }
        .background(Theme.paper)
    }
}
