import Foundation

/// Composes one bounded first action from a parsed intent.
///
/// Strategy families keep common tasks natural without making the category
/// list the source of the action. Every family receives the user's object or
/// context, and the generic path remains specific to the captured task.
struct TaskIntentComposer: Sendable {
    init() {}

    func compose(
        intent: TaskIntent,
        category: TaskCategory,
        calibrationMultiplier: Double = 1.0
    ) -> NextStepProposal {
        let semanticCategory = intent.categoryHint ?? category
        let composed: ComposedStep

        if intent.strategy == .repair && Self.isAdministrativeRepair(intent, category: semanticCategory) {
            composed = Self.domainStep(intent: intent, category: semanticCategory)
        } else {
            switch intent.strategy {
            case .paint:
                composed = Self.paintStep(intent)
            case .purchase:
                composed = Self.purchaseStep(intent)
            case .sale:
                composed = Self.saleStep(intent)
            case .feeding:
                composed = Self.feedingStep(intent)
            case .mailing:
                composed = Self.mailingStep(intent)
            case .repair:
                composed = Self.repairStep(intent)
            case .surfaceCare:
                composed = Self.surfaceCareStep(intent)
            case .directAction:
                composed = Self.directActionStep(intent)
            case .domain:
                composed = Self.domainStep(intent: intent, category: semanticCategory)
            case .generic:
                composed = Self.genericStep(intent)
            }
        }

        let minutes = max(
            5,
            min(15, Int((Double(composed.baseMinutes) * calibrationMultiplier).rounded()))
        )
        return NextStepProposal(
            title: composed.title,
            step: composed.step,
            timerMinutes: minutes,
            stopCondition: composed.stop,
            category: category,
            shrinkLevel: .zero,
            generatedBy: .localTemplate,
            whyThisStep: composed.why
        )
    }
}

private extension TaskIntentComposer {
    struct ComposedStep {
        let title: String
        let step: String
        let stop: String
        let why: String
        let baseMinutes: Int
    }

    static func paintStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the wall")
        switch language(intent) {
        case .zhHans:
            return ComposedStep(
                title: "刷一小块\(chineseObject(intent, fallback: "墙"))",
                step: "把油漆和一把刷子或滚筒放到\(chineseObject(intent, fallback: "墙"))旁边，只刷一小块手掌大小的区域。",
                stop: "刷完这一小块就停，剩下的\(chineseObject(intent, fallback: "墙面"))以后再做。",
                why: "先完成一个小区域，能让这件事从想法变成可见的开始。",
                baseMinutes: 10
            )
        case .zhHant:
            return ComposedStep(
                title: "刷一小塊\(chineseObject(intent, fallback: "牆"))",
                step: "把油漆和一把刷子或滾筒放到\(chineseObject(intent, fallback: "牆"))旁邊，只刷一小塊手掌大小的區域。",
                stop: "刷完這一小塊就停，剩下的\(chineseObject(intent, fallback: "牆面"))以後再做。",
                why: "先完成一個小區域，能讓這件事從想法變成可見的開始。",
                baseMinutes: 10
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "壁")
            return ComposedStep(
                title: "\(japanese)を少しだけ塗る",
                step: "ペンキと刷毛かローラーをひとつ\(japanese)のそばに出して、手のひらくらいの範囲だけ塗りましょう。",
                stop: "その一区画を塗ったら止めましょう。残りの\(japanese)はあとで大丈夫です。",
                why: "目に見える一区画ができると、全体に取りかからなくてもこのことが具体的になります。",
                baseMinutes: 10
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Paint one small patch of \(object)",
            step: "Set out the paint and one brush or roller by \(object), then paint one palm-sized patch.",
            stop: "Stop after one patch; leave the rest of \(object) for later.",
            why: "One visible patch makes the task concrete without committing to the whole surface.",
            baseMinutes: 10
        )
    }

    static func purchaseStep(_ intent: TaskIntent) -> ComposedStep {
        let core = englishCoreObject(intent, fallback: "the item")
        let object = englishObject(intent, fallback: "the item")
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "要买的东西")
            return ComposedStep(
                title: "找一个\(chinese)选项",
                step: "在一个可信的商店里搜索\(chinese)，保存一个选项，先不购买。",
                stop: "保存一个选项后就停，暂时不用付款。",
                why: "先看到一个具体选项，再决定是否购买。",
                baseMinutes: 10
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "要買的東西")
            return ComposedStep(
                title: "找一個\(chinese)選項",
                step: "在一個可信的商店裡搜尋\(chinese)，儲存一個選項，先不購買。",
                stop: "儲存一個選項後就停，暫時不用付款。",
                why: "先看到一個具體選項，再決定是否購買。",
                baseMinutes: 10
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "買いたいもの")
            return ComposedStep(
                title: "\(japanese)の候補をひとつ見つける",
                step: "信頼できるお店をひとつ開いて\(japanese)を探し、買わずに候補をひとつ保存しましょう。",
                stop: "候補をひとつ保存したら止めましょう。まだ買わなくて大丈夫です。",
                why: "保存した候補があれば、買う判断の前に戻れる出発点ができます。",
                baseMinutes: 10
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Find one option for \(core)",
            step: "Search one trusted store for \(object) and save one option without buying it.",
            stop: "Stop after one option is saved; no purchase is needed yet.",
            why: "A saved option creates a reversible starting point before any purchase decision.",
            baseMinutes: 10
        )
    }

    static func saleStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the item")
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "要卖的东西")
            return ComposedStep(
                title: "给\(chinese)拍一张照片",
                step: "把\(chinese)放到光线好的地方，拍一张用于出售的照片。",
                stop: "拍好一张照片就停，暂时不用发布。",
                why: "一张照片是出售流程中可撤回、看得见的第一步。",
                baseMinutes: 10
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "要賣的東西")
            return ComposedStep(
                title: "給\(chinese)拍一張照片",
                step: "把\(chinese)放到光線好的地方，拍一張用於出售的照片。",
                stop: "拍好一張照片就停，暫時不用釋出。",
                why: "一張照片是出售流程中可撤回、看得見的第一步。",
                baseMinutes: 10
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "売りたいもの")
            return ComposedStep(
                title: "\(japanese)の写真を1枚撮る",
                step: "\(japanese)を明るい場所に置いて、出品用の写真を1枚撮りましょう。",
                stop: "1枚撮れたら止めましょう。まだ出品しなくて大丈夫です。",
                why: "写真が1枚あれば、出品や値段を決めなくても売る準備が始まります。",
                baseMinutes: 10
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Take one photo to sell \(object)",
            step: "Place \(object) in a clear spot and take one well-lit photo for its listing.",
            stop: "Stop after one photo; you do not need to publish the listing yet.",
            why: "One photo starts the sale without committing to a listing or price.",
            baseMinutes: 10
        )
    }

    static func feedingStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the pet")
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "宠物")
            return ComposedStep(
                title: "给\(chinese)准备食物",
                step: "把\(chinese)的食物放进碗里，把碗放到它面前。",
                stop: "碗放好后就停，喂食这一步完成了。",
                why: "把食物放到位，就是一个清楚而有限的照顾动作。",
                baseMinutes: 5
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "寵物")
            return ComposedStep(
                title: "給\(chinese)準備食物",
                step: "把\(chinese)的食物放進碗裡，把碗放到它面前。",
                stop: "碗放好後就停，餵食這一步完成了。",
                why: "把食物放到位，就是一個清楚而有限的照顧動作。",
                baseMinutes: 5
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "ペット")
            return ComposedStep(
                title: "\(japanese)のごはんを用意する",
                step: "\(japanese)のごはんを器に入れて、器を置きましょう。",
                stop: "器を置いたら止めましょう。今はこれで完了です。",
                why: "用意した器ひとつで、区切りのあるお世話がひとつ終わります。",
                baseMinutes: 5
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Fill \(possessive(object)) bowl",
            step: "Put the food for \(object) in its bowl and set the bowl down.",
            stop: "Stop once the bowl is down; feeding \(object) is complete for now.",
            why: "One prepared bowl is a complete, bounded care action.",
            baseMinutes: 5
        )
    }

    static func mailingStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the item")
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "包裹")
            return ComposedStep(
                title: "准备寄出\(chinese)",
                step: "把\(chinese)和寄件标签放在门口，先不要寄出。",
                stop: "包裹和标签放在一起后就停，寄出可以稍后再做。",
                why: "先把寄件所需的东西放到一起，下一步会更清楚。",
                baseMinutes: 7
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "包裹")
            return ComposedStep(
                title: "準備寄出\(chinese)",
                step: "把\(chinese)和寄件標籤放在門口，先不要寄出。",
                stop: "包裹和標籤放在一起後就停，寄出可以稍後再做。",
                why: "先把寄件所需的東西放到一起，下一步會更清楚。",
                baseMinutes: 7
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "荷物")
            return ComposedStep(
                title: "\(japanese)を送る準備をする",
                step: "\(japanese)と送り状を玄関にまとめて置きましょう。まだ送らなくて大丈夫です。",
                stop: "\(japanese)と送り状がそろったら止めましょう。発送はあとで大丈夫です。",
                why: "送るものをまとめておくだけなら、いつでも戻せて、このことが目に入ります。",
                baseMinutes: 7
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Prepare \(object) for mailing",
            step: "Put \(object) and its mailing label together by the door; do not send it yet.",
            stop: "Stop when \(object) and the label are together; sending it can wait.",
            why: "Putting the mailing pieces together is reversible and gets the task into view.",
            baseMinutes: 7
        )
    }

    static func repairStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the item")
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "这件物品")
            return ComposedStep(
                title: "检查\(chinese)",
                step: "走到\(chinese)所在的位置，让它进入视线；先不拆开，只找一个明显的症状。",
                stop: "找到一个明显的症状就停，先保持\(chinese)完整。",
                why: "先找到看得见的症状，不需要马上拆开或修完。",
                baseMinutes: 10
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "這件物品")
            return ComposedStep(
                title: "檢查\(chinese)",
                step: "走到\(chinese)所在的位置，讓它進入視線；先不拆開，只找一個明顯的症狀。",
                stop: "找到一個明顯的症狀就停，先保持\(chinese)完整。",
                why: "先找到看得見的症狀，不需要馬上拆開或修完。",
                baseMinutes: 10
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "この品物")
            return ComposedStep(
                title: "直す前に\(japanese)を見てみる",
                step: "\(japanese)を目の前に持ってきて、分解せずに気になるところをひとつ見つけましょう。",
                stop: "気になるところをひとつ指させたら止めましょう。\(japanese)はそのままで大丈夫です。",
                why: "見えている症状がひとつ分かれば、分解しなくても修理が具体的になります。",
                baseMinutes: 10
            )
        case .en, .ko:
            break
        }
        return ComposedStep(
            title: "Inspect \(object) before fixing it",
            step: "Bring \(object) into view and identify one visible symptom without taking it apart.",
            stop: "Stop after you can point to one visible symptom; leave \(object) assembled for now.",
            why: "One visible symptom makes the repair concrete without requiring disassembly.",
            baseMinutes: 10
        )
    }

    static func surfaceCareStep(_ intent: TaskIntent) -> ComposedStep {
        let object = englishObject(intent, fallback: "the surface")
        let verb = (intent.verb ?? "care for").lowercased()
        switch language(intent) {
        case .zhHans:
            let chinese = chineseObject(intent, fallback: "这个表面")
            let action = intent.verb ?? "处理"
            return ComposedStep(
                title: "处理\(chinese)的一小块",
                step: "把\(chinese)放到面前，只用合适的工具\(action)一个小的、安全区域。",
                stop: "处理完这一小块就停，剩下的\(chinese)以后再做。",
                why: "先做一个小而安全的区域，不需要一次完成整件事。",
                baseMinutes: 8
            )
        case .zhHant:
            let chinese = chineseObject(intent, fallback: "這個表面")
            let action = intent.verb ?? "處理"
            return ComposedStep(
                title: "處理\(chinese)的一小塊",
                step: "把\(chinese)放到面前，只用合適的工具\(action)一個小的、安全區域。",
                stop: "處理完這一小塊就停，剩下的\(chinese)以後再做。",
                why: "先做一個小而安全的區域，不需要一次完成整件事。",
                baseMinutes: 8
            )
        case .ja:
            let japanese = japaneseObject(intent, fallback: "この面")
            return ComposedStep(
                title: "\(japanese)の一部だけ手入れする",
                step: "\(japanese)を目の前に置いて、小さくて安全なところだけ手入れしましょう。",
                stop: "その小さなところが終わったら止めましょう。残りの\(japanese)はあとで大丈夫です。",
                why: "小さく安全なところから始めれば、全体を引き受けなくても取りかかれます。",
                baseMinutes: 8
            )
        case .en, .ko:
            break
        }
        let area = verb == "polish" || verb == "buff"
            ? "one small, non-optical exterior area"
            : "one small, low-risk area"
        return ComposedStep(
            title: "Care for one small part of \(object)",
            step: "Bring \(object) into view, then \(verb) \(area).",
            stop: "Stop after that one small area; leave the rest of \(object) for later.",
            why: "A small, low-risk area lets the requested action begin without taking on the whole object.",
            baseMinutes: 8
        )
    }

    static func directActionStep(_ intent: TaskIntent) -> ComposedStep {
        switch language(intent) {
        case .zhHans:
            let object = chineseObject(intent, fallback: "这件事")
            if intent.verb == "读" || intent.verb == "阅读" {
                return ComposedStep(
                    title: "读\(object)的一小段",
                    step: "打开\(object)，读第一页或第一小段。",
                    stop: "读完这一页或这一小段就停。",
                    why: "先让阅读真正开始，不要求一次读完。",
                    baseMinutes: 8
                )
            }
            return ComposedStep(
                title: "打开\(object)",
                step: "找到\(object)，打开它，让里面的内容进入视线。",
                stop: "打开后就停，先不用做别的。",
                why: "先完成一个清楚、可见的开始。",
                baseMinutes: 5
            )
        case .zhHant:
            let object = chineseObject(intent, fallback: "這件事")
            if intent.verb == "讀" || intent.verb == "閱讀" {
                return ComposedStep(
                    title: "讀\(object)的一小段",
                    step: "開啟\(object)，讀第一頁或第一小段。",
                    stop: "讀完這一頁或這一小段就停。",
                    why: "先讓閱讀真正開始，不要求一次讀完。",
                    baseMinutes: 8
                )
            }
            return ComposedStep(
                title: "開啟\(object)",
                step: "找到\(object)，開啟它，讓裡面的內容進入視線。",
                stop: "開啟後就停，先不用做別的。",
                why: "先完成一個清楚、可見的開始。",
                baseMinutes: 5
            )
        case .ja:
            let object = japaneseObject(intent, fallback: "このこと")
            if intent.verb == "読む" || intent.verb == "読書" {
                return ComposedStep(
                    title: "\(object)を1ページ読む",
                    step: "\(object)を最初のページで開いて、1ページ読みましょう。",
                    stop: "1ページ読んだら止めましょう。",
                    why: "1ページから始めれば、通して読む時間を用意しなくても取りかかれます。",
                    baseMinutes: 8
                )
            }
            return ComposedStep(
                title: "\(object)を開く",
                step: "\(object)を見つけて開き、中身が見えるようにしましょう。",
                stop: "\(object)が開いて中身が見えたら止めましょう。",
                why: "開いて見えるようになれば、次の選択がしやすくなります。",
                baseMinutes: 5
            )
        case .en, .ko:
            break
        }

        let object = englishObject(intent, fallback: "the task")
        if intent.verb == "read" {
            return ComposedStep(
                title: "Read one page of \(object)",
                step: "Open \(object) to its first page and read one page.",
                stop: "Stop after one page.",
                why: "Starting with one page makes the task concrete without requiring a full reading session.",
                baseMinutes: 8
            )
        }
        return ComposedStep(
            title: "Open \(object)",
            step: "Find \(object) and open it so its contents are visible.",
            stop: "Stop once \(object) is open and its contents are visible.",
            why: "A visible opening is enough to make the next choice easier.",
            baseMinutes: 5
        )
    }

    static func domainStep(intent: TaskIntent, category: TaskCategory) -> ComposedStep {
        switch language(intent) {
        case .zhHans:
            return chineseDomainStep(intent: intent, category: category)
        case .zhHant:
            return traditionalDomainStep(intent: intent, category: category)
        case .ja:
            return japaneseDomainStep(intent: intent, category: category)
        case .ko:
            return koreanDomainStep(intent: intent, category: category)
        case .en:
            break
        }

        let target = englishObject(intent, fallback: "this task")
        let core = englishCoreObject(intent, fallback: "this task")
        switch category {
        case .bills:
            let paymentAnchor = [intent.object, intent.context]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            if paymentAnchor.contains("payment") || paymentAnchor.contains("bill") || intent.verb == "pay" || intent.verb == "settle" {
                return ComposedStep(
                    title: "Find the bill",
                    step: "Open your email and search for the bill or payment notice for \(core).",
                    stop: "Stop when you see one matching bill; do not pay it yet.",
                    why: "Finding the amount and due date is a useful first step before any payment.",
                    baseMinutes: 10
                )
            }
            return ComposedStep(
                title: "Find \(target)",
                step: "Open your email and search for \(target).",
                stop: "Stop when you see one matching bill or notice; the next action can wait.",
                why: "Locating the relevant notice makes the next decision smaller.",
                baseMinutes: 10
            )
        case .email:
            if intent.verb == "reply" || intent.verb == "respond" || intent.verb == "email" || intent.verb == "message" {
                let recipient = intent.object.map { _ in englishObject(intent, fallback: "the recipient") } ?? "the relevant thread"
                return ComposedStep(
                    title: "Draft the first sentence",
                    step: "Open the email thread with \(recipient) and write its first sentence; leave it unsent.",
                    stop: "Stop after the first sentence; sending can wait.",
                    why: "A draft is reversible and turns a reply into one visible start.",
                    baseMinutes: 10
                )
            }
            return ComposedStep(
                title: "Open one relevant email",
                step: "Open your inbox and select one message connected to \(core).",
                stop: "Stop when that one message is open.",
                why: "One message is enough to make the email task concrete.",
                baseMinutes: 8
            )
        case .appointments:
            return ComposedStep(
                title: "Find one appointment option",
                step: "Open the calendar or provider page for \(target) and note one available date or time.",
                stop: "Stop after one date or time is visible; do not book it yet.",
                why: "One visible option is a reversible start to scheduling.",
                baseMinutes: 10
            )
        case .returns:
            return ComposedStep(
                title: "Find the return information",
                step: "Open the order details for \(target) and locate the return instructions or label.",
                stop: "Stop when one return instruction or label is visible.",
                why: "Finding the instruction is the earliest useful step before packing or sending.",
                baseMinutes: 10
            )
        case .insurance:
            return ComposedStep(
                title: "Find the insurance detail",
                step: "Open the insurance record for \(target) and locate the due date or next required item.",
                stop: "Stop when one due date or required item is visible.",
                why: "One factual detail gives the task a clear next foothold.",
                baseMinutes: 10
            )
        case .banking:
            return ComposedStep(
                title: "Open the relevant account",
                step: "Open your banking app and find the account or amount connected to \(target); do not transfer anything yet.",
                stop: "Stop when the relevant account or amount is visible.",
                why: "Checking the relevant fact keeps the first move reversible.",
                baseMinutes: 10
            )
        case .taxes:
            return ComposedStep(
                title: "Find the first tax document",
                step: "Open the tax folder or portal for \(target) and bring this year's first document into view.",
                stop: "Stop when one relevant document is visible.",
                why: "One document is a concrete beginning without opening the whole tax task.",
                baseMinutes: 12
            )
        case .household, .cleaning:
            return ComposedStep(
                title: "Clear one small area",
                step: "Choose one small area connected to \(target) and clear or clean only that area.",
                stop: "Stop when that one small area is clear.",
                why: "A bounded area keeps the household task finishable.",
                baseMinutes: 10
            )
        case .familyAdmin:
            return ComposedStep(
                title: "Open the family task",
                step: "Open the form or message connected to \(target) and read the first field that needs attention.",
                stop: "Stop after the first field or request is clear.",
                why: "Seeing the first requirement is enough to begin without completing the form.",
                baseMinutes: 10
            )
        case .medical:
            return ComposedStep(
                title: "Find one factual detail",
                step: "Open the clinic, prescription, or health record connected to \(target) and locate one factual detail.",
                stop: "Stop when one factual detail is visible; no medical decision is needed here.",
                why: "A factual detail creates a safe organizing step without giving medical advice.",
                baseMinutes: 10
            )
        case .workAdmin, .school:
            return ComposedStep(
                title: "Open the relevant work",
                step: "Open the document or message connected to \(target) and read its first instruction.",
                stop: "Stop after the first instruction is clear.",
                why: "Reading the first instruction reduces uncertainty before more work begins.",
                baseMinutes: 10
            )
        case .errands:
            return ComposedStep(
                title: "Prepare one item for \(target)",
                step: "Put one item needed for \(target) by the door or in the place you will use it.",
                stop: "Stop when that one item is in place.",
                why: "Preparing one item makes the errand easier to continue later.",
                baseMinutes: 7
            )
        case .other:
            return genericStep(intent)
        }
    }

    static func chineseDomainStep(intent: TaskIntent, category: TaskCategory) -> ComposedStep {
        let target = chineseObject(intent, fallback: "这件事")
        switch category {
        case .bills:
            return ComposedStep(
                title: "找到账单",
                step: "打开邮件，搜索与\(target)有关的账单或付款通知。",
                stop: "看到一条匹配的账单或通知就停，先不用付款。",
                why: "先找到金额或截止日期，下一步会更清楚。",
                baseMinutes: 10
            )
        case .email:
            if intent.verb == "回复" || intent.verb == "发送" {
                return ComposedStep(
                    title: "写下第一句话",
                    step: "打开与\(target)有关的邮件，写下第一句话，先不要发送。",
                    stop: "写完第一句话就停，发送可以稍后再做。",
                    why: "草稿可以随时修改，是可撤回的开始。",
                    baseMinutes: 10
                )
            }
            return ComposedStep(
                title: "打开一封相关邮件",
                step: "打开收件箱，找到一封与\(target)有关的邮件。",
                stop: "打开这一封邮件就停。",
                why: "先让一封邮件出现在眼前，就有了清楚的入口。",
                baseMinutes: 8
            )
        case .appointments:
            return ComposedStep(
                title: "找一个预约选项",
                step: "打开日历或服务方页面，找到与\(target)有关的一个日期或时间。",
                stop: "看到一个日期或时间就停，暂时不用预约。",
                why: "先看到一个选项，安排预约会更容易。",
                baseMinutes: 10
            )
        case .returns:
            return ComposedStep(
                title: "找到退货信息",
                step: "打开\(target)的订单详情，找到退货说明或标签。",
                stop: "看到一条退货说明或标签就停。",
                why: "先找到说明，不需要马上打包或寄出。",
                baseMinutes: 10
            )
        case .insurance:
            return ComposedStep(
                title: "找到保险的一项信息",
                step: "打开与\(target)有关的保险记录，找到截止日期或下一项要求。",
                stop: "看到一个日期或要求就停。",
                why: "先找到一个事实，下一步会更具体。",
                baseMinutes: 10
            )
        case .banking:
            return ComposedStep(
                title: "打开相关账户",
                step: "打开银行 App，找到与\(target)有关的账户或金额，先不要转账。",
                stop: "看到相关账户或金额就停。",
                why: "先确认一个事实，第一步保持可撤回。",
                baseMinutes: 10
            )
        case .taxes:
            return ComposedStep(
                title: "找到第一份税务文件",
                step: "打开税务文件夹或网站，把今年的一份相关文件放到眼前。",
                stop: "看到一份相关文件就停。",
                why: "先看到一份文件，不需要打开整个税务任务。",
                baseMinutes: 12
            )
        case .household, .cleaning:
            return ComposedStep(
                title: "清理一个小区域",
                step: "选一个与\(target)有关的小区域，只清理这一个区域。",
                stop: "这一个小区域清好后就停。",
                why: "限定一个区域，家务就更容易开始和结束。",
                baseMinutes: 10
            )
        case .familyAdmin, .workAdmin, .school:
            return ComposedStep(
                title: "打开相关内容",
                step: "打开与\(target)有关的表格、文件或消息，读清第一项要求。",
                stop: "看清第一项要求就停。",
                why: "先看清第一项，不需要马上完成整份内容。",
                baseMinutes: 10
            )
        case .medical:
            return ComposedStep(
                title: "找到一项事实",
                step: "打开与\(target)有关的诊所、处方或健康记录，找到一项事实信息。",
                stop: "看到一项事实信息就停，这里不用做医疗决定。",
                why: "先整理事实，不提供医疗建议。",
                baseMinutes: 10
            )
        case .errands:
            return ComposedStep(
                title: "准备一件物品",
                step: "把与\(target)有关的一件物品放到门口或要使用的地方。",
                stop: "这一件物品放好后就停。",
                why: "先准备一件物品，跑腿会更容易继续。",
                baseMinutes: 7
            )
        case .other:
            return genericStep(intent)
        }
    }

    static func traditionalDomainStep(intent: TaskIntent, category: TaskCategory) -> ComposedStep {
        let target = chineseObject(intent, fallback: "這件事")
        switch category {
        case .bills:
            return ComposedStep(
                title: "找到帳單",
                step: "開啟郵件，搜尋與\(target)有關的帳單或付款通知。",
                stop: "看到一條匹配的帳單或通知就停，先不用付款。",
                why: "先找到金額或截止日期，下一步會更清楚。",
                baseMinutes: 10
            )
        case .email:
            if intent.verb == "回覆" || intent.verb == "傳送" {
                return ComposedStep(
                    title: "寫下第一句話",
                    step: "開啟與\(target)有關的郵件，寫下第一句話，先不要傳送。",
                    stop: "寫完第一句話就停，傳送可以稍後再做。",
                    why: "草稿可以隨時修改，是可撤回的開始。",
                    baseMinutes: 10
                )
            }
            return ComposedStep(
                title: "開啟一封相關郵件",
                step: "開啟收件箱，找到一封與\(target)有關的郵件。",
                stop: "開啟這一封郵件就停。",
                why: "先讓一封郵件出現在眼前，就有了清楚的入口。",
                baseMinutes: 8
            )
        case .appointments:
            return ComposedStep(
                title: "找一個預約選項",
                step: "開啟日曆或服務方頁面，找到與\(target)有關的一個日期或時間。",
                stop: "看到一個日期或時間就停，暫時不用預約。",
                why: "先看到一個選項，安排預約會更容易。",
                baseMinutes: 10
            )
        case .returns:
            return ComposedStep(
                title: "找到退貨資訊",
                step: "開啟\(target)的訂單詳情，找到退貨說明或標籤。",
                stop: "看到一條退貨說明或標籤就停。",
                why: "先找到說明，不需要馬上打包或寄出。",
                baseMinutes: 10
            )
        case .insurance:
            return ComposedStep(
                title: "找到保險的一項資訊",
                step: "開啟與\(target)有關的保險記錄，找到截止日期或下一項要求。",
                stop: "看到一個日期或要求就停。",
                why: "先找到一個事實，下一步會更具體。",
                baseMinutes: 10
            )
        case .banking:
            return ComposedStep(
                title: "開啟相關帳戶",
                step: "開啟銀行 App，找到與\(target)有關的帳戶或金額，先不要轉帳。",
                stop: "看到相關帳戶或金額就停。",
                why: "先確認一個事實，第一步保持可撤回。",
                baseMinutes: 10
            )
        case .taxes:
            return ComposedStep(
                title: "找到第一份稅務檔案",
                step: "開啟稅務資料夾或網站，把今年的一份相關檔案放到眼前。",
                stop: "看到一份相關檔案就停。",
                why: "先看到一份檔案，不需要開啟整個稅務任務。",
                baseMinutes: 12
            )
        case .household, .cleaning:
            return ComposedStep(
                title: "清理一個小區域",
                step: "選一個與\(target)有關的小區域，只清理這一個區域。",
                stop: "這一個小區域清好後就停。",
                why: "限定一個區域，家務就更容易開始和結束。",
                baseMinutes: 10
            )
        case .familyAdmin, .workAdmin, .school:
            return ComposedStep(
                title: "開啟相關內容",
                step: "開啟與\(target)有關的表格、檔案或訊息，讀清第一項要求。",
                stop: "看清第一項要求就停。",
                why: "先看清第一項，不需要馬上完成整份內容。",
                baseMinutes: 10
            )
        case .medical:
            return ComposedStep(
                title: "找到一項事實",
                step: "開啟與\(target)有關的診所、處方或健康記錄，找到一項事實資訊。",
                stop: "看到一項事實資訊就停，這裡不用做醫療決定。",
                why: "先整理事實，不提供醫療建議。",
                baseMinutes: 10
            )
        case .errands:
            return ComposedStep(
                title: "準備一件物品",
                step: "把與\(target)有關的一件物品放到門口或要使用的地方。",
                stop: "這一件物品放好後就停。",
                why: "先準備一件物品，跑腿會更容易繼續。",
                baseMinutes: 7
            )
        case .other:
            return genericStep(intent)
        }
    }

    static func japaneseDomainStep(intent: TaskIntent, category: TaskCategory) -> ComposedStep {
        let target = japaneseObject(intent, fallback: "このこと")
        switch category {
        case .bills:
            return ComposedStep(
                title: "請求書を見つける",
                step: "メールを開いて、\(target)に関係する請求書か支払いのお知らせを探しましょう。",
                stop: "合う請求書かお知らせがひとつ見えたら止めましょう。まだ支払わなくて大丈夫です。",
                why: "金額か期限が分かると、次の一歩がはっきりします。",
                baseMinutes: 10
            )
        case .email:
            if intent.verb == "返信" || intent.verb == "送信" {
                return ComposedStep(
                    title: "最初の一文を書く",
                    step: "\(target)に関係するメールを開いて、最初の一文だけ書きましょう。まだ送らなくて大丈夫です。",
                    stop: "一文書けたら止めましょう。送信はあとで大丈夫です。",
                    why: "下書きはいつでも直せるので、戻れる始め方です。",
                    baseMinutes: 10
                )
            }
            return ComposedStep(
                title: "関係するメールを1通開く",
                step: "受信トレイを開いて、\(target)に関係するメールを1通見つけましょう。",
                stop: "その1通を開いたら止めましょう。",
                why: "メールが1通目の前にあれば、入り口がはっきりします。",
                baseMinutes: 8
            )
        case .appointments:
            return ComposedStep(
                title: "予約の候補をひとつ見つける",
                step: "カレンダーか相手のページを開いて、\(target)に関係する日付か時間をひとつ見つけましょう。",
                stop: "日付か時間がひとつ見えたら止めましょう。まだ予約しなくて大丈夫です。",
                why: "候補がひとつ見えると、予約を決めやすくなります。",
                baseMinutes: 10
            )
        case .returns:
            return ComposedStep(
                title: "返品の案内を見つける",
                step: "\(target)の注文内容を開いて、返品の説明かラベルを見つけましょう。",
                stop: "返品の説明かラベルがひとつ見えたら止めましょう。",
                why: "まず案内が見つかれば十分です。梱包も発送もあとで大丈夫です。",
                baseMinutes: 10
            )
        case .insurance:
            return ComposedStep(
                title: "保険の情報をひとつ見つける",
                step: "\(target)に関係する保険の記録を開いて、期限か次に必要なことを見つけましょう。",
                stop: "日付か必要なことがひとつ見えたら止めましょう。",
                why: "事実がひとつ分かると、次の一歩が具体的になります。",
                baseMinutes: 10
            )
        case .banking:
            return ComposedStep(
                title: "関係する口座を開く",
                step: "銀行アプリを開いて、\(target)に関係する口座か金額を見つけましょう。まだ振込はしなくて大丈夫です。",
                stop: "関係する口座か金額が見えたら止めましょう。",
                why: "事実をひとつ確かめるだけなら、最初の一歩はいつでも戻せます。",
                baseMinutes: 10
            )
        case .taxes:
            return ComposedStep(
                title: "税金の書類を1つ見つける",
                step: "税金のフォルダかサイトを開いて、今年の関係する書類を1つ目の前に出しましょう。",
                stop: "関係する書類が1つ見えたら止めましょう。",
                why: "書類が1つ見えれば十分です。税金の作業全体を開かなくて大丈夫です。",
                baseMinutes: 12
            )
        case .household, .cleaning:
            return ComposedStep(
                title: "小さな場所をひとつ片づける",
                step: "\(target)に関係する小さな場所をひとつ選んで、そこだけ片づけましょう。",
                stop: "その小さな場所が片づいたら止めましょう。",
                why: "場所を区切ると、家事は始めやすく、終わらせやすくなります。",
                baseMinutes: 10
            )
        case .familyAdmin, .workAdmin, .school:
            return ComposedStep(
                title: "関係するものを開く",
                step: "\(target)に関係する書類かファイル、メッセージを開いて、最初の項目を読みましょう。",
                stop: "最初の項目が読めたら止めましょう。",
                why: "最初の項目だけ分かれば十分です。全部を今日終えなくて大丈夫です。",
                baseMinutes: 10
            )
        case .medical:
            return ComposedStep(
                title: "事実をひとつ見つける",
                step: "\(target)に関係する医院や処方、健康の記録を開いて、事実をひとつ見つけましょう。",
                stop: "事実がひとつ見えたら止めましょう。ここで医療の判断はしません。",
                why: "事実を整えるところまでです。医療的な助言はしません。",
                baseMinutes: 10
            )
        case .errands:
            return ComposedStep(
                title: "持ち物をひとつ用意する",
                step: "\(target)に関係するものをひとつ、玄関か使う場所に置きましょう。",
                stop: "そのひとつを置いたら止めましょう。",
                why: "ものがひとつ用意できていると、用事は続けやすくなります。",
                baseMinutes: 7
            )
        case .other:
            return genericStep(intent)
        }
    }

    static func koreanDomainStep(intent: TaskIntent, category: TaskCategory) -> ComposedStep {
        // The slot follows a noun (`\(target) 관련`) rather than a particle, so no
        // 은/는 or 을/를 has to agree with the last syllable of the object.
        let target = koreanObject(intent, fallback: "이 일")
        switch category {
        case .bills:
            return ComposedStep(
                title: "청구서 찾기",
                step: "메일을 열고 \(target) 관련 청구서나 결제 안내를 찾아보세요.",
                stop: "맞는 청구서나 안내가 하나 보이면 멈춰요. 아직 결제하지 않아도 돼요.",
                why: "금액이나 기한을 알면 다음 걸음이 분명해져요.",
                baseMinutes: 10
            )
        case .email:
            return ComposedStep(
                title: "관련 메일 하나 열기",
                step: "받은편지함을 열고 \(target) 관련 메일을 하나 찾아보세요.",
                stop: "그 메일을 열면 멈춰요.",
                why: "메일 하나가 눈앞에 있으면 시작할 곳이 분명해져요.",
                baseMinutes: 8
            )
        case .appointments:
            return ComposedStep(
                title: "예약 후보 하나 찾기",
                step: "캘린더나 상대방 페이지를 열고 \(target) 관련 날짜나 시간을 하나 찾아보세요.",
                stop: "날짜나 시간이 하나 보이면 멈춰요. 아직 예약하지 않아도 돼요.",
                why: "후보가 하나 보이면 예약을 정하기 쉬워져요.",
                baseMinutes: 10
            )
        case .returns:
            return ComposedStep(
                title: "반품 안내 찾기",
                step: "\(target) 관련 주문 내역을 열고 반품 방법이나 라벨을 찾아보세요.",
                stop: "반품 방법이나 라벨이 하나 보이면 멈춰요.",
                why: "먼저 안내만 찾으면 충분해요. 포장과 발송은 나중에 해도 돼요.",
                baseMinutes: 10
            )
        case .insurance:
            return ComposedStep(
                title: "보험 정보 하나 찾기",
                step: "\(target) 관련 보험 기록을 열고 기한이나 다음에 필요한 것을 찾아보세요.",
                stop: "날짜나 필요한 것이 하나 보이면 멈춰요.",
                why: "사실 하나를 알면 다음 걸음이 구체적이 돼요.",
                baseMinutes: 10
            )
        case .banking:
            return ComposedStep(
                title: "관련 계좌 열기",
                step: "은행 앱을 열고 \(target) 관련 계좌나 금액을 찾아보세요. 아직 이체하지 않아도 돼요.",
                stop: "관련 계좌나 금액이 보이면 멈춰요.",
                why: "사실 하나만 확인하는 거라 첫 걸음은 언제든 되돌릴 수 있어요.",
                baseMinutes: 10
            )
        case .taxes:
            return ComposedStep(
                title: "세금 서류 하나 찾기",
                step: "세금 폴더나 사이트를 열고 올해 관련 서류 하나를 눈앞에 꺼내 보세요.",
                stop: "관련 서류가 하나 보이면 멈춰요.",
                why: "서류 하나가 보이면 충분해요. 세금 작업 전체를 열지 않아도 돼요.",
                baseMinutes: 12
            )
        case .household, .cleaning:
            return ComposedStep(
                title: "작은 공간 하나 치우기",
                step: "\(target) 관련 작은 공간을 하나 골라 그곳만 치워 보세요.",
                stop: "그 작은 공간이 정리되면 멈춰요.",
                why: "공간을 나누면 집안일은 시작하기도, 끝내기도 쉬워져요.",
                baseMinutes: 10
            )
        case .familyAdmin, .workAdmin, .school:
            return ComposedStep(
                title: "관련 자료 열기",
                step: "\(target) 관련 서류나 파일, 메시지를 열고 첫 항목을 읽어 보세요.",
                stop: "첫 항목을 읽으면 멈춰요.",
                why: "첫 항목만 알면 충분해요. 오늘 전부 끝내지 않아도 돼요.",
                baseMinutes: 10
            )
        case .medical:
            return ComposedStep(
                title: "사실 하나 찾기",
                step: "\(target) 관련 병원, 처방, 건강 기록을 열고 사실 하나를 찾아보세요.",
                stop: "사실이 하나 보이면 멈춰요. 여기서 의학적 판단은 하지 않아요.",
                why: "사실을 정리하는 데까지만 해요. 의학적 조언은 하지 않아요.",
                baseMinutes: 10
            )
        case .errands:
            return ComposedStep(
                title: "챙길 것 하나 준비하기",
                step: "\(target) 관련해서 필요한 것을 하나, 현관이나 쓸 곳에 놓아 두세요.",
                stop: "그것 하나를 놓아 뒀으면 멈춰요.",
                why: "물건이 하나 준비돼 있으면 볼일을 이어 가기 쉬워요.",
                baseMinutes: 7
            )
        case .other:
            return genericStep(intent)
        }
    }

    static func genericStep(_ intent: TaskIntent) -> ComposedStep {
        let lang = language(intent)
        let fallbackAction = lang.pick(en: "this task", zh: "这件事", zhHant: "這件事", ja: "このこと", ko: "이 일")
        let action = intent.actionPhrase.isEmpty ? fallbackAction : intent.actionPhrase
        switch lang {
        case .zhHans:
            return ComposedStep(
                title: "查找“\(action)”的官方指南",
                step: "打开浏览器，搜索准确短语“\(action)”和“官方指南”，打开一个相关结果。",
                stop: "看到指南的第一条说明就停。",
                why: "先找到一个与这件事直接相关的可靠起点，不要求继续执行。",
                baseMinutes: 5
            )
        case .zhHant:
            return ComposedStep(
                title: "查詢「\(action)」的官方指南",
                step: "開啟瀏覽器，搜尋準確短語「\(action)」和「官方指南」，開啟一個相關結果。",
                stop: "看到指南的第一條說明就停。",
                why: "先找到一個與這件事直接相關的可靠起點，不要求繼續執行。",
                baseMinutes: 5
            )
        case .ja:
            return ComposedStep(
                title: "「\(action)」の公式な案内を探す",
                step: "ブラウザを開いて、「\(action)」と「公式」で検索し、関係のありそうな結果をひとつ開きましょう。",
                stop: "案内の最初の手順が見えたら止めましょう。",
                why: "関係のある案内がひとつあれば、慣れないことでも落ち着いた出発点になります。",
                baseMinutes: 5
            )
        case .ko:
            return ComposedStep(
                title: "“\(action)” 공식 안내 찾기",
                step: "브라우저를 열고 “\(action)”과 “공식”으로 검색한 뒤, 관련 있어 보이는 결과 하나를 열어 보세요.",
                stop: "안내의 첫 단계가 보이면 멈춰요.",
                why: "관련된 안내가 하나 있으면 낯선 일도 차분하게 시작할 수 있어요.",
                baseMinutes: 5
            )
        case .en:
            break
        }
        return ComposedStep(
            title: "Find an official guide for “\(action)”",
            step: "Open a browser, search the exact phrase “\(action)” plus “official guide”, and open one relevant result.",
            stop: "Stop when the guide’s first instruction is visible.",
            why: "A relevant guide gives an unfamiliar task a concrete, low-pressure starting point.",
            baseMinutes: 5
        )
    }

    static func isAdministrativeRepair(_ intent: TaskIntent, category: TaskCategory) -> Bool {
        guard [.bills, .email, .appointments, .returns, .insurance, .banking, .taxes, .familyAdmin, .medical, .workAdmin, .school].contains(category) else {
            return false
        }
        let text = [intent.object, intent.context, intent.actionPhrase]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let administrativeAnchors = [
            "bill", "payment", "invoice", "account", "claim", "insurance", "form",
            "email", "message", "appointment", "booking", "tax", "report", "school",
            "账单", "付款", "发票", "账户", "保险", "表格", "邮件", "预约", "税",
            "請求", "支払", "口座", "保険", "書類", "メール", "予約", "税金", "申請",
            "賬單", "付款", "發票", "帳戶", "保險", "郵件", "預約", "稅",
            "청구서", "결제", "계좌", "보험", "서류", "메일", "예약", "세금", "신청"
        ]
        return administrativeAnchors.contains(where: text.contains)
    }

    static func language(_ intent: TaskIntent) -> ContentLanguage {
        ContentLanguage(intent.language)
    }

    static func englishCoreObject(_ intent: TaskIntent, fallback: String) -> String {
        intent.object ?? fallback
    }

    static func englishObject(_ intent: TaskIntent, fallback: String) -> String {
        guard let phrase = intent.objectPhrase ?? intent.object, !phrase.isEmpty else {
            return fallback
        }
        let lower = phrase.lowercased()
        let startsWithDeterminer = [
            "a ", "an ", "the ", "my ", "our ", "your ", "his ", "her ", "their ",
            "this ", "that ", "these ", "those "
        ].contains(where: lower.hasPrefix)
        return startsWithDeterminer ? phrase : "the \(phrase)"
    }

    static func chineseObject(_ intent: TaskIntent, fallback: String) -> String {
        intent.objectPhrase ?? intent.object ?? fallback
    }

    /// Japanese, like Chinese, takes the object as-is: there is no article to
    /// prepend, and the templates supply the particle around it.
    static func japaneseObject(_ intent: TaskIntent, fallback: String) -> String {
        intent.objectPhrase ?? intent.object ?? fallback
    }

    /// Korean, like Japanese, takes the object as-is.
    static func koreanObject(_ intent: TaskIntent, fallback: String) -> String {
        intent.objectPhrase ?? intent.object ?? fallback
    }

    static func possessive(_ object: String) -> String {
        let value = object
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "my ", with: "")
            .replacingOccurrences(of: "your ", with: "")
        return value.hasSuffix("s") ? "the \(value)'" : "the \(value)'s"
    }
}
