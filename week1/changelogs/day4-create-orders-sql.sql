-- DAY 4 — SQL format changelog.
-- Liquibase supports plain SQL files with special comment markers.
-- Each changeset is delimited by: --changeset author:id
-- Rollback SQL goes between --rollback and the next --changeset

--liquibase formatted sql

--changeset khushal:day4-001
-- Creates the orders table linked to users
CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT        NOT NULL,
    status      VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    total       NUMERIC(10,2) NOT NULL,
    created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id)
);
--rollback DROP TABLE orders;

--changeset khushal:day4-002
-- Add an index on user_id so lookups by user are fast
CREATE INDEX idx_orders_user_id ON orders(user_id);
--rollback DROP INDEX idx_orders_user_id;

--changeset khushal:day4-003
-- Add a check constraint so status only allows known values
ALTER TABLE orders
    ADD CONSTRAINT chk_orders_status
    CHECK (status IN ('PENDING', 'PAID', 'SHIPPED', 'CANCELLED'));
--rollback ALTER TABLE orders DROP CONSTRAINT chk_orders_status;
