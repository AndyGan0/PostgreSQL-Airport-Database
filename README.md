# PostgreSQL-Airport-Database

This was a project created for my university "DATABASES" Course.<br>
Desgined a PostgreSQL database for an airport company in PostgreSQL<br>

#  Database Folder
This folder contains an sql file that creates the database.
The databasee contains tables for Airports, Flights, Aircrafts, Books, Tickets and Boarding Pass.<br>
It also makes sure that inserted information is always valid. Invalid insertions are rejected<br>
Theory of normalization has been applied so that all tablets follow the Boyce-Codd Normal Form(BCNF)<br>
The database also contains 2 views, the Flights_View and Routes_View.<br>
Lastly, The database also contains triggers and the table "Booking_Log" to keep history of changes.<br><br>

#  CSV Folder
Using mockaroo, some fake data was created to test the database.<br>
The csv files from this data are inside this folder<br><br>

#  API Folder
This folder contains an Application Programming Interface developed in C#.<br>
The client connects to the database, performs certain queries and presents the results to the user.<br><br>
