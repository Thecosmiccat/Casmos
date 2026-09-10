//
//  CasmosChatActions.swift
//  Casmos
//
//  Repeat, Details/JSON, no-quote forward, and double-click dispatch.
//

import Foundation
import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import Translate
import TelegramMedia
import InAppSettings
import Casmos

func casmosCanRepeatMessage(_ message: Message, chatInteraction: ChatInteraction) -> Bool {
    if message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
        return false
    }
    if message.adAttribute != nil {
        return false
    }
    if message.isCopyProtected() || message.containsSecretMedia {
        return false
    }
    if message.extendedMedia is TelegramMediaAction {
        return false
    }
    if chatInteraction.isLogInteraction {
        return false
    }
    if chatInteraction.mode.customChatContents != nil {
        return false
    }
    guard let peer = chatInteraction.peer else {
        return false
    }
    return peer.canSendMessage(chatInteraction.mode.isThreadMode || chatInteraction.mode.isTopicMode, media: message.media.first, threadData: chatInteraction.presentation.threadInfo)
}

func casmosRepeatMessages(_ messages: [Message], chatInteraction: ChatInteraction) {
    let context = chatInteraction.context
    let peerId = chatInteraction.peerId
    let threadId = chatInteraction.chatLocation.threadId
    let paid = chatInteraction.presentation.sendPaidMessageStars
    let groupingKey: Int64? = messages.count > 1 ? arc4random64() : nil
    for message in messages {
        var attributes: [MessageAttribute] = []
        if let entities = message.textEntities {
            attributes.append(entities)
        }
        if FastSettings.isChannelMessagesMuted(peerId) {
            attributes.append(NotificationInfoMessageAttribute(flags: [.muted]))
        }
        if let paid {
            attributes.append(PaidStarsMessageAttribute(stars: paid, postponeSending: false))
        }
        var mediaReference: AnyMediaReference? = nil
        if let media = message.media.first, !(media is TelegramMediaAction) {
            mediaReference = AnyMediaReference.message(message: MessageReference(message), media: media)
        }
        if message.text.isEmpty && mediaReference == nil {
            continue
        }
        let enqueue = EnqueueMessage.message(text: message.text, attributes: attributes, inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: [])
        _ = Sender.enqueue(message: enqueue, context: context, peerId: peerId).start()
    }
}

func casmosForwardWithoutQuote(_ messages: [Message], chatInteraction: ChatInteraction) {
    showModal(with: ShareModalController(ForwardMessagesObject(chatInteraction.context, messages: messages, album: messages.count > 1, getMessages: chatInteraction.getMessages, hideNames: true)), for: chatInteraction.context.window)
}

func casmosCopyMessageText(_ message: Message, context: AccountContext) {
    let text = message.text
    guard !text.isEmpty else {
        return
    }
    copyToClipboard(text)
    showModalText(for: context.window, text: "Copied")
}

func casmosTranslateMessage(_ message: Message, chatInteraction: ChatInteraction) {
    let text = message.text
    guard !text.isEmpty else {
        return
    }
    let context = chatInteraction.context
    let language = Translate.detectLanguage(for: text)
    showModal(with: TranslateModalController(context: context, from: language, toLang: appAppearance.languageCode, text: text, entities: message.textEntities?.entities ?? [], canBreak: false), for: context.window)
    if !CasmosHooks.translatorEnabled {
        chatInteraction.enableTranslatePaywall()
    }
}

func casmosMediaTypeName(_ media: Media) -> String {
    switch media {
    case is TelegramMediaImage:
        return "image"
    case let file as TelegramMediaFile:
        if file.isSticker {
            return "sticker"
        }
        if file.isAnimated && file.isVideo {
            return "gif"
        }
        if file.isVideo {
            return "video"
        }
        if file.isVoice {
            return "voice"
        }
        if file.isMusic {
            return "audio"
        }
        return "file"
    case is TelegramMediaWebpage:
        return "webpage"
    case is TelegramMediaPoll:
        return "poll"
    case is TelegramMediaMap:
        return "map"
    case is TelegramMediaContact:
        return "contact"
    case is TelegramMediaInvoice:
        return "invoice"
    case is TelegramMediaGame:
        return "game"
    case is TelegramMediaDice:
        return "dice"
    case is TelegramMediaTodo:
        return "todo"
    case is TelegramMediaStory:
        return "story"
    case is TelegramMediaAction:
        return "action"
    default:
        return String(describing: type(of: media))
    }
}

func casmosMessageJSONString(_ message: Message) -> String {
    var payload: [String: Any] = [
        "id": Int(message.id.id),
        "namespace": Int(message.id.namespace),
        "peerId": NSNumber(value: message.id.peerId.toInt64()),
        "timestamp": Int(message.timestamp),
        "text": message.text,
        "outgoing": !message.flags.contains(.Incoming),
        "failed": message.flags.contains(.Failed),
        "unsent": message.flags.contains(.Unsent)
    ]
    if let author = message.author {
        payload["authorId"] = NSNumber(value: author.id.toInt64())
        payload["author"] = author.displayTitle
    }
    if let groupingKey = message.groupingKey {
        payload["groupingKey"] = NSNumber(value: groupingKey)
    }
    if let forwardInfo = message.forwardInfo {
        var forward: [String: Any] = [
            "date": Int(forwardInfo.date)
        ]
        if let author = forwardInfo.author {
            forward["authorId"] = NSNumber(value: author.id.toInt64())
            forward["author"] = author.displayTitle
        }
        payload["forward"] = forward
    }
    if !message.media.isEmpty {
        payload["media"] = message.media.map { casmosMediaTypeName($0) }
    }
    if let entities = message.textEntities, !entities.entities.isEmpty {
        payload["entities"] = entities.entities.map { entity -> [String: Any] in
            return [
                "offset": entity.range.lowerBound,
                "length": entity.range.upperBound - entity.range.lowerBound,
                "type": String(describing: entity.type)
            ]
        }
    }
    for attribute in message.attributes {
        if let views = attribute as? ViewCountMessageAttribute {
            payload["views"] = views.count
        }
        if let replies = attribute as? ReplyThreadMessageAttribute {
            payload["replies"] = replies.count
        }
    }
    guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
          let string = String(data: data, encoding: .utf8) else {
        return "{}"
    }
    return string
}

func casmosShowMessageJSON(_ message: Message, context: AccountContext) {
    let json = casmosMessageJSONString(message)
    let identifier = InputDataIdentifier("casmos.message.json")
    let entries: [InputDataEntry] = [
        .sectionId(0, type: .normal),
        .custom(sectionId: 1, index: 0, value: .none, identifier: identifier, equatable: InputDataEquatable(json), comparable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: json, detectBold: false, textColor: theme.colors.text, fontSize: 12, isTextSelectable: true, viewType: .singleItem)
        }),
        .desc(sectionId: 1, index: 1, text: .plain("Message fields as JSON. Copy places the text on the clipboard."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)),
        .sectionId(2, type: .normal)
    ]
    let controller = InputDataController(dataSignal: .single(InputDataSignalValue(entries: entries)), title: "Message Details")
    let modal = InputDataModalController(controller, modalInteractions: ModalInteractions(acceptTitle: "Copy JSON", accept: {
        copyToClipboard(json)
        showModalText(for: context.window, text: "Copied")
    }, drawBorder: true, height: 50, singleButton: true))
    showModal(with: modal, for: context.window)
}

func casmosExportPreferences(window: Window) {
    guard let data = CasmosPreferences.exportJSON() else {
        alert(for: window, info: "Could not export Casmos preferences.")
        return
    }
    let temp = NSTemporaryDirectory() + "casmos-preferences.json"
    do {
        try data.write(to: URL(fileURLWithPath: temp))
        savePanel(file: temp, ext: "json", for: window, defaultName: "casmos-preferences.json")
    } catch {
        alert(for: window, info: "Could not write Casmos preferences.")
    }
}

func casmosImportPreferences(window: Window, completion: @escaping (Bool) -> Void) {
    filePanel(with: ["json"], allowMultiple: false, for: window) { paths in
        guard let path = paths?.first else {
            completion(false)
            return
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            alert(for: window, info: "Could not read that file.")
            completion(false)
            return
        }
        let ok = CasmosPreferences.importJSON(data)
        if ok {
            applyCasmosVerboseLogging()
            showModalText(for: window, text: "Casmos preferences imported")
        } else {
            alert(for: window, info: "That file is not a Casmos preferences JSON export.")
        }
        completion(ok)
    }
}

extension ChatRowItem {
    func casmosHandleDoubleTap() {
        guard let message = self.message else {
            return
        }
        switch CasmosPreferences.doubleTapAction {
        case .none:
            break
        case .reply:
            _ = replyAction()
        case .reaction:
            _ = reactAction()
        case .edit:
            _ = editAction()
        case .copy:
            casmosCopyMessageText(message, context: context)
        case .forward:
            _ = forwardAction()
        case .repeatMessage:
            if casmosCanRepeatMessage(message, chatInteraction: chatInteraction) {
                casmosRepeatMessages([message], chatInteraction: chatInteraction)
            }
        case .translate:
            casmosTranslateMessage(message, chatInteraction: chatInteraction)
        case .details:
            casmosShowMessageJSON(message, context: context)
        }
    }
}
