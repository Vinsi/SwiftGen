import Foundation

public class SwiftGenL10nEnumBuilder {

    public init() {}

    public func parseLocalizableStringsFile(path: String) throws {
        let fileContent = try NSString(contentsOfFile: path, encoding: NSUTF8StringEncoding)
        let lines = fileContent.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        for case let entry? in lines.map(Entry.init) {
            addEntry(entry)
        }
    }
    
    public func addEntry(entry: Entry) {
        parsedLines.append(entry)
    }
    
    public func build(enumName : String = "L10n") -> String {
        var enumText = "// AUTO-GENERATED FILE, DO NOT EDIT\n\n"
        
        enumText += "enum \(enumName.asSwiftIdentifier()) {\n"
        
        for entry in parsedLines {
            let caseName = entry.key.asSwiftIdentifier(forbiddenChars: "_")
            enumText += "\tcase \(caseName)"
            if !entry.types.isEmpty {
                enumText += "(" + ", ".join(entry.types.map{ $0.rawValue }) + ")"
            }
            enumText += "\n"
        }
        
        enumText += "}\n\n"
        
        enumText += "extension \(enumName.asSwiftIdentifier()) : CustomStringConvertible {\n"
        
        enumText += "\tvar description : String { return self.string }\n\n"
        
        enumText += "\tvar string : String {\n"
        enumText += "\t\tswitch self {\n"
        
        for entry in parsedLines {
            let caseName = entry.key.asSwiftIdentifier(forbiddenChars: "_")
            enumText += "\t\t\tcase .\(caseName)"
            if !entry.types.isEmpty {
                let params = (0..<entry.types.count).map { "let p\($0)" }
                enumText += "(" + ", ".join(params) + ")"
            }
            enumText += ":\n"
            enumText += "\t\t\t\treturn L10n.tr(\"\(entry.key)\""
            if !entry.types.isEmpty {
                enumText += ", "
                let params = (0..<entry.types.count).map { "p\($0)" }
                enumText += ", ".join(params)
            }
            enumText += ")\n"
        }
        
        enumText += "\t\t}\n"
        enumText += "\t}\n\n"
        
        enumText += "\tprivate static func tr(key: String, _ args: CVarArgType...) -> String {\n"
        enumText += "\t\tlet format = NSLocalizedString(key, comment: \"\")\n"
        enumText += "\t\treturn String(format: format, arguments: args)\n"
        enumText += "\t}\n"
        enumText += "}\n\n"
        
        enumText += "func tr(key: L10n) -> String {\n"
        enumText += "\treturn key.string\n"
        enumText += "}\n"
        
        return enumText
    }
    
    
    
    // MARK: - Public Enum types
    
    public enum PlaceholderType : String {
        case String
        case Float
        case Int
        
        init?(formatChar char: Character) {
            switch char {
            case "@":
                self = .String
            case "f":
                self = .Float
            case "d", "i", "u":
                self = .Int
            default:
                return nil
            }
        }
    }
    
    public struct Entry {
        let key: String
        let types: [PlaceholderType]
        
        init(key: String, types: [PlaceholderType]) {
            self.key = key
            self.types = types
        }
        
        init(key: String, types: PlaceholderType...) {
            self.key = key
            self.types = types
        }
        
        init?(line: String) {
            let range = NSRange(location: 0, length: line.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
            let regex = try! NSRegularExpression(pattern: "^\"([^\"]*)\" *= *\"(.*)\";", options: [])
            if let match = regex.firstMatchInString(line, options: [], range: range) {
                
                let key = (line as NSString).substringWithRange(match.rangeAtIndex(1))
                
                let translation = (line as NSString).substringWithRange(match.rangeAtIndex(2))
                let types = SwiftGenL10nEnumBuilder.typesFromFormatString(translation)
                
                self = Entry(key: key, types: types)
            }
            return nil
        }
    }
    
    
    
    // MARK: - Private Helpers
    
    private var parsedLines = [Entry]()
    
    // "I give %d apples to %@" --> [.Int, .String]
    private static func typesFromFormatString(formatString: String) -> [PlaceholderType] {
        var types = [PlaceholderType]()
        var placeholderIndex: Int? = nil
        var lastPlaceholderIndex = 0
        
        for char in formatString.characters {
            if char == Character("%") {
                // TODO: Manage the "%%" special sequence
                placeholderIndex = lastPlaceholderIndex++
            }
            else if placeholderIndex != nil {
                // TODO: Manage positional placeholders like "%2$@"
                //       That change the order the placeholder should be inserted in the types array
                //        (If types.count+1 < placehlderIndex, we'll need to insert "Any" types to fill the gap)
                if let type = PlaceholderType(formatChar: char) {
                    types.append(type)
                    placeholderIndex = nil
                }
            }
        }
        
        return types
    }
}

