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
        let zh = language.lowercased().hasPrefix("zh")
        return [
            MicroTemplate(
                id: "bill_anchor",
                titleKey: "template.bill.title",
                subtitleKey: "template.bill.subtitle",
                systemImage: "doc.text.fill",
                proposal: NextStepProposal(
                    title: zh ? "账单先只找入口" : "Find the bill entry point",
                    step: zh ? "打开一个可能有账单的地方，只找付款入口或金额。" : "Open one place where the bill might be, and only look for the amount or pay button.",
                    timerMinutes: 5,
                    stopCondition: zh ? "看到金额、付款入口或卡住点就停。" : "Stop when you see the amount, the pay button, or the blocker.",
                    category: .bills,
                    shrinkLevel: .one,
                    whyThisStep: zh ? "先找到入口，不用一次完成付款。" : "Finding the entry point is enough to create movement."
                )
            ),
            MicroTemplate(
                id: "email_reply",
                titleKey: "template.email.title",
                subtitleKey: "template.email.subtitle",
                systemImage: "envelope.fill",
                proposal: NextStepProposal(
                    title: zh ? "只写一句回复" : "Write one reply sentence",
                    step: zh ? "打开那封邮件，只写第一句回复草稿。" : "Open the email and write only the first sentence of a reply draft.",
                    timerMinutes: 5,
                    stopCondition: zh ? "写完第一句就停，不用发送。" : "Stop after one sentence. Sending can wait.",
                    category: .email,
                    shrinkLevel: .one,
                    whyThisStep: zh ? "草稿比发送轻很多，更容易开始。" : "A draft is lighter than sending, which makes starting easier."
                )
            ),
            MicroTemplate(
                id: "appointment_call",
                titleKey: "template.appointment.title",
                subtitleKey: "template.appointment.subtitle",
                systemImage: "calendar.badge.clock",
                proposal: NextStepProposal(
                    title: zh ? "找预约方式" : "Find how to book",
                    step: zh ? "只找到预约页面、电话或诊所名称。" : "Find only the booking page, phone number, or office name.",
                    timerMinutes: 7,
                    stopCondition: zh ? "找到一个联系方式就停。" : "Stop when you have one way to contact them.",
                    category: .appointments,
                    shrinkLevel: .one,
                    whyThisStep: zh ? "把预约拆成找入口，不要求马上预约成功。" : "Booking starts with finding the doorway, not finishing the appointment."
                )
            ),
            MicroTemplate(
                id: "document_hunt",
                titleKey: "template.document.title",
                subtitleKey: "template.document.subtitle",
                systemImage: "folder.fill",
                proposal: NextStepProposal(
                    title: zh ? "找一个文件线索" : "Find one document clue",
                    step: zh ? "打开一个文件夹、邮箱或照片相册，只找一个相关线索。" : "Open one folder, inbox, or photo album and look for one related clue.",
                    timerMinutes: 5,
                    stopCondition: zh ? "找到线索或确认不在这里就停。" : "Stop when you find a clue or confirm it is not there.",
                    category: .workAdmin,
                    shrinkLevel: .one,
                    whyThisStep: zh ? "文件任务通常卡在搜索范围太大，先缩小一个地方。" : "Document tasks often stall because the search area is too wide."
                )
            ),
            MicroTemplate(
                id: "home_reset",
                titleKey: "template.home.title",
                subtitleKey: "template.home.subtitle",
                systemImage: "house.fill",
                proposal: NextStepProposal(
                    title: zh ? "清出一个小表面" : "Clear one small surface",
                    step: zh ? "选一个手掌大的区域，只拿走三样东西。" : "Pick a hand-sized area and move only three things away.",
                    timerMinutes: 5,
                    stopCondition: zh ? "三样东西离开那个区域就停。" : "Stop when three things leave that spot.",
                    category: .household,
                    shrinkLevel: .one,
                    whyThisStep: zh ? "一个看得见的变化比完整打扫更容易启动。" : "A visible change is easier to start than a full clean-up."
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
