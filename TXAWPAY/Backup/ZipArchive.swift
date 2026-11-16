import Foundation
import Compression

// A small, dependency-free ZIP implementation (PKZIP 2.0 subset).
// * Writer: text files are compressed with raw DEFLATE (Apple's Compression
//   framework, COMPRESSION_ZLIB = RFC 1951); media is stored uncompressed and
//   streamed in chunks, so large videos aren't loaded into memory.
// * Reader: supports "stored" and "deflate" entries — everything the writer
//   produces and what Finder/Files create for ordinary archives.
// ZIP64 is not supported (individual files and the archive must be < 4 GB).

enum ZipError: LocalizedError {
    case cannotCreate
    case tooLarge
    case notAZip
    case unsupportedMethod(UInt16)
    case corrupt(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreate: "The archive couldn't be created."
        case .tooLarge: "The archive is larger than 4 GB, which isn't supported."
        case .notAZip: "This file isn't a ZIP archive."
        case .unsupportedMethod(let m): "The archive uses an unsupported compression method (\(m))."
        case .corrupt(let detail): "The archive is damaged: \(detail)"
        }
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func update(_ crc: UInt32, _ data: Data) -> UInt32 {
        var c = crc ^ 0xFFFFFFFF
        data.withUnsafeBytes { (buf: UnsafeRawBufferPointer) in
            for byte in buf { c = table[Int((c ^ UInt32(byte)) & 0xFF)] ^ (c >> 8) }
        }
        return c ^ 0xFFFFFFFF
    }

    static func checksum(_ data: Data) -> UInt32 { update(0, data) }
}

final class ZipWriter {
    private struct CentralEntry {
        var name: Data
        var method: UInt16
        var crc: UInt32
        var compressedSize: UInt32
        var size: UInt32
        var offset: UInt32
        var dosTime: UInt16
        var dosDate: UInt16
    }

    private let handle: FileHandle
    private var entries: [CentralEntry] = []
    private var offset: UInt64 = 0
    private let chunkSize = 1 << 20

    init(url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let h = try? FileHandle(forWritingTo: url) else { throw ZipError.cannotCreate }
        handle = h
    }

    /// Adds in-memory data (compressed with DEFLATE when that saves space).
    func add(path: String, data: Data, modified: Date = Date()) throws {
        let crc = CRC32.checksum(data)
        var method: UInt16 = 0
        var payload = data
        if let deflated = Self.deflate(data), deflated.count < data.count {
            method = 8
            payload = deflated
        }
        try writeEntry(path: path, method: method, crc: crc, compressedSize: payload.count, size: data.count, modified: modified) {
            try write(payload)
        }
    }

    /// Adds a file from disk without loading it fully into memory (stored, not compressed).
    func addFile(path: String, from url: URL) throws {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attrs[.modificationDate] as? Date) ?? Date()
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }

        // Pass 1: CRC.
        var crc: UInt32 = 0
        while let chunk = try reader.read(upToCount: chunkSize), !chunk.isEmpty { crc = CRC32.update(crc, chunk) }
        try reader.seek(toOffset: 0)

        // Pass 2: copy.
        try writeEntry(path: path, method: 0, crc: crc, compressedSize: size, size: size, modified: modified) {
            while let chunk = try reader.read(upToCount: chunkSize), !chunk.isEmpty { try write(chunk) }
        }
    }

    func finish() throws {
        let cdStart = offset
        for e in entries {
            var h = Data()
            h.append(le32: 0x02014b50)
            h.append(le16: 20)       // version made by
            h.append(le16: 20)       // version needed
            h.append(le16: 0x0800)   // UTF-8 names
            h.append(le16: e.method)
            h.append(le16: e.dosTime)
            h.append(le16: e.dosDate)
            h.append(le32: e.crc)
            h.append(le32: e.compressedSize)
            h.append(le32: e.size)
            h.append(le16: UInt16(e.name.count))
            h.append(le16: 0); h.append(le16: 0); h.append(le16: 0); h.append(le16: 0)
            h.append(le32: 0)
            h.append(le32: e.offset)
            h.append(e.name)
            try write(h)
        }
        let cdSize = offset - cdStart
        guard offset < UInt64(UInt32.max), entries.count < Int(UInt16.max) else { throw ZipError.tooLarge }
        var end = Data()
        end.append(le32: 0x06054b50)
        end.append(le16: 0); end.append(le16: 0)
        end.append(le16: UInt16(entries.count)); end.append(le16: UInt16(entries.count))
        end.append(le32: UInt32(cdSize))
        end.append(le32: UInt32(cdStart))
        end.append(le16: 0)
        try write(end)
        try handle.close()
    }

    private func writeEntry(path: String, method: UInt16, crc: UInt32, compressedSize: Int, size: Int, modified: Date,
                            body: () throws -> Void) throws {
        guard offset + UInt64(compressedSize) < UInt64(UInt32.max) else { throw ZipError.tooLarge }
        let name = Data(path.utf8)
        let (time, date) = Self.dosDateTime(modified)
        var h = Data()
        h.append(le32: 0x04034b50)
        h.append(le16: 20)
        h.append(le16: 0x0800)
        h.append(le16: method)
        h.append(le16: time)
        h.append(le16: date)
        h.append(le32: crc)
        h.append(le32: UInt32(compressedSize))
        h.append(le32: UInt32(size))
        h.append(le16: UInt16(name.count))
        h.append(le16: 0)
        h.append(name)
        let entryOffset = UInt32(offset)
        try write(h)
        try body()
        entries.append(CentralEntry(name: name, method: method, crc: crc, compressedSize: UInt32(compressedSize),
                                    size: UInt32(size), offset: entryOffset, dosTime: time, dosDate: date))
    }

    private func write(_ data: Data) throws {
        try handle.write(contentsOf: data)
        offset += UInt64(data.count)
    }

    static func deflate(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        let capacity = data.count + 1024
        var out = Data(count: capacity)
        let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, capacity,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0 else { return nil }
        out.count = written
        return out
    }

    static func dosDateTime(_ date: Date) -> (UInt16, UInt16) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year: Int = max(1980, c.year ?? 1980)
        let hour: Int = c.hour ?? 0
        let minute: Int = c.minute ?? 0
        let second: Int = c.second ?? 0
        let month: Int = c.month ?? 1
        let day: Int = c.day ?? 1
        let timeBits: Int = (hour << 11) | (minute << 5) | (second / 2)
        let dateBits: Int = ((year - 1980) << 9) | (month << 5) | day
        return (UInt16(truncatingIfNeeded: timeBits), UInt16(truncatingIfNeeded: dateBits))
    }
}

enum ZipReader {
    /// Extracts every entry into `destination`. Returns the extracted file URLs.
    @discardableResult
    static func extract(archive url: URL, to destination: URL) throws -> [URL] {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 22 else { throw ZipError.notAZip }

        // Locate the end-of-central-directory record (scan back over a possible comment).
        var eocd = -1
        let minPos = max(0, data.count - 22 - 65_535)
        var i = data.count - 22
        while i >= minPos {
            if data.le32(at: i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }
        let count = Int(data.le16(at: eocd + 10))
        var p = Int(data.le32(at: eocd + 16))

        var results: [URL] = []
        let fm = FileManager.default
        let destRoot = destination.standardizedFileURL.path + "/"
        for _ in 0..<count {
            guard p + 46 <= data.count, data.le32(at: p) == 0x02014b50 else { throw ZipError.corrupt("central directory") }
            let method = data.le16(at: p + 10)
            let compressedSize = Int(data.le32(at: p + 20))
            let size = Int(data.le32(at: p + 24))
            let nameLen = Int(data.le16(at: p + 28))
            let extraLen = Int(data.le16(at: p + 30))
            let commentLen = Int(data.le16(at: p + 32))
            let localOffset = Int(data.le32(at: p + 42))
            guard p + 46 + nameLen <= data.count else { throw ZipError.corrupt("file name") }
            let name = String(decoding: data.subdata(in: (p + 46)..<(p + 46 + nameLen)), as: UTF8.self)
            p += 46 + nameLen + extraLen + commentLen

            // Skip directories, macOS resource forks and unsafe paths ("zip slip").
            if name.hasSuffix("/") || name.hasPrefix("__MACOSX") { continue }
            let target = destination.appendingPathComponent(name).standardizedFileURL
            guard target.path.hasPrefix(destRoot) else { continue }

            guard localOffset + 30 <= data.count, data.le32(at: localOffset) == 0x04034b50 else { throw ZipError.corrupt("local header") }
            let localName = Int(data.le16(at: localOffset + 26))
            let localExtra = Int(data.le16(at: localOffset + 28))
            let start = localOffset + 30 + localName + localExtra
            guard start + compressedSize <= data.count else { throw ZipError.corrupt(name) }
            let raw = data.subdata(in: start..<(start + compressedSize))

            let content: Data
            switch method {
            case 0: content = raw
            case 8: content = try inflate(raw, expectedSize: size)
            default: throw ZipError.unsupportedMethod(method)
            }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: target, options: .atomic)
            results.append(target)
        }
        return results
    }

    static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        if expectedSize == 0 { return Data() }
        var out = Data(count: expectedSize)
        let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, expectedSize,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt("decompression") }
        return out
    }
}

extension Data {
    mutating func append(le16 v: UInt16) {
        var x = v.littleEndian
        Swift.withUnsafeBytes(of: &x) { append(contentsOf: $0) }
    }
    mutating func append(le32 v: UInt32) {
        var x = v.littleEndian
        Swift.withUnsafeBytes(of: &x) { append(contentsOf: $0) }
    }
    func le16(at i: Int) -> UInt16 {
        let b = self[self.startIndex + i ..< self.startIndex + i + 2]
        return UInt16(b[b.startIndex]) | (UInt16(b[b.startIndex + 1]) << 8)
    }
    func le32(at i: Int) -> UInt32 {
        let s = self.startIndex + i
        let b0: UInt32 = UInt32(self[s])
        let b1: UInt32 = UInt32(self[s + 1]) << 8
        let b2: UInt32 = UInt32(self[s + 2]) << 16
        let b3: UInt32 = UInt32(self[s + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
