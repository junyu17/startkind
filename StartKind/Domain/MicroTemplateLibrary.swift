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
                        zhHant: "帳單先只找入口",
                        ja: "請求書の入り口を見つける",
                        ko: "청구서 찾을 곳 정하기"
                    ),
                    step: lang.pick(
                        en: "Open one place where the bill might be, and only look for the amount or pay button.",
                        zh: "打开一个可能有账单的地方，只找付款入口或金额。",
                        zhHant: "開啟一個可能有帳單的地方，只找付款入口或金額。",
                        ja: "請求書がありそうな場所をひとつ開いて、金額か支払いボタンだけを探しましょう。",
                        ko: "청구서가 있을 만한 곳 하나를 열고, 금액이나 결제 버튼만 찾아보세요."
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when you see the amount, the pay button, or the blocker.",
                        zh: "看到金额、付款入口或卡住点就停。",
                        zhHant: "看到金額、付款入口或卡住點就停。",
                        ja: "金額か支払いボタン、または引っかかっている点が見えたら止めましょう。",
                        ko: "금액이나 결제 버튼, 또는 막히는 부분이 보이면 멈춰요."
                    ),
                    category: .bills,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Finding the entry point is enough to create movement.",
                        zh: "先找到入口，不用一次完成付款。",
                        zhHant: "先找到入口，不用一次完成付款。",
                        ja: "入り口が見つかれば十分です。支払いまで終える必要はありません。",
                        ko: "들어갈 곳만 찾아도 충분해요. 결제까지 끝내지 않아도 돼요."
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
                        zhHant: "只寫一句回覆",
                        ja: "返信を一文だけ書く",
                        ko: "답장 한 문장만 쓰기"
                    ),
                    step: lang.pick(
                        en: "Open the email and write only the first sentence of a reply draft.",
                        zh: "打开那封邮件，只写第一句回复草稿。",
                        zhHant: "開啟那封郵件，只寫第一句回覆草稿。",
                        ja: "そのメールを開いて、返信の下書きの最初の一文だけを書きましょう。",
                        ko: "이메일을 열고 답장 초안의 첫 문장만 써 보세요."
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop after one sentence. Sending can wait.",
                        zh: "写完第一句就停，不用发送。",
                        zhHant: "寫完第一句就停，不用傳送。",
                        ja: "一文書けたら止めましょう。送信はあとで大丈夫です。",
                        ko: "한 문장을 썼으면 멈춰요. 보내는 건 나중에 해도 돼요."
                    ),
                    category: .email,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "A draft is lighter than sending, which makes starting easier.",
                        zh: "草稿比发送轻很多，更容易开始。",
                        zhHant: "草稿比傳送輕很多，更容易開始。",
                        ja: "下書きは送信よりずっと軽いので、始めやすくなります。",
                        ko: "초안은 보내는 것보다 가벼워서 시작하기 쉬워요."
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
                        zhHant: "找預約方式",
                        ja: "予約の方法を見つける",
                        ko: "예약 방법 찾기"
                    ),
                    step: lang.pick(
                        en: "Find only the booking page, phone number, or office name.",
                        zh: "只找到预约页面、电话或诊所名称。",
                        zhHant: "只找到預約頁面、電話或診所名稱。",
                        ja: "予約ページか電話番号、または医院の名前だけを見つけましょう。",
                        ko: "예약 페이지, 전화번호, 병원 이름 중 하나만 찾아보세요."
                    ),
                    timerMinutes: 7,
                    stopCondition: lang.pick(
                        en: "Stop when you have one way to contact them.",
                        zh: "找到一个联系方式就停。",
                        zhHant: "找到一個聯絡方式就停。",
                        ja: "連絡する方法がひとつ分かったら止めましょう。",
                        ko: "연락할 방법 하나를 찾았으면 멈춰요."
                    ),
                    category: .appointments,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Booking starts with finding the doorway, not finishing the appointment.",
                        zh: "把预约拆成找入口，不要求马上预约成功。",
                        zhHant: "把預約拆成找入口，不要求馬上預約成功。",
                        ja: "予約は入り口を見つけるところから始まります。今日中に取り切らなくて大丈夫です。",
                        ko: "예약은 들어갈 곳을 찾는 데서 시작해요. 오늘 안에 끝내지 않아도 괜찮아요."
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
                        zhHant: "找一個檔案線索",
                        ja: "書類の手がかりをひとつ見つける",
                        ko: "서류 단서 하나 찾기"
                    ),
                    step: lang.pick(
                        en: "Open one folder, inbox, or photo album and look for one related clue.",
                        zh: "打开一个文件夹、邮箱或照片相册，只找一个相关线索。",
                        zhHant: "開啟一個資料夾、郵箱或照片相簿，只找一個相關線索。",
                        ja: "フォルダか受信トレイ、写真アルバムをひとつ開いて、関係のありそうな手がかりをひとつ探しましょう。",
                        ko: "폴더, 받은편지함, 사진 앨범 중 한 곳을 열고 관련 단서를 하나 찾아보세요."
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when you find a clue or confirm it is not there.",
                        zh: "找到线索或确认不在这里就停。",
                        zhHant: "找到線索或確認不在這裡就停。",
                        ja: "手がかりが見つかるか、ここには無いと分かったら止めましょう。",
                        ko: "단서를 찾았거나 여기엔 없다는 걸 확인했으면 멈춰요."
                    ),
                    category: .workAdmin,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "Document tasks often stall because the search area is too wide.",
                        zh: "文件任务通常卡在搜索范围太大，先缩小一个地方。",
                        zhHant: "檔案任務通常卡在搜尋範圍太大，先縮小一個地方。",
                        ja: "書類さがしは範囲が広すぎて止まりがちです。まず一か所に絞りましょう。",
                        ko: "서류 찾기는 범위가 너무 넓어서 멈추기 쉬워요. 먼저 한 곳으로 좁혀 봐요."
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
                        zhHant: "清出一個小表面",
                        ja: "小さな場所をひとつ片づける",
                        ko: "작은 공간 하나 치우기"
                    ),
                    step: lang.pick(
                        en: "Pick a hand-sized area and move only three things away.",
                        zh: "选一个手掌大的区域，只拿走三样东西。",
                        zhHant: "選一個手掌大的區域，只拿走三樣東西。",
                        ja: "手のひらくらいの範囲をひとつ選んで、3つだけどかしましょう。",
                        ko: "손바닥만 한 공간 하나를 골라 물건 세 개만 치워 보세요."
                    ),
                    timerMinutes: 5,
                    stopCondition: lang.pick(
                        en: "Stop when three things leave that spot.",
                        zh: "三样东西离开那个区域就停。",
                        zhHant: "三樣東西離開那個區域就停。",
                        ja: "3つどかせたら止めましょう。",
                        ko: "세 개를 치웠으면 멈춰요."
                    ),
                    category: .household,
                    shrinkLevel: .one,
                    whyThisStep: lang.pick(
                        en: "A visible change is easier to start than a full clean-up.",
                        zh: "一个看得见的变化比完整打扫更容易启动。",
                        zhHant: "一個看得見的變化比完整打掃更容易啟動。",
                        ja: "目に見える変化がひとつあるほうが、全部を片づけるより始めやすくなります。",
                        ko: "눈에 보이는 변화 하나가 전부 치우는 것보다 시작하기 쉬워요."
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
