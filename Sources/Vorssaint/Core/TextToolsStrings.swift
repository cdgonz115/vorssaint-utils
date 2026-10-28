//
//  TextToolsStrings.swift
//  Vorssaint
//
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Words for the find and replace bar, shared by every editor that uses it.
struct TextToolsStrings {
    let find: String
    let replace: String
    let replaceAll: String
    let findToggle: String
    let regex: String
    let matchCase: String
    let next: String
    let previous: String
    let matches: String
    let replaced: String
    let noMatches: String
    let invalidPattern: String
}

extension FeatureStrings {
    static func textTools(_ language: AppLanguage) -> TextToolsStrings {
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

extension TextToolsStrings {
    static let enUS = TextToolsStrings(
        find: "Find",
        replace: "Replace with",
        replaceAll: "Replace all",
        findToggle: "Find and replace",
        regex: "Regular expression",
        matchCase: "Match case",
        next: "Next match",
        previous: "Previous match",
        matches: "Matches",
        replaced: "Replaced",
        noMatches: "No matches",
        invalidPattern: "Invalid pattern"
    )
}

extension TextToolsStrings {
    static let ptBR = TextToolsStrings(
        find: "Localizar",
        replace: "Substituir por",
        replaceAll: "Substituir tudo",
        findToggle: "Localizar e substituir",
        regex: "Expressão regular",
        matchCase: "Diferenciar maiúsculas",
        next: "Próxima ocorrência",
        previous: "Ocorrência anterior",
        matches: "Ocorrências",
        replaced: "Substituídas",
        noMatches: "Nenhuma ocorrência",
        invalidPattern: "Padrão inválido"
    )
}

extension TextToolsStrings {
    static let tr = TextToolsStrings(
        find: "Bul",
        replace: "Şununla değiştir",
        replaceAll: "Tümünü değiştir",
        findToggle: "Bul ve değiştir",
        regex: "Düzenli ifade",
        matchCase: "Büyük/küçük harf duyarlı",
        next: "Sonraki eşleşme",
        previous: "Önceki eşleşme",
        matches: "Eşleşme",
        replaced: "Değiştirilen",
        noMatches: "Eşleşme yok",
        invalidPattern: "Geçersiz desen"
    )
}

extension TextToolsStrings {
    static let ru = TextToolsStrings(
        find: "Найти",
        replace: "Заменить на",
        replaceAll: "Заменить все",
        findToggle: "Найти и заменить",
        regex: "Регулярное выражение",
        matchCase: "Учитывать регистр",
        next: "Следующее совпадение",
        previous: "Предыдущее совпадение",
        matches: "Совпадений",
        replaced: "Заменено",
        noMatches: "Нет совпадений",
        invalidPattern: "Недопустимый шаблон"
    )
}

extension TextToolsStrings {
    static let es = TextToolsStrings(
        find: "Buscar",
        replace: "Reemplazar con",
        replaceAll: "Reemplazar todo",
        findToggle: "Buscar y reemplazar",
        regex: "Expresión regular",
        matchCase: "Distinguir mayúsculas",
        next: "Siguiente coincidencia",
        previous: "Coincidencia anterior",
        matches: "Coincidencias",
        replaced: "Reemplazadas",
        noMatches: "Sin coincidencias",
        invalidPattern: "Patrón no válido"
    )
}

extension TextToolsStrings {
    static let sk = TextToolsStrings(
        find: "Hľadať",
        replace: "Nahradiť čím",
        replaceAll: "Nahradiť všetko",
        findToggle: "Hľadať a nahradiť",
        regex: "Regulárny výraz",
        matchCase: "Rozlišovať veľkosť písmen",
        next: "Ďalšia zhoda",
        previous: "Predchádzajúca zhoda",
        matches: "Zhody",
        replaced: "Nahradené",
        noMatches: "Žiadne zhody",
        invalidPattern: "Neplatný vzor"
    )
}

extension TextToolsStrings {
    static let de = TextToolsStrings(
        find: "Suchen",
        replace: "Ersetzen durch",
        replaceAll: "Alle ersetzen",
        findToggle: "Suchen und Ersetzen",
        regex: "Regulärer Ausdruck",
        matchCase: "Groß-/Kleinschreibung beachten",
        next: "Nächster Treffer",
        previous: "Vorheriger Treffer",
        matches: "Treffer",
        replaced: "Ersetzt",
        noMatches: "Keine Treffer",
        invalidPattern: "Ungültiges Muster"
    )
}

extension TextToolsStrings {
    static let fr = TextToolsStrings(
        find: "Rechercher",
        replace: "Remplacer par",
        replaceAll: "Tout remplacer",
        findToggle: "Rechercher et remplacer",
        regex: "Expression régulière",
        matchCase: "Respecter la casse",
        next: "Occurrence suivante",
        previous: "Occurrence précédente",
        matches: "Occurrences",
        replaced: "Remplacées",
        noMatches: "Aucune occurrence",
        invalidPattern: "Motif invalide"
    )
}

extension TextToolsStrings {
    static let it = TextToolsStrings(
        find: "Trova",
        replace: "Sostituisci con",
        replaceAll: "Sostituisci tutto",
        findToggle: "Trova e sostituisci",
        regex: "Espressione regolare",
        matchCase: "Maiuscole/minuscole",
        next: "Corrispondenza successiva",
        previous: "Corrispondenza precedente",
        matches: "Corrispondenze",
        replaced: "Sostituite",
        noMatches: "Nessuna corrispondenza",
        invalidPattern: "Pattern non valido"
    )
}

extension TextToolsStrings {
    static let ja = TextToolsStrings(
        find: "検索",
        replace: "置換後の文字列",
        replaceAll: "すべて置換",
        findToggle: "検索と置換",
        regex: "正規表現",
        matchCase: "大文字と小文字を区別",
        next: "次の一致",
        previous: "前の一致",
        matches: "一致",
        replaced: "置換済み",
        noMatches: "一致なし",
        invalidPattern: "無効なパターン"
    )
}

extension TextToolsStrings {
    static let ko = TextToolsStrings(
        find: "찾기",
        replace: "바꿀 내용",
        replaceAll: "모두 바꾸기",
        findToggle: "찾기 및 바꾸기",
        regex: "정규식",
        matchCase: "대소문자 구분",
        next: "다음 일치 항목",
        previous: "이전 일치 항목",
        matches: "일치",
        replaced: "바꿈",
        noMatches: "일치 항목 없음",
        invalidPattern: "잘못된 패턴"
    )
}

extension TextToolsStrings {
    static let zhHans = TextToolsStrings(
        find: "查找",
        replace: "替换为",
        replaceAll: "全部替换",
        findToggle: "查找和替换",
        regex: "正则表达式",
        matchCase: "区分大小写",
        next: "下一个匹配",
        previous: "上一个匹配",
        matches: "匹配",
        replaced: "已替换",
        noMatches: "无匹配",
        invalidPattern: "无效的模式"
    )
}

extension TextToolsStrings {
    static let zhTW = TextToolsStrings(
        find: "尋找",
        replace: "取代為",
        replaceAll: "全部取代",
        findToggle: "尋找與取代",
        regex: "正規表示式",
        matchCase: "區分大小寫",
        next: "下一個符合項目",
        previous: "上一個符合項目",
        matches: "符合項目",
        replaced: "已取代",
        noMatches: "沒有符合項目",
        invalidPattern: "無效的模式"
    )
}

extension TextToolsStrings {
    static let zhHK = TextToolsStrings(
        find: "尋找",
        replace: "取代為",
        replaceAll: "全部取代",
        findToggle: "尋找及取代",
        regex: "正則表達式",
        matchCase: "區分大小寫",
        next: "下一個符合項目",
        previous: "上一個符合項目",
        matches: "符合項目",
        replaced: "已取代",
        noMatches: "沒有符合項目",
        invalidPattern: "無效的模式"
    )
}

extension TextToolsStrings {
    static let uk = TextToolsStrings(
        find: "Знайти",
        replace: "Замінити на",
        replaceAll: "Замінити все",
        findToggle: "Знайти й замінити",
        regex: "Регулярний вираз",
        matchCase: "Враховувати регістр",
        next: "Наступний збіг",
        previous: "Попередній збіг",
        matches: "Збігів",
        replaced: "Замінено",
        noMatches: "Немає збігів",
        invalidPattern: "Недійсний шаблон"
    )
}
