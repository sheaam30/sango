//
//  App.swift
//  Sango
//
//  Created by Steve Hales on 8/10/16.
//  Copyright © 2016 Afero, Inc. All rights reserved.
//

import Foundation
import AppKit
import CoreGraphics

/* enums
 
 java
 public enum Day {
    SUNDAY, MONDAY, TUESDAY, WEDNESDAY,
    THURSDAY, FRIDAY, SATURDAY
 }
 swift
 enum Day {
 case Sunday
 case Monday
 case Tuesday
 case Wednesday
 }

*/

let SchemaVersion = 1

let keySchemaVersion = "schemaVersion"
let keyFonts = "fonts"
let keyFontRoot = "fontRoot"
let keyImages = "images"
let keyLocale = "locale"
let keyEnums = "enums"
let keyImagesScaled = "imagesScaled"
let keyImagesScaledIos = "imagesScaledIos"
let keyImagesScaledAndroid = "imagesScaledAndroid"
let keyImagesScaledUp = "imagesScaledUp"
let keyImagesScaledIosUp = "imagesScaledIosUp"
let keyImagesScaledAndroidUp = "imagesScaledAndroidUp"
let keyImagesIos = "imagesIos"
let keyImagesAndroid = "imagesAndroid"
let keyGlobalTint = "globalTint"
let keyGlobalIosTint = "globalTintIos"
let keyGlobalAndroidTint = "globalTintAndroid"
let keyCopied = "copied"
let keyCopiedIos = "copiedIos"
let keyCopiedAndroid = "copiedAndroid"
let keyAppIcon = "appIcon"
let keyIOSAppIcon = "appIconIos"
let keyAndroidAppIcon = "appIconAndroid"
let keyAndroidLayout = "layoutAndroid"
let keyJava = "java"
let keySwift = "swift"
let firstPassIgnoredKeys = [keyCopied, keyIOSAppIcon, keyAndroidAppIcon, keyAppIcon,
                                    keyFonts, keyFontRoot, keySchemaVersion, keyAndroidLayout, keyEnums,
                                    keyImagesScaled, keyImagesScaledIos, keyImagesScaledAndroid,
                                    keyImagesScaledUp, keyImagesScaledIosUp, keyImagesScaledAndroidUp,
                                    keyImages, keyImagesIos, keyImagesAndroid, keyLocale,
                                    keyJava, keySwift, keyGlobalTint,
                                    keyGlobalIosTint, keyGlobalAndroidTint]

enum LangType {
    case unset
    case java
    case swift
}

enum AssetType {
    case font
    case layout
    case image
    case raw
}

enum ScaleType {
    case up
    case down
}

let assetTagIgnore = "~"
let assetTagHead = "head"

// app command line options
let optAssetTemplates = "-asset_template"
let optConfigTemplate = "-config_template"
let optConfig = "-config"
let optValidate = "-validate"
let optInput = "-input"
let optInputs = "-inputs"
let optInputAssets = "-input_assets"
let optOutSource = "-out_source"
let optJava = "-java"
let optSwift = "-swift"
let optOutAssets = "-out_assets"
let optInputAssetsTag = "-input_assets_tag"
let optVerbose = "-verbose"
let optHelpKeys = "-help_keys"
let optVersion = "-version"
let optLocaleOnly = "-locale_only"
let optSwift3 = "-swift3"

class App
{
    static let copyrightNotice = "Sango © 2016 Afero, Inc - Build \(BUILD_REVISION)"

    var package:String = ""
    var baseClass:String = ""
    var appIconName:String = "ic_launcher.png"
    var sourceAssetFolder:String? = nil
    var outputAssetFolder:String? = nil

    var inputFile:String? = nil
    var inputFiles:[String]? = nil
    var outputClassFile:String? = nil
    var assetTag:String? = nil

    var compileType:LangType = .unset
    var localeOnly:Bool = false

    var globalTint:NSColor? = nil
    var globalIosTint:NSColor? = nil
    var globalAndroidTint:NSColor? = nil
    var gitEnabled = false

    var swift3Output = false

    // because Android colors are stored as an xml file, we collect them when walking through the constants,
    // and write them out last
    var androidColors:[String:Any] = [:]

    var enumsFound: [String:Any] = [:]

    func usage() -> Void {
        let details = [
            optAssetTemplates: ["[basename]", "creates a json template, specifically for the assets"],
            optConfigTemplate: ["[file.json]", "creates a json template, specifically for the app"],
            optConfig: ["[file.json]", "use config file for options, instead of command line"],
            optValidate: ["[asset_file.json, ...]", "validates asset JSON file(s), requires \(optInputAssets)"],
            optInput: ["[file.json]", "asset json file"],
            optInputs: ["[file1.json file2.json ...]", "merges asset files and process"],
            optInputAssets: ["[folder]", "asset source folder (read)"],
            optOutSource: ["[source.java|swift]", "path to result of language"],
            optJava: ["", "write java source"],
            optSwift: ["", "write swift source"],
            optOutAssets: ["[folder]", "asset root folder (write), typically iOS Resource, or Android app/src/main"],
            optInputAssetsTag: ["[tag]", "optional git tag to pull repro at before processing"],
            optVerbose: ["", "be verbose in details"],
            optHelpKeys: ["", "display JSON keys and their use"],
            optVersion: ["", "version"],
            optLocaleOnly: ["", "when included, process localization files only"]
        ]
        var keyLength = 0
        var parmLength = 0
        for (key, value) in details {
            if (key.characters.count > keyLength) {
                keyLength = key.characters.count
            }
            if (value[0].characters.count > parmLength) {
                parmLength = value[0].characters.count
            }
        }
        
        print(App.copyrightNotice)
        print("Usage:")
        for (key, value) in Array(details).sorted(by: {$0.0 < $1.0}) {
            let item1 = value[0]
            let item2 = value[1]
            let output = key.padding(toLength: keyLength + 3, withPad: " ", startingAt: 0) +
                        item1.padding(toLength: parmLength + 3, withPad: " ", startingAt: 0) +
                        "  " + item2
            print(output)
        }
    }

    func helpKeys() -> Void {
        let details = [keySchemaVersion: "number. Version, which should be \(SchemaVersion)",
                       keyFonts: "array. path to font files",
                       keyFontRoot: "path. Destination font root. Default is root of resources",
                       keyEnums: "dictionary. keys are enum key:value name",
                       keyImages: "array. path to image files that are common.",
                       keyLocale: "dictionary. keys are IOS lang. ie, enUS, enES, path to strings file",
                       keyImagesIos: "array. path to image files that are iOS only",
                       keyImagesAndroid: "array. path to image files that are Android only",
                       keyImagesScaled: "array. path to image files that are common and will be scaled. Source is always scaled down",
                       keyImagesScaledIos: "array. path to image files that are iOS only and will be scaled. Source is always scaled down",
                       keyImagesScaledAndroid: "array. path to image files that are Android only and will be scaled. Source is always scaled down",
                       keyImagesScaledUp: "array. path to image files that are common and will be scaled. Source is always scaled up",
                       keyImagesScaledIosUp: "array. path to image files that are iOS only and will be scaled. Source is always scaled up",
                       keyImagesScaledAndroidUp: "array. path to image files that are Android only and will be scaled. Source is always scaled up",
                       keyCopied: "array. path to files that are common and are just copied",
                       keyCopiedIos: "array. path to files that are iOS only and are just copied",
                       keyCopiedAndroid: "array. path to files that Android only and are just copied",
                       keyAppIcon: "string. path to app icon that is common and is scaled",
                       keyIOSAppIcon: "string. path to app icon that is iOS  and is scaled",
                       keyAndroidAppIcon: "string. path to app icon that is Android only and is scaled",
                       keyAndroidLayout: "array. path to layout files that is Android only",
                       keySwift: "dictionary. keys are base:class name",
                       keyJava: "dictionary. keys are base:class name, package:package name",
                       keyGlobalTint: "color. ie #F67D4B. apply as tint to all images saved",
                       keyGlobalIosTint: "color. ie #F67D4B. apply as tint to all images saved for iOS",
                       keyGlobalAndroidTint: "color. ie #F67D4B. apply as tint to all images saved for Android"
                       ]
        var keyLength = 0
        for (key, _) in details {
            if (key.characters.count > keyLength) {
                keyLength = key.characters.count
            }
        }
        print("JSON keys and their meaning:")
        for (key, value) in Array(details).sorted(by: {$0.0 < $1.0}) {
            let keyPad = key.padding(toLength: keyLength + 3, withPad: " ", startingAt: 0)
            print(keyPad + value)
        }
    }
    
    // Save image, tinted
    @discardableResult func saveImage(_ image: NSImage, file: String) -> Bool {
        var tint:NSColor? = globalTint
        var result: Bool = false
    
        if ((compileType == .java) && (globalAndroidTint != nil)) {
            tint = globalAndroidTint
        }
        else if ((compileType == .swift) && (globalIosTint != nil)) {
            tint = globalIosTint
        }
        
        if (tint != nil) {
            let tintedImage = image.tint(globalTint!)
            result = tintedImage.saveTo(file)
        }
        else {
            result = image.saveTo(file)
        }
        if (result == false) {
            // an error was printed, just exit
            exit(-1)
        }
        return true
    }
    
    @discardableResult func saveString(_ data:String, file: String) -> Bool
    {
        do {
            try data.write(toFile: file, atomically: true, encoding: String.Encoding.utf8)
        }
        catch {
            Utils.error("Error: writing to \(file)")
            exit(-1)
        }
        return true
    }
    
    func writeImageStringArray(_ stringArray: Dictionary<String, Any>, type: LangType) -> String {
        var outputString = "\n"
        if (type == .swift) {
            // public static let UiSecondaryColorTinted = ["account_avatar1", "account_avatar2"]
            for (key, value) in Array(stringArray).sorted(by: {$0.0 < $1.0}) {
                outputString.append("\tpublic static let \(key) = [\"")
                let strValue = String(describing: value)
                outputString.append(strValue + "\"]\n")
            }
        }
        else if (type == .java) {
            // public static final String[] UI_SECONDARY_COLOR_TINTED = {"account_avatar1", "account_avatar2"};
            for (key, value) in Array(stringArray).sorted(by: {$0.0 < $1.0}) {
                outputString.append("\tpublic static final String[] \(key) = {\"")
                let strValue = String(describing: value)
                outputString.append(strValue + "\"};\n")
            }
        }
        else {
            Utils.error("Error: invalid output type")
            exit(-1)
        }
        return outputString
    }

    func parseColor(_ color: String) -> (r:Double, g:Double, b:Double, a:Double, s:Int,
                                            rgb:UInt32, hexRgb:String)?
    {
        var red:Double = 0.0
        var green:Double = 0.0
        var blue:Double = 0.0
        var alpha:Double = 1.0
        var rgbValue:UInt32 = 0
        var isColor = false
        var size = 0
        var hexRgb = ""
        let parts = color.components(separatedBy: ",")
        if (parts.count == 3 || parts.count == 4) {
            // color
            red = Double(parts[0])! / 255.0
            green = Double(parts[1])! / 255.0
            blue = Double(parts[2])! / 255.0
            alpha = 1
            size = 3
            if (parts.count == 4) {
                alpha = Double(parts[3])! / 255.0
                size = 4
            }
            isColor = true
            let r = UInt32(red * 255.0)
            let g = UInt32(green * 255.0)
            let b = UInt32(blue * 255.0)
            let a = UInt32(alpha * 255.0)
            rgbValue = (a << 24) | (r << 16) | (g << 8) | b
            if (size == 4) {
                hexRgb = String(format:"#%.2X%.2X%.2X%.2X", a, r, g, b)
            }
            else {
                hexRgb = String(format:"#%.2X%.2X%.2X", r, g, b)
            }
        }
        else if (color.hasPrefix("#")) {
            var hexStr = color.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            hexStr = hexStr.substring(from: hexStr.characters.index(hexStr.startIndex, offsetBy: 1))
            
            Scanner(string: hexStr).scanHexInt32(&rgbValue)
            red = 1
            green = 1
            blue = 1
            alpha = 1
            
            if (hexStr.characters.count < 6) {
                Utils.error("Error: not enough characters for hex color definition. Needs 6.")
                exit(-1)
            }
            
            if (hexStr.characters.count >= 6) {
                red = Double((rgbValue & 0x00FF0000) >> 16) / 255.0
                green = Double((rgbValue & 0x0000FF00) >> 8) / 255.0
                blue = Double(rgbValue & 0x000000FF) / 255.0
                size = 3
            }
            if (hexStr.characters.count == 8) {
                alpha = Double((rgbValue & 0xFF000000) >> 24) / 255.0
                size = 4
            }
            isColor = true
            let r = UInt32(red * 255.0)
            let g = UInt32(green * 255.0)
            let b = UInt32(blue * 255.0)
            let a = UInt32(alpha * 255.0)
            if (size == 4) {
                hexRgb = String(format:"#%.2X%.2X%.2X%.2X", a, r, g, b)
            }
            else {
                hexRgb = String(format:"#%.2X%.2X%.2X", r, g, b)
            }
        }
        if (isColor) {
            return (r: red, g: green, b: blue, a: alpha, s: size, rgb:rgbValue, hexRgb: hexRgb)
        }
        return nil
    }
    
    func writeEnums(_ enums: Dictionary<String, Any>, type: LangType) -> String {
        var outputString = "\n"
        let sorted = Array(enums).sorted(by: {$0.0 < $1.0})
        if (type == .swift) {
            for (key, value) in sorted {
                let list:[String] = value as! [String]
                outputString.append("public enum \(key.snakeCaseToCamelCase()) {\n")
                for itm in list {
                    outputString.append("\tcase \(itm.snakeCaseToCamelCase())\n")
                }
                outputString.append("}\n")
            }
        }
        else if (type == .java) {
            for (key, value) in sorted {
                let list:[String] = value as! [String]
                outputString.append("public enum \(key.snakeCaseToCamelCase()) {\n\t")
                var firstComma = false
                for itm in list {
                    if (firstComma) {
                        outputString.append(", ")
                    }
                    else {
                        firstComma = true
                    }
                    outputString.append(itm.uppercased())
                }
                outputString.append("\n}\n")
            }
        }
        else {
            Utils.error("Error: invalid output type")
            exit(-1)
        }
        return outputString
    }

    func writeSangoExtras(_ type: LangType, filePath: String) -> Void {
        var outputStr = "/* Generated with Sango, by Afero.io */\n\n"
        if (type == .swift) {
            outputStr.append("import UIKit\n")
        }
        else if (type == .java) {
            if (package.isEmpty) {
                outputStr.append("package java.lang;\n")
            }
            else {
                outputStr.append("package \(package);\n")
            }
        }
        if (type == .swift) {
            outputStr.append("public struct Sango {\n")
            outputStr.append("\tpublic static let Version = \"\(App.copyrightNotice)\"\n")
            outputStr.append("}\n\n")
            outputStr.append("extension String {\n")
            outputStr.append("\tinit(locKey key: String, value: String) {\n")
            outputStr.append("\t\tlet v = NSBundle.mainBundle().localizedStringForKey(key, value: value, table: nil)\n")
            outputStr.append("\t\tself.init(v)\n")
            outputStr.append("\t}\n\n")
            
            outputStr.append("\tinit(locKey key: String) {\n")
            outputStr.append("\t\tlet v = NSBundle.mainBundle().localizedStringForKey(key, value: nil, table: nil)\n")
            outputStr.append("\t\tself.init(v)\n")
            outputStr.append("\t}\n")
            
            outputStr.append("}\n")
        }
        else if (type == .java) {
            outputStr.append("public final class Sango {\n")
            outputStr.append("\tpublic static final String VERSION = \"\(App.copyrightNotice)\";\n")
            outputStr.append("}\n")
        }
        var sangoFile = filePath
        if (type == .swift) {
            sangoFile += "/Sango.swift"
        }
        else if (type == .java) {
            sangoFile += "/Sango.java"
        }
        saveString(outputStr, file: sangoFile)
    }

    func writeAndroidColors() -> Void {
        if (androidColors.count > 0) {
            var destPath = outputAssetFolder! + "/res/values"
            Utils.createFolder(destPath)
            destPath.append("/colors.xml")
            var outputStr = "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- Generated with Sango, by Afero.io -->\n"
            outputStr.append("<resources>\n")
            let sorted = androidColors.keys.sorted()
            for key in sorted {
                let color = parseColor(androidColors[key] as! String)
                if (color != nil) {
                    //    <color name="medium_gray">#939597</color>
                    // RGB
                    // ARGB
                    let hex = String(color!.hexRgb)
                    outputStr.append("\t<color name=\"\(key)\">\(hex)</color>\n")
                }
            }
            outputStr.append("</resources>\n")
            saveString(outputStr, file: destPath)
        }
    }
    
    struct EnumResults {
        var error = false
        var valid = false
        var enumType = ""
        var origType = ""
    }
    func validateEnum(_ name: String, value: String) -> EnumResults {
        var results = EnumResults()

        let valueBeta = value.snakeCaseToCamelCase()
        let keyBeta = name.snakeCaseToCamelCase()
        for (keyA, valueA) in enumsFound {
            let keyAlpha = keyA.snakeCaseToCamelCase()
            let list = valueA as! Array<String>
            for enumItm in list {
                let valueAlpha = enumItm.snakeCaseToCamelCase()
                if (keyAlpha != keyBeta) {
                    if (valueAlpha == valueBeta) {
                        results.enumType = keyA
                        results.origType = name
                        results.valid = true
                        break
                    }
                }
                else {
                    Utils.error("Error: Constant '\(name).\(value)' can't be the same as an enum type '\(keyA)'")
                    results.error = true
                    return results
                }
            }
        }
        return results
    }

    enum ValueType :String {
        case Color = "Color"
        case Int = "int"
        case String = "String"
        case Float = "double"
        case Boolean = "Boolean"
        case CustomEnum = "CustomEnum"
    }

    func parseSwiftConstant(_ key: String, value: Any) -> String {
        var outputString = ""
        let strValue = String(describing: value)

        let enums = validateEnum(key, value: strValue)
        if (enums.error) {
            exit(-1)
        }
        
        if (enums.valid && (key == enums.origType)) {
            let lineValue = "\(enums.enumType).\(String(describing: value))".snakeCaseToCamelCase()
            outputString.append(lineValue + "\n");
        }
        else {
            if ((value as AnyObject).className == "__NSCFBoolean") {
                outputString.append((value as AnyObject).boolValue.description)
            }
            else if (value is String) {
                if (strValue.isInteger() == true) {
                    outputString.append(String(describing: value));
                }
                else {
                    let color = parseColor(strValue)
                    if (color != nil) {
                        let line = "UIColor(red: \(roundTo3f(value: color!.r)), green: \(roundTo3f(value: color!.g)), blue: \(roundTo3f(value: color!.b)), alpha: \(roundTo3f(value: color!.a)))"
                        outputString.append(line + " /* \(value) */")
                    }
                    else {
                        outputString.append("\"\(String(describing: value))\"")
                    }
                }
            }
            else {
                outputString.append(strValue);
            }
        }

        return outputString
    }
    
    func parseJavaConstant(_ key: String, value: Any) -> (type:ValueType, output:String, results:EnumResults) {
        var outputString = ""
        var type = ValueType.Int
        let strValue = String(describing: value)

        let enums = validateEnum(key, value: strValue)
        if (enums.error) {
            exit(-1)
        }
        
        if (enums.valid && (key == enums.origType)) {
            let lineValue = "\(enums.enumType.snakeCaseToCamelCase()).\(strValue)"
            outputString.append(lineValue);
            type = ValueType.CustomEnum
        }
        else {
            if ((value as AnyObject).className == "__NSCFBoolean") {
                type = ValueType.Boolean
                outputString.append((value as AnyObject).boolValue.description)
            }
            else if (strValue.isFloat()) {
                type = ValueType.Float
                outputString.append(strValue)
            }
            else if (value is String) {
                if (strValue.isInteger() == true) {
                    outputString.append(strValue)
                }
                else {
                    type = ValueType.String
                    
                    let color = parseColor(strValue)
                    if (color != nil) {
                        type = ValueType.Color
                    }
                    else {
                        let line = "\"" + strValue + "\""
                        outputString.append(line)
                    }
                }
            }
            else {
                if (strValue.isFloat()) {
                    type = .Float
                }
                outputString.append(strValue);
            }
        }
        return (type:type, output:outputString, results:enums)
    }

    func writeConstants(_ name: String, value: Any, type: LangType) -> String {
        var outputString = "\n"
        if (type == .swift) {
            if let constantsDictionary = value as? Dictionary<String, Any> {
                outputString.append("public struct ")
                outputString.append(name + " {\n")
                for (key, value) in Array(constantsDictionary).sorted(by: {$0.0 < $1.0}) {
                    let line = "\tstatic let " + key.snakeCaseToCamelCase() + " = "
                    outputString.append(line)
                    let lineValue = parseSwiftConstant(key, value: value)
                    outputString.append(lineValue + "\n");
                }
                outputString.append("}")
            }
            else if let constantsArray = value as? Array<Any> {
                outputString.append("public static let \(name) = [\n\t\t")
                let lastItm = constantsArray.count - 1
                for (index, itm) in constantsArray.enumerated() {
                    let lineValue = parseSwiftConstant(String(index), value: itm)
                    outputString.append(lineValue);
                    if (index < lastItm) {
                        outputString.append(",\n\t\t")
                    }
                }
                outputString.append("\n\t]");
            }
        }
        else if (type == .java) {
            var skipClass = true
            var outputClassString = ""
            
            if let constantsDictionary = value as? Dictionary<String, Any> {
                for (key, value) in Array(constantsDictionary).sorted(by: {$0.0 < $1.0}) {
                    let strValue = String(describing: value)
                    let lineValue = parseJavaConstant(key, value: value)
                    if (lineValue.type == .Color) {
                        // ok, we have a color, so we're going to store it
                        let colorKey = name + "_\(key)"
                        androidColors[colorKey.lowercased()] = strValue as Any?
                    }
                    else if (lineValue.type == .CustomEnum) {
                        let line = "\tpublic static final " + lineValue.results.enumType.snakeCaseToCamelCase() + " " +
                            key.uppercased() + " = \(lineValue.output);\n"
                        outputClassString.append(line)
                        skipClass = false
                    }
                    else {
                        let line = "\tpublic static final " + lineValue.type.rawValue + " " +
                                key.uppercased() + " = \(lineValue.output);\n"
                        outputClassString.append(line)
                        skipClass = false
                    }
                }
            }
            else if let constantsArray = value as? Array<Any> {
                let lastItm = constantsArray.count - 1
                var ending = false
                // ok we have an array of strings, int, floats, we have to figure out a type before hand for Java
                var type:ValueType = .String
                if (hasArrayFloats(value)) {
                    type = .Float
                }
                else if (hasArrayInts(value)) {
                    type = .Int
                }
                else {
                    for (index, itm) in constantsArray.enumerated() {
                        let lineValue = parseJavaConstant(String(index), value: itm)
                        if (lineValue.type == .Color) {
                            type = .Color
                            break
                        }
                        if (lineValue.type == .CustomEnum) {
                            type = .CustomEnum
                            outputString.append("public static final \(lineValue.results.enumType.snakeCaseToCamelCase()) \(name)[] = {\n\t")
                            break
                        }
                    }
                }
                if (type != .Color && type != .CustomEnum) {
                    outputString.append("public static final \(type.rawValue) \(name)[] = {\n\t")
                }

                for (index, itm) in constantsArray.enumerated() {
                    let lineValue = parseJavaConstant(String(index), value: itm)
                    if (lineValue.type == .Color) {
                        // ok, we have a color, so we're going to store it
                        let colorKey = name + "_\(index)"
                        androidColors[colorKey.lowercased()] = String(describing: itm)
                    }
                    else {
                        ending = true
                        outputString.append(lineValue.output);
                        if (index < lastItm) {
                            outputString.append(",\n\t")
                        }
                    }
                }
                if (ending) {
                    outputString.append("\n};");
                }
            }

            if (skipClass == false) {
                outputString.append("public static final class ")
                outputString.append(name + " {\n")
                outputString.append(outputClassString)
                outputString.append("}")
            }
        }
        else {
            Utils.error("Error: invalid output type")
            exit(-1)
        }
        return outputString
    }

    // http://petrnohejl.github.io/Android-Cheatsheet-For-Graphic-Designers/
    
    func scaleAndCopyImages(_ files: [String], type: LangType, useRoot: Bool, scale: ScaleType) -> Void {
        for file in files {
            if (type == .java) {
                if (file.isAndroidCompatible() == false) {
                    Utils.error("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                    exit(-1)
                }
            }
            let filePath = sourceAssetFolder! + "/" + file
            var destFile:String
            if (useRoot) {
                destFile = outputAssetFolder! + "/" + file.lastPathComponent()
            }
            else {
                destFile = outputAssetFolder! + "/" + file  // can include file/does/include/path
            }
            let destPath = (destFile as NSString).deletingLastPathComponent
            Utils.createFolder(destPath)

            let imageScale = NSImage.getScaleFrom(file)
            let fileName = imageScale.file

            let baseImage = NSImage.loadFrom(filePath)
            if (baseImage == nil) {
                Utils.error("Error: missing file \(filePath)")
                exit(-1)
            }
            if (type == .swift) {
                let iosScales: [CGFloat:String] = [
                    100:   "@3x.png",
                    66.67: "@2x.png",
                    33.34: ".png"
                ]
                let iosScalesUp: [CGFloat:String] = [
                    300: "@3x.png",
                    200: "@2x.png",
                    100: ".png"
                ]
                let scales = (scale == .down) ? iosScales : iosScalesUp
                for (key, value) in Array(scales).sorted(by: {$0.0 < $1.0}) {
                    if let image = baseImage?.scale(key) {
                        let imageFile = destPath + "/" + fileName + value
                        Utils.debug("Image scale and copy \(filePath) -> \(imageFile)")
                        if (saveImage(image, file: imageFile) == false) {
                            exit(-1)
                        }
                    }
                    else {
                        Utils.error("Error: Failed to scale \(filePath)")
                        exit(-1)
                    }
                }
            }
            else if (type == .java) {
                let androidScales: [CGFloat:String] = [
                    100:   "/res/drawable-xxhdpi/", // 3x
                    66.67: "/res/drawable-xhdpi/",  // 2x
                    50:    "/res/drawable-hdpi/",   // 1.5x
                    33.34: "/res/drawable-mdpi/"    // 1x
                ]
                let androidScalesUp: [CGFloat:String] = [
                    300:   "/res/drawable-xxhdpi/", // 3x
                    200:   "/res/drawable-xhdpi/",  // 2x
                    150:   "/res/drawable-hdpi/",   // 1.5x
                    100:   "/res/drawable-mdpi/"    // 1x
                ]
                let scales = (scale == .down) ? androidScales : androidScalesUp
                for (key, value) in Array(scales).sorted(by: {$0.0 < $1.0}) {
                    let folderPath = destPath + value
                    let imageFile = folderPath + fileName + ".png"
                    if let image = baseImage?.scale(key) {
                        if (Utils.createFolders([folderPath])) {
                            Utils.debug("Image scale and copy \(filePath) -> \(imageFile)")
                            if (saveImage(image, file: imageFile) == false) {
                                exit(-1)
                            }
                        }
                    }
                    else {
                        Utils.error("Error: Failed to scale \(imageFile)")
                        exit(-1)
                    }
                }
            }
            else {
                Utils.error("Error: wrong type")
                exit(-1)
            }
        }
    }
    
    // this table to used to place images marked with either @2, @3 into their respective android equals
    let iOStoAndroid = [
        1: "mdpi",
        2: "xhdpi",
        3: "xxhdpi"
    ]

    
    func imageResourcePath(_ file: String, type: LangType, useRoot: Bool) -> (sourceFile: String,
                                                                                    destFile: String,
                                                                                    destPath: String)
    {
        let filePath = sourceAssetFolder! + "/" + file
        var destFile:String
        if (useRoot) {
            destFile = outputAssetFolder! + "/" + file.lastPathComponent()
        }
        else {
            destFile = outputAssetFolder! + "/" + file  // can include file/does/include/path
        }
        var destPath = (destFile as NSString).deletingLastPathComponent
        
        var fileName = file.lastPathComponent()
        let fileExt = file.fileExtention()
        fileName = (fileName as NSString).deletingPathExtension
        
        if (type == .swift) {
            // do nothing
        }
        else if (type == .java) {
            let result = NSImage.getScaleFrom(fileName)
            var drawable = iOStoAndroid[result.scale]!
            // if our image is a jpg, just place it into the xxhdpi folder
            if ((fileExt.contains("jpg")) && (result.scale == 1)) {
                drawable = "xxhdpi"
            }
            destPath = destPath + "/res/drawable-" + drawable + "/"
            destFile = destPath + result.file + ".\(fileExt)"
        }
        else {
            Utils.error("Error: Wrong type")
            exit(-1)
        }
        return (sourceFile: filePath, destFile: destFile, destPath: destPath)
    }
    
    func copyImage(_ file: String, type: LangType, useRoot: Bool) -> Void
    {
        if (type == .java) {
            if (file.isAndroidCompatible() == false) {
                Utils.error("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                exit(-1)
            }
        }
        let roots = imageResourcePath(file, type: type, useRoot: useRoot)
        Utils.createFolder(roots.destPath)
        if ((globalTint == nil) && (globalIosTint == nil) && (globalAndroidTint == nil)) {
            // just copy the image file raw, no tinting
            if (Utils.copyFile(roots.sourceFile, dest: roots.destFile) == false) {
                exit(-1)
            }
        }
        else {
            let image = NSImage.loadFrom(roots.sourceFile)
            if (image != nil) {
                saveImage(image!, file: roots.destFile)
            }
            else {
                Utils.error("Error: Can't find source image \(roots.sourceFile)")
                exit(-1)
            }
        }
    }

    func copyImages(_ files: [String], type: LangType, useRoot: Bool) -> Void {
        for file in files {
            copyImage(file, type: type, useRoot: useRoot)
        }
    }
    
    let iOSAppIconSizes = [
        "Icon-Small.png": 29,
        "Icon-Small@2x.png": 58,
        "Icon-Small@3x.png": 87,
        "Icon-Small-40.png": 40,
        "Icon-Small-40@2x.png": 80,
        "Icon-Small-40@3x.png": 120,
        "Icon-Small-50.png": 50,
        "Icon-Small-50@2x.png": 100,
        "Icon.png": 57,
        "Icon@2x.png": 114,
        "Icon-40.png": 40,
        "Icon-40@3x.png": 120,
        "Icon-60.png": 60,
        "Icon-60@2x.png": 120,
        "Icon-60@3x.png": 180,
        "Icon-72.png": 72,
        "Icon-72@2x.png": 144,
        "Icon-76.png": 76,
        "Icon-76@2x.png": 152,
        "Icon-80.png": 80,
        "Icon-80@2x.png": 160,
        "Icon-120.png": 120,
        "Icon-167.png": 167,
        "Icon-83.5@2x.png": 167
    ]
    let AndroidIconSizes = [
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192
    ]

    // http://iconhandbook.co.uk/reference/chart/android/
    // https://developer.apple.com/library/ios/qa/qa1686/_index.html
    func copyAppIcon(_ file: String, type: LangType) -> Void {
        if (type == .java) {
            if (file.isAndroidCompatible() == false) {
                Utils.error("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                exit(-1)
            }
        }
        let filePath = sourceAssetFolder! + "/" + file
        let iconImage = NSImage.loadFrom(filePath)
        if (iconImage == nil) {
            Utils.error("Error: missing file \(filePath)")
            exit(-1)
        }
        if (type == .swift) {
            let destPath = outputAssetFolder! + "/icons"
            Utils.createFolder(destPath)
            for (key, value) in iOSAppIconSizes {
                let width = CGFloat(value)
                let height = CGFloat(value)
                if let newImage = iconImage?.resize(width, height: height) {
                    let destFile = destPath + "/" + key
                    saveImage(newImage, file: destFile)
                    Utils.debug("Image scale icon and copy \(filePath) -> \(destFile)")
                }
                else {
                    Utils.error("Error: Failed to resize \(filePath)")
                    exit(-1)
                }
            }
        }
        else if (type == .java) {
            for (key, value) in AndroidIconSizes {
                let width = CGFloat(value)
                let height = CGFloat(value)
                if let newImage = iconImage?.resize(width, height: height) {
                    let destPath = outputAssetFolder! + "/res/drawable-" + key
                    Utils.createFolder(destPath)
                    let destFile = destPath + "/" + appIconName
                    saveImage(newImage, file: destFile)
                    Utils.debug("Image scale icon and copy \(filePath) -> \(destFile)")
                }
                else {
                    Utils.error("Error: Failed to resize \(filePath)")
                    exit(-1)
                }
            }
        }
        else {
            Utils.error("Error: wrong type")
            exit(-1)
        }
    }
    
    /**
     * Covert a string that has parameters, like %1$s, %1$d, %1$@, to be correct per platform.
     * ie $@ is converted to $s on android, and left along for iOS, and $s is converted to
     * @ on iOS
     */
    func updateStringParameters(_ string:String, type: LangType) -> String
    {
        var newString = string
        if (type == .swift) {
            if (string.contains("$s")) {
                newString = string.replacingOccurrences(of: "$s", with: "$@")
            }
        }
        else if (type == .java) {
            if (string.contains("$@")) {
                newString = string.replacingOccurrences(of: "$@", with: "$s")
            }
        }
        else {
            Utils.error("Error: incorrect type")
            exit(-1)
        }
        return newString
    }
    
    func writeLocale(_ localePath:String, properties:Dictionary<String, String>, type: LangType) -> Void
    {
        var genString = ""
        if (type == .swift) {
            genString.append("/* Generated with Sango, by Afero.io */\n")
        }
        else if (type == .java) {
            genString.append("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
            genString.append("<!-- Generated with Sango, by Afero.io -->\n")
            genString.append("<resources>\n")
        }
        for (key, value) in Array(properties).sorted(by: {$0.0 < $1.0}) {
            var newString = updateStringParameters(value, type: type)
            newString = newString.replacingOccurrences(of: "\n", with: "\\n");
            
            if (type == .swift) {
                newString = newString.escapeStr()
                let newKey = key.escapeStr()
                genString.append("\"" + newKey + "\" = \"" + newString + "\";\n")
            }
            else if (type == .java) {
                newString = newString.escapingForAndroid();
                let newKey = key.escapingForAndroid()
                genString.append("\t<string name=\"" + newKey! + "\">" + newString + "</string>\n")
            }
        }
        Utils.debug("Generate locale \(localePath)")
        if (type == .swift) {
        }
        else if (type == .java) {
            genString.append("</resources>\n")
        }
        saveString(genString, file: localePath)
    }
    
    /*
     Given a current locale dictionary in the form of:
     "locale" : {
         "en" : ["file1/path1, "file1/path2"]
         "de" : ["file2/path1, "file2/path2"]
     }
     
     and a new dictioanry in the form of:
     {
         "en" : "file/path1"
         "de" : "file/path2"
     }
     
     merge and return:
     "locale" : {
         "en" : ["file1/path1, "file1/path2"]
         "de" : ["file2/path1, "file2/path2"]
     }
     */
    func mergeLocales(_ src: Dictionary<String, Any>, newInput : Dictionary<String, Any>) -> Dictionary<String, Any> {
        var mergedLocales = src
        
        for (key, value) in newInput {
            var list = mergedLocales[key] as? [String]
            if (list != nil) {
                list?.append(value as! String)
                mergedLocales[key] = list as Any?
            }
            else {
                mergedLocales[key] = [value]
            }
        }
        
        return mergedLocales
    }
    
    /*
     Expecting locales to be in the form of:
     {
        "en" : ["file1/path1, "file1/path2"]
        "de" : ["file2/path1, "file2/path2"]
     }
     */
    func copyLocales(_ locales: Dictionary <String, Any>, type: LangType) -> Void
    {
        // for iOS, path name is:
        // Resources/en.lproj/Localizable.strings
        // for Android, path name is:
        // res/values/strings.xml
        // res/values-fr/strings.xml
        for (lang, fileList) in locales {
            var prop:[String:Any] = [:]
            for file in fileList as! [String] {
                let filePath = sourceAssetFolder! + "/" + file
                let newProps = NSDictionary.init(contentsOfFile: filePath) as? [String:Any]
                if (newProps != nil) {
                    prop = prop + newProps!
                }
                else {
                    Utils.error("Error: Can't find \(file)")
                    exit(-1)
                }
            }
            if (prop.count > 0) {
                var destPath = outputAssetFolder!
                let fileName:String
                if (type == .swift) {
                    if (lang.lowercased() == "default") {
                        destPath.append("/Base.lproj")
                    }
                    else {
                        let folderName = lang.replacingOccurrences(of: "-", with: "")
                        destPath.append("/\(folderName).lproj")
                    }
                    fileName = "Localizable.strings"
                }
                else if (type == .java) {
                    if ((lang.lowercased() == "en") || (lang.lowercased() == "en-us") || (lang.lowercased() == "enus") || (lang.lowercased() == "default")) {
                        destPath.append("/res/values")
                    }
                    else {
                        destPath.append("/res/values-\(lang)")
                    }
                    fileName = "strings.xml"
                }
                else {
                    Utils.error("Error: wrong type")
                    exit(-1)
                }
                Utils.createFolder(destPath)
                destPath.append("/" + fileName)
                writeLocale(destPath, properties: prop as! Dictionary<String, String>, type: type)
            }
        }
    }

    enum AssetLocation {
        case root
        case relative
        case custom
    }
    
    func copyAssets(_ files: [String], type: LangType,
                            assetType: AssetType,
                            destLocation: AssetLocation,
                            root: String = "") -> Void {
        let androidAssetLocations = [
            AssetType.font:"/assets/fonts/",
            AssetType.raw:"/assets/",
            AssetType.layout:"/res/layouts/"
        ]
        if ((assetType == .font) && (type == .java)) {
            let defaultLoc = outputAssetFolder! + androidAssetLocations[assetType]!
            Utils.deleteFolder(defaultLoc)
        }
        for file in files {
            let filePath = sourceAssetFolder! + "/" + file
            var destFile:String
            if (destLocation == .root) {
                destFile = outputAssetFolder! + "/" + file.lastPathComponent()
            }
            else if (destLocation == .relative) {
                destFile = outputAssetFolder! + "/" + file  // can include file/does/include/path
            }
            else {
                // Custom
                destFile = outputAssetFolder! + "/" + root + "/" + file.lastPathComponent()
            }
            let destPath = (destFile as NSString).deletingLastPathComponent
            Utils.createFolder(destPath)
            
            let fileName = file.lastPathComponent()
            
            if (type == .swift) {
                if (Utils.copyFile(filePath, dest: destFile) == false) {
                    exit(-1)
                }
            }
            else if (type == .java) {
                let defaultLoc = destPath + androidAssetLocations[assetType]!
                Utils.createFolder(defaultLoc)
                if (Utils.copyFile(filePath, dest: defaultLoc + fileName) == false) {
                    exit(-1)
                }
            }
            else {
                Utils.error("Error: wrong type")
                exit(-1)
            }
        }
    }

    func validate(_ files:[String], type: LangType) -> Void
    {
        for file in files {
            Utils.debug("Validating \(file)")
            let data = Utils.fromJSONFile(file)
            if (data != nil) {
                for (key, value) in data! {
                    var testFile = false
                    var testArray = false
                    var testAndroid = true
                    var testingArray = value
                    if (key == keyCopied) {
                        testArray = true
                        testAndroid = false
                    }
                    else if (key == keyAppIcon) {
                        testFile = true
                    }
                    else if (key == keyAndroidAppIcon) {
                        testFile = true
                    }
                    else if (key == keyIOSAppIcon) {
                        testFile = true
                        testAndroid = false
                    }
                    else if (key == keyFonts) {
                        testArray = true
                        testAndroid = false
                    }
                    else if (key == keyImages) {
                        testArray = true
                    }
                    else if ((key == keyImagesScaled) || (key == keyImagesScaledIos) || (key == keyImagesScaledAndroid)) {
                        testArray = true
                    }
                    else if ((key == keyImagesScaledUp) || (key == keyImagesScaledIosUp) || (key == keyImagesScaledAndroidUp)) {
                        testArray = true
                    }
                    else if (key == keyImagesIos) {
                        testArray = true
                    }
                    else if (key == keyImagesAndroid) {
                        testArray = true
                    }
                    else if (key == keyAndroidLayout) {
                        testArray = true
                    }
                    else if (key == keyLocale) {
                        let langList = value as! [String:String]
                        var list:[String] = []
                        for (_, file) in langList {
                            list.append(file)
                        }
                        testArray = true
                        testingArray = list
                        testAndroid = false
                    }
                    
                    if (testFile) {
                        let file = value as! String
                        if ((type == .java) && (testAndroid == true)) {
                            if (file.isAndroidCompatible() == false) {
                                Utils.error("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                                exit(-1)
                            }
                        }
                        let filePath = sourceAssetFolder! + "/" + file
                        if (FileManager.default.fileExists(atPath: filePath) == false) {
                            Utils.error("Error: missing file \(filePath)")
                            exit(-1)
                        }
                        else {
                            Utils.debug("Found \(filePath)")
                        }
                    }
                    if (testArray) {
                        let list = testingArray as! [String]
                        for file in list {
                            if ((type == .java) && (testAndroid == true)) {
                                if (file.isAndroidCompatible() == false) {
                                    Utils.error("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                                    exit(-1)
                                }
                            }
                            let filePath = sourceAssetFolder! + "/" + file
                            if (FileManager.default.fileExists(atPath: filePath) == false) {
                                Utils.error("Error: missing file \(filePath)")
                                exit(-1)
                            }
                            else {
                                Utils.debug("Found \(filePath)")
                            }
                        }
                    }
                }
            }
            else {
                exit(-1)
            }
        }
    }
    
    func insertTabPerLine(_ text: String) -> String {
        var output = ""
        let lines = text.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if (line.characters.count > 0) {
                output.append("\n\t")
            }
            output.append(line)
        }
        return output
    }
    
    func consume(_ data: Dictionary <String, Any>, type: LangType, langOutputFile: String) -> Void
    {
        Utils.createFolderForFile(langOutputFile)

        // process first pass keys
        for (key, value) in data {
            if (key == keySchemaVersion) {
                let version = value as! Int
                if (version != SchemaVersion) {
                    Utils.error("Error: mismatched schema. Got \(version), expected \(SchemaVersion)")
                    exit(-1)
                }
            }
            else if (key == keyJava) {
                let options = value as! Dictionary<String, Any>
                baseClass = options["base"] as! String
                package = options["package"] as! String
                var name = options["launcher_icon_name"] as? String
                if (name != nil) {
                    if (name!.hasSuffix(".png") == false) {
                        name!.append(".png")
                    }
                    appIconName = name!
                }
            }
            else if (key == keySwift) {
                let options = value as! Dictionary<String, Any>
                baseClass = options["base"] as! String
            }
            else if (key == keyGlobalTint) {
                let color = parseColor(value as! String)
                globalTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
            }
            else if (key == keyGlobalIosTint) {
                if (type == .swift) {
                    let color = parseColor(value as! String)
                    globalIosTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
                }
            }
            else if (key == keyGlobalAndroidTint) {
                if (type == .java) {
                    let color = parseColor(value as! String)
                    globalAndroidTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
                }
            }
            else if (key == keyEnums) {
                if let enums = value as? [String:Any] {
                    enumsFound = enumsFound + enums     // merge
                }
            }
        }
        
        // everything else is converted to Java, Swift classes
        var genString = ""
        for (key, value) in Array(data).sorted(by: {$0.0 < $1.0}) {
            if (firstPassIgnoredKeys.contains(key) == false) {
                let line = writeConstants(key, value:value, type: type)
                genString.append(line)
            }
        }
        var fontRoot = ""
        for (key, value) in data {
            if (key == keyFontRoot) {
                fontRoot = value as! String
            }
        }
        var completeOutput = true
        for (key, value) in data {
            if (key == keyLocale) {
                copyLocales(value as! Dictionary, type: type)
            }
            if (self.localeOnly == false) {
                if (key == keyCopied) {
                    copyAssets(value as! Array, type: type, assetType: .raw, destLocation: .relative)
                }
                else if (key == keyAppIcon) {
                    copyAppIcon(value as! String, type: type)
                }
                else if (key == keyAndroidAppIcon) {
                    if (type == .java) {
                        copyAppIcon(value as! String, type: type)
                    }
                }
                else if (key == keyIOSAppIcon) {
                    if (type == .swift) {
                        copyAppIcon(value as! String, type: type)
                    }
                }
                else if (key == keyFonts) {
                    copyAssets(value as! Array, type: type, assetType: .font, destLocation: .custom, root: fontRoot)
                }
                else if (key == keyImages) {
                    copyImages(value as! Array, type: type, useRoot: true)
                }
                else if (key == keyImagesScaled) {
                    scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .down)
                }
                else if (key == keyImagesScaledIos) {
                    if (type == .swift) {
                        scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .down)
                    }
                }
                else if (key == keyImagesScaledAndroid) {
                    if (type == .java) {
                        scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .down)
                    }
                }
                else if (key == keyImagesScaledUp) {
                    scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .up)
                }
                else if (key == keyImagesScaledIosUp) {
                    if (type == .swift) {
                        scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .up)
                    }
                }
                else if (key == keyImagesScaledAndroidUp) {
                    if (type == .java) {
                        scaleAndCopyImages(value as! Array, type: type, useRoot: true, scale: .up)
                    }
                }
                else if (key == keyImagesIos) {
                    if (type == .swift) {
                        copyImages(value as! Array, type: type, useRoot: true)
                    }
                }
                else if (key == keyImagesAndroid) {
                    if (type == .java) {
                        copyImages(value as! Array, type: type, useRoot: true)
                    }
                }
                else if (key == keyAndroidLayout) {
                    if (type == .java) {
                        copyAssets(value as! Array, type: type, assetType: .layout, destLocation: .root)
                    }
                }
            }
            else {
                completeOutput = false
            }
        }
        
        if (completeOutput) {
            if (enumsFound.isEmpty == false) {
                let line = writeEnums(enumsFound, type: type)
                genString.append(line)
            }
            if (genString.isEmpty == false) {
                var outputStr = "/* Generated with Sango, by Afero.io */\n\n"
                if (type == .swift) {
                    outputStr.append("import UIKit\n")
                }
                else if (type == .java) {
                    if (package.isEmpty) {
                        outputStr.append("package java.lang;\n")
                    }
                    else {
                        outputStr.append("package \(package);\n")
                    }
                }
                if (baseClass.isEmpty == false) {
                    genString = insertTabPerLine(genString)
                    if (type == .swift) {
                        outputStr.append("public struct \(baseClass) {")
                    }
                    else if (type == .java) {
                        outputStr.append("public final class \(baseClass) {")
                    }
                    genString.append("\n}")
                }
                outputStr.append(genString + "\n")
                _ = saveString(outputStr, file: langOutputFile)
            }
            writeSangoExtras(type, filePath: langOutputFile.pathOnlyComponent())
            if (type == .java) {
                writeAndroidColors()
            }
        }
    }
    
    func prepareGitRepro(_ folder:String, tag:String?) -> Void {
        let currentBranch = Shell.gitCurrentBranch(folder)
        if (tag != nil) {
            if (tag!.contains(assetTagIgnore)) {
                return
            }
            else if (tag!.lowercased().contains(assetTagHead)) {
                if (Shell.gitResetHead(folder, branch: currentBranch) == false) {
                    Utils.error("Error: Can't reset asset repo to HEAD")
                    exit(-1)
                }
            }
            else {
                if (Shell.gitCheckoutAtTag(folder, tag: tag!) == false) {
                    Utils.error("Error: Can't set asset repo to \(tag) tag")
                    exit(-1)
                }
            }
        }
    }
    
    let baseAssetTemplate = [keySchemaVersion :SchemaVersion,
                                    keyFonts: [],
                                    keyLocale: ["enUS":""],
                                    keyImages: [],
                                    keyImagesScaled: [],
                                    keyImagesIos: [],
                                    keyImagesAndroid: [],
                                    keyCopied: [],
                                    keyAppIcon: "",
                                    keyIOSAppIcon: "",
                                    keyAndroidAppIcon: ""
                                ] as [String : Any]

    func createAssetTemplate(_ base: String) -> Void {
        var temp = baseAssetTemplate as Dictionary<String,Any>
        temp[keyJava] = ["package" : "one.two", "base": base]
        temp[keySwift] = ["base": base]
        temp["Example"] = ["EXAMPLE_CONSTANT": 1]
        let jsonString = Utils.toJSON(temp)
        let outputFile = base + ".json"
        if (jsonString != nil) {
            if (saveString(jsonString!, file: outputFile)) {
                Utils.debug("JSON template created at \"\(outputFile)\"")
            }
        }
    }
    
    let baseConfigTemplate = ["inputs": ["example/base.json","example/brand_1.json"],
                                     "input_assets": "../path/to/depot",
                                     "out_source": "path/to/app/source",
                                     "out_assets": "path/to/app/resources",
                                     "type": "swift or java"
    ] as [String : Any]
    func createConfigTemplate(_ file: String) -> Void {
        let jsonString = Utils.toJSON(baseConfigTemplate)
        if (jsonString != nil) {
            if (saveString(jsonString!, file: file)) {
                Utils.debug("JSON template created at \"\(file)\"")
            }
        }
    }
    
    func start(_ args: [String]) -> Void {
        if (findOption(args, option: "-h") || args.count == 0) {
            usage()
            exit(0)
        }

        if (findOption(args, option: optHelpKeys)) {
            helpKeys()
            exit(0)
        }
        if (findOption(args, option: optVersion)) {
            print(App.copyrightNotice)
            exit(0)
        }

        gitEnabled = Shell.gitInstalled()
        
        Utils.debug(App.copyrightNotice)

        let baseName = getOption(args, option: optAssetTemplates)
        if (baseName != nil) {
            createAssetTemplate(baseName!)
            exit(0)
        }

        let configTemplateFile = getOption(args, option: optConfigTemplate)
        if (configTemplateFile != nil) {
            createConfigTemplate(configTemplateFile!)
            exit(0)
        }
        
        self.localeOnly = findOption(args, option: optLocaleOnly)
        self.swift3Output = findOption(args, option: optSwift3)
        self.swift3Output = true
        var validateInputs:[String]? = nil
        var validateLang:LangType = .unset
        validateInputs = getOptions(args, option: optValidate)
        if (validateInputs == nil) {
            validateInputs = getOptions(args, option: "-validate_ios")
            validateLang = .swift
        }
        if (validateInputs == nil) {
            validateInputs = getOptions(args, option: "-validate_android")
            validateLang = .java
        }
        if (validateInputs != nil) {
            sourceAssetFolder = getOption(args, option: optInputAssets)
            if (sourceAssetFolder != nil) {
                sourceAssetFolder = NSString(string: sourceAssetFolder!).expandingTildeInPath

                if (validateLang == .unset) {
                    validate(validateInputs!, type: .swift)
                    validate(validateInputs!, type: .java)
                }
                else {
                    validate(validateInputs!, type: validateLang)
                }
            }
            else {
                Utils.error("Error: missing source asset folder")
                exit(-1)
            }
            exit(0)
        }
        
        let configFile = getOption(args, option: optConfig)
        if (configFile != nil) {
            let result = Utils.fromJSONFile(configFile!)
            if (result != nil) {
                inputFile = result!["input"] as? String
                inputFiles = result!["inputs"] as? [String]
                sourceAssetFolder = result!["input_assets"] as? String
                outputClassFile = result!["out_source"] as? String
                outputAssetFolder = result!["out_assets"] as? String
                assetTag = result!["input_assets_tag"] as? String
                let type = result!["type"] as? String
                if (type == "java") {
                    compileType = .java
                }
                else if (type == "swift") {
                    compileType = .swift
                }
            }
            else {
                exit(-1)
            }
        }
        
        if (compileType == .unset) {
            if (findOption(args, option: optJava)) {
                compileType = .java
            }
            else if (findOption(args, option: optSwift)) {
                compileType = .swift
            }
            else {
                Utils.error("Error: need either -swift or -java")
                exit(-1)
            }
        }

        if (assetTag == nil) {
            assetTag = getOption(args, option: optInputAssetsTag)
        }

        if (outputClassFile == nil) {
            outputClassFile = getOption(args, option: optOutSource)
        }
        if (outputClassFile != nil) {
            outputClassFile = NSString(string: outputClassFile!).expandingTildeInPath
        }
        else {
            Utils.error("Error: missing output file")
            exit(-1)
        }

        let overrideSourceAssets = getOption(args, option: optInputAssets)
        if (overrideSourceAssets != nil) {
            sourceAssetFolder = overrideSourceAssets
        }
        if (sourceAssetFolder != nil) {
            sourceAssetFolder = NSString(string: sourceAssetFolder!).expandingTildeInPath
        }
        else {
            Utils.error("Error: missing source asset folder")
            exit(-1)
        }
        
        if (outputAssetFolder == nil) {
            outputAssetFolder = getOption(args, option: optOutAssets)
        }
        if (outputAssetFolder != nil) {
            outputAssetFolder = NSString(string: outputAssetFolder!).expandingTildeInPath
        }
        else {
            Utils.error("Error: missing output asset folder")
            exit(-1)
        }

        var locales:[String:Any] = [:]
        var result:[String:Any]? = nil
        if (inputFiles == nil) {
            inputFiles = getOptions(args, option: optInputs)
        }
        if (inputFiles != nil) {
            result = [:]
            for file in inputFiles! {
                let filePath = sourceAssetFolder! + "/" + file
                if var d = Utils.fromJSONFile(filePath) {
                    let locale: [String: String]? = d[keyLocale] as? [String:String]
                    if (locale != nil) {
                        d.removeValue(forKey: keyLocale)
                        locales = mergeLocales(locales, newInput:locale! as Dictionary<String, Any>)
                    }
                    result = result! + d
                }
                else {
                    exit(-1)
                }
            }
        }

        if (locales.count > 0) {
            result![keyLocale] = locales as Any?
        }

        if (inputFile == nil) {
            inputFile = getOption(args, option: optInput)
        }
        if (inputFile != nil) {
            result = Utils.fromJSONFile(inputFile!)
            if (result == nil) {
                exit(-1)
            }
        }

        if (result != nil) {
            if (gitEnabled) && (sourceAssetFolder != nil) {
                prepareGitRepro(sourceAssetFolder!, tag: assetTag!)
            }

            // process
            consume(result!, type: compileType, langOutputFile: outputClassFile!)
        }
        else {
            Utils.error("Error: missing input file")
            exit(-1)
        }
    }
}

