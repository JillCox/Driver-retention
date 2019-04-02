-- termed employees
DROP TABLE #Drivers, #paydetail, #segregate, #step1, #step2, #week
--6 months prior to termination date
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
			END 'count'
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
	DENSE_RANK() OVER (PARTITION BY mpp_id ORDER BY pyh_payperiod DESC) AS ranking

INTO #week
FROM #segregate
GROUP BY mpp_id, Drivertype, pyh_payperiod, mpp_type1
ORDER BY mpp_id, ranking
	

SELECT 
	mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count],
		AVG(weekpay) OVER(PARTITION BY mpp_id) AS avgdriverpay,
		AVG(weekpay) OVER(PARTITION BY Drivertype, mpp_type1) AS groupavgpay
INTO #step1
FROM #week
WHERE weekpay != 50.00
GROUP BY mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count]

SELECT mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count],
	(avgdriverpay - weekpay)  AS driverdiff,
	(groupavgpay - weekpay)  AS groupdiff,
	avgdriverpay, groupavgpay
INTO #step2
FROM #step1

SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	SUM(finesbinary) OVER(PARTITION BY mpp_id) AS 'finescount',
	SUM(detentionbinary) OVER(PARTITION BY mpp_id) AS 'detentioncount',
	SUM(DRVSLYbinary) OVER(PARTITION BY mpp_id) AS 'DRVSLYcount',
	SUM(ENDSEbinary) OVER(PARTITION BY mpp_id) AS 'endorsecount',
	SUM(chargebackbinary) OVER(PARTITION BY mpp_id) AS 'chargebackcount',
	SUM(safetybinary) OVER(PARTITION BY mpp_id) AS 'safetycount',
	SUM(correctionbinary) OVER(PARTITION BY mpp_id) AS 'correctioncount',
	termedbinary,
	SUM([count]) OVER(PARTITION BY mpp_id) AS 'paydetails',
	MIN(driverdiff) OVER(PARTITION BY mpp_id) AS 'mindridiff',
	MAX(driverdiff) OVER(PARTITION BY mpp_id) AS 'maxdridiff',
	MIN(groupdiff) OVER(PARTITION BY mpp_id) AS 'mingroupdiff',
	MAX(groupdiff) OVER(PARTITION BY mpp_id) AS 'maxgroupdiff',
	AVG(groupdiff) OVER(PARTITION BY mpp_id) AS 'avggroupdiff',
	avgdriverpay,
	groupavgpay
INTO #step3
FROM #step2
GROUP BY mpp_id, Drivertype, mpp_type1, avgdriverpay, groupavgpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], driverdiff, groupdiff
	 

	SELECT DISTINCT DriverType, mpp_type1, count(finescount) 'FINEScount', avg(finescount) 'FINESavg', count(detentioncount) 'DETcount', avg(detentioncount) 'DETavg', count(DRVSLYcount) 'DRVSLYcount', avg(DRVSLYcount) 'DRVSLYavg', 
	count(endorsecount) 'endorsecount', avg(endorsecount) 'endorseavg', count(chargebackcount) 'chargebackcount', avg(chargebackcount) 'chargebackavg', count(safetycount) 'safetycount', avg(safetycount) 'safetyavg', 
	count(correctioncount) 'correctioncount', avg(correctioncount) 'correctionavg', count(paydetails) 'paycount', avg(paydetails) 'payavg', count(mindridiff) 'mindricount', avg(mindridiff) 'mindriavg',
	count(maxdridiff) 'maxdricount', avg(maxdridiff) 'maxdiravg', count(mingroupdiff) 'mingrcount', avg(mingroupdiff) 'mingravg', count(maxgroupdiff) 'maxgrcount', avg(maxgroupdiff) 'maxgravg', count(avggroupdiff) 'avggrcount', 
	avg(avggroupdiff) 'avggravg', count(avgdriverpay) 'avgdrpaycount', avg(avgdriverpay) 'avgdripayavg', count(groupavgpay) 'groupavgpaycount', avg(groupavgpay) 'groupavgpayavg'
	FROM #step3
	GROUP BY Drivertype, mpp_type1




DROP TABLE #Drivers2, #paydetail2, #segregate2, #step12, #step22, #week2

-- now calculate drivers who stayed
--DROP TABLE #Drivers2
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

--DROP TABLE #paydetail

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
--DROP TABLE #segregate
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
			END 'count'
 INTO #segregate2
 FROM #paydetail2
 GROUP BY mpp_id, pyh_payperiod, mpp_terminationdt, StartDate, pyt_itemcode, mpp_state, mpp_type1, mpp_type2

 --DROP TABLE #week

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
		THEN 0
		ELSE 0
		END 'termedbinary',
	SUM(count) 'count',
	DENSE_RANK() OVER (PARTITION BY mpp_id ORDER BY pyh_payperiod DESC) AS ranking

INTO #week2
FROM #segregate2
GROUP BY mpp_id, Drivertype, pyh_payperiod, mpp_type1
ORDER BY mpp_id, ranking
	
--DROP TABLE #step1
SELECT 
	mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count],
		AVG(weekpay) OVER(PARTITION BY mpp_id) AS avgdriverpay,
		AVG(weekpay) OVER(PARTITION BY Drivertype, mpp_type1) AS groupavgpay
INTO #step12
FROM #week2
WHERE weekpay != 50.00
GROUP BY mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count]

SELECT mpp_id, Drivertype, mpp_type1, weekpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count],
	(avgdriverpay - weekpay)  AS driverdiff,
	(groupavgpay - weekpay)  AS groupdiff,
	avgdriverpay, groupavgpay
INTO #step22
FROM #step12

--DROP TABLE #step3
SELECT DISTINCT mpp_id, Drivertype, mpp_type1,
	cast(SUM(finesbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'finescount',
	cast(SUM(detentionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'detentioncount',
	cast(SUM(DRVSLYbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'DRVSLYcount',
	cast(SUM(ENDSEbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'endorsecount',
	cast(SUM(chargebackbinary) OVER(PARTITION BY mpp_id) as decimal(10,2))AS 'chargebackcount',
	cast(SUM(safetybinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'safetycount',
	cast(SUM(correctionbinary) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'correctioncount',
	termedbinary,
	cast(SUM([count]) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'paydetails',
	cast(MIN(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'mindridiff',
	cast(MAX(driverdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'maxdridiff',
	cast(MIN(groupdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'mingroupdiff',
	cast(MAX(groupdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'maxgroupdiff',
	cast(AVG(groupdiff) OVER(PARTITION BY mpp_id) as decimal(10,2)) AS 'avggroupdiff',
	avgdriverpay,
	groupavgpay
INTO #step3
FROM #step2
GROUP BY mpp_id, Drivertype, mpp_type1, avgdriverpay, groupavgpay, finesbinary, detentionbinary, DRVSLYbinary, ENDSEbinary, chargebackbinary, safetybinary, correctionbinary, termedbinary, [count], driverdiff, groupdiff

	SELECT DISTINCT DriverType, mpp_type1,  avg(finescount) 'FINESavg',  avg(detentioncount) 'DETavg',  avg(DRVSLYcount) 'DRVSLYavg', 
	 avg(endorsecount) 'endorseavg',  avg(chargebackcount) 'chargebackavg', avg(safetycount) 'safetyavg', 
	 avg(correctioncount) 'correctionavg',  avg(paydetails) 'payavg',  avg(mindridiff) 'mindriavg',
	 avg(maxdridiff) 'maxdiravg',  avg(mingroupdiff) 'mingravg',  avg(maxgroupdiff) 'maxgravg',  
	avg(avggroupdiff) 'avggravg', avg(avgdriverpay) 'avgdripayavg',  avg(groupavgpay) 'groupavgpayavg'
	FROM #step3
	GROUP BY Drivertype, mpp_type1
	ORDER BY  mpp_type1


 	SELECT DISTINCT DriverType, mpp_type1, count(finescount) 'FINEScount', avg(finescount)  'FINESavg', count(detentioncount) 'DETcount', avg(detentioncount)  'DETavg', count(DRVSLYcount) 'DRVSLYcount', avg(DRVSLYcount) 'DRVSLYavg', 
	count(endorsecount) 'endorsecount', avg(endorsecount) 'endorseavg', count(chargebackcount) 'chargebackcount', avg(chargebackcount) 'chargebackavg', count(safetycount) 'safetycount', avg(safetycount) 'safetyavg', 
	count(correctioncount) 'correctioncount', avg(correctioncount) 'correctionavg', count(paydetails) 'paycount', avg(paydetails) 'payavg', count(mindridiff) 'mindricount', avg(mindridiff) 'mindriavg',
	count(maxdridiff) 'maxdricount', avg(maxdridiff) 'maxdiravg', count(mingroupdiff) 'mingrcount', avg(mingroupdiff) 'mingravg', count(maxgroupdiff) 'maxgrcount', avg(maxgroupdiff) 'maxgravg', count(avggroupdiff) 'avggrcount', 
	avg(avggroupdiff) 'avggravg', count(avgdriverpay) 'avgdrpaycount', avg(avgdriverpay) 'avgdripayavg', count(groupavgpay) 'groupavgpaycount', avg(groupavgpay) 'groupavgpayavg'
	FROM #step33
	GROUP BY Drivertype, mpp_type1
