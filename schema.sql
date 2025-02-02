/*Put your CREATE TABLE statements (and any other schema related definitions) here*/
DROP TABLE IF EXISTS act CASCADE;
CREATE TABLE act (
    actID serial PRIMARY KEY,
    actname varchar(100) NOT NULL UNIQUE,
    genre varchar(10) NOT NULL,
    standardfee INTEGER NOT NULL CHECK (standardfee >= 0)
);

DROP TABLE IF EXISTS venue CASCADE;
CREATE TABLE venue (
    venueID serial PRIMARY KEY,
    venuename varchar(100) NOT NULL UNIQUE,
    hirecost integer NOT NULL CHECK (hirecost >= 0),
    capacity INTEGER NOT NULL CHECK (capacity >= 0)
);

DROP TABLE IF EXISTS gig CASCADE;
CREATE TABLE gig (
    gigID serial PRIMARY KEY,
    venueID integer references venue(venueID),
    gigtitle varchar(100) NOT NULL,
    gigdatetime timestamp NOT NULL ,
    gigstatus varchar(1) NOT NULL CHECK (gigstatus IN ('G', 'C')),

    -- RULE 12
    CONSTRAINT gig_start_time CHECK (
        EXTRACT(HOUR FROM gigdatetime) >= 9
        AND EXTRACT(HOUR FROM gigdatetime) < 24
        AND EXTRACT(MINUTE FROM gigdatetime) >= 0
        AND EXTRACT(MINUTE FROM gigdatetime) < 60
    )
);

DROP TABLE IF EXISTS act_gig CASCADE;
CREATE TABLE act_gig (
    actID integer references act(actID),
    gigID integer references gig(gigID),
    actgigfee integer NOT NULL CHECK (actgigfee >= 0),
    ontime timestamp NOT NULL,
    duration integer NOT NULL CHECK (duration >= 15 AND duration <= 90) --RULE 4
);

DROP TABLE IF EXISTS ticket CASCADE;
CREATE TABLE ticket (
    ticketID serial PRIMARY KEY,
    gigID integer references gig(gigID),
    pricetype varchar(2) NOT NULL,
    cost integer NOT NULL CHECK (cost >= 0),
    customername varchar(100) NOT NULL,
    customeremail varchar(100) NOT NULL
);

DROP TABLE IF EXISTS gig_ticket CASCADE;
CREATE TABLE gig_ticket (
    gigID integer references gig(gigID),
    pricetype varchar(2) NOT NULL,
    price integer NOT NULL CHECK (price >= 0),

    PRIMARY KEY (gigID)
);




-- RULE 1
CREATE OR REPLACE FUNCTION check_act_no_overlap() 
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the act overlaps with any other act in the same gig
    IF EXISTS (
    SELECT 1
    FROM act_gig ag2
    JOIN gig g ON ag2.gigID = g.gigID
    WHERE ag2.gigID = NEW.gigID
    AND ag2.actID <> NEW.actID 
    AND g.gigstatus = 'G'       
    AND (
        -- Check if the new act overlaps with any existing act
        (ag2.ontime < NEW.ontime + (NEW.duration * INTERVAL '1 minute') -- ag2 starts before NEW finishes
            AND ag2.ontime + (ag2.duration * INTERVAL '1 minute') > NEW.ontime) -- ag2 ends after NEW starts
        OR (NEW.ontime < ag2.ontime + (ag2.duration * INTERVAL '1 minute') -- NEW starts before ag2 finishes
            AND NEW.ontime + (NEW.duration * INTERVAL '1 minute') > ag2.ontime) -- NEW ends after ag2 starts
        )
    ) THEN
        RAISE EXCEPTION 'Act overlaps with existing act in the same gig';
        RETURN NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE  TRIGGER act_no_overlap_trigger
BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE FUNCTION check_act_no_overlap();



-- RULE 2
CREATE OR REPLACE FUNCTION act_same_time()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the act is performing at the same time or overlapping with another gig
    IF EXISTS (
        SELECT 1
        FROM act_gig
        WHERE act_gig.actID = NEW.actID
        AND act_gig.gigID <> NEW.gigID
        AND (
            (act_gig.ontime <= NEW.ontime + (NEW.duration * INTERVAL '1 minute') -- act_gig starts before NEW finishes
            AND act_gig.ontime + (act_gig.duration * INTERVAL '1 minute') > NEW.ontime) -- act_gig ends after NEW starts
            OR
            (NEW.ontime <= act_gig.ontime + (act_gig.duration * INTERVAL '1 minute') -- NEW starts before act_gig finishes
            AND NEW.ontime + (NEW.duration * INTERVAL '1 minute') > act_gig.ontime) -- NEW ends after act_gig starts
        )
    ) THEN
        RAISE EXCEPTION 'Act cannot perform multiple gigs at the same time or overlapping times';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER act_same_time_trigger
BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE FUNCTION act_same_time();



-- RULE 3
CREATE OR REPLACE FUNCTION act_single_fee_per_gig()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if there is already an entry for the act in the gig
    IF EXISTS (
        SELECT 1 FROM act_gig WHERE actID = NEW.actID AND gigID = NEW.gigID
    ) THEN
        NEW.actgigfee = 0; -- Set the actgigfee to 0 if the act is already in the gig
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER act_single_fee_per_gig_trigger
BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE FUNCTION act_single_fee_per_gig();



-- RULE 5
CREATE OR REPLACE FUNCTION check_act_travel_gap()
RETURNS TRIGGER AS $$
DECLARE
    previous_gig_end_time TIMESTAMP;
BEGIN
    -- Get the end time of the previous gig on the same day for the same act
    SELECT (ag.ontime + (ag.duration || ' minutes')::interval) AS end_time
    INTO previous_gig_end_time
    FROM act_gig ag
    JOIN gig g ON ag.gigID = g.gigID
    WHERE ag.actID = NEW.actID
      AND DATE(g.gigdatetime) = DATE(NEW.ontime) -- Same day
      AND ag.gigID <> NEW.gigID
      AND ag.ontime < NEW.ontime
      AND g.venueID <> (SELECT venueID FROM gig WHERE gigID = NEW.gigID)
    ORDER BY ag.ontime DESC
    LIMIT 1;

    -- Check if there is a previous gig and if the time gap is less than 60 minutes
    IF previous_gig_end_time IS NOT NULL AND previous_gig_end_time + INTERVAL '60 minutes' > NEW.ontime THEN
        RAISE EXCEPTION 'Act % does not have enough travel time (60 minutes) between consecutive gigs on %', NEW.actID, NEW.ontime::date;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER check_act_travel_gap_trigger
BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE FUNCTION check_act_travel_gap();


-- RULE 6
CREATE OR REPLACE FUNCTION venue_interval()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the venue has at least 3 hours between gigs
    IF EXISTS (
        SELECT 1
        FROM gig g
        WHERE g.venueID = NEW.venueID
          AND DATE(g.gigdatetime) = DATE(NEW.gigdatetime)
          AND g.gigID <> NEW.gigID
          AND g.gigstatus = 'G'  -- Only consider active gigs
          AND (
              NEW.gigdatetime < (g.gigdatetime + INTERVAL '3 hours')
              OR (NEW.gigdatetime + INTERVAL '3 hours') > g.gigdatetime
          )
    ) THEN
        RAISE EXCEPTION 'Venue must have at least 3 hours between gigs';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER venue_interval_trigger
BEFORE INSERT ON gig
FOR EACH ROW
EXECUTE FUNCTION venue_interval();


-- RULE 7
CREATE OR REPLACE FUNCTION check_act_breaks()
RETURNS TRIGGER AS $$
DECLARE
    _dummy INTEGER; -- Placeholder variable to capture SELECT results
BEGIN
    -- Query to check for invalid breaks or gaps
    WITH ordered_acts AS (
        SELECT gigID, actID, ontime,
            (ontime + (duration || ' minutes')::interval) AS offtime,
            LEAD(ontime) OVER (PARTITION BY gigID ORDER BY ontime) AS next_ontime -- Get the next act's ontime
        FROM act_gig
    )
    -- Find any acts with invalid breaks or overlaps
    SELECT 1
    INTO _dummy
    FROM ordered_acts
    WHERE 
        -- Check for overlapping acts
        next_ontime IS NOT NULL
        AND (
            (next_ontime < offtime) OR -- Overlap
            ((next_ontime - offtime) < INTERVAL '10 minutes' AND (next_ontime - offtime) > INTERVAL '0 minutes') OR 
            (next_ontime - offtime) > INTERVAL '30 minutes' 
        );

    -- Raise an exception if the condition is violated
    IF FOUND THEN
        RAISE EXCEPTION 'Invalid act scheduling: overlaps, breaks too short, or breaks too long detected.';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER enforce_act_breaks
AFTER INSERT OR UPDATE ON act_gig
FOR EACH STATEMENT
EXECUTE FUNCTION check_act_breaks();

-- RULE 8
CREATE OR REPLACE FUNCTION act_gig_start_time_check()
RETURNS TRIGGER AS $$
DECLARE
    dummy INTEGER; -- Placeholder variable to capture SELECT results
BEGIN
    -- Validate that the first act of every gig starts at the same time as the gigdatetime
    WITH first_acts AS (
        SELECT ag.gigID, MIN(ag.ontime) AS first_act_start, g.gigdatetime
        FROM act_gig ag
        JOIN gig g ON ag.gigID = g.gigID
        WHERE g.gigstatus != 'C' -- Only consider non-cancelled gigs
        GROUP BY ag.gigID, g.gigdatetime
    )
    SELECT 1
    FROM first_acts
    WHERE first_act_start != gigdatetime
    LIMIT 1
    INTO dummy; -- Ensure no invalid entries exist

    -- Raise exception if any invalid entries exist
    IF FOUND THEN
        RAISE EXCEPTION 'The first act for one or more gigs does not start at the gigdatetime.';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER act_gig_start_time_trigger
AFTER INSERT OR UPDATE ON act_gig
FOR EACH STATEMENT
EXECUTE FUNCTION act_gig_start_time_check();


--RULE 9
CREATE OR REPLACE FUNCTION check_ticket_capacity()
RETURNS TRIGGER AS $$
BEGIN
    --Get the no. of tickets for the gig
    IF (SELECT COUNT(*) FROM ticket WHERE gigID = NEW.gigID) >=
        (SELECT venue.capacity FROM venue WHERE venueID = (SELECT venueID FROM gig WHERE gigID = NEW.gigID)) THEN
        --Raise exception if the no. of tickets exceeds the venue capacity for that gig
        RAISE EXCEPTION 'The number of tickets exceeds the venue capacity';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER ticket_capacity_trigger
BEFORE INSERT ON ticket
FOR EACH ROW
EXECUTE FUNCTION check_ticket_capacity();


-- RULE 10
CREATE OR REPLACE FUNCTION check_final_act_finish_time()
RETURNS TRIGGER AS $$
DECLARE
    dummy INTEGER; -- Placeholder variable to capture SELECT results
BEGIN
    -- Calculate total duration for each affected gig
    WITH gig_durations AS (
        SELECT 
            gigID,
            MIN(ontime) AS gig_start_time,
            MAX(ontime + (duration || ' minutes')::interval) AS gig_end_time
        FROM act_gig
        GROUP BY gigID
    )
    -- Check if any gig lasts less than 1 hour
    SELECT 1
    INTO dummy
    FROM gig_durations
    WHERE (gig_end_time - gig_start_time) < INTERVAL '1 hour'
    LIMIT 1;

    -- Raise an exception if the condition is not met
    IF FOUND THEN
        RAISE EXCEPTION 'Gig must last at least 1 hour.';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER enforce_final_act_finish_time
AFTER INSERT OR UPDATE ON act_gig
FOR EACH STATEMENT
EXECUTE FUNCTION check_final_act_finish_time();

-- RULE 11
CREATE OR REPLACE FUNCTION disturb()
RETURNS TRIGGER AS $$
BEGIN   
    IF (SELECT genre FROM act WHERE actID = NEW.actID) IN ('Pop', 'Rock') THEN
        -- If the act is Pop or Rock, it must finish no later than 11 PM
        IF (NEW.ontime + (NEW.duration * INTERVAL '1 minute') > (NEW.ontime::date + INTERVAL '23:00:00')) THEN
            RAISE EXCEPTION 'Act must finish no later than 23:00 (11 PM)';
            RETURN NULL;
        END IF;
    ELSE
        --If the act is not Pop or Rock, it must finish no later than 1 AM of the next day
        IF (NEW.ontime + (NEW.duration * INTERVAL '1 minute') > (NEW.ontime::date + INTERVAL '1 day' + INTERVAL '1 hour')) THEN 
            RAISE EXCEPTION 'Act must finish no later than 01:00 (1 AM)';
            RETURN NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER disturb_trigger
BEFORE INSERT ON act_gig
FOR EACH ROW
EXECUTE FUNCTION disturb();


--Functions for Tasks 4,5,6,7,8


-- TASK 4
CREATE OR REPLACE FUNCTION cancel_act_in_gig(gig_id INT, act_name VARCHAR)
RETURNS TABLE (
    customerName VARCHAR,
    customerEmail VARCHAR
) AS $$
DECLARE
    cancel_duration INTERVAL; -- Duration of the canceled act
    act_ontime TIMESTAMP; -- Start time of the canceled act
    act_id INT; -- ID of the canceled act
    is_first_act BOOLEAN; -- Flag to check if the canceled act is the first act in the gig
    next_act_ontime TIMESTAMP; -- Start time of the next act after the canceled act
BEGIN
    -- Check if the specified act is the first act in the gig
    SELECT MIN(ontime) = (SELECT ontime FROM act_gig ag JOIN act a ON ag.actID = a.actID WHERE ag.gigID = gig_id AND a.actName = act_name)
    FROM act_gig WHERE gigID = gig_id
    INTO is_first_act;

    -- Get the act ID and ontime of the act being canceled
    SELECT ag.ontime, ag.duration * INTERVAL '1 minute'
    INTO act_ontime, cancel_duration
    FROM act_gig ag
    JOIN act a ON ag.actID = a.actID
    WHERE ag.gigID = gig_id AND a.actName = act_name;

    -- Get the act ID of the act being canceled
    SELECT actID INTO act_id FROM act WHERE actName = act_name;

    -- Remove the act from the gig
    DELETE FROM act_gig WHERE gigID = gig_id AND actID = act_id;

    -- Adjust ontime for affected acts
    IF is_first_act THEN
        -- If the canceled act is the first, reset the next act's ontime to the canceled act's ontime
        SELECT MIN(ontime) INTO next_act_ontime FROM act_gig WHERE gigID = gig_id AND ontime > act_ontime;

        -- Update the next act to start at the canceled act's original ontime
        UPDATE act_gig SET ontime = act_ontime WHERE gigID = gig_id AND ontime = next_act_ontime;

        -- Adjust subsequent acts relative to the new start time
        UPDATE act_gig SET ontime = act_ontime + (ontime - next_act_ontime) WHERE gigID = gig_id AND ontime > act_ontime;
    ELSE
        -- Adjust ontime for subsequent acts when the canceled act is not the first
        UPDATE act_gig SET ontime = ontime - cancel_duration WHERE gigID = gig_id AND ontime > act_ontime;
    END IF;

    -- Return affected customers
    RETURN QUERY
    SELECT DISTINCT t.customerName, t.customerEmail
    FROM ticket t
    WHERE t.gigID = gig_id
    ORDER BY t.customerName;
END;
$$ LANGUAGE plpgsql;


--TASK 5
CREATE OR REPLACE FUNCTION get_tickets_needed_to_sell()
RETURNS TABLE(gigID INT, tickets_needed INT) AS $$
BEGIN
    RETURN QUERY
    SELECT gig.gigID,
    -- Calculate the number of tickets needed to sell for each gig
           CASE
               WHEN COALESCE(SUM(ticket.cost), 0) >= costs.total_cost THEN 0
               ELSE CAST(CEIL((costs.total_cost - COALESCE(SUM(ticket.cost), 0)) / costs.cheapest_price) AS INTEGER)
           END AS tickets_needed
    FROM gig
    -- Subquery to calculate the total cost for each gig and the cheapest ticket price
    JOIN (
        SELECT g.gigID,
               v.hirecost + COALESCE(SUM(af.actgigfee), 0) AS total_cost,
               MIN(gt.price) AS cheapest_price
        FROM gig g
        JOIN venue v ON g.venueID = v.venueID
        -- Deduplicate act fees to ensure an act's fee is counted only once per gig
        LEFT JOIN (
            SELECT ag.gigID, ag.actID, MAX(ag.actgigfee) AS actgigfee
            FROM act_gig ag
            GROUP BY ag.gigID, ag.actID
        ) AS af ON g.gigID = af.gigID
        LEFT JOIN gig_ticket gt ON g.gigID = gt.gigID
        WHERE g.gigstatus = 'G'  -- Only include active gigs
        GROUP BY g.gigID, v.hirecost
    ) AS costs ON gig.gigID = costs.gigID
    -- Join with gig_ticket to ensure the gig has tickets
    JOIN gig_ticket ON gig.gigID = gig_ticket.gigID
    LEFT JOIN ticket ON gig.gigID = ticket.gigID
    WHERE gig.gigstatus = 'G'  -- Only include active gigs
    GROUP BY gig.gigID, costs.total_cost, costs.cheapest_price
    ORDER BY gig.gigID;
END;
$$ LANGUAGE plpgsql;



-- TASK 6
CREATE OR REPLACE FUNCTION get_ticket_sales_per_act()
RETURNS TABLE (
    actName VARCHAR(100),
    year TEXT,
    tickets_sold BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH ticket_sales AS (
        -- Ticket sales per year for each headline act
        SELECT act.actName AS actName, EXTRACT(YEAR FROM gig.gigdatetime)::TEXT AS sales_year, COUNT(ticket.ticketID) AS total_tickets
        FROM act_gig
        JOIN gig ON act_gig.gigID = gig.gigID
        JOIN ticket ON gig.gigID = ticket.gigID
        JOIN act ON act_gig.actID = act.actID
        WHERE gig.gigstatus != 'C'  -- Only include gigs that are not cancelled
        AND act_gig.ontime = (
            SELECT MAX(sub_act_gig.ontime) FROM act_gig AS sub_act_gig WHERE sub_act_gig.gigID = act_gig.gigID
        )  -- Only include headline acts
        GROUP BY act.actName, EXTRACT(YEAR FROM gig.gigdatetime)
        UNION ALL

        -- Total ticket sales for each headline act
        SELECT act.actName AS actName, 'Total' AS sales_year, COUNT(ticket.ticketID) AS total_tickets
        FROM act_gig
        JOIN gig ON act_gig.gigID = gig.gigID
        JOIN ticket ON gig.gigID = ticket.gigID
        JOIN act ON act_gig.actID = act.actID
        WHERE gig.gigstatus != 'C'  -- Only include gigs that are not cancelled
        AND act_gig.ontime = (
            SELECT MAX(sub_act_gig.ontime) FROM act_gig AS sub_act_gig WHERE sub_act_gig.gigID = act_gig.gigID
            )  -- Only include headline acts
        GROUP BY act.actName
    ),

    -- Subquery to calculate total ticket sales per act
    total_sales_per_act AS (
        SELECT ts.actName, SUM(ts.total_tickets) AS total_tickets FROM ticket_sales ts WHERE ts.sales_year != 'Total'
        GROUP BY ts.actName
    )
    SELECT ts.actName, ts.sales_year, ts.total_tickets FROM ticket_sales ts
    JOIN total_sales_per_act tspa ON ts.actName = tspa.actName
    ORDER BY 
        tspa.total_tickets ASC, -- Order by total ticket sales (ascending)
        ts.actName, -- Break ties by act name
        CASE WHEN ts.sales_year = 'Total' THEN 1 ELSE 0 END, -- Place 'Total' last
        ts.sales_year; -- Order years numerically
END;
$$ LANGUAGE plpgsql;


--TASK 7
CREATE OR REPLACE FUNCTION get_regular_attendees()
RETURNS TABLE (
    result1 VARCHAR(100), -- Act name
    result2 VARCHAR(100)  -- Customer name
) AS $$
BEGIN
    RETURN QUERY
    WITH headline_acts AS (
        -- Find all headline acts for gigs that are not cancelled
        SELECT a.actName AS act_name, g.gigID FROM act_gig ag
        JOIN act a ON ag.actID = a.actID
        JOIN gig g ON ag.gigID = g.gigID
        WHERE g.gigstatus != 'C' -- Only include gigs that are not cancelled
        AND ag.ontime = (
            SELECT MAX(ag2.ontime) FROM act_gig ag2 WHERE ag2.gigID = ag.gigID
        ) -- Only include the headline act
    ),

    -- Subquery to count the number of distinct gigs attended by each customer for each act
    customer_gig_count AS (
        SELECT ha.act_name, t.customerName AS customer_name, COUNT(DISTINCT ha.gigID) AS gig_count
        FROM headline_acts ha
        JOIN ticket t ON ha.gigID = t.gigID
        GROUP BY ha.act_name, t.customerName
    ),

    -- Subquery to filter customers who attended at least two different gigs for the same act
    regular_attendees AS (
        SELECT cgc.act_name AS result1, cgc.customer_name AS result2
        FROM customer_gig_count cgc
        WHERE cgc.gig_count >= 2
    ),

    -- Subquery to find acts with no customers
    acts_with_no_customers AS (
        SELECT ha.act_name AS result1, '[None]' AS result2
        FROM headline_acts ha
        WHERE NOT EXISTS (
            SELECT 1 FROM customer_gig_count cgc WHERE cgc.act_name = ha.act_name
        )
    )

    -- Combine results from regular attendees and acts with no customers
    SELECT combined_results.result1, combined_results.result2
    FROM (
        SELECT * FROM regular_attendees
        UNION ALL
        SELECT * FROM acts_with_no_customers
    ) combined_results
    ORDER BY 
        combined_results.result1 ASC,  -- Alphabetical order of acts
        combined_results.result2 ASC;  -- Alphabetical order of customers ('[None]' will appear last for each act)
END;
$$ LANGUAGE plpgsql;


--TASK 8
CREATE OR REPLACE FUNCTION get_economically_feasible_acts()
RETURNS TABLE (
    venue_name VARCHAR(100),  -- Updated column name
    act_name VARCHAR(100),
    min_tickets_needed INT
) AS $$
BEGIN
    RETURN QUERY

    -- Subqueries to calculate average ticket price 
    WITH avg_ticket_price AS (
        SELECT AVG(price) AS avg_price FROM gig_ticket
        JOIN gig ON gig.gigID = gig_ticket.gigID
        WHERE gig.gigstatus != 'C'  -- Exclude cancelled gigs
    ),

    -- Subquery to get venue capacities
    venues_with_capacity AS (
        SELECT venueID, venuename, capacity FROM venue
    ),

    -- Subquery to get all feasible act-venue pairs
    feasible_acts AS (
        SELECT v.venueID, v.venuename AS venue_name, a.actName, a.standardfee, v.hirecost, v.capacity
        FROM venue v
        CROSS JOIN act a  -- Generate all possible act-venue pairs
    )

    -- Main query to find economically feasible acts
    SELECT fa.venue_name, fa.actName, CEIL((fa.standardfee + fa.hirecost) / atp.avg_price)::INT AS min_tickets_needed
    FROM feasible_acts fa
    CROSS JOIN avg_ticket_price atp
    JOIN venues_with_capacity vwc ON fa.venueID = vwc.venueID
    WHERE
        -- Only include feasible acts where the required ticket sales are greater than zero
        (fa.standardfee + fa.hirecost) / atp.avg_price > 0

        AND
        -- Only include feasible acts where the income can cover the costs
        (fa.standardfee + fa.hirecost) <= (vwc.capacity * atp.avg_price) 

        AND
        -- Only include feasible acts where the capacity is not exceeded
        (fa.standardfee + fa.hirecost) / atp.avg_price <= vwc.capacity
    ORDER BY 
        fa.venue_name ASC,  
        min_tickets_needed DESC; 
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION check_act_gig_date_match()
RETURNS TRIGGER AS $$
BEGIN
    -- Compare the date part of ontime with the gigdatetime
    IF DATE(NEW.ontime) <> DATE((SELECT g.gigdatetime FROM gig g WHERE g.gigID = NEW.gigID)) THEN
        RAISE EXCEPTION 'Act ontime date must match gig date';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER enforce_act_gig_date
BEFORE INSERT OR UPDATE ON act_gig
FOR EACH ROW
EXECUTE FUNCTION check_act_gig_date_match();











