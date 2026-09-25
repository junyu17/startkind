import Foundation

struct MicroTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let titleKey: String
    let subtitleKey: String
    let systemImage: String
    let proposal: NextStepProposal
}

enum MicroTemplateLibrary {
    static func templates(language: String) -> [MicroTemplate] {
        let lang = ContentLanguage(language)
        return [
            MicroTemplate(
                id: "bill_anchor",
                titleKey: "template.bill.title",
                subtitleKey: "template.bill.subtitle",
                systemImage: "doc.text.fill",
                proposal: NextStepProposal(
                    title: lang.pick(
                        en: "Find the bill entry point",
                        zh: "账单先只找入口",
                        ja: "請求書の入り口を見つける"
                    ),
                    step: lang.pick(
                        en: "Open one place where the bill might be, and only look for the amount or pay button.",
                        zh: "打开一个可能有账单的地方，只找付款入口或金额。",
                        ja: "請求書がありそうな場所をひとつ開いて、金額か支払いボタンだけを探しましょう。"
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when you see the amount, the pay button, or the blocker.",
                        zh: "看到金额、付款入口或卡住点就停。",
                        ja: "金額か支払いボタン、または引っかかっている点が見えたら止めましょう。"
                    ),
                    category: .bills,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Finding the entry point is enough to create movement.",
                        zh: "先找到入口，不用一次完成付款。",
                        ja: "入り口が見つかれば十分です。支払いまで終える必要はありません。"
                    )
                )
            ),
            MicroTemplate(
                id: "email_reply",
                titleKey: "template.email.title",
                subtitleKey: "template.email.subtitle",
                systemImage: "envelope.fill",
                proposal: NextStepProposal(
                    title: lang.pick(
                        en: "Write one reply sentence",
                        zh: "只写一句回复",
                        ja: "返信を一文だけ書く"
                    ),
                    step: lang.pick(
                        en: "Open the email and write only the first sentence of a reply draft.",
                        zh: "打开那封邮件，只写第一句回复草稿。",
                        ja: "そのメールを開いて、返信の下書きの最初の一文だけを書きましょう。"
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop after one sentence. Sending can wait.",
                        zh: "写完第一句就停，不用发送。",
                        ja: "一文書けたら止めましょう。送信はあとで大丈夫です。"
                    ),
                    category: .email,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "A draft is lighter than sending, which makes starting easier.",
                        zh: "草稿比发送轻很多，更容易开始。",
                        ja: "下書きは送信よりずっと軽いので、始めやすくなります。"
                    )
                )
            ),
            MicroTemplate(
                id: "appointment_call",
                titleKey: "template.appointment.title",
                subtitleKey: "template.appointment.subtitle",
                systemImage: "calendar.badge.clock",
                proposal: NextStepProposal(
                    title: lang.pick(
                        en: "Find how to book",
                        zh: "找预约方式",
                        ja: "予約の方法を見つける"
                    ),
                    step: lang.pick(
                        en: "Find only the booking page, phone number, or office name.",
                        zh: "只找到预约页面、电话或诊所名称。",
                        ja: "予約ページか電話番号、または医院の名前だけを見つけましょう。"
                    ),
                    timerMinutes: 7,
                    stopCondition: lang.pick(
                        en: "Stop when you have one way to contact them.",
                        zh: "找到一个联系方式就停。",
                        ja: "連絡する方法がひとつ分かったら止めましょう。"
                    ),
                    category: .appointments,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Booking starts with finding the doorway, not finishing the appointment.",
                        zh: "把预约拆成找入口，不要求马上预约成功。",
                        ja: "予約は入り口を見つけるところから始まります。今日中に取り切らなくて大丈夫です。"
                    )
                )
            ),
            MicroTemplate(
                id: "document_hunt",
                titleKey: "template.document.title",
                subtitleKey: "template.document.subtitle",
                systemImage: "folder.fill",
                proposal: NextStepProposal(
                    title: lang.pick(
                        en: "Find one document clue",
                        zh: "找一个文件线索",
                        ja: "書類の手がかりをひとつ見つける"
                    ),
                    step: lang.pick(
                        en: "Open one folder, inbox, or photo album and look for one related clue.",
                        zh: "打开一个文件夹、邮箱或照片相册，只找一个相关线索。",
                        ja: "フォルダか受信トレイ、写真アルバムをひとつ開いて、関係のありそうな手がかりをひとつ探しましょう。"
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when you find a clue or confirm it is not there.",
                        zh: "找到线索或确认不在这里就停。",
                        ja: "手がかりが見つかるか、ここには無いと分かったら止めましょう。"
                    ),
                    category: .workAdmin,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Document tasks often stall because the search area is too wide.",
                        zh: "文件任务通常卡在搜索范围太大，先缩小一个地方。",
                        ja: "書類さがしは範囲が広すぎて止まりがちです。まず一か所に絞りましょう。"
                    )
                )
            ),
            MicroTemplate(
                id: "home_reset",
                titleKey: "template.home.title",
                subtitleKey: "template.home.subtitle",
                systemImage: "house.fill",
                proposal: NextStepProposal(
                    title: lang.pick(
                        en: "Clear one small surface",
                        zh: "清出一个小表面",
                        ja: "小さな場所をひとつ片づける"
                    ),
                    step: lang.pick(
                        en: "Pick a hand-sized area and move only three things away.",
                        zh: "选一个手掌大的区域，只拿走三样东西。",
                        ja: "手のひらくらいの範囲をひとつ選んで、3つだけどかしましょう。"
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when three things leave that spot.",
                        zh: "三样东西离开那个区域就停。",
                        ja: "3つどかせたら止めましょう。"
                    ),
                    category: .household,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "A visible change is easier to start than a full clean-up.",
                        zh: "一个看得见的变化比完整打扫更容易启动。",
                        ja: "目に見える変化がひとつあるほうが、全部を片づけるより始めやすくなります。"
                    )
                )
            ),
            MicroTemplate(
                id: "bad_day_reset",
                titleKey: "template.badDay.title",
                subtitleKey: "template.badDay.subtitle",
                systemImage: "heart.circle.fill",
                proposal: NextStepEngine.badDayProposal(language: language, preferred: nil)
            )
        ]
    }
}
