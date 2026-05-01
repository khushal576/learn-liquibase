-- Referenced by day5-raw-sql.xml changeset w2-day5-004
-- This file is loaded via <sqlFile> — kept separate for DBA review

CREATE TABLE IF NOT EXISTS audit_log (
    id          BIGSERIAL PRIMARY KEY,
    table_name  VARCHAR(50)  NOT NULL,
    operation   VARCHAR(10)  NOT NULL,  -- INSERT / UPDATE / DELETE
    row_id      BIGINT,
    old_data    JSONB,
    new_data    JSONB,
    changed_by  VARCHAR(50),
    changed_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION audit_user_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log(table_name, operation, row_id, new_data)
        VALUES ('users', 'INSERT', NEW.id, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log(table_name, operation, row_id, old_data, new_data)
        VALUES ('users', 'UPDATE', NEW.id, to_jsonb(OLD), to_jsonb(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log(table_name, operation, row_id, old_data)
        VALUES ('users', 'DELETE', OLD.id, to_jsonb(OLD));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_audit
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_user_changes();
