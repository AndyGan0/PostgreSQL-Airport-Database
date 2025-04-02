using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using Npgsql;

namespace Airport_API
{
    public partial class Form1 : Form
    {

        private static string ConnectionString = "User ID=postgres;Password=ADMIN;Host=localhost;Port=5432;Database=Airplanes;";            
        private static NpgsqlConnection conn;

        public Form1()
        {
            InitializeComponent();
            conn = new NpgsqlConnection(ConnectionString);                      
        }





        private void buttonA_Click(object sender, EventArgs e)
        {
            if (textBox1.Text == "")
            {
                MessageBox.Show("You have to give a flight ID!");
                return;
            }

            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "SELECT passenger_id, passenger_name, book_date FROM \"Boarding_Pass\" INNER JOIN \"Ticket\" USING(passenger_name) JOIN \"Book_has_Tickets\" USING(ticket_no) JOIN \"Book\" USING(book_ref) INNER JOIN \"Flight\" USING(flight_id) WHERE flight_id = @flight AND seat_no = '1A'  AND departure_date = CURRENT_DATE - 1;";
            command.Parameters.AddWithValue("@flight", textBox1.Text);

            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();

        }

        private void buttonB_Click(object sender, EventArgs e)
        {
            if (textBox2.Text =="")
            {
                MessageBox.Show("You have to give a flight ID!");
                return;
            }

            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "WITH t1 AS (SELECT count(seat_no) AS taken_seats FROM \"Boarding_Pass\" WHERE flight_id = @flight), t2 AS (SELECT capacity AS all_seats FROM \"Flight\" INNER JOIN \"Aircraft\" ON aircraft_model = model_name WHERE flight_id = @flight) SELECT all_seats-taken_seats AS free_seats FROM t1, t2;";
            command.Parameters.AddWithValue("@flight", textBox2.Text);
            //"FT3pHqnyYMG"
            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();
        }

        private void buttonC_Click(object sender, EventArgs e)
        {
            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "SELECT flight_id FROM \"Flight\" WHERE departure_date>= '2022-01-01' AND departure_date<= '2022-12-31' ORDER BY actual_departure_time::time - scheduled_departure_time::time DESC LIMIT 5; ";

            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();
        }

        private void buttonD_Click(object sender, EventArgs e)
        {
            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "WITH t1 AS (SELECT passenger_name, sum(distance) FROM \"Ticket\" JOIN \"Book_has_Tickets\" USING(ticket_no) JOIN \"Book_has_Flights\" USING(book_ref) JOIN \"Flight\" USING(flight_id) WHERE departure_date >= '2022-01-01' AND departure_date <= '2022-12-31' GROUP BY passenger_name ORDER BY sum DESC LIMIT 5) SELECT passenger_name FROM t1 ORDER BY sum DESC;";

            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();
        }

        private void buttonE_Click(object sender, EventArgs e)
        {
            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "WITH t1 AS (SELECT city, count(*) FROM \"Book_has_Tickets\" JOIN \"Book_has_Flights\" USING(book_ref) JOIN \"Flight\" USING(flight_id) INNER JOIN \"Airport\" ON arrival_airport = code WHERE departure_date >= '2022-01-01' AND departure_date <= '2022-12-31' GROUP BY city ORDER BY count DESC LIMIT 5) SELECT city FROM t1 ORDER BY count DESC;";

            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();
        }

        private void buttonF_Click(object sender, EventArgs e)
        {
            dataGridView1.DataSource = null;

            conn.Open();

            NpgsqlCommand command = conn.CreateCommand();
            command.Connection = conn;

            command.CommandText = "WITH t1 AS (SELECT passenger_name FROM(SELECT passenger_name, count(*) FROM \"Boarding_Pass\" GROUP BY passenger_name) as x WHERE count >= 1), t2 AS (SELECT passenger_name, count(*) FROM \"Boarding_Pass\" NATURAL JOIN t1 WHERE boarding_no = 1 GROUP BY passenger_name ORDER BY count DESC) SELECT passenger_name FROM t2 WHERE count IN(SELECT max(count) FROM t2);";

            DataTable datatable = new DataTable();
            datatable.Load(command.ExecuteReader());

            conn.Close();

            dataGridView1.DataSource = datatable;
            dataGridView1.Refresh();
        }

        private void buttonINFO_Click(object sender, EventArgs e)
        {
            MessageBox.Show("A: Εμφάνίζει το άτομο που τάξίδεψε στην θέση 1Α στην πτήση που επιλέξατε καθώς και την κράτηση του!\n" +
                            "B: Εμφάνίζει πόσες θέσεις παρέμειναν ελεύθερες στην ανώτερω πτήση!\n" +
                            "C: Εμφανίζει τις 5 πτήσεις με την μεγαλύτερη καθυστέρηση το 2022\n" +
                            "D: Εμφανιζει τους 5 πιο συχνούς ταξιδιώτες του 2022\n" +
                            "E: Εμφανιζει τους 5 πιο δημοφιλείς προορισμούς του 2022\n" +
                            "F: Εμφανίζει τους πιο γρήγορους επιβάτες");
            
        }
    }

    
}
