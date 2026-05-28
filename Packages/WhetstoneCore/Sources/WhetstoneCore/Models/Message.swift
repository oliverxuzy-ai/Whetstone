import Foundation
import SwiftData

@Model
public final class Message {
    public enum Role: String, Codable {
        case user
        case ai
        case system
    }

    public var roleRaw: String = Role.user.rawValue
    public var content: String = ""
    public var timestamp: Date = Date()

    public var conversation: Conversation?

    public var role: Role {
        get { Role(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    public init(role: Role, content: String, conversation: Conversation? = nil) {
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = Date()
        self.conversation = conversation
    }
}
