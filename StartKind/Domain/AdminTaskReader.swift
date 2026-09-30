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
        let lang = ContentLanguage(language)
        let artifact = detectArtifactType(in: text)
        let amount = firstMatch(in: text, pattern: #"(?:\$|USD\s?|￥|¥)\s?\d[\d,]*\.?\d*|\d[\d,]*(?:\.\d+)?\s?[円원]"#)
        let phone = firstMatch(in: text, pattern: #"\+?\d[\d\-\.\s]{7,}\d"#)
        let url = firstMatch(in: text, pattern: #"https?://[^\s]+|www\.[^\s]+"#)
        let contact = firstMatch(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: .caseInsensitive)
        let dueDate = parseDueDate(in: text)

        var missing: [String] = []
        if dueDate == nil {
            missing.append(lang.pick(en: "due date", zh: "截止日期", zhHant: "截止日期", ja: "期限", ko: "기한"))
        }
        if amount == nil && artifact == .bill {
            missing.append(lang.pick(en: "amount", zh: "金额", zhHant: "金額", ja: "金額", ko: "금액"))
        }

        let requiredDocs = requiredDocuments(for: artifact, language: lang)
        let nextStep = oneNextStep(for: artifact, missingInfo: missing, language: lang)

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
            (.bill, ["bill", "invoice", "amount due", "payment due", "账单", "发票", "缴费", "請求書", "請求", "支払", "料金", "光熱費", "納付", "賬單", "發票", "繳費", "청구서", "고지서", "납부", "요금", "공과금", "청구"]),
            (.insurance, ["insurance", "claim", "policy", "保险", "理赔", "保单", "保険", "保険金", "給付", "保險", "理賠", "保單", "보험", "보험금", "청구 서류"]),
            (.banking, ["bank", "transfer", "deposit", "银行", "转账", "存款", "銀行", "口座", "振込", "入金", "轉帳", "存款", "은행", "계좌", "이체", "입금"]),
            (.appointment, ["appointment", "scheduled", "booking", "预约", "挂号", "予約", "診察", "来院", "面談", "預約", "掛號", "예약", "진료", "방문", "면담"]),
            (.return, ["return", "refund", "退货", "退款", "返品", "返金", "返送", "退貨", "반품", "환불", "반송"]),
            (.medical, ["medical", "prescription", "diagnosis", "医疗", "处方", "诊断", "処方箋", "処方", "診断", "薬局", "醫療", "處方", "診斷", "의료", "처방", "진단", "약국"]),
            (.school, ["school", "enrollment", "registration", "学校", "报名", "注册", "入学", "登録", "同意書", "連絡帳", "註冊", "學校", "報名", "학교", "등록", "입학", "동의서", "가정통신문"]),
            (.household, ["repair", "maintenance", "household", "维修", "物业", "修理", "点検", "管理組合", "維修", "物業", "수리", "점검", "관리사무소", "관리비"]),
            (.email, ["email", "邮件", "郵件", "メール", "이메일", "메일"])
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

    private func parseDueDate(in text: String, now: Date = .now) -> Date? {
        let lower = text.lowercased()
        let dueCues = [
            "due", "by ", "deadline",
            "截止", "到期", "前",
            // Korean.
            "기한", "마감", "까지", "납부일",
            // Japanese. `まで` is broad, but it is how a deadline is actually
            // written, and it is no broader than the `前` cue above.
            "締切", "締め切り", "期限", "まで", "納期"
        ]
        guard dueCues.contains(where: { lower.contains($0) }) else {
            return nil
        }
        // The full Japanese form is listed first so the leftmost match keeps its
        // year: matching `10月10日` first would silently drop the `2026年`.
        let datePattern = #"\d{4}年\s?\d{1,2}月\s?\d{1,2}日|\d{1,2}月\s?\d{1,2}日|\d{4}년\s?\d{1,2}월\s?\d{1,2}일|\d{1,2}월\s?\d{1,2}일|\d{1,2}[/\-]\d{1,2}([/\-]\d{2,4})?|\d{4}-\d{2}-\d{2}|[A-Z][a-z]{2,9}\.?\s?\d{1,2},?\s?\d{4}"#
        guard let candidate = firstMatch(in: text, pattern: datePattern, options: .caseInsensitive) else { return nil }

        if candidate.contains("月") {
            return parseJapaneseDate(candidate, now: now)
        }
        // Korean writes the same shape with 년 / 월 / 일, so it reuses the parser.
        if candidate.contains("월") {
            let kanji = candidate
                .replacingOccurrences(of: "년", with: "年")
                .replacingOccurrences(of: "월", with: "月")
                .replacingOccurrences(of: "일", with: "日")
            return parseJapaneseDate(kanji, now: now)
        }
        let formats = ["M/d/yyyy", "MM/dd/yyyy", "yyyy-MM-dd", "MMM d, yyyy", "d MMM yyyy"]
        for fmt in formats {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = fmt
            if let date = df.date(from: candidate) { return date }
        }
        return nil
    }

    /// `2026年10月10日`, or `10月10日` with the year left off - which is the
    /// common form on a Japanese bill. A bare month/day is read as the current
    /// year, the same assumption a person reading the notice would make.
    private func parseJapaneseDate(_ candidate: String, now: Date) -> Date? {
        let normalized = candidate.replacingOccurrences(of: " ", with: "")
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.calendar = Calendar(identifier: .gregorian)
        if normalized.contains("年") {
            df.dateFormat = "yyyy年M月d日"
            return df.date(from: normalized)
        }
        let year = Calendar(identifier: .gregorian).component(.year, from: now)
        df.dateFormat = "yyyy年M月d日"
        return df.date(from: "\(year)年\(normalized)")
    }

    private func requiredDocuments(for type: AdminArtifactType, language: ContentLanguage) -> [String] {
        switch type {
        case .bill:
            switch language {
            case .en: return ["bill email or screenshot", "payment method"]
            case .zhHans: return ["账单邮件或截图", "付款方式"]
            case .zhHant: return ["帳單郵件或截圖", "付款方式"]
            case .ja: return ["請求書のメールかスクリーンショット", "支払い方法"]
            case .ko: return ["청구서 이메일이나 스크린샷", "결제 수단"]
            }
        case .insurance:
            switch language {
            case .en: return ["policy number", "claim form"]
            case .zhHans: return ["保单号", "理赔单"]
            case .zhHant: return ["保單號", "理賠單"]
            case .ja: return ["保険証券番号", "保険金請求書"]
            case .ko: return ["보험증권 번호", "보험금 청구서"]
            }
        case .banking:
            switch language {
            case .en: return ["account number", "verification method"]
            case .zhHans: return ["账号", "身份验证方式"]
            case .zhHant: return ["帳號", "身分驗證方式"]
            case .ja: return ["口座番号", "本人確認の方法"]
            case .ko: return ["계좌번호", "본인 확인 방법"]
            }
        case .medical:
            switch language {
            case .en: return ["insurance card", "clinic info"]
            case .zhHans: return ["保险卡", "诊所信息"]
            case .zhHant: return ["保險卡", "診所資訊"]
            case .ja: return ["保険証", "クリニックの情報"]
            case .ko: return ["보험증", "병원 정보"]
            }
        case .appointment:
            switch language {
            case .en: return ["calendar", "contact info"]
            case .zhHans: return ["日历", "联系方式"]
            case .zhHant: return ["行事曆", "聯絡方式"]
            case .ja: return ["カレンダー", "連絡先"]
            case .ko: return ["캘린더", "연락처"]
            }
        default:
            return []
        }
    }

    private func oneNextStep(for type: AdminArtifactType, missingInfo: [String], language: ContentLanguage) -> NextStepProposal {
        let hasMissing = !missingInfo.isEmpty
        let title: String
        let step: String
        let stop: String
        if hasMissing {
            title = language.pick(
                en: "Find the missing info",
                zh: "先找到缺失的信息",
                zhHant: "先找到缺失的資訊",
                ja: "不足している情報を見つける",
                ko: "빠진 정보 찾기"
            )
            let list = missingInfo.joined(
                separator: language.pick(en: " and ", zh: "、", zhHant: "、", ja: "と", ko: ", ")
            )
            step = language.pick(
                en: "Open this message and find the \(list).",
                zh: "打开这条信息，找到\(list)。",
                zhHant: "開啟這條資訊，找到\(list)。",
                ja: "このメッセージを開いて、\(list)を見つけましょう。",
                ko: "이 메시지를 열고 찾아보세요: \(list)."
            )
            stop = language.pick(
                en: "Stop once you see it - no action needed yet.",
                zh: "找到后就停，不用做别的。",
                zhHant: "找到後就停，不用做別的。",
                ja: "見つかったら止めて大丈夫です。まだ何もしなくて構いません。",
                ko: "찾으면 거기서 멈춰도 돼요. 아직 아무것도 안 해도 괜찮아요."
            )
        } else {
            switch type {
            case .bill:
                title = language.pick(
                    en: "Confirm amount and due date",
                    zh: "确认金额和截止日",
                    zhHant: "確認金額和截止日",
                    ja: "金額と期限を確認する",
                    ko: "금액과 기한 확인하기"
                )
                step = language.pick(
                    en: "Open the bill and read the amount and due date.",
                    zh: "打开账单，看清金额和截止日期。",
                    zhHant: "開啟帳單，看清金額和截止日期。",
                    ja: "請求書を開いて、金額と支払期限を読みましょう。",
                    ko: "청구서를 열고 금액과 납부 기한을 읽어 보세요."
                )
                stop = language.pick(
                    en: "Stop when you can see both.",
                    zh: "看清两者就停。",
                    zhHant: "看清兩者就停。",
                    ja: "両方が見えたら止めましょう。",
                    ko: "둘 다 보이면 멈춰요."
                )
            case .appointment:
                title = language.pick(
                    en: "See the appointment time",
                    zh: "看清预约时间",
                    zhHant: "看清預約時間",
                    ja: "予約の時間を確かめる",
                    ko: "예약 시간 확인하기"
                )
                step = language.pick(
                    en: "Open the appointment and see the date and time.",
                    zh: "打开预约信息，看清日期和时间。",
                    zhHant: "開啟預約資訊，看清日期和時間。",
                    ja: "予約の情報を開いて、日付と時間を確かめましょう。",
                    ko: "예약 내용을 열고 날짜와 시간을 확인해 보세요."
                )
                stop = language.pick(
                    en: "Stop once you can see it.",
                    zh: "看清就停。",
                    zhHant: "看清就停。",
                    ja: "確かめられたら止めましょう。",
                    ko: "확인했으면 멈춰요."
                )
            default:
                title = language.pick(
                    en: "Read the key info",
                    zh: "读一遍关键信息",
                    zhHant: "讀一遍關鍵資訊",
                    ja: "大事なところを一度読む",
                    ko: "핵심 내용 한 번 읽기"
                )
                step = language.pick(
                    en: "Open this and read the key part once.",
                    zh: "打开这条信息，读一遍关键部分。",
                    zhHant: "開啟這條資訊，讀一遍關鍵部分。",
                    ja: "これを開いて、大事な部分を一度だけ読みましょう。",
                    ko: "이걸 열고 중요한 부분만 한 번 읽어 보세요."
                )
                stop = language.pick(
                    en: "Stop after one read-through.",
                    zh: "读一遍就停。",
                    zhHant: "讀一遍就停。",
                    ja: "一度読んだら止めましょう。",
                    ko: "한 번 읽었으면 멈춰요."
                )
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
