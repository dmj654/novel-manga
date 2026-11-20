import Foundation
import GRDB

/// 数据库建库与迁移。v1 表结构对应《开发计划》§5.1。
enum AppDatabase {
    static func makeQueue(at url: URL) throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode = WAL")
        }
        return try DatabaseQueue(path: url.path, configuration: config)
    }

    /// 测试用内存库
    static func makeInMemoryQueue() throws -> DatabaseQueue {
        try DatabaseQueue()
    }

    static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(sql: v1DDL)
        }
        return migrator
    }()

    static func migrate(_ queue: DatabaseQueue) throws {
        try migrator.migrate(queue)
    }

    static let v1DDL = """
    CREATE TABLE books (
      id            TEXT PRIMARY KEY,
      title         TEXT NOT NULL,
      author        TEXT,
      cover_path    TEXT,
      type          INTEGER NOT NULL,
      origin        INTEGER NOT NULL,
      source_id     TEXT,
      remote_key    TEXT,
      intro         TEXT,
      category      TEXT,
      serial_status INTEGER,
      unit_count    INTEGER NOT NULL DEFAULT 0,
      in_shelf      INTEGER NOT NULL DEFAULT 0,
      favorited_at  INTEGER,
      last_opened_at INTEGER,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER
    );

    CREATE TABLE units (
      id         TEXT PRIMARY KEY,
      book_id    TEXT NOT NULL,
      idx        INTEGER NOT NULL,
      title      TEXT,
      url        TEXT,
      page_count INTEGER,
      cached     INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER,
      UNIQUE (book_id, idx)
    );

    CREATE TABLE pages (
      book_id    TEXT NOT NULL,
      unit_idx   INTEGER NOT NULL,
      page_idx   INTEGER NOT NULL,
      url        TEXT,
      local_path TEXT,
      width      INTEGER,
      height     INTEGER,
      PRIMARY KEY (book_id, unit_idx, page_idx)
    );

    CREATE TABLE progress (
      book_id    TEXT PRIMARY KEY,
      unit_idx   INTEGER NOT NULL,
      char_offset INTEGER NOT NULL DEFAULT 0,
      page_idx   INTEGER NOT NULL DEFAULT 0,
      percent    REAL NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL
    );

    CREATE TABLE sources (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      type        INTEGER NOT NULL,
      enabled     INTEGER NOT NULL DEFAULT 1,
      rules_json  TEXT NOT NULL,
      last_status INTEGER,
      last_checked_at INTEGER,
      created_at  INTEGER NOT NULL
    );

    CREATE TABLE groups (
      id   TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      sort INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE book_groups (
      book_id  TEXT NOT NULL,
      group_id TEXT NOT NULL,
      PRIMARY KEY (book_id, group_id)
    );

    CREATE TABLE search_history (
      keyword  TEXT NOT NULL,
      tab      INTEGER NOT NULL,
      used_at  INTEGER NOT NULL
    );

    CREATE TABLE cards (
      id     TEXT PRIMARY KEY,
      type   INTEGER NOT NULL,
      params TEXT,
      sort   INTEGER NOT NULL
    );

    CREATE TABLE settings (
      key   TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );

    CREATE INDEX idx_books_in_shelf ON books (in_shelf, last_opened_at);
    CREATE INDEX idx_progress_updated ON progress (updated_at);
    CREATE INDEX idx_units_book_idx ON units (book_id, idx);
    """
}
