import Foundation
import SwiftData

@Model
final class Message {
    enum Role: String, Codable {
        case user
        case ai
        case system
    }

    var roleRaw: String = Role.user.rawValue
    var content: String = ""
    var timestamp: Date = Date()

    var conversation: Conversation?

    var role: Role {
        get { Role(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: Role, content: String, conversation: Conversation? = nil) {
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = Date()
        self.conversation = conversation
    }
}
