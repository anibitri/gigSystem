<!-- This is a template for the README.md that you should submit. For instructions on how to get started, see INSTRUCTIONS.md -->
# Design Choices

One of the few changes I would make to the table results would be adding a column to the act_gig table that has the finish time. The column would automatically calculate the finish time by adding the duration to the ontime. This would make several of the business rules and tasks easier to implement. Additionally, I would also add an extra column to the same table which would determine if the act was an opening act or a headline act. The datatype would be a character, either 'O' for opening or 'H' for headline. This column would be equally helpful to the finish time column as it would make several tasks and rules much more easier to implement.


<!-- Write suggestions for improving the design of the tables here -->

# Task Implementations

<!-- For each of the tasks below, please write around 100-200 words explaining how your solution works (describing the behaviour of your SQL statements/queries) -->

## Task 1

For task 1, I chose to use a prepared statement since only a simple query is used to get the desired results. The act name, its start time and its finish time were needed as results. Since the act name and the start time are not in the same table, I chose to join the two tables based on actIDs, and since we needed information for a particular gig, I used the gigID to filter the results and then order them by their start time. Furthermore, I used the SimpleDateFormat library to alter the start time and only show the hour and the minute instead of the whole DateTime object. The act_gig duration was needed to calculate the finish time since it is not an availble column in the table, and then store it just like I did with the start time. Then, the results were stored in a list of arrays because of inserting efficiency and return as an array by using the toArray() method.

## Task 2

For task 2, I used 3 different prepared statements, each one inserting the data to the gig, act_gig and gig_ticket tables.  The query used to insert the new gig into the relation returned a gigID, and if that gigID was NULL, then a SQL exception would be raised since the gig failed to be inserted. Next, the gigID retrieved from the successful gig insertion was used to populate the act_gig and gig_ticket tables. For the gig_ticket table, a second PreparedStatement inserted the ticket pricing details associated with the gig. For the act_gig table, a single dynamically constructed query was created to handle the insertion of multiple performances efficiently. This was achieved by building a parameterized VALUES clause for all the acts provided in the input, minimizing the number of database interactions. If any part of this process failed, the transaction would be rolled back entirely to ensure data consistency across all tables. By structuring the solution with three separate prepared statements and leveraging transactional control, the implementation maintained a balance between clarity, modularity, and efficiency while ensuring any insertion errors were promptly identified and handled with appropriate error management.


## Task 3

Similarly to task 2, task 3 also uses multiple prepared statements to check if the gig is active and to get the cost of the ticket from the relation gig_ticket, and then inserting the new ticket booking into the ticket relation with the given and selected information. If the status of the gig is cancelled or the price is returned as NULL, then the transaction would be rolled back to ensure the state of the database remains valid. If any exceptions were raised by the business rules, the method would catch these exceptions and roll back the transaction, making sure the new ticket is not inserted, and the state remains valid. 

## Task 4

Task 4 uses an SQL function with gigID and the act name as inputs which returns a table with all the customers names and emails affected by the act cancellation. The function manages the cancellation of the act while ensuring the lineup maintains its integrity and the logical transaction between acts. It first checks whether the specified act is the first act in the gig by comparing its ontime with the earliest act in the schedule. If the cancelled act is the first, the function recalculates the ontime for the other affected acts to make sure the gig's timeline remains coherent. When the first act is cancelled, the next act in the lineup inherits the original ontime of the cancelled act to make sure that the new first act starts at the same time as the gig. Subsequent acts are then adjusted to maintain their relative time intervals. If the cancelled act is not the first, all affected acts are simply shifted earlier by the duration of the cancelled act to close the gap in the schedule. For headline acts (final acts in the lineup), the function cancels the entire gig by updating the gig’s status to cancelled, setting ticket costs to zero, and returning customer details. Then the results are selected from the prepared statement in the Java method and put into a list of arrays, which on return is converted to a 2-D array.


## Task 5

For task 5, I recreated the same steps from task 4, meaning I developed a SQL function to get the desired results, used a prepare statement to select the results and put them in an array with all the numbers of tickets needed for every gigID. First, the function calculates the total cost of a gig, which includes the venue's hire cost, and the sum of all performance fees associated with the gig. This calculation is done through a subquery that also determines the cheapest ticket price for the gig. The function compares the total revenue generated from ticket sales with the calculated total cost of the gig. If the revenue meets or exceeds the total cost, the tickets needed are set to 0. Otherwise, the function computes the shortfall in revenue, divides it by the cheapest ticket price, and rounds up to the nearest whole number using CEIL, ensuring that enough tickets are sold to cover the cost.



## Task 6



The same steps follow for task 6 as they did in task 5. The SQL function for task 6 uses joins to efficiently gather and relate data across multiple tables. Specifically, the act_gig table is joined with the gig table to link acts to their gigs, ensuring the function considers only headline acts, which are determined by the latest ontime for each gig. Additionally, the gig table is joined with the ticket table to associate gigs with ticket sales, and the act table is joined to link tickets and gigs back to their respective acts. These joins allow the function to filter out canceled gigs and focus on valid headline acts. The function uses a subquery to compute ticket sales per year and another subquery to calculate total sales for each act. The final result is sorted first by ascending total sales, then alphabetically by act name, and finally numerically by year, ensuring clear and meaningful output. The results from the function are stored in a list of arrays and returned as a 2-D array.

## Task 7


Task 7 uses an SQL function to get the desired results as well. The function uses several steps and joins to filter and aggregate the data. It starts by identifying headline acts from the act_gig, act, and gig tables, ensuring only gigs that are not cancelled are included and selecting the act with the latest ontime per gig.  Next, it counts the number of distinct gigs attended by each customer for each headline act using the ticket table, linking tickets to specific gigs. This count is grouped by both act_name and customer_name. The regular_attendees subquery filters the results to include only those customers who have attended at least two different gigs for the same act. The function also accounts for acts that have no customers by creating the acts_with_no_customers subquery, which returns [None] for such acts. The final result combines the regular attendees and acts with no customers using UNION ALL, ensuring acts with no customers are included with '[None]' in the customer’s name column. The results are ordered alphabetically by act name and customer name. This approach provides a comprehensive list of both regular attendees and acts with no customers. Then in the Java method, the results are selected by a prepared statement, then put into a list of arrays and then returned as a 2-D array.


## Task 8

Similarly to the last several tasks, task 8 has its own SQL function. The function uses several subqueries and joins to calculate the feasibility of each act performing at various venues. The first subquery, avg_ticket_price, calculates the average ticket price for all non-cancelled gigs by joining the gig_ticket and gig tables. The second subquery, venues_with_capacity, retrieves the capacity and other details of each venue from the venue table. The third subquery, feasible_acts, generates all possible act-venue combinations using a CROSS JOIN between the venue and act tables. This provides a list of all possible scenarios for acts performing at different venues. The final SELECT statement calculates the minimum number of tickets needed to cover both the act’s standard fee and the venue’s hire cost by dividing the total cost by the average ticket price. It ensures that the venue can accommodate the required ticket sales and filters out any infeasible scenarios where the cost exceeds the venue's capacity. The results are ordered by venue name and the number of tickets needed, with the acts requiring the most tickets listed first. Then in the Java method, the results are selected by a prepared statement, then put into a list of arrays and then returned as a 2-D array.