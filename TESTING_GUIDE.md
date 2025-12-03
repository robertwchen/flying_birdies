# Testing Guide - Flying Birdies App with v8 Metrics

## ✅ Installation Complete

The app has been successfully installed on your phone (GM1917).

## 🎯 What's New

### Backend Services Integrated:
- ✅ **BLE Service**: Connects to Flying Birdies sensor
- ✅ **Analytics Service**: Processes IMU data with v8 metrics
- ✅ **Database Service**: Saves sessions and swings to SQLite
- ✅ **Supabase Service**: Cloud sync (optional)

### v8 Metrics Implemented:
- **Shuttle Speed Ratio**: 1.5x (shuttle speed ≈ 1.5 × racket tip speed)
- **Mount to Tip Distance**: 0.39m (updated from 0.35m)
- **Force Calculation**: Uses shuttle-based momentum
- **New Metrics**: `shuttleSpeedOut`, `forceStandardized`

## 📱 Testing Steps

### 1. Launch the App
- Open "Flying Birdies" on your phone
- You should see the welcome/login screen

### 2. Navigate to Train Tab
- Log in or skip to main screen
- Tap on the "Train" tab at the bottom

### 3. Check Connection Status
- Look for the connection pill in the top right
- Should show "Not connected" (orange) initially

### 4. Connect to Sensor
- Tap the connection pill or connect button
- This should open the BLE scan sheet
- Turn on your Flying Birdies sensor
- Wait for it to appear in the list
- Tap to connect
- Connection pill should turn green: "StrikePro Sensor"

### 5. Select Stroke Type
- Choose a stroke from the dropdown:
  - Overhead Forehand
  - Overhead Backhand
  - Underarm Forehand
  - Underarm Backhand

### 6. Start Training Session
- Tap "Start session" button
- The hero card should change to "Session live"
- Shot counter should show "0 shots" with a green dot

### 7. Perform Swings
- Make swings with your racket
- Watch for metrics to update:
  - **Swing speed** (km/h) - tip speed
  - **Impact force** (N) - v8 shuttle-based force
  - **Acceleration** (m/s²) - peak acceleration
  - **Swing force** (au) - impact severity
- Shot counter should increment with each detected swing

### 8. End Session
- Tap "End session" button
- Session data is saved to local database

### 9. Check Database (Optional)
- Sessions and swings are stored in SQLite
- Can be viewed in Progress/Stats tabs (if implemented)

## 🔍 What to Look For

### ✅ Good Signs:
- App launches without crashes
- BLE connection works smoothly
- Metrics update in real-time during swings
- Shot counter increments correctly
- No lag or freezing during data processing

### ⚠️ Potential Issues:
- **No sensor found**: Make sure sensor is powered on and in range
- **Metrics not updating**: Check if session is active (green dot)
- **App crashes**: Check for permission issues (BLE, Location)
- **No swings detected**: Swing harder (threshold is 3.0 rad/s)

## 📊 v8 Metrics Validation

### Expected Values (for reference):
- **Swing Speed**: 20-60 km/h (typical badminton)
- **Shuttle Speed**: 1.5x swing speed (30-90 km/h)
- **Impact Force**: 50-300 N (shuttle-based calculation)
- **Acceleration**: 20-100 m/s²

### Quality Gates:
- Minimum angular velocity: 3.0 rad/s
- Maximum tip speed: 50 m/s (180 km/h)
- Maximum force: 1000 N
- Swing duration: 100-1500 ms

## 🐛 Troubleshooting

### BLE Connection Issues:
1. Enable Bluetooth on phone
2. Enable Location services (required for BLE scan on Android)
3. Grant app permissions when prompted
4. Restart sensor if not appearing

### No Swings Detected:
1. Make sure session is active (green dot)
2. Swing with sufficient speed (>3.0 rad/s)
3. Check sensor is properly mounted on racket
4. Verify sensor is sending data (check BLE connection)

### App Crashes:
1. Check logcat for errors: `adb logcat | grep flutter`
2. Verify all permissions granted
3. Restart app and try again

## 📝 Testing Checklist

- [ ] App launches successfully
- [ ] Can navigate to Train tab
- [ ] BLE scan finds sensor
- [ ] Can connect to sensor
- [ ] Connection status updates correctly
- [ ] Can select stroke type
- [ ] Can start session
- [ ] Metrics update during swings
- [ ] Shot counter increments
- [ ] Can end session
- [ ] No crashes or freezes
- [ ] Metrics values look reasonable

## 🎉 Success Criteria

The app is working correctly if:
1. ✅ BLE connects to Flying Birdies sensor
2. ✅ Real-time metrics display during swings
3. ✅ Swing detection works (counter increments)
4. ✅ v8 force calculation shows reasonable values
5. ✅ Sessions save to database
6. ✅ No crashes or major bugs

## 📞 Next Steps

After testing, report:
- ✅ What works well
- ⚠️ Any issues encountered
- 💡 Suggestions for improvements
- 📊 Sample metric values you observed

---

**Built:** December 2, 2025  
**Version:** 0.1.0+1  
**Backend:** v8 metrics with SHUTTLE_VS_TIP_RATIO = 1.5
