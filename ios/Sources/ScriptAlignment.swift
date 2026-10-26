import Foundation

/// Positions map to UTF-16 offsets, so UIKit's layout ranges and the original
/// Chinese script use the same coordinate system, including expanded numbers.
struct ScriptUnits {
    let characters: [Character]
    let sourceOffsets: [Int]
    let sourceEnds: [Int]

    init(_ text: String) {
        let source = text as NSString
        let numbers = try! NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?")
        let matches = numbers.matches(in: text, range: NSRange(location: 0, length: source.length))
        var chars: [Character] = []
        var offsets: [Int] = []
        var ends: [Int] = []
        var position = 0
        func append(_ fragment: String, start: Int, end: Int? = nil) {
            var offset = start
            for character in fragment.lowercased() {
                let length = String(character).utf16.count
                if character.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) || CharacterSet.decimalDigits.contains($0) }) {
                    chars.append(character == "两" ? "二" : character)
                    offsets.append(end == nil ? offset : start)
                    ends.append(end ?? offset + length)
                }
                offset += length
            }
        }
        for match in matches {
            if match.range.location > position {
                append(source.substring(with: NSRange(location: position, length: match.range.location - position)), start: position)
            }
            append(Self.spokenNumber(source.substring(with: match.range)), start: match.range.location, end: NSMaxRange(match.range))
            position = NSMaxRange(match.range)
        }
        if position < source.length { append(source.substring(from: position), start: position) }
        characters = chars; sourceOffsets = offsets; sourceEnds = ends
    }

    static func spokenNumber(_ raw: String) -> String {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        let digits = Array("零一二三四五六七八九")
        func digitString(_ s: Substring) -> String { String(s.compactMap { $0.wholeNumberValue.map { digits[$0] } }) }
        let whole = parts[0]
        var result: String
        if whole.count > 5 || (whole.count > 1 && whole.first == "0") {
            result = digitString(whole)
        } else if let value = Int(whole), value > 0 {
            func underTenThousand(_ n: Int) -> String {
                let units = [1000, 100, 10, 1]
                let names = ["千", "百", "十", ""]
                var output = ""
                var pendingZero = false
                for (i, unit) in units.enumerated() {
                    let d = (n / unit) % 10
                    if d > 0 {
                        if pendingZero { output += "零"; pendingZero = false }
                        if !(unit == 10 && d == 1 && output.isEmpty) { output += String(digits[d]) }
                        output += names[i]
                    } else if !output.isEmpty && n % unit != 0 { pendingZero = true }
                }
                return output
            }
            if value >= 10000 {
                let rest = value % 10000
                result = String(digits[value / 10000]) + "万"
                if rest > 0 { result += (rest < 1000 ? "零" : "") + underTenThousand(rest) }
            } else { result = underTenThousand(value) }
        } else { result = "零" }
        if parts.count > 1 { result += "点" + digitString(parts[1]) }
        return result
    }
}

struct AlignmentMatch {
    let cursor: Int
    let matched: Bool
    let score: Double
}

/// Aligns the latest ASR hypothesis with the script in O(heard × window) work.
/// A free script prefix allows matching within the window without running a
/// separate edit-distance allocation for every possible substring.
struct ScriptAligner {
    let script: ScriptUnits

    func align(_ transcript: String, near cursor: Int) -> AlignmentMatch {
        let spoken = ScriptUnits(transcript).characters
        guard spoken.count >= 3, !script.characters.isEmpty else {
            return AlignmentMatch(cursor: cursor, matched: false, score: 0)
        }
        let position = min(max(0, cursor), script.characters.count)
        var best = AlignmentMatch(cursor: cursor, matched: false, score: 0)
        var tested = Set<Int>()
        for requested in [24, 16, 10, 6, 4] {
            let size = min(requested, spoken.count)
            guard tested.insert(size).inserted else { continue }
            let match = search(Array(spoken.suffix(size)), lower: max(0, position - 70),
                               upper: min(script.characters.count, position + 220), cursor: position)
            if match.score > best.score { best = match }
        }
        if !best.matched && spoken.count >= 12 {
            // Reacquire after the reader skips a paragraph. Long, near-exact
            // evidence is required so an unrelated short phrase cannot jump.
            best = search(Array(spoken.suffix(24)), lower: 0, upper: script.characters.count,
                          cursor: position, reacquiring: true)
        }
        return best
    }

    private func search(_ spoken: [Character], lower: Int, upper: Int, cursor: Int,
                        reacquiring: Bool = false) -> AlignmentMatch {
        let text = script.characters
        let count = upper - lower
        guard count > 0 else { return AlignmentMatch(cursor: cursor, matched: false, score: 0) }
        var previous = Array(repeating: 0, count: count + 1)
        var starts = Array(0...count)
        var current = Array(repeating: 0, count: count + 1)
        var currentStarts = Array(repeating: 0, count: count + 1)
        for (index, character) in spoken.enumerated() {
            current[0] = index + 1; currentStarts[0] = 0
            for column in 1...count {
                var cost = previous[column - 1] + (character == text[lower + column - 1] ? 0 : 1)
                var start = starts[column - 1]
                if previous[column] + 1 < cost { cost = previous[column] + 1; start = starts[column] }
                if current[column - 1] + 1 < cost { cost = current[column - 1] + 1; start = currentStarts[column - 1] }
                current[column] = cost; currentStarts[column] = start
            }
            swap(&previous, &current); swap(&starts, &currentStarts)
        }
        var best = AlignmentMatch(cursor: cursor, matched: false, score: 0)
        for end in 1...count {
            let length = end - starts[end]
            guard length >= 3, abs(length - spoken.count) <= 4 else { continue }
            let similarity = 1 - Double(previous[end]) / Double(max(length, spoken.count))
            let movement = lower + end - cursor
            let required = reacquiring ? 0.9 : (spoken.count < 6 ? 1.0 : (spoken.count < 10 ? 0.8 : 0.7))
            guard similarity >= required else { continue }
            if !reacquiring {
                if spoken.count < 6 && (movement < -6 || movement > 24) { continue }
                if spoken.count < 8 && (movement < -8 || movement > 60) { continue }
            }
            let penalty = Double(abs(movement)) * (reacquiring ? 0.00001 : 0.002)
            let score = (similarity - 0.55) * sqrt(Double(spoken.count)) - min(0.4, penalty)
            if score > best.score { best = AlignmentMatch(cursor: lower + end, matched: true, score: score) }
        }
        return best
    }
}
