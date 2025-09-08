
DROP DATABASE IF EXISTS airline_db;
CREATE DATABASE airline_db;
USE airline_db;



-- Customers Table
CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Flights Table
CREATE TABLE Flights (
    flight_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_number VARCHAR(20) UNIQUE NOT NULL,
    origin VARCHAR(50) NOT NULL,
    destination VARCHAR(50) NOT NULL,
    departure_time DATETIME NOT NULL,
    arrival_time DATETIME NOT NULL,
    total_seats INT NOT NULL
);

-- Seats Table
CREATE TABLE Seats (
    seat_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_id INT,
    seat_number VARCHAR(10),
    is_booked BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id)
);

-- Bookings Table
CREATE TABLE Bookings (
    booking_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    flight_id INT,
    seat_id INT,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status ENUM('CONFIRMED','CANCELLED') DEFAULT 'CONFIRMED',
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),
    FOREIGN KEY (seat_id) REFERENCES Seats(seat_id)
);

-- Waitlist Table
CREATE TABLE Waitlist (
    waitlist_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_id INT,
    customer_id INT,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    priority INT DEFAULT 1,
    status ENUM('WAITING','CONFIRMED','CANCELLED') DEFAULT 'WAITING',
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id),
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
);

-- Payments Table
CREATE TABLE Payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT,
    amount DECIMAL(10,2) NOT NULL,
    method ENUM('CARD','UPI','NETBANKING','WALLET') NOT NULL,
    status ENUM('SUCCESS','FAILED','REFUNDED') DEFAULT 'SUCCESS',
    transaction_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id)
);



-- Customers
INSERT INTO Customers (name, email, phone) VALUES
('Alice Kumar', 'alice@example.com', '9876543210'),
('Ravi Sharma', 'ravi@example.com', '9123456780'),
('Meena Iyer', 'meena@example.com', '9988776655'),
('John Paul', 'john@example.com', '8899776655');

-- Flights
INSERT INTO Flights (flight_number, origin, destination, departure_time, arrival_time, total_seats) VALUES
('AI101', 'Delhi', 'Mumbai', '2025-08-20 09:00:00', '2025-08-20 11:00:00', 5),
('AI202', 'Chennai', 'Bangalore', '2025-08-21 14:00:00', '2025-08-21 15:15:00', 5),
('AI303','bangalore','Mumbai','2025-09-22 15:00:00','2025-09-22 18:00:00',5);

-- Seats (Flight 1)
INSERT INTO Seats (flight_id, seat_number) VALUES
(1, '1A'), (1, '1B'), (1, '1C'), (1, '2A'), (1, '2B');

-- Seats (Flight 2)
INSERT INTO Seats (flight_id, seat_number) VALUES
(2, '1A'), (2, '1B'), (2, '1C'), (2, '2A'), (2, '2B');

-- Bookings
INSERT INTO Bookings (customer_id, flight_id, seat_id) VALUES
(1, 1, 1),
(2, 1, 2),
(3, 2, 6);

-- Payments
INSERT INTO Payments (booking_id, amount, method, status) VALUES
(1, 5000.00, 'CARD', 'SUCCESS'),
(2, 5000.00, 'UPI', 'SUCCESS'),
(3, 3000.00, 'WALLET', 'SUCCESS');

-- Waitlist (flight 1 is filling up, so extra request goes here)
INSERT INTO Waitlist (flight_id, customer_id, priority) VALUES
(1, 4, 1);



-- 1. Mark seat as booked on booking
DELIMITER //
CREATE TRIGGER seat_booked
AFTER INSERT ON Bookings
FOR EACH ROW
BEGIN
    UPDATE Seats
    SET is_booked = TRUE
    WHERE seat_id = NEW.seat_id;
END;
//
DELIMITER ;

-- 2. Free seat on cancellation & allocate from waitlist
DELIMITER //
CREATE TRIGGER seat_cancelled
AFTER UPDATE ON Bookings
FOR EACH ROW
BEGIN
    IF NEW.status='CANCELLED' THEN
        UPDATE Seats
        SET is_booked = FALSE
        WHERE seat_id = NEW.seat_id;

        -- Pick highest priority from waitlist
        UPDATE Waitlist
        SET status='CONFIRMED'
        WHERE flight_id = NEW.flight_id
        AND status='WAITING'
        ORDER BY priority ASC, request_time ASC
        LIMIT 1;
    END IF;
END;
//
DELIMITER ;

-- 3. Insert payment on booking
DELIMITER //
CREATE TRIGGER payment_on_booking
AFTER INSERT ON Bookings
FOR EACH ROW
BEGIN
    INSERT INTO Payments (booking_id, amount, method, status)
    VALUES (NEW.booking_id, 4000.00, 'CARD', 'SUCCESS');
END;
//
DELIMITER ;

-- 4. Refund on cancellation
DELIMITER //
CREATE TRIGGER refund_on_cancel
AFTER UPDATE ON Bookings
FOR EACH ROW
BEGIN
    IF NEW.status='CANCELLED' THEN
        INSERT INTO Payments (booking_id, amount, method, status)
        VALUES (NEW.booking_id, 4000.00, 'CARD', 'REFUNDED');
    END IF;
END;
//
DELIMITER ;



-- Flight Availability View
CREATE VIEW FlightAvailability AS
SELECT f.flight_id, f.flight_number, f.origin, f.destination,
       f.departure_time, f.arrival_time,
       COUNT(s.seat_id) - SUM(CASE WHEN s.is_booked=TRUE THEN 1 ELSE 0 END) AS available_seats
FROM Flights f
JOIN Seats s ON f.flight_id = s.flight_id
GROUP BY f.flight_id;

-- Booking Summary Report
CREATE VIEW BookingSummary AS
SELECT f.flight_number, f.origin, f.destination,
       COUNT(b.booking_id) AS total_bookings,
       SUM(CASE WHEN b.status='CONFIRMED' THEN 1 ELSE 0 END) AS confirmed_bookings,
       SUM(CASE WHEN b.status='CANCELLED' THEN 1 ELSE 0 END) AS cancelled_bookings
FROM Flights f
LEFT JOIN Bookings b ON f.flight_id=b.flight_id
GROUP BY f.flight_id;

-- Revenue Report
CREATE VIEW RevenueReport AS
SELECT f.flight_number, SUM(p.amount) AS total_revenue
FROM Flights f
JOIN Bookings b ON f.flight_id=b.flight_id
JOIN Payments p ON b.booking_id=p.booking_id
WHERE p.status='SUCCESS'
GROUP BY f.flight_number;

-- Find flights from Delhi to Mumbai
SELECT * FROM Flights WHERE origin='Delhi' AND destination='Mumbai';
SELECT seat_number 
FROM Seats 
WHERE flight_id=1 AND is_booked=FALSE;

SELECT f.flight_number, COUNT(b.booking_id) AS total_bookings
FROM Flights f
LEFT JOIN Bookings b ON f.flight_id = b.flight_id AND b.status='Confirmed'
GROUP BY f.flight_number;



UPDATE Bookings SET status='CANCELLED' WHERE booking_id=1;

SELECT seat_id, seat_number, is_booked
FROM Seats
WHERE seat_id = 1;

SELECT * FROM Waitlist WHERE flight_id=1;

SELECT * FROM FlightAvailability;
SELECT * FROM BookingSummary;
SELECT * FROM RevenueReport;
SELECT * FROM Waitlist;
SELECT * FROM Payments;