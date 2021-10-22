/* Selecting database, change name to schema name in the local machine.
Please import the main table as biba_challenge*/
USE rappi;

/*Changing column names to avoid using the reserved word STATUS*/
ALTER TABLE biba_challenge RENAME COLUMN `STATUS` TO STATUS_;
ALTER TABLE biba_challenge RENAME COLUMN `UPDATE` TO UPDATE_;

/*Creating temporary tables to simplify queries*/

CREATE TEMPORARY TABLE transactions (
	SELECT ID, UPDATE_, TXN
    FROM biba_challenge
    WHERE TXN IS NOT NULL);
    
CREATE TEMPORARY TABLE type_of_card (
	SELECT ID, UPDATE_, MOTIVE
    FROM biba_challenge
    WHERE MOTIVE IN('DIGITAL','PLASTIC'));
    
CREATE TEMPORARY TABLE card_terms (
	SELECT ID, UPDATE_, INTEREST_RATE, AMOUNT, CAT
    FROM biba_challenge
    WHERE AMOUNT IS NOT NULL);

-----------------------------------------------------------------------------------------------------------------

/*Get growth rate per month*/
CREATE TEMPORARY TABLE GR(
SELECT DATE_FORMAT(bi1.UPDATE_, "%Y-%m") as 'app_date', 
	   COUNT(STATUS_='APPROVED') as 'Approved', 
       (SELECT COUNT(bi2.STATUS_='APPROVED')
		FROM biba_challenge as bi2 
		WHERE DATE_FORMAT(bi2.UPDATE_, "%Y-%m") <= DATE_FORMAT(bi1.UPDATE_, "%Y-%m")) as 'total_YTD'
FROM biba_challenge as bi1
GROUP BY DATE_FORMAT(UPDATE_, "%Y-%m")
ORDER BY DATE_FORMAT(UPDATE_, "%Y-%m"));

SELECT app_date, approved, total_YTD, (total_ytd - (total_ytd-approved))/(total_ytd-approved) as 'growth_rate'
FROM GR
INTO OUTFILE 'GR.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get the average revenue per card per month*/
SELECT rev_date, revenue, total_cards_ytd, revenue/total_cards_ytd as 'ARC'
FROM(
	SELECT DATE_FORMAT(tr.UPDATE_, "%Y-%m") as 'rev_date', SUM(TXN)  AS 'Revenue', 
			@tcards:=(SELECT COUNT(bi1.STATUS_='APPROVED')
			FROM biba_challenge as bi1 
			WHERE DATE_FORMAT(bi1.UPDATE_, "%Y-%m") <= DATE_FORMAT(tr.UPDATE_, "%Y-%m")) as 'total_cards_ytd'
	FROM type_of_card as ty
	LEFT JOIN transactions as tr ON ty.ID = tr.ID
	WHERE DATE_FORMAT(tr.UPDATE_, "%Y-%m") IS NOT NULL
	GROUP BY DATE_FORMAT(tr.UPDATE_, "%Y-%m")
	ORDER BY DATE_FORMAT(tr.UPDATE_, "%Y-%m")
    ) AS temp
INTO OUTFILE 'ARC.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Average delivery score by month*/
SELECT DATE_FORMAT(UPDATE_, "%Y-%m"), AVG(DELIVERY_SCORE)
FROM biba_challenge
GROUP BY DATE_FORMAT(UPDATE_, "%Y-%m")
ORDER BY DATE_FORMAT(UPDATE_, "%Y-%m")
INTO OUTFILE 'delivery.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/* Get the ratio of approved cards over total leads*/
SELECT COUNT(IF(STATUS_='RESPONSE',STATUS_,NULL)) AS 'Total_leads',COUNT(IF(STATUS_='APPROVED',STATUS_,NULL)) AS 'Lead_conversion', 
COUNT(IF(STATUS_='APPROVED',STATUS_,NULL))/COUNT(IF(STATUS_='RESPONSE',STATUS_,NULL)) as 'Approval ratio'
FROM biba_challenge
INTO OUTFILE 'lead_conversion.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get the average revenue per card by type of card*/
SELECT MOTIVE, COUNT(MOTIVE)  AS 'Number_of_cards', SUM(TXN)/COUNT(MOTIVE) AS "Avg_per_card" 
FROM type_of_card as ty
LEFT JOIN transactions as tr ON ty.ID = tr.ID
GROUP BY MOTIVE
INTO OUTFILE 'type_card.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get Average revenue by card by AMOUNT segment*/
SELECT Amount_segment, SUM(TXN)/COUNT(AMOUNT) AS 'Avg_per_segment'
FROM (
	 SELECT
     CASE
		WHEN AMOUNT <= 5000 THEN '0-5000'
        WHEN AMOUNT > 5000 AND AMOUNT <= 15000 THEN '5001 - 15000'
        WHEN AMOUNT > 15000 AND AMOUNT <= 30000 THEN '15001 - 30000'
        WHEN AMOUNT > 30000 AND AMOUNT <= 50000 THEN '30000 - 50000'
        WHEN AMOUNT > 50000 THEN '+50000' END AS 'Amount_segment', ct.ID, AMOUNT, TXN
	 FROM card_terms as ct
     LEFT JOIN transactions as tr ON ct.ID = tr.ID
     ) AS Temp
GROUP BY Amount_segment
ORDER BY Amount_segment
INTO OUTFILE 'rev_amount.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get Average revenue by card by INTEREST RATE segment*/
SELECT Interest_segment, SUM(TXN)/COUNT(INTEREST_RATE) AS 'Avg_per_segment'
FROM (
	 SELECT
     CASE
		WHEN INTEREST_RATE <= 35 THEN '30-35'
        WHEN INTEREST_RATE > 35 AND INTEREST_RATE <= 40 THEN '36 - 40'
        WHEN INTEREST_RATE > 40 AND INTEREST_RATE <= 45 THEN '41 - 45'
        WHEN INTEREST_RATE > 45 AND INTEREST_RATE <= 50 THEN '46 - 50' END AS 'Interest_segment', ct.ID, INTEREST_RATE, TXN
	 FROM card_terms as ct
     LEFT JOIN transactions as tr ON ct.ID = tr.ID
     ) AS Temp
GROUP BY Interest_segment
ORDER BY Interest_segment
INTO OUTFILE 'avg_interest.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/* Get number of active and inactive customers */
SELECT COUNT(Total_transactions > 0) AS 'Active customers', COUNT(Total_transactions IS NULL) - COUNT(Total_transactions > 0) AS 'Inactive customers'
FROM(
	SELECT ty.ID, MOTIVE, SUM(TXN) AS 'Total_transactions'
    FROM type_of_card AS ty
    LEFT JOIN transactions as tr ON ty.ID=tr.ID
    GROUP BY ID
    ) AS Temp
INTO OUTFILE 'inactive.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Average delivery score by CP*/
SELECT CP, AVG(DELIVERY_SCORE)
FROM biba_challenge
GROUP BY CP
INTO OUTFILE 'score_cp.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get number of records where CAT is lower than Interest rate*/
SELECT COUNT(ID)
FROM card_terms
WHERE CAT < INTEREST_RATE
INTO OUTFILE 'rate_cat.csv'
FIELDS TERMINATED BY ',';

-----------------------------------------------------------------------------------------------------------------

/*Get number of records where the sum of TXN is greater than AMOUNT*/
SELECT COUNT(ID)
FROM(
	SELECT tr.ID, SUM(TXN) as 'Revenue', COUNT(TXN) as 'ntransactions', MAX(INTEREST_RATE) , MAX(AMOUNT) as 'credit_limit', MAX(CAT), MOTIVE
	FROM transactions as tr
	LEFT JOIN card_terms as te ON tr.ID=te.ID
	LEFT JOIN type_of_card as ty ON tr.ID=ty.ID
	GROUP BY tr.ID
    HAVING Revenue > credit_limit
	ORDER BY Revenue DESC
    ) as temp;