SELECT COUNT(*) FROM Appointment;
SELECT COUNT(*) FROM BedRecords;
SELECT COUNT(*) FROM RoomRecords;
-----------------------------------------------------------------
--QUESTION 1: Which departments have the highest total and average costs per patient across all services (appointments, beds, and rooms)? 
-----------------------------------------------------------------

--Appointment via Doctor

SELECT 
Department.dept_id,
Department.dept_Name,
COUNT(DISTINCT Appointment.patient_id) AS number_of_unique_patients,
SUM(Appointment.payment_amount) AS total_appointment_cost,
ROUND(SUM(Appointment.payment_amount) * 1.0 / COUNT(DISTINCT Appointment.patient_id), 2) AS average_cost_per_patient
FROM Appointment
JOIN Doctor ON Appointment.doct_id = Doctor.doct_id
JOIN Department ON Doctor.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name
ORDER BY total_appointment_cost DESC
LIMIT 5;

--BedRecords via Nurse

SELECT 
Department.dept_id,
Department.dept_Name,
COUNT(DISTINCT BedRecords.patient_id) AS number_of_unique_patients,
SUM(BedRecords.amount) AS total_bedrecords_cost_via_nurse,
ROUND(SUM(BedRecords.amount) * 1.0 / COUNT(DISTINCT BedRecords.patient_id), 2) AS average_cost_per_patient_via_nurse
FROM BedRecords
JOIN Nurse ON BedRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name
ORDER BY total_bedrecords_cost_via_nurse DESC
LIMIT 5;

--RoomRecords via Nurse

SELECT 
Department.dept_id,
Department.dept_Name,
COUNT(DISTINCT RoomRecords.patient_id) AS number_of_unique_patients,
SUM(RoomRecords.amount) AS total_roomrecords_cost_via_nurse,
ROUND(SUM(RoomRecords.amount) * 1.0 / COUNT(DISTINCT RoomRecords.patient_id), 2) AS average_cost_per_patient_via_nurse
FROM RoomRecords
JOIN Nurse ON RoomRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name
ORDER BY total_roomrecords_cost_via_nurse DESC
LIMIT 5;


--TOTAL QUERY---------------------------------
--Appointment via Doctor
WITH Appointment_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
Appointment.patient_id, 
SUM(Appointment.payment_amount) AS cost
FROM Appointment
JOIN Doctor ON Appointment.doct_id = Doctor.doct_id
JOIN Department ON Doctor.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, Appointment.patient_id
),
--BedRecords via Nurse
BedRecords_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
BedRecords.patient_id,
SUM(BedRecords.amount) AS cost
FROM BedRecords
JOIN Nurse ON BedRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, BedRecords.patient_id
),
--RoomRecords via Nurse
RoomRecords_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
RoomRecords.patient_id,
SUM(RoomRecords.amount) AS cost
FROM RoomRecords
JOIN Nurse ON RoomRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, RoomRecords.patient_id
),
--COSTS UNION
All_Costs AS (
SELECT * FROM Appointment_Costs
UNION ALL
SELECT * FROM BedRecords_Costs
UNION ALL
SELECT * FROM RoomRecords_Costs
)
--Table Showing Total and Average Cost by Patient 
SELECT 
dept_id,
dept_Name,
COUNT(DISTINCT patient_id) AS total_unique_patients,
ROUND(SUM(cost), 2) AS total_cost,
ROUND(SUM(cost) * 1.0 / COUNT(DISTINCT patient_id), 2) AS average_cost_per_patient
FROM All_Costs
GROUP BY dept_id, dept_Name
ORDER BY total_cost DESC;

-----------------------------------------------------------------
--QUESTION 2: Do departments with more assigned staff roles (doctors, nurses, helpers) tend to generate higher costs? 
-----------------------------------------------------------------

--Count of Doctors
WITH Doctor_Count AS (
SELECT dept_id, COUNT(*) AS number_of_doctors
FROM Doctor
GROUP BY dept_id
),
--Count of Nurses
Nurse_Count AS (
SELECT dept_id, COUNT(*) AS number_of_nurses
FROM Nurse
GROUP BY dept_id
),
--Count of Helpers
Helper_Count AS (
SELECT dept_id, COUNT(*) AS number_of_helpers
FROM Helpers
GROUP BY dept_id
),
--Total Costs
Cost_Summary AS (
SELECT 
dept_id,
SUM(cost) AS total_cost
FROM (
-- Total Costs from Appointment
SELECT 
Department.dept_id,
Appointment.patient_id, 
SUM(Appointment.payment_amount) AS cost
FROM Appointment
JOIN Doctor ON Appointment.doct_id = Doctor.doct_id
JOIN Department ON Doctor.dept_id = Department.dept_id
GROUP BY Department.dept_id, Appointment.patient_id
UNION ALL

-- Total Costs from BedRecords 
SELECT 
Department.dept_id,
BedRecords.patient_id,
SUM(BedRecords.amount) AS cost
FROM BedRecords
JOIN Nurse ON BedRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, BedRecords.patient_id
UNION ALL

-- Total Costs from RoomRecords
SELECT 
Department.dept_id,
RoomRecords.patient_id,
SUM(RoomRecords.amount) AS cost
FROM RoomRecords
JOIN Nurse ON RoomRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, RoomRecords.patient_id
)
GROUP BY dept_id
)
--Table Showing Total Staff Count per Department
SELECT 
Doctor_Count.dept_id,
Doctor_Count.number_of_doctors,
COALESCE(Nurse_Count.number_of_nurses, 0) AS number_of_nurses,
Helper_Count.number_of_helpers,
Doctor_Count.number_of_doctors 
+ COALESCE(Nurse_Count.number_of_nurses, 0) 
+ Helper_Count.number_of_helpers AS total_staff,
Cost_Summary.total_cost
FROM Doctor_Count
LEFT JOIN Nurse_Count ON Doctor_Count.dept_id = Nurse_Count.dept_id
LEFT JOIN Helper_Count ON Doctor_Count.dept_id = Helper_Count.dept_id
LEFT JOIN Cost_Summary ON Doctor_Count.dept_id = Cost_Summary.dept_id
ORDER BY Cost_Summary.total_cost DESC;


-----------------------------------------------------------------
--QUESTION 3: Are there departments that achieve lower average patient costs while handling a similar number of patients? 
-----------------------------------------------------------------

--Cost by Appointments
WITH
Appointment_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
Appointment.patient_id, 
SUM(Appointment.payment_amount) AS cost
FROM Appointment
JOIN Doctor ON Appointment.doct_id = Doctor.doct_id
JOIN Department ON Doctor.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, Appointment.patient_id
),

--Cost by BedRecords
BedRecords_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
BedRecords.patient_id,
SUM(BedRecords.amount) AS cost
FROM BedRecords
JOIN Nurse ON BedRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, BedRecords.patient_id
),

--Cost by RoomRecords
RoomRecords_Costs AS (
SELECT 
Department.dept_id,
Department.dept_Name,
RoomRecords.patient_id,
SUM(RoomRecords.amount) AS cost
FROM RoomRecords
JOIN Nurse ON RoomRecords.nurse_id = Nurse.nurse_id
JOIN Department ON Nurse.dept_id = Department.dept_id
GROUP BY Department.dept_id, Department.dept_Name, RoomRecords.patient_id
),

--COSTS UNION
All_Costs AS (
SELECT * FROM Appointment_Costs
UNION ALL
SELECT * FROM BedRecords_Costs
UNION ALL
SELECT * FROM RoomRecords_Costs
)

--Table Showing Total and Average Cost by Patient 
SELECT 
dept_id,
dept_Name,
COUNT(DISTINCT patient_id) AS total_unique_patients,
ROUND(SUM(cost), 2) AS total_cost,
ROUND(SUM(cost) * 1.0 / COUNT(DISTINCT patient_id), 2) AS average_cost_per_patient
FROM All_Costs
GROUP BY dept_id, dept_Name
ORDER BY total_unique_patients DESC, average_cost_per_patient ASC;
