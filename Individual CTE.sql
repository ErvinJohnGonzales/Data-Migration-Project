---INDIVIDUAL CTE VERSION---
WITH base_data AS (
    SELECT
        sfp.kprogprovid,
        sfp.kprogprovstatusid,
        sfp.pprovend,
        sfp.kcaseprogid,
        sfp.kcworkeridprim,
        ai.kcasemembersid,
        ca.kindid,
        ip.indfirstname,
        ip.indlastname,
        ip.inddateofbirth,
        ip.indaddress1,
        ip.indaddress2,
        ip.indcounty,
        ip.indpczip,
        ip.luindprovstateid,
        lu.gender,
        sta.provstatename,
        sta.provstateshort,
        ic.kcontacttypeid,
        ic.contact,
        sp.kagserid,
        sp.aserstatus,
		dex.dss_client_id,
		dex.dss_latest_submission_status,
        usr.usstatus
    FROM public.ctprogprov sfp
    FULL JOIN public.aicprogmem ai ON sfp.kprogprovid = ai.kprogprovid
    FULL JOIN public.aiccasemembers ca ON ai.kcasemembersid = ca.kcasemembersid
    FULL JOIN public.irindividual ip ON ca.kindid = ip.kindid
    FULL JOIN public.irindcontact ic ON ip.kindid = ic.kindid
    FULL JOIN public.prcaseprog pr ON sfp.kcaseprogid = pr.kcaseprogid
    FULL JOIN public.pragser sp ON pr.kagserid = sp.kagserid
    FULL JOIN public.lugender lu ON ip.luindgenderid = lu.lugenderid
    FULL JOIN public.luprovstate sta ON ip.luindprovstateid = sta.luprovstateid
    FULL JOIN public.wrcworker wrc ON sfp.kcworkeridprim = wrc.kcworkerid
    FULL JOIN public.wruser usr ON wrc.kuserid = usr.kuserid
	FULL JOIN public.view_athena_ind_dss dex ON ip.kindid = dex.ind_id
-- Only include individuals with at least one Open Service File
    WHERE sfp.kprogprovstatusid = 1
-- Only include clients with Open Service Files attached to active Practitioners
      AND usr.usstatus = '1'
-- Only include clients with an Open service file in an active Benefit
      AND sp.aserstatus = '1'
-- Only include specific Benefits
      AND sp.kagserid IN (
          '1247', '1226', '1110', '1289', '1044', '1245', '1190', '1036', '1186', '1113',
          '1290', '1046', '1229', '1165', '1193', '1049', '1204', '1219', '1300', '1057',
          '1213', '1124', '1156', '1056', '1055', '1284', '1047', '1040', '1050', '1256',
          '1217', '1052', '1303', '1053', '1288', '1048', '1299', '1277', '1094', '1276',
          '1302', '1076', '1153', '1182', '1275', '1059', '1233', '1281', '1239', '1259',
          '1227', '1294', '1072', '1074', '1234', '1292', '1280', '1172', '1298', '1293',
          '1088', '1235', '1279', '1154', '1272', '1228', '1216'
      )
-- Exclude records with 'RASA' in the last name because they are practitioners this is case sensitive
      AND ip.indlastname NOT LIKE '%RASA%'
-- Exclude records with problematic first names (e.g., test, dummy, etc.)
      AND ip.indfirstname !~* '(triplicate|deceased|dummy|test|duplication|dupli|do not use|delete|dupe[12]?|n?ccs|worker|zz--|\?\?|[a-z]--|---)'
-- Exclude records with problematic last names (e.g., legal, office, etc.)
      AND ip.indlastname !~* '(triplicate|deceased|dummy|duplication|dupli|test|do not use|delete|dupe[12]?|lawyer|legal|worker|service|council|association|solicitor|partners|support|office|attention|zz--|\?\?|[a-z]--|---)'
),



-- Contacts CTE: Extracts and normalizes contact information by type
contacts AS (
    SELECT
        kindid,
        MIN(CASE WHEN kcontacttypeid IN ('3', '12', '7') THEN REGEXP_REPLACE(contact, '[^a-zA-Z0-9@._-]', '', 'g') END) AS email,
        MIN(CASE WHEN kcontacttypeid = '2' THEN REGEXP_REPLACE(REPLACE(LOWER(contact), 'x', '0'), '[^0-9]', '', 'g') END) AS mobile,
        MIN(CASE WHEN kcontacttypeid IN ('1', '9', '10') THEN REGEXP_REPLACE(REPLACE(LOWER(contact), 'x', '0'), '[^0-9]', '', 'g') END) AS home,
        MIN(CASE WHEN kcontacttypeid IN ('11', '6') THEN REGEXP_REPLACE(REPLACE(LOWER(contact), 'x', '0'), '[^0-9]', '', 'g') END) AS fax,
        MIN(CASE WHEN kcontacttypeid IN ('4', '5') THEN REGEXP_REPLACE(REPLACE(LOWER(contact), 'x', '0'), '[^0-9]', '', 'g') END) AS other
    FROM public.irindcontact
    GROUP BY kindid
),


-- Final output CTE: Formats and selects final fields for export
final_output AS (
    SELECT DISTINCT ON (bd.kindid)
        bd.kindid AS "AccountLegacyId__c",
        bd.indfirstname AS "FirstName",
        bd.indlastname AS "LastName",
-- Reformat date for Salesforce import
        TO_CHAR(bd.inddateofbirth, 'YYYY-MM-DD') AS "PersonBirthdate",
        TO_CHAR(bd.inddateofbirth, 'YYYY-MM-DD') AS "DateOfBirth__pc",
-- Reformat genders according to Salesforce picklist for genders
        CASE 
            WHEN bd.gender IN ('-Unspecified-', 'Intersex', 'Different term') THEN 'RASA Did Not Ask'
            ELSE bd.gender
        END AS "PersonGenderIdentity",
        c.email AS "PersonEmail",
        c.mobile AS "PersonMobilePhone",
        c.home AS "PersonHomePhone",
        c.fax AS "Fax",
        c.mobile AS "Phone",
        c.other AS "PersonOtherPhone",
        (bd.indaddress1 || ' ' || bd.indaddress2) AS "PersonMailingStreet",
        LEFT(bd.indcounty, 40) AS "PersonMailingCity",
        bd.indpczip AS "PersonMailingPostalCode",
-- Reformat States according to Salesforce requirements
        CASE 
            WHEN bd.luindprovstateid = '71' THEN 'South Australia'
            WHEN bd.luindprovstateid = '39' THEN 'Australian Capital Territory'
            ELSE bd.provstatename
        END AS "PersonMailingState",
-- Reformat State shortnames
        CASE 
            WHEN bd.luindprovstateid = '71' THEN 'SA'
            ELSE bd.provstateshort
        END AS "PersonMailingStateCode",
        'Australia' AS "PersonMailingCountry",
		bd.dss_client_id AS "DEXClientId__pc",
		CASE
			WHEN bd.dss_latest_submission_status = 'Success' THEN 'Synced'
			ELSE ''
		END AS "DEXSyncStatus__pc",
        'Personal Account' AS "Type",
        bd.pprovend AS "ServiceFileEndDate",
  
-- Reformat status according to Salesforce field specifications
        CASE 
            WHEN bd.kprogprovstatusid = '1' THEN 'Active'
            WHEN bd.kprogprovstatusid = '2' THEN 'Completed'
        END AS "Status"
    FROM base_data bd
    LEFT JOIN contacts c ON bd.kindid = c.kindid
)

SELECT * FROM final_output
ORDER BY "AccountLegacyId__c";


