-- ## Question 1: Rankings
-- #### Question 1a: Warmup Question
-- Write a query which retrieves each teamid and number of wins (w) for the 2016 season. 
-- Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. 
-- Compare the output from these three functions. What do you notice?

SELECT 
	teamid,
	w,
	RANK() OVER(ORDER BY w DESC) AS desc_rank,
	ROW_NUMBER() OVER(ORDER BY w DESC) AS rows_number,
	DENSE_RANK() OVER(ORDER BY w DESC) AS dense_ranks
FROM teams
WHERE yearid = '2016';


SELECT 
	teamid,
	yearid,
	w,
	ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid)
FROM teams



-- #### Question 1b: 
-- Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table.

WITH place AS(
SELECT 
	teamid, yearid, w,
	DENSE_RANK() OVER(PARTITION BY lgid, yearid, divid ORDER BY w)
FROM teams
)

SELECT teamid, COUNT(dense_rank) AS last_place_finishes
FROM place
WHERE dense_rank = 1
GROUP BY teamid
ORDER BY last_place_finishes DESC
LIMIT 1;



-- ## Question 2: Cumulative Sums
-- #### Question 2a: 
-- Barry Bonds has the record for the highest career home runs, with 762. 
-- Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)


SELECT 
	playerid,
	yearid,
	SUM(HR)
	OVER(
	ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS cum_runs,
	ROW_NUMBER() OVER(ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS cum_season
FROM batting
WHERE playerid = 'bondsba01'


-- #### Question 2b:
-- How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? 
-- For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career. 

WITH cte AS(
SELECT playerid, yearid, SUM(hr) AS hr
FROM Batting
GROUP BY playerid, yearid
),

 all_players AS(
SELECT
	yearid,
	playerid,
	SUM(HR)
	OVER(
	PARTITION BY playerid
	ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS all_cum_runs,
	ROW_NUMBER() OVER(
	PARTITION BY playerid
	ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS season
FROM cte
),

barry AS(
SELECT 
	playerid,
	SUM(HR)
	OVER(
	PARTITION BY playerid
	ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS barry_cum_runs,
	ROW_NUMBER() OVER(ORDER BY yearid 
	ROWS BETWEEN 
	UNBOUNDED PRECEDING 
	AND 
	CURRENT ROW) AS season
FROM cte
WHERE playerid = 'bondsba01'
)

SELECT COUNT(*)
FROM all_players
INNER JOIN barry
USING(season)
WHERE all_cum_runs > barry_cum_runs AND yearid = 2016


-- #### Question 2c: 
-- Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career? 


WITH hr_partition AS (
    SELECT 
        namefirst||' '||namelast AS playername,
        playerid,
        yearid,
        SUM(hr) OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_hr,
        RANK() OVER(PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_seasons
    FROM batting AS b
        INNER JOIN people AS p USING(playerid)
),


bonds AS (
    SELECT 
        cumulative_seasons,
        cumulative_hr as bonds_hr
    FROM hr_partition
    WHERE playerid = 'bondsba01'
),


players_pace AS (
    SELECT 
        h.playername AS playername,
        h.yearid,
        h.cumulative_hr AS cumulative_hr,
        h.cumulative_seasons AS cumulative_seasons,
        b.bonds_hr,
        CASE WHEN h.cumulative_hr > b.bonds_hr THEN 'On Pace' ELSE 'Not On Pace' END AS pace
    FROM hr_partition AS h
    LEFT JOIN bonds AS b ON h.cumulative_seasons = b.cumulative_seasons
    WHERE h.playerid != 'bondsba01'
)
SELECT playername, cumulative_hr, cumulative_seasons 
FROM players_pace
WHERE pace = 'On Pace'
    AND cumulative_seasons =20;

-- ## Question 3: Anomalous Seasons
-- Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).
SELECT 
    namefirst||' '||namelast AS playername,
    yearid,
    hr,
    AVG(hr) OVER(ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS five_yr_avg, 
    hr - AVG(hr) OVER(ORDER BY yearid ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS hr_diff
FROM batting AS b
    INNER JOIN people AS p USING (playerid)
ORDER BY hr_diff DESC;


-- ## Question 4: Players Playing for one Team
-- For this question, we'll just consider players that appear in the batting table.
-- #### Question 4a: 
-- Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)


WITH career AS(
SELECT 
	playerid,
	COUNT(DISTINCT yearid) AS career_length,
	COUNT(DISTINCT teamid) AS n_teams,
	teamid
	FROM batting
	WHERE yearid <> 2016
	GROUP BY playerid, teamid

)

SELECT 
    DISTINCT namefirst||' '||namelast AS playername,
    career_length,
    n_teams,
    name AS team
FROM career AS c
    INNER JOIN people AS p USING(playerid)
    INNER JOIN teams AS t USING(teamid)
    WHERE career_length >= 10
        AND n_teams = 1
ORDER BY career_length DESC;

-- #### Question 4b: 
-- Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.

WITH career_10_multiteam AS (
    SELECT 
        playerid,
        COUNT(DISTINCT yearid) AS career_length,
        COUNT(DISTINCT teamid) AS n_teams
    FROM batting
        INNER JOIN people USING (playerid)
    -- WHERE yearid <> 2016
    GROUP BY playerid
    HAVING COUNT(DISTINCT yearid) >= 10
        AND COUNT(DISTINCT teamid) > 1
        AND MAX(yearid) < 2016 -- looks at 2016 and excludes anyone who appears
),


first_last_teams AS (
    SELECT
        DISTINCT playerid,
        FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid, stint) as first_team,
        FIRST_VALUE(teamid) OVER (PARTITION BY playerid ORDER BY yearid DESC, stint DESC) as last_team
    FROM batting
    WHERE yearid <> 2016
)


SELECT DISTINCT 
    namefirst || ' ' || namelast AS playername,
    career_length,
    n_teams AS n_distinct_teams,
    first_team,
    last_team
FROM career_10_multiteam AS cm
    INNER JOIN people p USING (playerid)
    INNER JOIN first_last_teams AS flt USING (playerid)
WHERE career_length >= 10 
    AND n_teams > 1
    AND first_team = last_team
ORDER BY career_length DESC;

-- ## Question 5: Streaks
-- #### Question 5a: 
-- How many times did a team win the World Series in consecutive years?


WITH winners AS (
    SELECT 
        teamid,
        yearid AS ws_win_year,
        LAG(yearid) OVER(PARTITION BY teamid ORDER BY yearid) AS prev_wswin,
        CASE WHEN (yearid - LAG(yearid) OVER(PARTITION BY teamid ORDER BY yearid)) = 1 THEN 'Y' ELSE 'N' END AS consecutive
    FROM teams
    WHERE wswin = 'Y' AND yearid >=1903
    ORDER BY 
        teamid, 
        yearid
)
SELECT 
    COUNT(*) AS n_consecutive_wins
FROM winners
WHERE consecutive = 'Y';


-- #### Question 5b: 
-- What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.

WITH streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM teams
    WHERE wswin = 'Y'
    ORDER BY teamid, yearid
)
SELECT 
    name,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;


WITH streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM teams
    WHERE wswin = 'Y'
    ORDER BY teamid, yearid
)

-- #### Question 5c: 
-- A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs? 

WITH playoffs AS (
    SELECT
        name,
        teamid,
        yearid,
        CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' THEN 'Y' ELSE 'N' END AS playoff
    FROM teams
),
streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM playoffs
    WHERE playoff = 'Y'
    ORDER BY teamid, yearid
)
SELECT 
    name,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;


-- #### Question 5d: 
-- The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?

WITH playoffs AS (
    SELECT
        name,
        teamid,
        yearid,
        CASE WHEN divwin = 'Y' OR wcwin = 'Y' OR lgwin = 'Y' OR yearid=1994 THEN 'Y' ELSE 'N' END AS playoff
    FROM teams
),
streaks AS (
    SELECT 
        name,
        teamid,
        yearid,
        yearid - ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY yearid) AS streak_group
    FROM playoffs
    WHERE playoff = 'Y' 
    ORDER BY teamid, yearid
)
SELECT 
    name||'*' AS teamname,
    MIN(yearid) as streak_start,
    MAX(yearid) as streak_end,
    COUNT(*) - 1 as streak_length
FROM streaks
GROUP BY name, teamid, streak_group
HAVING COUNT(*) > 1
ORDER BY streak_length DESC;

-- ## Question 6: Manager Effectiveness
-- Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season.