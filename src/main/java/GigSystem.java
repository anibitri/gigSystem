import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Time;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.Scanner;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.sql.Timestamp;
import java.util.Vector;
import java.text.SimpleDateFormat;

public class GigSystem {

    public static void main(String[] args) {

        Scanner scanner = new Scanner(System.in);

        // You should only need to fetch the connection details once
        // You might need to change this to either getSocketConnection() or getPortConnection() - see below
        Connection conn = getPortConnection();

        boolean repeatMenu = true;

        while(repeatMenu){
            System.out.println("_________________________");
            System.out.println("________GigSystem________");
            System.out.println("_________________________");

            System.out.println("1. Gig Line-Up");
            System.out.println("2. Organise Gig");
            System.out.println("3. Booking a Ticket");
            System.out.println("4. Cancelling an act");
            System.out.println("5. Tickets needed to sell");
            System.out.println("6. How many Tickets sold");
            System.out.println("7. Regular Customers");
            System.out.println("8. Economically Feasible Gigs");

            System.out.println("q: Quit");

            String menuChoice = readEntry("Please choose an option: ");

            if(menuChoice.length() == 0){
                //Nothing was typed (user just pressed enter) so start the loop again
                continue;
            }
            char option = menuChoice.charAt(0);

            /**
             * If you are going to implement a menu, you must read input before you call the actual methods
             * Do not read input from any of the actual task methods
             */
            switch(option){
                case '1':
                    System.out.println("Enter the gigID: ");
                    int gigID = scanner.nextInt();
                    String[][] result = task1(conn, gigID);
                    for (String[] act : result) {
                        System.out.printf("Act Name: %s, Start Time: %s, End Time: %s%n", act[0], act[1], act[2]);
                    }
                    break;

                case '2':
                    System.out.println("Enter the venue name: ");
                    String venue = scanner.nextLine();
                    
                    System.out.println("Enter the gig title: ");
                    String gigTitle = scanner.nextLine();
                    
                    System.out.println("Enter the gig start date and time (YYYY-MM-DD HH:MM): ");
                    String gigStartStr = scanner.next() + " " + scanner.next();
                    LocalDateTime gigStart = LocalDateTime.parse(gigStartStr, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
                    
                    System.out.println("Enter the adult ticket price: ");
                    int adultTicketPrice = scanner.nextInt();

                    System.out.println("Enter the number of acts: ");
                    int numActs = scanner.nextInt();
                    ActPerformanceDetails[] actDetails = new ActPerformanceDetails[numActs];

                    for (int i = 0; i < numActs; i++) {
                        System.out.printf("Enter details for act %d:\n", i + 1);
                        
                        System.out.println("Enter actID: ");
                        int actID = scanner.nextInt();
                        
                        System.out.println("Enter the fee for this act: ");
                        int fee = scanner.nextInt();
                        
                        System.out.println("Enter the start date and time for this act (YYYY-MM-DD HH:MM): ");
                        String onTimeStr = scanner.next() + " " + scanner.next();
                        LocalDateTime onTime = LocalDateTime.parse(onTimeStr, DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm"));
                        
                        System.out.println("Enter the duration of this act in minutes: ");
                        int duration = scanner.nextInt();
                        
                        actDetails[i] = new ActPerformanceDetails(actID, fee, onTime, duration);
                    }

                    // Call task2 with the collected inputs
                    task2(conn, venue, gigTitle, gigStart, adultTicketPrice, actDetails);
                    System.out.println("Gig setup attempt complete.");
                    break;
                case '3':
                    System.out.print("Enter the gig ID: ");
                    int task3gigid = scanner.nextInt();
                    scanner.nextLine(); // Consume newline
        
                    // Prompt the user for customer name
                    System.out.print("Enter customer name: ");
                    String customerName = scanner.nextLine();
        
                    // Prompt the user for customer email
                    System.out.print("Enter customer email: ");
                    String customerEmail = scanner.nextLine();
        
                    // Prompt the user for ticket type
                    System.out.print("Enter ticket type: ");
                    String ticketType = scanner.nextLine();
        
                    // Call the task 3 method to process the ticket purchase
                    task3(conn, task3gigid, customerName, customerEmail, ticketType);
                    break;
                case '4':
                    System.out.print("Enter the gig ID: ");
                    int task4gigid = scanner.nextInt();
                    scanner.nextLine(); // Consume newline

                    System.out.print("Enter the act name: ");
                    String actName = scanner.nextLine();

                    String[][] cancelledAct = task4(conn, task4gigid, actName);
                    for (String[] customer : cancelledAct) {
                        System.out.printf("Customer Name: %s, Customer Email: %s%n", customer[0], customer[1]);
                    }
                    break;
                case '5':
                    String[][] ticketsNeeded = task5(conn);
                    for (String[] ticket : ticketsNeeded) {
                        System.out.printf("Gig ID: %s, Tickets Needed: %s%n", ticket[0], ticket[1]);
                    }
                    break;
                case '6':
                    String[][] ticketsSold = task6(conn);
                    for (String[] ticket : ticketsSold) {
                        System.out.printf("Act Name: %s, Year: %s, Tickets Sold: %s%n", ticket[0], ticket[1], ticket[2]);
                    }
                    break;
                case '7':
                    String[][] regularAttendees = task7(conn);
                    for (String[] attendee : regularAttendees) {
                        System.out.printf("Act Name: %s, Customer Name: %s%n", attendee[0], attendee[1]);
                    }
                    break;
                case '8':
                    String[][] economicallyFeasibleActs = task8(conn);
                    for (String[] act : economicallyFeasibleActs) {
                        System.out.printf("Venue Name: %s, Act Name: %s, Min Tickets Needed: %s%n", act[0], act[1], act[2]);
                    }
                    break;
                case 'q':
                    repeatMenu = false;
                    break;
                default: 
                    System.out.println("Invalid option");
            }
        }
    }

    /*
     * You should not change the names, input parameters or return types of any of the predefined methods in GigSystem.java
     * You may add extra methods if you wish (and you may overload the existing methods - as long as the original version is implemented)
     */

    public static String[][] task1(Connection conn, int gigID){
        ArrayList<String[]> lineup = new ArrayList<>();
        String query = "SELECT act.actname, act_gig.ontime, act_gig.duration FROM act JOIN act_gig ON act.actID=act_gig.actID WHERE act_gig.gigID = ? ORDER BY act_gig.ontime";
        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ps.setInt(1, gigID);
            ResultSet rs = ps.executeQuery();
            SimpleDateFormat timeFormat = new SimpleDateFormat("HH:mm");

            while (rs.next()) {
                String actname = rs.getString("actname");
                Timestamp ontime = rs.getTimestamp("ontime");
                int duration = rs.getInt("duration");


                Timestamp endtime = new Timestamp(ontime.getTime() + duration * 60000);

                String formattedOnTime = timeFormat.format(ontime);
                String formattedEndTime = timeFormat.format(endtime);

                lineup.add(new String[] {actname, formattedOnTime, formattedEndTime});

            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        String[][] result = new String[lineup.size()][3];
        return lineup.toArray(result);
    }

    public static void task2(Connection conn, String venue, String gigTitle, LocalDateTime gigStart, int adultTicketPrice, ActPerformanceDetails[] actDetails){
        String insertGigQuery = "INSERT INTO gig (venueID, gigtitle, gigdatetime, gigstatus) VALUES ((SELECT venueID FROM venue WHERE venuename = ?), ?, ?, 'G') RETURNING gigID";
        String insertActGigQuery = "INSERT INTO act_gig (actID, gigID, actgigfee, ontime, duration) VALUES ";
        String insertTicketPriceQuery = "INSERT INTO gig_ticket (gigID, pricetype, price) VALUES (?, 'A', ?)";

        try {
            conn.setAutoCommit(false);

            // Insert the gig and retrieve the generated gigID
            PreparedStatement psGig = conn.prepareStatement(insertGigQuery);
            psGig.setString(1, venue);
            psGig.setString(2, gigTitle);
            psGig.setTimestamp(3, Timestamp.valueOf(gigStart));
            ResultSet rs = psGig.executeQuery();

            int gigID = -1;
            if (rs.next()) {
                gigID = rs.getInt("gigID");
            } else {
                throw new SQLException("Failed to insert gig");
            }

            // Insert the ticket price
            PreparedStatement psTicketPrice = conn.prepareStatement(insertTicketPriceQuery);
            psTicketPrice.setInt(1, gigID);
            psTicketPrice.setInt(2, adultTicketPrice);
            psTicketPrice.executeUpdate();

            // Prepare a single query for act_gig insertion
            StringBuilder valuesClause = new StringBuilder();
            for (int i = 0; i < actDetails.length; i++) {
                if (i > 0) valuesClause.append(", ");
                valuesClause.append("(?, ?, ?, ?, ?)");
            }
            String finalActGigQuery = insertActGigQuery + valuesClause.toString();

            // Execute batch insert for act_gig
            PreparedStatement psActGig = conn.prepareStatement(finalActGigQuery);
            int paramIndex = 1;
            for (ActPerformanceDetails actDetail : actDetails) {
                psActGig.setInt(paramIndex++, actDetail.getActID());
                psActGig.setInt(paramIndex++, gigID);
                psActGig.setInt(paramIndex++, actDetail.getFee());
                psActGig.setTimestamp(paramIndex++, Timestamp.valueOf(actDetail.getOnTime()));
                psActGig.setInt(paramIndex++, actDetail.getDuration());
            }
            psActGig.executeUpdate();

            conn.commit();
            System.out.println("Gig successfully inserted");

        } catch (SQLException e) {
            try {
                conn.rollback();
                System.out.println("Failed to insert gig " + e.getMessage());
            } catch (SQLException rollbackex) {
                System.out.println("Failed to rollback transaction " + rollbackex.getMessage());
            }
        } finally {
            try {
                conn.setAutoCommit(true);
            } catch (SQLException ex) {
                System.out.println("Failed to set autocommit to true " + ex.getMessage());
            }
        }
        
    }

    public static void task3(Connection conn, int gigid, String name, String email, String ticketType){
        String checkGigStatus = "SELECT gigstatus FROM gig WHERE gigID = ?";
        String checkDetails = "SELECT price FROM gig_ticket where gigID = ? AND pricetype = ?";
        String insertTicket = "INSERT INTO ticket (gigID, pricetype, cost, customername, customeremail) VALUES (?, ?, ?, ?, ?)"; 
        
        try {
            conn.setAutoCommit(false);

            PreparedStatement psCheckStatus = conn.prepareStatement(checkGigStatus);
            psCheckStatus.setInt(1, gigid);
            ResultSet rsGig = psCheckStatus.executeQuery();

            if (!rsGig.next() || !"G".equals(rsGig.getString("gigstatus"))) {
                System.out.println("Invalid gig, gig cancelled or not found");
                conn.rollback();
                return;
            }

            PreparedStatement psCheckDetails = conn.prepareStatement(checkDetails);
            psCheckDetails.setInt(1, gigid);
            psCheckDetails.setString(2, ticketType);
            ResultSet rsDetails = psCheckDetails.executeQuery();

            if(!rsDetails.next()) {
                System.out.println("Invalid ticket type");
                conn.rollback();
                return;
            }

            int ticketCost = rsDetails.getInt("price");

            PreparedStatement psInsertTicket = conn.prepareStatement(insertTicket);
            psInsertTicket.setInt(1, gigid);
            psInsertTicket.setString(2, ticketType);
            psInsertTicket.setInt(3, ticketCost);
            psInsertTicket.setString(4, name);
            psInsertTicket.setString(5, email);
            psInsertTicket.executeUpdate();
            
            conn.commit();
            System.out.println("Ticket successfully inserted");

        } catch (SQLException e) {
            if (e.getMessage().contains("capacity")) {
                System.out.println("Ticket purchase failed: Venue capacity exceeded.");
            } else {
                System.out.println("Ticket purchase failed due to a constraint violation." + e.getMessage());
            }
            try {
                conn.rollback();
            } catch (SQLException ex) {
                ex.printStackTrace();
            }
        } finally{
            try {
                conn.setAutoCommit(true);
            } catch (SQLException ex) {
                ex.printStackTrace();
            }
        }
    }

    public static String[][] task4(Connection conn, int gigID, String actName){

        String query = "SELECT * FROM cancel_act_in_gig(?, ?)";
        List<String[]> output = new ArrayList<>();

        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ps.setInt(1, gigID);
            ps.setString(2, actName);
            ResultSet rs = ps.executeQuery();

            while (rs.next()) {
                String cname = rs.getString("customername");
                String cemail = rs.getString("customeremail");
                output.add(new String[] {cname, cemail});
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }


        return output.toArray(new String[0][2]);
    }

    public static String[][] task5(Connection conn){
       String query = "SELECT * FROM get_tickets_needed_to_sell()";
        List<String[]> output = new ArrayList<>();

        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ResultSet rs = ps.executeQuery();
            
            while (rs.next()) {
                String gigID = rs.getString("gigid");
                String ticketsNeeded = rs.getString("tickets_needed");
                output.add(new String[] {gigID, ticketsNeeded});
            }

        } catch (SQLException e) {
            e.printStackTrace();
        }
        return output.toArray(new String[0][2]);
    }

    public static String[][] task6(Connection conn){
        String query = "SELECT * FROM get_ticket_sales_per_act()";
        List<String[]> output = new ArrayList<>();

        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ResultSet rs = ps.executeQuery();
            
            while (rs.next()) {
                String actName = rs.getString("actname");
                String year = rs.getString("year");
                String ticketsSold = rs.getString("tickets_sold");
                output.add(new String[] {actName,year, ticketsSold});
            }


        } catch (SQLException e) {
            e.printStackTrace();
        }
        return output.toArray(new String[0][3]);
    }

    public static String[][] task7(Connection conn){
        String query = "SELECT * FROM get_regular_attendees()";
        List<String[]> output = new ArrayList<>();
        

        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ResultSet rs = ps.executeQuery();

            while (rs.next()) {
                String actName = rs.getString("actname");
                String customerName = rs.getString("customername");
                output.add(new String[] {actName, customerName});
                }

        } catch (SQLException e) {
            e.printStackTrace();
            return null;
        }

        return output.toArray(new String[0][2]);
    }

    public static String[][] task8(Connection conn){
        String query = "SELECT * FROM get_economically_feasible_acts()";
        List<String[]> output = new ArrayList<>();

        try {
            PreparedStatement ps = conn.prepareStatement(query);
            ResultSet rs = ps.executeQuery();
            
            while (rs.next()) {
                String venueName = rs.getString("venuename");
                String actname = rs.getString("act_name");
                int mintickets = rs.getInt("min_tickets_needed");
                output.add(new String[] {venueName, actname, Integer.toString(mintickets)});
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return output.toArray(new String[0][3]);
    }

    /**
     * Prompts the user for input
     * @param prompt Prompt for user input
     * @return the text the user typed
     */
    private static String readEntry(String prompt) {
        
        try {
            StringBuffer buffer = new StringBuffer();
            System.out.print(prompt);
            System.out.flush();
            int c = System.in.read();
            while(c != '\n' && c != -1) {
                buffer.append((char)c);
                c = System.in.read();
            }
            return buffer.toString().trim();
        } catch (IOException e) {
            return "";
        }

    }
     
    /**
    * Gets the connection to the database using the Postgres driver, connecting via unix sockets
    * @return A JDBC Connection object
    */
    public static Connection getSocketConnection(){
        Properties props = new Properties();
        props.setProperty("socketFactory", "org.newsclub.net.unix.AFUNIXSocketFactory$FactoryArg");
        props.setProperty("socketFactoryArg",System.getenv("HOME") + "/cs258-postgres/postgres/tmp/.s.PGSQL.5432");
        Connection conn;
        try{
          conn = DriverManager.getConnection("jdbc:postgresql://localhost/cwk", props);
          return conn;
        }catch(Exception e){
            e.printStackTrace();
        }
        return null;
    }

    /**
     * Gets the connection to the database using the Postgres driver, connecting via TCP/IP port
     * @return A JDBC Connection object
     */
    public static Connection getPortConnection() {
        
        String user = "postgres";
        String passwrd = "password";
        Connection conn;

        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException x) {
            System.out.println("Driver could not be loaded");
        }

        try {
            conn = DriverManager.getConnection("jdbc:postgresql://127.0.0.1:5432/cwk?user="+ user +"&password=" + passwrd);
            return conn;
        } catch(SQLException e) {
            System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
            e.printStackTrace();
            System.out.println("Error retrieving connection");
            return null;
        }
    }

    /**
     * Iterates through a ResultSet and converts to a 2D Array of Strings
     * @param rs JDBC ResultSet
     * @return 2D Array of Strings
     */
     public static String[][] convertResultToStrings(ResultSet rs) {
        List<String[]> output = new ArrayList<>();
        String[][] out = null;
        try {
            int columns = rs.getMetaData().getColumnCount();
            while (rs.next()) {
                String[] thisRow = new String[columns];
                for (int i = 0; i < columns; i++) {
                    thisRow[i] = rs.getString(i + 1);
                }
                output.add(thisRow);
            }
            out = new String[output.size()][columns];
            for (int i = 0; i < output.size(); i++) {
                out[i] = output.get(i);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return out;
    }

    public static void printTable(String[][] out){
        int numCols = out[0].length;
        int w = 20;
        int widths[] = new int[numCols];
        for(int i = 0; i < numCols; i++){
            widths[i] = w;
        }
        printTable(out,widths);
    }

    public static void printTable(String[][] out, int[] widths){
        for(int i = 0; i < out.length; i++){
            for(int j = 0; j < out[i].length; j++){
                System.out.format("%"+widths[j]+"s",out[i][j]);
                if(j < out[i].length - 1){
                    System.out.print(",");
                }
            }
            System.out.println();
        }
    }

}
