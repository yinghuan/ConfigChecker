//
//  main.swift
//  ConfigChecker
//
//  Created by yangzhen.yh on 19/10/2017.
//  Copyright © 2017 yangzhen.yh. All rights reserved.
//

import Foundation

func readConfigFile(_ path: String) -> [String : Any]? {
    var config: [String : Any]?
    do {
        let configData = try Data(contentsOf: URL(fileURLWithPath: path))
        config = try JSONSerialization.jsonObject(with: configData, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any]
    } catch {
        print(error)
    }
    return config
}

func readFilterFile(_ path: String) -> [String]? {
    var filters: [String]?
    do {
        let filterContent = try String(contentsOfFile: path)
        filters = filterContent.components(separatedBy: CharacterSet.newlines)
    } catch {
        print(error)
    }
    return filters
}

func ==(lhs: [[String : Any]], rhs: [[String : Any]]) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for index in 0..<lhs.count {
        let lv = lhs[index]
        let rv = rhs[index]
        guard lv == rv else { return false }
        continue
    }
    return true
}

func ==(lhs: [String : Any], rhs: [String : Any]) -> Bool {
    guard lhs.count == rhs.count else {
        print("count is not same")
        print("---------------------------")
        print("\(lhs)")
        print("---------------------------")
        print("\(rhs)")
        print("---------------------------")
        return false
    }
    guard lhs.keys == rhs.keys else {
        print("keys is not same")
        print("---------------------------")
        print("\(lhs.keys)")
        print("---------------------------")
        print("\(rhs.keys)")
        print("---------------------------")
        return false
    }
    for key in lhs.keys {
        let lv = lhs[key]
        let rv = rhs[key]
        var ret = false
        if let lv = lv as? [String : Any], let rv = rv as? [String : Any] {
            ret = lv == rv
        } else if let lv = lv as? [[String : Any]], let rv = rv as? [[String : Any]] {
            ret = lv == rv
        } else {
            ret = "\(lv ?? "")" == "\(rv ?? "")"
        }
        guard ret else {
            print("sub dictionary is not same")
            print("---------------------------")
            print("\(lv ?? "NULL")")
            print("---------------------------")
            print("\(rv ?? "NULL")")
            print("---------------------------")
            return false
        }
        continue
    }
    return true
}

var filters: [String] = [String]()

struct TargetConfig {
    var name: String?
    var plist: [String : Any]
    
    init?(dic: [String : Any]?) {
        self.name = dic?["target"] as? String
        guard let plistPath = dic?["plist"] as? String else { return nil }
        guard let plistDic = NSDictionary.init(contentsOfFile: plistPath) as? [String : Any] else {
            print("invaild plist file")
            return nil
        }
        self.plist = TargetConfig.filterPlist(plistDic)
    }
    
    static func filterPlist(_ input: [String : Any]) -> [String : Any] {
        guard filters.count > 0 else { return input }
        
        var output = [String : Any]()
        for (key, value) in input {
            guard !filters.contains(key) else { continue }
            if let vd = value as? [String : Any] {
                let vdn = filterPlist(vd)
                output[key] = vdn as Any
            } else if let vda = value as? [[String : Any]] {
                var vdan = [[String : Any]]()
                for vd in vda {
                    let vdn = filterPlist(vd)
                    guard vdn.count > 0 else { continue }
                    vdan.append(vdn)
                }
                output[key] = vdan as Any
            } else {
                output[key] = value
            }
        }
        return output
    }
}

func ==(lhs: TargetConfig, rhs: TargetConfig) -> Bool {
    return lhs.plist == rhs.plist
}

struct Target {
    var release: TargetConfig
    var inhouse: TargetConfig
    
    init?(dic: [String : Any]?) {
        guard let releaseConfig = TargetConfig(dic: dic?["release"] as? [String : Any]) else { return nil }
        self.release = releaseConfig
        
        guard let inhouseConfig = TargetConfig(dic: dic?["inhouse"] as? [String : Any]) else { return nil }
        self.inhouse = inhouseConfig
    }
    
    func isValidTarget() -> Bool {
        return self.inhouse == self.release
    }
}

func ==(lhs: Target, rhs: Target) -> Bool {
    return lhs.inhouse == rhs.inhouse && lhs.release == rhs.release
}

struct AppBuild {
    var name: String
    var appTarget: Target
    
    init?(_ name: String, dic: [String : Any]?) {
        self.name = name
        guard let target = Target(dic: dic?["app"] as? [String : Any]) else { return nil }
        self.appTarget = target
    }
    
    func isValidBuild() -> Bool {
        return self.appTarget.isValidTarget()
    }
}

func ==(lhs: AppBuild, rhs: AppBuild) -> Bool {
    return lhs.appTarget == rhs.appTarget
}

func parseConfig(_ config: [String : Any]?) -> [AppBuild] {
    var builds = [AppBuild]()
    config?.forEach { (key, value) in
        guard let build = AppBuild(key, dic: value as? [String : Any]) else { return }
        builds.append(build)
    }
    return builds
}

if CommandLine.argc <= 1 {
    print("you should input a config file path")
    exit(1)
}

let configFilePath = CommandLine.arguments[1]
if CommandLine.argc > 2 {
    let filterFilePath = CommandLine.arguments[2]
    filters = readFilterFile(filterFilePath) ?? []
}
let builds = parseConfig(readConfigFile(configFilePath))
if builds.count <= 0 {
    print("invaild config file")
    exit(1)
}
var ret = true
builds.forEach { (build) in
    if !build.isValidBuild() {
        print("\(build.name) is invalid")
        ret = false
    } else {
        print("\(build.name) is OK")
    }
}
if let standard = builds.first {
    builds.forEach { (build) in
        if !(build == standard) {
            print("\(build.name) is different from \(standard.name)")
            ret = false
        } else {
            print("\(build.name) is SAME with \(standard.name)")
        }
    }
}

exit(ret ? 0 : 1)
