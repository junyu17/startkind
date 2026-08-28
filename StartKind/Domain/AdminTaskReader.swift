import Foundation

/// Local Admin Task Reader.
///
/// Extracts actionable facts (amount, contact, link, due date, required docs)
/// from pasted administrative text and produces one next step. This is the
/// offline fallback / Free "Admin Quick Start"; Plus uses cloud AI via the
/// AIClient for deeper parsing (see `docs/PRODUCT_REQUIREMENTS.md` §6).
struct AdminTaskReader: Sendable {
    init() {}

    func parse(text: String, language: String) -> AdminParseResult {
        let zh = language.lowercased().hasPrefix("zh")
        let artifact = detectArtifactType(in: text)
        let amount = firstMatch(in: text, pattern: #"(?:\$|USD\s?|￥|¥)\s?\d[\d,]*\.?\d*"#)
        let phone = firstMatch(in: text, pattern: #"\+?\d[\d\-\.\s]{7,}\d"#)
        let url = firstMatch(in: text, pattern: #"https?://[^\s]+|www\.[^\s]+"#)
        let contact = firstMatch(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: .caseInsensitive)
        let dueDate = parseDueDate(in: text)

        var missing: [String] = []
        if dueDate == nil { missing.append(zh ? "截止日期" : "due date") }
        if amount == nil && artifact == .bill { missing.append(zh ? "金额" : "amount") }

        let requiredDocs = requiredDocuments(for: artifact, zh: zh)
        let nextStep = oneNextStep(for: artifact, missingInfo: missing, zh: zh)

        let extractedCount = [amount, phone, url, contact].compactMap { $0 }.count + (dueDate == nil ? 0 : 1)
        let confidence = min(0.9, 0.3 + Double(extractedCount) * 0.15)

        return AdminParseResult(
            artifactType: artifact,
            dueDate: dueDate,
            amount: amount,
            contact: contact ?? phone,
            linkOrPhone: url ?? phone,
            requiredDocuments: requiredDocs,
            oneNextStep: nextStep,
            confidence: confidence,
            missingInfo: missing
        )
    }

    // MARK: - Helpers

    private func detectArtifactType(in text: String) -> AdminArtifactType {
        let lower = text.lowercased()
        let rules: [(AdminArtifactType, [String])] = [
            (.bill, ["bill", "invoice", "amount due", "payment due", "账单", "发票", "缴费"]),
            (.insurance, ["insurance", "claim", "policy", "保险", "理赔", "保单"]),
            (.banking, ["bank", "transfer", "deposit", "银行", "转账", "存款"]),
            (.appointment, ["appointment", "scheduled", "booking", "预约", "挂号"]),
            (.return, ["return", "refund", "退货", "退款"]),
            (.medical, ["medical", "prescription", "diagnosis", "医疗", "处方", "诊断"]),
            (.school, ["school", "enrollment", "registration", "学校", "报名", "注册"]),
            (.household, ["repair", "maintenance", "household", "维修", "物业"]),
            (.email, ["email", "邮件"])
        ]
        for (type, keywords) in rules {
            if keywords.contains(where: { lower.contains($0) }) { return type }
        }
        return .other
    }

    private func firstMatch(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: range), m.range.location != NSNotFound,
              let r = Range(m.range, in: text) else { return nil }
        return String(text[r]).trimmingCharacters(in: .whitespaces)
    }

    private func parseDueDate(in text: String) -> Date? {
        let lower = text.lowercased()
        guard lower.contains("due") || lower.contains("by ") || lower.contains("deadline")
                || lower.contains("截止") || lower.contains("到期") || lower.contains("前") else {
            return nil
        }
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "MMM d, yyyy", "d MMM yyyy"]
        let datePattern = #"\d{1,2}[/\-]\d{1,2}([/\-]\d{2,4})?|\d{4}-\d{2}-\d{2}|[A-Z][a-z]{2,9}\.?\s?\d{1,2},?\s?\d{4}"#
        guard let candidate = firstMatch(in: text, pattern: datePattern, options: .caseInsensitive) else { return nil }
        for fmt in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let date = df.date(from: candidate) { return date }
        }
        return nil
    }

    private func requiredDocuments(for type: AdminArtifactType, zh: Bool) -> [String] {
        switch type {
        case .bill:
            return zh ? ["账单邮件或截图", "付款方式"] : ["bill email or screenshot", "payment method"]
        case .insurance:
            return zh ? ["保单号", "理赔单"] : ["policy number", "claim form"]
        case .banking:
            return zh ? ["账号", "身份验证方式"] : ["account number", "verification method"]
        case .medical:
            return zh ? ["保险卡", "诊所信息"] : ["insurance card", "clinic info"]
        case .appointment:
            return zh ? ["日历", "联系方式"] : ["calendar", "contact info"]
        default:
            return []
        }
    }

    private func oneNextStep(for type: AdminArtifactType, missingInfo: [String], zh: Bool) -> NextStepProposal {
        let hasMissing = !missingInfo.isEmpty
        let title: String
        let step: String
        let stop: String
        if hasMissing {
            title = zh ? "先找到缺失的信息" : "Find the missing info"
            let list = missingInfo.joined(separator: zh ? "、" : " and ")
            step = zh ? "打开这条信息，找到\(list)。" : "Open this message and find the \(list)."
            stop = zh ? "找到后就停，不用做别的。" : "Stop once you see it - no action needed yet."
        } else {
            switch type {
            case .bill:
                title = zh ? "确认金额和截止日" : "Confirm amount and due date"
                step = zh ? "打开账单，看清金额和截止日期。" : "Open the bill and read the amount and due date."
                stop = zh ? "看清两者就停。" : "Stop when you can see both."
            case .appointment:
                title = zh ? "看清预约时间" : "See the appointment time"
                step = zh ? "打开预约信息，看清日期和时间。" : "Open the appointment and see the date and time."
                stop = zh ? "看清就停。" : "Stop once you can see it."
            default:
                title = zh ? "读一遍关键信息" : "Read the key info"
                step = zh ? "打开这条信息，读一遍关键部分。" : "Open this and read the key part once."
                stop = zh ? "读一遍就停。" : "Stop after one read-through."
            }
        }
        return NextStepProposal(
            title: title,
            step: step,
            timerMinutes: 5,
            stopCondition: stop,
            category: .other,
            shrinkLevel: .one,
            generatedBy: .localTemplate
        )
    }
}
