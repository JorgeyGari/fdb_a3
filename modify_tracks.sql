ALTER TABLE tracks add (searchk varchar2(20), lyrics VARCHAR2(4000));
UPDATE tracks set searchk=pair||'//'||sequ;
COMMIT;