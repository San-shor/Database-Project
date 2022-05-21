
SET VERIFY OFF;
SET SERVEROUTPUT ON;

-- 1
CREATE OR REPLACE VIEW DEATH_PREDICT AS (SELECT * from (SELECT 
(select sum(first_dose.no_vaccine) from first_dose where first_dose.day <= covid.day) 
As NO_FIRST,
 COALESCE((select sum(second_dose.no_vaccine) from second_dose 
where second_dose.day <= covid.day),0) 
AS NO_second, death FROM covid) T
where T.no_first is not null );
/

SELECT * FROM DEATH_PREDICT;
-- 2
CREATE OR REPLACE VIEW TRAIN_DATA_COVID AS SELECT * FROM DEATH_PREDICT SAMPLE (70) SEED (1);
CREATE OR REPLACE VIEW TEST_DATA_COVID AS SELECT * FROM DEATH_PREDICT MINUS SELECT * FROM TRAIN_DATA_COVID;
/
SELECT *FROM TRAIN_DATA_COVID;
SELECT *FROM TEST_DATA_COVID;
-- 3
BEGIN DBMS_DATA_MINING.DROP_MODEL('LINEAR_REGRESSION');
EXCEPTION 
    WHEN OTHERS THEN 
        NULL; 
END;
/

-- 4
DECLARE
    v_setlst DBMS_DATA_MINING.SETTING_LIST;
    
BEGIN
    v_setlst('PREP_AUTO') := 'ON';
    v_setlst('ALGO_NAME') := 'ALGO_GENERALIZED_LINEAR_MODEL';
    v_setlst('GLMS_DIAGNOSTICS_TABLE_NAME') := 'GLMR_SH_SAMPLE_DIAG_LINEAR';
    v_setlst('GLMS_RIDGE_REGRESSION') := 'GLMS_RIDGE_REG_ENABLE';
    
    
    DBMS_DATA_MINING.CREATE_MODEL2(
        MODEL_NAME          => 'LINEAR_REGRESSION',
        MINING_FUNCTION     => 'REGRESSION',
        DATA_QUERY          => 'SELECT * FROM TRAIN_DATA_COVID',
        SET_LIST            => v_setlst,
        CASE_ID_COLUMN_NAME => 'NO_FIRST',
        TARGET_COLUMN_NAME  => 'DEATH'
    );
END;
/

-- 5
CREATE OR REPLACE VIEW DEATH_prediction_linear AS
    SELECT NO_FIRST,NO_SECOND, round(PREDICTION(LINEAR_REGRESSION USING *)) PREDICTION_DEATH, DEATH ACTUAL_DEATH
    FROM TEST_DATA_COVID;
/

-- 6
DECLARE 
CURSOR c1 IS 
        SELECT * 
        FROM DEATH_prediction_linear;
      
    
BEGIN
 FOR record IN c1
    LOOP
        dbms_output.put_line(record.NO_FIRST || ':' || record.NO_SECOND || '---' || record.PREDICTION_DEATH
        ||'---' || record.ACTUAL_DEATH);
            
    END LOOP;
  
END;
/
