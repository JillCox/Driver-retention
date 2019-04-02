-- termed employees--
---------------------


DROP TABLE #Drivers, #paydetail, #segregate, #step1, #step2, #week
-- pull in pro drivers 6 months prior to termination date
SELECT    
   mpp_id
  ,DATEADD(MONTH, -6, mpp_terminationdt) 'StartDate'
  ,mpp_terminationdt
  ,mpp_state
  ,mpp_type2
  ,mpp_type1
INTO 
   #Drivers
FROM  tmw_live.dbo.manpowerprofile
WHERE mpp_status = 'OUT'
      AND mpp_terminationdt >= '2018-01-01';
-- pay details for the last 6 months one week at a time
SELECT   
   mpp_id, StartDate, mpp_terminationdt, mpp_state, mpp_type2, mpp_type1, lgh_number, mov_number, pyt_itemcode, pyd_description, pyd_rate, pyd_amount, pyh_payperiod, pyd_sequence, pyd_branch
INTO #paydetail
FROM TMW_LIVE.dbo.paydetail
JOIN #Drivers ON asgn_type = 'DRV'
                 AND asgn_id = mpp_id
                 AND pyh_payperiod >= StartDate
                 AND pyh_payperiod < mpp_terminationdt
ORDER BY mpp_id

--minimize and divide into groups

SELECT DISTINCT mpp_id, pyh_payperiod, mpp_terminationdt, StartDate, mpp_state, mpp_type1,
	CASE WHEN mpp_type2 in ('DRV180', 'DRV90', 'TD1', 'TD2', 'VET22', 'FPST', 'ST1', 'VET11', 'STUD', 'ST2-3', 'FPEX')
		THEN 'Team Driver_Student'
		WHEN mpp_type2 in ('OO', 'OOTETR')
		THEN 'Owner Operator'
		WHEN mpp_type2 in ('DRVENG', 'LOCAL', 'LOCCAN')
		THEN 'DRVENG'
		WHEN mpp_type2 in ('TR410', 'TR2', 'TR3', 'TR2FL', 'TR4', 'TR410', 'TRAIN', 'TR404', 'TR3FL', 'TR40FL', 'TR4FL')
		THEN 'Trainer'
		WHEN mpp_type2 in ('OTR', 'VET33', 'SLHMTK', 'SRTLOY', 'SR2008', 'S8HMTK', 'UNK', 'SRO8HM', 'SRTREG')
		THEN 'OTR'
		ELSE 'OTR'
	END 'Drivertype',
		CASE WHEN pyt_itemcode = 'FINES' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'FINES',
		CASE WHEN pyt_itemcode = 'MILES' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'MILES',
		CASE WHEN pyt_itemcode = 'PDIEM' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'PDIEM',
		CASE WHEN pyt_itemcode in ('LDMNY', 'ADV.PA') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'personaladv',
		CASE WHEN pyt_itemcode in ('DETPAY', 'STOPS') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'Detention',
		CASE WHEN pyt_itemcode = 'DRVSLY' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'DRVSLY',
		CASE WHEN pyt_itemcode in ('ENDRSE', 'ENDRS-')
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'ENDSE',
		CASE WHEN pyt_itemcode in ('TRAVEL', 'HOTEL', 'CHAIN', 'SCALE', 'OIL', 'FAX', 'PALLET', 'PARKING', 'REPAIR', 'ADV.MO', 'ADV.LU', 'ADV.HZ', 'ORTRAV', 'HOLDAY') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'chargeback',
		CASE WHEN pyt_itemcode = 'BNSSAF' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'safetybonus',
		CASE WHEN pyt_itemcode in ('HAZRET', 'HAZMTM', 'LOCAL') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'calcrev',
		CASE WHEN pyt_itemcode = 'GRNT' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'correction',
		CASE WHEN pyt_itemcode not in ('GRNT', 'HAZRET', 'HAZMTM', 'LOCAL', 'BNSSAF', 'TRAVEL', 'HOTEL', 'CHAIN', 'SCALE', 'OIL', 'FAX', 'PALLET', 'PARKING', 'REPAIR', 'ADV.MO', 'ADV.LU', 'ADV.HZ', 'ORTRAV', 'HOLDAY', 'ENDRSE', 'ENDRS-', 'DRVSLY', 
										'DETPAY', 'STOPS', 'LDMNY', 'ADV.PA', 'PDIEM', 'MILES', 'FINES') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'other',
		CASE WHEN pyt_itemcode not in ('PDIEM', 'MILES')
			THEN count(pyd_amount) 
			ELSE 0
			END 'count',
		CASE WHEN pyt_itemcode = 'HMETME'
			THEN count(pyd_amount)
			ELSE 0
			END 'latehome',
		CASE WHEN pyt_itemcode = 'LAY'
			THEN count(pyd_amount)
			ELSE 0
			END 'layover'
 INTO #segregate
 FROM #paydetail
 GROUP BY mpp_id, pyh_payperiod, mpp_terminationdt, StartDate, pyt_itemcode, mpp_state, mpp_type1, mpp_type2

 SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	(SUM(FINES)+ SUM(MILES)+ SUM(PDIEM) + SUM(personaladv) + SUM(Detention) + SUM(DRVSLY) + SUM(ENDSE) + SUM(chargeback) + SUM(safetybonus) + SUM(calcrev) + SUM(correction) + SUM(other)) 'weekpay',
	CASE WHEN SUM(FINES) < 0 THEN 1
		ELSE 0
		END 'finesbinary',
	CASE WHEN SUM(Detention) >0 THEN 1
		ELSE 0
		END 'detentionbinary',
	CASE WHEN SUM(DRVSLY) >0 THEN 1
		ELSE 0
		END 'DRVSLYbinary',
	CASE WHEN SUM(ENDSE) >0 THEN 1
		ELSE 0
		END 'ENDSEbinary',
	CASE WHEN SUM(chargeback) >0 THEN 1
		ELSE 0
		END 'chargebackbinary',
	CASE WHEN SUM(safetybonus) >0 THEN 1
		ELSE 0
		END 'safetybinary',
	CASE WHEN SUM(correction) >0 THEN 1
		ELSE 0
		END 'correctionbinary',
	CASE WHEN (SUM(FINES)+ SUM(MILES)+ SUM(PDIEM) + SUM(personaladv) + SUM(Detention) + SUM(DRVSLY) + SUM(ENDSE) + SUM(chargeback) + SUM(safetybonus) + SUM(calcrev) + SUM(correction) + SUM(other)) != 0
		THEN 1
		ELSE 1
		END 'termedbinary',
	SUM(count) 'count',
	CASE WHEN SUM(latehome) >0 THEN 1
		ELSE 0
		END 'latehomebinary',
	CASE WHEN SUM(layover) >0 THEN 1
		ELSE 0
		END 'layoverbinary',
	DENSE_RANK() OVER (PARTITION BY mpp_id ORDER BY pyh_payperiod DESC) AS ranking

INTO #week
FROM #segregate
GROUP BY mpp_id, Drivertype, pyh_payperiod, mpp_type1
ORDER BY mpp_id, ranking


SELECT 
	mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], latehomebinary, layoverbinary,
		AVG(weekpay) OVER(PARTITION BY mpp_id) AS avgdriverpay,
		AVG(weekpay) OVER(PARTITION BY Drivertype, mpp_type1) AS groupavgpay
INTO #step1
FROM #week
WHERE weekpay >200.00 
--and mpp_id = 'CVEN'
GROUP BY mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count],latehomebinary, layoverbinary

SELECT mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], latehomebinary, layoverbinary,
	(avgdriverpay - weekpay)  AS driverdiff,
	avgdriverpay, groupavgpay
INTO #step2
FROM #step1

SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	cast(SUM(finesbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'finescount',
	cast(SUM(detentionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'detentioncount',
	cast(SUM(DRVSLYbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'DRVSLYcount',
	cast(SUM(ENDSEbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'endorsecount',
	cast(SUM(chargebackbinary) OVER(PARTITION BY mpp_id) as decimal(10,2))AS 'chargebackcount',
	cast(SUM(safetybinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'safetycount',
	cast(SUM(correctionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'correctioncount',
	cast(SUM(latehomebinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'latehomecount',
	cast(SUM(layoverbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'layoverbinary',
	termedbinary,
	cast(SUM([count]) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'paydetails',
	cast(MIN(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'mindridiff',
	cast(MAX(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'maxdridiff',
	avgdriverpay,
	groupavgpay,
	0 'stayed'
INTO #step3
FROM #step2
GROUP BY mpp_id, Drivertype, mpp_type1, avgdriverpay, groupavgpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], latehomebinary, layoverbinary, driverdiff
-- DROP TABLE #step3
/*	SELECT DISTINCT DriverType, mpp_type1,  avg(finescount) 'FINESavg',  avg(detentioncount) 'DETavg',  avg(DRVSLYcount) 'DRVSLYavg', 
	 avg(endorsecount) 'endorseavg',  avg(chargebackcount) 'chargebackavg',  avg(safetycount) 'safetyavg', 
	 avg(correctioncount) 'correctionavg', avg(paydetails) 'payavg', avg(mindridiff) 'mindriavg',
	avg(maxdridiff) 'maxdiravg',  avg(avgdriverpay) 'avgdripayavg',  avg(groupavgpay) 'groupavgpayavg'
	FROM #step3
	GROUP BY Drivertype, mpp_type1 */


DROP TABLE #Drivers2, #paydetail2, #segregate2, #step12, #step22, #step32 ,#week2

-- Drivers who stayed
----------------------------------
--6 months prior to termination date
SELECT    
   mpp_id
  ,DATEADD(MONTH, -6, GETDATE()) 'StartDate'
  ,mpp_terminationdt
  ,mpp_state
  ,mpp_type2
  ,mpp_type1
INTO 
   #Drivers2
FROM  tmw_live.dbo.manpowerprofile
WHERE  mpp_terminationdt = '2049-12-31 23:59:00.000';

SELECT   
   mpp_id, StartDate, mpp_terminationdt, mpp_state, mpp_type2, mpp_type1, lgh_number, mov_number, pyt_itemcode, pyd_description, pyd_rate, pyd_amount, pyh_payperiod, pyd_sequence, pyd_branch
INTO #paydetail2
FROM TMW_LIVE.dbo.paydetail
JOIN #Drivers2 ON asgn_type = 'DRV'
                 AND asgn_id = mpp_id
                 AND pyh_payperiod >= StartDate
                 AND pyh_payperiod < mpp_terminationdt
ORDER BY mpp_id

--minimize and divide into groups

SELECT DISTINCT mpp_id, pyh_payperiod, mpp_terminationdt, StartDate, mpp_state, mpp_type1,
	CASE WHEN mpp_type2 in ('DRV180', 'DRV90', 'TD1', 'TD2', 'VET22', 'FPST', 'ST1', 'VET11', 'STUD', 'ST2-3', 'FPEX')
		THEN 'Team Driver_Student'
		WHEN mpp_type2 in ('OO', 'OOTETR')
		THEN 'Owner Operator'
		WHEN mpp_type2 in ('DRVENG', 'LOCAL', 'LOCCAN')
		THEN 'DRVENG'
		WHEN mpp_type2 in ('TR410', 'TR2', 'TR3', 'TR2FL', 'TR4', 'TR410', 'TRAIN', 'TR404', 'TR3FL', 'TR40FL', 'TR4FL')
		THEN 'Trainer'
		WHEN mpp_type2 in ('OTR', 'VET33', 'SLHMTK', 'SRTLOY', 'SR2008', 'S8HMTK', 'UNK', 'SRO8HM', 'SRTREG')
		THEN 'OTR'
		ELSE 'OTR'
	END 'Drivertype',
		CASE WHEN pyt_itemcode = 'FINES' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'FINES',
		CASE WHEN pyt_itemcode = 'MILES' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'MILES',
		CASE WHEN pyt_itemcode = 'PDIEM' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'PDIEM',
		CASE WHEN pyt_itemcode in ('LDMNY', 'ADV.PA') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'personaladv',
		CASE WHEN pyt_itemcode in ('DETPAY', 'STOPS') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'Detention',
		CASE WHEN pyt_itemcode = 'DRVSLY' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'DRVSLY',
		CASE WHEN pyt_itemcode in ('ENDRSE', 'ENDRS-')
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'ENDSE',
		CASE WHEN pyt_itemcode in ('TRAVEL', 'HOTEL', 'CHAIN', 'SCALE', 'OIL', 'FAX', 'PALLET', 'PARKING', 'REPAIR', 'ADV.MO', 'ADV.LU', 'ADV.HZ', 'ORTRAV', 'HOLDAY') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'chargeback',
		CASE WHEN pyt_itemcode = 'BNSSAF' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'safetybonus',
		CASE WHEN pyt_itemcode in ('HAZRET', 'HAZMTM', 'LOCAL') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'calcrev',
		CASE WHEN pyt_itemcode = 'GRNT' 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'correction',
		CASE WHEN pyt_itemcode not in ('GRNT', 'HAZRET', 'HAZMTM', 'LOCAL', 'BNSSAF', 'TRAVEL', 'HOTEL', 'CHAIN', 'SCALE', 'OIL', 'FAX', 'PALLET', 'PARKING', 'REPAIR', 'ADV.MO', 'ADV.LU', 'ADV.HZ', 'ORTRAV', 'HOLDAY', 'ENDRSE', 'ENDRS-', 'DRVSLY', 
										'DETPAY', 'STOPS', 'LDMNY', 'ADV.PA', 'PDIEM', 'MILES', 'FINES') 
			THEN SUM(pyd_amount) 
			ELSE 0
			END 'other',
		CASE WHEN pyt_itemcode not in ('PDIEM', 'MILES')
			THEN count(pyd_amount) 
			ELSE 0
			END 'count',
		CASE WHEN pyt_itemcode = 'HMETME'
			THEN count(pyd_amount)
			ELSE 0
			END 'latehome',
		CASE WHEN pyt_itemcode = 'LAY'
			THEN count(pyd_amount)
			ELSE 0
			END 'layover'
 INTO #segregate2
 FROM #paydetail2
 GROUP BY mpp_id, pyh_payperiod, mpp_terminationdt, StartDate, pyt_itemcode, mpp_state, mpp_type1, mpp_type2

 SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	(SUM(FINES)+ SUM(MILES)+ SUM(PDIEM) + SUM(personaladv) + SUM(Detention) + SUM(DRVSLY) + SUM(ENDSE) + SUM(chargeback) + SUM(safetybonus) + SUM(calcrev) + SUM(correction) + SUM(other)) 'weekpay',
	CASE WHEN SUM(FINES) < 0 THEN 1
		ELSE 0
		END 'finesbinary',
	CASE WHEN SUM(Detention) >0 THEN 1
		ELSE 0
		END 'detentionbinary',
	CASE WHEN SUM(DRVSLY) >0 THEN 1
		ELSE 0
		END 'DRVSLYbinary',
	CASE WHEN SUM(ENDSE) >0 THEN 1
		ELSE 0
		END 'ENDSEbinary',
	CASE WHEN SUM(chargeback) >0 THEN 1
		ELSE 0
		END 'chargebackbinary',
	CASE WHEN SUM(safetybonus) >0 THEN 1
		ELSE 0
		END 'safetybinary',
	CASE WHEN SUM(correction) >0 THEN 1
		ELSE 0
		END 'correctionbinary',
	CASE WHEN (SUM(FINES)+ SUM(MILES)+ SUM(PDIEM) + SUM(personaladv) + SUM(Detention) + SUM(DRVSLY) + SUM(ENDSE) + SUM(chargeback) + SUM(safetybonus) + SUM(calcrev) + SUM(correction) + SUM(other)) != 0
		THEN 1
		ELSE 1
		END 'termedbinary',
	SUM(count) 'count',
		CASE WHEN SUM(latehome) >0 THEN 1
		ELSE 0
		END 'latehomebinary',
	CASE WHEN SUM(layover) >0 THEN 1
		ELSE 0
		END 'layoverbinary',
	DENSE_RANK() OVER (PARTITION BY mpp_id ORDER BY pyh_payperiod DESC) AS ranking

INTO #week2
FROM #segregate2
GROUP BY mpp_id, Drivertype, pyh_payperiod, mpp_type1
ORDER BY mpp_id, ranking


SELECT 
	mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, 
	[count], latehomebinary, layoverbinary,
		AVG(weekpay) OVER(PARTITION BY mpp_id) AS avgdriverpay,
		AVG(weekpay) OVER(PARTITION BY Drivertype, mpp_type1) AS groupavgpay
INTO #step12
FROM #week2
WHERE weekpay >200.00 
GROUP BY mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], latehomebinary, layoverbinary

SELECT mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count] , latehomebinary, layoverbinary,
	(avgdriverpay - weekpay)  AS driverdiff,
	avgdriverpay, groupavgpay
INTO #step22
FROM #step12

SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	cast(SUM(finesbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'finescount',
	cast(SUM(detentionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'detentioncount',
	cast(SUM(DRVSLYbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'DRVSLYcount',
	cast(SUM(ENDSEbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'endorsecount',
	cast(SUM(chargebackbinary) OVER(PARTITION BY mpp_id) as decimal(10,2))AS 'chargebackcount',
	cast(SUM(safetybinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'safetycount',
	cast(SUM(correctionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'correctioncount',
	cast(SUM(latehomebinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'latehomebinary',
	cast(SUM(layoverbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'layoverbinary',
	termedbinary,
	cast(SUM([count]) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'paydetails',
	cast(MIN(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'mindridiff',
	cast(MAX(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'maxdridiff',
	avgdriverpay,
	groupavgpay,
		1 'stayed'
INTO #step32
FROM #step22
GROUP BY mpp_id, Drivertype, mpp_type1, avgdriverpay, groupavgpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, 
correctionbinary, termedbinary, [count], latehomebinary, layoverbinary, driverdiff
	 
/*	SELECT DISTINCT DriverType, mpp_type1,  avg(finescount) 'FINESavg',  avg(detentioncount) 'DETavg', avg(DRVSLYcount) 'DRVSLYavg', 
	 avg(endorsecount) 'endorseavg',  avg(chargebackcount) 'chargebackavg',  avg(safetycount) 'safetyavg', 
	 avg(correctioncount) 'correctionavg',  avg(paydetails) 'payavg',  avg(mindridiff) 'mindriavg',
	avg(maxdridiff) 'maxdiravg',  avg(avgdriverpay) 'avgdripayavg',  avg(groupavgpay) 'groupavgpayavg'
	FROM #step32
	GROUP BY Drivertype, mpp_type1 */

--put both tables together to add characteristics to the data.
SELECT * INTO #all
FROM
(SELECT * FROM #step3
UNION ALL
SELECT * FROM #step32) a
--SELECT * FROM #all
-- DROP TABLE #model
SELECT a.mpp_id, Drivertype, a.mpp_type1, finescount, detentioncount, DRVSLYcount, endorsecount, chargebackcount, safetycount, correctioncount, latehomecount, layoverbinary,
 ISNULL(p.mpp_firstname + ' ' + p.mpp_lastname, 'UNKNOWN') 'DriverName',paydetails, avgdriverpay, AVG(avgdriverpay) OVER(PARTITION BY Drivertype, a.mpp_type1) AS groupavgpay, stayed
INTO #model
FROM #all a
LEFT JOIN tmw_live.dbo.manpowerprofile  p (NOLOCK) on a.mpp_id = p.mpp_id
WHERE a.mpp_type1 = 'CVEN'
--SELECT * FROM #model
-------------------------------------------------------------------------------------------------------------------
--add safety measures, seniority, days to accident, phone number, and name
-- add filter on the join not in the where clause
SELECT DISTINCT a.mpp_id, a.Drivertype, 
a.DriverName, 
p.mpp_currentphone as 'phone',
finescount, detentioncount, DRVSLYcount, count(m.EventTrigger) as Critical,
DATEDIFF(MONTH, mpp_hiredate, GETDATE()) 'seniority', 
endorsecount, chargebackcount, safetycount, correctioncount, latehomecount, layoverbinary, paydetails, avgdriverpay, groupavgpay, stayed
,ISNULL(MIN(DATEDIFF(DAY, e.REPORT_DT, GETDATE())) OVER(PARTITION BY a.mpp_id), 10000) as daystoacc
,ISNULL(sum(cast(vio.ViolationValue as float)), 0) as CSA,
ISNULL(count(cast(vio.ViolationValue as float)), 0) as Violations
INTO #added
FROM #model a
LEFT JOIN Omnitracs.dbo.MECEREvents m (NOLOCK) on a.mpp_id = m.DriverID and EventTrigger NOT LIKE '%Lane_Departure%'
LEFT JOIN tmw_live.dbo.manpowerprofile  p (NOLOCK) on a.mpp_id = p.mpp_id
LEFT JOIN STRACS.dbo.CT_Occur_Extract e (NOLOCK) on a.mpp_id = e.MISC2_NM and  SPECIAL23= 'Chargeable'
LEFT JOIN ITQ.dbo.DriverVioHistory vio (NOLOCK) on a.DriverName = vio.DriverName
GROUP BY a.mpp_id, a.Drivertype, a.finescount, a.detentioncount, a.DRVSLYcount, a.endorsecount, a.chargebackcount, a.safetycount, a.correctioncount, a.paydetails, 
a.avgdriverpay, a.groupavgpay, a.stayed, p.mpp_hiredate, e.REPORT_DT, 
p.mpp_firstname, p.mpp_lastname, p.mpp_currentphone, a.DriverName, a.latehomecount, a.layoverbinary
ORDER BY seniority desc
-- DROP TABLE #added
-- add in teaming information. Data is completed in R. The R data populates a historic teaming table in CIP
-- DROP TABLE #team
SELECT a.mpp_id, a.Drivertype, a.DriverName, a.phone, a.Critical, a.seniority, a.endorsecount, a.chargebackcount, a.safetycount,
a.correctioncount, a.latehomecount, a.layoverbinary, a.paydetails, a.avgdriverpay, a.groupavgpay, a.stayed, a.daystoacc, 
	CASE WHEN a.CSA > 0 and a.seniority >0
		THEN (a.CSA/a.seniority)
		ELSE 0
		END 'CSA_month',
	CASE WHEN a.Violations >0 and a.seniority >0
		THEN (a.Violations/a.seniority)
		ELSE 0
		END 'Vio_month',
t.team_binary, t.leg_count, t.rownames,
DENSE_RANK() OVER (PARTITION BY mpp_id ORDER BY rownames DESC) AS ranking
INTO #team
FROM #added a
LEFT JOIN [CIP].[cven\coxjil].[teaming] t on a.mpp_id = t.DriverID
WHERE Drivertype not in ('Trainer', 'DRVENG', 'Owner Operator')
--DROP TABLE #team
-- teaming metrics
SELECT DISTINCT mpp_id, Drivertype, DriverName, phone, Critical,
 CASE WHEN seniority <= 6
	  THEN '6 months'
	  WHEN seniority >6 and seniority <= 12
	  THEN '6m- 1 year'
	  WHEN seniority >12 and seniority <= 24
	  THEN '1-2 years'
	  WHEN seniority >24 and seniority <= 60
	  THEN '2-5'
	  WHEN seniority >60
	  THEN '5+'
	  ELSE 'UNKNOWN'
	  END 'seniority', 
 endorsecount, chargebackcount, safetycount, correctioncount, latehomecount, layoverbinary, paydetails,
avgdriverpay, groupavgpay, stayed, daystoacc, CSA_month, Vio_month,
count(team_binary) OVER(PARTITION BY mpp_id) as numteams,
SUM(team_binary) OVER(PARTITION BY mpp_id) as partsolo,
AVG(leg_count) OVER(PARTITION BY mpp_id) as avgtenure,
ISNULL(STDEV(leg_count) OVER(PARTITION BY mpp_id), 0) as stdevtenure,
MAX(ranking) OVER(PARTITION BY mpp_id) as maxrank
INTO #teaming
FROM #team t
--DROP TABLE #teaming
--select * from #teaming
--create binary 
SELECT * FROM #teaming t
JOIN [CIP].[dbo].['ETO Expirations$'] e on t.mpp_id = e.DriverID



-- summarize results
	SELECT DISTINCT stayed, Drivertype, seniority, avg(Critical) 'Critical',  avg(endorsecount) 'endorse', avg(chargebackcount) 'chargeback',
	avg([safetycount]) 'safety', avg(correctioncount) 'correction', avg(latehomecount) 'latehome', avg(layoverbinary) 'layover', avg(paydetails) 'paydetails',
	avg(groupavgpay) 'avgpay', count(*) 'count', avg(CSA_month) 'CSA', avg(Vio_month) 'Vio', avg(numteams) 'numteams', avg((numteams - partsolo)) 'solo', avg(avgtenure) 'avgtenure',
	avg(stdevtenure) 'stdevtenure'
	FROM #teaming
	GROUP BY stayed, Drivertype, seniority
	ORDER BY Drivertype, seniority

/*	SELECT DISTINCT DriverType, mpp_type1,  avg(finescount) 'FINESavg',  avg(detentioncount) 'DETavg',  avg(DRVSLYcount) 'DRVSLYavg', 
	 avg(endorsecount) 'endorseavg',  avg(chargebackcount) 'chargebackavg',  avg(safetycount) 'safetyavg', 
	 avg(correctioncount) 'correctionavg', avg(paydetails) 'payavg', avg(mindridiff) 'mindriavg',
	avg(maxdridiff) 'maxdiravg',  avg(avgdriverpay) 'avgdripayavg',  avg(groupavgpay) 'groupavgpayavg'
	FROM #step3
	GROUP BY Drivertype, mpp_type1 */
-- add home time

