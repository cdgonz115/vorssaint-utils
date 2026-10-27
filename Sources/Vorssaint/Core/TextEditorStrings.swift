//
//  TextEditorStrings.swift
//  Vorssaint
//
//  Created by Christian Gonzalez on 10/23/26.
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Words for the text editor's settings page: the formats it reads and the
/// colors it draws them in. Format names (JSON, XML) are not translated.
struct TextEditorStrings {
    let pageTitle: String
    let caption: String
    let colors: String
    let reset: String
    let key: String
    let string: String
    let number: String
    let literal: String
    let symbols: String
    let tag: String
    let attribute: String
    let attributeValue: String
    let text: String
    let comment: String

    /// What a kind of text is called on the colors list. The same kind reads
    /// differently in different formats: a string is an attribute value in XML.
    func label(for kind: SyntaxHighlightSupport.Kind, in format: TextToolsSupport.Format) -> String {
        switch (kind, format) {
        case (.key, _): return key
        case (.string, .xml): return attributeValue
        case (.string, _): return string
        case (.number, _): return number
        case (.literal, _): return literal
        case (.punctuation, _): return symbols
        case (.tag, _): return tag
        case (.attribute, _): return attribute
        case (.value, _): return text
        case (.comment, _): return comment
        }
    }
}

extension FeatureStrings {
    static func textEditor(_ language: AppLanguage) -> TextEditorStrings {
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

extension TextEditorStrings {
    static let enUS = TextEditorStrings(
        pageTitle: "Text editor",
        caption: "Formats the text editor can read and color. A format that is off is left out of the type menu and never picked automatically.",
        colors: "Colors",
        reset: "Reset colors",
        key: "Keys",
        string: "Strings",
        number: "Numbers",
        literal: "true, false, null",
        symbols: "Symbols",
        tag: "Tags",
        attribute: "Attributes",
        attributeValue: "Attribute values",
        text: "Text",
        comment: "Comments"
    )

    static let ptBR = TextEditorStrings(
        pageTitle: "Editor de texto",
        caption: "Formatos que o editor de texto pode ler e colorir. Um formato desativado fica fora do menu de tipos e nunca é escolhido automaticamente.",
        colors: "Cores",
        reset: "Redefinir cores",
        key: "Chaves",
        string: "Textos",
        number: "Números",
        literal: "true, false, null",
        symbols: "Símbolos",
        tag: "Tags",
        attribute: "Atributos",
        attributeValue: "Valores de atributo",
        text: "Texto",
        comment: "Comentários"
    )

    static let tr = TextEditorStrings(
        pageTitle: "Metin düzenleyici",
        caption: "Metin düzenleyicinin okuyup renklendirebileceği biçimler. Kapalı bir biçim tür menüsünde yer almaz ve otomatik seçilmez.",
        colors: "Renkler",
        reset: "Renkleri sıfırla",
        key: "Anahtarlar",
        string: "Dizeler",
        number: "Sayılar",
        literal: "true, false, null",
        symbols: "Semboller",
        tag: "Etiketler",
        attribute: "Öznitelikler",
        attributeValue: "Öznitelik değerleri",
        text: "Metin",
        comment: "Yorumlar"
    )

    static let ru = TextEditorStrings(
        pageTitle: "Текстовый редактор",
        caption: "Форматы, которые редактор может читать и подсвечивать. Выключенный формат не показывается в меню типов и не выбирается автоматически.",
        colors: "Цвета",
        reset: "Сбросить цвета",
        key: "Ключи",
        string: "Строки",
        number: "Числа",
        literal: "true, false, null",
        symbols: "Символы",
        tag: "Теги",
        attribute: "Атрибуты",
        attributeValue: "Значения атрибутов",
        text: "Текст",
        comment: "Комментарии"
    )

    static let es = TextEditorStrings(
        pageTitle: "Editor de texto",
        caption: "Formatos que el editor de texto puede leer y colorear. Un formato desactivado no aparece en el menú de tipos ni se elige automáticamente.",
        colors: "Colores",
        reset: "Restablecer colores",
        key: "Claves",
        string: "Cadenas",
        number: "Números",
        literal: "true, false, null",
        symbols: "Símbolos",
        tag: "Etiquetas",
        attribute: "Atributos",
        attributeValue: "Valores de atributo",
        text: "Texto",
        comment: "Comentarios"
    )

    static let sk = TextEditorStrings(
        pageTitle: "Textový editor",
        caption: "Formáty, ktoré textový editor vie čítať a farebne zvýrazniť. Vypnutý formát sa nezobrazí v ponuke typov a nikdy sa nevyberie automaticky.",
        colors: "Farby",
        reset: "Obnoviť farby",
        key: "Kľúče",
        string: "Reťazce",
        number: "Čísla",
        literal: "true, false, null",
        symbols: "Symboly",
        tag: "Značky",
        attribute: "Atribúty",
        attributeValue: "Hodnoty atribútov",
        text: "Text",
        comment: "Komentáre"
    )

    static let de = TextEditorStrings(
        pageTitle: "Texteditor",
        caption: "Formate, die der Texteditor lesen und einfärben kann. Ein deaktiviertes Format fehlt im Typmenü und wird nie automatisch gewählt.",
        colors: "Farben",
        reset: "Farben zurücksetzen",
        key: "Schlüssel",
        string: "Zeichenfolgen",
        number: "Zahlen",
        literal: "true, false, null",
        symbols: "Symbole",
        tag: "Tags",
        attribute: "Attribute",
        attributeValue: "Attributwerte",
        text: "Text",
        comment: "Kommentare"
    )

    static let fr = TextEditorStrings(
        pageTitle: "Éditeur de texte",
        caption: "Formats que l’éditeur de texte peut lire et colorer. Un format désactivé n’apparaît pas dans le menu des types et n’est jamais choisi automatiquement.",
        colors: "Couleurs",
        reset: "Réinitialiser les couleurs",
        key: "Clés",
        string: "Chaînes",
        number: "Nombres",
        literal: "true, false, null",
        symbols: "Symboles",
        tag: "Balises",
        attribute: "Attributs",
        attributeValue: "Valeurs d’attribut",
        text: "Texte",
        comment: "Commentaires"
    )

    static let it = TextEditorStrings(
        pageTitle: "Editor di testo",
        caption: "Formati che l’editor di testo può leggere e colorare. Un formato disattivato non compare nel menu dei tipi e non viene mai scelto automaticamente.",
        colors: "Colori",
        reset: "Ripristina i colori",
        key: "Chiavi",
        string: "Stringhe",
        number: "Numeri",
        literal: "true, false, null",
        symbols: "Simboli",
        tag: "Tag",
        attribute: "Attributi",
        attributeValue: "Valori degli attributi",
        text: "Testo",
        comment: "Commenti"
    )

    static let ja = TextEditorStrings(
        pageTitle: "テキストエディタ",
        caption: "テキストエディタが読み取って色分けできる形式です。オフにした形式は種類メニューに表示されず、自動では選ばれません。",
        colors: "色",
        reset: "色をリセット",
        key: "キー",
        string: "文字列",
        number: "数値",
        literal: "true、false、null",
        symbols: "記号",
        tag: "タグ",
        attribute: "属性",
        attributeValue: "属性値",
        text: "テキスト",
        comment: "コメント"
    )

    static let ko = TextEditorStrings(
        pageTitle: "텍스트 편집기",
        caption: "텍스트 편집기가 읽고 색을 입힐 수 있는 형식입니다. 꺼진 형식은 유형 메뉴에서 빠지고 자동으로 선택되지 않습니다.",
        colors: "색상",
        reset: "색상 재설정",
        key: "키",
        string: "문자열",
        number: "숫자",
        literal: "true, false, null",
        symbols: "기호",
        tag: "태그",
        attribute: "속성",
        attributeValue: "속성 값",
        text: "텍스트",
        comment: "주석"
    )

    static let zhHans = TextEditorStrings(
        pageTitle: "文本编辑器",
        caption: "文本编辑器可以读取并着色的格式。关闭的格式不会出现在类型菜单中，也不会被自动选择。",
        colors: "颜色",
        reset: "重置颜色",
        key: "键",
        string: "字符串",
        number: "数字",
        literal: "true、false、null",
        symbols: "符号",
        tag: "标签",
        attribute: "属性",
        attributeValue: "属性值",
        text: "文本",
        comment: "注释"
    )

    static let zhTW = TextEditorStrings(
        pageTitle: "文字編輯器",
        caption: "文字編輯器可讀取並上色的格式。關閉的格式不會出現在類型選單中，也不會被自動選取。",
        colors: "顏色",
        reset: "重設顏色",
        key: "鍵",
        string: "字串",
        number: "數字",
        literal: "true、false、null",
        symbols: "符號",
        tag: "標籤",
        attribute: "屬性",
        attributeValue: "屬性值",
        text: "文字",
        comment: "註解"
    )

    static let zhHK = TextEditorStrings(
        pageTitle: "文字編輯器",
        caption: "文字編輯器可讀取並上色的格式。關閉的格式不會出現在類型選單中，也不會被自動選取。",
        colors: "顏色",
        reset: "重設顏色",
        key: "鍵",
        string: "字串",
        number: "數字",
        literal: "true、false、null",
        symbols: "符號",
        tag: "標籤",
        attribute: "屬性",
        attributeValue: "屬性值",
        text: "文字",
        comment: "註解"
    )

    static let uk = TextEditorStrings(
        pageTitle: "Текстовий редактор",
        caption: "Формати, які редактор може читати й підсвічувати. Вимкнений формат не показується в меню типів і не вибирається автоматично.",
        colors: "Кольори",
        reset: "Скинути кольори",
        key: "Ключі",
        string: "Рядки",
        number: "Числа",
        literal: "true, false, null",
        symbols: "Символи",
        tag: "Теги",
        attribute: "Атрибути",
        attributeValue: "Значення атрибутів",
        text: "Текст",
        comment: "Коментарі"
    )
}
