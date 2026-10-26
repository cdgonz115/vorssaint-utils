//
//  ClipboardEditorStrings.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/1/26.
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardEditorStrings {
    let enable: String
    let caption: String
    let defaultView: String
    let defaultViewHistory: String
    let defaultViewEditor: String
    let defaultViewCaption: String
    let noticeView: String
    let format: String
    let minify: String
    let raw: String
    let formatted: String
    let typeText: String
    let invalidJSON: String
    let invalidXML: String
}

extension FeatureStrings {
    static func clipboardEditor(_ language: AppLanguage) -> ClipboardEditorStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension ClipboardEditorStrings {
    static let enUS = ClipboardEditorStrings(
        enable: "Clipboard editor",
        caption: "Edit copied text, format JSON or XML, and find and replace with regex. Closing the editor or switching to another app puts the result back on the clipboard. Undo to cancel.",
        defaultView: "Clipboard opens on",
        defaultViewHistory: "History",
        defaultViewEditor: "Editor",
        defaultViewCaption: "The editor starts with the text on your clipboard right now.",
        noticeView: "Clipboard notification opens on",
        format: "Format",
        minify: "Minify",
        raw: "Raw",
        formatted: "Formatted",
        typeText: "Text",
        invalidJSON: "Not valid JSON",
        invalidXML: "Not valid XML"
    )

    static let ptBR = ClipboardEditorStrings(
        enable: "Editor de clipboard",
        caption: "Edite o texto copiado, formate JSON ou XML e use localizar e substituir com regex. Ao fechar o editor ou trocar de app, o resultado volta para o clipboard. Desfaça para cancelar.",
        defaultView: "O clipboard abre em",
        defaultViewHistory: "Histórico",
        defaultViewEditor: "Editor",
        defaultViewCaption: "O editor começa com o texto que está no clipboard agora.",
        noticeView: "A notificação do clipboard abre em",
        format: "Formatar",
        minify: "Minificar",
        raw: "Bruto",
        formatted: "Formatado",
        typeText: "Texto",
        invalidJSON: "JSON inválido",
        invalidXML: "XML inválido"
    )

    static let tr = ClipboardEditorStrings(
        enable: "Pano düzenleyicisi",
        caption: "Kopyalanan metni düzenleyin, JSON veya XML biçimlendirin, regex ile bulun ve değiştirin. Düzenleyiciyi kapattığınızda veya başka bir uygulamaya geçtiğinizde sonuç panoya geri yazılır. İptal etmek için geri alın.",
        defaultView: "Pano şununla açılır",
        defaultViewHistory: "Geçmiş",
        defaultViewEditor: "Düzenleyici",
        defaultViewCaption: "Düzenleyici, şu anda panonuzda bulunan metinle başlar.",
        noticeView: "Pano bildirimi şununla açılır",
        format: "Biçimlendir",
        minify: "Sıkıştır",
        raw: "Ham",
        formatted: "Biçimlendirilmiş",
        typeText: "Metin",
        invalidJSON: "Geçersiz JSON",
        invalidXML: "Geçersiz XML"
    )

    static let ru = ClipboardEditorStrings(
        enable: "Редактор буфера обмена",
        caption: "Редактируйте скопированный текст, форматируйте JSON или XML, ищите и заменяйте с помощью regex. При закрытии редактора или переключении на другое приложение результат возвращается в буфер обмена. Чтобы отменить правки, используйте отмену действия.",
        defaultView: "Буфер обмена открывается на",
        defaultViewHistory: "История",
        defaultViewEditor: "Редактор",
        defaultViewCaption: "Редактор открывается с текстом, который сейчас в буфере обмена.",
        noticeView: "Уведомление буфера обмена открывается на",
        format: "Форматировать",
        minify: "Минифицировать",
        raw: "Исходный",
        formatted: "Форматированный",
        typeText: "Текст",
        invalidJSON: "Недопустимый JSON",
        invalidXML: "Недопустимый XML"
    )

    static let es = ClipboardEditorStrings(
        enable: "Editor del portapapeles",
        caption: "Edita el texto copiado, da formato a JSON o XML y busca y reemplaza con regex. Al cerrar el editor o cambiar a otra app, el resultado vuelve al portapapeles. Deshaz los cambios para cancelar.",
        defaultView: "El portapapeles se abre en",
        defaultViewHistory: "Historial",
        defaultViewEditor: "Editor",
        defaultViewCaption: "El editor empieza con el texto que hay ahora en el portapapeles.",
        noticeView: "La notificación del portapapeles se abre en",
        format: "Dar formato",
        minify: "Minificar",
        raw: "Sin formato",
        formatted: "Formateado",
        typeText: "Texto",
        invalidJSON: "JSON no válido",
        invalidXML: "XML no válido"
    )

    static let sk = ClipboardEditorStrings(
        enable: "Editor schránky",
        caption: "Upravujte skopírovaný text, formátujte JSON alebo XML a hľadajte a nahrádzajte pomocou regex. Po zatvorení editora alebo prepnutí do inej aplikácie sa výsledok vráti do schránky. Zrušíte to vrátením zmien.",
        defaultView: "Schránka sa otvorí na",
        defaultViewHistory: "História",
        defaultViewEditor: "Editor",
        defaultViewCaption: "Editor sa otvorí s textom, ktorý je práve v schránke.",
        noticeView: "Oznámenie schránky sa otvorí na",
        format: "Formátovať",
        minify: "Minifikovať",
        raw: "Pôvodný",
        formatted: "Formátovaný",
        typeText: "Text",
        invalidJSON: "Neplatný JSON",
        invalidXML: "Neplatný XML"
    )

    static let de = ClipboardEditorStrings(
        enable: "Zwischenablage-Editor",
        caption: "Kopierten Text bearbeiten, JSON oder XML formatieren sowie mit Regex suchen und ersetzen. Beim Schließen des Editors oder beim Wechsel zu einer anderen App landet das Ergebnis wieder in der Zwischenablage. Zum Abbrechen die Änderungen rückgängig machen.",
        defaultView: "Zwischenablage öffnet mit",
        defaultViewHistory: "Verlauf",
        defaultViewEditor: "Editor",
        defaultViewCaption: "Der Editor beginnt mit dem Text, der gerade in der Zwischenablage liegt.",
        noticeView: "Zwischenablage-Hinweis öffnet mit",
        format: "Formatieren",
        minify: "Minimieren",
        raw: "Roh",
        formatted: "Formatiert",
        typeText: "Text",
        invalidJSON: "Kein gültiges JSON",
        invalidXML: "Kein gültiges XML"
    )

    static let fr = ClipboardEditorStrings(
        enable: "Éditeur du presse-papiers",
        caption: "Modifiez le texte copié, formatez du JSON ou du XML, puis recherchez et remplacez avec des regex. Fermer l’éditeur ou passer à une autre app remet le résultat dans le presse-papiers. Pour annuler, défaites les modifications.",
        defaultView: "Le presse-papiers s’ouvre sur",
        defaultViewHistory: "Historique",
        defaultViewEditor: "Éditeur",
        defaultViewCaption: "L’éditeur démarre avec le texte actuellement dans le presse-papiers.",
        noticeView: "La notification du presse-papiers s’ouvre sur",
        format: "Formater",
        minify: "Minifier",
        raw: "Brut",
        formatted: "Formaté",
        typeText: "Texte",
        invalidJSON: "JSON invalide",
        invalidXML: "XML invalide"
    )

    static let it = ClipboardEditorStrings(
        enable: "Editor degli appunti",
        caption: "Modifica il testo copiato, formatta JSON o XML e usa trova e sostituisci con le regex. Chiudendo l’editor o passando a un’altra app, il risultato torna negli appunti. Annulla le modifiche per rinunciare.",
        defaultView: "Gli appunti si aprono su",
        defaultViewHistory: "Cronologia",
        defaultViewEditor: "Editor",
        defaultViewCaption: "L’editor parte con il testo che è negli appunti in questo momento.",
        noticeView: "La notifica degli appunti si apre su",
        format: "Formatta",
        minify: "Minifica",
        raw: "Originale",
        formatted: "Formattato",
        typeText: "Testo",
        invalidJSON: "JSON non valido",
        invalidXML: "XML non valido"
    )

    static let ja = ClipboardEditorStrings(
        enable: "クリップボードエディタ",
        caption: "コピーしたテキストを編集し、JSON や XML を整形し、正規表現で検索と置換ができます。エディタを閉じるか別のアプリに切り替えると、結果がクリップボードに戻ります。元に戻すと変更を取り消せます。",
        defaultView: "クリップボードの初期表示",
        defaultViewHistory: "履歴",
        defaultViewEditor: "エディタ",
        defaultViewCaption: "エディタには、現在クリップボードにあるテキストが表示されます。",
        noticeView: "クリップボード通知で開く画面",
        format: "整形",
        minify: "圧縮",
        raw: "未加工",
        formatted: "整形済み",
        typeText: "テキスト",
        invalidJSON: "無効なJSON",
        invalidXML: "無効なXML"
    )

    static let ko = ClipboardEditorStrings(
        enable: "클립보드 편집기",
        caption: "복사한 텍스트를 편집하고, JSON이나 XML을 정렬하며, 정규식으로 찾아 바꿀 수 있습니다. 편집기를 닫거나 다른 앱으로 전환하면 결과가 클립보드로 돌아갑니다. 취소하려면 실행 취소를 사용하세요.",
        defaultView: "클립보드 시작 화면",
        defaultViewHistory: "기록",
        defaultViewEditor: "편집기",
        defaultViewCaption: "편집기는 현재 클립보드에 있는 텍스트로 시작합니다.",
        noticeView: "클립보드 알림 시작 화면",
        format: "정렬",
        minify: "압축",
        raw: "원본",
        formatted: "서식 적용",
        typeText: "텍스트",
        invalidJSON: "올바르지 않은 JSON",
        invalidXML: "올바르지 않은 XML"
    )

    static let zhHans = ClipboardEditorStrings(
        enable: "剪贴板编辑器",
        caption: "编辑已复制的文本，格式化 JSON 或 XML，并用正则表达式查找和替换。关闭编辑器或切换到其他 App 时，结果会写回剪贴板。撤销即可取消更改。",
        defaultView: "剪贴板默认打开",
        defaultViewHistory: "历史",
        defaultViewEditor: "编辑器",
        defaultViewCaption: "编辑器会以当前剪贴板中的文本开始。",
        noticeView: "剪贴板通知默认打开",
        format: "格式化",
        minify: "压缩",
        raw: "原始",
        formatted: "格式化",
        typeText: "文本",
        invalidJSON: "JSON 无效",
        invalidXML: "XML 无效"
    )

    static let zhTW = ClipboardEditorStrings(
        enable: "剪貼簿編輯器",
        caption: "編輯已複製的文字、格式化 JSON 或 XML，並用正規表達式尋找與取代。關閉編輯器或切換到其他 App 時，結果會寫回剪貼簿。復原即可取消變更。",
        defaultView: "剪貼簿預設開啟",
        defaultViewHistory: "紀錄",
        defaultViewEditor: "編輯器",
        defaultViewCaption: "編輯器會以目前剪貼簿中的文字開始。",
        noticeView: "剪貼簿通知預設開啟",
        format: "格式化",
        minify: "壓縮",
        raw: "原始",
        formatted: "已格式化",
        typeText: "文字",
        invalidJSON: "JSON 無效",
        invalidXML: "XML 無效"
    )

    static let zhHK = ClipboardEditorStrings(
        enable: "剪貼簿編輯器",
        caption: "編輯已複製的文字、格式化 JSON 或 XML，並用正規表達式尋找及取代。關閉編輯器或切換至其他 App 時，結果會寫回剪貼簿。還原即可取消更改。",
        defaultView: "剪貼簿預設開啟",
        defaultViewHistory: "記錄",
        defaultViewEditor: "編輯器",
        defaultViewCaption: "編輯器會以目前剪貼簿中的文字開始。",
        noticeView: "剪貼簿通知預設開啟",
        format: "格式化",
        minify: "壓縮",
        raw: "原始",
        formatted: "已格式化",
        typeText: "文字",
        invalidJSON: "JSON 無效",
        invalidXML: "XML 無效"
    )

    static let uk = ClipboardEditorStrings(
        enable: "Редактор буфера обміну",
        caption: "Редагуйте скопійований текст, форматуйте JSON або XML, шукайте й замінюйте за допомогою regex. Після закриття редактора або переходу в іншу програму результат повертається в буфер обміну. Щоб скасувати правки, використайте скасування дії.",
        defaultView: "Буфер обміну відкривається на",
        defaultViewHistory: "Історія",
        defaultViewEditor: "Редактор",
        defaultViewCaption: "Редактор починається з тексту, який зараз у буфері обміну.",
        noticeView: "Сповіщення буфера обміну відкривається на",
        format: "Форматувати",
        minify: "Мінімізувати",
        raw: "Вихідний",
        formatted: "Форматований",
        typeText: "Текст",
        invalidJSON: "Недійсний JSON",
        invalidXML: "Недійсний XML"
    )
}
