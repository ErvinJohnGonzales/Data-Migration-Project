---USERS CTE Version---

WITH user_data AS (
    SELECT
        us.kuserid,
        us.usfirstname,
        us.uslastname,
        us.usemail,
        us.usloginid,
        sec.ksecurityclassid,
        sec.scname
    FROM public.wruser us
    INNER JOIN public.wrcworker wrc ON us.kuserid = wrc.kuserid
    INNER JOIN public.wrsecurityclass sec ON us.ksecurityclassid = sec.ksecurityclassid
    WHERE us.usstatus = '1'
    AND sec.ksecurityclassid NOT IN ('8', '30', '26')
),


role_mapping AS (
    SELECT
        kuserid,
        CASE 
            WHEN ksecurityclassid IN ('4', '22', '16') THEN 'Staff: Frontline Support'
            WHEN ksecurityclassid IN ('2', '9', '18', '11', '21', '31', '5', '1', '23', '3', '7', '12', '28') THEN 'Staff: Practitioner'
            WHEN ksecurityclassid IN ('6') THEN 'People Leader'
            WHEN ksecurityclassid IN ('29', '19') THEN 'Management (Program, Region, and Practice)'
            ELSE scname
        END AS UserRoleName
    FROM user_data
),


final_output AS (
    SELECT DISTINCT ON (ud.kuserid)
        ud.kuserid AS "UserLegacyId__c",
        CASE
            WHEN ud.usemail = '' THEN
                LOWER(
                    SUBSTRING(SPLIT_PART(COALESCE(ud.usfirstname, ''), ' ', 1) FROM 1 FOR 1) || '.' || LOWER(COALESCE(ud.uslastname, ''))
                ) || '@rasa.org.au'
            ELSE ud.usemail
        END AS "Username",
        ud.usFirstName AS "FirstName",
        ud.uslastname AS "LastName",
        CASE
            WHEN ud.usemail = '' THEN
                LOWER(
                    SUBSTRING(SPLIT_PART(COALESCE(ud.usfirstname, ''), ' ', 1) FROM 1 FOR 1) || '.' || LOWER(COALESCE(ud.uslastname, ''))
                ) || '@rasa.org.au'
            ELSE ud.usemail
        END AS "Email",
        LEFT(ud.usloginid, 7) AS "Alias",
        'RASA Staff' AS "Profile:Profile-Name",
        rm.UserRoleName AS "UserRole:UserRole-Name",
        'Australia/Adelaide' AS "TimeZoneSidKey",
        'en_AU' AS "Locale",
        'UTF-8' AS "EmailEncodingKey",
        'en_US' AS "LanguageLocaleKey",
        '1' AS "IsActive"
    FROM user_data ud
    JOIN role_mapping rm ON ud.kuserid = rm.kuserid
)

SELECT * FROM final_output
ORDER BY "UserLegacyId__c";

