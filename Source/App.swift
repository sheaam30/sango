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

// See:
// https://docs.google.com/document/d/1X-pHtwzB6Qbkh0uuhmqtG98o2_Dv_okDUim6Ohxhd8U/edit
// for more details

private let SchemaVersion = 1

private let keySchemaVersion = "schemaVersion"
private let keyFonts = "fonts"
private let keyImages = "images"
private let keyLocale = "locale"
private let keyImagesScaled = "imagesScaled"
private let keyImagesScaledIos = "imagesScaledIos"
private let keyImagesScaledAndroid = "imagesScaledAndroid"
private let keyImagesIos = "imagesIos"
private let keyImagesAndroid = "imagesAndroid"
private let keyImagesTinted = "imagesTinted"
private let keyGlobalTint = "globalTint"
private let keyGlobalIosTint = "globalTintIos"
private let keyGlobalAndroidTint = "globalTintAndroid"
private let keyCopied = "copied"
private let keyCopiedIos = "copiedIos"
private let keyCopiedAndroid = "copiedAndroid"
private let keyAppIcon = "appIcon"
private let keyIOSAppIcon = "appIconIos"
private let keyAndroidAppIcon = "appIconAndroid"
private let keyAndroidLayout = "layoutAndroid"
private let keyJava = "java"
private let keySwift = "swift"
private let firstPassIgnoredKeys = [keyCopied, keyIOSAppIcon, keyAndroidAppIcon, keyAppIcon,
                                    keyFonts, keySchemaVersion, keyAndroidLayout,
                                    keyImagesScaled, keyImagesScaledIos, keyImagesScaledAndroid,
                                    keyImages, keyImagesIos, keyImagesAndroid, keyLocale,
                                    keyImagesTinted, keyJava, keySwift, keyGlobalTint,
                                    keyGlobalIosTint, keyGlobalAndroidTint]

private enum LangType {
    case Unset
    case Java
    case Swift
}

private enum AssetType {
    case Font
    case Layout
    case Image
    case Raw
}

class App
{
    private var package:String = ""
    private var baseClass:String = ""
    private var appIconName:String = "ic_launcher.png"
    private var sourceAssetFolder:String? = nil
    private var outputAssetFolder:String? = nil

    private var inputFile:String? = nil
    private var inputFiles:[String]? = nil
    private var outputClassFile:String? = nil
    private var assetTag:String? = nil

    private var compileType:LangType = .Unset

    private var globalTint:NSColor? = nil
    private var globalIosTint:NSColor? = nil
    private var globalAndroidTint:NSColor? = nil
    private let copyrightNotice = "Sango © 2016 Afero, Inc - Build \(BUILD_REVISION) \(BUILD_DATE)"

    private var gitEnabled = false

    func usage() -> Void {
        print(copyrightNotice)
        print("Usage:")
        print(" -asset_template [basename]          creates a json template, specifically for the assets")
        print(" -config_template [file.json]        creates a json template, specifically for the app")
        print(" -config [file.json]                 use config file for options, instead of command line")
        print(" -validate [asset_file.json, ...]    validates asset JSON file(s), requires -input_assets")
        print(" -input [file.json]                  asset json file")
        print(" -inputs [file1.json file2.json ...] merges asset files and process")
        print(" -input_assets [folder]              asset source folder (read)")
        print(" -out_source [source.java|swift]     path to result of language")
        print(" -java                               write java source")
        print(" -swift                              write swift source")
        print(" -out_assets [folder]                asset root folder (write), typically iOS Resource, or Android app/src/main")
        print(" -input_assets_tag [tag]             optional git tag to pull repro at before processing")
        print(" -verbose                            be verbose in details")
        print(" -help_keys                          display JSON keys and their use")
        print(" -version                            version")
    }

    private func helpKeys() -> Void {
        let details = [keySchemaVersion: "number. Version, which should be \(SchemaVersion)",
                       keyFonts: "array. path to font files",
                       keyImages: "array. path to image files that are common.",
                       keyLocale: "dictionary. keys are IOS lang. ie, enUS, enES, path to strings file",
                       keyImagesIos: "array. path to image files that are iOS only",
                       keyImagesAndroid: "array. path to image files that are Android only",
                       keyImagesScaled: "array. path to image files that are common and will be scaled",
                       keyImagesScaledIos: "array. path to image files that are iOS only and will be scaled",
                       keyImagesScaledAndroid: "array. path to image files that are Android only and will be scaled",
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
        for (key, value) in Array(details).sort({$0.0 < $1.0}) {
            let keyPad = key.stringByPaddingToLength(keyLength + 3, withString: " ", startingAtIndex: 0)
            print(keyPad + value)
        }
    }
    
    // Save image, tinted
    func saveImage(image: NSImage, file: String) -> Bool {
        var tint:NSColor? = globalTint
        
        if ((compileType == .Java) && (globalAndroidTint != nil)) {
            tint = globalAndroidTint
        }
        else if ((compileType == .Swift) && (globalIosTint != nil)) {
            tint = globalIosTint
        }
        
        if (tint != nil) {
            let tintedImage = image.tint(globalTint!)
            return tintedImage.saveTo(file)
        }
        else {
            return image.saveTo(file)
        }
    }
    
    func saveString(data:String, file: String) -> Bool
    {
        do {
            try data.writeToFile(file, atomically: true, encoding: NSUTF8StringEncoding)
        }
        catch {
            print("Error: writing to \(file)")
            exit(-1)
        }
        return true
    }
    
    private func writeImageStringArray(stringArray: Dictionary<String, AnyObject>, type: LangType) -> String {
        var outputString = "\n"
        if (type == .Swift) {
            // public static let UiSecondaryColorTinted = ["account_avatar1", "account_avatar2"]
            for (key, value) in stringArray {
                outputString.appendContentsOf("\tpublic static let \(key) = [\"")
                let strValue = String(value)
                outputString.appendContentsOf(strValue + "\"]\n")
            }
        }
        else if (type == .Java) {
            // public static final String[] UI_SECONDARY_COLOR_TINTED = {"account_avatar1", "account_avatar2"};
            for (key, value) in stringArray {
                outputString.appendContentsOf("\tpublic static final String[] \(key) = {\"")
                let strValue = String(value)
                outputString.appendContentsOf(strValue + "\"};\n")
            }
        }
        else {
            print("Error: invalide output type")
            exit(-1)
        }
        return outputString
    }

    private func parseColor(color: String) -> (r:Double, g:Double, b:Double, a:Double, s:Int, rgb:UInt32)? {
        var red:Double = 0
        var green:Double = 0
        var blue:Double = 0
        var alpha:Double = 1
        var rgbValue:UInt32 = 0
        var isColor = false
        var size = 0

        let parts = color.componentsSeparatedByString(",")
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
        }
        else if (color.hasPrefix("#")) {
            var hexStr = color.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet() as NSCharacterSet).uppercaseString
            hexStr = hexStr.substringFromIndex(hexStr.startIndex.advancedBy(1))
            
            NSScanner(string: hexStr).scanHexInt(&rgbValue)
            red = 1
            green = 1
            blue = 1
            alpha = 1
            
            if (hexStr.characters.count < 6) {
                print("Error: not enough characters for hex color definition. Needs 6.")
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
        }
        if (isColor) {
            return (r: red, g: green, b: blue, a: alpha, s: size, rgb:rgbValue)
        }
        return nil
    }
    
    private func writeConstants(name: String, constants: Dictionary<String, AnyObject>, type: LangType) -> String {
        var outputString = "\n"
        if (type == .Swift) {
            outputString.appendContentsOf("public struct ")
            outputString.appendContentsOf(name + " {\n")
            for (key, value) in constants {
                let line = "\tstatic let " + key.snakeCaseToCamelCase() + " = "
                outputString.appendContentsOf(line)

                var useQuotes = false
                let strValue = String(value)
                if (value is String) {
                    useQuotes = true
                    if (strValue.isNumber() == true) {
                        useQuotes = false
                    }
                    else {
                        let color = parseColor(strValue)
                        if (color != nil) {
                            let line = "UIColor(red: \(color!.r.roundTo3f), green: \(color!.g.roundTo3f), blue: \(color!.b.roundTo3f), alpha: \(color!.a.roundTo3f))"
                            outputString.appendContentsOf(line + "\t// ")
                            useQuotes = false
                        }
                    }
                }
                if (useQuotes) {
                    let line = "\"" + String(value) + "\""
                    outputString.appendContentsOf(line);
                }
                else {
                    let line = String(value)
                    outputString.appendContentsOf(line);
                }
                outputString.appendContentsOf("\n")
            }
            outputString.appendContentsOf("}")
        }
        else if (type == .Java) {
            outputString.appendContentsOf("public final class ")
            outputString.appendContentsOf(name + " {\n")

            for (key, value) in constants {
                var type = "int"
                var endQuote = ";"
                var parmSize = ""
                var useQuotes = false
                var strValue = String(value)
                if (value is String) {
                    useQuotes = true
                    if (strValue.isNumber() == true) {
                        useQuotes = false
                    }
                    else {
                        type = "String"

                        let color = parseColor(strValue)
                        if (color != nil) {
                            type = "int"
                            if (color?.s == 4) {
                                parmSize = "L"
                                type = "long"
                            }
                            let line = String(color!.rgb)
                            strValue = String(line + parmSize + ";\t// \(value)")
                            useQuotes = false
                            endQuote = ""
                        }
                    }
                }

                let line = "\tpublic static final " + type + " " + key + " = "
                outputString.appendContentsOf(line)
                if (useQuotes) {
                    let line = "\"" + strValue + "\"" + endQuote
                    outputString.appendContentsOf(line);
                }
                else {
                    let line = strValue + endQuote
                    outputString.appendContentsOf(line);
                }
                outputString.appendContentsOf("\n")
            }
            outputString.appendContentsOf("}")
        }
        else {
            print("Error: invalide output type")
            exit(-1)
        }
        return outputString
    }

    // http://petrnohejl.github.io/Android-Cheatsheet-For-Graphic-Designers/
    
    private func scaleAndCopyImages(files: [String], type: LangType, useRoot: Bool) -> Void {
        for file in files {
            if (type == .Java) {
                if (file.isAndroidCompatible() == false) {
                    print("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
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
            let destPath = (destFile as NSString).stringByDeletingLastPathComponent
            createFolder(destPath)

            var fileName = file.lastPathComponent()
            fileName = (fileName as NSString).stringByDeletingPathExtension
            fileName = fileName.stringByReplacingOccurrencesOfString("@2x", withString: "")
            fileName = fileName.stringByReplacingOccurrencesOfString("@3x", withString: "")

            if (type == .Swift) {
                // Ok, we're going to create the @3, @2, and normal size from the given assumed largest image
                let image3 = NSImage.loadFrom(filePath) // @3
                if (image3 == nil) {
                    print("Error: missing file \(filePath)")
                    exit(-1)
                }
                let image2 = image3.scale(66.67)        // @2
                let image = image3.scale(33.34)         // @1
                var file = destPath + "/" + fileName + "@3x.png"
                if (saveImage(image3, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
                file = destPath + "/" + fileName + "@2x.png"
                if (saveImage(image2, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
                file = destPath + "/" + fileName + ".png"
                if (saveImage(image, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
            }
            else if (type == .Java) {
                let image4 = NSImage.loadFrom(filePath) // 3x
                if (image4 == nil) {
                    print("Error: missing file \(filePath)")
                    exit(-1)
                }
                let image3 = image4.scale(66.67)        // 2x
                let image2 = image4.scale(50)           // 1.5x
                let image = image4.scale(33.34)         // 1x
                let mdpi = destPath + "/res/drawable-mdpi/"
                let hdpi = destPath + "/res/drawable-hdpi/"
                let xhdpi = destPath + "/res/drawable-xhdpi/"
                let xxhdpi = destPath + "/res/drawable-xxhdpi/"
                createFolders([mdpi, hdpi, xhdpi, xxhdpi])
                fileName = fileName + ".png"
                var file = xxhdpi + fileName
                if (saveImage(image4, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
                file = xhdpi + fileName
                if (saveImage(image3, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
                file = hdpi + fileName
                if (saveImage(image2, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
                file = mdpi + fileName
                if (saveImage(image, file: file) == false) {
                    exit(-1)
                }
                Utils.debug("Image scale and copy \(filePath) -> \(file)")
            }
            else {
                print("Error: wrong type")
                exit(-1)
            }
        }
    }
    
    // this table to used to place images marked with either @2, @3 into their respective android equals
    private let iOStoAndroid = [
        1: "mdpi",
        2: "xhdpi",
        3: "xxhdpi"
    ]

    
    private func imageResourcePath(file: String, type: LangType, useRoot: Bool) -> (sourceFile: String,
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
        var destPath = (destFile as NSString).stringByDeletingLastPathComponent
        
        var fileName = file.lastPathComponent()
        fileName = (fileName as NSString).stringByDeletingPathExtension
        
        if (type == .Swift) {
            // do nothing
        }
        else if (type == .Java) {
            let result = NSImage.getScaleFrom(fileName)
            let drawable = iOStoAndroid[result.scale]!
            destPath = destPath + "/res/drawable-" + drawable + "/"
            destFile = destPath + result.file + ".png"
        }
        else {
            print("Error: Wrong type")
            exit(-1)
        }
        return (sourceFile: filePath, destFile: destFile, destPath: destPath)
    }
    
    private func copyImage(file: String, type: LangType, useRoot: Bool) -> Void
    {
        if (type == .Java) {
            if (file.isAndroidCompatible() == false) {
                print("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                exit(-1)
            }
        }
        let roots = imageResourcePath(file, type: type, useRoot: useRoot)
        createFolder(roots.destPath)
        if ((globalTint == nil) && (globalIosTint == nil) && (globalAndroidTint == nil)) {
            copyFile(roots.sourceFile, dest: roots.destFile)
        }
        else {
            let image = NSImage.loadFrom(roots.sourceFile)
            if (image != nil) {
                saveImage(image, file: roots.destFile)
            }
            else {
                print("Error: Can't find source image \(roots.sourceFile)")
                exit(-1)
            }
        }
    }

    private func copyImages(files: [String], type: LangType, useRoot: Bool) -> Void {
        for file in files {
            copyImage(file, type: type, useRoot: useRoot)
        }
    }
    
    private let iOSAppIconSizes = [
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
    private let AndroidIconSizes = [
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192
    ]

    // http://iconhandbook.co.uk/reference/chart/android/
    // https://developer.apple.com/library/ios/qa/qa1686/_index.html
    private func copyAppIcon(file: String, type: LangType) -> Void {
        if (type == .Java) {
            if (file.isAndroidCompatible() == false) {
                print("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                exit(-1)
            }
        }
        let filePath = sourceAssetFolder! + "/" + file
        let iconImage = NSImage.loadFrom(filePath)
        if (iconImage == nil) {
            print("Error: missing file \(iconImage)")
            exit(-1)
        }
        if (type == .Swift) {
            let destPath = outputAssetFolder! + "/icons"
            createFolder(destPath)
            for (key, value) in iOSAppIconSizes {
                let width = CGFloat(value)
                let height = CGFloat(value)
                let newImage = iconImage.resize(width, height: height)
                let destFile = destPath + "/" + key
                saveImage(newImage, file: destFile)
                Utils.debug("Image scale icon and copy \(filePath) -> \(destFile)")
            }
        }
        else if (type == .Java) {
            for (key, value) in AndroidIconSizes {
                let width = CGFloat(value)
                let height = CGFloat(value)
                let newImage = iconImage.resize(width, height: height)
                let destPath = outputAssetFolder! + "/res/drawable-" + key
                createFolder(destPath)
                let destFile = destPath + "/" + appIconName
                saveImage(newImage, file: destFile)
                Utils.debug("Image scale icon and copy \(filePath) -> \(destFile)")
            }
        }
        else {
            print("Error: wrong type")
            exit(-1)
        }
    }
    
    /**
     * Covert a string that has parameters, like %1$s, %1$d, %1$@, to be correct per platform.
     * ie $@ is converted to $s on android, and left along for iOS, and $s is converted to
     * @ on iOS
     */
    private func updateStringParameters(string:String, type: LangType) -> String
    {
        var newString = string
        if (type == .Swift) {
            if (string.containsString("$s")) {
                newString = string.stringByReplacingOccurrencesOfString("$s", withString: "$@")
            }
        }
        else if (type == .Java) {
            if (string.containsString("$@")) {
                newString = string.stringByReplacingOccurrencesOfString("$@", withString: "$s")
            }
        }
        else {
            print("Error: incorrect type")
            exit(-1)
        }
        return newString
    }
    
    private func writeLocale(localePath:String, properties:Dictionary<String, String>, type: LangType) -> Void
    {
        var genString = ""
        if (type == .Swift) {
            genString.appendContentsOf("/* Generated with Sango, by Afero.io */\n")
        }
        else if (type == .Java) {
            genString.appendContentsOf("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
            genString.appendContentsOf("<!-- Generated with Sango, by Afero.io -->\n")
            genString.appendContentsOf("<resources>\n")
        }
        for (key, value) in properties {
            let newString = updateStringParameters(value, type: type)
            if (type == .Swift) {
                genString.appendContentsOf("\"" + key + "\" = \"" + newString + "\";\n")
            }
            else if (type == .Java) {
                genString.appendContentsOf("\t<string name=\"" + key + "\">" + newString.stringByEscapingForHTML() + "</string>\n")
            }
        }
        if (type == .Swift) {
        }
        else if (type == .Java) {
            genString.appendContentsOf("</resources>\n")
        }
        saveString(genString, file: localePath)
    }
    
    private func copyLocales(locales: Dictionary <String, AnyObject>, type: LangType) -> Void
    {
        // for iOS, path name is:
        // Resources/en.lproj/Localizable.strings
        // for Android, oaht name is:
        // res/values/strings.xml
        // res/values-fr/strings.xml
        for (lang, file) in locales {
            let filePath = sourceAssetFolder! + "/" + (file as! String)
            let prop = NSDictionary.init(contentsOfFile: filePath)
            if (prop != nil) {
                var destPath = outputAssetFolder!
                let fileName:String
                if (type == .Swift) {
                    if ((lang.lowercaseString == "en-us") || (lang.lowercaseString == "enus") || (lang.lowercaseString == "default")) {
                        destPath.appendContentsOf("/Base.lproj")
                    }
                    else {
                        let folderName = lang.stringByReplacingOccurrencesOfString("-", withString: "")
                        destPath.appendContentsOf("/\(folderName).lproj")
                    }
                    fileName = "Localizable.strings"
                }
                else if (type == .Java) {
                    if ((lang.lowercaseString == "en-us") || (lang.lowercaseString == "enus") || (lang.lowercaseString == "default")) {
                        destPath.appendContentsOf("/res/values")
                    }
                    else {
                        destPath.appendContentsOf("/res/values-\(lang)")
                    }
                    fileName = "strings.xml"
                }
                else {
                    print("Error: wrong type")
                    exit(-1)
                }
                createFolder(destPath)
                destPath.appendContentsOf("/" + fileName)
                writeLocale(destPath, properties: prop as! Dictionary<String, String>, type: type)
            }
            else {
                print("Error: Can't find \(file)")
                exit(-1)
            }
        }
    }

    private func copyAssets(files: [String], type: LangType, assetType: AssetType, useRoot: Bool) -> Void {
        let androidAssetLocations = [
            AssetType.Font:"/assets/fonts/",
            AssetType.Raw:"/assets/",
            AssetType.Layout:"/res/layouts/"
        ]
        for file in files {
            let filePath = sourceAssetFolder! + "/" + file
            var destFile:String
            if (useRoot) {
                destFile = outputAssetFolder! + "/" + file.lastPathComponent()
            }
            else {
                destFile = outputAssetFolder! + "/" + file  // can include file/does/include/path
            }
            let destPath = (destFile as NSString).stringByDeletingLastPathComponent
            createFolder(destPath)
            
            let fileName = file.lastPathComponent()
            
            if (type == .Swift) {
                copyFile(filePath, dest: destFile)
            }
            else if (type == .Java) {
                let defaultLoc = destPath + androidAssetLocations[assetType]!
                createFolder(defaultLoc)
                copyFile(filePath, dest: defaultLoc + fileName)
            }
            else {
                print("Error: wrong type")
                exit(-1)
            }
        }
    }
    
    private func validate(files:[String], type: LangType) -> Void
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
                    else if (key == keyImagesScaled) {
                        testArray = true
                    }
                    else if (key == keyImagesScaledIos) {
                        testArray = true
                    }
                    else if (key == keyImagesScaledAndroid) {
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
                        if ((type == .Java) && (testAndroid == true)) {
                            if (file.isAndroidCompatible() == false) {
                                print("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                                exit(-1)
                            }
                        }
                        let filePath = sourceAssetFolder! + "/" + file
                        if (NSFileManager.defaultManager().fileExistsAtPath(filePath) == false) {
                            print("Error: missing file \(filePath)")
                            exit(-1)
                        }
                        else {
                            Utils.debug("Found \(filePath)")
                        }
                    }
                    if (testArray) {
                        let list = testingArray as! [String]
                        for file in list {
                            if ((type == .Java) && (testAndroid == true)) {
                                if (file.isAndroidCompatible() == false) {
                                    print("Error: \(file) must contain only lowercase a-z, 0-9, or underscore")
                                    exit(-1)
                                }
                            }
                            let filePath = sourceAssetFolder! + "/" + file
                            if (NSFileManager.defaultManager().fileExistsAtPath(filePath) == false) {
                                print("Error: missing file \(filePath)")
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
    
    private func consume(data: Dictionary <String, AnyObject>, type: LangType, langOutputFile: String) -> Void
    {
        createFolderForFile(langOutputFile)

        // process first pass keys
        for (key, value) in data {
            if (key == keySchemaVersion) {
                let version = value as! Int
                if (version != SchemaVersion) {
                    print("Error: mismatched schema. Got \(version), expected \(SchemaVersion)")
                    exit(-1)
                }
            }
            else if (key == keyJava) {
                let options = value as! Dictionary<String, AnyObject>
                baseClass = options["base"] as! String
                package = options["package"] as! String
                var name = options["launcher_icon_name"] as? String
                if (name != nil) {
                    if (name!.hasSuffix(".png") == false) {
                        name!.appendContentsOf(".png")
                    }
                    appIconName = name!
                }
            }
            else if (key == keySwift) {
                let options = value as! Dictionary<String, AnyObject>
                baseClass = options["base"] as! String
            }
            else if (key == keyGlobalTint) {
                let color = parseColor(value as! String)
                globalTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
            }
            else if (key == keyGlobalIosTint) {
                if (type == .Swift) {
                    let color = parseColor(value as! String)
                    globalIosTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
                }
            }
            else if (key == keyGlobalAndroidTint) {
                if (type == .Java) {
                    let color = parseColor(value as! String)
                    globalAndroidTint = NSColor(calibratedRed: CGFloat(color!.r), green: CGFloat(color!.g), blue: CGFloat(color!.b), alpha: CGFloat(color!.a))
                }
            }
        }
        
        // everything else is converted to Java, Swift classes
        var genString = ""
        for (key, value) in data {
            if (firstPassIgnoredKeys.contains(key) == false) {
                let constants = value as! Dictionary<String, AnyObject>
                let line = writeConstants(key, constants:constants, type: type)
                genString.appendContentsOf(line)
            }
        }
        for (key, value) in data {
            if (key == keyCopied) {
                copyAssets(value as! Array, type: type, assetType: .Raw, useRoot: false)
            }
            else if (key == keyAppIcon) {
                copyAppIcon(value as! String, type: type)
            }
            else if (key == keyAndroidAppIcon) {
                if (type == .Java) {
                    copyAppIcon(value as! String, type: type)
                }
            }
            else if (key == keyIOSAppIcon) {
                if (type == .Swift) {
                    copyAppIcon(value as! String, type: type)
                }
            }
            else if (key == keyFonts) {
                copyAssets(value as! Array, type: type, assetType: .Font, useRoot: true)
            }
            else if (key == keyLocale) {
                copyLocales(value as! Dictionary, type: type)
            }
            else if (key == keyImages) {
                copyImages(value as! Array, type: type, useRoot: true)
            }
            else if (key == keyImagesScaled) {
                scaleAndCopyImages(value as! Array, type: type, useRoot: true)
            }
            else if (key == keyImagesScaledIos) {
                if (type == .Swift) {
                    scaleAndCopyImages(value as! Array, type: type, useRoot: true)
                }
            }
            else if (key == keyImagesScaledAndroid) {
                if (type == .Java) {
                    scaleAndCopyImages(value as! Array, type: type, useRoot: true)
                }
            }
                
            else if (key == keyImagesIos) {
                if (type == .Swift) {
                    copyImages(value as! Array, type: type, useRoot: true)
                }
            }
            else if (key == keyImagesAndroid) {
                if (type == .Java) {
                    copyImages(value as! Array, type: type, useRoot: true)
                }
            }
            else if (key == keyAndroidLayout) {
                if (type == .Java) {
                    copyAssets(value as! Array, type: type, assetType: .Layout, useRoot: true)
                }
            }
        }
        if (genString.isEmpty == false) {
            var outputStr = "/* Generated with Sango, by Afero.io */\n\n"
            if (type == .Swift) {
                outputStr.appendContentsOf("import UIKit\n")
            }
            else if (type == .Java) {
                if (package.isEmpty) {
                    outputStr.appendContentsOf("package java.lang;\n")
                }
                else {
                    outputStr.appendContentsOf("package \(package);\n")
                }
            }
            if (baseClass.isEmpty == false) {
                genString = genString.stringByReplacingOccurrencesOfString("\n", withString: "\n\t")
                if (type == .Swift) {
                    outputStr.appendContentsOf("public struct \(baseClass) {")
                }
                else if (type == .Java) {
                    outputStr.appendContentsOf("public final class \(baseClass) {")
                }
                genString.appendContentsOf("\n}")
            }
            outputStr.appendContentsOf(genString + "\n")
            saveString(outputStr, file: langOutputFile)
        }
    }

    private func createFolders(folders: [String]) -> Bool {
        for file in folders {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(file, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                print("Error: creating folder \(file)")
                exit(-1)
            }
        }
        return true
    }

    private func createFolderForFile(srcFile: String) -> Bool {
        let destPath = (srcFile as NSString).stringByDeletingLastPathComponent
        return createFolder(destPath)
    }

    private func createFolder(src: String) -> Bool {
        var ok = true
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(src, withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            print("Error: creating folder \(src)")
            ok = false
        }
        
        return ok
    }

//    private func copyFiles(files: [String], type: LangType, useRoot: Bool) -> Void {
//        for file in files {
//            let filePath = sourceAssetFolder! + "/" + file
//            var destFile:String
//            if (useRoot) {
//                destFile = outputAssetFolder! + "/" + file.lastPathComponent()
//            }
//            else {
//                destFile = outputAssetFolder! + "/" + file
//            }
//            let destPath = (destFile as NSString).stringByDeletingLastPathComponent
//            createFolder(destPath)
//            if (copyFile(filePath, dest: destFile) == false) {
//                exit(-1)
//            }
//        }
//    }
    
    private func copyFile(src: String, dest: String, restrict: Bool = false) -> Bool {
        deleteFile(dest)
        var ok = true
        do {
            try NSFileManager.defaultManager().copyItemAtPath(src, toPath: dest)
            Utils.debug("Copy \(src) -> \(dest)")
        }
        catch {
            print("Error: copying file \(src) to \(dest)")
            ok = false
        }

        return ok
    }
    
    private func deleteFile(src: String) -> Bool {
        var ok = true
        do {
            try NSFileManager.defaultManager().removeItemAtPath(src)
        }
        catch {
            ok = false
        }
        
        return ok
    }

    private let baseAssetTemplate = [keySchemaVersion :SchemaVersion,
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
                                ]

    private func createAssetTemplate(base: String) -> Void {
        var temp = baseAssetTemplate as! Dictionary<String,AnyObject>
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
    
    private let baseConfigTemplate = ["inputs": ["example/base.json","example/brand_1.json"],
                                     "input_assets": "../path/to/depot",
                                     "out_source": "path/to/app/source",
                                     "out_assets": "path/to/app/resources",
                                     "type": "swift or java"
    ]
    private func createConfigTemplate(file: String) -> Void {
        let jsonString = Utils.toJSON(baseConfigTemplate)
        if (jsonString != nil) {
            if (saveString(jsonString!, file: file)) {
                Utils.debug("JSON template created at \"\(file)\"")
            }
        }
    }
    
    func start(args: [String]) -> Void {
        if (findOption(args, option: "-h") || args.count == 0) {
            usage()
            exit(0)
        }

        if (findOption(args, option: "-help_keys")) {
            helpKeys()
            exit(0)
        }
        if (findOption(args, option: "-version")) {
            print(copyrightNotice)
            exit(0)
        }

        Utils.debug(copyrightNotice)

        let baseName = getOption(args, option: "-asset_template")
        if (baseName != nil) {
            createAssetTemplate(baseName!)
            exit(0)
        }

        let configTemplateFile = getOption(args, option: "-config_template")
        if (configTemplateFile != nil) {
            createConfigTemplate(configTemplateFile!)
            exit(0)
        }
        
        var validateInputs:[String]? = nil
        var validateLang:LangType = .Unset
        validateInputs = getOptions(args, option: "-validate")
        if (validateInputs == nil) {
            validateInputs = getOptions(args, option: "-validate_ios")
            validateLang = .Swift
        }
        if (validateInputs == nil) {
            validateInputs = getOptions(args, option: "-validate_android")
            validateLang = .Java
        }
        if (validateInputs != nil) {
            sourceAssetFolder = getOption(args, option: "-input_assets")
            if (sourceAssetFolder != nil) {
                sourceAssetFolder = NSString(string: sourceAssetFolder!).stringByExpandingTildeInPath

                if (validateLang == .Unset) {
                    validate(validateInputs!, type: .Swift)
                    validate(validateInputs!, type: .Java)
                }
                else {
                    validate(validateInputs!, type: validateLang)
                }
            }
            else {
                print("Error: missing source asset folder")
                exit(-1)
            }
            exit(0)
        }
        
        let configFile = getOption(args, option: "-config")
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
                    compileType = .Java
                }
                else if (type == "swift") {
                    compileType = .Swift
                }
            }
            else {
                exit(-1)
            }
        }
        
        if (compileType == .Unset) {
            if (findOption(args, option: "-java")) {
                compileType = .Java
            }
            else if (findOption(args, option: "-swift")) {
                compileType = .Swift
            }
            else {
                print("Error: need either -swift or -java")
                exit(-1)
            }
        }

        if (assetTag == nil) {
            assetTag = getOption(args, option: "-input_assets_tag")
        }

        if (assetTag != nil) {
            // check for latest tag
            if (assetTag == "~") {
                assetTag = nil
            }
        }

        if (outputClassFile == nil) {
            outputClassFile = getOption(args, option: "-out_source")
        }
        if (outputClassFile != nil) {
            outputClassFile = NSString(string: outputClassFile!).stringByExpandingTildeInPath
        }
        else {
            print("Error: missing output file")
            exit(-1)
        }

        let overrideSourceAssets = getOption(args, option: "-input_assets")
        if (overrideSourceAssets != nil) {
            sourceAssetFolder = overrideSourceAssets
        }
        if (sourceAssetFolder != nil) {
            sourceAssetFolder = NSString(string: sourceAssetFolder!).stringByExpandingTildeInPath
        }
        else {
            print("Error: missing source asset folder")
            exit(-1)
        }
        
        if (outputAssetFolder == nil) {
            outputAssetFolder = getOption(args, option: "-out_assets")
        }
        if (outputAssetFolder != nil) {
            outputAssetFolder = NSString(string: outputAssetFolder!).stringByExpandingTildeInPath
        }
        else {
            print("Error: missing output asset folder")
            exit(-1)
        }

        var result:[String:AnyObject]? = nil
        if (inputFiles == nil) {
            inputFiles = getOptions(args, option: "-inputs")
        }
        if (inputFiles != nil) {
            result = [:]
            for file in inputFiles! {
                let filePath = sourceAssetFolder! + "/" + file
                if let d = Utils.fromJSONFile(filePath) {
                    result = result! + d
                }
                else {
                    exit(-1)
                }
            }
        }

        if (inputFile == nil) {
            inputFile = getOption(args, option: "-input")
        }
        if (inputFile != nil) {
            result = Utils.fromJSONFile(inputFile!)
            if (result == nil) {
                exit(-1)
            }
        }
        
        if (result != nil) {
            var currentBranch:String? = nil
            if (gitEnabled) && (assetTag != nil) && (sourceAssetFolder != nil) {
                currentBranch = Shell.gitCurrentBranch(sourceAssetFolder!)
                if (Shell.gitCheckoutAtTag(sourceAssetFolder!, tag: assetTag!) == false) {
                    print("Error: Can't set asset repo to \(assetTag) tag")
                    exit(-1)
                }
            }
            
            // process
            consume(result!, type: compileType, langOutputFile: outputClassFile!)

            if (gitEnabled) && (assetTag != nil) && (sourceAssetFolder != nil) {
                if (currentBranch != nil) {
                    Shell.gitSetBranch(sourceAssetFolder!, branch: currentBranch!)
                }
            }
        }
        else {
            print("Error: missing input file")
            exit(-1)
        }
    }
}

