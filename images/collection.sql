SELECT `a`.*
FROM
  (SELECT a.idapplication AS application_id,
          vp.vehicle_id,
          ap.idapplicant,
          CONCAT(ap.first_name, ' ', ap.last_name) AS applicant_full_name,
          llc.loan_number,
          fln.cyberridge_loan_number,
          `cc`.`days_delinquent`,
          `cc`.`total_past_due_balance` AS `dollars_delinquent`,
          `cc`.`contract_date`,
          `cc`.`current_principal_balance` AS `active_balance`,
          `cc`.`payment_type`,
          `cc`.`principal_balance`,
          `cata`.`collector_id`,
          `cata`.`collection_loan_group_id`,
          `clg`.`group_name` AS `collection_group_name`,
          `u`.`nickname` AS `collector_nickname`,
          `cl`.`callstatus_id`,
          `cl`.`promise_to_pay_yesno`,
          `ptp`.`promise_to_pay_amount`,
          DATE_FORMAT(`ptp`.`promise_to_pay_date`, '%m/%d/%Y') AS `promise_to_pay_date`,
          `dr`.`iddelinquency_reason` AS `delinquency_reason_id`,
          `dr`.`description` AS `delinquency_reason_name`,
          `drb`.`iddelinquency_reason_bucket` AS `delinquency_bucket_id`,
          `drb`.`description` AS `delinquency_reason_bucket`,
          DATE_FORMAT(`csc`.`scheduled_for_date`, '%m/%d/%Y %H:%i:%s') AS `schedule_date_time`,
          `clcalls`.`attempted_calls`,
          `clcalls`.`successful_calls`,
          DATE_FORMAT(`clcalls`.`call_date_time`, '%m/%d/%Y %H:%i:%s') AS `last_call_attempt`,
          `ccoll`.`user_id`,
          `vmnk`.`vin`,
          CASE
              WHEN valuation_mmr IS NOT NULL
                   AND valuation_mmr != 0 THEN CAST((amount_financed-IFNULL(vp.vsi_fee,0)-IFNULL(s.discount,0))/valuation_mmr AS DECIMAL(6,2))
              WHEN (valuation_mmr IS NULL
                    OR valuation_mmr = 0)
                   AND a.idapplication < 11553 THEN CAST((amount_financed-IFNULL(vp.vsi_fee,0)-IFNULL(s.discount,0))/vehicle_valuation_fhf_old AS DECIMAL (6,2))
              WHEN (valuation_mmr IS NULL
                    OR valuation_mmr = 0)
                   AND a.idapplication >= 11553 THEN CAST((amount_financed-IFNULL(vp.vsi_fee,0)-IFNULL(s.discount,0))/vehicle_value_average_trade_in AS DECIMAL (6,2))
          END AS loan_to_value ,
          CASE
              WHEN valuation_mmr IS NOT NULL
                   AND valuation_mmr != 0 THEN CAST(amount_financed + 1106 + 2100 - valuation_mmr*POW(1-0.0181,(DATEDIFF(CURDATE(),afs.contract_date)/30 + 2))*0.961 AS DECIMAL (8,2))
              WHEN (valuation_mmr IS NULL
                    OR valuation_mmr = 0)
                   AND a.idapplication < 11553 THEN CAST(amount_financed + 1106 + 2100 - vehicle_valuation_fhf_old*POW(1-0.0181,(DATEDIFF(CURDATE(),afs.contract_date)/30 + 2))*0.961 AS DECIMAL (8,2))
              WHEN (valuation_mmr IS NULL
                    OR valuation_mmr = 0)
                   AND a.idapplication >= 11553 THEN CAST(amount_financed + 1106 + 2100 - vehicle_value_average_trade_in*POW(1-0.0181,(DATEDIFF(CURDATE(),afs.contract_date)/30 + 2))*0.961 AS DECIMAL (8,2))
          END AS net_exposure
   FROM link_loan_contact AS llc
   LEFT OUTER JOIN fhf_loan_numbers AS fln ON fln.loan_number = llc.loan_number
   LEFT OUTER JOIN application AS a ON llc.application_id = a.idapplication
   LEFT OUTER JOIN status AS s ON a.idapplication = s.application_id
   LEFT OUTER JOIN vehicle_master_nada_keyed AS vmnk ON vmnk.application_id = a.idapplication
   AND is_applying_for = 1
   LEFT OUTER JOIN vehicle_pricing AS vp ON vp.vehicle_id = vmnk.idvehicle
   LEFT OUTER JOIN vehicle_valuation_nada AS vvn ON vvn.vehicle_id = vmnk.idvehicle
   LEFT OUTER JOIN vehicle_valuation_auction_data AS vvad ON vvad.vehicle_id = vmnk.idvehicle
   LEFT OUTER JOIN accounting_funding_station AS afs ON llc.application_id = afs.application_id
   INNER JOIN `applicant` AS `ap` ON a.idapplication = ap.application_id
    AND ap.is_coapplicant = 0
   LEFT OUTER JOIN `cr_cron` AS `cc` ON fln.cyberridge_loan_number = cc.loan_number
   LEFT OUTER JOIN `collection_collector_assigned_to_applicationid` AS `cata` ON llc.application_id = cata.application_id
    AND cata.active_status = 1
   LEFT OUTER JOIN `collection_collectors` AS `ccoll` ON cata.collector_id = ccoll.idcollection_collectors
   LEFT OUTER JOIN `user` AS `u` ON ccoll.user_id = u.iduser
   LEFT OUTER JOIN
     (SELECT application_id, callstatus_id, promise_to_pay_yesno, call_date_time
         FROM collection_call_log
         ORDER BY call_date_time DESC
      ) AS `cl` ON llc.application_id = cl.application_id
   LEFT OUTER JOIN `collection_loan_group` AS `clg` ON cata.collection_loan_group_id = clg.collection_loan_group_id
   LEFT OUTER JOIN
     (SELECT *
         FROM `collection_promises_to_pay`
         ORDER BY recorded_at DESC) AS `ptp` ON llc.idloan = ptp.loan_id
   LEFT OUTER JOIN
        (SELECT *
         FROM `collection_scheduled_calls`
         ORDER BY scheduled_on_date DESC) AS `csc` ON llc.idloan = csc.loan_id
   LEFT OUTER JOIN
        (SELECT *
         FROM `collection_delinquency_reason_assignments`
         ORDER BY recorded_at DESC) AS `cdra` ON llc.idloan = cdra.loan_id
   LEFT OUTER JOIN `collection_delinquency_reasons` AS `dr` ON cdra.delinquency_reason_id = dr.iddelinquency_reason
   LEFT OUTER JOIN `collection_delinquency_reason_buckets` AS `drb` ON cdra.delinquency_bucket_id = drb.iddelinquency_reason_bucket
   LEFT OUTER JOIN
     ( SELECT `ac`.`application_id` ,
              `ac`.`attempted_calls` ,
              `sc`.`successful_calls` ,
              ac.call_date_time
      FROM
        ( SELECT application_id, MAX( call_date_time ) AS call_date_time, COUNT( 1 ) AS attempted_calls
          FROM collection_call_log
          GROUP BY application_id ) AS `ac`
      LEFT JOIN
        (SELECT application_id,
                COUNT(1) AS successful_calls
         FROM
           (SELECT application_id, callstatus_id
            FROM collection_call_log AS clt HAVING callstatus_id <=1 ) AS successfulcalls
         GROUP BY application_id ) AS `sc` ON ac.application_id = sc.application_id ) AS `clcalls` ON llc.application_id = clcalls.application_id
   WHERE 1
     AND (cc.days_delinquent > 0)
     AND (cc.total_past_due_balance > 0)) AS `a`
GROUP BY `application_id`
ORDER BY `days_delinquent` ASC