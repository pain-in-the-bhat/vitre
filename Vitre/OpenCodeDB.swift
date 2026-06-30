import Foundation
import SQLite3

struct DayAggregate: Codable {
    let date: String
    let tokens: Int
    let sessions: Int
}

/// Reads daily token aggregates directly from opencode.db.
/// No sandbox — can open the file directly.
enum OpenCodeDB {
    static func dailyAggregates(days: Int = 30) -> [DayAggregate] {
        let dbPath = "/Users/\(NSUserName())/.local/share/opencode/opencode.db"
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db = db else { return [] }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "PRAGMA journal_mode = OFF", nil, nil, nil)

        let sql = """
            SELECT date(time_created/1000, 'unixepoch'),
                   SUM(tokens_input+tokens_output+tokens_reasoning+tokens_cache_read+tokens_cache_write),
                   COUNT(*) FROM session
            WHERE time_created/1000 > unixepoch('now','-\(days) days')
            GROUP BY 1 ORDER BY 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt = stmt else { return [] }
        defer { sqlite3_finalize(stmt) }

        var r: [DayAggregate] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            r.append(DayAggregate(date: String(cString: sqlite3_column_text(stmt, 0)),
                                  tokens: Int(sqlite3_column_int64(stmt, 1)),
                                  sessions: Int(sqlite3_column_int64(stmt, 2))))
        }
        return r
    }
}