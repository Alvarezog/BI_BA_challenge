/* Selecting database*/
USE rappi;

/*Changing column names to avoid using the reserved word STATUS*/
ALTER TABLE businessbiba_challenge RENAME COLUMN `STATUS` TO STATUS_;
ALTER TABLE businessbiba_challenge RENAME COLUMN `UPDATE` TO UPDATE_;

CREATE TABLE transactions (
	SELECT ID, UPDATE_, TXN
    FROM businessbiba_challenge
    WHERE TXN IS NOT NULL);
    
CREATE TABLE type_of_card (
	SELECT ID, UPDATE_, MOTIVE
    FROM businessbiba_challenge
    WHERE MOTIVE IN('DIGITAL','PLASTIC'));
    
CREATE TABLE card_terms (
	SELECT ID, UPDATE_, INTEREST_RATE, AMOUNT, CAT
    FROM businessbiba_challenge
    WHERE AMOUNT IS NOT NULL);




/* Get the ratio of approved cards over total leads*/
SELECT COUNT(IF(STATUS_='RESPONSE',STATUS_,NULL)) AS 'Total_leads',COUNT(IF(STATUS_='APPROVED',STATUS_,NULL)) AS 'Approved_cards', 
COUNT(IF(STATUS_='APPROVED',STATUS_,NULL))/COUNT(IF(STATUS_='RESPONSE',STATUS_,NULL)) as 'Approval ratio'
FROM businessbiba_challenge;

/*Get the average revenue by card by type of card*/
SELECT MOTIVE, COUNT(MOTIVE)  AS 'Number_of_cards', SUM(TXN)/COUNT(MOTIVE) AS "Avg_per_card" 
FROM type_of_card as ty
LEFT JOIN transactions as tr ON ty.ID = tr.ID
GROUP BY MOTIVE;

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
ORDER BY Amount_segment;

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
ORDER BY Interest_segment;

/* Get number of active and inactive customers */
SELECT COUNT(Total_transactions > 0) AS 'Active customers', COUNT(Total_transactions IS NULL) - COUNT(Total_transactions > 0) AS 'Inactive customers'
FROM(
	SELECT ty.ID, MOTIVE, SUM(TXN) AS 'Total_transactions'
    FROM type_of_card AS ty
    LEFT JOIN transactions as tr ON ty.ID=tr.ID
    GROUP BY ID
    ) AS Temp;


/*Get number of records where CAT is lower than Interest rate*/
SELECT COUNT(ID)
FROM card_terms
WHERE CAT < INTEREST_RATE;


/*Average delivery score by CP*/
SELECT CP, AVG(DELIVERY_SCORE)
FROM businessbiba_challenge
GROUP BY CP;