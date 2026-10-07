-- Conservar los registros de combustible al eliminar una obra.
-- Antes: combustible.id_obra era NOT NULL con ON DELETE CASCADE (se borraba el combustible).
-- Ahora: id_obra pasa a NULL al borrar la obra y el registro queda guardado.

ALTER TABLE combustible DROP FOREIGN KEY fk_combustible_obra;

ALTER TABLE combustible MODIFY id_obra INT NULL;

ALTER TABLE combustible
    ADD CONSTRAINT fk_combustible_obra FOREIGN KEY (id_obra) REFERENCES obras(id_obra)
        ON UPDATE CASCADE ON DELETE SET NULL;
