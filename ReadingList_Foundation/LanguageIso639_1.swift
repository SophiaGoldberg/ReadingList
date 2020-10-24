import Foundation

//swiftlint:disable type_body_length type_name explicit_enum_raw_value identifier_name
// ISO 639.1: two-digit language code
public enum LanguageIso639_1: String, CustomStringConvertible, CaseIterable, Decodable {
    case ab
    case aa
    case af
    case ak
    case sq
    case am
    case ar
    case an
    case hy
    case `as`
    case av
    case ae
    case ay
    case az
    case bm
    case ba
    case eu
    case be
    case bn
    case bh
    case bi
    case bs
    case br
    case bg
    case my
    case ca
    case km
    case ch
    case ce
    case ny
    case zh
    case cu
    case cv
    case kw
    case co
    case cr
    case hr
    case cs
    case da
    case dv
    case nl
    case dz
    case en
    case eo
    case et
    case ee
    case fo
    case fj
    case fi
    case fr
    case ff
    case gd
    case gl
    case lg
    case ka
    case de
    case gn
    case gu
    case ht
    case ha
    case he
    case hz
    case hi
    case ho
    case hu
    case `is`
    case io
    case ig
    case id
    case ia
    case ie
    case iu
    case ik
    case ga
    case it
    case ja
    case jv
    case kl
    case kn
    case kr
    case ks
    case kk
    case ki
    case rw
    case ky
    case kv
    case kg
    case ko
    case kj
    case ku
    case lo
    case la
    case lv
    case li
    case ln
    case lt
    case lu
    case lb
    case mk
    case mg
    case ms
    case ml
    case mt
    case gv
    case mi
    case mr
    case mh
    case el
    case mn
    case na
    case nv
    case ng
    case ne
    case nd
    case se
    case no
    case nb
    case nn
    case oc
    case oj
    case or
    case om
    case os
    case pi
    case pa
    case fa
    case pl
    case pt
    case ps
    case qu
    case ro
    case rm
    case rn
    case ru
    case sm
    case sg
    case sa
    case sc
    case sr
    case sn
    case ii
    case sd
    case si
    case sk
    case sl
    case so
    case nr
    case st
    case es
    case su
    case sw
    case ss
    case sv
    case tl
    case ty
    case tg
    case ta
    case tt
    case te
    case th
    case bo
    case ti
    case to
    case ts
    case tn
    case tr
    case tk
    case tw
    case ug
    case uk
    case ur
    case uz
    case ve
    case vi
    case vo
    case wa
    case cy
    case fy
    case wo
    case xh
    case yi
    case yo
    case za

    public var description: String {
        switch self {
        case .ab: return "Abkhazian"
        case .aa: return "Afar"
        case .af: return "Afrikaans"
        case .ak: return "Akan"
        case .sq: return "Albanian"
        case .am: return "Amharic"
        case .ar: return "Arabic"
        case .an: return "Aragonese"
        case .hy: return "Armenian"
        case .as: return "Assamese"
        case .av: return "Avaric"
        case .ae: return "Avestan"
        case .ay: return "Aymara"
        case .az: return "Azerbaijani"
        case .bm: return "Bambara"
        case .ba: return "Bashkir"
        case .eu: return "Basque"
        case .be: return "Belarusian"
        case .bn: return "Bengali"
        case .bh: return "Bihari languages"
        case .bi: return "Bislama"
        case .bs: return "Bosnian"
        case .br: return "Breton"
        case .bg: return "Bulgarian"
        case .my: return "Burmese"
        case .ca: return "Catalan; Valencian"
        case .km: return "Central Khmer"
        case .ch: return "Chamorro"
        case .ce: return "Chechen"
        case .ny: return "Chichewa; Chewa; Nyanja"
        case .zh: return "Chinese"
        case .cu: return "Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic"
        case .cv: return "Chuvash"
        case .kw: return "Cornish"
        case .co: return "Corsican"
        case .cr: return "Cree"
        case .hr: return "Croatian"
        case .cs: return "Czech"
        case .da: return "Danish"
        case .dv: return "Dhivehi; Dhivehi; Maldivian"
        case .nl: return "Dutch; Flemish"
        case .dz: return "Dzongkha"
        case .en: return "English"
        case .eo: return "Esperanto"
        case .et: return "Estonian"
        case .ee: return "Ewe"
        case .fo: return "Faroese"
        case .fj: return "Fijian"
        case .fi: return "Finnish"
        case .fr: return "French"
        case .ff: return "Fulah"
        case .gd: return "Gaelic; Scottish Gaelic"
        case .gl: return "Galician"
        case .lg: return "Ganda"
        case .ka: return "Georgian"
        case .de: return "German"
        case .gn: return "Guarani"
        case .gu: return "Gujarati"
        case .ht: return "Haitian; Haitian Creole"
        case .ha: return "Hausa"
        case .he: return "Hebrew"
        case .hz: return "Herero"
        case .hi: return "Hindi"
        case .ho: return "Hiri Motu"
        case .hu: return "Hungarian"
        case .is: return "Icelandic"
        case .io: return "Ido"
        case .ig: return "Igbo"
        case .id: return "Indonesian"
        case .ia: return "Interlingua (International Auxiliary Language Association)"
        case .ie: return "Interlingue; Occidental"
        case .iu: return "Inuktitut"
        case .ik: return "Inupiaq"
        case .ga: return "Irish"
        case .it: return "Italian"
        case .ja: return "Japanese"
        case .jv: return "Javanese"
        case .kl: return "Kalaallisut; Greenlandic"
        case .kn: return "Kannada"
        case .kr: return "Kanuri"
        case .ks: return "Kashmiri"
        case .kk: return "Kazakh"
        case .ki: return "Kikuyu; Gikuyu"
        case .rw: return "Kinyarwanda"
        case .ky: return "Kirghiz; Kyrgyz"
        case .kv: return "Komi"
        case .kg: return "Kongo"
        case .ko: return "Korean"
        case .kj: return "Kuanyama; Kwanyama"
        case .ku: return "Kurdish"
        case .lo: return "Lao"
        case .la: return "Latin"
        case .lv: return "Latvian"
        case .li: return "Limburgan; Limburger; Limburgish"
        case .ln: return "Lingala"
        case .lt: return "Lithuanian"
        case .lu: return "Luba-Katanga"
        case .lb: return "Luxembourgish; Letzeburgesch"
        case .mk: return "Macedonian"
        case .mg: return "Malagasy"
        case .ms: return "Malay"
        case .ml: return "Malayalam"
        case .mt: return "Maltese"
        case .gv: return "Manx"
        case .mi: return "Maori"
        case .mr: return "Marathi"
        case .mh: return "Marshallese"
        case .el: return "Modern Greek (1453–)"
        case .mn: return "Mongolian"
        case .na: return "Nauru"
        case .nv: return "Navajo; Navaho"
        case .ng: return "Ndonga"
        case .ne: return "Nepali"
        case .nd: return "North Ndebele"
        case .se: return "Northern Sami"
        case .no: return "Norwegian"
        case .nb: return "Norwegian Bokmål"
        case .nn: return "Norwegian Nynorsk"
        case .oc: return "Occitan (post 1500)"
        case .oj: return "Ojibwa"
        case .or: return "Oriya"
        case .om: return "Oromo"
        case .os: return "Ossetian; Ossetic"
        case .pi: return "Pali"
        case .pa: return "Panjabi; Punjabi"
        case .fa: return "Persian"
        case .pl: return "Polish"
        case .pt: return "Portuguese"
        case .ps: return "Pushto; Pashto"
        case .qu: return "Quechua"
        case .ro: return "Romanian; Moldavian; Moldovan"
        case .rm: return "Romansh"
        case .rn: return "Rundi"
        case .ru: return "Russian"
        case .sm: return "Samoan"
        case .sg: return "Sango"
        case .sa: return "Sanskrit"
        case .sc: return "Sardinian"
        case .sr: return "Serbian"
        case .sn: return "Shona"
        case .ii: return "Sichuan Yi; Nuosu"
        case .sd: return "Sindhi"
        case .si: return "Sinhala; Sinhalese"
        case .sk: return "Slovak"
        case .sl: return "Slovenian"
        case .so: return "Somali"
        case .nr: return "South Ndebele"
        case .st: return "Southern Sotho"
        case .es: return "Spanish; Castilian"
        case .su: return "Sundanese"
        case .sw: return "Swahili"
        case .ss: return "Swati"
        case .sv: return "Swedish"
        case .tl: return "Tagalog"
        case .ty: return "Tahitian"
        case .tg: return "Tajik"
        case .ta: return "Tamil"
        case .tt: return "Tatar"
        case .te: return "Telugu"
        case .th: return "Thai"
        case .bo: return "Tibetan"
        case .ti: return "Tigrinya"
        case .to: return "Tonga (Tonga Islands)"
        case .ts: return "Tsonga"
        case .tn: return "Tswana"
        case .tr: return "Turkish"
        case .tk: return "Turkmen"
        case .tw: return "Twi"
        case .ug: return "Uighur; Uyghur"
        case .uk: return "Ukrainian"
        case .ur: return "Urdu"
        case .uz: return "Uzbek"
        case .ve: return "Venda"
        case .vi: return "Vietnamese"
        case .vo: return "Volapük"
        case .wa: return "Walloon"
        case .cy: return "Welsh"
        case .fy: return "Western Frisian"
        case .wo: return "Wolof"
        case .xh: return "Xhosa"
        case .yi: return "Yiddish"
        case .yo: return "Yoruba"
        case .za: return "Zhuang; Chuang"
        }
    }
}
