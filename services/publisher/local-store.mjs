import { DatabaseSync } from "node:sqlite";
import fs from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
export class LocalJobs {
  constructor(directory) {
    fs.mkdirSync(directory, { recursive: true });
    this.db = new DatabaseSync(path.join(directory, "jobs.sqlite"));
    this.db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
 CREATE TABLE IF NOT EXISTS jobs(id TEXT PRIMARY KEY,idempotency TEXT UNIQUE NOT NULL,snapshot TEXT NOT NULL,state TEXT NOT NULL DEFAULT 'queued',version INTEGER UNIQUE NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,error TEXT);
 CREATE TABLE IF NOT EXISTS publication_state(id INTEGER PRIMARY KEY CHECK(id=1),active_version INTEGER NOT NULL DEFAULT 0,next_version INTEGER NOT NULL DEFAULT 1,lease_owner TEXT,lease_until INTEGER NOT NULL DEFAULT 0);
 INSERT OR IGNORE INTO publication_state(id) VALUES(1);`);
  }
  transaction(callback) {
    this.db.exec("BEGIN IMMEDIATE");
    try {
      const value = callback();
      this.db.exec("COMMIT");
      return value;
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
  }
  submit(snapshot, idempotency) {
    return this.transaction(() => {
      const encoded = JSON.stringify(structuredClone(snapshot));
      const old = this.db
        .prepare("SELECT * FROM jobs WHERE idempotency=?")
        .get(idempotency);
      if (old) {
        if (old.snapshot !== encoded) throw Error("IDEMPOTENCY_CONFLICT");
        return old;
      }
      const state = this.state();
      const id = randomUUID();
      this.db
        .prepare(
          "INSERT INTO jobs(id,idempotency,snapshot,version) VALUES(?,?,?,?)",
        )
        .run(id, idempotency, encoded, state.next_version);
      this.db
        .prepare(
          "UPDATE publication_state SET next_version=next_version+1 WHERE id=1",
        )
        .run();
      return this.db.prepare("SELECT * FROM jobs WHERE id=?").get(id);
    });
  }
  state() {
    return this.db.prepare("SELECT * FROM publication_state WHERE id=1").get();
  }
  claim(owner, now = Date.now(), leaseMs = 120000) {
    return this.transaction(() => {
      const state = this.state();
      if (state.lease_owner && state.lease_until > now) return null;
      const job = this.db
        .prepare(
          "SELECT * FROM jobs WHERE state IN ('queued','running') ORDER BY version LIMIT 1",
        )
        .get();
      if (!job) return null;
      this.db
        .prepare(
          "UPDATE publication_state SET lease_owner=?,lease_until=? WHERE id=1",
        )
        .run(owner, now + leaseMs);
      this.db
        .prepare(
          "UPDATE jobs SET state='running',attempts=attempts+1 WHERE id=?",
        )
        .run(job.id);
      return { ...job, owner, snapshot: JSON.parse(job.snapshot) };
    });
  }
  assertLease(owner, now = Date.now()) {
    const s = this.state();
    if (s.lease_owner !== owner || s.lease_until <= now)
      throw Error("LEASE_LOST");
  }
  heartbeat(owner, now = Date.now(), leaseMs = 120000) {
    this.assertLease(owner, now);
    this.db
      .prepare(
        "UPDATE publication_state SET lease_until=? WHERE id=1 AND lease_owner=?",
      )
      .run(now + leaseMs, owner);
  }
  complete(job) {
    this.transaction(() => {
      this.assertLease(job.owner);
      if (this.state().active_version > job.version)
        throw Error("VERSION_REGRESSION");
      this.db
        .prepare("UPDATE jobs SET state='published',error=NULL WHERE id=?")
        .run(job.id);
      this.db
        .prepare(
          "UPDATE publication_state SET active_version=?,lease_owner=NULL,lease_until=0 WHERE id=1",
        )
        .run(job.version);
    });
  }
  async commitPointer(job, changePointer) {
    this.db.exec("BEGIN IMMEDIATE");
    try {
      this.assertLease(job.owner);
      if (this.state().active_version > job.version)
        throw Error("VERSION_REGRESSION");
      await changePointer();
      this.db
        .prepare("UPDATE jobs SET state='published',error=NULL WHERE id=?")
        .run(job.id);
      this.db
        .prepare(
          "UPDATE publication_state SET active_version=?,lease_owner=NULL,lease_until=0 WHERE id=1",
        )
        .run(job.version);
      this.db.exec("COMMIT");
    } catch (e) {
      this.db.exec("ROLLBACK");
      throw e;
    }
  }
  fail(job, error) {
    this.transaction(() => {
      this.assertLease(job.owner);
      this.db
        .prepare("UPDATE jobs SET state='failed',error=? WHERE id=?")
        .run(error.slice(0, 1000), job.id);
      this.db
        .prepare(
          "UPDATE publication_state SET lease_owner=NULL,lease_until=0 WHERE id=1",
        )
        .run();
    });
  }
  retry(id) {
    this.db
      .prepare(
        "UPDATE jobs SET state='queued',error=NULL WHERE id=? AND state='failed'",
      )
      .run(id);
  }
  close() {
    this.db.close();
  }
}
