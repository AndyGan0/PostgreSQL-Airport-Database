/*
 *	TABLES
 */


CREATE TABLE IF NOT EXISTS public."Airport"
(
    code character varying(3) COLLATE pg_catalog."default" NOT NULL,
    name character varying COLLATE pg_catalog."default",
    city character varying COLLATE pg_catalog."default",
    timezone character varying COLLATE pg_catalog."default",
    CONSTRAINT "Airport_pkey" PRIMARY KEY (code),
    CONSTRAINT code_check CHECK (code::text ~ '^[A-Za-z]*$'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Airport"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Aircraft"
(
    aircraft_code character varying(3) COLLATE pg_catalog."default" NOT NULL,
    model_name character varying COLLATE pg_catalog."default" NOT NULL,
    capacity integer NOT NULL,
    range integer NOT NULL,
    CONSTRAINT "Aircraft_pkey" PRIMARY KEY (aircraft_code),
    CONSTRAINT model UNIQUE (model_name),
    CONSTRAINT aircraft_code_check CHECK (aircraft_code::text ~ '^[0-9]*$'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Aircraft"
    OWNER to postgres;









CREATE OR REPLACE FUNCTION public.aircraft_has_more_range(
	aircraft_model character varying,
	distance integer)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN

RETURN
(
  select exists (
    select 1 from "Aircraft"
    where "Aircraft".model_name=aircraft_model
      AND distance<="Aircraft".range)
  );
  
  
  
END
$BODY$;

ALTER FUNCTION public.aircraft_has_more_range(character varying, integer)
    OWNER TO postgres;









CREATE TABLE IF NOT EXISTS public."Flight"
(
    flight_id character varying COLLATE pg_catalog."default" NOT NULL,
    departure_airport character varying COLLATE pg_catalog."default" NOT NULL,
    arrival_airport character varying COLLATE pg_catalog."default" NOT NULL,
    departure_date date,
    aircraft_model character varying COLLATE pg_catalog."default",
    distance integer,
    scheduled_departure_time time with time zone,
    scheduled_arrival_time time with time zone,
    scheduled_duration_time interval,
    actual_departure_time time with time zone,
    actual_arrival_time time with time zone,
    flight_status character varying COLLATE pg_catalog."default",
    CONSTRAINT "Flight_pkey" PRIMARY KEY (flight_id),
    CONSTRAINT aircraft_model FOREIGN KEY (aircraft_model)
        REFERENCES public."Aircraft" (model_name) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT arrival_airport FOREIGN KEY (arrival_airport)
        REFERENCES public."Airport" (code) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT departure_airport FOREIGN KEY (departure_airport)
        REFERENCES public."Airport" (code) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT "Aircraft_has_more_range" CHECK (aircraft_has_more_range(aircraft_model, distance)),
    CONSTRAINT "departure_not_same as_arrival_airport" CHECK (arrival_airport::text <> departure_airport::text),
    CONSTRAINT state_is_valid CHECK (flight_status::text = 'Scheduled'::text OR flight_status::text = 'OnTime'::text OR flight_status::text = 'Delayed'::text OR flight_status::text = 'Departed'::text OR flight_status::text = 'Arrival'::text OR flight_status::text = 'Cancelled'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Flight"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Book"
(
    book_date date NOT NULL,
    book_ref character varying(6) COLLATE pg_catalog."default" NOT NULL,
    overall_value integer NOT NULL,
    CONSTRAINT "Book_pkey" PRIMARY KEY (book_ref),
    CONSTRAINT book_ref_check CHECK (book_ref::text ~ '^[A-Za-z0-9]*$'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Book"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Ticket"
(
    ticket_no character varying(13) COLLATE pg_catalog."default" NOT NULL,
    passenger_id character varying COLLATE pg_catalog."default" NOT NULL,
    passenger_name character varying COLLATE pg_catalog."default" NOT NULL,
    contact_data character varying COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Ticket_pkey" PRIMARY KEY (ticket_no),
    CONSTRAINT "Ticket_only_numbers" CHECK (ticket_no::text ~ '^[0-9]*$'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Ticket"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Book_has_Tickets"
(
    book_ref character varying(6) COLLATE pg_catalog."default" NOT NULL,
    ticket_no character varying(13) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Book_has_Tickets_pkey" PRIMARY KEY (ticket_no),
    CONSTRAINT book_ref FOREIGN KEY (book_ref)
        REFERENCES public."Book" (book_ref) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
        NOT VALID,
    CONSTRAINT ticket_no FOREIGN KEY (ticket_no)
        REFERENCES public."Ticket" (ticket_no) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
        NOT VALID
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Book_has_Tickets"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Book_has_Flights"
(
    book_ref character varying(6) COLLATE pg_catalog."default" NOT NULL,
    flight_id character varying COLLATE pg_catalog."default" NOT NULL,
    amount integer NOT NULL,
    fare character varying COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Ticket_has_Flights_pkey" PRIMARY KEY (book_ref, flight_id),
    CONSTRAINT book_ref FOREIGN KEY (book_ref)
        REFERENCES public."Book" (book_ref) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT flight_id FOREIGN KEY (flight_id)
        REFERENCES public."Flight" (flight_id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fare_check CHECK (fare::text = 'Economy'::text OR fare::text = 'Business'::text OR fare::text = 'First Class'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Book_has_Flights"
    OWNER to postgres;










CREATE TABLE IF NOT EXISTS public."Boarding_Pass"
(
    boarding_no integer NOT NULL,
    flight_id character varying COLLATE pg_catalog."default" NOT NULL,
    passenger_name character varying COLLATE pg_catalog."default" NOT NULL,
    seat_no character varying COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Boarding_Pass_pkey" PRIMARY KEY (boarding_no, flight_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Boarding_Pass"
    OWNER to postgres;


















/*
 *	CHECK-IN PROCEDURE
 */
CREATE OR REPLACE PROCEDURE public.check_in(
	IN new_ticket_no character varying,
	IN new_flight_id character varying,
	IN new_seat_no character varying)
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    Current_seats integer;
    Max_seats integer;
    passengers_name VARCHAR;
    flight_status VARCHAR;

BEGIN

    
    SELECT "Flight".flight_status FROM "Flight" WHERE "Flight".flight_id=new_flight_id
    INTO flight_status;
    
    /* CHECKING status */
    if flight_status!='OnTime' AND flight_status!='Delayed' THEN
       RAISE NOTICE  'UNABLE TO CHECK-IN! FLIGHT STATUS: %',flight_status;
       RETURN;
    end if;            
    
    
    

    SELECT "Ticket".passenger_name FROM "Ticket" WHERE "Ticket".ticket_no=new_ticket_no
    INTO passengers_name;        
    
    /* CHECKING IF PASSENGER HAS ALREADY DONE CHECK IN */
    IF
    (SELECT EXISTS
    (SELECT * FROM "Boarding_Pass" 
    WHERE "Boarding_Pass".passenger_name=passengers_name AND "Boarding_Pass".flight_id=new_flight_id))
    THEN 
        RAISE NOTICE  'PASSENGER HAS ALREADY CHECKED-IN!';
        RETURN;
    END IF;
    
    
    
    /* CHECKING IF SEAT IS TAKEN IN THIS AIRPLANE */
    IF
    (SELECT EXISTS
    (SELECT * FROM "Boarding_Pass" 
    WHERE "Boarding_Pass".flight_id=new_flight_id AND "Boarding_Pass".seat_no=new_seat_no))
    THEN 
        RAISE NOTICE  'THIS SEAT IS ALREADY GIVEN TO SOMEONE!';
        RETURN;
    END IF;
    

    SELECT count(boarding_no) FROM "Boarding_Pass"
    WHERE "Boarding_Pass".flight_id=new_flight_id
    INTO Current_seats;

    SELECT capacity FROM "Flight" INNER JOIN "Aircraft"  ON aircraft_model=model_name 
    WHERE "Flight".flight_id=new_flight_id
    INTO Max_seats;    
    
    
    
    /* CHECKING IF MAX SEATS HAVE BEEN REACHED */
    if Current_seats>=Max_seats THEN
        RAISE NOTICE  'AIRPLANE IS FULL! NO MORE SEATS AVAILABLE!';
       RETURN;
    end if;

    /* INSERTING */
    INSERT INTO "Boarding_Pass"(boarding_no,flight_id,passenger_name,seat_no) 
    VALUES(Current_seats+1,new_flight_id,passengers_name,new_seat_no);

END;
$BODY$;
ALTER PROCEDURE public.check_in(character varying, character varying, character varying)
    OWNER TO postgres;



















/*
 *	INSERTS
 */

COPY "Airport" (code, name, city, timezone) FROM 'C:\Users\Public\csv\Airport.csv' DELIMITER ',' CSV HEADER;

COPY "Aircraft" (aircraft_code, model_name, capacity, range) FROM 'C:\Users\Public\csv\Aircraft.csv' DELIMITER ',' CSV HEADER;

COPY "Flight" (flight_id, departure_airport, arrival_airport, departure_date, aircraft_model, distance, scheduled_departure_time, scheduled_arrival_time, scheduled_duration_time, actual_departure_time, actual_arrival_time, flight_status) FROM 'C:\Users\Public\csv\Flight.csv' DELIMITER ',' CSV HEADER;

COPY "Book" (book_date, book_ref, overall_value) FROM 'C:\Users\Public\csv\Book.csv' DELIMITER ',' CSV HEADER;

COPY "Ticket" (ticket_no, passenger_id, passenger_name, contact_data) FROM 'C:\Users\Public\csv\Ticket.csv' DELIMITER ',' CSV HEADER;

COPY "Book_has_Tickets" (book_ref, ticket_no) FROM 'C:\Users\Public\csv\Book_has_Ticket.csv' DELIMITER ',' CSV HEADER;

COPY "Book_has_Flights" (book_ref, flight_id, amount, fare) FROM 'C:\Users\Public\csv\Book_has_Flight.csv' DELIMITER ',' CSV HEADER;

















/*
 *	MAKE SURE BOOK DOESNT HAVE FLIGHT WITH book_date more than 1 month earlier than departure_date
 */
CREATE OR REPLACE FUNCTION public.check_flight_for_book(
	new_book_ref character varying,
	new_flight_id character varying)
    RETURNS boolean
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
BEGIN

RETURN
(
  SELECT EXISTS (
      SELECT 1 FROM      
    
        (SELECT * FROM "Flight" 
                    JOIN "Book_has_Flights" USING(flight_id)
                    JOIN "Book" USING(book_ref)
             WHERE book_ref=new_book_ref AND flight_id=new_flight_id 
            AND departure_date>book_date AND departure_date- interval '1 month'<=book_date
        ) as t1
    
  )
  
  
);
  
  
  
END;
$BODY$;

ALTER FUNCTION public.check_flight_for_book(character varying, character varying)
    OWNER TO postgres;


ALTER TABLE "Book_has_Flights"
ADD CONSTRAINT flight_date_no_more_than_month_later CHECK(check_flight_for_book(book_ref, flight_id)) NOT VALID;














/*
 *	Flights_View
 */
CREATE OR REPLACE VIEW public."Flights_View"
 AS
 WITH t1 AS (
         SELECT "Airport".code AS departure_airport_code,
            "Airport".name AS departure_airport_name,
            "Airport".city AS departure_city,
            "Airport".timezone AS departure_timezone
           FROM "Airport"
          WHERE ("Airport".code::text IN ( SELECT "Flight_1".departure_airport
                   FROM "Flight" "Flight_1"))
        ), t2 AS (
         SELECT "Airport".code AS arrival_airport_code,
            "Airport".name AS arrival_airport_name,
            "Airport".city AS arrival_city,
            "Airport".timezone AS arrival_timezone
           FROM "Airport"
          WHERE ("Airport".code::text IN ( SELECT "Flight_1".arrival_airport
                   FROM "Flight" "Flight_1"))
        )
 SELECT "Flight".flight_id,
    t1.departure_airport_code,
    t1.departure_airport_name,
    t1.departure_city,
    t2.arrival_airport_code,
    t2.arrival_airport_name,
    t2.arrival_city,
    "Flight".departure_date,
    "Flight".scheduled_departure_time,
    "Flight".actual_departure_time,
    timezone(t2.arrival_timezone::text, "Flight".departure_date + "Flight".scheduled_departure_time + "Flight".scheduled_duration_time)::date AS scheduled_arrival_date,
    "Flight".scheduled_arrival_time,
    "Flight".actual_arrival_time,
    "Flight".scheduled_duration_time
   FROM "Flight"
     JOIN t1 ON t1.departure_airport_code::text = "Flight".departure_airport::text
     JOIN t2 ON t2.arrival_airport_code::text = "Flight".arrival_airport::text
  WHERE "Flight".departure_date = '2022-07-24'::date;

ALTER TABLE public."Flights_View"
    OWNER TO postgres;



















/*
 *	Routes_View
 */
CREATE OR REPLACE VIEW public."Routes_View"
 AS
 WITH t1 AS (
         SELECT "Airport".code AS departure_airport_code,
            "Airport".name AS departure_airport_name,
            "Airport".city AS departure_city
           FROM "Airport"
          WHERE ("Airport".code::text IN ( SELECT "Flight_1".departure_airport
                   FROM "Flight" "Flight_1"))
        ), t2 AS (
         SELECT "Airport".code AS arrival_airport_code,
            "Airport".name AS arrival_airport_name,
            "Airport".city AS arrival_city
           FROM "Airport"
          WHERE ("Airport".code::text IN ( SELECT "Flight_1".arrival_airport
                   FROM "Flight" "Flight_1"))
        ), t3 AS (
         SELECT "Flight".flight_id,
            t1.departure_airport_code,
            t1.departure_airport_name,
            t1.departure_city,
            t2.arrival_airport_code,
            t2.arrival_airport_name,
            t2.arrival_city,
            "Flight".aircraft_model,
            "Flight".scheduled_departure_time,
            "Flight".departure_date AS "Days_of_Week"
           FROM "Flight"
             JOIN t1 ON t1.departure_airport_code::text = "Flight".departure_airport::text
             JOIN t2 ON t2.arrival_airport_code::text = "Flight".arrival_airport::text
          WHERE "Flight".departure_date >= '2022-05-23'::date AND "Flight".departure_date <= '2022-05-29'::date
        ), mon AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-23'::date
        ), tue AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-24'::date
        ), wed AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-25'::date
        ), thu AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-26'::date
        ), fri AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-27'::date
        ), sat AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-28'::date
        ), sun AS (
         SELECT "Flight".flight_id
           FROM "Flight"
          WHERE "Flight".departure_date = '2022-05-29'::date
        ), days_of_week AS (
         SELECT t3_1.flight_id,
            concat(
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT mon.flight_id
                       FROM mon)) THEN 'Mo '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT tue.flight_id
                       FROM tue)) THEN ' Tu '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT wed.flight_id
                       FROM wed)) THEN ' We '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT thu.flight_id
                       FROM thu)) THEN ' Th '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT fri.flight_id
                       FROM fri)) THEN ' Fr '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT sat.flight_id
                       FROM sat)) THEN ' Sa '::text
                    ELSE ' -- '::text
                END,
                CASE
                    WHEN (t3_1.flight_id::text IN ( SELECT sun.flight_id
                       FROM sun)) THEN ' Su'::text
                    ELSE ' -- '::text
                END) AS days_of_week
           FROM t3 t3_1
        )
 SELECT t3.flight_id,
    t3.departure_airport_code,
    t3.departure_airport_name,
    t3.departure_city,
    t3.arrival_airport_code,
    t3.arrival_airport_name,
    t3.arrival_city,
    t3.aircraft_model,
    t3.scheduled_departure_time,
    t3."Days_of_Week",
    days_of_week.days_of_week
   FROM t3
     JOIN days_of_week USING (flight_id);

ALTER TABLE public."Routes_View"
    OWNER TO postgres;




















/*
 *	SELECT STATEMENTS (QUESTION 2)
 */

/*	2a	*/
SELECT passenger_id, passenger_name, book_date
FROM "Boarding_Pass"
					INNER JOIN "Ticket" USING(passenger_name)
					JOIN "Book_has_Tickets" USING (ticket_no)
					JOIN "Book" USING (book_ref)
					INNER JOIN "Flight" USING (flight_id)
WHERE flight_id='FT3pHqnyYMG' AND seat_no='1A'  AND departure_date=CURRENT_DATE-1;





/*	2b	*/
WITH t1 AS
(SELECT count(seat_no) AS taken_seats
FROM "Boarding_Pass"
WHERE flight_id='FT3pHqnyYMG'),

t2 AS
(SELECT capacity AS all_seats
FROM "Flight" INNER JOIN "Aircraft" ON aircraft_model=model_name
WHERE flight_id='FT3pHqnyYMG')

SELECT all_seats-taken_seats AS free_seats FROM t1,t2;





/*	2c	*/
SELECT flight_id FROM "Flight"
WHERE departure_date>='2022-01-01' AND departure_date<='2022-12-31'
ORDER BY actual_departure_time::time-scheduled_departure_time::time DESC
LIMIT 5;





/*	2d	*/
WITH t1 AS
(SELECT passenger_name,sum(distance) FROM "Ticket"
			JOIN "Book_has_Tickets" USING (ticket_no)
			JOIN "Book_has_Flights" USING (book_ref)
			JOIN "Flight" USING (flight_id)			
WHERE departure_date>='2022-01-01' AND departure_date<='2022-12-31'
GROUP BY passenger_name
ORDER BY sum DESC
LIMIT 5)

SELECT passenger_name FROM t1 ORDER BY sum DESC;





/*	2e	*/
WITH t1 AS 
(SELECT city,count(*) FROM "Book_has_Tickets"
					JOIN "Book_has_Flights" USING (book_ref)
					JOIN "Flight" USING (flight_id)
					INNER JOIN "Airport" ON arrival_airport=code
WHERE departure_date>='2022-01-01' AND departure_date<='2022-12-31'
GROUP BY city
ORDER BY count DESC
LIMIT 5)

SELECT city FROM t1 ORDER BY count DESC;





/*	2f	*/
WITH t1 AS
(SELECT passenger_name 
FROM (SELECT passenger_name,count(*) FROM "Boarding_Pass" GROUP BY passenger_name) as x
WHERE count>=1),

t2 AS
(SELECT passenger_name,count(*)
FROM "Boarding_Pass" NATURAL JOIN t1
WHERE boarding_no=1
GROUP BY passenger_name
ORDER BY count DESC)

SELECT passenger_name FROM t2 
WHERE count IN (SELECT max(count) FROM t2);




















/*
 *	TRIGGERS
 */

CREATE TABLE IF NOT EXISTS public."Booking_log"
(
    book_ref character varying COLLATE pg_catalog."default" NOT NULL,
    book_date date NOT NULL,
    overall_value integer NOT NULL,
    date_changed date NOT NULL,
    time_changed time without time zone NOT NULL,
    change_type character varying COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT "Booking_log_pkey" PRIMARY KEY (date_changed, time_changed),
    CONSTRAINT book_ref_check CHECK (book_ref::text ~ '^[A-Za-z0-9]*$'::text),
    CONSTRAINT change_type_check CHECK (book_ref::text = 'd'::text OR book_ref::text = 'u'::text)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public."Booking_log"
    OWNER to postgres;










CREATE OR REPLACE FUNCTION public.update_log()
    RETURNS trigger
    LANGUAGE 'plpgsql'
AS $BODY$
BEGIN	
	
    IF TG_OP='DELETE' THEN
        INSERT INTO "Booking_log" VALUES(OLD.book_ref,OLD.book_date,OLD.overall_value,CURRENT_DATE,CURRENT_TIME,'d');
        return OLD;
    ELSE
        INSERT INTO "Booking_log" VALUES(OLD.book_ref,OLD.book_date,OLD.overall_value,CURRENT_DATE,CURRENT_TIME,'u');
        return NEW;
    END IF;             

END
$BODY$;

ALTER FUNCTION public.update_log()
    OWNER TO postgres;










CREATE TRIGGER keep_logs
    BEFORE DELETE OR UPDATE 
    ON public."Book"
    FOR EACH ROW
    EXECUTE FUNCTION public.update_log();


















/*
 *	CURSORS
 */


CREATE OR REPLACE FUNCTION public.cursor_fetch(
	)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
	row_item record;
	my_cursor cursor for
					WITH t1 AS (
							 SELECT "Airport".code AS departure_airport_code,
								"Airport".name AS departure_airport_name,
								"Airport".timezone AS departure_timezone
							   FROM "Airport"
							  WHERE ("Airport".code::text IN ( SELECT "Flight_1".departure_airport
									   FROM "Flight" "Flight_1"))
							), t2 AS (
							 SELECT "Airport".code AS arrival_airport_code,
								"Airport".name AS arrival_airport_name,
								"Airport".timezone AS arrival_timezone
							   FROM "Airport"
							  WHERE ("Airport".code::text IN ( SELECT "Flight_1".arrival_airport
									   FROM "Flight" "Flight_1"))
							)
					 SELECT "Flight".departure_date,
						timezone(t2.arrival_timezone::text, "Flight".departure_date + "Flight".scheduled_departure_time + "Flight".scheduled_duration_time)::date AS arrival_date, 	
						t1.departure_airport_name,
						t2.arrival_airport_name,
						"Flight".flight_id,
						"Ticket".passenger_name
					   FROM "Flight"
						 JOIN t1 ON t1.departure_airport_code::text = "Flight".departure_airport::text
						 JOIN t2 ON t2.arrival_airport_code::text = "Flight".arrival_airport::text
						 JOIN "Book_has_Flights" USING(flight_id)
						 JOIN "Book_has_Tickets" USING(book_ref)
						 JOIN "Ticket" USING(ticket_no)
						ORDER BY passenger_name,departure_date;
						 
						 
BEGIN
	OPEN my_cursor;
	loop
		fetch my_cursor into row_item;
		exit when not found;
	end loop;
	close my_cursor;
END
	
	
$BODY$;

ALTER FUNCTION public.cursor_fetch()
    OWNER TO postgres;

















