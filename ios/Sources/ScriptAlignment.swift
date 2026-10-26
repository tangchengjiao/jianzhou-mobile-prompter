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

/// Aligns recent recognized Chinese characters against the known script.
/// ASR revisions are treated as replacement hypotheses, never appended blindly.
struct ScriptAligner {
    let script: ScriptUnits

    func align(_ transcript: String, near cursor: Int) -> AlignmentMatch {
        let spoken = ScriptUnits(transcript).characters
        guard spoken.count >= 3, !script.characters.isEmpty else {
            return AlignmentMatch(cursor: cursor, matched: false, score: 0)
        }
        let text = script.characters
        let lower = max(0, cursor - 70)
        let upper = min(text.count, cursor + 220)
        var best = AlignmentMatch(cursor: cursor, matched: false, score: 0)
        for requested in [18, 12, 8, 5] {
            let size = min(requested, spoken.count)
            if size < 3 { continue }
            let recent = Array(spoken.suffix(size))
            for end in max(lower + 1, size / 2)...max(lower + 1, upper) {
                for length in max(3, size - 2)...(size + 2) {
                    let start = end - length
                    if start < lower || end > upper { continue }
                    let distance = Self.editDistance(recent, Array(text[start..<end]))
                    let similarity = 1 - Double(distance) / Double(max(size, length))
                    let movement = end - cursor
                    if movement < -8 && size < 6 { continue }
                    if movement > 60 && size < 8 { continue }
                    let score = similarity - Double(abs(movement)) * 0.0007 + Double(size) * 0.001
                    if score > best.score && similarity >= 0.72 {
                        best = AlignmentMatch(cursor: end, matched: true, score: score)
                    }
                }
            }
        }
        return best
    }

    private static func editDistance(_ a: [Character], _ b: [Character]) -> Int {
        var row = Array(0...b.count)
        for i in a.indices {
            var next = [i + 1] + Array(repeating: 0, count: b.count)
            for j in b.indices { next[j + 1] = min(next[j] + 1, min(row[j + 1] + 1, row[j] + (a[i] == b[j] ? 0 : 1))) }
            row = next
        }
        return row[b.count]
    }
}
