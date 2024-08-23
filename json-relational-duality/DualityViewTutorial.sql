/*
** Copyright (c) 2024 Oracle and/or its affiliates
** The Universal Permissive License (UPL), Version 1.0
**
** Subject to the condition set forth below, permission is hereby granted to any
** person obtaining a copy of this software, associated documentation and/or data
** (collectively the "Software"), free of charge and under any and all copyright
** rights in the Software, and any and all patent rights owned or freely
** licensable by each licensor hereunder covering either (i) the unmodified
** Software as contributed to or provided by such licensor, or (ii) the Larger
** Works (as defined below), to deal in both
**
** (a) the Software, and
** (b) any piece of software and/or hardware listed in the lrgrwrks.txt file if
** one is included with the Software (each a "Larger Work" to which the Software
** is contributed by such licensors),
**
** without restriction, including without limitation the rights to copy, create
** derivative works of, display, perform, and distribute the Software and make,
** use, sell, offer for sale, import, export, have made, and have sold the
** Software and the Larger Work(s), and to sublicense the foregoing rights on
** either these or other terms.
**
** This license is subject to the following condition:
** The above copyright notice and either this complete permission notice or at
** a minimum a reference to the UPL must be included in all copies or
** substantial portions of the Software.
**
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
** AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
** LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
** OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
** SOFTWARE.
*/

--    TITLE
--      Working with JSON Relational Duality Views using SQL.
--
--    DESCRIPTION
--      This tutorial script walks you through examples of working with
--      JSON Relational Duality Views using Formula-1 (auto-racing) season data
--      through SQL.
--
--    PREREQUISITES
--      Ensure that you have Oracle database 23ai installed and running on a
--      port. Ensure that the compatible parameter is set to 23.0.0.0.
--
--    USAGE
--      Connect to the database as a regular (non-SYS) user and run this
--      script. The user must have create session and resource privileges.
--      A demo user (janus) can be created using this statement:
--       GRANT CTXAPP, CONNECT, RESOURCE, UNLIMITED TABLESPACE, CREATE ANY
--         DIRECTORY, DROP ANY DIRECTORY, DBA TO janus IDENTIFIED BY janus;
--
--    NOTES
--      Please go through the duality view documentation
--      (https://docs.oracle.com/en/database/oracle/oracle-database/23/jsnvu/index.html)
--      to learn more about duality views and their advantages.
--      This tutorial is analogous to the REST (Working with JSON Relational
--      Duality Views using REST) and MongoAPI (Working with JSON-Relational
--      Duality Views using Oracle Database API for MongoDB) tutorials.
--      Additional resources:
--      Duality Views blog (posted October 2022): https://blogs.oracle.com/database/post/json-relational-duality-app-dev?source=:so:ch:or:awr::::OCW23cbeta
--      Oracle CloudWorld 2022 keynote - https://www.youtube.com/watch?v=e8-jBkO1NqY&t=17s

SET ECHO ON
SET FEEDBACK 1
SET NUMWIDTH 10
SET LINESIZE 80
SET TRIMSPOOL ON
SET TAB OFF
SET PAGESIZE 100
SET LONG 20000

prompt
prompt ** Working with JSON Relational Duality Views using SQL **
prompt

-- Do cleanup for previous run (if any).
--
drop view  if exists team_dv;
drop view  if exists race_dv;
drop view  if exists driver_dv;
drop table if exists driver_race_map;
drop table if exists race;
drop table if exists driver;
drop table if exists team;


--------------------------------------------------
-- Step 1: Create JSON Relational Duality Views --
--------------------------------------------------

-- Create base tables for the duality views.
--
CREATE TABLE team
  (team_id INTEGER GENERATED BY DEFAULT ON NULL AS IDENTITY,
   name    VARCHAR2(255) NOT NULL UNIQUE,
   points  INTEGER NOT NULL,
   CONSTRAINT team_pk PRIMARY KEY(team_id));

CREATE TABLE driver
  (driver_id INTEGER GENERATED BY DEFAULT ON NULL AS IDENTITY,
   name      VARCHAR2(255) NOT NULL UNIQUE,
   points    INTEGER NOT NULL,
   team_id   INTEGER,
   CONSTRAINT driver_pk PRIMARY KEY(driver_id),
   CONSTRAINT driver_fk FOREIGN KEY(team_id) REFERENCES team(team_id));

CREATE TABLE race
  (race_id   INTEGER GENERATED BY DEFAULT ON NULL AS IDENTITY,
   name      VARCHAR2(255) NOT NULL UNIQUE,
   laps      INTEGER NOT NULL,
   race_date DATE,
   podium    JSON,
   CONSTRAINT   race_pk PRIMARY KEY(race_id));
  
CREATE TABLE driver_race_map
  (driver_race_map_id INTEGER GENERATED BY DEFAULT ON NULL AS IDENTITY,
   race_id            INTEGER NOT NULL,
   driver_id          INTEGER NOT NULL,
   position           INTEGER,
   CONSTRAINT     driver_race_map_uk  UNIQUE (race_id, driver_id),
   CONSTRAINT     driver_race_map_pk  PRIMARY KEY(driver_race_map_id),
   CONSTRAINT     driver_race_map_fk1 FOREIGN KEY(race_id)   REFERENCES race(race_id),
   CONSTRAINT     driver_race_map_fk2 FOREIGN KEY(driver_id) REFERENCES driver(driver_id));

-- Create a trigger on the driver_race_map table to populate
-- the points fields in team and driver based on race results.
--
-- For people that are not familiar with Formula One: Depending on the position in a race,
-- both the racing team and the driver get points. There are two championships in Formula One: 
-- one for the drivers and one for the teams. The team championship is called the Constructors' 
-- Championship and the scoring system is the same as in the Drivers' Championship — except the 
-- points from both drivers on a team are tallied together.
-- If you want to read up more, then check out 
-- - https://www.redbull.com/in-en/formula-1-points-system-guide
--
CREATE OR REPLACE TRIGGER driver_race_map_trigger
  BEFORE INSERT ON driver_race_map
  FOR EACH ROW
  DECLARE
    v_points  INTEGER;
    v_team_id INTEGER;
BEGIN
  SELECT team_id INTO v_team_id FROM driver WHERE driver_id = :NEW.driver_id;

  IF :NEW.position = 1 THEN
    v_points := 25;
  ELSIF :NEW.position = 2 THEN
    v_points := 18;
  ELSIF :NEW.position = 3 THEN
    v_points := 15;
  ELSIF :NEW.position = 4 THEN
    v_points := 12;
  ELSIF :NEW.position = 5 THEN
    v_points := 10;
  ELSIF :NEW.position = 6 THEN
    v_points := 8;
  ELSIF :NEW.position = 7 THEN
    v_points := 6;
  ELSIF :NEW.position = 8 THEN
    v_points := 4;
  ELSIF :NEW.position = 9 THEN
    v_points := 2;
  ELSIF :NEW.position = 10 THEN
    v_points := 1;
  ELSE
    v_points := 0;
  END IF;

  UPDATE driver SET points = points + v_points
    WHERE driver_id = :NEW.driver_id;
  UPDATE team SET points = points + v_points
    WHERE team_id = v_team_id;
END;
/

-- Create race view, RACE_DV
--

-- Creation using SQL syntax
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW race_dv AS
  SELECT JSON {'_id' : r.race_id,
               'name'   : r.name,
               'laps'   : r.laps WITH NOUPDATE,
               'date'   : r.race_date,
               'podium' : r.podium WITH NOCHECK,
               'result' :
                 [ SELECT JSON {'driverRaceMapId' : drm.driver_race_map_id,
                                'position'        : drm.position,
                                UNNEST
                                  (SELECT JSON {'driverId' : d.driver_id,
                                                'name'     : d.name}
                                     FROM driver d WITH NOINSERT UPDATE NODELETE
                                     WHERE d.driver_id = drm.driver_id)}
                     FROM driver_race_map drm WITH INSERT UPDATE DELETE
                     WHERE drm.race_id = r.race_id ]}
    FROM race r WITH INSERT UPDATE DELETE;

-- Creation using GraphQL syntax
/*
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW race_dv AS
  race @insert @update @delete
  {
    _id : race_id
    name   : name
    laps   : laps @noUpdate
    date   : race_date
    podium : podium @noCheck
    result : driver_race_map @insert @update @delete
    [
     {
      driverRaceMapId : driver_race_map_id
      position        : position
      driver @noInsert @update @noDelete @unnest
      {
        driverId : driver_id
        name     : name
      }
     }
    ]
  };
*/

-- Create driver view, DRIVER_DV
--

-- Creation using SQL syntax
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW driver_dv AS
  SELECT JSON {'_id' : d.driver_id,
               'name'     : d.name,
               'points'   : d.points,
               UNNEST
                 (SELECT JSON {'teamId' : t.team_id,
                               'team'   : t.name WITH NOCHECK}
                    FROM team t WITH NOINSERT NOUPDATE NODELETE
                    WHERE t.team_id = d.team_id),
               'race'     :
                 [ SELECT JSON {'driverRaceMapId' : drm.driver_race_map_id,
                                UNNEST
                                  (SELECT JSON {'raceId' : r.race_id,
                                                'name'   : r.name}
                                     FROM race r WITH NOINSERT NOUPDATE NODELETE
                                     WHERE r.race_id = drm.race_id),
                                'finalPosition'   : drm.position}
                    FROM driver_race_map drm WITH INSERT UPDATE NODELETE
                    WHERE drm.driver_id = d.driver_id ]}
    FROM driver d WITH INSERT UPDATE DELETE;
  
-- Creation using GraphQL syntax
/*
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW driver_dv AS
  driver @insert @update @delete
  {
    _id : driver_id
    name     : name
    points   : points
    team @noInsert @noUpdate @noDelete @unnest
    {
      teamId : team_id
      team   : name @noCheck
    }
    race : driver_race_map @insert @update @noDelete
    [
     {
      driverRaceMapId : driver_race_map_id
      race @noInsert @noUpdate @noDelete @unnest
      {
        raceId : race_id
        name   : name
      }
      finalPosition   : position
     }
    ]
  };
*/

-- Create team view, TEAM_DV
--

-- Creation using SQL syntax
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW team_dv AS
  SELECT JSON {'_id' : t.team_id,
               'name'   : t.name,
               'points' : t.points,
               'driver' :
                 [ SELECT JSON {'driverId' : d.driver_id,
                                'name'     : d.name,
                                'points'   : d.points WITH NOCHECK}
                     FROM driver d WITH INSERT UPDATE
                     WHERE d.team_id = t.team_id ]}
    FROM team t WITH INSERT UPDATE DELETE;

-- Creation using GraphQL syntax
/*
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW team_dv AS
  team @insert @update @delete
  {
    _id : team_id
    name   : name
    points : points
    driver : driver @insert @update
    [
     {
      driverId : driver_id
      name     : name
      points   : points @noCheck
     }
    ]
  };
*/


--------------------------------------------------
-- Step 2: List all documents in a duality view --
--------------------------------------------------

SELECT json_serialize(data PRETTY) FROM driver_dv;
SELECT json_serialize(data PRETTY) FROM race_dv;
SELECT json_serialize(data PRETTY) FROM team_dv;


----------------------------------------
-- Step 3: Populate the duality views --
----------------------------------------

-- Insert a collection of team documents into TEAM_DV.
-- This automatically populates the driver and team table as well as the
-- driver collection.
--
INSERT INTO team_dv VALUES ('{"_id" : 301,
                              "name"   : "Red Bull",
                              "points" : 0,
                              "driver" : [ {"driverId" : 101,
                                            "name"     : "Max Verstappen",
                                            "points"   : 0},
                                           {"driverId" : 102,
                                            "name"     : "Sergio Perez",
                                            "points"   : 0} ]}');

INSERT INTO team_dv VALUES ('{"_id" : 302,
                              "name"   : "Ferrari",
                              "points" : 0,
                              "driver" : [ {"driverId" : 103,
                                            "name"     : "Charles Leclerc",
                                            "points"   : 0},
                                           {"driverId" : 104,
                                            "name"     : "Carlos Sainz Jr",
                                            "points"   : 0} ]}');

INSERT INTO team_dv VALUES ('{"_id" : 2,
                              "name"   : "Mercedes",
                              "points" : 0,
                              "driver" : [ {"driverId" : 105,
                                            "name"     : "George Russell",
                                            "points"   : 0},
                                           {"driverId" : 106,
                                            "name"     : "Lewis Hamilton",
                                            "points"   : 0} ]}');

-- Insert a collection of race documents into RACE_DV.
-- This automatically populates the race table.
--
INSERT INTO race_dv VALUES ('{"_id" : 201,
                              "name"   : "Bahrain Grand Prix",
                              "laps"   : 57,
                              "date"   : "2022-03-20T00:00:00",
                              "podium" : {}}');

INSERT INTO race_dv VALUES ('{"_id" : 202,
                              "name"   : "Saudi Arabian Grand Prix",
                              "laps"   : 50,
                              "date"   : "2022-03-27T00:00:00",
                              "podium" : {}}');

INSERT INTO race_dv VALUES ('{"_id" : 203,
                              "name"   : "Australian Grand Prix",
                              "laps"   : 58,
                              "date"   : "2022-04-09T00:00:00",
                              "podium" : {}}');

COMMIT;


----------------------------------------------------------
-- Step 4: See the effects of populating a duality view --
----------------------------------------------------------

-- Populating a duality view automatically updates data shown in related
-- duality views, by updating their underlying tables. For example, in the
-- previous step documents were inserted into the team_dv duality view. This
-- duality view joins the team table with the driver table, so on insert into
-- this duality view both the team table as well as the driver table are
-- populated. If you now list the contents of the driver_dv duality view, which
-- is based on the driver table, it has documents as well.
--
SELECT json_serialize(data PRETTY) FROM driver_dv;
SELECT json_serialize(data PRETTY) FROM race_dv;


----------------------------------------------------------
-- Step 5: Find documents matching a filter (predicate) --
--    with optional projection of fields and sorting    --
----------------------------------------------------------

-- Find race info by raceId.
-- You can use JSON functions, such as json_value or json_exists in predicates
-- when querying duality views. You can also use simplified dot notation in
-- predicates (see Step 9 for an example of this). The json_exists function is
-- more powerful than json_value in terms of the conditions it can express and
-- is used by the REST interface to translate QBEs.
--
SELECT json_serialize(data PRETTY)
  FROM race_dv WHERE json_value(data, '$._id') = 201;

-- Project specific document fields.
-- In SQL, specific documents fields can be requested using the KEEP operator
-- in json_transform (other fields will be excluded in returned document).
-- Alternatively, you can exclude specific fields from the returned documents
-- using the REMOVE operator in json_transform.
SELECT json_serialize(json_transform(data, KEEP '$.name', '$.team') PRETTY)
  FROM driver_dv;

-- Sort returned documents by field value.
-- Returned documents can be sorted, using simplified syntax or json_value.
SELECT json_serialize(json_transform(data, KEEP '$.name', '$.team') PRETTY)
  FROM driver_dv ORDER BY json_value(data, '$.team');


--------------------------------------
-- Step 6: Replace a document by ID --
--------------------------------------

-- Announce results for the Bahrain Grand Prix.
-- Note that the "etag" value supplied in the content is used for "out-of-
-- the-box" optimistic locking, to prevent the well-known "lost update" problem
-- that can occur with concurrent operations. During the replace by ID
-- operation, the database checks that the eTag provided in the replacement
-- document matches the latest eTag of the target duality view document. If the
-- eTags do not match, which can occur if another concurrent operation updated
-- the same document, an error is thrown. In case of such an error, you can
-- reread the updated value (including the updated eTag), and retry the replace
-- operation again, adjusting it (if desired) based on the updated value.
-- To see that a replace using an eTag that is not the most recent fails, run
-- the same command again.
--
UPDATE race_dv dv
  SET data = ('{_metadata : {"etag" : "2E8DC09543DD25DC7D588FB9734D962B"},
                "_id" : 201,
                "name"   : "Bahrain Grand Prix",
                "laps"   : 57,
                "date"   : "2022-03-20T00:00:00",
                "podium" :
                  {"winner"         : {"name" : "Charles Leclerc",
                                       "time" : "01:37:33.584"},
                   "firstRunnerUp"  : {"name" : "Carlos Sainz Jr",
                                       "time" : "01:37:39.182"},
                   "secondRunnerUp" : {"name" : "Lewis Hamilton",
                                       "time" : "01:37:43.259"}},
                "result" : [ {"driverRaceMapId" : 3,
                              "position"        : 1,
                              "driverId"        : 103,
                              "name"            : "Charles Leclerc"},
                             {"driverRaceMapId" : 4,
                              "position"        : 2,
                              "driverId"        : 104,
                              "name"            : "Carlos Sainz Jr"},
                             {"driverRaceMapId" : 9,
                              "position"        : 3,
                              "driverId"        : 106,
                              "name"            : "Lewis Hamilton"},
                             {"driverRaceMapId" : 10,
                              "position"        : 4,
                              "driverId"        : 105,
                              "name"            : "George Russell"} ]}')
    WHERE dv.data."_id" = 201;

COMMIT;

-- See the results for the Bahrain Grand Prix.
-- You can use a predicate on the primary key field to query by ID.
--
SELECT json_serialize(data PRETTY)
  FROM race_dv dv WHERE dv.data."_id" = 201;

------------------------------------------------------------------------------
-- Step 7: Update specific fields in the document identified by a predicate --
------------------------------------------------------------------------------

-- Update Bahrain GP name with sponsor information.
-- Here we use json_transform to update specific fields. An alternative
-- approach is to use json_mergepatch, which is standardized (RFC 7386), but is
-- limited to simple object field updates and cannot be used for updating
-- specific array elements. The json_transform function, however, can be used
-- to update specific array elements. Note that the "where" clause can have any
-- valid SQL expression, e.g. equality on primary key, some condition using
-- simplified syntax, or JSON function, such as json_value or json_exists.
--
UPDATE race_dv dv
  SET data = json_transform(data, SET '$.name' = 'Blue Air Bahrain Grand Prix')
    WHERE dv.data.name LIKE 'Bahrain%';

COMMIT;

SELECT json_serialize(data PRETTY)
  FROM race_dv WHERE json_value(data, '$.name') LIKE 'Blue Air Bahrain%';

-- Update Bahrain GP name with sponsor information.
-- Here we use json_mergepatch instead of json_transform to perform the same
-- operation. We also use json_exists in the predicate.
--
UPDATE race_dv dv
  SET data = json_mergepatch(data, '{"name" : "Blue Air Bahrain Grand Prix"}')
    WHERE dv.data.name LIKE 'Blue Air Bahrain%';

COMMIT;

SELECT json_serialize(data PRETTY)
  FROM race_dv WHERE json_value(data, '$.name') LIKE 'Blue Air Bahrain%';


---------------------------------------------------------------
-- Step 8: Re-parenting of sub-objects between two documents --
---------------------------------------------------------------

-- Switch Charles Leclerc's and George Russell's teams.
-- This can be done by updating the Mercedes and Ferrari team_dvs. The
-- documents can be updated by simply sending the new list of drivers for both
-- documents in the input.

-- First, show the team documents.
--
SELECT json_serialize(data PRETTY) FROM team_dv dv
  WHERE dv.data.name LIKE 'Mercedes%';
SELECT json_serialize(data PRETTY) FROM team_dv dv
  WHERE dv.data.name LIKE 'Ferrari%';

-- Then perform the updates.
--
UPDATE team_dv dv
  SET data = ('{_metadata : {"etag" : "855840B905C8CAFA99FB9CBF813992E5"},
                "_id" : 2,
                "name"   : "Mercedes",
                "points" : 40,
                "driver" : [ {"driverId" : 106,
                              "name"     : "Lewis Hamilton",
                              "points"   : 15},
                             {"driverId" : 103,
                              "name"     : "Charles Leclerc",
                              "points"   : 25} ]}')
    WHERE dv.data.name LIKE 'Mercedes%';

UPDATE team_dv dv
  SET data = ('{_metadata : {"etag" : "DA69DD103E8BAE95A0C09811B7EC9628"},
                "_id" : 302,
                "name"   : "Ferrari",
                "points" : 30,
                "driver" : [ {"driverId" : 105,
                              "name"     : "George Russell",
                              "points"   : 12},
                             {"driverId" : 104,
                              "name"     : "Carlos Sainz Jr",
                              "points"   : 18} ]}')
    WHERE dv.data.name LIKE 'Ferrari%';

COMMIT;

-- Then show the team documents after the updates:
--
SELECT json_serialize(data PRETTY) FROM team_dv dv
  WHERE dv.data.name LIKE 'Mercedes%';
 
SELECT json_serialize(data PRETTY) FROM team_dv dv
  WHERE dv.data.name LIKE 'Ferrari%';

-- Then show the driver documents after the updates:
--
SELECT json_serialize(data PRETTY) FROM driver_dv dv
  WHERE dv.data.name LIKE 'Charles Leclerc%';

SELECT json_serialize(data PRETTY) FROM driver_dv dv
  WHERE dv.data.name LIKE 'George Russell%';
  

-------------------------------------------
-- Step 9: Update a non-updateable field --
-------------------------------------------

-- Update team for a driver through driver_dv.
-- This will throw an error.
--
UPDATE driver_dv dv
  SET DATA = ('{_metadata : {"etag" : "FCD4CEC63897F60DEA1EC2F64D3CE53A"},
                "_id" : 103,
                "name" : "Charles Leclerc",
                "points" : 25,
                "teamId" : 2,
                "team" : "Ferrari",
                "race" :
                [
                  {
                    "driverRaceMapId" : 3,
                    "raceId" : 201,
                    "name" : "Blue Air Bahrain Grand Prix",
                    "finalPosition" : 1
                  }
                ]
            }')
  WHERE dv.data."_id" = 103;


----------------------------------
-- Step 10: Delete by predicate --
----------------------------------

-- Delete the race document for Bahrain GP.
-- The underlying rows are deleted from the race and driver_race_map
-- tables, but not from the driver table because it is marked read-only
-- in the view definition. Note that the "where" clause can have any
-- valid SQL expression, e.g. equality on primary key, some condition using
-- simplified syntax, or JSON function, such as json_value or json_exists.
--
DELETE FROM race_dv dv WHERE dv.data."_id" = 201;

SELECT json_serialize(data PRETTY) FROM race_dv;
SELECT json_serialize(data PRETTY) FROM driver_dv;

COMMIT;
