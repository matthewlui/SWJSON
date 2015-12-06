
import SWStringExtension

typealias SWJSONDict = [SWJSON:SWJSON]
typealias SWJSONArray = [SWJSON]

enum xJSONParsingError:ErrorType {
    case ParsingFail(reason:String,areaRange:Range<String.Index>)
}

class SWJSONCore {
    private var rawString    :String
    init (str:String){
        self.rawString = str
    }
    subscript (range:Range<String.Index>) -> String?{
        get{
            if range.endIndex < rawString.endIndex{
                return rawString[range]
            }
            return nil
        }
    }
}

public class SWJSON{

    private var range : Range<String.Index>

    private var json  : SWJSONCore

    enum JSONValue{
        case StringValue
        case NumberValue
        case DictionaryValue(SWJSONDict)
        case ArrayValue(SWJSONArray)
        case BoolenValue
        case Null
        case Undefined
    }

    lazy var value    : JSONValue = {
        .Undefined
    }()

    lazy var stringValue    : String?
    = {
        if case .StringValue = self.value{
            return self.json.rawString[self.range]
        }
        return nil
    }()

    lazy var dictionaryValue: SWJSONDict?
    = {
        if case let .DictionaryValue ( dict ) = self.value{
            return dict
        }
        return nil
    }()

    lazy var arrayValue     : SWJSONArray?
    = {
        if case let .ArrayValue ( array ) = self.value{
            return array
        }
        return nil
    }()

    lazy var boolenValue    : Bool?
    = {
        if case .BoolenValue = self.value{
            return self.range.startIndex.distanceTo(self.range.endIndex) == 4
        }
        return false
    }()

    lazy var intValue       : Int?
    = {
        if case .NumberValue = self.value {
            return Int(self.json.rawString[self.range])
        }
        return nil
    }()

    lazy var doubleValue    : Double?
    = {
        if case .NumberValue = self.value {
            let s = self.json.rawString[self.range]
            let d = Double(s)
            return Double(self.json.rawString[self.range])
        }
        return nil
    }()

    init (str:String) {
        self.json  = SWJSONCore(str: str.trimHeadAndTailSapce())
        self.range = str.startIndex...str.endIndex.predecessor()
    }

    init (json:SWJSON,range:Range<String.Index>,value:JSONValue){
        self.json  = json.json
        self.range = range
        self.value = value
    }

}

extension SWJSON {
    static func parseJSONString(str:String) throws ->  SWJSON? {
        var stringToParse       = str //.trimHeadAndTailSapce()
        var json                = SWJSON(str: stringToParse)
        func parse(from:String.Index,stringToParse:String) throws ->  SWJSON?{
            var workingRange        = from...from
            var startSymblo         = stringToParse[from]
            var cache               = [SWJSON]()
            while workingRange.endIndex < stringToParse.endIndex{

                switch (startSymblo,stringToParse[workingRange.endIndex]) {
                case ("{", let currentChar ):
                    if currentChar.containedInString(" \n"){
                        workingRange = workingRange.startIndex...stringToParse.nextNoneEmptyIndex(workingRange.endIndex).predecessor()
                        break
                    }else if currentChar.containedInString(":,"){
                        workingRange = workingRange.startIndex...stringToParse.nextNoneEmptyIndex(workingRange.endIndex.successor()).predecessor()
                    }
                    if currentChar == "}"{
                        var dict = [SWJSON:SWJSON]()
                        while let first = cache.first {
                            cache.removeFirst()
                            guard let second = cache.first else{
                                return SWJSON(json: json, range: workingRange, value: .DictionaryValue(dict))
                            }
                            dict[first] = second
                            cache.removeFirst()
                        }
                        workingRange.expand()
                        return SWJSON(json: json, range: workingRange, value: .DictionaryValue(dict))
                    }
                    do{
                        guard let jObject = try parse(workingRange.endIndex, stringToParse: stringToParse) else {
                            return nil
                        }
                        workingRange.endIndex = jObject.range.endIndex
                        cache.append(jObject)
                        stringToParse[workingRange.endIndex]
                    }catch let err{
                        throw err
                    }
                    break

                case ("[",let currentChar):
                    if currentChar.containedInString(" \n"){
                        workingRange = workingRange.startIndex...stringToParse.nextNoneEmptyIndex(workingRange.endIndex).predecessor()
                        break
                    }else if currentChar == ","{
                        workingRange = workingRange.startIndex...stringToParse.nextNoneEmptyIndex(workingRange.endIndex.successor()).predecessor()
                    }
                    if currentChar == "]"{
                        workingRange.expand()
                        return SWJSON(json: json, range: workingRange, value: .ArrayValue(cache))
                    }
                    do {
                        guard let jObject = try parse(workingRange.endIndex, stringToParse: stringToParse) else{
                            return nil
                        }
                        workingRange.endIndex = jObject.range.endIndex
                        cache.append(jObject)
                    }catch let err{
                        throw err
                    }
                    break

                case ("\"", let currentChar):
                    workingRange.expand()
                    if currentChar == "\\"{
                        // Skip next char
                        workingRange.expand()
                        break
                    }
                    if currentChar == "\""{
                        // packing back cache and return
                        return SWJSON(json: json, range: workingRange, value: .StringValue)
                    }

                case let ( beginChar , b ) where beginChar.containedInString("+-.0123456789") :
                    //MARK: move backward if test fail

                    if b.containedInString(",}] "){
                        let j = SWJSON(json: json, range: workingRange, value: .NumberValue)
                        workingRange.expand()
                        return j

                    }
                    workingRange.expand()
                    break

                case let ( beginChar, _ ) where beginChar.containedInString("nN") :
                    let assumingRange = workingRange.startIndex...workingRange.startIndex.advancedBy(3)
                    return SWJSON(json: json, range: assumingRange, value: .Null)

                case let ( beginChar, _ ) where beginChar.containedInString("tT") :
                    let assumingRange = workingRange.startIndex...workingRange.startIndex.advancedBy(3)
                    return SWJSON(json: json, range: assumingRange, value: .BoolenValue)

                case let ( beginChar, _ ) where beginChar.containedInString("fF"):
                    let assumingRange = workingRange.startIndex...workingRange.startIndex.advancedBy(4)
                    return SWJSON(json: json, range: assumingRange, value: .BoolenValue)

                case let ( beginChar, _ ) where beginChar.containedInString(" \n"):
                    let nextNoneEmpty = stringToParse.nextNoneEmptyIndex(workingRange.startIndex)
                    if nextNoneEmpty < workingRange.endIndex{
                        workingRange = nextNoneEmpty...workingRange.endIndex.predecessor()
                        startSymblo = stringToParse[workingRange.startIndex]
                    }else{
                        workingRange = nextNoneEmpty...nextNoneEmpty
                    }

                    break

                default:
                    if workingRange.startIndex.successor() < workingRange.endIndex.predecessor(){
                        workingRange = workingRange.startIndex.successor()...workingRange.endIndex.predecessor()
                        break
                    }
                    throw xJSONParsingError.ParsingFail(reason: "Undefined : (\(stringToParse[workingRange])) \n", areaRange: workingRange)
                }
            }
            return nil
        }
        do {
            return try parse(stringToParse.startIndex, stringToParse: stringToParse)
        }catch let err{
            throw err
        }
    }
}

extension SWJSON {
    subscript (key:String) -> AnyObject? {
        get {
            if let dict = dictionaryValue,
                let value = dict[SWJSON(str: key)]{
                    switch value.value {
                    case .NumberValue:
                        return value.doubleValue
                    case .StringValue:
                        return value.stringValue
                    case .ArrayValue(let array):
                        return array
                    case .DictionaryValue(let dict):
                        return dict
                    case .BoolenValue:
                        return value.boolenValue
                    case .Undefined:
                        return "Undefined"
                    case .Null:
                        return nil
                    }
                return value
            }
            return nil
        }
    }
}

extension SWJSON : Hashable {
    public var hashValue : Int {
        return json.rawString[range].unwrapSymblo(("\"","\"")).hashValue
    }
}

public func == (lhs:SWJSON,rhs:SWJSON) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

struct JSONBlockIdentifier {
    static let Dictionary   = "{}"
    static let Array        = "[]"
    static let String       = "\""
    static let Number       = ".0123456789"
    static let Boolen       = "TFE"
    static let NULL         = "NULL"
    static let null         = "null"
}

extension SWJSON:CustomDebugStringConvertible{

    public var debugDescription:String {
        switch self.value{
        case .StringValue:
            return "String:" + json.rawString[range] + "\n"
        case .DictionaryValue(let dict):
            var str = "Dictionary:\n"
            if dict.isEmpty {
                return str + "{ }"
            }
            str     += "{"
            for (k,v) in dict {
                switch v.value{
                case .ArrayValue(_):
                    str += "  key:\(k.debugDescription)\n ," + "  value:Array \n"
                    break
                case .DictionaryValue(_):
                    str += "  key:\(k.debugDescription)\n ," + "  value: Dictionary \n"
                    break

                default:
                    str += "  key:\(k.debugDescription)\n ," + "  value:\(v.debugDescription)\n"
                }
            }
            return str + "}"
        case .NumberValue:
            return "Number:" + json.rawString[range] + "\n"
        case .ArrayValue(let array):
            var str = "Array:\n [ "
            //TODO: decription may limit to first & last 10?
            //str  = "Original:" + json.rawValue[range] + "\n"
            if array.isEmpty {
                return str + " empty ]"
            }
            for (i,v) in array.enumerate() {
                switch v.value {
                case .ArrayValue(_):
                    str += "[\(i)] =  Array \n"
                    break
                case .DictionaryValue(_):
                    str += "[\(i)] = Dictionary \n"
                    break
                default:
                    str += "[\(i)] = " + v.debugDescription + "\n"
                }

            }
            return str + "]"
        case .Null:
            return "Null:" + json.rawString[range] + "\n"
        case .BoolenValue:
            return "Boolen:" + json.rawString[range] + "\n"
        default:
            return "Undefined"
        }
    }

}
