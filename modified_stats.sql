-- ----------------------------------------------------
-- ----------------------------------------------------
-- -- TESTS & STATISTICS SCRIPT -----------------------
-- ----------------------------------------------------
-- -- Course: File Structures and DataBases -----------
-- ----------------------------------------------------
-- -- (c) 2023 Javier Calle ---------------------------
-- ------ Carlos III University of Madrid -------------
-- ----------------------------------------------------
-- ----------------------------------------------------
-- -- Part I: Auxiliary structures (views) & data -----
-- ----------------------------------------------------
-- you can comment this line after running once
ALTER TABLE tracks add (searchk varchar2(20), lyrics VARCHAR2(4000));
UPDATE tracks set searchk=pair||'//'||sequ;
COMMIT;

-- ----------------------------------------------------
-- -- Part II: Package Definition ---------------------
-- ----------------------------------------------------

CREATE OR REPLACE PACKAGE PKG_COSTES AS

-- PREPARE ONE RUN
	PROCEDURE PR_PREPARE;
-- WORKLOAD definition
	PROCEDURE PR_WORKLOAD(N NUMBER);
-- RE-STABLISH DB STATE
	PROCEDURE PR_RESET(N NUMBER);
-- Execution of workload (10 times) displaying some measurements 
	PROCEDURE RUN_TEST(ite NUMBER);

END PKG_COSTES;
/

-- ----------------------------------------------------
-- -- Part II: Package BODY ---------------------------
-- ----------------------------------------------------

CREATE OR REPLACE PACKAGE BODY PKG_COSTES AS

-- auxiliary type and variable declaration (local)
TYPE tipotab IS TABLE OF VARCHAR2(20) INDEX BY BINARY_INTEGER;
changes tipotab;

-- auxiliary function converting an interval into a number (milliseconds)
FUNCTION interval_to_milliseconds(x INTERVAL DAY TO SECOND ) RETURN NUMBER IS
  BEGIN
    return (((extract( day from x)*24 + extract( hour from x))*60 + extract( minute from x))*60 + extract( second from x))*1000;
  END interval_to_milliseconds;
PROCEDURE PR_PREPARE IS

-- this proc prep the following WL
BEGIN
   select searchk bulk collect into changes from (select searchk from tracks order by dbms_random.value) where rownum<=98;
END PR_PREPARE;


PROCEDURE PR_WORKLOAD(N NUMBER) IS
-- this year, the WL does not need to distinguish iterations, so N is not taken into account
BEGIN

--  UPDATE
FOR i IN 1 .. changes.COUNT LOOP
   UPDATE tracks set lyrics = dbms_random.string('a',dbms_random.value(900,1200))
      where searchk=changes(i);
END LOOP;
COMMIT;

-- QUERY 1
FOR fila in (
WITH authors as (select title,writer, writer musician from songs 
                 UNION select title,writer,cowriter musician from songs), 
     authorship as (select distinct band performer, title, writer, 1 flag 
                       FROM involvement join authors using(musician) ),
     recordings as (select performer,tracks.title,writer 
                       from albums join tracks using(pair)),
     recs_match as (select performer, round(sum(flag)*100/count('c'),2) pct_recs 
                       from recordings left join authorship 
                            using(performer,title,writer) 
                       group by performer),
     pers_match as (select performer, round(sum(flag)*100/count('c'),2) pct_pers 
                       from (select performer, songtitle title, songwriter writer 
                                from performances) P 
                            left join authorship using(performer,title,writer) 
                       group by performer)
SELECT performer, pct_recs, pct_pers 
   from recs_match full join pers_match using(performer)
) LOOP null; END LOOP;

-- QUERY 2
FOR fila in (
WITH recordings as (select performer,tracks.title, writer,
                           min(rec_date) rec, 1 token
                       from albums join tracks using(pair)
                       group by performer,tracks.title,writer),
     playbacks as (select P.performer, sum(token)*100/count('x') percentage,
                          avg(nvl2(rec,when-rec,rec)) as age
                       FROM performances P left join recordings R
                            on(P.performer=R.performer AND R.title=P.songtitle
                               AND R.writer=P.songwriter AND P.when>R.rec)
                       GROUP BY P.performer
                       ORDER BY percentage desc)
SELECT performer, percentage, floor(age/365.2422) years,
       floor(mod(age,365.2422)/30.43685) months,
       floor(mod(age,365.2422)-(floor(mod(age,365.2422)/30.43685)*30.43685)) days
   FROM playbacks WHERE rownum<=10
) LOOP null; END LOOP;
END PR_WORKLOAD;


PROCEDURE PR_RESET(N NUMBER) IS
-- Realize that your design could be degenerating
-- To test only initial state's performance, you can restablish initial state
-- this year, the reset does not need to distinguish iterations, so N is not taken into account
BEGIN
    /*********** OLD RESET ***********/
    /*
    execute immediate 'TRUNCATE TABLE tracks';
    INSERT INTO TRACKS(PAIR,sequ,title,writer,duration,rec_date,studio,engineer,searchk)
    (SELECT DISTINCT album_pair,tracknum,min(song),min(writer),min(duration),
                     min(rec_date),min(studio),min(engineer),album_pair||'//'||tracknum
        FROM fsdb.recordings
        WHERE album_pair is not null and tracknum is not null and song is not null and writer is not null
              and duration is not null and rec_date is not null and engineer is not null
      and not (song='Something jazzes' and writer='GB>>0785936179')
    GROUP BY album_pair,tracknum having count('s')=1
    );
    */
      /*********** NEW RESET ***********/
   FOR i IN 1 .. changes.COUNT LOOP
   UPDATE tracks set lyrics = dbms_random.string(NULL,dbms_random.value(900,1200))
      where searchk=changes(i);
   END LOOP;

    COMMIT;
-- NOTE: you should purge structures subjected to changes (actualizations) so they don't fake stats
-- Since procedures are intended for DML, for altering those structures we will use dynamic SQL (as trapdoor)
-- Use this to purge any table, cluster or materialized view (involving structures subject to actualizations)
-- For resetting indexes (involved in actualizations) it's preferrable to rebuild them;
--    execute immediate 'alter table name_of_the_table deallocate unused';
--    execute immediate 'alter cluster name_of_the_cluster deallocate unused';
--    execute immediate 'alter materialized view name_of_the_view deallocate unused';
--    execute immediate 'alter index name_of_the_index rebuild';
END PR_RESET;


PROCEDURE RUN_TEST(ite NUMBER) IS
   t1 TIMESTAMP;
   t2 TIMESTAMP;
   auxt NUMBER := 0;
   g1 NUMBER;
   g2 NUMBER;
   auxg NUMBER := 0;
   localsid NUMBER;
BEGIN
      PKG_COSTES.PR_WORKLOAD(0);  -- idle run for preparing db_buffers
      PKG_COSTES.PR_RESET(0);
      select distinct sid into localsid from v$mystat;
--- LOOP WORKLOAD ITERATIONS (ite times) --------------------------------
      FOR i IN 1..ite LOOP
        DBMS_OUTPUT.PUT_LINE('Iteration '||i);
--- PREPARE WORKLOAD -----------------------------------
        PKG_COSTES.PR_PREPARE;
--- GET PREVIOUS MEASURES -----------------------------------
        SELECT SYSTIMESTAMP INTO t1 FROM DUAL;
        select S.value into g1
           from (select * from v$sesstat where sid=localsid) S
                join (select * from v$statname where name='consistent gets') using(STATISTIC#);
--- EXECUTION OF THE WORKLOAD -----------------------------------
        PKG_COSTES.PR_WORKLOAD (i);
--- GET AFTER-RUN MEASURES -----------------------------------
        SELECT SYSTIMESTAMP INTO t2 FROM DUAL;
        select S.value into g2
           from (select * from v$sesstat where sid=localsid) S
                join (select * from v$statname where name='consistent gets') using(STATISTIC#);
--- ACCUMULATE MEASURES -----------------------------------
        auxt:= auxt + interval_to_milliseconds(t2-t1);
        auxg:= auxg + g2-g1;
--- RESTABLISH STATE-----------------------------------
--- by commenting this line, you can test how your design degenerates (or meets balance)
        PKG_COSTES.PR_RESET (i);
--- END TESTS ---------------------------------------------------
      END LOOP;
      auxt:= auxt / ite;
      auxg:= auxg / ite;
--- DISPLAY RESULTS -----------------------------------
    DBMS_OUTPUT.PUT_LINE('RESULTS AT '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss'));
    DBMS_OUTPUT.PUT_LINE('TIME CONSUMPTION: '|| auxt ||' milliseconds.');
    DBMS_OUTPUT.PUT_LINE('CONSISTENT GETS: '|| auxg ||' blocks');
END RUN_TEST;


BEGIN
-- alter system flush buffer_cache;
   DBMS_OUTPUT.ENABLE (buffer_size => NULL);

END PKG_COSTES;
/

  