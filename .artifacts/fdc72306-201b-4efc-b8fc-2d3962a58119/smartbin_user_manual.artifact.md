# SmartBin App - Complete User Manual & Instruction Guide

Welcome to **SmartBin**, an IoT-enabled smart recycling waste management system designed to encourage proper waste disposal, reward eco-friendly behavior, and provide real-time monitoring.

---

## 📱 1. Portals Overview
SmartBin features three distinct user portals accessible via the top-right switcher in the app:
1. **📱 User App:** For students/users to register, deposit waste, earn eco-points, and redeem rewards/vouchers.
2. **🛠 Admin Portal:** For administrators to monitor bin fill levels, manage bin statuses, and inspect sensor/hardware events.
3. **📊 PSITS Portal:** For student organization leaders to view leaderboards, statistics, and student participation standings.

---

## 👤 2. How to Use the User App (Student Portal)

### Step A: Account Registration & Login
1. Open the app and ensure you are on the **User App** portal.
2. If you are new, click **Register** at the bottom.
3. Fill in your **Full Name**, **School ID Number**, select your **Gender** (Boy/Girl), and create a **Password**.
4. Click **Register** to create your Supabase-secured profile. Once registered, log in with your School ID and password.

### Step B: Depositing Waste & Earning Points
1. Approach a SmartBin station.
2. Place your waste item onto the smart bin scale.
3. The hardware's AI classifier and 20kg load cell will process the item (categorizing it as **Recyclable** or **Non-Biodegradable**) and weigh it in real time.
4. The ESP32 hardware automatically updates Supabase.
5. You receive points based on successful deposits, which instantly reflect in your dashboard (**Total Points**, **Items Recycled**, and **Lifetime Points**).

### Step C: Viewing Leaderboards & Vouchers
* **Leaderboard:** Check your ranking among other students in real-time.
* **Vouchers & Rewards:** Redeem your accumulated eco-points for printing credits, canteen vouchers, or badges.

---

## 🛠 3. How to Use the Admin Portal

1. Switch to the **Admin** portal using the top-right dropdown.
2. **Bin Monitoring:** View all active SmartBins, their locations, and real-time fill percentages for both **Recyclable (rec)** and **Non-Biodegradable (non)** compartments.
3. **Hardware Simulation / Testing:** Admins can trigger test deposits or simulate hardware signals to verify bin event logging.
4. **Activity Logs:** Review the history of all recent waste deposits, accepted/rejected items, and system events.

---

## 📊 4. How to Use the PSITS Portal

1. Switch to the **PSITS** portal.
2. Monitor organization-wide recycling statistics, total waste diverted, and active student leaderboards.

---

## 🔌 5. IoT Hardware & ESP32 Integration

The smart bin hardware consists of:
* **ESP32 Microcontroller** connected to Wi-Fi.
* **HX711 20kg Load Cell Amplifier** (Pins: DT on GPIO 15, SCK on GPIO 2).
* **AI Classifier Module** communicating via Serial (`"rec"` or `"non"`).

### How it Automates the App:
* **Real-Time Weighing:** Continuously monitors waste weight up to 20kg.
* **Supabase Sync:** Instantly updates `bin_compartments` (fill levels) and logs `bin_events` via REST API.
* **Auto-Reset:** Automatically resets bin fill levels back to 0% when maintenance empties the bin.
