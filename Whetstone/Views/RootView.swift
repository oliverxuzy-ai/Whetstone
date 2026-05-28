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
                    try? modelContext.save()
                    hasCompletedOnboarding = true
                })
            } else {
                ContentView()
            }
        }
        .background(Theme.bgCream)
    }
}
