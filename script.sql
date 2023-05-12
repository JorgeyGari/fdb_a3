DROP TABLE MANAGERS CASCADE CONSTRAINTS;
DROP TABLE PUBLISHERS CASCADE CONSTRAINTS;
DROP TABLE STUDIOS CASCADE CONSTRAINTS;
DROP TABLE PERFORMERS CASCADE CONSTRAINTS;
DROP TABLE MUSICIANS  CASCADE CONSTRAINTS;
DROP TABLE INVOLVEMENT  CASCADE CONSTRAINTS;
DROP TABLE ALBUMS CASCADE CONSTRAINTS;
DROP TABLE SONGS CASCADE CONSTRAINTS;
DROP TABLE TRACKS CASCADE CONSTRAINTS;
DROP TABLE TOURS CASCADE CONSTRAINTS;
DROP TABLE CONCERTS CASCADE CONSTRAINTS;
DROP TABLE PERFORMANCES CASCADE CONSTRAINTS;
DROP TABLE CLIENTS CASCADE CONSTRAINTS;
DROP TABLE ATTENDANCES CASCADE CONSTRAINTS;
DROP TABLE LANGUAGES CASCADE CONSTRAINTS;
DROP TABLE NATIONALITIES CASCADE CONSTRAINTS;

DROP CLUSTER albums_cluster;

-- Create the monocluster on the "PAIR" column of the "tracks" table
-- CREATE CLUSTER cluster_tracks (PAIR CHAR(15));

-- Create index on cluster
-- CREATE INDEX idx_pair ON CLUSTER cluster_tracks;

-- CREATE INDEX idx_pair ON CLUSTER albums_cluster;

-- -----------------------------------------
-- validation tables
-- -----------------------------------------

CREATE TABLE LANGUAGES(
name    VARCHAR2(20), 
CONSTRAINT PK_LANGUAGES PRIMARY KEY(name)
);

CREATE TABLE NATIONALITIES (
name     VARCHAR2(20), 
CONSTRAINT PK_NATIONALITIES PRIMARY KEY(name)
);

-- -----------------------------------------
-- auxiliary tables
-- -----------------------------------------

CREATE TABLE MANAGERS(
name    VARCHAR2(35) not null, 
f_name  VARCHAR2(20) not null, 
surname VARCHAR2(20), 
mobile  NUMBER(9),
CONSTRAINT PK_MANAGERS PRIMARY KEY(mobile)
);

CREATE TABLE PUBLISHERS(
name    VARCHAR2(25), 
phone   NUMBER(9) NOT NULL,  
CONSTRAINT PK_PUBLISHERS PRIMARY KEY(name)
);

CREATE TABLE STUDIOS(
name     VARCHAR2(50), 
address   VARCHAR2(80) NOT NULL, 
CONSTRAINT PK_STUDIOS PRIMARY KEY(name)
);

-- -----------------------------------------
-- musicians part
-- -----------------------------------------

CREATE TABLE PERFORMERS(
name          VARCHAR2(50),
nationality   VARCHAR2(20) NOT NULL, 
language      VARCHAR2(20) NOT NULL,
CONSTRAINT PK_PERFORMERS PRIMARY KEY(name),
CONSTRAINT FK_nationality FOREIGN KEY(nationality) REFERENCES nationalities,
CONSTRAINT FK_language FOREIGN KEY(language) REFERENCES languages
);

CREATE TABLE MUSICIANS (
name        VARCHAR2(50) NOT NULL,
passport    CHAR(14),
birthdate   DATE NOT NULL,
nationality VARCHAR2(20) NOT NULL, 
CONSTRAINT PK_MUSICIANS PRIMARY KEY(passport),
CONSTRAINT FK_MUSICIANS FOREIGN KEY(nationality) REFERENCES nationalities
);

CREATE TABLE INVOLVEMENT (
band       VARCHAR2(50),
musician   CHAR(14),
role       VARCHAR2(15), 
start_d    DATE NOT NULL,
end_d      DATE,
CONSTRAINT PK_INVOLVEMENT PRIMARY KEY(band,musician,role),
CONSTRAINT FK_INVOLVEMENT1 FOREIGN KEY(band) REFERENCES PERFORMERS ON DELETE CASCADE,
CONSTRAINT FK_INVOLVEMENT2 FOREIGN KEY(musician) REFERENCES MUSICIANS ON DELETE CASCADE,
CONSTRAINT CK_INVOLVEMENT CHECK (end_d is null OR end_d>=start_d)
);


-- -----------------------------------------
-- works part
-- -----------------------------------------
CREATE TABLE ALBUMS(
PAIR       CHAR(15), 
performer  VARCHAR2(50) NOT NULL,
format     CHAR(1) NOT NULL,  -- (T)streaming (C)CD (M)Audio File (V)Vynil (S)Single 
title      VARCHAR2(50) NOT NULL,
rel_date   DATE NOT NULL,
publisher  VARCHAR2(25) NOT NULL,
manager    NUMBER(9) NOT NULL,
CONSTRAINT PK_ALBUMS PRIMARY KEY(PAIR),
CONSTRAINT UK_ALBUMS UNIQUE (performer,format,title,rel_date),
CONSTRAINT FK_ALBUMS1 FOREIGN KEY(performer) REFERENCES PERFORMERS,
CONSTRAINT FK_ALBUMS2 FOREIGN KEY(manager) REFERENCES MANAGERS,
CONSTRAINT FK_ALBUMS3 FOREIGN KEY(publisher) REFERENCES PUBLISHERS,
CONSTRAINT CK_format CHECK (format in ('T','C','M','V','S'))
);

CREATE TABLE SONGS (
title      VARCHAR2(50),
writer     CHAR(14),
cowriter   CHAR(14),
CONSTRAINT PK_SONGS PRIMARY KEY(title, writer),
CONSTRAINT FK_SONGS1 FOREIGN KEY(writer) REFERENCES MUSICIANS,
CONSTRAINT FK_SONGS2 FOREIGN KEY(cowriter) REFERENCES MUSICIANS ON DELETE SET NULL,
CONSTRAINT CK_SONGS CHECK (writer!=cowriter) 
);

CREATE TABLE TRACKS (
PAIR      CHAR(15),
sequ      NUMBER(3) NOT NULL,
title     VARCHAR2(50) NOT NULL,
writer    CHAR(14) NOT NULL, 
duration  NUMBER(4) NOT NULL, -- in seconds
rec_date  DATE NOT NULL,
studio    VARCHAR2(50),
engineer  VARCHAR2(50) NOT NULL, 
CONSTRAINT PK_TRACKS PRIMARY KEY(PAIR, sequ), 
CONSTRAINT FK_TRACKS1 FOREIGN KEY (PAIR) REFERENCES ALBUMS  ON DELETE CASCADE,
CONSTRAINT FK_TRACKS2 FOREIGN KEY (title, writer) REFERENCES SONGS,
CONSTRAINT FK_TRACKS3 FOREIGN KEY (studio) REFERENCES STUDIOS ON DELETE SET NULL,
CONSTRAINT CK_duracion CHECK (duration<=5400))
-- CLUSTER cluster_tracks (PAIR);

-- Create index for the tracks table with the PAIR attribute
CREATE INDEX idx_pair ON TRACKS (PAIR);

-- -----------------------------------------
-- concerts part
-- -----------------------------------------

CREATE TABLE TOURS (
performer   VARCHAR2(50),
name        VARCHAR2(100), 
manager     NUMBER(9) NOT NULL, 
CONSTRAINT PK_TOURS PRIMARY KEY (performer,name),
CONSTRAINT UK_TOURS UNIQUE (performer,name,manager),
CONSTRAINT FK_TOURS FOREIGN KEY(performer) REFERENCES PERFORMERS
);

CREATE TABLE CONCERTS (
performer      VARCHAR2(50),
when           DATE,
tour           VARCHAR2(100), 
municipality   VARCHAR2(100) NOT NULL, 
address        VARCHAR2(100), 
country        VARCHAR2(100), 
attendance     NUMBER(7) DEFAULT (0) NOT NULL,
duration       NUMBER(4),
manager        NUMBER(9) NOT NULL, 
CONSTRAINT PK_CONCERTS PRIMARY KEY (performer,when),
CONSTRAINT FK_CONCERTS1 FOREIGN KEY(performer) REFERENCES PERFORMERS,
CONSTRAINT FK_CONCERTS2 FOREIGN KEY(manager) REFERENCES MANAGERS,
CONSTRAINT FK_CONCERTS3 FOREIGN KEY(performer, tour, manager) REFERENCES TOURS(performer,name,manager)
);

CREATE TABLE PERFORMANCES (
performer  VARCHAR2(50),
when       DATE,
sequ       NUMBER(3), 
songtitle  VARCHAR2(100) NOT NULL, 
songwriter CHAR(14) NOT NULL, 
duration   NUMBER(4),
CONSTRAINT PK_PERFORMANCES PRIMARY KEY (performer,when,sequ),
CONSTRAINT FK_PERFORMANCES1 FOREIGN KEY (performer,when) REFERENCES CONCERTS ON DELETE CASCADE,
CONSTRAINT FK_PERFORMANCES2 FOREIGN KEY (songtitle,songwriter) REFERENCES SONGS
);

-- -----------------------------------------
-- clients part
-- -----------------------------------------

CREATE TABLE CLIENTS (
e_mail      VARCHAR2(100), 
name        VARCHAR2(80), 
surn1       VARCHAR2(80), 
surn2       VARCHAR2(80),
birthdate   DATE, 
phone       NUMBER(9),
address     VARCHAR2(100), 
DNI         VARCHAR2(8),
CONSTRAINT PK_CLIENTS PRIMARY KEY (e_mail),
CONSTRAINT UK_CLIENTS UNIQUE (DNI)
);

CREATE TABLE ATTENDANCES (
client      VARCHAR2(100), 
performer   VARCHAR2(100), 
when        DATE, 
RFID        VARCHAR2(120) NOT NULL,
purchase    DATE,
CONSTRAINT PK_ATTENDANCES PRIMARY KEY (client,performer,when),
CONSTRAINT UK_ATTENDANCES UNIQUE (performer,when,RFID),
CONSTRAINT FK_ATTENDANCES1 FOREIGN KEY (performer,when) REFERENCES CONCERTS ON DELETE CASCADE,
CONSTRAINT FK_ATTENDANCES2 FOREIGN KEY (client) REFERENCES CLIENTS
);

-- Modify table tracks to add searchk and lyrics

ALTER TABLE tracks add (searchk varchar2(20), lyrics VARCHAR2(4000));
UPDATE tracks set searchk=pair||'//'||sequ;
COMMIT;
