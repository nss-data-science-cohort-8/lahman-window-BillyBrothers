-- ## Question 1: Rankings -- #### Question 1a: Warmup Question -- Write a query which retrieves each teamid and number of wins (w) for the 2016 season. -- Apply three window functions to the number of wins (ordered in descending order) - ROW_NUMBER, RANK, AND DENSE_RANK. -- Compare the output from these three functions. What do you notice?

SELECT teamid, w, RANK() OVER(ORDER BY w DESC) AS desc_rank, ROW_NUMBER() OVER(ORDER BY w DESC) AS rows_number, DENSE_RANK() OVER(ORDER BY w DESC) AS dense_ranks FROM teams WHERE yearid = '2016';

-- #### Question 1b: -- Which team has finished in last place in its division (i.e. with the least number of wins) the most number of times? A team's division is indicated by the divid column in the teams table.

WITH place AS( SELECT teamid, yearid, w, DENSE_RANK() OVER(PARTITION BY lgid, yearid, divid ORDER BY w) FROM teams )

SELECT teamid, COUNT(dense_rank) AS last_place_finishes FROM place WHERE dense_rank = 1 GROUP BY teamid ORDER BY last_place_finishes DESC;

-- ## Question 2: Cumulative Sums -- #### Question 2a: -- Barry Bonds has the record for the highest career home runs, with 762. -- Write a query which returns, for each season of Bonds' career the total number of seasons he had played and his total career home runs at the end of that season. (Barry Bonds' playerid is bondsba01.)

SELECT playerid, yearid, SUM(HR) OVER( ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_runs, ROW_NUMBER() OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_season FROM batting WHERE playerid = 'bondsba01'

-- #### Question 2b: -- How many players at the end of the 2016 season were on pace to beat Barry Bonds' record? -- For this question, we will consider a player to be on pace to beat Bonds' record if they have more home runs than Barry Bonds had the same number of seasons into his career.

WITH cte AS( SELECT playerid, yearid, SUM(hr) AS hr FROM Batting GROUP BY playerid, yearid ),

all_players AS( SELECT yearid, playerid, SUM(HR) OVER( PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS all_cum_runs, ROW_NUMBER() OVER( PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS season FROM cte ),

barry AS( SELECT playerid, SUM(HR) OVER( PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS barry_cum_runs, ROW_NUMBER() OVER(ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS season FROM cte WHERE playerid = 'bondsba01' )

SELECT COUNT(*) FROM all_players JOIN barry USING(season) WHERE all_cum_runs > barry_cum_runs AND yearid = 2016

-- #### Question 2c: -- Were there any players who 20 years into their career who had hit more home runs at that point into their career than Barry Bonds had hit 20 years into his career?

WITH all_players AS( SELECT playerid, yearid, SUM(HR) OVER( PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS total_home_runs FROM batting )

WITH barry AS( SELECT playerid, yearid, SUM(HR) OVER( PARTITION BY playerid ORDER BY yearid ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW ) AS total_home_runs FROM batting WHERE playerid = 'bondsba01' )

-- ## Question 3: Anomalous Seasons -- Find the player who had the most anomalous season in terms of number of home runs hit. To do this, find the player who has the largest gap between the number of home runs hit in a season and the 5-year moving average number of home runs if we consider the 5-year window centered at that year (the window should include that year, the two years prior and the two years after).

-- ## Question 4: Players Playing for one Team -- For this question, we'll just consider players that appear in the batting table. -- #### Question 4a: -- Warmup: How many players played at least 10 years in the league and played for exactly one team? (For this question, exclude any players who played in the 2016 season). Who had the longest career with a single team? (You can probably answer this question without needing to use a window function.)

-- #### Question 4b: -- Some players start and end their careers with the same team but play for other teams in between. For example, Barry Zito started his career with the Oakland Athletics, moved to the San Francisco Giants for 7 seasons before returning to the Oakland Athletics for his final season. How many players played at least 10 years in the league and start and end their careers with the same team but played for at least one other team during their career? For this question, exclude any players who played in the 2016 season.

-- ## Question 5: Streaks -- #### Question 5a: -- How many times did a team win the World Series in consecutive years?

-- #### Question 5b: -- What is the longest steak of a team winning the World Series? Write a query that produces this result rather than scanning the output of your previous answer.

-- #### Question 5c: -- A team made the playoffs in a year if either divwin, wcwin, or lgwin will are equal to 'Y'. Which team has the longest streak of making the playoffs?

-- #### Question 5d: -- The 1994 season was shortened due to a strike. If we don't count a streak as being broken by this season, does this change your answer for the previous part?

-- ## Question 6: Manager Effectiveness -- Which manager had the most positive effect on a team's winning percentage? To determine this, calculate the average winning percentage in the three years before the manager's first full season and compare it to the average winning percentage for that manager's 2nd through 4th full season. Consider only managers who managed at least 4 full years at the new team and teams that had been in existence for at least 3 years prior to the manager's first full season.